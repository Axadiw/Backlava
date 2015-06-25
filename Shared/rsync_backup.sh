#!/usr/bin/env bash

APPNAME=$(basename $0 | sed "s/\.sh$//")
start_time=$(date +%s)
# -----------------------------------------------------------------------------
# Log functions
# -----------------------------------------------------------------------------

fn_log_info()  { echo "$APPNAME: $1"; }
fn_log_warn()  { echo "$APPNAME: [WARNING] $1" 1>&2; }
fn_log_error() { echo "$APPNAME: [ERROR] $1" 1>&2; }

# -----------------------------------------------------------------------------
# Make sure everything really stops when CTRL+C is pressed
# -----------------------------------------------------------------------------

fn_terminate_script() {
	fn_log_info "SIGINT caught."
	exit 1
}

trap 'fn_terminate_script' SIGINT

# -----------------------------------------------------------------------------
# Small utility functions for reducing code duplication
# -----------------------------------------------------------------------------

fn_parse_date() {
	# Converts YYYY-MM-DD-HHMMSS to YYYY-MM-DD HH:MM:SS and then to Unix Epoch.
	case "$OSTYPE" in
		linux*) date -d "${1:0:10} ${1:11:2}:${1:13:2}:${1:15:2}" +%s ;;
		cygwin*) date -d "${1:0:10} ${1:11:2}:${1:13:2}:${1:15:2}" +%s ;;
		darwin*) date -j -f "%Y-%m-%d-%H%M%S" "$1" "+%s" ;;
	esac
}

fn_find_backups() {
	find "$DEST_FOLDER" -maxdepth 1 -type d -name "????-??-??-??????" -prune | sort -r
}

fn_expire_backup() {
	# Double-check that we're on a backup destination to be completely
	# sure we're deleting the right folder
	if [ -z "$(fn_find_backup_marker "$(dirname -- "$1")")" ]; then
		fn_log_error "$1 is not on a backup destination - aborting."
		exit 1
	fi

	fn_log_info "Expiring $1"
	rm -rf -- "$1"
}

# -----------------------------------------------------------------------------
# Source and destination information
# -----------------------------------------------------------------------------

SRC_FOLDER="${1%/}"
DEST_FOLDER="${2%/}"
EXCLUSION_FILE="$3"

if [ "$4" == "--check-only" ]; then
	CHECK_IF_BACKUP_NEEDED=true
fi

for ARG in "$SRC_FOLDER" "$DEST_FOLDER" "$EXCLUSION_FILE"; do
if [[ "$ARG" == *"'"* ]]; then
		fn_log_error 'Arguments may not have any single quote characters.'
		exit 1
	fi
done

# -----------------------------------------------------------------------------
# Check that the destination drive is a backup drive
# -----------------------------------------------------------------------------

# TODO: check that the destination supports hard links

fn_backup_marker_path() { echo "$1/backup.marker"; }
fn_find_backup_marker() { find "$(fn_backup_marker_path "$1")" 2>/dev/null; }

if [ -z "$(fn_find_backup_marker "$DEST_FOLDER")" ]; then
fn_log_info "Safety check failed - the destination does not appear to be a backup folder or drive (marker file not found)."
	fn_log_info "If it is indeed a backup folder, you may add the marker file by running the following command:"
	fn_log_info ""
	fn_log_info "mkdir -p -- \"$DEST_FOLDER\" ; touch \"$(fn_backup_marker_path "$DEST_FOLDER")\""
	fn_log_info ""
	exit 1
fi

# -----------------------------------------------------------------------------
# Setup additional variables
# -----------------------------------------------------------------------------

# Date logic
NOW=$(date +"%Y-%m-%d-%H%M%S")
EPOCH=$(date "+%s")
KEEP_ALL_DATE=$(($EPOCH - 86400))       # 1 day ago
KEEP_DAILIES_DATE=$(($EPOCH - 604800)) # 7 days ago

export IFS=$'\n' # Better for handling spaces in filenames.
PROFILE_FOLDER="$HOME/.$APPNAME"
DEST="$DEST_FOLDER/$NOW"
PREVIOUS_DEST="$(fn_find_backups | head -n 1)"
INPROGRESS_FILE="$DEST_FOLDER/backup.inprogress"


# -----------------------------------------------------------------------------
# Check if backup was done in the last 24 hours
# -----------------------------------------------------------------------------

LATEST_SUCCESSFUL_BACKUP="0000-00-00-000000"
for FILENAME in $(fn_find_backups | sort); do
	BACKUP_DATE=$(basename "$FILENAME")
	TIMESTAMP=$(fn_parse_date $BACKUP_DATE)

	# Skip if failed to parse date...
	if [ -z "$TIMESTAMP" ]; then
		fn_log_warn "Could not parse date: $FILENAME"
		continue
	fi

	LATEST_SUCCESSFUL_BACKUP=$TIMESTAMP
done

TIME_FROM_LAST_BACKUP=$(($EPOCH - $LATEST_SUCCESSFUL_BACKUP))

if [ "$TIME_FROM_LAST_BACKUP" -le "$((24*60*60))" ] && [ ! -e $INPROGRESS_FILE ]; then
	fn_log_info "Backup was completed in the last 24 hours (it was done $(($TIME_FROM_LAST_BACKUP/(60*60))) hours ago). Finishing."
	exit 42
fi

if [ "$CHECK_IF_BACKUP_NEEDED" == true ]; then
	exit 0
fi

# -----------------------------------------------------------------------------
# Create profile folder if it doesn't exist
# -----------------------------------------------------------------------------

if [ ! -d "$PROFILE_FOLDER" ]; then
	fn_log_info "Creating profile folder in '$PROFILE_FOLDER'..."
	mkdir -- "$PROFILE_FOLDER"
fi

# -----------------------------------------------------------------------------
# Handle case where a previous backup failed or was interrupted.
# -----------------------------------------------------------------------------

if [ -f "$INPROGRESS_FILE" ]; then
	if pgrep -F "$INPROGRESS_FILE" "$APPNAME"> /dev/null 2>&1 ; then
		fn_log_error "Previous backup task is still active - aborting."
		exit 1
	fi
	if [ -n "$PREVIOUS_DEST" ]; then
		# - Last backup is moved to current backup folder so that it can be resumed.
		# - 2nd to last backup becomes last backup.
		fn_log_info "$INPROGRESS_FILE already exists - the previous backup failed or was interrupted. Backup will resume from there."
		mv -- "$PREVIOUS_DEST" "$DEST"
		if [ "$(fn_find_backups | wc -l)" -gt 1 ]; then
			PREVIOUS_DEST="$(fn_find_backups | sed -n '2p')"
		else
			PREVIOUS_DEST=""
		fi
		# update PID to current process to avoid multiple concurrent resumes
		echo "$$" > "$INPROGRESS_FILE"
	fi
fi

# Run in a loop to handle the "No space left on device" logic.
while : ; do

	# -----------------------------------------------------------------------------
	# Check if we are doing an incremental backup (if previous backup exists).
	# -----------------------------------------------------------------------------

	LINK_DEST_OPTION=""
	if [ -z "$PREVIOUS_DEST" ]; then
		fn_log_info "No previous backup - creating new one."
	else
		# If the path is relative, it needs to be relative to the destination. To keep
		# it simple, just use an absolute path. See http://serverfault.com/a/210058/118679
		PREVIOUS_DEST="$(cd "$PREVIOUS_DEST"; pwd)"
		fn_log_info "Previous backup found - doing incremental backup from $PREVIOUS_DEST"
		LINK_DEST_OPTION="--link-dest='$PREVIOUS_DEST'"
	fi

	# -----------------------------------------------------------------------------
	# Create destination folder if it doesn't already exists
	# -----------------------------------------------------------------------------

	if [ ! -d "$DEST" ]; then
		fn_log_info "Creating destination $DEST"
		mkdir -p -- "$DEST"
	fi

	# -----------------------------------------------------------------------------
	# Purge certain old backups before beginning new backup.
	# -----------------------------------------------------------------------------

	# Default value for $PREV ensures that the most recent backup is never deleted.
	PREV="0000-00-00-000000"
	for FILENAME in $(fn_find_backups | sort -r); do
		BACKUP_DATE=$(basename "$FILENAME")
		TIMESTAMP=$(fn_parse_date $BACKUP_DATE)

		# Skip if failed to parse date...
		if [ -z "$TIMESTAMP" ]; then
			fn_log_warn "Could not parse date: $FILENAME"
			continue
		fi

		if   [ $TIMESTAMP -ge $KEEP_ALL_DATE ]; then
			true #keep all younger than 1 day
		elif [ $TIMESTAMP -ge $KEEP_DAILIES_DATE ]; then
			# Delete all but the most recent of each day.
			[ "${BACKUP_DATE:0:10}" == "${PREV:0:10}" ] && fn_expire_backup "$FILENAME"
		else
			# Delete older than 7 days
			fn_expire_backup "$FILENAME"
		fi

		PREV=$BACKUP_DATE
	done

	# -----------------------------------------------------------------------------
	# Start backup
	# -----------------------------------------------------------------------------


	fn_log_info "Starting backup..."
	fn_log_info "From: $SRC_FOLDER"
	fn_log_info "To:   $DEST"

	CMD="rsync"
	CMD="$CMD --compress"
	CMD="$CMD --numeric-ids"
	CMD="$CMD --links"
	CMD="$CMD --hard-links"
	CMD="$CMD --archive"
	CMD="$CMD --itemize-changes"
	CMD="$CMD --delete"
	CMD="$CMD --verbose"
	CMD="$CMD --human-readable"
	CMD="$CMD --stats"

	if [ -n "$EXTRA_RSYNC_PARAMS" ]; then
		CMD="$CMD $EXTRA_RSYNC_PARAMS"
	fi

	if [ -n "$EXCLUSION_FILE" ]; then
		# We've already checked that $EXCLUSION_FILE doesn't contain a single quote
		CMD="$CMD --exclude-from '$EXCLUSION_FILE'"
	fi
	CMD="$CMD $LINK_DEST_OPTION"
	CMD="$CMD -- '$SRC_FOLDER/' '$DEST/'"
	CMD="$CMD | grep -E '^deleting|[^/]$'"

	fn_log_info "Running command:"
	fn_log_info "$CMD"

	echo "$$" > "$INPROGRESS_FILE"
	eval $CMD

	end_time=$(date +%s)
	stat_time=$((end_time - start_time))
	if [ $stat_time -lt 60 ]; then
	  stat_time="$stat_time seconds"
	elif [ $stat_time -lt 3600 ]; then
	  stat_time="$((stat_time / 60)) minutes and $((stat_time % 60)) seconds"
	else
	  stat_time="$((stat_time / 3600)) hours and $(((stat_time % 3600) / 60)) minutes"
	fi

	echo `date`
	echo "Backup Time: $stat_time"

	# -----------------------------------------------------------------------------
	# Check if we ran out of space
	# -----------------------------------------------------------------------------

	# TODO: find better way to check for out of space condition without parsing log.
	NO_SPACE_LEFT="$(grep "No space left on device (28)\|Result too large (34)" "$LOG_FILE")"

	if [ -n "$NO_SPACE_LEFT" ]; then
		fn_log_warn "No space left on device - removing oldest backup and resuming."

		if [[ "$(fn_find_backups | wc -l)" -lt "2" ]]; then
			fn_log_error "No space left on device, and no old backup to delete."
			exit 1
		fi

		fn_expire_backup "$(fn_find_backups | tail -n 1)"

		# Resume backup
		continue
	fi

	# -----------------------------------------------------------------------------
	# Check whether rsync reported any errors
	# -----------------------------------------------------------------------------
	
	if [ -n "$(grep "rsync:" "$LOG_FILE")" ]; then
		fn_log_warn "Rsync reported a warning, please check '$LOG_FILE' for more details."
	fi
	if [ -n "$(grep "rsync error:" "$LOG_FILE")" ]; then
		fn_log_error "Rsync reported an error, please check '$LOG_FILE' for more details."
		exit 1
	fi

	# -----------------------------------------------------------------------------
	# Add symlink to last successful backup
	# -----------------------------------------------------------------------------

	rm -rf -- "$DEST_FOLDER/latest"
	ln -vs -- "$(basename -- "$DEST")" "$DEST_FOLDER/latest"

	rm -f -- "$INPROGRESS_FILE"
	
	fn_log_info "Backup completed without errors."

	exit 0
done