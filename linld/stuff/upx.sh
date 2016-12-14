#!/bin/sh

upx -5 $1 && echo "0  3C E8 75 FB 89 F7 AD 86 E0 29 F8 AB |" | hexdump -R | \
dd bs=1 seek=$(($(stat -c %s $1) - 15)) of=$1 conv=notrunc 2> /dev/null
