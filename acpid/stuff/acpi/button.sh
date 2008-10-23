#!/bin/sh
# button.sh - Managing button events for SliTaz
# 

source /etc/acpi/key-constants

# logger "button.sh: event=$1"

# take care about the way events are reported

EVENT_TYPE=`echo $1 | cut -d/ -f1`
if [ $EVENT_TYPE = $1 ]; then
	EVENT=$2
else
	EVENT=`echo "$1" | cut -d/ -f2`
fi

case $EVENT in
	power)
		logger "Event: button/power - sending KEY_EXIT($KEY_EXIT)"
		/usr/bin/acpi_fakekey $KEY_EXIT
	;;
	lid)
		if [ -e /usr/bin/suspend ] ; then
			logger "Event: button/lid - suspending"
			/usr/bin/suspend
		else
			logger "Event: button/lid - /usr/bin/suspend not found, skipping.."
		fi
	;;
	sleep)
		if [ -e /usr/bin/hibernate ] ; then
			logger "Event: button/sleep - hibernating"
			/usr/bin/hibernate
		else
			logger "Event: button/sleep - /usr/bin/hibernate not found, skipping.."
		fi
	;;
esac
