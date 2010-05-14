#!/bin/sh
#
# This script creates a floppy image set from a linux bzImage and can merge
# a cmdline and/or one or more initramfs.
# The total size can not exceed 15M because INT 15H function 87H limitations.
#
# (C) 2009 Pascal Bellard - GNU General Public License v3.

usage()
{
cat <<EOT
Usage: $0 bzImage [--prefix image_prefix] [--cmdline 'args']
       [--format 1440|1680|1720|2880 ] [--initrd initrdfile]...

Example:
$0 /boot/vmlinuz-2.6.30.6 --cmdline 'rw lang=fr_FR kmap=fr-latin1 laptop autologin' --initrd /boot/rootfs.gz --initrd ./myconfig.gz
EOT
exit 1
}

KERNEL=""
INITRD=""
CMDLINE=""
PREFIX="floppy"
FORMAT="1440"
while [ -n "$1" ]; do
	case "$1" in
	--cmdline) CMDLINE="$2"; shift;;
	--initrd)  INITRD="$INITRD $2"; shift;;
	--prefix)  PREFIX="$2"; shift;;
	--format)  FORMAT="$2"; shift;;
	*) KERNEL="$1";;
	esac
	shift
done
[ -n "$KERNEL" -a -f "$KERNEL" ] || usage

# write a 32 bits data
# usage: storelong offset data32 file
storelong()
{
	echo $2 | awk '{ printf "%c%c%c%c",$1%256,($1/256)%256,($1/256/256)%256,
					   ($1/256/256/256)%256 }' | \
	dd bs=1 conv=notrunc of=$3 seek=$(( $1 )) 2> /dev/null
}

# read a 32 bits data
# usage: getlong offset file
getlong()
{
	dd if=$2 bs=1 skip=$(( $1 )) count=4 2> /dev/null | \
		hexdump -e '"" 1/4 "%d" "\n"'
}

floppyset()
{
	# bzImage offsets
	SetupSzOfs=497
	SyssizeOfs=500
	CodeAdrOfs=0x214
	RamfsAdrOfs=0x218
	RamfsLenOfs=0x21C
	ArgPtrOfs=0x228

	# boot+setup address
	SetupBase=0x90000

	stacktop=0x9E00

	bs=/tmp/bs$$

	# Get and patch boot sector
	# See http://hg.slitaz.org/wok/raw-file/tip/linux/stuff/linux-header-2.6.30.6.u
	dd if=$KERNEL bs=512 count=1 of=$bs 2> /dev/null
	uudecode <<EOT | dd of=$bs conv=notrunc 2> /dev/null
begin-base64 644 -
/L+6nWgAkAcGF4n8McC5HQDzq1sfD6mg8X1ABlfFd3ixBvOlZWaPR3gGH8ZF
+D/6l1hB6DQBvgACA3QO6HYBWwseKAJ0LFNH6AoBXuhmAbAgzRCwCM0QTuhl
ATwIdAOIBK05NigCdPDoPgE8CnXgiHz+ieb/TBD/TBi/9AGBTRz/gMdFMACc
sBCxBUi0k4lEHLABiUQUmGaY0+BIZgMFZtPoaAAQB7+AACn4nHMCAccx21BW
6J4AXrkAgLSH/kQczRVYnXfcoRoCvxwCsQk4RBxyuJPNE+oAACCQsEYoyL7b
AejSAF3rI4D5E3IEOMF3a4D+AnIEOOZ3bGCB/QAGdCoGUlFTlrQCULEGtQTB
xQSwDyHoBJAnFEAn6IwA/s117LAgzRDitOiWAJjNE2FSUCjIdwKwAZg5+HIC
ifhQtALNE5VeWFpyoJVBjuGAxwJPdFFOdfSM4ZU4wXVFiMj+xrEBOOZ1O4j0
/sW2AID9UHIwOi7wAXIqtQBgvt4B/kQMU+gxAFvoOAB1FlKYzRO4AQLNE1rQ
1Dpk/nXqRgjkdeVh64sWB7AxLAO0DrsHAM0QPA1088OwDejv/6wIwHX4w79s
BLFbZQINuA0BZToNdArNFnT0mM0Wju9Hw1g6AEluc2VydCBkaXNrIDEuBw0A
AA==
====
EOT

	# Get setup
	setupsz=$(getlong $SetupSzOfs $bs)
	setupszb=$(( $setupsz & 255 ))
	dd if=$KERNEL bs=512 skip=1 count=$setupszb 2> /dev/null >> $bs

	# Store cmdline after setup
	if [ -n "$CMDLINE" ]; then
		echo -n "$CMDLINE" | dd bs=512 count=1 conv=sync 2> /dev/null >> $bs
		storelong ArgPtrOfs $(( $SetupBase + $stacktop )) $bs
	fi

	# Compute initramfs size
	initrdlen=0
	padding=0
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		initrdlen=$(( $initrdlen + $padding ))
		padding=$(stat -c %s $i)
		initrdlen=$(( $initrdlen + $padding ))
		padding=$(( 4096 - ($padding & 4095) ))
		[ $padding -eq 4096 ] && padding=0
	done
	Ksize=$(( $(getlong $SyssizeOfs $bs)*16 ))
	Kpad=$(( (($Ksize+4095)/4096)*4096 - Ksize ))
	if [ $initrdlen -ne 0 ]; then
		Kbase=$(getlong $CodeAdrOfs $bs)
		storelong $RamfsAdrOfs \
			$(( (0x1000000 - $initrdlen) & 0xFFFF0000 )) $bs
		storelong $RamfsLenOfs $initrdlen $bs
	fi

	# Output boot sector + setup + cmdline
	dd if=$bs 2> /dev/null

	# Output kernel code
	dd if=$KERNEL bs=512 skip=$(( $setupszb + 1 )) 2> /dev/null

	# Pad to next sector
	Kpad=$(( 512 - ($(stat -c %s $KERNEL) & 511) ))
	[ $Kpad -eq 512 ] || dd if=/dev/zero bs=1 count=$Kpad 2> /dev/null

	# Output initramfs
	padding=0
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		[ $padding -ne 0 ] && dd if=/dev/zero bs=1 count=$padding
		dd if=$i 2> /dev/null
		padding=$(( 4096 - ($(stat -c %s $i) & 4095) ))
		[ $padding -eq 4096 ] && padding=0
	done

	# Cleanup
	rm -f $bs
}

floppyset | split -b ${FORMAT}k /dev/stdin floppy$$
i=1
ls floppy$$* | while read file ; do
	output=$PREFIX.$(printf "%03d" $i)
	cat $file /dev/zero | dd bs=1k count=$FORMAT conv=sync of=$output 2> /dev/null
	echo $output
	rm -f $file
	i=$(( $i + 1 ))
done
