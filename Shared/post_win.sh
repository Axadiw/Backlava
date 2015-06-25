#!/bin/bash
# script to delete the shadow copies used by backuppc
# URL
# http://majentis.com/2011/01/03/backuppc-with-sshrsyncvss-on-windows-server/
# Edited by Michał Mizera

SHADOW_DIR_UNIX=$1

while read line ;
do
    vshadow -ds=$line
done < ~/shadow-guids

rm -rf $SHADOW_DIR_UNIX
rm ~/shadow-guids