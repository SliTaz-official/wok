#!/bin/sh
#
# /etc/rc.d/laptop-mode: start/stop laptop-mode
#

case $1 in
start)
        [ ! -d /var/run/laptop-mode-tools ] && install -d /var/run/laptop-mode-tools
        touch /var/run/laptop-mode-tools/enabled
        /usr/sbin/laptop_mode auto init >/dev/null 2>&1
        ;;
stop)
        rm -f /var/run/laptop-mode-tools/enabled
        ;;
restart)
        /usr/sbin/laptop_mode auto init force >/dev/null 2>&1
        ;;
status)
        /usr/sbin/laptop_mode status
        ;;
*)
        echo "usage: $0 [start|stop|restart|status]"
        ;;
esac

# End of file
