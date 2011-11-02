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
       [--rdev device] [--video mode] [--flags rootflags] [--tracks cnt]
       [--format 1440|1680|1920|2880 ] [--initrd initrdfile]...

Default values: --format 1440 --tracks 80 --prefix floppy.

Or:	cat fd0*.img | $0 --extract

Create the kernel, cmdline and rootfs files from a floppy set

Example:
$0 /boot/vmlinuz-2.6.30.6 --rdev /dev/ram0 --video -3 \
--cmdline 'rw lang=fr_FR kmap=fr-latin1 laptop autologin' \
--initrd /boot/rootfs.gz --initrd ./myconfig.gz
EOT
exit 1
}

ddq()
{
	dd $@ 2> /dev/null
}

dbg()
{
	[ -n "$DEBUG" ] && echo "$@" 1>&2
}

# write a 32 bits data
# usage: put offset data32 file [bytes]
put()
{
	n=$2; for i in $(seq 1 ${4:-4}); do
		printf '\\\\x%02X' $(($n & 255))
		n=$(($n >> 8))
	done | xargs echo -en | ddq bs=1 conv=notrunc of=$3 seek=$1
	[ -n "$DEBUG" ] && printf "put$4(%04X) = %X\n" $1 $2 1>&2
}

# read a 32 bits data
# usage: get offset file [bytes]
get()
{
	ddq if=$2 bs=1 skip=$(($1)) count=${3:-4} | hexdump -e '"" 1/4 "%d"'
}

SetupSzOfs=0x1F1
SyssizeOfs=0x1F4
RamfsLenOfs=0x21C
ArgPtrOfs=0x228

floppyset()
{
	# bzImage offsets
	CylinderCount=0x1F0
	FlagsOfs=0x1F2
	VideoModeOfs=0x1FA
	RootDevOfs=0x1FC
	CodeAdrOfs=0x214
	RamfsAdrOfs=0x218

	# boot+setup address
	SetupBase=0x90000

	stacktop=0x9E00

	bs=/tmp/bs$$

	# Get and patch boot sector
	# See  http://hg.slitaz.org/wok/raw-file/711d076b277c/linux/stuff/linux-header-2.6.34.u
	ddq if=$KERNEL bs=512 count=1 of=$bs
	uudecode <<EOT | ddq of=$bs conv=notrunc
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
	setupsz=$(get $SetupSzOfs $bs 1)
	ddq if=$KERNEL bs=512 skip=1 count=$setupsz >> $bs

	if [ -n "$TRACKS" ]; then
		dbg -n "--tracks "
		put $CylinderCount $TRACKS $bs 1
	fi
	if [ -n "$FLAGS" ]; then
		dbg -n "--flags "
		put $FlagsOfs $FLAGS $bs 2
	fi
	if [ -n "$VIDEO" ]; then
		dbg -n "--video "
		put $VideoModeOfs $VIDEO $bs 2
	fi
	if [ -n "$RDEV" ]; then
		dbg -n "--rdev "
		n=$(stat -c '0x%02t%02T' $RDEV 2> /dev/null)
		[ -n "$n" ] || n=$RDEV
		put $RootDevOfs $n $bs 2
	fi

	# Store cmdline after setup
	if [ -n "$CMDLINE" ]; then
		dbg -n "--cmdline '$CMDLINE' "
		echo -n "$CMDLINE" | ddq bs=512 count=1 conv=sync >> $bs
		put $ArgPtrOfs $(( $SetupBase + $stacktop )) $bs
	fi

	# Compute initramfs size
	initrdlen=0
	padding=0
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		dbg "--initrd $i "
		initrdlen=$(( $initrdlen + $padding ))
		padding=$(stat -c %s $i)
		initrdlen=$(( $initrdlen + $padding ))
		padding=$(( 4096 - ($padding & 4095) ))
		[ $padding -eq 4096 ] && padding=0
	done
	Ksize=$(( $(get $SyssizeOfs $bs)*16 ))
	Kpad=$(( (($Ksize+4095)/4096)*4096 - Ksize ))
	if [ $initrdlen -ne 0 ]; then
		dbg "initrdlen = $initrdlen "
		Kbase=$(get $CodeAdrOfs $bs)
		put $RamfsAdrOfs \
			$(( (0x1000000 - $initrdlen) & 0xFFFF0000 )) $bs
		put $RamfsLenOfs $(( ($initrdlen + 3) & -4 )) $bs
	fi

	# Output boot sector + setup + cmdline
	ddq if=$bs

	# Output kernel code
	ddq if=$KERNEL bs=512 skip=$(( $setupsz + 1 ))

	# Pad to next sector
	Kpad=$(( 512 - ($(stat -c %s $KERNEL) & 511) ))
	[ $Kpad -eq 512 ] || ddq if=/dev/zero bs=1 count=$Kpad

	# Output initramfs
	padding=0
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		[ $padding -ne 0 ] && ddq if=/dev/zero bs=1 count=$padding
		ddq if=$i
		padding=$(( 4 - ($(stat -c %s $i) & 3) ))
		[ $padding -eq 4 ] && padding=0
	done

	# Cleanup
	rm -f $bs
}

KERNEL=""
INITRD=""
CMDLINE=""
PREFIX="floppy."
FORMAT="1440"
RDEV=""
VIDEO=""
FLAGS=""
TRACKS=""
DEBUG=""
while [ -n "$1" ]; do
	case "${1/--/-}" in
	-c*)	CMDLINE="$2"; shift;;
	-i*)	INITRD="$INITRD $2"; shift;;
	-p*)	PREFIX="$2"; shift;;
	-fl*)	FLAGS="$2"; shift;;	# 1 read-only, 0 read-write
	-f*)	FORMAT="$2"; shift;;
	-r*)	RDEV="$2"; shift;;	# /dev/???
	-v*)	VIDEO="$2"; shift;;	# -3 .. n
	-t*)	TRACKS="$2"; shift;; 	# likely 81 .. 84
	-d*)	DEBUG="1";;
	-e*)	ddq bs=512 count=2 > kernel
		setupsz=$(get $SetupSzOfs kernel 1)
		ddq bs=512 count=$(($setupsz - 1)) >> kernel
		[ $(get $ArgPtrOfs kernel) -ne 0 ] && 
			ddq bs=512 count=1 | strings > cmdline
		syssz=$(get $SyssizeOfs kernel)
		ddq bs=512 count=$(( ($syssz + 31) / 32 )) >> kernel
		ddq bs=16 seek=$(($syssz + 32 + $setupsz*32)) count=0 of=kernel
		ramsz=$(get $RamfsLenOfs kernel)
		ddq bs=512 count=$((($ramsz + 511) / 512)) of=rootfs
		ddq bs=1 seek=$ramsz count=0 of=rootfs
		exit ;;
	*) KERNEL="$1";;
	esac
	shift
done
[ -n "$KERNEL" -a -f "$KERNEL" ] || usage
[ -n "$TRACKS" ] && [ $(( $FORMAT % $TRACKS )) -ne 0 ] &&
	echo "Invalid track count for format $FORMAT." && usage

if [ "$FORMAT" == "0" ]; then # unsplitted
	floppyset > $PREFIX
	exit
fi
floppyset | split -b ${FORMAT}k /dev/stdin floppy$$
i=1
ls floppy$$* | while read file ; do
	output=$PREFIX$(printf "%03d" $i)
	cat $file /dev/zero | ddq bs=1k count=$FORMAT conv=sync of=$output
	echo $output
	rm -f $file
	i=$(( $i + 1 ))
done
