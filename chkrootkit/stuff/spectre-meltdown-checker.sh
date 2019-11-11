#!/bin/sh

wget -qO /tmp/$$.zip https://github.com/speed47/spectre-meltdown-checker/archive/master.zip
unzip -q /tmp/$$.zip -d /tmp
mv /tmp/spectre-meltdown-checker-master/spectre-meltdown-checker.sh /bin
rm -rf /tmp/spectre-meltdown-checker /tmp/$$.zip
/bin/spectre-meltdown-checker.sh
