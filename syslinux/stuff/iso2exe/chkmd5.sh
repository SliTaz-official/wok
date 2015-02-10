#!/bin/sh

ddq()
{
	dd $@ 2> /dev/null
}

get()
{
	od -v -j $1 -N ${4:-${3:-2}} -t u${3:-2} -w${3:-2} -An $2 2>/dev/null ||
	hexdump -v -s $1 -n ${4:-${3:-2}} -e "\"\" 1/${3:-2} \" %d\n\"" $2
}

[ -z "$1" ] && echo "usage: $0 file.iso" && exit 1

echo "iso data sectors 16..$(echo $(get 32848 $1 4))"
ddq if=$1 bs=2k skip=16 count=$(echo $(get 32848 $1 4)) | md5sum
ddq if=$1 bs=16 count=1 skip=2047 | od -N 16 -t x1 -An | sed 's/ //g'
n=$(($(get 2 $1)-1+($(get 4 $1)-1)*512))
[ 0 -ne $(get 18 $1) ] && [ $n -lt 50000 ] && [ $n -gt 32768 ] &&
printf "exe16 chk 0..%04X (65535) %d\n" $n $(get 0 $1 2 $n | awk '{ i+= $0 } END { print i % 65536 }')
echo -n "boot chk 40..8000 (0) "
get 64 $1 2 32704 | awk '{ i+= $0 } END { print i % 65536 }'
if [ 23117 -eq $(get 0 $1) ]; then
	win32sz=$((512*$(get 69 $1 1)))
	[ 17744 -eq $(get 128 $1) ] && printf "WIN32 file at 0000 (%d bytes)\n" $win32sz
	[ 29538 -eq $(get 125 $1) ] && echo "bootiso head at 0000"
	if [ $win32sz -ne 0 ]; then
		printf "syslinux hybrid boot record at %04X (512 bytes)\n" $win32sz
		printf "tazlito data record at %04X (512 bytes)\n" $(($win32sz+512))
	fi
	dosexe=$(($(get 20 $1) - 0xC0))
	rootfs=$(($dosexe - $(get 24 $1)))
	doscom=$(get 66 $1)
	fdsect=$(get 28 $1 1)
	printf "%d free bytes at %04X..%04X\n" $(($doscom - (512*$fdsect) - $win32sz - 1024))  $(($win32sz+1024)) $(($doscom - (512*$fdsect)))
	[ $fdsect -ne 0 ] && 
	printf "floppy bootstrap file at %04X (%d bytes)\n" $(($doscom - (512*$fdsect))) $((512*$fdsect))
	[ $doscom -ne 0 ] &&
	printf "DOS boot file at %04X (%d bytes)\n" $doscom $(($rootfs - $doscom))
	[ $dosexe -ne $rootfs ] &&
	printf "rootfs.gz file at %04X (%d bytes)\n" $rootfs $(($dosexe - $rootfs))
	printf "DOS/EXE stub at %04X (%d bytes)\n" $dosexe $((0x8000 - $dosexe))
	[ 0 -ne $(get 32756 $1) ] && echo "ISO image md5 at 7FF0 (16 bytes)"
fi
