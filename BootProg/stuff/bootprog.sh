#!/bin/sh

[ ! -e "$1" ] && cat <<EOT && exit 2
Usage: [FAT=<FAT12|FAT16|FAT32|EXFAT>] $0 device [file]
Example: $0 /dev/fd0 STARTUP.BIN
EOT

xd="dd of=$1 bs=1 conv=notrunc"
while read c o b f; do
	[ "${FAT:-$(dd if="$1" bs=1 count=5 skip=$c)}" = "$f" ] || continue
	echo "Install $f bootsector on $1."
	for a in "$((o+b)) seek=$o count=$((512-o))" "$b count=11"; do
		sed '1,/^exit 1/d' $0 | unlzma | $xd skip=$a
	done
	[ "$2" ] && echo "Set boot file '$2'" && echo -n "$2" | case "$f" in
	E*)	sed 's| |.|;s| ||g' | cat - /dev/zero;;
	*)	tr a-z A-Z | sed 's|\.|       |;s|^\(.\{8\}\) *|\1|;s|$|   |'
	esac | $xd seek=499 count=11
	[ "$f" = "EXFAT" ] && dd if="$1" bs=512 count=11 | od -v -An -t u1 -w1 - | LANG=C awk '
BEGIN { a=0;i=-1;m=0xFFFFFFFE }
{ if (++i!=106 && i!=107 && i!=112) a=or(and(lshift(a,31),m),and(rshift(a,1),m/2))+$1 }
END { b=a/256;c=b/256; for (i=0;i<128;i++) printf "%c%c%c%c",a%256,b%256,c%256,(c/256)%256 }' | $xd seek=5632
	exit 0
done 2>/dev/null <<EOT
54	62	0	FAT12
54	62	0	FAT16
82	90	512	FAT32
3	113	1024	EXFAT
EOT
exit 1
