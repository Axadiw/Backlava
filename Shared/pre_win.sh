#!/bin/bash
# Place vshadow.exe to C:\Windows
# Disk will be shadowed to path applied in first two arguments
# URL
# http://majentis.com/2011/01/03/backuppc-with-sshrsyncvss-on-windows-server/

##############################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# http://www.gnu.org/licenses/
##############################################################################

SHADOW_DIR_UNIX=$1
SHADOW_DIR_WINDOWS=$2

while read line ;
do
    vshadow -ds=$line
done < ~/shadow-guids

rm -rf $SHADOW_DIR_UNIX
rm ~/shadow-guids

mkdir -p $SHADOW_DIR_UNIX

for DRIVE_LETTER in ${@:3}
do
    DRIVE="$DRIVE_LETTER"":" 
    echo Shadowing Drive $DRIVE

    GUID=`vshadow.exe -p $DRIVE | grep "* SNAPSHOT ID" | awk '{print $5}'`

    if [ -z $GUID ]; then
	exit 1
    fi

    echo $GUID >> ~/shadow-guids
    echo "Drive $DRIVE GUID = $GUID"

    mkdir -p "$SHADOW_DIR_UNIX/$DRIVE_LETTER"
    vshadow.exe -el=$GUID,"$SHADOW_DIR_WINDOWS\\$DRIVE_LETTER"

    if [ $? -ne 0 ]; then
        exit 2
    fi
	
done

