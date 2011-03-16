#!/bin/sh

# In /etc/BackupPC/config.pl:
# $Conf{DumpPreUserCmd} = '/etc/backuppc/wol.sh $host $userName';

USER=$2
#USER=$2%thepassword

/usr/bin/ether-wake $1
sleep 60
for i in $(seq 1 15); do
	smbclient -L $1 -U $USER >/dev/null && break
	sleep 10
done
