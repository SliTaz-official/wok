#!/bin/sh
# Echo any module in kernel .config that's not added to one of linux-* pkgs
# 2009/06/18 <jozee@slitaz.org> - GNU General Public License.
#
	. /etc/tazwok.conf
	VERSION=`grep  ^VERSION= $WOK/linux/receipt | cut -d "=" -f2 | sed -e 's/"//g'`
	src="$WOK/linux/linux-$VERSION"
	
	cd $src
	mkdir -p ../stuff/tmp
	rm -f ../stuff/tmp/* # clean up
	# create a packaged modules list
	cat ../stuff/modules-"$VERSION".list >> ../stuff/tmp/pkgs-modules-"$VERSION".list 
	
	for i in $(cd $WOK; ls -d linux-*)
	do
		tazpath="taz/$i-$VERSION"
		for j in $(cat $WOK/$i/$tazpath/files.list | grep ".ko.gz")
		do
			basename $j >> ../stuff/tmp/pkgs-modules-"$VERSION".list	
		done 	
	done
	# get the original list in .config
	for i in $(find $_pkg -iname "*.ko.gz") 
	do
		basename $i >> ../stuff/tmp/originial-"$VERSION".list
	done
	# compare original .config and pkged modules
	for i in $(cat ../stuff/tmp/originial-$VERSION.list)   
	do		
		if ! grep -qs "$i" ../stuff/tmp/pkgs-modules-"$VERSION".list ; then 
			modpath=`find $_pkg -iname "$i"`
			echo "$i" >> ../stuff/tmp/unpackaged-modules-"$VERSION".list
			echo "$i : $modpath" >> ../stuff/tmp/unpackaged-modules-"$VERSION"-full.list
		fi
	done
	if [ -f ../stuff/tmp/unpackaged-modules-"$VERSION".list ]; then
		echo "======================================================================"
		echo " These modules selected in .config were not categorized in linux-* pkgs:"
		cat ../stuff/tmp/unpackaged-modules-$VERSION.list 
		echo "======================================================================"
		echo -e "Check linux/stuff/tmp/unpackaged-modules-$VERSION-full.list to see\n"
	else
		rm -r ../stuff/tmp
	fi
	
