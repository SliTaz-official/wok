#!/bin/sh

if [ "$1" == "--build" ]; then
	cat >> $0 <<EOM
$(for i in fx fx_f fx_c px px_f px_c ; do
     cat mbr/isohdp$i.bin /dev/zero | dd bs=1 count=512 2> /dev/null
  done | gzip -9 | uuencode -m -)
EOT
EOM
	sed -i '/--build/,/^fi/d' $0
	exit
fi
iso=
heads=64	# zipdrive-style geometry
sectors=32
partype=23	# "Windows hidden IFS"
entry=1
id=$(( ($RANDOM <<16) + $RANDOM))
offset=0
partok=0
hd0=0

while [ -n "$1" ]; do
	case "$1" in
	-ct*)		hd0=2;;
	-e*|--e*)	entry=$2; shift;;
	-f*)		hd0=1;;
	-h)		heads=$2; shift;;
	-i|--i*)	id=$(($2)); shift;;
	-noh*)		hd0=0;;
	-nop*)		partok=0;;
	-o*|--o*)	offset=$(($2)); shift;;
	-p*)		partok=1;;
	-s)		sectors=$2; shift;;
	-t*|--t*)	partype=$(($2 & 255)); shift;;
	*)		iso=$1;;
	esac
	shift
done

if [ ! -f "$iso" ]; then
	cat << EOT
usage: $0 [options] isoimage
options:
	-h <X>		Number of default geometry heads
	-s <X>		Number of default geometry sectors
	-e --entry	Specify partition entry number (1-4)
	-o --offset	Specify partition offset (default 0)
	-t --type	Specify partition type (default 0x17)
	-i --id		Specify MBR ID (default random)
	--forcehd0	Assume we are loaded as disk ID 0
	--ctrlhd0	Assume disk ID 0 if the Ctrl key is pressed
	--partok	Allow booting from within a partition
EOT
	exit 1
fi

ddq()
{
	dd "$@" 2> /dev/null
}

readiso()
{
	ddq bs=2k skip=$1 count=1 if=$iso | ddq bs=1 skip=$2 count=$3
}

# read a 32 bits data
read32()
{
	readiso $1 $2 4 | hexdump -e '"" 1/4 "%d" "\n"'
}

# write a 32 bits data
store32()
{
	n=$2; i=4; while [ $i -ne 0 ]; do
		printf '\\\\x%02X' $(($n & 255))
		i=$(($i-1)); n=$(($n >> 8))
	done | xargs echo -en | ddq bs=1 conv=notrunc of=$iso seek=$(($1))
}

main()
{
	uudecode | gunzip | ddq bs=512 count=1 of=$iso conv=notrunc \
	  skip=$(( (3*$partok) + $hd0))
	store32 432 $(($lba * 4))
	store32 440 $id
	store32 508 0xAA550000
	e=$(( (($entry -1) % 4) *16 +446))
	store32 $e 0x10080
	esect=$(( ($sectors + ((($cylinders -1) & 0x300) >>2)) <<16))
	ecyl=$(( (($cylinders -1) & 0xff) <<24))
	store32 $(($e + 4)) $(($partype + (($heads - 1) <<8) +$esect +$ecyl))
	store32 $(($e + 8)) $offset
	store32 $(($e + 12)) $(($cylinders * $heads * $sectors))
}

abort()
{
	echo "$iso: $1"
	exit 1
}

[ "$(readiso 17 7 23)" == "EL TORITO SPECIFICATION" ] ||
	abort "no boot record found."
cat=$(read32 17 71)
[ $(read32 $cat 0) -eq 1 -a $(read32 $cat 30) -eq $(( 0x88AA55 )) ] ||
	abort "invalid boot catalog."
lba=$(read32 $cat 40)
[ $(read32 $lba 64) -eq 1886961915 ] ||
	abort "no isolinux.bin hybrid signature in bootloader."
size=$(stat -c "%s" $iso)
trksz=$(( 512 * $heads * $sectors ))
cylinders=$(( ($size + $trksz - 1) / $trksz ))
pad=$(( (($cylinders * $trksz) - $size) / 512 ))
[ $pad -eq 0 ] || ddq bs=512 count=$pad if=/dev/zero >> $iso
if [ $cylinders -gt 1024 ]; then
	cat 1>&2 <<EOT
Warning: more than 1024 cylinders ($cylinders).
Not all BIOSes will be able to boot this device.
EOT
	cylinders=1024
fi

main <<EOT
