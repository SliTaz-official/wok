#!/bin/sh
# Echo any module in kernel .config that's not added to one of linux-* pkgs
# (c) 2009-2014 SliTaz - GNU General Public License.
#

WOK=$(cd `dirname $0` && pwd | sed 's/wok.*/wok/')
VERSION=$(grep  ^VERSION= $WOK/linux/receipt | cut -d "=" -f2 | sed -e 's/"//g')
BASEVER="${VERSION:0:3}"
src="$WOK/linux/source/linux-$VERSION"

cd $src
tmp=$WOK/${PACKAGE:-linux}/tmp
mkdir -p $tmp 2>/dev/null
rm -f $tmp/*

echo -e "\nChecking for modules selected in .config but not in linux-* pkgs"
echo "======================================================================"

# create a packaged modules list
cat $WOK/linux/stuff/modules.list >> $tmp/pkgs-modules-"$VERSION".list 

for i in $(cd $WOK; grep -l '^WANTED="linux"' */receipt | sed 's|/receipt||g')
do
	tazpath="taz/$i-*"
	if [ ! $(grep -l 'linux-libre' $WOK/$i/receipt) ]; then
		for j in $(cat $WOK/$i/$tazpath/files.list | grep ".ko..z")
		do
			basename $j >> $tmp/pkgs-modules-"$VERSION".list	
		done
	fi
done
# get the original list in .config
for i in $(find $install -iname "*.ko.?z")
do
	basename $i
done > $tmp/original-"$VERSION".list
# compare original .config and pkged modules
for i in $(cat $tmp/original-$VERSION.list)
do
	if ! grep -qs "$i" $tmp/pkgs-modules-"$VERSION".list ; then
		modpath=`find $install -iname "$i"`
		echo "Orphan module: $i"
		echo "$i : $modpath" >> $tmp/unpackaged-modules-"$VERSION".list
	fi
done
if [ -f $tmp/unpackaged-modules-"$VERSION".list ]; then
	echo "======================================================================"
	echo -e "Check linux/tmp/unpackaged-modules-$VERSION.list for mod path\n"
else
	echo -e "\nAll modules are packaged\n"
	echo "======================================================================"
	echo ""
	rm -rf $tmp
fi
