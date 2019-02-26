#!/bin/sh
# tramys - TRAnslate MY Slitaz. Server solution
# Tool for managing translation files for SliTaz GNU/Linux
# Aleksej Bobylev <al.bobylev@gmail.com>, 2014

# How to use:
# 1. Request for archive:
#    HTTP_ACCEPT_LANGUAGE -> users locale
#    HTTP_ACCEPT -> SliTaz release
#    HTTP_COOKIE (list=...) -> space-separated list of packages to process
#
# 2. Remove archive that the user has refused to download:
#    HTTP_COOKIE (rm=DLKEY) -> remove /tmp/tmp.DLKEY.tgz file
#
# 3. Send archive to user:
#    HTTP_COOKIE (dl=DLKEY) -> send /tmp/tmp.DLKEY.tgz file

. /usr/bin/httpd_helper.sh
. /home/slitaz/www/cook/tramys2.msg # translations

WORKING=$(busybox mktemp -d) # make temp working dir /tmp/tmp.??????
DATADIR=/usr/share/tramys    # this folder contains lists

# Get user settings from HTTP headers.
lang="$HTTP_ACCEPT_LANGUAGE"
rel="$HTTP_ACCEPT"
cmd="${HTTP_COOKIE%%=*}"
arg="${HTTP_COOKIE#*=}"

#-----------#
# Functions #
#-----------#

# Prepare list for search.
# Original GNU gettext searches precisely in this order.
locales_list() {
	LL=$(echo $1 | sed 's|^\([^_.@]*\).*$|\1|')
	CC=$(echo $1 | sed -n '/_/s|^[^_]*\(_[^.@]*\).*$|\1|p')
	EE=$(echo $1 | sed -n '/./s|^[^\.]*\(\.[^@]*\).*$|\1|p')
	VV=$(echo $1 | sed -n '/@/s|^[^@]*\(@.*\)$|\1|p')
	ee=$(echo $EE | tr A-Z a-z | tr -cd a-z0-9); [ "$ee" ] && ee=.$ee
	[ "x$EE" = "x$ee" ] && ee=''

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
MY_LOCALES=$(locales_list $lang)

# Search and copy translation files
copy_translations() {
	# for all packages in list
	for P in $arg; do

		echo "$((100*$NUM/$PKGNUM))" # send percentage to Yad client
		NUM=$(($NUM+1))              # next package

		# for all list types
		for list_type in mo qm; do
			IFS=$'\n'
			for line in $(grep -e "^$P	" $DATADIR/$PREFIX$list_type.list); do
				locales=$(echo $line | cut -d'	' -f2)
				names=$(echo $line | cut -d'	' -f3)
					[ "x$names" = "x" ] && names=$P
				paths=$(echo $line | cut -d'	' -f4)
					[ "x$paths" = "x" ] && paths="$US/locale/%/$LC"

				IFS=' '
				# for all valid locale variants
				for locale in $MY_LOCALES; do
					if $(echo " $locales " | grep -q " $locale "); then

						# for all file names
						for name in $names; do
							# for all paths
							for path in $paths; do
								# substitute variables and "%"
								eval "fullname=${path//%/$locale}/${name//%/$locale}.$list_type"

								# copy translation file to working dir
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
}

#----------#
#   Main   #
#----------#

# Branch commands: list, rm, dl.
case "x$cmd" in
	xlist) # Main actions: get list, search translations, make an archive.
		# constants to use in lists
		US="/usr/share"
		LC="LC_MESSAGES"
		PY="/usr/lib/python2.7/site-packages"
		R="/usr/lib/R/library"
		RT="$R/translations/%/$LC"

		# Supported 4.0 (as stable now) and cooking (rolling, 5.0)
		# Don't know what to do with "arm" and "x86_64" woks ???
		case "x$rel" in
			x4*|xstable) PREFIX="stable_"; WOK="stable"  ;;
			*)           PREFIX="";        WOK="cooking" ;;
		esac
		# Path to the specified WOK in the SliTaz server.
		WOK="/home/slitaz/$WOK/chroot/home/slitaz/wok"

		PKGNUM=$(echo $arg | wc -w) # number of packages in the list
		NUM=1 # initial value

		echo -e "Content-Type: text/plain\n\n" # to Yad client
		msg 1 # Message to Yad log

		copy_translations

		msg 2 # Message to Yad log

		# Make the archive from working dir and remove temp working dir.
		busybox tar -czf $WORKING.tgz -C $WORKING .
		rm -rf $WORKING

		SIZE=$(ls -lh $WORKING.tgz | awk '{print $5}')
		msg 3 # Message to Yad log

		echo "${WORKING#*.}" # give download token to Yad client
		exit 0 ;;

	xrm) # Remove archive.
		# Avoid relative path to avoid removing of any system file.
		archive="/tmp/tmp.$(echo $arg | tr -cd 'A-Za-z0-9').tgz"
		rm -f $archive
		cat <<EOT
Content-Type: text/plain; charset=UTF-8
Content-Length: 0

EOT
		exit 0 ;;

	xdl) # Send archive to client.
		# Avoid relative path to avoid hijacking of any system file.
		archive="/tmp/tmp.$(echo $arg | tr -cd 'A-Za-z0-9').tgz"
		cat <<EOT
Content-Type: application/x-compressed-tar
Content-Length: $(stat -c %s $archive)
Content-Disposition: attachment; filename=tramys.tgz

EOT
		cat $archive
		# Remove archive after sending.
		rm -f $archive
		exit 0 ;;

	*) # Hide the script from the web bots and browsers.
		echo -e "HTTP/1.0 404 Not Found\nContent-Type: text/html\n\n<!DOCTYPE html><html><head><title>404 - Not Found</title></head><body><h1>404 - Not Found</h1></body></html>"
		exit ;;
esac

exit 0
