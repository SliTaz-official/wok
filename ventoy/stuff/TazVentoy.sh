#!/bin/sh

case "$1" in
-*) echo "Usage: $0 [ip] [port]" && exit 1
esac

[ $(id -u) -ne 0 ] && exec tazbox su $0 $@

cd $(dirname $0)
HOST="${1:-127.0.0.1}"
PORT=${2:-24680}
[ $(stat -c %s log.txt) -gt 4096 ] && rm log.txt

PATH=./tool/i386:$PATH
V2DServer "$HOST" "$PORT" &
wID=$!
sleep 1

tazweb --notoolbar http://$HOST:$PORT/ || browser http://$HOST:$PORT/
kill $wID
