#!/bin/sh

services="/ /reset /reboot /ssh"

mkexe()
{
exe=$0
while true; do
	cd $(dirname $exe)
	exe=$(basename $exe)
	[ -L $exe ] || break
	exe=$(readlink $exe)
done
echo $(pwd)/$exe
}
exe=$(mkexe)

services_arg()
{
for i in $services ; do
	echo -n "-s '$i:root:root:/tmp:LINES=25 /bin/sh -c \"$exe service $i "
	echo -n "\${peer} \${url} \${columns} \${lines}\"' "
done
}

launch_ssh()
{
	# Get SSH server
	server=""
	echo -n "SSH server: "
	read -t 300 server || exit 1
	[ -n "$server" ] || exit 1

	# Allow non default SSH port with format server:port
	sshport=""
	case "$server" in
	*:*)	sshport="-p ${server#*:}"
		server=${server%:*};;
	esac

	# heading ! in server name means open remote ssh port with a knock sequence
	if [ -x /usr/bin/knock ]; then
		case "$server" in
		!*)	server=${server#*!}
			echo -n "Knock sequence (port[:proto]...): "
			read -t 30 sequence && knock ${server#*@} $sequence
		esac
	fi

	# Get SSH user if missing
	case "$server" in
	*@*)	;;
	*)	echo -n "$server login: "
		read -t 30 user || exit 1
		server="$user@$server";;
	esac

	# Launch OpenSSH or Dropbear
	sshargs="-oPreferredAuthentications=keyboard-interactive,password -oNoHostAuthenticationForLocalhost=yes -oLogLevel=FATAL -F/dev/null";
	[ -L /usr/bin/ssh ] && sshargs=""
	exec ssh $sshport $sshargs $server
}

auth()
{
	while read host md5 ; do
		[ "${host#*.}" == "${1#*.}" ] && break
	done < $(dirname $exe)/shellinabox.secrets
	echo -n "$host password: "
	read -s -t 30 password || exit 1
	[ "$(echo $password | md5sum)" == "$md5  -" ] || exit 1
	echo ""
}

pidfile=/var/run/shellinaboxd.pid
case "$1" in
service)
	host=$(echo $4 | sed 's/.*\/\/\(.*\):.*/\1/')
	tty=$(awk "/$host/ { print \$2 }" /etc/inittab)
	vm=$(awk "/$host/ { print \$3 }" /etc/inittab)
	[ -n "$vm" ] || exit 1
	case "$2" in
	/)
		auth $host
		exec /usr/bin/conspy ${tty#tty} ;;
	/reboot)
		auth $host
		echo -n "Sure to reboot $host now (YES or NO) ?"
		read -t 30 answer || exit 1
		case "$answer" in
		YES*) ;;
		*) exit 1;;
		esac
		exec /bin/kill $(ps ww | grep $vm | awk '/lguest/ { printf "%s ",$1 }') ;;
	/ssh)
		auth $host
		launch_ssh ;;
	esac
	;;
start)
	dir=$(dirname $exe)
	eval shellinaboxd --background=$pidfile --cert=/boot/cert $(services_arg)
	;;
stop)
	[ -s $pidfile ] && kill $(cat $pidfile)
	;;
esac
