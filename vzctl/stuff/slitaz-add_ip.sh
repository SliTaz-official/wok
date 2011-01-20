#!/bin/bash
# Adds IP address(es) in a container running Slitaz.
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#  Copyright (C) 2011 Eric Joseph-Alexandre <erjo@slitaz.org>
#

VENET_DEV=eth0
CFGFILE=/etc/network.conf

function add_ip()
{
	if ! grep -q venet0 ${CFGFILE}; then
		sed -i "s/^INTERFACE.*/INTERFACE=\"${VENET_DEV}\"/" ${CFGFILE}
	fi
	
	if [ ! -z ${IP_ADDR} ]; then
		sed -i 's/DHCP=.*/DHCP="no"/' ${CFGFILE}
		sed -i 's/STATIC=.*/STATIC="yes"/' ${CFGFILE}
		sed -i -e "s/IP=".*"/IP=\"${IP_ADDR}\"/" ${CFGFILE}
		sed -i -e "s/NETMASK=".*"/NETMASK=\"255.255.255.255\"/" ${CFGFILE}
	fi
	
	# Starting the network
	/etc/init.d/network.sh
	
	# Add default route
	/sbin/route add default ${VENET_DEV}
}

add_ip

exit 0
