<img src="./resources/logo.png" alt="backlava" title="backlava" width=200px/>
# Backlava

*Backlava* is centralized backup solution, basing on rsync and *laurent22's* **rsync-time-backup** backup script.

Client machines are backed up using ssh and rsync only.

Backup data is stored in separated folders for each machine, so it's very easy to recover them (you just need to copy them to target machine using standard "cp" command). Backups are incremental thanks to rsync's built in "--link-dest" option, and they are regullary deduplicated between machines thanks to [hardlink.py](http://www.sodarock.com/hardlink/).

# Features

 - keeping backups from last 7 days for each backed machine
 - incremental backups 
 - backup Windows, Linux and Mac OS machines
 - support for shadow copies on Windows (backing up files that are already opened, like Microsoft Outlook .pst files)
 - support for simultaneous backup of multiple drives on Windows machines
 - deduplication (thanks to [hardlink.py](http://www.sodarock.com/hardlink/) and rsync's "--link-dest" option)


# Requirements

*Backlava* was created and tested on Ubuntu, but should work as well on other Linux platforms.

Other requirements:

 - python 2.7
 - flock 2.20.1
 - rsync 3.1.0 
 - hardlinks-friendly filesystem for backup data (tested on EXT4). **FAT isn't supported here!**
 
Client machines need to have ssh server installed with certificate based authentication (backup server needs to login via ssh to client machines without a password). In order to avoid problems with access permisions, usage of root account is recommended.

# Installation

# Linux

1. Clone *Backlava* repository

		git clone https://github.com/Axadiw/Backlava.git
    
2. Provide general configuraion (according to next section)

		cd Backlava
		vim backlava.sh
	
3.  Create configuration files for each backed machine (and set execution flag for each)

		cd ..
		cd Machines
		vim sample-machine.sh				
		<edit configuraion>		
		chmod +x sample-machine.sh

4. Add *Backlava* to cron

		crontab -e	
	
at the end of crontab add:

		* * * * * /<path_to_backlava>/backlava.sh


# General configuration

General configuration is stored at the beginning of backlava.sh file:

		export LOCAL_BACKUP_PATH="path_to_backup_path"
		export LOGS_PATH="path_to_logs_path"
		SCRIPTS_FOLDER="./Machines/"
		MAX_TIME_BETWEEN_DEDUPLICATIONS=60*60*24*7
		
*LOCAL_BACKUP_PATH* - path to directory where backup data will be stored

*LOGS_PATH* - path to directory where log files will be stored

*SCRIPTS_FOLDER* - path to directory with configuration files for backed machines

*MAX_TIME_BETWEEN_DEDUPLICATIONS* - time interval (in seconds) that specifies how often deduplication should take place

# Clients configuration

Sample configuration files can be found in *Samples* directory. For each machine you need to adjust  variables located at the beginning of each configuration file.


## Unix (OSX / Linux / etc.)

Sample config:

		export FRIENDLY_NAME='SampleUnix'
		export HOST='SampleUnixHost'
		export REMOTE_ADDRESS="root@SampleUnixHost:/"
		export EXCLUDED_FILE="path_to_excluded_files_list"
		
Variables:

*FRIENDLY_NAME* - backup data and log files for this machine will be stored using this name

*HOST* - hostname or IP address of a backed machine

*REMOTE_ADDRESS* - full ssh-like path to backed files: \<username\>@\<host\>:\<path_to_backup\>

For example *REMOTE_ADDRESS* provided in sample configuration will log in to "SampleUnixHost" machine as "root" , and back up every directory that is present under "/" directory.

*EXCLUDED_FILE* - path to file with list of files / directories that will be excluded from backups on remote machine

## Windows

In addition to Unix config files, windows machines contains these variables:

*REMOTE_ADDRESS_WINDOWS* - address to directory where snapshots of backed drives will be stored

*DRIVES_BACKED_UP* - space separated list of drives that will be backed up

Please take not that **unlike on Unix machines** *REMOTE_ADDRESS* variable contains path to the same directory as *REMOTE_ADDRESS_WINDOWS*, but represented in unix style.

Sample config:

		export FRIENDLY_NAME='SampleWin'
		export HOST='SampleWinHost'
		export USERNAME='user'
		export REMOTE_ADDRESS="/cygdrive/c/RsyncBackup"
		export REMOTE_ADDRESS_WINDOWS="C:\\\RsyncBackup"
		export DRIVES_BACKED_UP="c e"
		export EXCLUDED_FILE="path_to_excluded_files_list"
		

### Additional configuration on WIndows machines

##### Vshadow

In order to create shadow copy snapshots of backed drives you need to download vshadow.exe (available [here](http://edgylogic.com/blog/vshadow-exe-versions/)) and place it in *C:\\Windows* directory (please make sure to rename downloaded file to *vhsadow.exe*))
	
	
##### SSH

In order to use *Backlava* you need to be able to log into your Windows host via ssh protocol. Here's simplified tutorial how to do it using Cygwin:

1. Install cygwin
2. Run **cyglsa-config** command in cygwin terminal
3. Reboot
4. Open Windows explorer, and go to cygwin installation directory
5. Right click "var" directory, and go to Properties -> Security tab.
6. Add access for "Administrator" group
7. Open cygwin terminal and run these commands:

		setfacl -b /var
		chown :Users /var
		chmod 757 /var
		chmod ug-s /var
		chmod +t /var
		chmod 775 /var/*
		
 8. Run **ssh-host-config** and respond to asked questions:
 
		Privilege Separation: yes
		New local account "sshd": yes
		Install sshd as service: yes
		CYGWIN value: ntsec tty
		Different name for "cyg_server": no
		Create new privileged user account "cyg_server": yes
		Set "cyg_server" password and keep in a safe place
 9. Run net start sshd
 10. Add **/usr/sbin/sshd.exe** to Windows firewall


# Links

[http://www.goodjobsucking.com/?p=62](http://www.goodjobsucking.com/?p=62)

[http://www.michaelstowe.com/backuppc/](http://www.michaelstowe.com/backuppc/)

# Thanks



Logo: Baklava by Amelia Wattenberger from the Noun Project

# LICENSE

The MIT License (MIT)

Copyright (c) 2015 Michał Mizer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

