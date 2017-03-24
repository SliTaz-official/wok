#!/bin/sh

upx -5 $1
o=$(($(stat -c %s $1) - 15))
if dd bs=1 skip=$o if=$1 count=15 2> /dev/null | hd | \
   grep -iq     "2c e8 3c 01 77 f9 c1 04  08 29 34 ad e2 f1 c3"; then
	echo "0  3C E8 75 FB 89 F7 AD 86  E0 29 F8 AB |" | hexdump -R | \
	dd bs=1 seek=$o of=$1 conv=notrunc 2> /dev/null
else
	upx -d $1 > /dev/null 2>&1
	upx -5 --8086 $1
fi
