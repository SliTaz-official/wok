#!/bin/sh

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

echo -n "Building cooking"
rm -f cooking/*-*.cfg
( cd ../boot/cooking ; ls rootfs-*.gz 2> /dev/null ) | \
sed 's/rootfs-\(.*\).gz/\1/' | while read flavor; do
    	[ -f cooking/$flavor.cfg ] && continue
        cp cooking/core.cfg cooking/$flavor.cfg
	sed -i -e "s/core-common/$flavor-common/" \
	       -e "s/rootfs.gz/rootfs-$flavor.gz/" cooking/$flavor.cfg
done
for flavor in $(cd cooking ; ls *.cfg | sed 's/.cfg//') ; do
  echo -n " $flavor"
  cat > cooking/$flavor-common.cfg <<EOT
default slitaz
label deCH
	config cooking/$flavor-de_CH.cfg
label frCH
	config cooking/$flavor-fr_CH.cfg
label reboot
	com32 reboot.c32

implicit 0	
prompt 1	
timeout 80
F1 cooking/help.txt
F2 cooking/options.txt
F3 cooking/isolinux.msg
F4 cooking/display.txt
F5 cooking/enhelp.txt
F6 cooking/enopts.txt

EOT
  while read cfg kbd loc ; do
    info="Now using $kbd keyboard and $loc locale."
    sed -e "s/^display/kbdmap cooking\/$cfg.kbd\ndisplay/" \
        -e "s/^label slitaz$/say $info\nlabel slitaz/" \
        -e "s/gz/gz lang=$loc kmap=$kbd/" \
        < cooking/$flavor.cfg > cooking/$flavor-$cfg.cfg
    cat >> cooking/$flavor-common.cfg <<EOT
label $cfg
	config cooking/$flavor-$cfg.cfg
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

echo -n "Building 1.0"
rm -f 1.0/*-*.cfg
( cd ../boot/1.0 ; ls rootfs-*.gz 2> /dev/null ) | \
sed 's/rootfs-\(.*\).gz/\1/' | while read flavor; do
    	[ -f 1.0/$flavor.cfg ] && continue
        cp 1.0/core.cfg 1.0/$flavor.cfg
	sed -i -e "s/core-common/$flavor-common/" \
	       -e "s/rootfs.gz/rootfs-$flavor.gz/" 1.0/$flavor.cfg
done
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
