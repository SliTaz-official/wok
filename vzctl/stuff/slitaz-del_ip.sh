#!/bin/bash
# Deletes IP address from a container running SliTaz distro.
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


VENET_DEV=eth0
CFGFILE=/etc/network.conf

# Function to delete IP address
function del_ip()
{
	if grep -q ${IP_ADDR} ${CFGFILE}; then
		sed -i 's/^IP.*/IP=\"0\"/' ${CFGFILE}
	fi
	
	# Shutting down $VENET_DEV if CT is running.
	if [ "$VE_STATE" = "running" ]; then
		/sbin/ifconfig ${VENET_DEV} down
	fi
}

del_ip

exit 0
