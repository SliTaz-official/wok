#!/bin/sh

#usage:
# copy /boot/isolinux/* <version>
# remove *.cfg
# copy then update /boot/isolinux/isolinux.cfg <version>core.cfg

cd $(dirname $0)

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

directlinks()
{
	mkdir $1/$2
	ln -s .. $1/$2/$1
	ln -s ../$2.cfg $1/$2/default
	ln -s ../../pxelinux.0 $1/$2/pxelinux.0
	ln -s . $1/$2/pxelinux.cfg
	[ -e $1/boot ] || ln -s ../../boot $1/boot
}
for version in cooking $(ls ../boot | grep 0$) ; do

[ "$version" = "1.0" ] && continue
echo -n "Building $version"
for i in splash.lss isolinux.msg core.cfg ; do
	[ -s $version/$i ] && continue
	echo -n " $version/$i not found !"
	false
	status
	continue 2
done
if ! grep -q $version/splash.lss $version/isolinux.msg ; then
	echo "WARNING: please update $version/isolinux.msg with $version/splash.lss"
fi
rm -f $version/*-*.cfg
( cd ../boot/$version ; ls rootfs-*.gz 2> /dev/null ) | \
sed 's/rootfs-\(.*\).gz/\1/' | while read flavor; do
	lowcased=$(echo $flavor | tr [A-Z] [a-z])
	if [ "$lowcased" != "$flavor" ]; then
		echo ""
		echo "Warning : renaming ../boot/$version/rootfs-$flavor.gz to ../boot/$version/rootfs-$lowcased.gz"
		mv ../boot/$version/rootfs-$flavor.gz ../boot/$version/rootfs-$lowcased.gz
		flavor=$lowcased
	fi
    	[ -f $version/$flavor.cfg ] && continue
        cp $version/core.cfg $version/$flavor.cfg
	sed -i -e "s/core-common/$flavor-common/" \
	       -e "s/^label slitaz$/say Using $flavor flavor.\nlabel slitaz/" \
	       -e "s/rootfs.gz/rootfs-$flavor.gz/" $version/$flavor.cfg
	directlinks $version $flavor
done
for flavor in $(cd $version ; ls *.cfg | sed 's/.cfg//') ; do
  echo -n " $flavor"
  cat > $version/$flavor-common.cfg <<EOT
default slitaz
label deCH
	config $version/$flavor-de_CH.cfg
label frCH
	config $version/$flavor-fr_CH.cfg
label reboot
	com32 reboot.c32

implicit 0	
prompt 1	
timeout 80
F1 $version/help.txt
F2 $version/options.txt
F3 $version/isolinux.msg
F4 $version/display.txt
F5 $version/enhelp.txt
F6 $version/enopts.txt

EOT
  while read cfg kbd loc ; do
    if [ ! -f $version/$cfg.kbd ]; then
    	echo ""
	echo "Not found: $version/$cfg.kbd"
    fi
    info="Now using $kbd keyboard and $loc locale."
    sed -e "s/^display/kbdmap $version\/$cfg.kbd\ndisplay/" \
        -e "s/^label slitaz$/say $info\nlabel slitaz/" \
        -e "s/gz/gz lang=$loc kmap=$kbd/" \
        < $version/$flavor.cfg > $version/$flavor-$cfg.cfg
    cat >> $version/$flavor-common.cfg <<EOT
label $cfg
	config $version/$flavor-$cfg.cfg
EOT
  done <<EOT
be    be-latin1    fr_FR
br    br-abnt2     pt_PT
ca    cf           fr_FR
de    de-latin1    de_DE
de_CH de_CH-latin1 de_DE
en    uk           C
es    es           es_ES
fi    fi-latin1    fi
fr    fr-latin1    fr_FR
fr_CH fr_CH-latin1 fr_FR
hu    hu           hu
it    it           it_IT
jp    jp106        jp_JP
pt    pt-latin1    pt_PT
ru    ru           ru_RU
us    us           C
EOT
done
status

done

echo -n "Building 1.0"
rm -f 1.0/*-*.cfg
( cd ../boot/1.0 ; ls rootfs-*.gz 2> /dev/null ) | \
sed 's/rootfs-\(.*\).gz/\1/' | while read flavor; do
    	[ -f 1.0/$flavor.cfg ] && continue
        cp 1.0/core.cfg 1.0/$flavor.cfg
	sed -i -e "s/core-common/$flavor-common/" \
	       -e "s/rootfs.gz/rootfs-$flavor.gz/" 1.0/$flavor.cfg
	directlinks 1.0 $flavor
done
directlinks 1.0 core
for flavor in $(cd 1.0; ls *.cfg | sed 's/.cfg//') ; do
  echo -n " $flavor"
  cat > 1.0/$flavor-common.cfg <<EOT
default slitaz

label def
	config 1.0/$flavor.cfg

label reboot
	com32 reboot.c32

implicit 0	
prompt 1	
timeout 80
F1 1.0/help.txt
F2 1.0/options.txt
F3 1.0/isolinux.msg
F4 1.0/display.txt
EOT
  while read cfg kbd loc ; do
    if [ ! -f 1.0/$cfg.kbd ]; then
    	echo ""
	echo "Not found: 1.0/$cfg.kbd"
    fi
    sed -e "s/^display/KBDMAP 1.0\/$cfg.kbd\ndisplay/" \
        -e "s/gz/gz lang=$loc kmap=$kbd/" \
        < 1.0/$flavor.cfg > 1.0/$flavor-$cfg.cfg
    cat >> 1.0/$flavor-common.cfg <<EOT
label $cfg
	config 1.0/$flavor-$cfg.cfg
EOT
  done <<EOT
be    be    fr
ca    ca    fr
de_CH fr_CH fr_CH
en    en    en
es    es    en
fr    fr    fr
fr_CH fr_CH fr_CH
it    it    en
us    us    en
EOT
done
status
