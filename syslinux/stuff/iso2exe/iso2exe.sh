#!/bin/sh
if [ "$1" == "--build" ]; then
	shift
	[ $(tar cf - $@ | wc -c) -gt $((32 * 1024)) ] &&
		echo "The file set $@ is too large (31K max) :" &&
		ls -l $@ && exit 1
	cat >> $0 <<EOM
$(tar cf - $@ | lzma e -si -so | uuencode -m -)
EOT
EOM
	sed -i '/--build/,/^fi/d' $0
	exit
fi

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

main()
{
	case "$1" in
	--get)	shift
		uudecode | unlzma | tar xOf - $@
		exit ;;
	*)	cat > /dev/null
	esac
	
	[ ! -s "$1" ] && echo "usage: $0 image.iso" 1>&2 && exit 1
	case "$(od -N 2 -t x2 -An $1)" in
	*5a4d)	echo "The file $1 is already an EXE file." 1>&2 && exit 1;;
	*0000)	[ -x /usr/bin/isohybrid ] && isohybrid $1
	esac
	[ ! -x /usr/sbin/mount.posixovl ] && 
	echo "No file mount.posixovl. Aborting." 1>&2 && exit 1
		
	echo "Moving syslinux hybrid boot record..."
	ddq if=$1 bs=512 count=1 | ddq of=$1 bs=512 count=1 seek=1 conv=notrunc 
	
	echo "Inserting EXE boot record..."
	$0 --get bootiso.bin | ddq of=$1 conv=notrunc

	# keep the largest room for the tazlito info file
	TMP=/tmp/iso2exe$$
	mkdir -p $TMP/bin $TMP/dev
	cp /usr/sbin/mount.posixovl $TMP/bin/mount.posixovl.iso2exe
	cp -a /dev/?d?* $TMP/dev
	$0 --get init > $TMP/init.exe
	chmod +x $TMP/init.exe $TMP/bin/mount.posixov*
	( cd $TMP ; find * | cpio -o -H newc ) | \
		lzma e $TMP/rootfs.gz -si 2> /dev/null
	SIZE=$(wc -c < $TMP/rootfs.gz)
	store 28 $SIZE $1
	OFS=$(( 0x8000 - $SIZE ))
	printf "Adding rootfs.gz file at %04X...\n" $OFS
	cat $TMP/rootfs.gz | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	rm -rf $TMP
	SIZE=$($0 --get lzcom.bin boot.com.lzma | wc -c)
	OFS=$(( $OFS - $SIZE ))
	printf "Adding DOS boot file at %04X...\n" $OFS
	$0 --get lzcom.bin boot.com.lzma | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	store 34 $(($OFS+0xE0)) $1
	store 30 ${RANDOM:-0} $1
	i=34
	n=0
	echo -n "Adding checksum..."
	while [ $i -lt 32768 ]; do
		n=$(($n + $(od -j $i -N 2 -t u2 -An $1) ))
		i=$(($i + 2))
	done
	store 32 -$n $1
	echo " done."
}

main $@ <<EOT
