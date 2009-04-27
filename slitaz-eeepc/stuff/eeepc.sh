#!/bin/sh
#
# /etc/init.d/eeepc.sh: Script used at boot time to setup screen 
# resolution and configure hardware with tazeee on the EeePC.
# 

# Setup is run only once.
if [ ! -s /etc/eeepc.conf ]; then
	/sbin/tazeee setup
fi

. /etc/eeepc.conf

# 915resolution screen hack.
[ -n "$HACK_915" ] && 915resolution $HACK_915

# Enable Kernel Laptop mode.
echo "5" > /proc/sys/vm/laptop_mode

exit 0
