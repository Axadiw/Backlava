#!/bin/sh

#CONFIG

export FRIENDLY_NAME='SampleUnix'
export HOST='SampleUnixHost'
export REMOTE_ADDRESS="root@SampleUnixHost:/"
export EXCLUDED_FILE="path_to_excluded_files_list"

# Don't change after this!
export LOG_FILE="$LOGS_PATH/$FRIENDLY_NAME-$(date +"%Y-%m-%d-%H%M%S").log"
cd "$(dirname "$0")/../Shared" 
sh backup_unix.sh > $LOG_FILE 2>&1 

# Nothing important changed, delete log file
if [ $? -eq 42 ]; then
	rm $LOG_FILE
fi
