#!/bin/sh
# /etc/init.d/wpa_supplicant.sh - WPA initialisation boot script.
# Config file is: /etc/wpa_supplicant.conf
#
. /etc/init.d/rc.functions
. /etc/network.conf

# Start wpa_supplicant
echo "Starting WPA on $INTERFACE... "
/usr/bin/wpa_supplicant -Bw -c/etc/wpa_supplicant.conf -iwlan0
