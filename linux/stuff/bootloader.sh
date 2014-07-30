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
Usage: $0 bzImage [--prefix image_prefix] [--info file ]
       [--format 1200|1440|1680|1920|2880|... ] [--mem mb]
       [--rdev device] [--video mode] [--flags rootflags] [--tracks cnt]
       [--cmdline 'args'] [--dont-edit-cmdline] [--no-syssize-fix]
       [--address-initrd address] [--initrd initrdfile]...

Default values: --format 1440 --tracks 80 --rdev /dev/fd0 --prefix floppy. --mem 16

Example:
$0 /boot/bzImage --rdev /dev/ram0 --video -3 --cmdline 'rw lang=fr_FR kmap=fr-latin1 laptop autologin' --initrd /boot/rootfs.gz --initrd ./myconfig.gz
EOT
exit 1
}

KERNEL=""
INITRD=""
ADRSRD=""
CMDLINE=""
PREFIX="floppy."
FORMAT="1440"
RDEV=""
VIDEO=""
FLAGS=""
TRACKS="80"
MEM="16"
NOEDIT=""
NOSYSSIZEFIX=""
INFOFILE=""
DEBUG=""
while [ -n "$1" ]; do
	case "${1/--/-}" in
	-c*) CMDLINE="$2"; shift;;
	-inf*) INFOFILE="$2"; shift;;
	-i*) INITRD="$INITRD $2"; shift;;
	-a*) ADRSRD="$2"; shift;;
	-h*) HEAP="$2"; shift;;
	-l*) LOADERTYPE="$2"; shift;;
	-p*) PREFIX="$2"; shift;;
	-fl*)FLAGS="$2"; shift;;	# 1 read-only, 0 read-write
	-f*) FORMAT="$2"; shift;;
	-m*) MEM="$(echo $2 | sed 's/[^0-9]//g')"; shift;;
	-r*) RDEV="$2"; shift;;
	-v*) VIDEO="$2"; shift;;	# -3 .. n
	-t*) TRACKS="$2"; shift;; # likely 81 .. 84
	-n*) NOSYSSIZEFIX="1";;
	-debug) DEBUG="1";;
	-d*) NOEDIT="1";;
	*) KERNEL="$1";;
	esac
	shift
done
[ -n "$KERNEL" -a -f "$KERNEL" ] || usage
while [ -L "$KERNEL" ]; do KERNEL="$(readlink "$KERNEL")"; done
if [ $(( $FORMAT % $TRACKS )) -ne 0 ]; then
	echo "Invalid track count for format $FORMAT."
	usage
fi
[ 0$MEM -lt 4  ] && MEM=4
[ $MEM -gt 16 ] && MEM=16

ddq() { dd $@ 2> /dev/null; }

patch()
{
	echo -en $(echo ":$2" | sed 's/:/\\x/g') | \
		ddq bs=1 conv=notrunc of=$3 seek=$((0x$1))
	[ -n "$DEBUG" ] && echo "patch $1 $2		$4" 1>&2
}

# usage: store bits offset data file
store()
{
	n=$3; for i in $(seq 8 8 $1); do
		printf '\\\\x%02X' $(($n & 255))
		n=$(($n >> 8))
	done | xargs echo -en | ddq bs=1 conv=notrunc of=$4 seek=$(($2))
	[ -n "$DEBUG" ] && printf "store%d(%03X) = %0$(($1/4))X	%s\n" $1 $2 $3 "$5" 1>&2
}

# usage: getlong offset file [bytes]
getlong()
{
	echo $(od -j $1 -N ${3:-4} -t u${3:-4} -An $2)
}

error()
{
	echo $@ 1>&2
	rm -f $bs
	exit 1
}

floppyset()
{
	# bzImage offsets
	SetupSzOfs=497
	FlagsOfs=498
	VideoModeOfs=506
	RootDevOfs=508
	Magic=0x202
	RamfsAdrOfs=0x218
	RamfsLenOfs=0x21C

	# boot+setup address
	SetupBase=0x90000

	bs=/tmp/bs$$

	# Get and patch boot sector
	# See http://hg.slitaz.org/wok/raw-file/66e38bd6a132/linux/stuff/linux-header.u
	[ -n "$DEBUG" ] && echo "Read bootsector..." 1>&2
	ddq if=$KERNEL bs=512 count=1 of=$bs

	[ $(getlong 0x1FE $bs 2) -eq 43605 ] || error "Not bootable"
	
	uudecode <<EOT | ddq of=$bs conv=notrunc
begin-base64 644 -
/L+4nWgAkBeJ/BYHMcC5HgDzq1sfD6Gg8X1AxXd4BlexBvOlFh9kZo9HeMZF
+D/6l1hB6DwBvgACgUwQIIDGRCWbA3QO6GoBWwseKAJ0LFNH6AYBXuhaAbAg
zRCwCM0QTuhZATwIdAOIBK05NigCdPDoMgE8CnXgiHz+W4nm/0gQxkAVk4Dz
CHX0u/QBoRUCsQVmix9mS2bT60NoAAgHv4AAiXwTiUQbAfjR7yn7nHMCAd9Q
V1ZTMdvongBbXlmGzbSHFgfNFVidd9ChGQK7HAKxCTlEG3K6l80T6gAAIJCw
RijIvtgB6MoAXesjgPkTcgQ4wXdrgP4CcgQ45ndsYIH9AAZ0KgZSUVOWtAJQ
sQa1BMHFBLAPIegEkCcUQCfohAD+zXXssCDNEOK06I4AmM0TYVJQKMh3ArAB
mDn4cgKJ+FC0As0TlV5YWnKglUGO6YDHAk90S0519IzplTjBdT+IyP7GsQE4
5nU1iPT+xYD9ULYAdSq1AGC+2wH+RAxT6C8AW+g2AHUWUpjNE7gBAs0TWtDU
OmT+depGCOR15WHrkbAxLAO0DrsHAM0QPA1088OwDejv/6wIwHX4w79sBLFb
ZAINuA0BZDoNdArNFnT0mM0WjudHw1g6AEluc2VydCBkaXNrIDEHDQA=
====
EOT
	# Get setup
	setupsz=$(getlong $SetupSzOfs $bs 1)
	if [ $setupsz -eq 0 ]; then
		setupsz=4
		store 8 $SetupSzOfs $setupsz $bs "setup size $setupsz"
	fi
	[ -n "$DEBUG" ] && echo "Read setup ($setupsz sectors) ..." 1>&2
	ddq if=$KERNEL bs=512 skip=1 count=$setupsz >> $bs

	Version=$(getlong 0x206 $bs 2)
	[ $(getlong $Magic $bs) -ne 1400005704 ] && Version=0
	feature=""
	while read prot kern info ; do
		[ $Version -lt $((0x$prot)) ] && continue
		feature="features $prot starting from kernel $kern "
	done <<EOT
200	1.3.73	kernel_version, bzImage, initrd, loadflags/type_of_loader
201	1.3.76	heap_end_ptr
202	2.4.0	new cmdline
204	2.6.14	long syssize
EOT
	[ -n "$DEBUG" ] && printf "Protocol %X $feature\n" $Version 1>&2
	
	# Old kernels need bootsector patches to disable rescent features
	while read minversion maxversion offset bytes rem; do
		[ $Version -gt $(( 0x$maxversion )) ] && continue
		[ $Version -lt $(( 0x$minversion )) ] && continue
		patch $offset $bytes $bs "$rem"
	done <<EOT
000 1FF 08D	B8:00:01			force zImage (movw \$0x100, %ax)
000 1FF 0CB	EB:0B				skip initrd code 
000 201 01E	EB:1E:00:00:00:00		room for the cmdline magic
000 201 036	BE:00:00:E8:76:01:EB:0A:06:57:B1:06:F3:A5:EB:DE	code in cmdline magic moved
000 1FF 039	90:90:90			no kernel version
000 201 04B	22:00				old cmdline ptr 1
000 201 06D	22:00				old cmdline ptr 2
000 203 1F6	00:00 				syssize32
200 FFF 210	FF				type_of_loader=FF
201 FFF 224	00:9B				heap_end_ptr
EOT
	if [ $Version -lt 514 ]; then
		version_string=$((0x200 + $(getlong 0x20E $bs 2) ))
		store	16	0x0037	$version_string	$bs version_string
	fi
	if [ $Version -ge 512 -a $(getlong 0x214 $bs) -ge $((0x100000)) ]; then 
		patch	211	81	$bs	loadflags=can_use_heap+loadhigh
		patch	09D	10	$bs	LOADSEG=0x1000
		patch	0A0	00:01	$bs	LOADSZ=0x10000
	fi
	[ -n "$CMDLINE" ] || patch 04D EB $bs "No cmdline"
	[ -n "$NOEDIT" ] && patch 059 0D:46:EB:14 $bs 'mov CR,%al ; inc %si; jmp putal'
	[ 1$TRACKS -ne 180 ] &&	store	8	0x171		$TRACKS $bs TRACKS
	
	[ -n "$FLAGS" ] &&	store	16	$FlagsOfs	$FLAGS $bs FLAGS
	[ -n "$VIDEO" ] &&	store	16	$VideoModeOfs	$VIDEO $bs VIDEO
	[ -n "$RDEV" ] || case "$FORMAT" in
		1200)	RDEV=0x0208 ;;
		1440)	RDEV=0x021C ;;
		2880)	RDEV=0x0220 ;;
		*)	RDEV=0x0200 ;;
	esac
	while [ -L "$RDEV" ]; do RDEV="$(readlink "$RDEV")"; done
	[ -b "$RDEV" ] && RDEV=$(stat -c '0x%02t%02T' $RDEV 2> /dev/null)
	store 16 $RootDevOfs $RDEV $bs RDEV

	[ $FORMAT -lt 1440 ] && store 8 0xEF  16	 $bs	1.2M
	[ $FORMAT -lt 1200 ] && store 8 0xEF  10	 $bs	720K
	[ $FORMAT -lt 720  ] && store 8 0x171 40	 $bs	360K
	[ $FORMAT -lt 360  ] && store 8 0xEF  9		 $bs	320K
	[ $FORMAT -lt 320  ] && store 8 0xF8  2		 $bs	160K
	
	# Info text after setup
	if [ -s "$INFOFILE" ]; then
		patch	048	9a:00:00:00:90	$bs	lcall displayinfo
		uudecode >$bs.infotext <<EOT
begin-base64 644 -
MdsGYI7D6AAAXoHGSgCJ8MHoCUii8QGwDbQOuwcAzRCsPAx1I79sBLFbJgIN
uBsBJjoNdAnNFnT0mM0Wjsc8IHPjPBt0BuvPCMB1zWEHCx4oAss=
====
EOT
		cat "$INFOFILE" >>$bs.infotext
		if [ $Version -lt 514 ]; then
			store 16 0x050 0x0022 $bs.infotext 
		fi
		ddq if=/dev/zero bs=512 count=1 >>$bs.infotext
		n=$(($(stat -c %s $bs.infotext)/512))
		ddq if=$bs.infotext count=$n bs=512 >> $bs
		rm -f $bs.infotext
		store 8 0x1F1  $(($setupsz+$n))	 $bs	update setup size
		store 8 0x04A  $((2+2*$setupsz)) $bs	update displayinfo call
	fi

	# Store cmdline after setup for kernels >= 0.99
	if [ -n "$CMDLINE" ]; then
		echo -n "$CMDLINE" | ddq bs=512 count=1 conv=sync >> $bs
		CmdlineOfs=0x9E00	# Should be in 0x8000 .. 0xA000
		ArgPtrOfs=0x228
		ArgPtrVal=$(( $SetupBase + $CmdlineOfs ))
		if [ $Version -lt 514 ]; then
			ArgPtrOfs=0x0020
			ArgPtrVal=$(( 0xA33F + ($CmdlineOfs << 16) ))
		fi
		store 32 $ArgPtrOfs $ArgPtrVal $bs "Cmdline '$CMDLINE'"
	fi

	# Compute initramfs size (protocol >= 2.00)
	[ $Version -lt 512 ] && INITRD=""
	initrdlen=0
INITRDPAD=4
INITRDALIGN=0x1000
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		while [ -L "$i" ]; do i="$(readlink $i)"; done
		size=$(( ($(stat -c %s "$i") + $INITRDPAD - 1) & -$INITRDPAD ))
		[ -n "$DEBUG" ] && echo "initrd $i $size " 1>&2
		initrdlen=$(( $initrdlen + $size ))
		ADRSRD=$(( (($MEM * 0x100000) - $initrdlen) & -$INITRDALIGN ))
		store 32 $RamfsAdrOfs $(( $ADRSRD )) $bs initrd adrs
		store 32 $RamfsLenOfs $initrdlen $bs initrdlen
	done

	[ -n "$NOSYSSIZEFIX" ] || store 32 0x1F4 \
		$(( ($(stat -c %s $KERNEL)+15)/16 - ($setupsz+1)*32)) $bs fix system size

	# Output boot sector + setup + cmdline
	ddq if=$bs

	# Output kernel code
	syssz=$(( ($(getlong 0x1F4 $bs)+31)/32 ))
	cat $KERNEL /dev/zero | ddq bs=512 skip=$(( $setupsz+1 )) count=$syssz conv=sync

	# Output initramfs
	for i in $( echo $INITRD | sed 's/,/ /' ); do
		[ -s "$i" ] || continue
		ddq if=$i
		padding=$(( $INITRDPAD - ($(stat -c %s $i) % $INITRDPAD) ))
		[ $padding -eq $INITRDPAD ] || ddq if=/dev/zero bs=1 count=$padding
	done

	# Cleanup
	rm -f $bs
}

if [ "$FORMAT" == "0" ]; then # unsplitted
	floppyset > $PREFIX
	PAD=$(( 512 - ($(stat -c %s $PREFIX) % 512) ))
	[ $PAD -ne 512 ] && ddq if=/dev/zero bs=1 count=$PAD >> $PREFIX
	exit
fi
floppyset | split -b ${FORMAT}k /dev/stdin floppy$$
i=1
ls floppy$$* 2> /dev/null | while read file ; do
	output=$PREFIX$(printf "%03d" $i)
	cat $file /dev/zero | ddq bs=1k count=$FORMAT conv=sync of=$output
	echo $output
	rm -f $file
	i=$(( $i + 1 ))
done
