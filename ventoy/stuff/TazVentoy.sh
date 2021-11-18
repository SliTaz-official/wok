#!/bin/sh

case "$1" in
-*) echo "Usage: $0 [ip] [port]" && exit 1
esac

[ $(id -u) -ne 0 ] && exec tazbox su $0 $@

cd $(dirname $0)
HOST="${1:-127.0.0.1}:${2:-24680}"
echo -n > log.txt

PATH=./tool/i386:$PATH V2DServer ${HOST/:/ } &
sleep 1

tazweb --notoolbar http://$HOST/ || browser http://$HOST/
kill %1
