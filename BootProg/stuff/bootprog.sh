#!/bin/sh

[ ! -e "$1" ] && cat<<S && exit 2
Usage: [FAT=<FAT12|FAT16|FAT32|EXFAT>] $0 device [file]
Example: $0 /dev/fd0 STARTUP.BIN
S
r="dd if=$1 count"
w="dd of=$1 bs=1 conv=notrunc seek"
while read c o b f
do	[ "${FAT:-$($r=5 bs=1 skip=$c)}" = "$f" ] || continue
	echo "Install $f bootsector on $1."
	for a in "$o skip=$((o+b)) count=$((512-o))" "0 skip=$b count=11"
	do sed '1,/^exit/d' $0 | unlzma | $w=$a; done
	echo -n $f | $w=$c
	[ "$2" ] && echo "Set boot file '$2'" && echo -n "$2" | case "$f" in
	E*)	sed 's| |.|;s| ||g' | cat - /dev/zero;;
	*)	tr a-z A-Z | sed 's|\.|       |;s|^\(.\{8\}\) *|\1|;s|$|   |'
	esac | $w=499 count=11
	case "$f" in
	*32)	$w=1536 if=$1 count=512;;
	E*)	$r=11 bs=1b | od -vAn -tu1 -w1 - | LANG=C awk 'BEGIN { a=0;i=-1;m=0xFFFFFFFE }
{ if (++i!=106 && i!=107 && i!=112) a=or(and(lshift(a,31),m),and(rshift(a,1),m/2))+$1 }
END { b=a/256;c=b/256; for (;i>0;i-=44) printf "%c%c%c%c",a%256,b%256,c%256,(c/256)%256 }' | $w=5632
	esac
	exit 0
done<<S 2>/dev/null
54	59	0	FAT12
54	59	0	FAT16
82	87	512	FAT32
3	113	1024	EXFAT
S
exit 1
