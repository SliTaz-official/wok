#!/bin/sh

cd $(dirname $0)
for i in main.htm multiset.sh slc2htm.sh ; do [ ! -s "$i" ] && echo "$PWD/$i not found" && exit 1; done
[ -s Levels.zip ] || wget https://www.sourcecode.se/sokoban/download/Levels.zip
unzip Levels.zip
./multiset.sh
./slc2htm.sh *.slc
rm -f *.slc
sed -i 's| .get 39000.*||' /usr/share/applications/Sokoban.desktop
