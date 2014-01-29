#!/bin/sh
# gztazmod.sh: Compress Linux kernel modules for SliTaz GNU/Linux.
# 2007-2014 <pankso@slitaz.org> - GNU General Public License.
#
. /lib/libtaz.sh

# We do our work in the kernel version modules directory.
if [ -z "$1" ] ; then
	newline
	echo "Usage: $(basename $0) path/to/kernel-version"
	newline && exit 1
fi

if [ ! -r "$1" ] ; then
	newline
	echo -e "Error : $1 does not exist."
	newline && exit 1
fi

cd $1

# Script start.
newline
echo "Starting gztazmod.sh to build compressed kernel modules... "
newline

# Find all modules.
echo -n "Searching all modules to compress them... "
find . -name "*.ko" -exec xz '{}' \; 2> /dev/null
status
find . -name "*.ko" -exec rm '{}' \;

# Build a new temporary modules.dep.
echo -n "Building tmp.dep... "
sed 's/\.ko.[xg]z/.ko/g' modules.dep > tmp.dep
sed -i 's/\.ko.[xg]z/.ko/g' tmp.dep
sed -i 's/\.ko/.ko.xz/g' tmp.dep
status

# Destroy original modules.dep
echo -n "Destroying modules.dep... "
rm modules.dep
status

# Remove tmp.dep to modules.dep.
echo -n "Removing tmp.dep to modules.dep... "
mv tmp.dep modules.dep
status

# Script end.
newline
echo "Kernel modules `basename $1` are ready."
newline
