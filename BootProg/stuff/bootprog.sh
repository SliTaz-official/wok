#!/bin/sh

[ ! -e "$1" ] && cat <<EOT && exit 2
Usage: [FAT=<FAT12|FAT16|FAT32|EXFAT>] $0 device [boot name entry] [boot.bin]
Example: $0 /dev/fd0 STARTUP.BIN
EOT

while read chk ofs fat bin name; do
	[ $FAT -eq $fat ] || [ "$(dd if="$1" bs=1 count=8 skip=$chk)" = "$fat   " ] || continue
	echo "Install $fat bootsector on $1."
	for arg in "skip=$(($ofs+8)) seek=$(($ofs+8))" "count=11" ; do
		if [ "$3" ]; then
			cat "$3"
		else
			sed '1,/^exit 1/d' $0 | tar xzOf - boot$bin.bin
		fi | dd of="$1" bs=1 conv=notrunc $arg
	done
	[ "$2" ] && echo "Set bootfile '$2'" && echo -en "$name" | \
		dd of="$1" bs=1 conv=notrunc seek=499 count=11
	case "$fat" in
	EXFAT) dd if="$1" bs=512 count=11 | od -v -An -t u1 -w1 - | awk '
BEGIN { chk=0; i=-1 }
{
  i++
  if (i == 106 || i == 107 || i == 112) next
  chk = or(lshift(chk,31),rshift(chk,1)) + $1
}
END { a=chk%256; b=(chk/256)%256; c=(chk/256/256)%256; d=chk/256/256/256
  for (i=0;i<128;i++) printf "echo -en \"\\x%02X\\x%02X\\x%02X\\x%02X\"\n",a,b,c,d
} ' | sh | dd bs=512 of="$1" seek=11
	esac
	exit 0
done 2> /dev/null <<EOT
54	54	FAT12	16	$(A="${2/./       }";echo "${A:0:8}${A##* }          " | tr '[a-z]' '[A-Z]' | sed 's| |\\\\x20|g')
54	54	FAT16	16	$(A="${2/./       }";echo "${A:0:8}${A##* }          " | tr '[a-z]' '[A-Z]' | sed 's| |\\\\x20|g')
82	82	FAT32	32	$(A="${2/./       }";echo "${A:0:8}${A##* }          " | tr '[a-z]' '[A-Z]' | sed 's| |\\\\x20|g')
3	105	EXFAT	ex	$(echo "$2" | sed 's| |.|;s| ||g')\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0\\\\0
EOT
exit 1
