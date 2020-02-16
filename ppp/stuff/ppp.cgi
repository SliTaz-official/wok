#!/bin/sh
#
# Network/PPP configuration CGI interface
#
# Copyright (C) 2015 SliTaz GNU/Linux - BSD License
#

# Common functions from libtazpanel
. lib/libtazpanel
get_config


set_secrets()
{
	grep -qs "^$1	" /etc/ppp/pap-secrets ||
	echo "$1	*	$2" >> /etc/ppp/pap-secrets
	grep -qs "^$1	" /etc/ppp/chap-secrets ||
	echo "$1	*	$2" >> /etc/ppp/chap-secrets
}


create_gsm_conf()
{
	local provider="${1:-myGSMprovider}"
	set_secrets "$provider" "$provider"
	[ -s /etc/ppp/scripts/gsm.chat ] ||
	cat > /etc/ppp/scripts/gsm.chat <<EOT
ABORT 'BUSY'
ABORT 'NO CARRIER'
ABORT 'VOICE'
ABORT 'NO DIALTONE'
ABORT 'NO DIAL TONE'
ABORT 'NO ANSWER'
ABORT 'DELAYED'
REPORT CONNECT
TIMEOUT 6
'' 'ATQ0'
'OK-AT-OK' 'ATZ'
TIMEOUT 3
'OK' 'ATI'
'OK' 'ATZ'
'OK' 'ATQ0 V1 E1 S0=0 &C1 &D2 +FCLASS=0'
'OK' 'AT+CGDCONT=1,"IP","$provider"'
'OK' 'ATDT*99#'
TIMEOUT 30
CONNECT ''
EOT
	[ -s /etc/ppp/options-gsm ] ||
	cat > /etc/ppp/options-gsm << EOT
rfcomm0
460800
lock
crtscts
modem
passive
novj
defaultroute
noipdefault
usepeerdns
noauth
hide-password
persist
holdoff 10
maxfail 0
debug
EOT
	[ -s /etc/ppp/peers/gsm ] ||
	cat > /etc/ppp/peers/gsm << EOT
file /etc/ppp/options-gsm
user "$provider"
password "$provider"
connect "/usr/sbin/chat -v -t15 -f /etc/ppp/scripts/gsm.chat"
EOT
}


phone_names()
{
	rfcomm | awk '/connected/{print $2}' | while read mac; do
		grep -A2 $mac /etc/bluetooth/rfcomm.conf | \
			sed '/comment/!d;s/.* "\(.*\) modem";/ \1/'
	done
}


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
*\ start_pstn\ *)
	if [ "$(GET user)" ]; then
		set_secrets "$(GET user)" "$(GET pass)"
		sed -i 's/^name /d' /etc/ppp/options
		echo "name $(GET user)" >> /etc/ppp/options
		/etc/ppp/scripts/ppp-off
		/etc/ppp/scripts/ppp-on &
	fi ;;
*\ start_gsm\ *)
	if [ "$(GET gsmprovider)" ]; then
		[ -n "$(pidof dbus-daemon)" ] || /etc/init.d/dbus start
		[ -n "$(pidof bluetoothd)" ] || bluetoothd
		grep -qs btusb /proc/modules || !modprobe btusb || sleep 1
		[ -n "$(which bluetoothctl)" ] && bluetoothctl power on
		hcitool scan | grep : | while read dev name; do
			set -- $dev "$name" $(sdptool browse $dev | awk '
/Service Class ID List/	{n=0}
/Dialup Networking/	{n=1}
/RFCOMM/		{n++}
/Channel/		{if (n==2) { print $2; exit } }')
			[ -n "$3" ] || continue
			grep -qs $1 /etc/bluetooth/rfcomm.conf ||
			cat >> /etc/bluetooth/rfcomm.conf <<EOT
rfcomm0 {
	bind yes;
	device $1;
	channel $3;
	comment "$2 modem";
}
EOT
			rfcomm bind all || rfcomm bind 0 $1 $3
			break
		done
		create_gsm_conf "$(GET gsmprovider)"
		[ -n "$(GET gsmprovider)" ] &&
		sed -i "s|\"IP\",\".*\"|\"IP\",\"$(GET gsmprovider)\"|" \
			/etc/ppp/scripts/gsm.chat &&
		sed -i "s|myGSMprovider|$(GET gsmprovider)|g" \
			/etc/ppp/chap-secrets /etc/ppp/pap-secrets
		pppd call gsm
		host=$(hcitool dev | sed '/hci0/!d;s/.*hci0\t//')
		pin=$(GET gsmpin)
		hcitool scan | grep "$1" | while read adrs name ; do
			echo ${pin:-0000} | bluez-simple-agent $host $adrs
		done
	fi ;;
*\ stop_pstn\ *|*\ stop_gsm\ *)
	/etc/ppp/scripts/ppp-off ;;
*\ start_pppoe\ *)
	if [ "$(GET user)" ]; then
		set_secrets "$(GET user)" "$(GET pass)"
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
	fi ;;
*\ stop_pppoe\ *)
	killall pppd ;;
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
		pppssh	"$(GET ssharg) $(GET peer)" \
			"$(GET localip):$(GET remoteip) $(GET localpppopt)" \
			"$(GET remotepppopt)" "$(GET routes)" \
			"$(GET udp)" > /dev/null &
		sleep 1
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
		<a data-icon="web" href="https://en.wikipedia.org/wiki/Hayes_command_set" target="_blank" rel="noopener">$(_ 'Hayes codes')</a><p>
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
EOT
[ "$(which sdptool 2>/dev/null)" ] && create_gsm_conf && cat <<EOT
		<a data-icon="conf" href="index.cgi?file=/etc/bluetooth/rfcomm.conf" target="_blank" rel="noopener">$(_ 'GSM device')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/peers/gsm" target="_blank" rel="noopener">$(_ 'PPP GSM script')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/scripts/gsm.chat" target="_blank" rel="noopener">$(_ 'PPP GSM chat')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/options-gsm" target="_blank" rel="noopener">$(_ 'PPP GSM options')</a><p>
EOT
cat << EOT
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/scripts/ppp-on" target="_blank" rel="noopener">$(_ 'PPP PSTN script')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/scripts/ppp-on-dialer" target="_blank" rel="noopener">$(_ 'PPP PSTN chat')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/options" target="_blank" rel="noopener">$(_ 'PPP PSTN options')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/chap-secrets" target="_blank" rel="noopener">$(_ 'chap users')</a><p>
		<a data-icon="conf" href="index.cgi?file=/etc/ppp/pap-secrets" target="_blank" rel="noopener">$(_ 'pap users')</a><p>
EOT
for i in /etc/ppp/peers/* ; do
	[ -s "$i" ] && [ "$i" != "/etc/ppp/peers/gsm" ] && cat << EOT
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
if [ "$(busybox ps x | grep "pppd" | awk '/gsm/{print $1}')" ]; then
	startgsm_disabled='disabled'
else
	stopgsm_disabled='disabled'
fi
head="	<footer>
	</footer>
</section>
<section>
	<header>
		$(_ 'Install extra')
	</header>"
while read file pkg name ; do
	[ -z "$(which $file 2>/dev/null)" ] && echo $head && head="" &&
	echo "	<a href='pkgs.cgi?do=Install&amp;pkg=$pkg'>$name</a>"
done <<EOT
sdptool	bluez		GSM / Bluetooth
pppssh	dropbear	SSH / VPN
EOT
#pptp	pptpclient	PPTP client
#pptpd	poptop		PPTP server
cat << EOT
	<footer>
	</footer>
</section>
</div>

EOT
if [ "$(which sdptool 2>/dev/null)" ]; then
	cat <<EOT
<a name="pppgsm"></a>
<section>
	<header>
		<span data-icon="modem">$(_ 'GSM modem') -
		$(_ 'Manage Bluetooth GSM Internet connections')</span>
	</header>
<form method="get">
	<input type="hidden" name="setpppgsm" />
	<table>
	<tr>
		<td>$(_ 'GSM provider')</td>
		<td><input type="text" name="gsmprovider" size="40" value="$(sed \
			'/AT+CGDCONT/!d;s|.*IP","\(.*\)".|\1|' \
			/etc/ppp/scripts/gsm.chat 2> /dev/null)" /></td>
	</tr>
	<tr>
		<td>$(_ 'Bluetooth PIN')</td>
		<td><input type="text" name="gsmpin" size="40" value="0000" /></td>
	</tr>
	</table>
	<footer><!--
		--><button type="submit" name="start_gsm" data-icon="start" $startgsm_disabled>$(_ 'Start'  )</button><!--
		--><button type="submit" name="stop_gsm"  data-icon="stop"  $stopgsm_disabled>$(_ 'Stop'   )</button><!--
	-->$(phone_names)</footer>
</form>
</section>
EOT
fi
cat << EOT
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
		<td><input type="text" name="localpppopt" size="50" value="${LOCALPPP:-usepeerdns}" /></td>
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
		<td><input type="text" name="udp" size="50" value="$UDP" title="$(_ "Optional UDP port for real-time (with a very reliable link only)")"/></td>
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
