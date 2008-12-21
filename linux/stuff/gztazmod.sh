#!/bin/sh
# gztazmod.sh: Compress Linux kernel modules for SliTaz GNU/Linux.
# 2007/10/04 <pankso@slitaz.org> - GNU General Public License.
#

# We do our work in the kernel version modules directory.
if [ -z "$1" ] ; then
  echo ""
  echo -e "\033[1musage:\033[0m `basename $0` path/to/kernel-version"
  echo ""
  exit 1
fi

if [ ! -r "$1" ] ; then
  echo ""
  echo -e "Error : $1 does not exist."
  echo ""
  exit 1
fi

cd $1

# Status functions.
status()
{
	local CHECK=$?
	echo -en "\\033[70G[ "
	if [ $CHECK = 0 ]; then
		echo -en "\\033[1;33mOK"
	else
		echo -en "\\033[1;31mFailed"
	fi
	echo -e "\\033[0;39m ]"
}

# Script start.
echo ""
echo "Starting gztazmod.sh to build compressed kernel modules... "
echo ""

# Find all modules.
echo -n "Searching all modules to compress them... "
find . -name "*.ko" -exec lzma e '{}' '{}'.gz \; 2> /dev/null
status
find . -name "*.ko" -exec rm '{}' \;

# Build a new temporary modules.dep.
echo -n "Building tmp.dep... "
sed 's/\.ko.gz/.ko/g' modules.dep > tmp.dep
sed -i 's/\.ko.gz/.ko/g' tmp.dep
sed -i 's/\.ko/.ko.gz/g' tmp.dep
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
echo ""
echo "Kernel modules `basename $1` are ready."
echo ""
