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
	echo $(od -j $(($1)) -N ${3:-2} -t u${3:-2} -An "$2")
}

compress()
{
	if [ "$1" ]; then
		[ "$(which zopfli 2> /dev/null)" ] &&
		zopfli --i100 -c /dev/stdin > $1 ||
		gzip -9 > $1
		[ "$(which advdef 2> /dev/null)" ] &&
		advdef -z4 $1 > /dev/null
	elif [ "$(which xz 2> /dev/null)" ]; then
		xz -z -e --format=lzma --lzma1=mode=normal --stdout
	else
		lzma e -si -so
	fi 2> /dev/null
}

add_rootfs()
{
	TMP=/tmp/iso2exe$$
	mkdir -p $TMP/dev
	cp -a /dev/tty /dev/tty0 $TMP/dev
	$0 --get init > $TMP/init.exe
#	mount -o loop,ro $1 $TMP
#	oldslitaz="$(ls $TMP/boot/isolinux/splash.lss 2> /dev/null)"
#	umount -d $TMP
#	[ "$oldslitaz" ] && # for SliTaz <= 3.0 only...
#	grep -q mount.posixovl.iso2exe $TMP/init.exe && mkdir $TMP/bin &&
#	cp /usr/sbin/mount.posixovl $TMP/bin/mount.posixovl.iso2exe \
#		2> /dev/null && echo "Store mount.posixovl ($(wc -c \
#			< /usr/sbin/mount.posixovl) bytes) ..."
	find $TMP -type f -print0 | xargs -0 chmod +x
	( cd $TMP ; find * | grep -v rootfs.gz | cpio -o -H newc ) | \
		compress $TMP/rootfs.gz
	SIZE=$(wc -c < $TMP/rootfs.gz)
	store 24 $SIZE $1
	OFS=$(( $OFS - $SIZE ))
	printf "Adding rootfs.gz file at %04X (%d bytes) ...\n" $OFS $SIZE
	cat $TMP/rootfs.gz | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	rm -rf $TMP
}

add_dosexe()
{
	TMP=/tmp/bootiso$$
	$0 --get bootiso.bin > $TMP 2> /dev/null 
	OFS=$(($(get 20 $TMP) - 0xC0))
	printf "Adding DOS/EXE stub at %04X (%d bytes) ...\n" $OFS $((0x8000 - $OFS))
	ddq if=$TMP bs=1 skip=$OFS of=$1 seek=$OFS conv=notrunc
	rm -f $TMP
}

add_doscom()
{
	SIZE=$($0 --get boot.com | wc -c)
	OFS=$(( $OFS - $SIZE ))
	printf "Adding DOS boot file at %04X (%d bytes) ...\n" $OFS $SIZE
	$0 --get boot.com | ddq of=$1 bs=1 seek=$OFS conv=notrunc
	store 64 $(($OFS+0xC0)) $1
}

add_tazlito_info()
{
	HOLE=$OFS
	[ $(get 0 $2) -eq 35615 ] || return
	zcat $2 | compress /tmp/rezipped$$.gz
	n=$(stat -c %s /tmp/rezipped$$.gz)
	printf "Moving tazlito data record at %04X ($n bytes) ...\n" $OFS
	ddq if=/tmp/rezipped$$.gz bs=1 of=$1 seek=$OFS conv=notrunc
	HOLE=$(($HOLE+$n))
	rm -f /tmp/rezipped$$.gz
}

add_win32exe()
{
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
	ddq if=/tmp/exe$$ of=$1 bs=1 count=24 seek=$((0x1A0)) skip=$((0x1A0)) conv=notrunc
	ddq if=$2 bs=1 skip=$((0x1B8)) seek=$((0x1B8)) count=72 of=$1 conv=notrunc
	store 417 $(($SIZE/512)) $1 8
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
		store 26 $(($SIZE/512)) $1 8
	fi
}

gzsize()
{
	echo $(($(hexdump -C | awk ' {
		for (i = 2; i < 18; i++) if ($i != "00") break;
		if (i == 18) {
			for (i = 17; i > 1; i--) if ($i != "00") break;
			print "0x" $1 " + 7 - " (16 - i) 
			exit
		}
	}')))
}

fileofs()
{
	[ $(get 1024 "$ISO") -eq 35615 ] && i=1024 ||
	i=$((512*(1+$(get 417 "$ISO" 1))))
	stub=$(($(get 20 "$ISO") - 0xC0))
	c=$(custom_config_sector "$ISO")
	SIZE=0; OFFSET=0
	case "$1" in
	win32.exe)	[ $i -eq 1024 ] || SIZE=$(($i - 512));;
	syslinux.mbr)	[ $i -eq 1024 ] || OFFSET=$(($i - 512)); SIZE=512;;
	flavor.info)	OFFSET=$i
			SIZE=$(ddq bs=512 skip=$(($i/512)) if="$ISO" | gzsize);;
	floppy.boot)	SIZE=$(($(get 26 "$ISO" 1)*512))
			OFFSET=$(($(get 64 "$ISO") - 0xC0 - $SIZE));;
	rootfs.gz)	SIZE=$(get 24 "$ISO"); OFFSET=$(($stub - $SIZE));;
	tazboot.com)	OFFSET=$(($(get 64 "$ISO") - 0xC0))
			SIZE=$(($stub - $(get 24 "$ISO") - $OFFSET));;
	dosstub)	OFFSET=$stub; SIZE=$((0x8000 - $OFFSET));;
	boot.md5)	OFFSET=$((0x7FF0)); SIZE=16;;
	fs.iso)		OFFSET=$((0x8000))
			SIZE=$((2048*$c - $OFFSET));;
	custom.magic)	ddq bs=2k skip=$c if="$ISO" | ddq bs=1 count=6 | \
				grep -q '#!boot' && OFFSET=$((2048*$c)) &&
			SIZE=39 ;;
	custom.append)  OFFSET=$((2048*$c+47)) &&
			SIZE=$(ddq bs=2k skip=$c if="$ISO" count=1 | \
				sed '/^append=/!d;s/^[^=]*=.//' | wc -c);;
	custom.initrd)  i=$(ddq bs=2k skip=$c if="$ISO" count=1 | \
				sed '/^append=\|^initrd:/!d' | wc -c)
			OFFSET=$((2048*$c+$i+40))
			SIZE=$(($(ddq bs=2k skip=$c if="$ISO" count=1 | \
				sed '/^initrd:/!d;s/.*://') + 0));;
	esac
}

list()
{
	HEAP=0
	for f in win32.exe syslinux.mbr flavor.info floppy.boot tazboot.com \
		 rootfs.gz dosstub boot.md5 fs.iso custom.magic custom.append \
		 custom.initrd; do
		fileofs $f
		[ $SIZE -le 0 ] && continue
		[ "${OFFSET:8}" ] && continue
		[ $OFFSET -lt 0 ] && continue
		[ $(get $OFFSET "$ISO") -eq 0 ] && continue
		[ $OFFSET -gt $HEAP ] && [ $(($OFFSET - $HEAP)) -gt 16 ] &&
		printf "%d free bytes in %04X..%04X\n" $(($OFFSET - $HEAP)) $HEAP $OFFSET
		[ $OFFSET -ge $HEAP ] && HEAP=$(($OFFSET+$SIZE))
		printf "$f at %04X ($SIZE bytes).\n" $OFFSET
	done
	OFFSET=$(stat -c %s "$ISO")
	[ $OFFSET -gt $HEAP ] &&
	printf "%d free bytes in %04X..%04X\n" $(($OFFSET - $HEAP)) $HEAP $OFFSET
}

extract()
{
	for f in $@; do
		fileofs $f
		[ $SIZE -eq 0 ] ||
		ddq bs=1 count=$SIZE skip=$OFFSET if="$ISO" >$f
	done
}

custom_config_sector()
{
	echo $(($(get 32848 "$1" 4)+16))
}

clear_custom_config()
{
    start=$(custom_config_sector $1)
    cnt=$((512 - ($start % 512)))
    [ $cnt -ne 512 ] &&
    ddq if=/dev/zero of=$1 bs=2k seek=$start count=$cnt
}
case "$1" in
--build)
	shift
	ls -l $@
	cat >> $0 <<EOM
$(tar cf - $@ | compress | uuencode -m -)
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

#ifndef __MSDOS__
static char $name[] = {
/* head */
$(hexdump -v -n $HSZ -e '"    " 16/1 "0x%02X, "' -e '"  /* %04.4_ax */ \n"' $DATA | sed 's/ 0x  ,/      /g')
/* tail */
$(hexdump -v -s $OFS -e '"    " 16/1 "0x%02X, "' -e '"  /* %04.4_ax */ \n"' $DATA | sed 's/ 0x  ,/      /g')

/* These strange constants are defined in RFC 1321 as
   T[i] = (int)(4294967296.0 * fabs(sin(i))), i=1..64
 */
/* static const uint32_t C_array[64] */
EOT
	while read a b c d; do
		for i in $a $b $c $d; do
			echo $i | sed 's/0x\(..\)\(..\)\(..\)\(..\),/0x\4, 0x\3, 0x\2, 0x\1, /'
		done
	done <<EOT
	0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
	0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
	0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
	0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
	0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
	0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
	0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
	0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
	0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
	0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
	0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
	0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
	0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
	0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
	0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
	0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
EOT
	cat <<EOT
/* static const char P_array[64] */
	0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, /* 1 */
	1, 6, 11, 0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12, /* 2 */
	5, 8, 11, 14, 1, 4, 7, 10, 13, 0, 3, 6, 9, 12, 15, 2, /* 3 */
	0, 7, 14, 5, 12, 3, 10, 1, 8, 15, 6, 13, 4, 11, 2, 9, /* 4 */
/* static const char S_array[16] */
	7, 12, 17, 22,
	5, 9, 14, 20,
	4, 11, 16, 23,
	6, 10, 15, 21,
EOT

for mode in data offset ; do
	ofs=0
	while read tag str; do
		if [ "$mode" == "data" ]; then
			echo -en "$str\0" | hexdump -v -e '"    " 16/1 "0x%02X, "' \
				-e '"  /* %04.4_ax */ \n"' | \
				sed 's/ 0x  ,/      /g'
		else
			if [ $ofs -eq 0 ]; then
				cat <<EOT
};
#endif

#define C_array (uint32_t *) ($name + $(($BOOTISOSZ)))
#define P_array (char *)     ($name + $(($BOOTISOSZ+(64*4))))
#define S_array (char *)     ($name + $(($BOOTISOSZ+(64*4)+64)))
#define ELTORITOOFS	3
EOT
			fi
			echo "#define $tag	$(($BOOTISOSZ+(64*4)+64+16+$ofs))"
			ofs=$(($(echo -en "$str\0" | wc -c)+$ofs))
		fi
	done <<EOT
READSECTORERR	Read sector failure.
USAGE		Usage: isohybrid.exe [--list|--read] [--append cmdline] [--initrd file] file.iso [--forced|--undo|--quick|filename...]
OPENERR		Can't open the iso file.
ELTORITOERR	No EL TORITO SPECIFICATION signature.
CATALOGERR	Invalid boot catalog.
HYBRIDERR	No isolinux.bin hybrid signature.
SUCCESSMSG	Now you can create a USB key with your .iso file.\\\\nSimply rename it to an .exe file and run it.
FORCEMSG	You can add --forced to proceed anyway.
MD5MSG		Computing md5sum...
UNINSTALLMSG	Uninstall done.
OPENINITRDERR	Can't open the initrd file.
ALREADYEXEERR	Already an EXE file.
WIN32_EXE	win32.exe
SYSLINUX_MBR	syslinux.mbr
FLAVOR_INFO	flavor.info
FLOPPY_BOOT	floppy.boot
TAZBOOT_COM	tazboot.com
ROOTFS_GZ	rootfs.gz
DOSSTUB		dosstub
BOOT_MD5	boot.md5
FS_ISO		fs.iso
CUSTOM_MAGIC	custom.magic
CUSTOM_APPEND	custom.append
CUSTOM_INITRD	custom.initrd
CUSTOM_HEADER	#!boot 00000000000000000000000000000000\\\\n
FREE_FORMAT	%ld free bytes in %04lX..%04lX\\\\n
USED_FORMAT	%s at %04lX (%ld bytes).\\\\n
CMDLINE_TAG	append=
INITRD_TAG	initrd:
EOT
done
	cat <<EOT
#ifdef __MSDOS__
#define BOOTISOFULLSIZE	$(($BOOTISOSZ+(64*4)+64+16+$ofs))
static char bootiso[BOOTISOFULLSIZE];
static data_fixup(void)
{
#asm
	push	ds
	push	ds
	pop	es
	mov	ax,ds
	sub	ax,#0x1000
	mov	ds,ax
	xor	si,si
scanlp:
	dec	si
	jz	copydone
	cmp	byte ptr [si+2],#0xEB
	jne	scanlp
	cmp	word ptr [si],#0x5A4D
	jne	scanlp
	mov	cx,#BOOTISOFULLSIZE
	mov	di,#_bootiso
	cld
	rep
	  movsb
copydone:
	pop	ds	
#endasm
	if (!bootiso[0]) {
		puts("No bootiso data");
		exit(-1);
	}
}
#else
#define data_fixup()
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
	[ $(id -u) -ne 0 ] && cmd="$0 $@" && exec su -c "$cmd" < /dev/tty
	append=
	initrd=
	while [ "$1" ]; do
		case "${1/--/-}" in
		-get)	shift
			uudecode | unlzma | tar xOf - $@
			exit ;;
		-a*)	append="$2" ; shift 2 ;;
		-i*)	initrd="$2" ; shift 2 ;;
		-r*|-l*)
			ISO="$2" ; shift 2
			[ -z "$1" ] && list || extract $@
			exit ;;
		*)	cat > /dev/null
			break
		esac
	done
	
	[ ! -s "$1" ] && cat 1>&2 <<EOT && exit 1
usage: $0 [--list|--read] [--append custom_cmdline ] [ --initrd custom_initrd ] image.iso [--force|--undo|"DOS help message"|filename...]
EOT
	case "${2/--/-}" in
	-u*|-r*|-w*|-f*)
	    case "$(get 0 $1)" in
	    23117)
		b=$(get 417 $1 1)
		n=$(($(get 64 $1) + 0xC0 - ($(get 26 $1 1)*512) - ($b+1)*512))
		ddq if=$1 bs=512 count=1 skip=$b of=$1 conv=notrunc
		ddq if=/dev/zero bs=512 seek=1 count=1 of=$1 conv=notrunc
		ddq if=$1 bs=512 seek=2 count=30 skip=$(($b+1)) of=$1 conv=notrunc
		ddq if=/dev/zero bs=1 seek=$n count=$((0x8000 - $n)) of=$1 conv=notrunc ;;
	    *)  ddq if=/dev/zero bs=1k count=32 of=$1 conv=notrunc ;;
	    esac
	    case "${2/--/-}" in
	    -f*)
		[ "$append$initrd" ] && clear_custom_config $1
		set -- "$1" "$3" ;;
	    *)
		clear_custom_config $1
		exit 0 ;;
	    esac
	esac
	case "$(get 0 $1)" in
	23117)	echo "The file $1 is already an EXE file." 1>&2 && exit 1;;
	0)	[ -x /usr/bin/isohybrid ] && isohybrid $1;;
	esac
		
	echo "Read hybrid & tazlito data..."
	ddq if=$1 bs=512 count=1 of=/tmp/hybrid$$
	ddq if=$1 bs=512 skip=2 count=20 of=/tmp/tazlito$$
	add_win32exe $1 /tmp/hybrid$$
	add_tazlito_info $1 /tmp/tazlito$$
	rm -f /tmp/tazlito$$ /tmp/hybrid$$
	
	# keep the largest room for the tazlito info file
	add_dosexe $1
	add_rootfs $1
	add_doscom $1
	add_fdbootstrap $1
	printf "%d free bytes in %04X..%04X\n" $(($OFS-$HOLE)) $HOLE $OFS
	store 440 $(date +%s) $1 32
	[ "$2" ] && echo "$2               " | \
		ddq bs=1 seek=$((0x7FDE)) count=15 conv=notrunc of=$1
	if [ $(stat -c %s $1) -gt 34816 ]; then
		echo "Adding ISO image md5 at 7FF0 (16 bytes) ..."
		echo -en "$(ddq if=$1 bs=2k skip=16 count=$(get 32848 $1 4) | \
			md5sum | cut -c-32 | sed 's/\(..\)/\\x\1/g')" | \
			ddq bs=16 seek=2047 conv=notrunc of=$1
	fi
	if [ "$append$initrd" ]; then
		echo -n "Adding custom config... "
		DATA=/tmp/$(basename $0)$$
		rm -f $DATA > /dev/null
		isosz=$(stat -c %s $1)
		[ "$append" ] && echo "append=$append" >> $DATA
		[ -s "$initrd" ] && echo "initrd:$(stat -c %s $initrd)" >> $DATA &&
			cat $initrd >> $DATA
		echo "#!boot $(md5sum $DATA | sed 's/ .*//')" | cat - $DATA | \
		ddq bs=2k seek=$(custom_config_sector $1) of=$1 conv=notrunc
		newsz=$(stat -c %s $1)
		for i in 1 2 3 4 ; do
			[ $(get $((0x1BE+16*i)) $1 4) == $((0x00010080)) ] || continue
			mb=$(((($newsz -1)/1024/1024)+1))
			h=$((512*$(get 417 "$1" 1)))
			store $(($mb-1)) $((0x1C5+16*i)) $1 8
			store $(($mb-1)) $(($h+0x1C5+16*i)) $1 8
			store $(($mb*2048)) $((0x1D2+16*i)) $1 32
			store $(($mb*2048)) $(($h+0x1D2+16*i)) $1 32
		done
		if [ $newsz -gt $isosz ]; then
			echo "$(($newsz - $isosz)) extra bytes."
		else
			echo "$(($isosz - 32768 - 2048*$(get 32848 $1 4) 
				 - $(stat -c %s $DATA) - 24)) bytes free."
		fi
		rm -f $DATA > /dev/null
	fi
	echo -n "Adding boot checksum..."
	if [ $(stat -c %s $1) -gt 32768 ]; then
		n=$(($(get 2 $1) - 1 + ($(get 4 $1) - 1)*512))
		n=$(($(od -v -N $n -t u2 -w2 -An $1 | \
		       awk '{ i+= $0 } END { print (i % 65536) }') \
		     + $(get $(($n+1)) $1 1)))
		store 18 $(( (-$n -1) % 65536 )) $1
	fi
	echo " done."
}

main "$@" <<EOT
