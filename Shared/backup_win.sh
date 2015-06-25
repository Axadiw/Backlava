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

export EXTRA_RSYNC_PARAMS=" --fake-super"

./rsync_backup.sh "$USERNAME@$HOST:$REMOTE_ADDRESS" $LOCAL_BACKUP_PATH $EXCLUDED_FILE --check-only

if [ $? -eq 42 ]; then
	exit 42
fi

ssh "$USERNAME@$HOST" '/usr/bin/bash -s' < ./pre_win.sh $REMOTE_ADDRESS $REMOTE_ADDRESS_WINDOWS $DRIVES_BACKED_UP

if [ $? -ne 0 ]; then
	exit 1
fi

./rsync_backup.sh "$USERNAME@$HOST:$REMOTE_ADDRESS" $LOCAL_BACKUP_PATH $EXCLUDED_FILE
ssh "$USERNAME@$HOST" '/usr/bin/bash -s' < ./post_win.sh $REMOTE_ADDRESS
