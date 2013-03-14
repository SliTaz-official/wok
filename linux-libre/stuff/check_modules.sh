#!/bin/sh
# Echo any module in kernel .config that's not added to one of linux-libre-* pkgs
# (c) SliTaz - GNU General Public License.
# 20090618 <jozee@slitaz.org> 
# 20100528 <pankso@slitaz.org>
#
#. /etc/slitaz/slitaz.conf

#WOK=$LOCAL_REPOSITORY/wok
WOK=$(cd `dirname $0` && pwd | sed 's/wok.*/wok/')
VERSION=`grep  ^VERSION= $WOK/linux-libre/receipt | cut -d "=" -f2 | sed -e 's/"//g'`
src="$WOK/linux-libre/source/linux-libre-$VERSION"

cd $src
tmp=$WOK/${PACKAGE:-linux-libre}/tmp
mkdir -p $tmp 2>/dev/null
rm -f $tmp/*

echo -e "\nChecking for modules selected in .config but not in linux-libre-* pkgs"
echo "======================================================================"

# create a packaged modules list
cat $WOK/linux-libre/stuff/modules-"$VERSION".list >> $tmp/pkgs-modules-"$VERSION".list 

for i in $(cd $WOK; grep -l '^WANTED="linux-libre"' */receipt | sed 's|/receipt||g')
do
	tazpath="taz/$i-*"
		for j in $(cat $WOK/$i/$tazpath/files.list | grep ".ko..z")
		do
			basename $j >> $tmp/pkgs-modules-"$VERSION".list	
		done
done
# get the original list in .config
for i in $(find $_pkg -iname "*.ko.?z")
do
	basename $i
done > $tmp/original-"$VERSION".list
# compare original .config and pkged modules
for i in $(cat $tmp/original-$VERSION.list)
do
	if ! grep -qs "$i" $tmp/pkgs-modules-"$VERSION".list ; then
		modpath=`find $_pkg -iname "$i"`
		echo "Orphan module: $i"
		echo "$i : $modpath" >> $tmp/unpackaged-modules-"$VERSION".list
	fi
done
if [ -f $tmp/unpackaged-modules-"$VERSION".list ]; then
	echo "======================================================================"
	echo -e "Check linux-libre/tmp/unpackaged-modules-$VERSION.list for mod path\n"
else
	echo -e "\nAll modules are packaged\n"
	echo "======================================================================"
	echo ""
	rm -rf $tmp
fi
