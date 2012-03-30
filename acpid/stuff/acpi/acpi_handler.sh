#!/bin/sh
# A script for handling ACPI events.
# See events/*.conf for a configuration file that can be used to
# run this script.

if [ $# != 1 ]; then
	exit 1
fi
set $*

case "$1" in
	button/lid)
		[ -e /usr/sbin/pm-suspend ] && /usr/sbin/pm-suspend \
		|| logger "acpid: pm-suspend not found, skipping.." ;;
	ac_adapter)
		case "$2" in
		 AC*|AD*)
			case "$4" in
				00000000) # disconnected
					[ -e /usr/sbin/pm-powersave ] \
					&& /usr/sbin/pm-powersave battery \
					|| logger "acpid: pm-powersave not found, skipping.." ;;
				00000001) # connected
					[ -e /usr/sbin/pm-powersave ] \
					&& /usr/sbin/pm-powersave ac \
					|| logger "acpid: pm-powersave not found, skipping.." ;;
            esac ;;
		esac ;;
	*) 
		logger "acpid: action $1 $2 is not defined" ;;
esac
