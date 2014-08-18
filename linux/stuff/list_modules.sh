#!/bin/sh
# list_modules.sh: list Linux kernel modules for SliTaz GNU/Linux.
# 2008/06/07 <pascal.bellard@slitaz.org> - GNU General Public License.
#

find_modules() {
	find $install/lib/modules/*-slitaz*/kernel/$1 -type f -exec basename {} \;
}

if [ -z "$1" ] ; then
  cat 1>&2 <<EOT
  
\033[1musage:\033[0m `basename $0` path/to/kernel-modules-subtrees
exemple `basename $0` drivers/net/wireless >list

EOT
  exit 1
fi

if [ -z "$(ls -d $install/lib/modules/*-slitaz*/kernel/$1 2> /dev/null)" ] ; then
  cat 1>&2 <<EOT
  
Error : $1 does not exist.

EOT
  exit 1
fi

for tree in $@; do
    for module in $(find_modules $tree) ; do
        grep /$module: $install/lib/modules/*-slitaz*/modules.dep ||
        find $install/lib/modules/*-slitaz*/kernel/$tree -name $module
    done | awk '{ for (i = 1; i <= NF; i++)  print $i; }'
done | sort | uniq | sed -e 's,.*slitaz[64]*/,,' -e 's,^kernel/,,' -e 's/:$//' | \
while read module; do
    grep -qs ^$module$ $src/../tmp/modules.list && continue
    if [ ! -f $install/lib/modules/*-slitaz*/kernel/$module ]; then
	(cd $install/lib/modules/*-slitaz*/kernel; find -name $(basename $module) )
    else
        echo $module
    fi
done
