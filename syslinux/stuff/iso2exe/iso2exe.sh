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
	cp /usr/sbin/mount.posixovl $TMP/bin/mount.posixovl.iso2exe
	find $TMP -type f | xargs chmod +x
	( cd $TMP ; find * | cpio -o -H newc ) | \
		lzma e $TMP/rootfs.gz -si 2> /dev/null
	SIZE=$(wc -c < $TMP/rootfs.gz)
	store 24 $SIZE $1
	OFS=$(( 0x8000 - $SIZE ))
	printf "Adding rootfs.gz file at %04X...\n" $OFS
	cat $TMP/rootfs.gz | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	rm -rf $TMP
}

add_doscom()
{
	SIZE=$($0 --get boot.com | wc -c)
	OFS=$(( $OFS - $SIZE ))
	printf "Adding DOS boot file at %04X...\n" $OFS
	$0 --get boot.com | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	store 66 $(($OFS+0xC0)) $1
}

add_win32exe()
{
	SIZE=$($0 --get win32.exe 2> /dev/null | tee /tmp/exe$$ | wc -c)
	if [ $SIZE -ne 0 ]; then
		OFS=$(( 128 + ( ($OFS - $SIZE + 128) & 0xFE00 ) ))
		printf "Adding WIN32 file at %04X...\n" $OFS
		LOC=$((0xAC+$(get 0x94 /tmp/exe$$)))
		for i in $(seq 1 $(get 0x86 /tmp/exe$$)); do
			CUR=$(get $LOC /tmp/exe$$)
			[ $CUR -eq 0 ] || store $LOC $(($CUR+$OFS-128)) /tmp/exe$$
			LOC=$(($LOC+40))
		done
		ddq if=/tmp/exe$$ of=$1 bs=1 skip=128 seek=$OFS conv=notrunc
		store 60 $OFS $1
	fi
	rm -f /tmp/exe$$ 
}

add_fdbootstrap()
{
	SIZE=$($0 --get bootfd.bin 2> /dev/null | tee /tmp/exe$$ | wc -c)
	if [ $SIZE -ne 0 ]; then
		OFS=$(( $OFS - $SIZE ))
		printf "Adding floppy bootstrap file at %04X...\n" $OFS
		$0 --get bootfd.bin | ddq of=$1 bs=1 seek=$OFS conv=notrunc
		store 28 $(($SIZE/512)) $1 8
	fi
}
case "$1" in
--build)
	shift
	[ $(tar cf - $@ | wc -c) -gt $((32 * 1024)) ] &&
		echo "WARNING: The file set $@ is too large (31K max) :" &&
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
	ddq if=bootiso.bin of=$DATA conv=notrunc
	ddq if=$2 of=$DATA bs=512 seek=1 conv=notrunc
	add_rootfs $DATA > /dev/null
	add_doscom $DATA > /dev/null
	add_win32exe $DATA > /dev/null
	add_fdbootstrap $DATA > /dev/null
	name=${3:-bootiso}
	cat <<EOT

#define $(echo $name | tr '[a-z]' '[A-Z]')SZ $((0x8400 - $OFS))

#ifdef WIN32
static char $name[] = {
$(hexdump -v -n 1024 -e '"    " 16/1 "0x%02X, "' -e '"  // %04.4_ax |" 16/1 "%_p" "| \n"' $DATA | sed 's/ 0x  ,/      /g')
$(hexdump -v -s $OFS -e '"    " 16/1 "0x%02X, "' -e '"  // %04.4_ax |" 16/1 "%_p" "| \n"' $DATA | sed 's/ 0x  ,/      /g')
};
#endif
EOT
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
	case "$1" in
	--get)	shift
		uudecode | unlzma | tar xOf - $@
		exit ;;
	*)	cat > /dev/null
	esac
	
	[ ! -s "$1" ] && echo "usage: $0 image.iso" 1>&2 && exit 1
	case "$(get 0 $1)" in
	23117)	echo "The file $1 is already an EXE file." 1>&2 && exit 1;;
	0)	[ -x /usr/bin/isohybrid ] && isohybrid $1
	esac
		
	echo "Moving syslinux hybrid boot record..."
	ddq if=$1 bs=512 count=1 | ddq of=$1 bs=512 count=1 seek=1 conv=notrunc 
	
	echo "Inserting EXE boot record..."
	$0 --get bootiso.bin | ddq of=$1 conv=notrunc

	# keep the largest room for the tazlito info file
	add_rootfs $1
	add_doscom $1
	add_win32exe $1
	add_fdbootstrap $1
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
