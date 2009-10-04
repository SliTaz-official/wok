#!/bin/sh
# slitaz-wrap.sh - sh slitaz core wrapper for xarchive frontend
# Copyright (C) 2005 Lee Bigelow <ligelowbee@yahoo.com> 
# Copyright (C) 2009 Pascal Bellard <pascal.bellard@slitaz.org> 
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# set up exit status variables
E_UNSUPPORTED=65

# Supported file extentions for tar 
TAR_EXTS="tar"
GZIP_EXTS="tar.gz tgz"
LZMA_EXTS="tar.lz tar.lzma tlz"
BZIP2_EXTS="tar.bz tbz tar.bz2 tbz2"
XZ_EXTS="tar.xz txz"
COMPRESS_EXTS="tar.z tar.Z"
IPK_EXTS="ipk"
CPIO_EXTS="cpio"
CPIOGZ_EXTS="cpio.gz"
CPIOXZ_EXTS="cpio.xz"
ZIP_EXTS="zip cbz jar"
RPM_EXTS="rpm"
DEB_EXTS="deb"
TAZPKG_EXTS="tazpkg spkg"
ISO_EXTS="iso"
SQUASHFS_EXTS="sqfs squashfs"
CROMFS_EXTS="cromfs"
FS_EXTS="ext2 ext3 dos fat vfat xfs fd fs loop"
CLOOP_EXTS="cloop"
RAR_EXTS="rar cbr"
LHA_EXTS="lha lzh lzs"
LZO_EXTS="lzo"

# Setup awk program
AWK_PROGS="mawk gawk awk"
AWK_PROG=""
for awkprog in $AWK_PROGS; do
    if [ "$(which $awkprog)" ]; then
        AWK_PROG="$awkprog"
        break
    fi
done

# Setup xterm program to use
XTERM_PROGS="xterm rxvt xvt wterm aterm Eterm"
XTERM_PROG=""
for xtermprog in $XTERM_PROGS; do
    if [ "$(which $xtermprog)" ]; then
        XTERM_PROG="$xtermprog"
        break
    fi
done

# setup variables opt and archive.
# the shifting will leave the files passed as
# all the remaining args "$@"
opt="$1"
test -z $1 || shift 1
archive="$1"
test -z $1 || shift 1

tazpkg2cpio()
{
	tmpcpio="$(mktemp -d -t tmpcpio.XXXXXX)"
	cd $tmpcpio
	cpio -i fs.cpio.gz > /dev/null < "$1"
	zcat fs.cpio.gz
	cd -
	rm -rf $tmpcpio
}

decompress_ipk()
{
	tar xOzf "$1" ./data.tar.gz | gzip -dc
}

# set up compression variables for our compression functions. 
# translate archive name to lower case for pattern matching.
# use compressor -c option to output to stdout and direct it where we want
lc_archive="$(echo $archive|tr [:upper:] [:lower:])"
DECOMPRESS="cat"
COMPRESS="cat"
for ext in $IPK_EXTS; do
    if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        DECOMPRESS="decompress_ipk"
    fi
done
for ext in $GZIP_EXTS $CPIOGZ_EXTS; do
    if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        DECOMPRESS="gzip -dc"
        COMPRESS="gzip -c"
    fi
done
for ext in $BZIP2_EXTS; do
    if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        DECOMPRESS="bunzip2 -c" 
        COMPRESS="bzip2 -c"
    fi
done
for ext in $LZMA_EXTS; do
    if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        DECOMPRESS="unlzma -c" 
        COMPRESS="lzma e -si -so"
    fi
done
for ext in $XZ_EXTS $CPIOXZ_EXTS; do
    if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        [ -x /usr/bin/rx ] || exit $E_UNSUPPORTED
        DECOMPRESS="xz -dc"
        COMPRESS="xz -c"
    fi
done
for ext in $COMPRESS_EXTS; do
    if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        DECOMPRESS="uncompress -dc" 
        COMPRESS="compress -c"
    fi
done

do_decompress()
{
	$DECOMPRESS "$1"
}

# Compression functions
decompress_func()
{
    if [ "$DECOMPRESS" != "cat" ]; then 
        tmpname="$(mktemp -t tartmp.XXXXXX)"
        if [ -f "$archive" ]; then 
            $DECOMPRESS "$archive" > "$tmpname" 
        fi
        # store old name for when we recompress
        oldarch="$archive"
        # change working file to decompressed tmp 
        archive="$tmpname"
    fi
}

compress_func()
{
    if [ "$COMPRESS" != "cat" ] && [ "$oldarch" ]; then
        [ -f "$oldarch" ] && rm "$oldarch"
        if $COMPRESS < "$archive" > "$oldarch"; then
            rm "$archive"
        fi
    fi
}

not_busybox()
{
    case "$(readlink $(which $1))" in
    *busybox*) return 1;;
    esac
    return 0
}

addtar()
{
	tar -cf - $@
}

extracttar()
{
	tar -xf -
}

addcpio()
{
	find $@ | cpio -o -H newc
}

extractcpio()
{
	cpio -id > /dev/null
}

add_file()
{
	( cd $2 ; tar -cf - $1 ) | tar -xf -
}

remove_file()
{
	rm -rf ./$1
}

update_tar_cpio()
{
    action=$1
    shift
    tardir="$(dirname "$archive")"
    if [ $(expr "$lc_archive" : ".*\."$BZIP2_EXTS"$") -gt 0 ]; then
         [ "$(which bzip2)" ] || return
    fi
    if not_busybox tar && [ "$action" != "new_archive" ]; then
	for ext in $TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $XZ_EXTS \
		   $COMPRESS_EXTS $LZMA_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	        decompress_func
		case "$action" in
		remove_file)
			tar --delete -f "$archive" "$@";;
		add_file)
			cd "$tardir"
			while [ -n "$1" ]; do
			    tar -rf "$archive" "${1#$tardir/}"
			done;;
		esac
		status=$?
		compress_func
		exit $status
            fi
	done
    fi
    while read add extract exts; do
      for ext in $exts; do
        if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    if [ "$action" = "new_archive" ]; then
	        decompress_func
		cd "$tardir"
		$add "${1#$tardir/}" > "$archive"
		status=$?
		compress_func
		exit $status
	    fi
            tmptar="$(mktemp -d -t tartmp.XXXXXX)"
	    here="$(pwd)"
	    cd $tmptar
            $DECOMPRESS "$archive" | $extract
            status=$?
	    if [ $status -eq 0 -a -n "$1" ]; then
                while [ "$1" ]; do
		    	$action "${1#$tardir/}" $here
			shift
		done
		$add $(ls -a | grep -v ^\.$  | grep -v ^\.\.$) | \
			$COMPRESS > "$archive"
                status=$?
	    fi
	    cd $here
	    rm -rf $tmptar
	    exit $status
	fi
      done
    done <<EOT
addtar	extracttar   $TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $XZ_EXTS $COMPRESS_EXTS $LZMA_EXTS
addcpio	extractcpio  $CPIO_EXTS $CPIOGZ_EXTS $CPIOXZ_EXTS
EOT
}

loop_fs()
{
    tmpfs="$(mktemp -d -t fstmp.XXXXXX)"
    umnt="umount -d"
    ext=${lc_archive##*.}
    case " $CROMFS_EXTS " in 
    *\ $ext\ *) umnt="fusermount -u"
    		cromfs-driver "$archive" $tmpfs;;
    esac
    case " $CLOOP_EXTS " in
    *\ $ext\ *) mount -o loop=/dev/cloop,ro "$archive" $tmpfs;;
    esac
    case " $FS_EXTS " in 
    *\ $ext\ *) mount -o loop,rw "$archive" $tmpfs;;
    esac
    case " $ISO_EXTS $SQUASHFS_EXTS " in 
    *\ $ext\ *) mount -o loop,ro "$archive" $tmpfs;;
    esac
    rmdir $tmpfs 2> /dev/null && exit $E_UNSUPPORTED
    cmd=$1
    shift
    case "$cmd" in
    stat)	find $tmpfs | while read f; do
    		    [ "$f" = "$tmpfs" ] && continue
		    link="-"
		    [ -L "$f" ] && link=$(readlink "$f")
		    date=$(stat -c "%y" $f | awk \
		    	'{ printf "%s;%s\n",$1,substr($2,0,8)}')
		    echo "${f#$tmpfs/};$(stat -c "%s;%A;%U;%G" $f);$date;$link"
    		done;;
    copy)	if [ -z "$1" ]; then
    		    ( cd $tmpfs ; tar cf - . ) | tar xf -
    		else
		    while [ -n "$1" ]; do
    			( cd $tmpfs ; tar cf - "$1" ) | tar xf -
			shift;
		    done
		fi;;
    add)	tar cf - "$@" | ( cd $tmpfs ; tar xf - );;
    remove)	while [ -n "$1" ]; do
    			rm -rf $tmpfs/$1
    		done;;
    esac
    $umnt $tmpfs
    rmdir $tmpfs
    exit 0
}

# the option switches
case "$opt" in
    -i) # info: output supported extentions for progs that exist
        for ext in $TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $COMPRESS_EXTS $LZMA_EXTS \
                   $CPIO_EXTS $CPIOGZ_EXTS $ZIP_EXTS $DEB_EXTS $RPM_EXTS \
                   $TAZPKG_EXTS $ISO_EXTS $FS_EXTS $IPK_EXTS; do
            printf "%s;" $ext
            if [ "$ext" = "zip" -a ! "$(which zip)" ]; then
                echo warning: zip not found, extract only >/dev/stderr
            fi
        done
        [ -x /usr/bin/xz ] && for ext in $XZ_EXTS $CPIOXZ_EXTS; do
            printf "%s;" $ext
        done
	while read mod exts; do
	    [ -f /lib/modules/$(uname -r)/kernel/$mod ] || continue
	    for ext in $exts; do
                printf "%s;" $ext
	    done
	done <<EOT
fs/squashfs/squashfs.ko	$SQUASHFS_EXTS
drivers/block/cloop.ko	$CLOOP_EXTS
EOT
	while read exe exts; do
            [ "$(which $exe)" ] || continue
	    for ext in $exts; do
                printf "%s;" $ext
	    done
	done <<EOT
cromfs-driver	$CROMFS_EXTS
rar		$RAR_EXTS
unace		ace
arj		arj
7za		7z
lha		$LHA_EXTS
lzop		$LZO_EXTS
EOT
        printf "\n"
        exit
        ;;

    -o) # open: mangle output of tar cmd for xarchive 
	while read cmd filter exts; do
            for ext in $exts; do
        # format of cpio output:
# lrwxrwxrwx USR/GRP       0 2005-05-12 00:32:03 file -> /path/to/link
# -rw-r--r-- USR/GRP    6622 2005-04-22 12:29:14 file 
# 1          2          3    4          5        6
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                $cmd "$archive" | $filter | $AWK_PROG '
        {
          attr=$1
          split($2,ids,"/") #split up the 2nd field to get uid/gid
          uid=ids[1]
          gid=ids[2]
          size=$3
          date=$4
          time=$5
          
          #this method works with filenames that start with a space (evil!)
          #split line a time and a space
          split($0,linesplit, $5 " ")
          #then split the second item (name&link) at the space arrow space
          split(linesplit[2], nlsplit, " -> ")

          name=nlsplit[1]
          link=nlsplit[2]

          if (! link) {link="-"} #if there was no link set it to a dash

          if (name != "" && uid != "blocks") printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
                exit 0
	    fi
        done
        done <<EOT
do_decompress	cpio\ -tv	$CPIO_EXTS $CPIOGZ_EXTS $CPIOXZ_EXTS
do_decompress	tar\ -tvf\ -	$TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $XZ_EXTS $COMPRESS_EXTS $LZMA_EXTS $IPK_EXTS
rpm2cpio	cpio\ -tv	$RPM_EXTS
tazpkg2cpio	cpio\ -tv	$TAZPKG_EXTS
EOT
        for ext in $ZIP_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
		if [ "$(which zipinfo)" ]; then
                    # format of zipinfo -T -s-h- output:
                    # -rw-r--r--  2.3 unx    11512 tx defN YYYYMMDD.HHMMSS file 
                    # 1           2   3      4     5  6    7               8
                    zipinfo -T -s-h-t "$archive" | $AWK_PROG -v uuid=$(id -u -n) '
        {
          attr=$1; size=$4
          
          year=substr($7,1,4)
          month=substr($7,5,2)
          day=substr($7,7,2)
          date=year "-" month "-" day

          hours=substr($7,10,2)
          mins=substr($7,12,2)
          secs=substr($7,14,2)
          time=hours ":" mins ":" secs

          uid=uuid; gid=uuid; link="-"
          #split line at the time and a space, second item is our name
          split($0, linesplit, ($7 " "))
          name=linesplit[2]
          printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'            
                    exit 0
		else
                    # format of unzip -l output:
                    # 6622 2005-04-22 12:29:14 file 
                    # 1    2          3        4
                    unzip -l "$archive" | $AWK_PROG -v uuid=$(id -u -n) '
	BEGIN { n = 0}
        {
	  n=n+1
	  attr=""
          uid=uuid; gid=uuid
          size=$1
          date=$2
          time=$3
          
          #this method works with filenames that start with a space (evil!)
          #split line a time and a space
          split($0,linesplit, $3 "   ")
          #then split the second item (name&link) at the space arrow space
          split(linesplit[2], nlsplit, " -> ")

          name=nlsplit[1]
          link=nlsplit[2]

          if (! link) {link="-"} #if there was no link set it to a dash

          if (name != "" && n > 3) printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
                    exit 0
		fi
	    fi
        done

        for ext in $ISO_EXTS $SQUASHFS_EXTS $CROMFS_EXTS $CLOOP_EXTS $FS_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    	loop_fs stat
            fi
	done
        for ext in $RAR_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        # format of rar output:
#-------------------------------------
# bookmarks/mozilla_bookmarks.html
#            11512     5231  45% 28-02-05 16:19 -rw-r--r-- F3F3477F m3b 2.9
#       (or  11512     5231  45% 28-02-05 16:19 .D....     00000000 m3b 2.9)
#       (or  11512     5231  45% 28-02-05 16:19 .....S     F3F3477F m3b 2.9)
#            1         2     3   4        5     6          7        8   9
#-------------------------------------
        
        rar v -c- "$archive" | $AWK_PROG -v uuid=$(id -u -n) '
        # The body of info we wish to process starts with a dashed line 
        # so set a flag to signal when to start and stop processing.
        # The name is on one line with the info on the next so toggle
        # a line flag letting us know what kinda info to get.  
        BEGIN { flag=0; line=0 }
        /^------/ { flag++; if (flag > 1) exit 0; next} #line starts with dashs
        {
          if (flag == 0) next #not in the body yet so grab the next line
          if (line == 0) #this line contains the name
          { 
            name=substr($0,2) #strip the single space from start of name
            line++  #next line will contain the info so increase the flag
            next
          }
          else #we got here so this line contains the info
          {
            size=$1
            date=$4
            time=$5
            
            #modify attributes to read more unix like if they are not
            if (index($6, "D") != 0) {attr="drwxr-xr-x"}
            else if (index($6, ".") != 0) {attr="-rw-r--r--"}
            else {attr=$6}

            uid=uuid
            gid=uuid
            link="-"

            printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
            line=0 #next line will be a name so reset the flag
          }
        }'
                exit 0
	    fi
	done
        for ext in ace; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        # format of ace output:
        # Date    ³Time ³Packed     ³Size     ³Ratio³File
        # 17.09.02³00:32³     394116³   414817³  95%³ OggDS0993.exe 
	# 1                   2         3        4    5
	unace v -c- "$archive" | $AWK_PROG -v uuid=$(id -u -n) '
        #only process lines starting with two numbers and a dot
        /^[0-9][0-9]\./ {
          date=substr($1,1,8)
          time=substr($1,10,5)
          #need to strip the funky little 3 off the end of size
          size=substr($3,1,(length($3)-1))
          
          #split line at ratio and a space, second item is our name
          split($0, linesplit, ($4 " "))
          name=linesplit[2]
          
          uid=uuid; gid=uuid; link="-"; attr="-"
          printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
                exit 0
	    fi
	done
        for ext in arj; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        # format of arj output:
        # 001) ANKETA.FRG
        #   3 MS-DOS          356        121 0.340 92-04-12 11:39:46                  1  
        
	arj v "$archive" | $AWK_PROG -v uuid=$(id -u -n) '{ 
		if (($0 ~ /^[0-9]+\) .*/)||($0 ~ /^------------ ---------- ---------- -----/)){
			if (filestr ~ /^[0-9]+\) .*/) {
				printf "%s;%d;%s;%d;%d;%02d-%02d-%02d;%02d:%02d;%s\n", file, size, perm, uid, gid, date[1], date[3], date[2], time[1], time[2], symfile
				perm=""
				file=""
				symfile=""
				filestr=""
			}
		}

		if ($0 ~ /^[0-9]+\) .*/) {
			filestr=$0
			sub(/^[0-9]*\) /, "")
			file=$0
			uid=uuid
			gid=0
		}

		if ($0 ~ /^.* [0-9]+[\t ]+[0-9]+ [0-9]\.[0-9][0-9][0-9] [0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9].*/) {
			size=$3
			split($6, date, "-")
			split($7, time, ":")
			if ($8 ~ /^[rwx-]/) {perm=$8;} else {perm="-rw-r--r--"}
		}

		if ($0 ~ /^[\t ]+SymLink -> .*/) {
			symfile = $3
			perm="l"substr(perm, 2)
		} else {symfile="-"}

		if ($0 ~ /^[\t ]+Owner: UID [0-9]+\, GID [0-9]+/) {
			uid=$3
			gid=$5
			owner=1
		}
	}'
                exit 0
	    fi
	done
        for ext in 7z; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        # format of 7za output:
	# ------------------- ----- ------------ ------------  ------------
	# 1992-04-12 11:39:46 ....A          356               ANKETA.FRG
        
	7za l "$archive" | $AWK_PROG -v uuid=$(id -u -n) '
	BEGIN { flag=0; }
	/^-------/ { flag++; if (flag > 1) exit 0; next }
	{
		if (flag == 0) next

		year=substr($1, 1, 4)
		month=substr($1, 6, 2)
		day=substr($1, 9, 2)
		time=substr($2, 1, 5)

		if (index($3, "D") != 0) {attr="drwxr-xr-x"}
		else if (index($3, ".") != 0) {attr="-rw-r--r--"}

		size=$4

		$0=substr($0, 54)
		if (NF > 1) {name=$0}
		else {name=$1}
		gsub(/\\/, "/", name)

		printf "%s;%d;%s;%d;%d;%d-%02d-%02d;%s;-\n", name, size, attr, uid, 0, year, month, day, time
	}'
                exit 0
	    fi
	done
        for ext in $LHA_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        # format of lha output:
	# Desktop/up -> ..
	# lrwxrwxrwx     0/0           0       0 ****** -lhd- 0000 2009-05-03 16:59:03 [2]

	lha v -q -v  "$archive" | $AWK_PROG '
	{
		if ($4 == "") {
          		split($0, nlsplit, " -> ")
          		name=nlsplit[1]
         		link=nlsplit[2]
       			if (! link) {link="-"}
			next
		}
		attr=$1
		ids=$2
		split($2,ids,"/") #split up the 2nd field to get uid/gid
		uid=ids[1]
		gid=ids[2]
		size=$4

		year=substr($8, 1, 4)
		month=substr($8, 6, 2)
		day=substr($8, 9, 2)
		time=substr($9, 1, 5)

		printf "%s;%d;%s;%d;%d;%d-%02d-%02d;%s;-\n", name, size, attr, uid, gid, year, month, day, time
	}'
                exit 0
	    fi
	done
        for ext in $LZO_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        # format of lzo output:
# Method         Length    Packed  Ratio     Date    Time   Name
# ------         ------    ------  -----     ----    ----   ----
# LZO1X-1           626       526  84.0%  2009-05-27 09:52  file
# LZO1X-1         10057      5675  56.4%  2005-07-25 16:26  path/file
#               -------   -------  -----                    ----
# 1               2          3     4      5          6      7
                lzop -Plv "$archive" | $AWK_PROG -v uuid=$(id -u -n) '
	BEGIN { show = 0}
        {
          if ($5 == "----" || $4 == "----") {
          	show = 1 - show
          	next
          }
	  attr="-rw-r--r--"
          uid=uuid; gid=uuid
          size=$2
          date=$5
          time=$6
          
          #this method works with filenames that start with a space (evil!)
          #split line a time and a space
          split($0,linesplit, $6 "  ")

          name=linesplit[2]
          link="-"	# links are not supported

          if (show == 1) printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
                exit 0
	    fi
	done
        exit $E_UNSUPPORTED
        ;;

    -a) # add to archive passed files
	update_tar_cpio add_file "$@"
        for ext in $FS_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    	loop_fs add "$@"
	    fi
	done
	while read exe args exts; do
	    [ "$(which $exe)" ] || continue
	    for ext in $exts; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                # we only want to add the file's basename, not
                # the full path so...
                while [ "$1" ]; do
                    cd "$(dirname "$1")"
                    $exe $args "$archive" "$(basename "$1")"
                    wrapper_status=$?
                    shift 1
                done
                exit $wrapper_status
	    fi
	    done
	done <<EOT
zip	-g\ -r		$ZIP_EXTS
rar	a		$RAR_EXTS
arj	a		arj
7za	a\ -ms=off	7z
lha	a		$LHA_EXTS
EOT
        exit $E_UNSUPPORTED
        ;;

    -n) # new: create new archive with passed files 
	update_tar_cpio new_archive "$@"
	while read exe args exts; do
	    [ "$(which $exe)" ] || continue
	    for ext in $exts; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                # create will only be passed the first file, the
                # rest will be "added" to the new archive
                cd "$(dirname "$1")"
                $exe $args "$archive" "$(basename "$1")"
	    fi
	    done
	done <<EOT
zip	-r		$ZIP_EXTS
rar	a		$RAR_EXTS
arj	a		arj
7za	a\ -ms=off	7z
lha	a		$LHA_EXTS
EOT
        exit $E_UNSUPPORTED
        ;;

    -r) # remove: from archive passed files 
	update_tar_cpio remove_file "$@"
	while read exe args exts; do
	    [ "$(which $exe)" ] || continue
	    for ext in $exts; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                $exe $args "$archive" "$@"
                exit $?
	    fi
	    done
	done <<EOT
loop_fs	remove	$FS_EXTS
zip	-d	$ZIP_EXTS
rar	d	$RAR_EXTS
arj	d	arj
lha	d	$LHA_EXTS
EOT
    	wrapper_status=0
	[ "$(which 7za)" ] && [ $(expr "$lc_archive" : ".*\.7z$") -gt 0 ] && 
	while [ "$1" ]; do
		7za l "$archive" 2>/dev/null | grep -q "[.][/]" >&/dev/null \
			&& EXFNAME=*./"$1" || EXFNAME="$1"
		7za d "$archive" "$EXFNAME" 2>&1 \
		| grep -q E_NOTIMPL &> /dev/null && {
			echo -e "Function not implemented: 7z cannot delete files from solid archive." >&2
			wrapper_status=$E_UNSUPPORTED
		}
		shift 1;
	done
        exit $E_UNSUPPORTED
        ;;

    -e) # extract: from archive passed files 
        for ext in $TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $COMPRESS_EXTS $LZMA_EXTS \
        	   $IPK_EXTS $XZ_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                # xarchive will put is the right extract dir
                # so we just have to extract.
		$DECOMPRESS "$archive" | tar -xf - "$@"
                exit $?
	    fi
	done

	while read exe exts; do
	    [ "$(which $exe)" ] || continue
	    for ext in $exts; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	        if [ -n "$1" ]; then
                    while [ "$1" ]; do
                       $exe "$archive" | cpio -idv "$1"
                       shift 1
                    done
		else
                    $exe "$archive" | cpio -idv
		fi
                exit $?
	    fi
            done
	done <<EOT
rpm2cpio	$RPM_EXTS
do_decompress	$CPIO_EXTS $CPIOGZ_EXTS $CPIOXZ_EXTS
tazpkg2cpio	$TAZPKG_EXTS
EOT

	while read exe args exts; do
	    [ "$(which $exe)" ] || continue
	    for ext in $exts; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                $exe $args "$archive" "$@"
                exit $?
	    fi
	done
	done <<EOT
loop_fs		copy	$ISO_EXTS $SQUASHFS_EXTS $CROMFS_EXTS $CLOOP_EXTS $FS_EXTS
unzip		-n	$ZIP_EXTS
dpkg-deb	-X	$DEB_EXTS
lha		x	$LHA_EXTS
lzop		-x	$LZO_EXTS
EOT
	while read exe args argpass exts; do
	    [ "$(which $exe)" ] || continue
	    for ext in $exts; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	        [ $exe != unace ] && $exe $args "$archive" "$@"
	        if [ "$?" -ne "0" ] && [ "$XTERM_PROG" ]; then
	            echo Probably password protected,
	            echo Opening an x-terminal...
	            $XTERM_PROG -e $exe $argpass "$archive" "$@"
	        fi
                exit 0
	    fi
	    done
	done <<EOT
rar	x\ -o-\ -p-	x\ -o-		$RAR_EXTS
arj	x\ -y		x\ -y\ -g?	arj
7za	x\ -y\ -p-	x\ -y		7z
unace	-UNUSED-	x\ -o\ -y	ace
EOT
        exit $E_UNSUPPORTED
        ;;

     *) echo "error, option $opt not supported"
        echo "use one of these:" 
        echo "-i                #info" 
        echo "-o archive        #open" 
        echo "-a archive files  #add" 
        echo "-n archive file   #new" 
        echo "-r archive files  #remove" 
        echo "-e archive files  #extract" 
        exit
esac
