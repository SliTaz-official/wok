#!/bin/sh

case "$1" in
-*) echo "Usage: $0 [device] [ip] [port]" && exit 1
esac

[ $(id -u) -ne 0 ] && exec tazbox su $0 $@

cd $(dirname $0)
dev="${1:-$(blkid | sed '/Ventoy/!d;s|:.*||;q')}"
DISK=${dev%[0-9]*}; DISK=${DISK%p}
HOST="${2:-127.0.0.1}:${3:-24681}"
fstype="$(blkid $dev | sed 's|.* TYPE="||;s|".*||')"
case "$fstype" in
exfat)	fstype="exFAT";;
ntfs)	fstype="NTFS";;
esac
mkdir /tmp/mnt$$
mount ${dev/1/2} /tmp/mnt$$
version="$(sed '/VERSION=/!d;s|.*="||;s|"||' /tmp/mnt$$/grub/grub.cfg)"
[ -e /tmp/mnt$$/EFI/BOOT/grubx64_real.efi ] && secureboot=1 || secureboot=0
umount /tmp/mnt$$
blkid $DISK | grep -q 'PTTYPE="gpt"' && partstyle=1 || partstyle=0
echo PATH=$(dirname $0)/tool/i386:$PATH Plugson ${HOST/:/ } $(dirname $0) "$DISK" $version "$fstype" $partstyle $secureboot > VentoyPlugson.log
mount $dev /tmp/mnt$$
cd /tmp/mnt$$
mkdir ventoy 2> /dev/null || true

PATH=$(dirname $0)/tool/i386:$PATH Plugson ${HOST/:/ } $(dirname $0) "$DISK" $version "$fstype" $partstyle $secureboot &
sleep 1

tazweb --notoolbar http://$HOST/ || browser http://$HOST/
kill %1
while !umount /tmp/mnt$$ 2> /dev/null; do sleep 1; done && rmdir /tmp/mnt$$
