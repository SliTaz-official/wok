#!/bin/sh

if [ ! -e "$1" ]; then
	echo "Usage: $0 fd_image [hd_image]"
else
	clear
	stty cbreak raw -echo min 0
	${TINY8086:-/usr/bin/8086tiny} /usr/share/8086tiny/bios "$@"
	stty cooked echo
fi
