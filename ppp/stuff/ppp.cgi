#!/bin/sh
#
# Network/PPP configuration CGI interface
#
# Copyright (C) 2015 SliTaz GNU/Linux - BSD License
#

# Common functions from libtazpanel
. lib/libtazpanel
get_config


case "$1" in
	menu)
		TEXTDOMAIN_original=$TEXTDOMAIN
		export TEXTDOMAIN='ppp'

		groups | grep -q dialout && dialout="" || dialout=" data-root"
		case "$2" in
		*VPN*)
		[ "$(which pptp 2>/dev/null)$(which pptpd 2>/dev/null)" ] && cat <<EOT
<li><a data-icon="vpn" href="ppp.cgi#pptp"$dialout>$(_ 'PPTP')</a></li>
EOT
		[ "$(which pppssh 2>/dev/null)" ] && cat <<EOT
<li><a data-icon="vpn" href="ppp.cgi#pppssh"$dialout>$(_ 'PPP/SSH')</a></li>
EOT
		;;
		*)
		cat <<EOT
<li><a data-icon="modem" href="ppp.cgi"$dialout>$(_ 'PPP Modem')</a></li>
EOT
		esac
		export TEXTDOMAIN=$TEXTDOMAIN_original
		exit
esac


#
# Commands
#

case " $(GET) " in
*\ setppppstn\ *)
	if [ "$(GET start_pstn)" -a "$(GET user)" ]; then
		grep -s "$(GET user)" /etc/ppp/pap-secrets ||
		echo "$(GET user)	*	$(GET pass)" >> /etc/ppp/pap-secrets
		grep -s "$(GET user)" /etc/ppp/chap-secrets ||
		echo "$(GET user)	*	$(GET pass)" >> /etc/ppp/chap-secrets
		sed -i 's/^name /d' /etc/ppp/options
		echo "name $(GET user)" >> /etc/ppp/options
		/etc/ppp/scripts/ppp-off
		/etc/ppp/scripts/ppp-on &
	fi
	if [ "$(GET stop_pstn)" ]; then
		/etc/ppp/scripts/ppp-off
	fi
	;;
*\ setpppoe\ *)
	if [ "$(GET start_pppoe)" -a "$(GET user)" ]; then
		grep -s "$(GET user)" /etc/ppp/pap-secrets ||
		echo "$(GET user)	*	$(GET pass)" >> /etc/ppp/pap-secrets
		grep -s "$(GET user)" /etc/ppp/chap-secrets ||
		echo "$(GET user)	*	$(GET pass)" >> /etc/ppp/chap-secrets
		grep -qs pppoe /etc/ppp/options || cat > /etc/ppp/options <<EOT
plugin rp-pppoe.so
noipdefault
defaultroute
mtu 1492
mru 1492
lock
EOT
		sed -i 's/^name /d' /etc/ppp/options
		echo "name $(GET user)" >> /etc/ppp/options
		( . /etc/network.conf ; pppd $INTERFACE & )
	fi
	if [ "$(GET stop_pppoe)" ]; then
		killall pppd
	fi
	;;
*\ setpppssh\ *)
	cat > /etc/ppp/pppssh <<EOT
PEER="$(GET peer)"
SSHARG="$(GET ssharg)"
LOCALIP="$(GET localip)"
REMOTEIP="$(GET remoteip)"
LOCALPPP="$(GET localpppopt)"
REMOTEPPP="$(GET remotepppopt)"
ROUTES="$(GET routes)"
UDP="$(GET udp)"
EOT
	[ "$(GET pass)" ] && export DROPBEAR_PASSWORD="$(GET pass)"
	case " $(GET) " in
	*\ send_key\ *)
		( dropbearkey -y -f /etc/dropbear/dropbear_rsa_host_key ;
		  cat /etc/ssh/ssh_host_rsa_key.pub ) 2> /dev/null | \
		grep ^ssh | dbclient $(echo $(GET send_key) | sed \
		's/.*\([A-Za-z0-9_\.-]*\).*/\1/') "mkdir .ssh 2> /dev/null ; \
		while read key; do for i in authorized_keys authorized_keys2; do \
		grep -qs '\$key' .ssh/\$i || echo '\$key' >> .ssh/\$i ; done ; done ; \
		chmod 700 .ssh ; chmod 600 .ssh/authorized_keys*"
		;;
	*\ stop_pppssh\ *)
		ppp="$(sed '/pppd/!d;s/.*="\([^"]*\).*/\1/' /usr/bin/pppssh)"
		kill $(busybox ps x | grep "$ppp" | awk '/pty/{next}/dbclient/{print $1}')
		;;
	*\ start_pppssh\ *)
EOT
		pppssh	"$(GET ssharg) $(GET peer)" \
			"$(GET localip):$(GET remoteip) $(GET localpppopt)" \
			"$(GET remotepppopt)" "$(GET routes)" "$(GET udp)" &
		;;
	esac
	;;
esac

USERNAME="$(sed '/^name/!d;s/^[^ ]* *//' /etc/ppp/options)"
PASSWORD="$(awk -v key=$USERNAME "\$1==key{print \$3}" /etc/ppp/pap-secrets)"
ACCOUNT="$(sed '/^ACCOUNT=/!d;s/^.*=\([^ \t]*\).*/\1/' /etc/ppp/scripts/ppp-on)"
PASSPSTN="$(sed '/^PASSWORD=/!d;s/^.*=\([^ \t]*\).*/\1/' /etc/ppp/scripts/ppp-on)"
PHONE="$(sed '/^TELEPHONE=/!d;s/^.*=\([^ \t]*\).*/\1/' /etc/ppp/scripts/ppp-on)"
TITLE="$(_ 'TazPanel - Network') - $(_ 'PPP Connections')"
header
xhtml_header | sed 's/id="content"/id="content-sidebar"/'
cat << EOT
<div id="sidebar">
<section>
	<header>
		$(_ 'Documentation')
	</header>
		<a data-icon="web" href="http://ppp.samba.org/" target="_blank" rel="noopener">$(_ 'PPP web page')</a><p>
		<a data-icon="help" href="index.cgi?exec=pppd%20--help" target="_blank" rel="noopener">$(_ 'PPP help')</a><p>
		<a data-icon="help" href="index.cgi?exec=man%20pppd" target="_blank" rel="noopener">$(_ 'PPP Manual')</a><p>
EOT
[ "$(which pptp 2>/dev/null)" ] && cat <<EOT
		<a data-icon="web" href="http://pptpclient.sourceforge.net/" target="_blank" rel="noopener">$(_n 'PPTP web page')</a><p>
		<a data-icon="help" href="index.cgi?exec=pptp" target="_blank" rel="noopener">$(_ 'PPTP Help')</a><p>
EOT
[ "$(which pptpd 2>/dev/null)" ] && cat <<EOT
		<a data-icon="web" href="http://poptop.sourceforge.net/" target="_blank" rel="noopener">$(_n 'PPTPD web page')</a><p>
		<a data-icon="help" href="index.cgi?exec=pptpd%20--help" target="_blank" rel="noopener">$(_ 'PPTPD Help')</a><p>
EOT
[ "$(which pppssh 2>/dev/null)" ] && cat <<EOT
		<a data-icon="web" href="http://doc.slitaz.org/en:guides:vpn" target="_blank" rel="noopener">$(_n 'VPN Wiki')</a><p>
		<a data-icon="help" href="index.cgi?exec=dbclient" target="_blank" rel="noopener">$(_ 'SSH Help')</a><p>
EOT
cat << EOT
	<footer>
	</footer>
</section>
<section>
	<header>
		$(_ 'Configuration')
	</header>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/scripts/ppp-on" target="_blank" rel="noopener">$(_ 'PPP PSTN script')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/scripts/ppp-on-dialer" target="_blank" rel="noopener">$(_ 'PPP dialer chat')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/options" target="_blank" rel="noopener">$(_ 'PPP options')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/chap-secrets" target="_blank" rel="noopener">$(_ 'chap users')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/pap-secrets" target="_blank" rel="noopener">$(_ 'pap users')</a><p>
EOT
for i in /etc/ppp/peers/* ; do
	[ -s "$i" ] && cat << EOT
		<a data-icon="conf" href="index.cgi?file=$i" target="_blank" rel="noopener">$(basename $i)</a><p>
EOT
done
[ "$(which pptpd 2>/dev/null)" ] && cat <<EOT
		<a data-icon="conf" href="index.cgi?file=/etc/pptpd.conf" target="_blank" rel="noopener">$(_ 'pptpd.conf')</a><p>
EOT
if [ "$(busybox ps x | grep "pppd" | awk '/modem/{print $1}')" ]; then
	start_disabled='disabled'
else
	stop_disabled='disabled'
fi
if [ "$(busybox ps x | grep "pppd" | awk '/eth/{print $1}')" ]; then
	startoe_disabled='disabled'
else
	stopoe_disabled='disabled'
fi
cat << EOT
	<footer>
	</footer>
</section>
</div>

<a name="ppppstn"></a>
<section>
	<header>
		<span data-icon="modem">$(_ 'PSTN modem') -
		$(_ 'Manage PSTN Internet connections')</span>
	</header>
<form action="index.cgi" id="indexform"></form>
<form method="get">
	<input type="hidden" name="setppppstn" />
	<table>
	<tr>
		<td>$(_ 'Username')</td>
		<td><input type="text" name="user" size="40" value="$ACCOUNT" /></td>
	</tr>
	<tr>
		<td>$(_ 'Password')</td>
		<td><input type="text" name="pass" size="40" value="$PASSPSTN" /></td>
	</tr>
	<tr>
		<td>$(_ 'Phone number')</td>
		<td><input type="text" name="phone" size="40" value="$PHONE" /></td>
	</tr>
	</table>
	<footer><!--
		--><button type="submit" name="start_pstn" data-icon="start" $start_disabled>$(_ 'Start'  )</button><!--
		--><button type="submit" name="stop_pstn"  data-icon="stop"  $stop_disabled >$(_ 'Stop'   )</button><!--
	--></footer>
</form>
</section>

<a name="pppoe"></a>
<section>
	<header>
		<span data-icon="eth">$(_ 'Cable Modem') -
		$(_ 'Manage PPPoE Internet connections')</span>
	</header>
<form method="get">
	<input type="hidden" name="setpppoe" />
	<table>
	<tr>
		<td>$(_ 'Username')</td>
		<td><input type="text" name="user" size="40" value="$USERNAME" /></td>
	</tr>
	<tr>
		<td>$(_ 'Password')</td>
		<td><input type="text" name="pass" size="40" value="$PASSWORD" /></td>
	</tr>
	</table>
	<footer><!--
		--><button type="submit" name="start_pppoe" data-icon="start" $startoe_disabled>$(_ 'Start'  )</button><!--
		--><button type="submit" name="stop_pppoe"  data-icon="stop"  $stopoe_disabled >$(_ 'Stop'   )</button><!--
	--></footer>
</form>
</section>
EOT
if [ "$(which pppssh 2>/dev/null)" ]; then
	[ -s /etc/ppp/pppssh ] && . /etc/ppp/pppssh
	ppp="$(sed '/pppd/!d;s/.*="\([^"]*\).*/\1/' /usr/bin/pppssh)"
	if [ "$(busybox ps x | grep "$ppp" | awk '/dbclient/{print $1}')" ]; then
		startssh_disabled='disabled'
	else
		stopssh_disabled='disabled'
	fi
	cat <<EOT
<a name="pppssh"></a>
<section>
	<header>
		<span data-icon="vpn">$(_ 'Virtual Private Network') -
		$(_ 'Manage private TCP/IP connections')</span>
	</header>
<form method="get">
	<input type="hidden" name="setpppssh" />
	<table>
	<tr>
		<td>$(_ 'Peer')</td>
		<td><input type="text" name="peer" size="50" value="${PEER:-user@elsewhere}" /></td>
	</tr>
	<tr>
		<td>$(_ 'SSH options')</td>
		<td><input type="text" name="ssharg" size="50" value="$SSHARG" /></td>
	</tr>
	<tr>
		<td>$(_ 'Password')</td>
		<td><input type="password" name="pass" size="50" title="Should be empty to use the SSH key; useful to send the SSH key only" /></td>
	</tr>
	<tr>
		<td>$(_ 'Local IP address')</td>
		<td><input type="text" name="localip" size="50" value="${LOCALIP:-192.168.254.1}" /></td>
	</tr>
	<tr>
		<td>$(_ 'Remote IP address')</td>
		<td><input type="text" name="remoteip" size="50" value="${REMOTEIP:-192.168.254.2}" /></td>
	</tr>
	<tr>
		<td>$(_ 'Local PPP options')</td>
		<td><input type="text" name="localpppopt" size="50" value="$LOCALPPP" /></td>
	</tr>
	<tr>
		<td>$(_ 'Remote PPP options')</td>
		<td><input type="text" name="remotepppopt" size="50" value="${REMOTEPPP:-proxyarp}" title="$(_ "You may need 'proxyarp' to use the new routes")" /></td>
	</tr>
	<tr>
		<td>$(_ 'Peer routes')</td>
		<td><input type="text" name="routes" size="50" value="${ROUTES:-192.168.10.0/24 192.168.20.0/28}" title="$(_ "Routes on peer network to import or 'default' to redirect the default route")"/></td>
	</tr>
	<tr>
		<td>$(_ 'UDP port')</td>
		<td><input type="text" name="udp" size="50" value="$UDP" title="$(_ "Optional UDP port for a real-time but unencrypted link")"/></td>
	</tr>
	</table>
	<footer><!--
		--><button type="submit" name="start_pppssh" data-icon="start" $startssh_disabled>$(_ 'Start'  )</button><!--
		--><button type="submit" name="stop_pppssh"  data-icon="stop"  $stopssh_disabled>$(_ 'Stop'   )</button><!--
		--><button type="submit" name="send_key"  data-icon="sync"  >$(_ 'Send SSH key'   )</button><!--
	--></footer>
</form>
</section>
EOT
fi

xhtml_footer
exit 0
