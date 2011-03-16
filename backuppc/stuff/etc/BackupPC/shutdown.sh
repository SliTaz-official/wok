#!/bin/sh

# In /etc/BackupPC/config.pl:
# $Conf{DumpPostUserCmd} = '/etc/backuppc/shutdown.sh $host $xferOK';

ADMUSER=administrator
ADMPASS=passwdadministrator

if [ $(date +%k) -lt 07 -o $(date +%k ) -gt 20 ]; then
	/usr/bin/net rpc SHUTDOWN -f -I $1 -U $ADMUSER%$ADMPASS -t 30
else
	msg="Backup failed."
	[ $2 = 1 ] && msg="Backup successful."
	echo "$msg" | smbclient -M $1 --user="backuppc"
fi
