#!/bin/sh

build="--build"
if [ "$1" == "$build" ]; then
	cat  >> $0 <<EOM
$(uuencode -m mbr/isohdpfx.bin -)
EOT
EOM
	busybox sed -i "/$build/{NNNNNNNNNd}" $0
	exit
fi

if [ -z "$1" ]; then
	cat << EOT
usage: $0 isoimage
EOT
	exit 1
fi
iso=$1
heads=64	# zipdrive-style geometry
sectors=32
partype=23	# "Windows hidden IFS"

readiso()
{
	dd if=$iso bs=2k skip=$1 count=1 2> /dev/null | \
	dd bs=1 skip=$2 count=$3 2> /dev/null
}

# read a 32 bits data
readlong()
{
	readiso $1 $2 4  | hexdump -e '"" 1/4 "%d" "\n"'
}

# write a 32 bits data
storelong()
{
	printf "00000  %02X %02X %02X %02X \n" \
		$(( $2 & 255 )) $(( ($2>>8) & 255 )) \
		$(( ($2>>16) & 255 )) $(( ($2>>24) & 255 )) | \
	hexdump -R | dd bs=1 conv=notrunc of=$iso seek=$(( $1 )) 2> /dev/null
}

setmbr()
{
	uudecode | dd of=$iso conv=notrunc 2> /dev/null
	storelong 432 $(( $lba * 4 ))
	storelong 440 $(( ($RANDOM << 16) + $RANDOM ))
	storelong 446 $(( 0x80 + ( 1 << 16) ))
	esect=$(( $sectors + ((($cylinders -1) & 0x300) >> 2) ))
	ecyl=$(( ($cylinders - 1) & 0xff ))
	storelong 450 $(( $partype + (($heads - 1) << 8) + ($esect << 16) + ($ecyl <<24) ))
	storelong 458 $(( $cylinders * $heads * $sectors ))
	storelong 510 $(( 0xAA55 ))
}

if [ "$(readiso 17 7 23)" != "EL TORITO SPECIFICATION" ]; then
	echo "$iso: no boot record found.";
	exit 1
fi
catalog=$(readlong 17 71)
if [ "$(readiso $catalog 0 32 | md5sum | awk '{ print $1 }')" != \
     "788e7bfdad52cc6aae525725f24a7f89" ]; then
	echo "$iso: invalid boot catalog.";
	exit 1
fi
lba=$(readlong $catalog 40)
if [ $(readlong $lba 64) -ne 1886961915 ]; then
	echo "$iso: bootloader does not have a isolinux.bin hybrid signature.";
	exit 1
fi
size=$(stat -c "%s" $iso)
pad=$(( $size % (512 * $heads * $sectors) ))
[ $pad -eq 0 ] || pad=$((  (512 * $heads * $sectors) - $pad ))
[ $pad -eq 0 ] || dd if=/dev/zero bs=512 count=$(( $pad / 512 )) >> $iso 2> /dev/null
cylinders=$(( ($size + $pad) / (512 * $heads * $sectors) ))
if [ $cylinders -gt 1024 ]; then
	cat 1>&2 <<EOT
Warning: more than 1024 cylinders ($cylinders).
Not all BIOSes will be able to boot this device.
EOT
	cylinders=1024
fi

setmbr <<EOT
