#!/bin/sh
# slitaz-wrap.sh - sh slitaz core wrapper for xarchive frontend
# Copyright (C) 2005 Lee Bigelow <ligelowbee@yahoo.com> 
# Copyright (C) 2008 Pascal Bellard <pascal.bellard@slitaz.org> 
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
COMPRESS_EXTS="tar.z tar.Z"
IPK_EXTS="ipk"
CPIO_EXTS="cpio"
CPIOGZ_EXTS="cpio.gz"
ZIP_EXTS="zip cbz jar"
RPM_EXTS="rpm"
DEB_EXTS="deb"
TAZPKG_EXTS="tazpkg"
ISO_EXTS="iso"
SQUASHFS_EXTS="sqfs squashfs"
CROMFS_EXTS="cromfs"
FS_EXTS="ext2 ext3 dos fat vfat fd fs loop"
CLOOP_EXTS="cloop"

# Setup awk program
AWK_PROGS="mawk gawk awk"
AWK_PROG=""
for awkprog in $AWK_PROGS; do
    if [ "$(which $awkprog)" ]; then
        AWK_PROG="$awkprog"
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
for ext in $COMPRESS_EXTS; do
    if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
        DECOMPRESS="uncompress -dc" 
        COMPRESS="compress -c"
    fi
done

# Compression functions
decompress_func()
{
    if [ "$DECOMPRESS" ]; then 
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
    if [ "$COMPRESS" ] && [ "$oldarch" ]; then
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
    [ $(expr "$lc_archive" : ".*\."$BZIP2_EXTS"$") -gt 0 ] && ! which bzip2 && return
    for ext in $TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $COMPRESS_EXTS $LZMA_EXTS; do
        if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    if [ "$action" = "new_archive" ]; then
	        decompress_func
		cd "$tardir"
		tar -cf "$archive" "${1#$tardir/}"
		status=$?
		compress_func
		exit $status
	    fi
	    if not_busybox tar; then
	        decompress_func
		case "$action" in
		remove_file)
			tar --delete -f "$archive" "$@";;
		add_file)
			cd "$tardir"
			tar -rf "$archive" "${1#$tardir/}";;
		*)	false;;
		esac
		status=$?
		compress_func
		exit $status
	    fi
            tmptar="$(mktemp -d -t tartmp.XXXXXX)"
	    here="$(pwd)"
	    cd $tmptar
            $DECOMPRESS < "$archive" | tar -xf -
            status=$?
	    if [ $status -eq 0 -a -n "$1" ]; then
                    while [ "$1" ]; do
		    	$action "${1#$tardir/}" $here
			shift
		    done
		tar -cf - $(ls -a | grep -v ^\.$  | grep -v ^\.\.$) | \
			$COMPRESS > "$archive"
                status=$?
	    fi
	    cd $here
	    rm -rf $tmptar
	    exit $status
	fi
    done
    for ext in $CPIO_EXTS $CPIOGZ_EXTS; do
        if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    if [ "$action" = "new_archive" ]; then
	        decompress_func
		cd "$tardir"
		echo "${1#$tardir/}" | cpio -o -H newc > "$archive"
		status=$?
		compress_func
		exit $status
	    fi
            tmpcpio="$(mktemp -d -t cpiotmp.XXXXXX)"
	    here="$(pwd)"
	    cd $tmpcpio
            $DECOMPRESS "$archive" | cpio -id > /dev/null
            status=$?
	    if [ $status -eq 0 -a -n "$1" ]; then
                    while [ "$1" ]; do
		    	$action "${1#$tardir/}" $here
			shift
		    done
		find . | cpio -o -H newc | $COMPRESS > "$archive"
                status=$?
	    fi
	    cd $here
	    rm -rf $tmpcpio
	    exit $status
	fi
    done
}

loop_fs()
{
    tmpfs="$(mktemp -d -t fstmp.XXXXXX)"
    umnt="umount -d"
    case " $CLOOP_EXTS " in
    \ $1\ ) mount -o loop=/dev/cloop,ro "$archive" $tmpfs;;
    esac
    case " $FS_EXTS " in 
    \ $1\ ) mount -o loop,rw "$archive" $tmpfs;;
    esac
    case " $ISO_EXTS " in 
    \ $1\ ) mount -o loop,ro -t iso9660 "$archive" $tmpfs;;
    esac
    case " $SQUASHFS_EXTS " in 
    \ $1\ ) mount -o loop,ro -t squashfs "$archive" $tmpfs;;
    esac
    case " $CROMFS_EXTS " in 
    \ $1\ ) cromfs-driver "$archive" $tmpfs; umnt="fusermount -u";;
    esac
    case "$2" in
    stat)	find $tmpfs | while read f; do
    		    [ "$f" = "$tmpfs" ] && continue
		    link="-"
		    [ -L "$f" ] && link=$(readlink "$f")
		    date=$(stat -c "%y" $f | awk \
		    	'{ printf "%s;%s\n",$1,substr($2,0,8)}')
		    echo "${f#$tmpfs/};$(stat -c "%s;%A;%U;%G" $f);$date;$link"
    		done;;
    copy)	if [ -z "$3" ]; then
    		    ( cd $tmpfs ; tar cf - . ) | tar xf -
    		else
		    while [ -n "$3" ]; do
    			( cd $tmpfs ; tar cf - "$3" ) | tar xf -
			shift;
		    done
		fi;;
    add)	tar cf - "$@" | ( cd $tmpfs ; tar xf - );;
    remove)	while [ -n "$3" ]; do
    			rm -rf $tmpfs/$3
    		done;;
    esac
    $umnt $tmpfs
    rmdir $tmpfs
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
	[ -d /lib/modules/$(uname -r)/kernel/fs/squashfs/squashfs.ko ] && \
	for ext in $SQUASHFS_EXTS; do
            printf "%s;" $ext
	done
	[ -x /bin/cromfs-driver ] && for ext in $CROMFS_EXTS; do
            printf "%s;" $ext
	done
	[ -d /lib/modules/$(uname -r)/kernel/drivers/block/cloop.ko ] && \
	for ext in $CLOOP_EXTS; do
            printf "%s;" $ext
	done
        printf "\n"
        exit
        ;;

    -o) # open: mangle output of tar cmd for xarchive 
        for ext in $TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $COMPRESS_EXTS $LZMA_EXTS \
        	   $IPK_EXTS; do
        # format of tar output:
# lrwxrwxrwx USR/GRP       0 2005-05-12 00:32:03 file -> /path/to/link
# -rw-r--r-- USR/GRP    6622 2005-04-22 12:29:14 file 
# 1          2          3    4          5        6
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
		$DECOMPRESS "$archive" | tar -tvf - | $AWK_PROG '
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

          printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
                exit
	    fi
        done

        for ext in $CPIO_EXTS $CPIOGZ_EXTS; do
        # format of cpio output:
# lrwxrwxrwx USR/GRP       0 2005-05-12 00:32:03 file -> /path/to/link
# -rw-r--r-- USR/GRP    6622 2005-04-22 12:29:14 file 
# 1          2          3    4          5        6
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                $DECOMPRESS "$archive" | cpio -tv | $AWK_PROG '
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
                exit
	    fi
        done

        for ext in $ZIP_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	        if which zipinfo; then
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
                    exit
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
                    exit
		fi
	    fi
        done

        for ext in $RPM_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                rpm2cpio "$archive" | cpio -tv | $AWK_PROG '
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

          name=substr(nlsplit[1],2)
          link=nlsplit[2]

          if (! link) {link="-"} #if there was no link set it to a dash

          if (name != "" && uid != "blocks") printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
                exit
	    fi
        done

        for ext in $DEB_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                dpkg-deb -c "$archive" | $AWK_PROG '
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

          name=substr(nlsplit[1],2)
          link=nlsplit[2]

          if (! link) {link="-"} #if there was no link set it to a dash

          printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
                exit
	    fi
        done

        for ext in $TAZPKG_EXTS; do
        # format of cpio output:
# lrwxrwxrwx USR/GRP       0 2005-05-12 00:32:03 file -> /path/to/link
# -rw-r--r-- USR/GRP    6622 2005-04-22 12:29:14 file 
# 1          2          3    4          5        6
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                tmpcpio="$(mktemp -d -t cpiotmp.XXXXXX)"
		here="$(pwd)"
		cd $tmpcpio
		cpio -i fs.cpio.gz > /dev/null < "$archive"
                zcat fs.cpio.gz | cpio -tv | $AWK_PROG '
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

          name=substr(nlsplit[1],3)
          link=nlsplit[2]

          if (! link) {link="-"} #if there was no link set it to a dash

          if (name != "" && uid != "blocks") printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
        }'
		cd $here
		rm -rf $tmpcpio
                exit
	    fi
        done

        for ext in $ISO_EXTS $SQUASHFS_EXTS $CROMFS_EXTS $CLOOP_EXTS $FS_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    	loop_fs $ext stat
                exit
            fi
	done
        exit $E_UNSUPPORTED
        ;;

    -a) # add to archive passed files
	update_tar_cpio add_file "$@"
        for ext in $FS_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    	loop_fs $ext add "$@"
                exit 0
	    fi
	done
        which zip >/dev/null && for ext in $ZIP_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                # we only want to add the file's basename, not
                # the full path so...
                while [ "$1" ]; do
                    cd "$(dirname "$1")"
                    zip -g -r "$archive" "$(basename "$1")"
                    wrapper_status=$?
                    shift 1
                done
                exit $wrapper_status
	    fi
	done
        exit $E_UNSUPPORTED
        ;;

    -n) # new: create new archive with passed files 
	update_tar_cpio new_archive "$@"
        which zip >/dev/null && for ext in $ZIP_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                # create will only be passed the first file, the
                # rest will be "added" to the new archive
                cd "$(dirname "$1")"
                zip -r "$archive" "$(basename "$1")"
	    fi
	done
        exit $E_UNSUPPORTED
        ;;

    -r) # remove: from archive passed files 
	update_tar_cpio remove_file "$@"
        for ext in $FS_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    	loop_fs $ext remove "$@"
                exit 0
	    fi
	done
        which zip >/dev/null && for ext in $ZIP_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                zip -d "$archive" "$@"
	    fi
	done
        exit $E_UNSUPPORTED
        ;;

    -e) # extract: from archive passed files 
        for ext in $TAR_EXTS $GZIP_EXTS $BZIP2_EXTS $COMPRESS_EXTS $LZMA_EXTS \
        	   $IPK_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                # xarchive will put is the right extract dir
                # so we just have to extract.
		$DECOMPRESS "$archive" | tar -xf - "$@"
                exit $?
	    fi
	done
        for ext in $CPIO_EXTS $CPIOGZ_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	        if [ -n "$1" ]; then
                    while [ "$1" ]; do
                       $DECOMPRESS "$archive" | cpio -idv "$1"
                       shift 1
                    done
		else
                    $DECOMPRESS "$archive" | cpio -idv
		fi
                exit $?
	    fi
        done
        for ext in $ZIP_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                # xarchive will put is the right extract dir
                # so we just have to extract.
                unzip -n "$archive" "$@"
                exit $?
	    fi
	done
        for ext in $RPM_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	        if [ -n "$1" ]; then
                    while [ "$1" ]; do
                       rpm2cpio "$archive" | cpio -idv "$1"
                       shift 1
                    done
		else
                    rpm2cpio "$archive" | cpio -idv
		fi
                exit $?
	    fi
        done

        for ext in $DEB_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                dpkg-deb -X "$archive" "$@"
                exit $?
	    fi
	done
        for ext in $TAZPKG_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
                tmpcpio="$(mktemp -d -t cpiotmp.XXXXXX)"
		here="$(pwd)"
		cd $tmpcpio
		cpio -i < "$archive" > /dev/null
		zcat fs.cpio.gz | cpio -id > /dev/null
                status=$?
	        if [ -n "$1" ]; then
                    while [ "$1" ]; do
		        dir=$(dirname "$here/$1")
			mkdir -p "$dir" 2> /dev/null
		        mv "fs/$1" "$dir" 2> /dev/null
		    done
		else
		    mv fs/* fs/.* $here 2> /dev/null
		fi
		cd $here
		rm -rf $tmpcpio
		exit $status
	    fi
	done
        for ext in $ISO_EXTS $SQUASHFS_EXTS $CROMFS_EXTS $CLOOP_EXTS $FS_EXTS; do
            if [ $(expr "$lc_archive" : ".*\."$ext"$") -gt 0 ]; then
	    	loop_fs $ext copy "$@"
                exit 0
            fi
	done
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
