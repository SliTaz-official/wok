#!/bin/sh

KEEP=1
EXTRA="monthly:30:2"
BACKUP_USER=bellard
REMOTE_USER=bellard

backup_data()
{
while read file dirs; do
	find $dirs  | cpio -o -H newc | rgzip -9 > $file.cpio.gz 2> /dev/null
done <<EOT
etc		/etc /home/$BACKUP_USER/.ssh
www		/var/www/mirror-info /var/www/pizza
packages	/var/lib/tazpkg/installed
rrd		/var/spool/rrd
crontabs	/var/spool/cron/crontabs
awstats		/var/lib/awstats
EOT
}

#
# The following should be kept untouched.
#

SSH="ssh -i /home/$BACKUP_USER/.ssh/id_rsa"

cd $(dirname $0)
[ $(id -u) == 0 ] || exit 1
[ $(hostname) == $(basename $PWD) ] || exit 1

rotate()
{
	local i
	local j
	for j in $(seq $(($1 - 1)) -1 1); do
		for i in *.$2.$(($j - 1)) ; do mv -f $i ${i%.$2.*}.$2.$j; done
	done
}

[ -n "$EXTRA" ] && for x in $EXTRA ; do
	IFS=':' ; set -- $x ; unset IFS
	suffix=$1
	days=$2
	keep=$3
	for i in *.gz ; do
		mtime=$(( $(stat -c %Y $i) - ($days * 24 * 3600) ))
		j=$i.$suffix.0
		[ -e $j ] && [ $(stat -c %Y $j) -gt $mtime ] && continue
		rotate $keep gz.$suffix
		ln $i $j
	done
done
if [ 0$KEEP -gt 0 ]; then
	[ $KEEP -gt 1 ] && rotate $KEEP gz
	for i in *.gz ; do mv -f $i $i.0; done
fi

backup_data

chown $BACKUP_USER *
chmod 700 *

for i in $(cd .. ; ls); do
	[ $i == $(hostname) ] && continue
	rsync -aH -e "$SSH" --bwlimit=50 $REMOTE_USER@$i.slitaz.org:/home/backups/$i/. ../$i/.
done
