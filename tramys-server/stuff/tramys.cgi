#!/bin/sh
# tramys - TRAnslate MY Slitaz. Server solution
# Tool for managing translation files for SliTaz GNU/Linux
# Aleksej Bobylev <al.bobylev@gmail.com>, 2014

# How to use: tramys.cgi?lang=$LANG
# Pass packages list in HTTP_USER_AGENT header
# (seems it have no restrictions for length and no encoded symbols ' ' and '+')

. /usr/bin/httpd_helper.sh

WORKING=$(mktemp -d)
DATADIR=/home/lexeii/Public/tramys

# prepare list for search
# original GNU gettext searches precisely in this order
locales_list() {
	LL=$(echo $1 | sed 's|^\([^_.@]*\).*$|\1|')
	CC=$(echo $1 | sed -n '/_/s|^[^_]*\(_[^.@]*\).*$|\1|p')
	EE=$(echo $1 | sed -n '/./s|^[^\.]*\(\.[^@]*\).*$|\1|p')
	VV=$(echo $1 | sed -n '/@/s|^[^@]*\(@.*\)$|\1|p')
	ee=$(echo $EE | tr A-Z a-z | tr -cd a-z0-9); [ "$ee" ] && ee=.$ee
	[ "x$EE" == "x$ee" ] && ee=''

	[ "$CC" -a "$EE" -a "$VV" ]	&& echo -n "$LL$CC$EE$VV "
	[ "$CC" -a "$ee" -a "$VV" ]	&& echo -n "$LL$CC$ee$VV "
	[ "$CC" -a "$VV" ]			&& echo -n "$LL$CC$VV "
	[ "$EE" -a "$VV" ]			&& echo -n "$LL$EE$VV "
	[ "$ee" -a "$VV" ]			&& echo -n "$LL$ee$VV "
	[ "$VV" ]					&& echo -n "$LL$VV "
	[ "$CC" -a "$EE" ]			&& echo -n "$LL$CC$EE "
	[ "$CC" -a "$ee" ]			&& echo -n "$LL$CC$ee "
	[ "$CC" ]					&& echo -n "$LL$CC "
	[ "$EE" ]					&& echo -n "$LL$EE "
	[ "$ee" ]					&& echo -n "$LL$ee "
	echo "$LL"
}
MY_LOCALES=$(locales_list $(GET lang))

# constants to use in lists
US="/usr/share"
LC="LC_MESSAGES"
PY="/usr/lib/python2.7/site-packages"
R="/usr/lib/R/library"
RT="$R/translations/%/$LC"

for P in $HTTP_USER_AGENT; do

	for list_type in mo qm; do
		IFS=$'\n'
		for line in $(grep -e "^$P	" $DATADIR/$list_type.list); do
			locales=$(echo $line | cut -d'	' -f2)
			names=$(echo $line | cut -d'	' -f3)
				[ "x$names" == "x" ] && names=$P
			pathes=$(echo $line | cut -d'	' -f4)
				[ "x$pathes" == "x" ] && pathes="$US/locale/%/$LC"

			IFS=' '
			for locale in $MY_LOCALES; do
				if $(echo " $locales " | grep -q " $locale "); then

					for name in $names; do
						for path in $pathes; do
							eval "fullname=${path//%/$locale}/${name//%/$locale}.$list_type"
							mkdir -p $WORKING$(dirname $fullname)
							cp -pf /home/slitaz/cooking/chroot/home/slitaz/wok/$P/install$fullname \
								$WORKING$fullname
						done
					done
					break
				fi
			done
		done
	done
done

busybox tar -czf $WORKING.tgz -C $WORKING .
cat <<EOT
Content-Type: application/x-compressed-tar
Content-Length: $(stat -c %s $WORKING.tgz)
Content-Disposition: attachment; filename=tramys.tgz

EOT
cat $WORKING.tgz

rm -rf $WORKING
rm -f $WORKING.tgz
