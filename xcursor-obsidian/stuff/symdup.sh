# substitute repeated files by symlinks
md5file=$(mktemp)
find $install -type f -exec md5sum {} \; | sort > $md5file

for md in $(uniq -d -w32 $md5file | cut -c1-32); do
	# group of similar files
	similar="$(grep $md $md5file | cut -c35-)"

	# find shortest filename
	shortest=$(echo "$similar" | cut -d' ' -f1)
	for line in $(echo $similar); do
		[ "${#line}" -lt "${#shortest}" ] && shortest="$line"
	done

	# make symlinks to the file with shortest filename
	for file in $similar; do
		[ "$shortest" != "$file" ] && ln -sf $shortest $file
	done
done
rm "$md5file"

# make all symlinks relative
symlinks -crs $install
