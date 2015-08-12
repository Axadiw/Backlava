#!/bin/bash

export FRIENDLY_NAME='SampleWin'
export HOST='SampleWinHost'
export USERNAME='user'
export REMOTE_ADDRESS="/cygdrive/c/RsyncBackup"
export REMOTE_ADDRESS_WINDOWS="C:\\\RsyncBackup"
export DRIVES_BACKED_UP="c e"
export EXCLUDED_FILE="path_to_excluded_files_list"

# Don't change this!
export LOG_FILE="$LOGS_PATH/$FRIENDLY_NAME-$(date +"%Y-%m-%d-%H%M%S").log"
cd "$(dirname "$0")/../Shared" 
sh backup_win.sh > $LOG_FILE 2>&1 

# Nothing important changed, delete log file
if [ $? -eq 42 ]; then
	rm $LOG_FILE
fi