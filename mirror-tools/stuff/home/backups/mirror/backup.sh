#!/bin/sh

KEEP=1
EXTRA="monthly:30:2"
BACKUP_USER=bellard
REMOTE_USER=bellard

backup_data()
{
GZIP=rgzip
which $GZIP > /dev/null || GZIP=gzip
echo "Sync doc.slitaz.org ..."
rsync -aH -e "$SSH" --bwlimit=50 \
  $REMOTE_USER@tank.slitaz.org:/home/slitaz/www/doc/data/. /var/www/doc/data/.
while read file dirs; do
	echo "Create $file.cpio.gz ..."
	( cd / ; find $dirs  | cpio -o -H newc ) | \
		$GZIP -9 > $file.cpio.gz 2> /dev/null
done <<EOT
etc		etc home/$BACKUP_USER/.ssh
www		var/www/mirror-info var/www/pizza
www2		var/www/boot /var/www/hg /var/www/pkgs /var/www/doc
packages	var/lib/tazpkg/installed
rrd		var/spool/rrd
crontabs	var/spool/cron/crontabs
awstats		var/lib/awstats
EOT
}

#
# The following should be kept untouched.
#

SSH="ssh -i /home/$BACKUP_USER/.ssh/id_rsa -o PasswordAuthentication=no"

cd $(dirname $0)
[ $(id -u) == 0 ] || exit 1
[ $(hostname) == $(basename $PWD) -o \
  $(hostname) == $(basename $PWD).slitaz.org ] || exit 1

rotate()
{
	local i
	local j
	for j in $(seq $(($1 - 1)) -1 1); do
		for i in *.$2.$(($j - 1)) ; do
			[ -e $i ] && mv -f $i ${i%.$2.*}.$2.$j
		done
	done
}

[ -n "$EXTRA" ] && for x in $EXTRA ; do
	IFS=':' ; set -- $x ; unset IFS
	suffix=$1
	days=$2
	keep=$3
	for i in *.gz ; do
		[ -e $i ] || continue
		mtime=$(( $(stat -c %Y $i) - ($days * 24 * 3600) ))
		j=$i.$suffix.0
		[ -e $j ] && [ $(stat -c %Y $j) -gt $mtime ] && continue
		rotate $keep gz.$suffix
		ln $i $j
	done
done
if [ 0$KEEP -gt 0 ]; then
	[ $KEEP -gt 1 ] && rotate $KEEP gz
	for i in *.gz ; do
		[ -e $i ] && mv -f $i $i.0
	done
fi

echo "Local backup for $(hostname) ..."
backup_data

chown $BACKUP_USER *
chmod 700 *

[ -n "$REMOTE_USER" ] && for i in $(cd .. ; ls); do
	[ $i == $(hostname) -o $i.slitaz.org == $(hostname) ] && continue
	echo "Get backups from $i ..."
	rsync -aH -e "$SSH" --bwlimit=50 $REMOTE_USER@$i.slitaz.org:/home/backups/$i/. ../$i/.
done
