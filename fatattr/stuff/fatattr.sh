#!/bin/sh

ATTRS=.fatattr

cdfat() {
	fatattr $1 > /dev/null && cd $1
}

case "${1/--/-}" in
-s*)	find ${3:-.} -exec fatattr {} \; > ${2:-$ATTRS} ;;
-r*)	while read line; do
		fatattr	$(echo ${line:0:9} | sed 's/[^ ]/+\0 /g') "$3${line:9}"
	done < ${2:-$ATTRS} ;;
-c*)	cdfat ${2:-.} && $0 -s && find . | cpio -o -H newc ;;
-[xe]*)	cdfat ${2:-.} && cpio -idmu && $0 -r && rm -f $ATTRS ;;
*)	cat 1>&2 <<EOT
Usage:	$0 [--save|--restore] [datafile] [root]
	$0 [--create-cpio|--extract-cpio] [root]
EOT
esac

