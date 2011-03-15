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
src="$WOK/linux-libre/linux-$VERSION"

cd $src
mkdir -p $WOK/$PACKAGE/tmp
rm -f $WOK/$PACKAGE/tmp/*

echo -e "\nChecking for modules selected in .config but not in linux-libre-* pkgs"
echo "======================================================================"

# create a packaged modules list
cat ../stuff/modules-"$VERSION".list >> $WOK/$PACKAGE/tmp/pkgs-modules-"$VERSION".list 

for i in $(cd $WOK; ls -d linux-libre-*)
do
	tazpath="taz/$i-$VERSION"
	for j in $(cat $WOK/$i/$tazpath/files.list | grep ".ko.gz")
	do
		basename $j >> $WOK/$PACKAGE/tmp/pkgs-modules-"$VERSION".list	
	done 	
done
# get the original list in .config
for i in $(find $_pkg -iname "*.ko.gz") 
do
	basename $i >> $WOK/$PACKAGE/tmp/originial-"$VERSION".list
done
# compare original .config and pkged modules
for i in $(cat $WOK/$PACKAGE/tmp/originial-$VERSION.list)   
do		
	if ! grep -qs "$i" $WOK/$PACKAGE/tmp/pkgs-modules-"$VERSION".list ; then 
		modpath=`find $_pkg -iname "$i"`
		echo "Orphan module: $i"
		echo "$i : $modpath" >> $WOK/$PACKAGE/tmp/unpackaged-modules-"$VERSION".list
	fi
done
if [ -f $WOK/$PACKAGE/tmp/unpackaged-modules-"$VERSION".list ]; then
	echo "======================================================================"
	echo -e "Check linux-libre/tmp/unpackaged-modules-$VERSION.list for mod path\n"
else
	echo -e "\nAll modules are packaged\n"
	echo "======================================================================"
	echo ""
	rm -rf $WOK/$PACKAGE/tmp
fi
