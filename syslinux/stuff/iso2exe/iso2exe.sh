#!/bin/sh

ddq()
{
	dd $@ 2> /dev/null
}

store()
{
	n=$2; for i in $(seq 8 8 ${4:-16}); do
		printf '\\\\x%02X' $(($n & 255))
		n=$(($n >> 8))
	done | xargs echo -en | ddq bs=1 conv=notrunc of=$3 seek=$(($1))
}

get()
{
	echo $(od -j $(($1)) -N ${3:-2} -t u${3:-2} -An $2)
}

add_rootfs()
{
	TMP=/tmp/iso2exe$$
	mkdir -p $TMP/bin $TMP/dev
	cp -a /dev/?d?* $TMP/dev
	$0 --get init > $TMP/init.exe
	grep -q mount.posixovl.iso2exe $TMP/init.exe &&
	cp /usr/sbin/mount.posixovl $TMP/bin/mount.posixovl.iso2exe \
		2> /dev/null && echo "Store mount.posixovl ($(wc -c \
			< /usr/sbin/mount.posixovl) bytes) ..."
	find $TMP -type f -print0 | xargs -0 chmod +x
	( cd $TMP ; find * | cpio -o -H newc ) | \
		lzma e $TMP/rootfs.gz -si 2> /dev/null
	SIZE=$(wc -c < $TMP/rootfs.gz)
	store 24 $SIZE $1
	OFS=$(( $OFS - $SIZE ))
	printf "Adding rootfs.gz file at %04X (%d bytes) ...\n" $OFS $SIZE
	cat $TMP/rootfs.gz | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	rm -rf $TMP
}

add_dosexe()
{
	OFS=$((0x7EE0))
	printf "Adding DOS/EXE at %04X (%d bytes) ...\n" $OFS $((0x8000 - $OFS))
	$0 --get bootiso.bin 2> /dev/null | \
	ddq bs=1 skip=$OFS of=$1 seek=$OFS conv=notrunc
}

add_doscom()
{
	SIZE=$($0 --get boot.com | wc -c)
	OFS=$(( $OFS - $SIZE ))
	printf "Adding DOS boot file at %04X (%d bytes) ...\n" $OFS $SIZE
	$0 --get boot.com | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	store 66 $(($OFS+0xC0)) $1
}

add_win32exe()
{
	ddq if=/tmp/exe$$ of=$1 conv=notrunc
	SIZE=$($0 --get win32.exe 2> /dev/null | tee /tmp/exe$$ | wc -c)
	printf "Adding WIN32 file at %04X (%d bytes) ...\n" 0 $SIZE
	ddq if=/tmp/exe$$ of=$1 conv=notrunc
	printf "Adding bootiso head at %04X...\n" 0
	$0 --get bootiso.bin 2> /dev/null > /tmp/exe$$
	ddq if=/tmp/exe$$ of=$1 bs=128 count=1 conv=notrunc
	store $((0x94)) $((0xE0 - 12*8)) $1
	store $((0xF4)) $((16 - 12)) $1
	ddq if=$1 of=/tmp/coff$$ bs=1 skip=$((0x178)) count=$((0x88))
	ddq if=/tmp/coff$$ of=$1 conv=notrunc bs=1 seek=$((0x178 - 12*8))
	ddq if=/tmp/exe$$ of=$1 bs=1 count=30 seek=$((0x1A0)) skip=$((0x1A0)) conv=notrunc
	ddq if=$2 bs=1 skip=$((0x1BE)) seek=$((0x1BE)) count=66 of=$1 conv=notrunc
	store 69 $(($SIZE/512)) $1 8
	store 510 $((0xAA55)) $1
	rm -f /tmp/exe$$ /tmp/coff$$
	printf "Moving syslinux hybrid boot record at %04X (512 bytes) ...\n" $SIZE
	ddq if=$2 bs=1 count=512 of=$1 seek=$SIZE conv=notrunc
	OFS=$(($SIZE+512))
}

add_fdbootstrap()
{
	SIZE=$($0 --get bootfd.bin 2> /dev/null | wc -c)
	if [ $SIZE -ne 0 ]; then
		SIZE=$(( $SIZE -  512 )) # sector 2 is data
		OFS=$(( $OFS - $SIZE ))
		printf "Adding floppy bootstrap file at %04X (%d bytes) ...\n" $OFS $SIZE
		$0 --get bootfd.bin | \
		ddq of=$1 bs=1 count=512 seek=$OFS conv=notrunc
		$0 --get bootfd.bin | \
		ddq of=$1 bs=1 skip=1024 seek=$((512 + $OFS)) conv=notrunc
		store 28 $(($SIZE/512)) $1 8
	fi
}
case "$1" in
--build)
	shift
	ls -l $@
	cat >> $0 <<EOM
$(tar cf - $@ | lzma e -si -so | uuencode -m -)
EOT
EOM
	sed -i '/^case/,/^esac/d' $0
	exit ;;
--get)
	cat $2
	exit ;;
--array)
	DATA=/tmp/dataiso$$
	ddq if=/dev/zero bs=32k count=1 of=$DATA
	add_win32exe $DATA $2 > /dev/null
	HSZ=$OFS
	add_dosexe $DATA > /dev/null
	add_rootfs $DATA > /dev/null
	add_doscom $DATA > /dev/null
	add_fdbootstrap $DATA > /dev/null
	name=${3:-bootiso}
	BOOTISOSZ=$((0x8000 - $OFS + $HSZ))
	cat <<EOT

#define $(echo $name | tr '[a-z]' '[A-Z]')SZ $BOOTISOSZ

#ifdef WIN32
static char $name[] = {
$(hexdump -v -n $HSZ -e '"    " 16/1 "0x%02X, "' -e '"  // %04.4_ax |" 16/1 "%_p" "| \n"' $DATA | sed 's/ 0x  ,/      /g')
$(hexdump -v -s $OFS -e '"    " 16/1 "0x%02X, "' -e '"  // %04.4_ax |" 16/1 "%_p" "| \n"' $DATA | sed 's/ 0x  ,/      /g')
EOT

for mode in data offset ; do
	ofs=0
	while read tag str; do
		if [ "$mode" == "data" ]; then
			echo -en "$str\0" | hexdump -v -e '"    " 16/1 "0x%02X, "' \
				-e '"  // %04.4_ax |" 16/1 "%_p" "| \n"' | \
				sed 's/ 0x  ,/      /g'
		else
			if [ $ofs -eq 0 ]; then
				cat <<EOT
};
#else
static char *$name;
#endif
#define ELTORITOOFS	3
EOT
			fi
			echo "#define $tag	$(($BOOTISOSZ+$ofs))"
			ofs=$(($(echo -en "$str\0" | wc -c)+$ofs))
		fi
	done <<EOT
READSECTORERR	Read sector failure.
USAGE		Usage: isohybrid.exe file.iso [--forced]
OPENERR		Can't open r/w the iso file.
ELTORITOERR	No EL TORITO SPECIFICATION signature.
CATALOGERR	Invalid boot catalog.
HYBRIDERR	No isolinux.bin hybrid signature.
SUCCESSMSG	Now you can create a USB key with your .iso file.\\\\nSimply rename it to a .exe file and run it.
FORCEMSG	You can add --forced to proceed anyway.
EOT
done
	rm -rf $DATA
	exit ;;
--exe)
	# --exe mvcom.bin x.com y.exe > xy.exe
	cat $4 $3 > /tmp/exe$$
	S=$(stat -c %s /tmp/exe$$)
	store 2 $(($S%512)) /tmp/exe$$
	store 4 $((($S+511)/512)) /tmp/exe$$
	store 14 -16 /tmp/exe$$
	store 16 -2 /tmp/exe$$
	store 20 256 /tmp/exe$$
	store 22 -16 /tmp/exe$$
	ddq if=$2 bs=1 seek=64 of=/tmp/exe$$ conv=notrunc
	store 65 $(stat -c %s $3) /tmp/exe$$
	store 68 $((0x100-0x40+$(stat -c %s $4))) /tmp/exe$$
	cat /tmp/exe$$
	rm -f /tmp/exe$$
	exit ;;
esac

main()
{
	[ $(id -u) -ne 0 ] && exec su -c "$0 $@" < /dev/tty
	case "${1/--/-}" in
	-get)	shift
		uudecode | unlzma | tar xOf - $@
		exit ;;
	*)	cat > /dev/null
	esac
	
	[ ! -s "$1" ] && echo "usage: $0 image.iso [--undo]" 1>&2 && exit 1
	case "${2/--/-}" in
	-u*|-r*|-w*)
	    case "$(get 0 $1)" in
	    23117)
		ddq if=$1 bs=512 count=2 skip=$(get 69 $1 1) of=$1 conv=notrunc
		ddq if=/dev/zero bs=1k seek=1 count=31 of=$1 conv=notrunc ;;
	    *)  ddq if=/dev/zero bs=1k count=32 of=$1 conv=notrunc ;;
	    esac
	    exit 0
	esac
	case "$(get 0 $1)" in
	23117)	echo "The file $1 is already an EXE file." 1>&2 && exit 1;;
	0)	[ -x /usr/bin/isohybrid ] && isohybrid $1 && echo "Do isohybrid"
	esac
		
	echo "Read hybrid & tazlito data..."
	ddq if=$1 bs=512 count=1 of=/tmp/hybrid$$
	ddq if=$1 bs=512 skip=2 count=20 of=/tmp/tazlito$$
	add_win32exe $1 /tmp/hybrid$$
	printf "Moving tazlito data record at %04X (512 bytes) ...\n" $OFS
	ddq if=/tmp/tazlito$$ bs=1 count=512 of=$1 seek=$OFS conv=notrunc
	rm -f /tmp/tazlito$$ /tmp/hybrid$$
	HOLE=$(($OFS+512))
	
	# keep the largest room for the tazlito info file
	add_dosexe $1
	add_rootfs $1
	add_doscom $1
	add_fdbootstrap $1
	printf "%d free bytes in %04X..%04X\n" $(($OFS-$HOLE)) $HOLE $OFS
	store 26 ${RANDOM:-0} $1
	i=66
	n=0
	echo -n "Adding checksum..."
	while [ $i -lt 32768 ]; do
		n=$(($n + $(get $i $1) ))
		i=$(($i + 2))
	done
	store 64 -$n $1
	echo " done."
}

main $@ <<EOT
