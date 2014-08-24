#!/bin/sh
# tramys - TRAnslate MY Slitaz. Server solution
# Tool for managing translation files for SliTaz GNU/Linux
# Aleksej Bobylev <al.bobylev@gmail.com>, 2014

# How to use:
# 1. tramys2.cgi?lang=$LANG&rel=$RELEASE to generate archive
# Pass packages list in HTTP_USER_AGENT header
# (seems it have no restrictions for length and no encoded symbols ' ' and '+')
# 2. tramys2.cgi?dl=$DL_KEY to download archive (user can cancel downloading)

. /usr/bin/httpd_helper.sh

WORKING=$(mktemp -d)
DATADIR=/usr/share/tramys

# hide script
if [ "x$(GET lang)$(GET rel)$(GET dl)" == "x" ]; then
	echo -e "HTTP/1.1 404 Not Found\nContent-Type: text/html\n\n<!DOCTYPE html><html><head><title>404 - Not Found</title></head><body><h1>404 - Not Found</h1></body></html>"
	exit
fi

# begin: compress and give to client
if [ "x$(GET dl)" != "x" ]; then
	WORKING="/tmp/tmp.$(echo $(GET dl) | tr -cd 'A-Za-z0-9')" # avoid relative paths
	cat <<EOT
Content-Type: application/x-compressed-tar
Content-Length: $(stat -c %s $WORKING.tgz)
Content-Disposition: attachment; filename=tramys.tgz

EOT
	cat $WORKING.tgz
	rm -f $WORKING.tgz
	exit 0
fi
# end: compress and give to client


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

# supported 4.0 (as stable now) an cooking (rolling, 5.0)
# don't know what to do with "arm" and "x86_64" woks
case $(GET rel) in
	4*) PREFIX="stable_"; WOK="stable"  ;;
	*)  PREFIX="";       WOK="cooking" ;;
esac
WOK="/home/slitaz/$WOK/chroot/home/slitaz/wok"

PKGNUM=$(echo $HTTP_USER_AGENT | wc -w)
NUM=1

echo -e "Content-Type: text/plain\n\n" # to Yad client
echo "#Number of packages: $PKGNUM"
echo "#Searching in progress..."

for P in $HTTP_USER_AGENT; do

	echo "$((100*$NUM/$PKGNUM))" # percentage to Yad client
	NUM=$(($NUM+1))

	for list_type in mo qm; do
		IFS=$'\n'
		for line in $(grep -e "^$P	" $DATADIR/$PREFIX$list_type.list); do
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
							cp -pf $WOK/$P/install$fullname $WORKING$fullname
						done
					done
					break
				fi
			done
		done
	done
done

echo "#" # to Yad client log
echo "#Preparing archive. Please wait"

busybox tar -czf $WORKING.tgz -C $WORKING .
rm -rf $WORKING

echo "#" # to Yad client log
echo "#Done!"
echo "#Now you can proceed to downloading"
echo "#and installing your translations."
echo "#File size: $(stat -c %s $WORKING.tgz)"

echo "${WORKING#*.}" # give download key to Yad client
exit 0
