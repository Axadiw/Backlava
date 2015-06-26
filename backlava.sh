#!/bin/bash
( flock -en 9 || exit 1

#CONFIG

export LOCAL_BACKUP_PATH="path_to_backup_path"
export LOGS_PATH="path_to_logs_path"
SCRIPTS_FOLDER="./Machines/"
MAX_TIME_BETWEEN_DEDUPLICATIONS=60*60*24*7

#--------------------------------------------------------------------

fn_parse_date() {
    case "$OSTYPE" in
        linux*) date -d "${1:0:10} ${1:11:2}:${1:13:2}:${1:15:2}" +%s ;;
        cygwin*) date -d "${1:0:10} ${1:11:2}:${1:13:2}:${1:15:2}" +%s ;;
        darwin*) date -j -f "%Y-%m-%d-%H%M%S" "$1" "+%s" ;;
    esac
}

fn_find_duplicates() {
    find "." -maxdepth 1 -name "????-??-??-??????.deduplicate" -prune | sort -r
}

cd "$(dirname "$0")"
PIDS=""
EPOCH=$(date "+%s")
NEED_TO_CREATE_DUPLICATES=false
LATEST_SUCCESSFUL_DEDUPLICATE="0000-00-00-000000"

#--------------------------------------------------------------------

for FILENAME in $(fn_find_duplicates | sort); do
    BASENAME=$(basename "$FILENAME")
    DEDUPLICATE_DATE=${BASENAME:0:17}
    TIMESTAMP=$(fn_parse_date $DEDUPLICATE_DATE)

    if [ -z "$TIMESTAMP" ]; then
        echo "Could not parse date: $FILENAME"
        continue
    fi

    LATEST_SUCCESSFUL_DEDUPLICATE=$TIMESTAMP
done

TIME_FROM_LAST_DEDUPLICATION=$(($EPOCH - $LATEST_SUCCESSFUL_DEDUPLICATE))

if [[ $TIME_FROM_LAST_DEDUPLICATION -gt $MAX_TIME_BETWEEN_DEDUPLICATIONS ]]; then
    NEED_TO_CREATE_DUPLICATES=true
fi

for SCRIPT in $SCRIPTS_FOLDER/*
        do
                if [ -f $SCRIPT -a -x $SCRIPT ]
                then
                        /usr/bin/flock -n "$SCRIPT.lock" $SCRIPT &
                        SCRIPT_BASE=$(basename "$SCRIPT")
                        PIDS="$PIDS `ps -ef | grep $SCRIPT_BASE | grep -v grep | awk '{print $2}'`"
                        PIDS=$(echo $PIDS|tr -d '\n')
                fi
done

if [ "$NEED_TO_CREATE_DUPLICATES" = true ]; then
    DEDUPLICATION_DATE=`date +"%Y-%m-%d-%H%M%S"`
    DEDUPLICATION_LOG_FILE="$LOGS_PATH/DEDUPLICATE_$DEDUPLICATION_DATE.log"

    for pid_to_wait in $PIDS
    do
    while ps -p $pid_to_wait > /dev/null; do sleep 1; done
    done

    find $LOCAL_BACKUP_PATH -maxdepth 2 -name 'latest' -print0 | xargs -0 readlink -fs | xargs hardlink -f >> $DEDUPLICATION_LOG_FILE
    rm *.deduplicate >> $DEDUPLICATION_LOG_FILE 2>&1
    touch "$DEDUPLICATION_DATE.deduplicate" 
fi
) 9>/root/backupAll.lock