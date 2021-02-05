#!/bin/sh

cd $(dirname $0)
for i in ?? ; do
	for j in $i/?? ; do
		for k in $j/* ; do
			[ -f $k ] || continue
			grep -qs '"expire_date":' $k || continue
			[ $(sed 's/.*"expire_date":\([0-9]*\).*/\1/' $k) -lt \
			  $(date +%s) ] && rm -rf $k*
		done
		rmdir $j
	done
	rmdir $i
done 2>/dev/null
