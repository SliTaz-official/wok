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

get()
{
	echo $(od -j $(($1)) -N ${3:-2} -t u${3:-2} -An $2)
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
		
	echo "Moving syslinux hybrid boot record..."
	ddq if=$1 bs=512 count=1 | ddq of=$1 bs=512 count=1 seek=1 conv=notrunc 
	
	echo "Inserting EXE boot record..."
	$0 --get bootiso.bin | ddq of=$1 conv=notrunc

	# keep the largest room for the tazlito info file
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
	SIZE=$($0 --get boot.com | wc -c)
	OFS=$(( $OFS - $SIZE ))
	printf "Adding DOS boot file at %04X...\n" $OFS
	$0 --get boot.com | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	store 66 $(($OFS+0xC0)) $1
	SIZE=$($0 --get win32.exe 2> /dev/null | tee /tmp/exe$$ | wc -c)
	if [ $SIZE -ne 0 ]; then
		OFS=$(( 128 + ( ($OFS - $SIZE + 128) & 0xFE00 ) ))
		printf "Adding WIN32 file at %04X...\n" $OFS
		LOC=$((0xAC+$(get 0x94 /tmp/exe$$)))
		for i in $(seq 1 $(get 0x86 /tmp/exe$$)); do
			store $LOC $(($(get $LOC /tmp/exe$$)+$OFS-128)) /tmp/exe$$
			LOC=$(($LOC+40))
		done
		ddq if=/tmp/exe$$ of=$1 bs=1 skip=128 seek=$OFS conv=notrunc
	fi
	rm -f /tmp/exe$$ 
	store 60 $OFS $1
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
