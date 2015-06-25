#!/bin/sh

export LOCAL_BACKUP_PATH="$LOCAL_BACKUP_PATH$FRIENDLY_NAME/"

if [ "$(whoami)" != "root" ]; then
  echo "Sorry, you are not root."
  exit 1
fi

if ! ping -c 1 "$HOST" ; then
        echo "no ping"
        exit 42
fi

./rsync_backup.sh $REMOTE_ADDRESS $LOCAL_BACKUP_PATH $EXCLUDED_FILE --check-only

if [ $? -eq 42 ]; then
	exit 42
fi

./rsync_backup.sh $REMOTE_ADDRESS $LOCAL_BACKUP_PATH $EXCLUDED_FILE
