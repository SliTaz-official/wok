#!/bin/sh
#
# slitaz-wrap.sh - slitaz core wrapper for xarchive frontend
# Copyright (C) 2005 Lee Bigelow <ligelowbee@yahoo.com>
# Copyright (C) 2010 Pascal Bellard <pascal.bellard@slitaz.org>
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

UNSUPPORTED=65

GZIP_EXTS="tar.gz tgz cpio.gz"
LZMA_EXTS="tar.lz tar.lzma tlz"
BZIP2_EXTS="tar.bz tbz tar.bz2 tbz2"
COMPRESS_EXTS="tar.z tar.Z"
TAR_EXTS="tar tar.gz tgz $LZMA_EXTS $BZIP2_EXTS $COMPRESS_EXTS"
XZ_EXTS="tar.xz txz"
LRZIP_EXTS="tar.lrz tlrz"
IPK_EXTS="ipk"
CPIO_EXTS="cpio cpio.gz"
CPIOXZ_EXTS="cpio.xz"
CPIOLRZIP_EXTS="cpio.lrz"
ZIP_EXTS="zip cbz jar"
RPM_EXTS="rpm"
DEB_EXTS="deb udeb"
TAZPKG_EXTS="tazpkg spkg"
ISO_EXTS="iso"
SQUASHFS_EXTS="sfs sqfs squashfs"
CROMFS_EXTS="cfs cromfs"
FS_EXTS="ext2 ext3 dos fat vfat xfs fd fs loop"
CLOOP_EXTS="cloop"
RAR_EXTS="rar cbr"
LHA_EXTS="lha lzh lzs"
LZO_EXTS="lzo"
ARJ_EXTS="arj pak arc j uc2 zoo"
_7Z_EXTS="7z bcj bcj2"

while read var progs; do
	eval $var=""
	for i in $progs; do
		[ "$(which $i)" ] || continue
		eval $var="$i"
		break
	done
done <<EOT
AWK_PROG	mawk gawk awk
XTERM_PROG	xterm rxvt xvt wterm aterm Eterm false
EOT

# the shifting will leave the files passed as all the remaining args "$@"
opt="$1"
archive="$2"
lc_ext="$(echo ${2##*.} |tr [:upper:] [:lower:])"
shift 2

tazpkg2cpio()
{
tmp="$(mktemp -d -t tmpcpio.XXXXXX)"
case "$(cd $tmp; cpio -iv < "$1")" in
*lzma) unlzma -c $tmp/fs.cpio.lzma;;
*gz)   zcat $tmp/fs.cpio.gz
esac
rm -rf $tmp
}

decompress_ipk()
{
tar xOzf "$1" ./data.tar.gz | gzip -dc
}

# variables for our compression functions.
DECOMPRESS="cat"
COMPRESS="cat"
while read d c exts; do
	case " $exts " in *\ $lc_ext\ *)
		[ "$d" == "${d% *}" -o "$(which ${d% *})" ] || exit $UNSUPPORTED
		DECOMPRESS="$d"
		COMPRESS="$c"
		[ "$(which ${c% *})" ] || COMPRESS="false"
		break
	esac
done <<EOT
unlzma\ -c		lzma\ e\ -si\ -so	$LZMA_EXTS
bunzip2\ -c		bzip2\ -c		$BZIP2_EXTS
gzip\ -dc		gzip\ -c		$GZIP_EXTS
xz\ -dc			xz\ -c			$XZ_EXTS $CPIOXZ_EXTS
lrzip\ -d		lrzip			$LRZIP_EXTS $CPIOLRZIP_EXTS
uncompress\ -dc		compress\ -c		$COMPRESS_EXTS
rpm2cpio		false			$RPM_EXTS
tazpkg2cpio		false			$TAZPKG_EXTS
decompress_ipk		false			$IPK_EXTS
EOT

decompress_func()
{
[ "$DECOMPRESS" = "cat" ] && return
tmp="$(mktemp -t tartmp.XXXXXX)"
[ -f "$archive" ] && $DECOMPRESS "$archive" > "$tmp"
# store old name for compress_func
oldarch="$archive"
# change working file
archive="$tmp"
}

compress_func()
{
status=$?
if [ "$COMPRESS" != "cat" -a -n "$oldarch" ]; then
       	[ -f "$oldarch" ] && rm "$oldarch"
       	$COMPRESS < "$archive" > "$oldarch" && rm "$archive"
fi
exit $status
}

not_busybox()
{
[ "$(basename $(readlink $(which $1)))" != "busybox" ]
}

addcpio()
{
find $@ | cpio -o -H newc
}

a_file()
{
( cd $2 ; tar -cf - $1 ) | tar -xf -
}

r_file()
{
rm -rf ./$1
}

dpkg_c()
{
dpkg-deb -c "$archive"
}

loop_fs()
{
[ "$1" = "-n" ] && retrun
cmd=$1
shift
tmp="$(mktemp -d -t fstmp.XXXXXX)"
while read command umnt exts; do
	case " $exts " in *\ $lc_ext\ *)
		$command "$archive" $tmp
		break
	esac
done <<EOT
cromfs-driver			fusermount\ -u	$CROMFS_EXTS
mount\ -o\ loop=/dev/cloop,ro	umount\ -d	$CLOOP_EXTS
mount\ -o\ loop,rw		umount\ -d	$FS_EXTS
mount\ -o\ loop,ro		umount\ -d	$ISO_EXTS $SQUASHFS_EXTS
EOT
rmdir $tmp 2> /dev/null && return
case "$cmd" in
-o)	find $tmp | while read f; do
		[ "$f" = "$tmp" ] && continue
		link="-"
		[ -L "$f" ] && link=$(readlink "$f")
		date=$(stat -c "%y" $f | $AWK_PROG \
			'{ printf "%s;%s\n",$1,substr($2,0,8)}')
		echo "${f#$tmp/};$(stat -c "%s;%A;%U;%G" $f);$date;$link"
    	done;;
-e)	( cd $tmp ; tar cf - "$@" ) | tar xf - ;;
-a)	tar cf - "$@" | ( cd $tmp ; tar xf - );;
-r)	( cd $tmp ; rm -rf "$@" )
esac
$umnt $tmp
rmdir $tmp
exit
}

update()
{
loop_fs "$@"
[ "$COMPRESS" = "false" ] && return
action=$1
shift
tardir="$(dirname "$archive")"
if not_busybox tar && [ "$action" != "-n" ]; then
	case " $TAR_EXTS $XZ_EXTS $LRZIP_EXTS " in *\ $lc_ext\ *)
		decompress_func
		case "$action" in
		-r)	tar --delete -f "$archive" "$@";;
		-a)	cd "$tardir"
			while [ -n "$1" ]; do
				tar -rf "$archive" "${1#$tardir/}"
			done
		esac
		compress_func
	esac
fi
while read add extract exts; do
	case " $exts " in *\ $lc_ext\ *)
		if [ "$action" = "-n" ]; then
			decompress_func
			cd "$tardir"
			$add "${1#$tardir/}" > "$archive"
			compress_func
		fi
		tmp="$(mktemp -d -t tartmp.XXXXXX)"
		cd $tmp
		$DECOMPRESS "$archive" | $extract
		status=$?
		if [ $status -eq 0 -a -n "$1" ]; then
			while [ "$1" ]; do
				${action#-}_file "${1#$tardir/}" $here
				shift
			done
			$add $(ls -a | grep -v ^\.$  | grep -v ^\.\.$) | \
				$COMPRESS > "$archive"
			status=$?
		fi
		cd - >/dev/null
		rm -rf $tmp
		exit $status
	esac
done <<EOT
tar\ -cf\ -	tar\ -xf\ -			$TAR_EXTS $XZ_EXTS $LRZIP_EXTS
addcpio		cpio\ -id\ >\ /dev/null		$CPIO_EXTS $CPIOXZ_EXTS $CPIOLRZIP_EXTS
EOT
}

# main: option switches
case "$opt" in
    -i) # info: output supported extentions for progs that exist
	while read exe exts; do
		[ "$(which $exe)" -o -f /lib/modules/$(uname -r)/kernel/$exe.ko ] &&
		echo -n "$exts " | sed 's/ /;/g'
	done <<EOT
tar		$TAR_EXTS $IPK_EXTS
cpio		$CPIO_EXTS $TAZPKG_EXTS
unzip		$ZIP_EXTS
dpkg-deb	$DEB_EXTS
rpm2cpio	$RPM_EXTS
mount		$ISO_EXTS $FS_EXTS
xz		$XZ_EXTS $CPIOXZ_EXTS
lrzip		$LRZIP_EXTS $CPIOLRZIP_EXTS
rar		$RAR_EXTS
unace		ace
arj		$ARJ_EXTS
7zr		$_7Z_EXTS
lha		$LHA_EXTS
lzop		$LZO_EXTS
cabextract	cab
cromfs-driver	$CROMFS_EXTS
fs/squashfs/squashfs	$SQUASHFS_EXTS
drivers/block/cloop	$CLOOP_EXTS
EOT
	echo ""
	exit
	;;
    -o) # open: mangle output for xarchive
	AWK_MISC='
BEGIN {
	attr="-"
	link="-"
	uid=uuid
	gid=uuid
}
function getlink(arg)
{
	split(arg, x, " -> ")
	name=x[1]
	link=x[2]
	if (!link) link="-"
}

function getname(arg)
{
	# works with filenames that start with a space (evil!)
	split($0,x, arg)
	getlink(x[2])
}

function getid(arg)
{
	if (uuid != "") return
	split(arg,x,"/")
	uid=x[1]
	gid=x[2]
}

function getattr(arg)
{
	attr=arg
	if (index(attr, "D") != 0) attr="drwxr-xr-x"
	else if (index(attr, ".") != 0 || attr !~ /^[rwx-]/) attr="-rw-r--r--"
}

function display()
{
	if (name != "") printf "%s;%s;%s;%s;%s;%s;%s;%s\n",name,size,attr,uid,gid,date,time,link
}

function show(arg)
{
	getid($2)
	getname(arg)
	if (uid != "blocks") display()
}'
	AWKU="$AWK_PROG -v uuid=$(id -u -n) $AWK_MISC"
	AWK="$AWK_PROG $AWK_MISC"
	while read filter exts; do
# lrwxrwxrwx USR/GRP       0 2005-05-12 00:32:03 file -> /path/to/link
		case " $exts " in *\ $lc_ext\ *)
			$DECOMPRESS "$archive" | $filter | $AWK'
{
	attr=$1
	size=$3
	date=$4
	time=$5
	show($5 " ")
}'
		esac
	done <<EOT
cpio\ -tv	$CPIO_EXTS $CPIOXZ_EXTS $CPIOLRZIP_EXTS $RPM_EXTS $TAZPKG_EXTS
tar\ -tvf\ -	$TAR_EXTS $XZ_EXTS $LRZIP_EXTS $IPK_EXTS
dpkg_c		$DEB_EXTS
EOT
	loop_fs $opt
	case " $ZIP_EXTS " in *\ $lc_ext\ *)
		if [ "$(which zipinfo)" ]; then
# -rw-r--r--  2.3 unx    11512 tx defN YYYYMMDD.HHMMSS file
			zipinfo -T -s-h-t "$archive" | $AWKU'
{
	attr=$1
	size=$4
	date=substr($7,1,4)  "-" substr($7,5,2)  "-" substr($7,7,2)
	time=substr($7,10,2) ":" substr($7,12,2) ":" substr($7,14,2)
	show($7 " ")
}'
		else
# 6622 2005-04-22 12:29:14 file
			unzip -l "$archive" | $AWKU'
/-[0-9]+-/ {
	size=$1
	date=$2
	time=$3
	show($3 "   ")
}'
		fi
	esac
# -----------+---------------------+-------
#       6622 | 22.04.2005 12:29:14 | file
	[ "$lc_ext" == "cab" ] && cabextract -q -l "$archive" | $AWKU'
/[0-9]+ |/ {
	size=$1
	date=$3
	time=$4
	show($4 " | ")
}'
	case " $RAR_EXTS " in *\ $lc_ext\ *)
#-------------------------------------
# bookmarks/mozilla_bookmarks.html
#            11512     5231  45% 28-02-05 16:19 -rw-r--r-- F3F3477F m3b 2.9
#       (or  11512     5231  45% 28-02-05 16:19 .D....     00000000 m3b 2.9)
		rar v -c- "$archive" | $AWKU'
/-[0-9]+-/ {
	getattr($6)
	size=$1
	date=$4
	time=$5
	display()
}
{
	name=substr($0,2)
}'
	esac
	case "$lc_ext" in
	ace)
# Date    �Time �Packed     �Size     �Ratio�File
# 17.09.02�00:32�     394116�   414817�  95%� OggDS0993.exe
		unace v -c- "$archive" | $AWKU'
/^[0-9][0-9]\./ {
	# strip the funky little 3 off the end of size
	size=substr($3,1,(length($3)-1))
	date=substr($1,1,8)
	time=substr($1,10,5)
	show($4 " ")
}'
		;;
	7z|bcj|bcj2)
# ------------------- ----- ------------ ------------  ------------
# 1992-04-12 11:39:46 ....A          356               ANKETA.FRG
		7zr l "$archive" | $AWKU'
/^[0-9]+-/ {
	date=$1
	time=$2
	getattr($3)
	size=$4
	$0=substr($0, 54)
	name=$1
	if (NF > 1) name=$0
	gsub(/\\/, "/", name)
	display()
}'
	esac
	case " $ARJ_EXTS " in *\ $lc_ext\ *)
# 001) ANKETA.FRG
#   3 MS-DOS          356        121 0.340 92-04-12 11:39:46                  1
		arj v "$archive" | $AWKU'
BEGIN { name="" }
/^[0-9]+\) / {
	display()
	getname($1 " ")
}
/^[\t ]+[0-9]+/ {
	size=$3
	date=$6
	time=$7
	getattr($8)
}
/^[\t ]+Owner: UID [0-9]+\, GID [0-9]+/ { uid=$3; gid=$5 }
/^[\t ]+SymLink -> / { link=$3; attr="l"substr(attr, 2) }
/^---/ { display() }
'
	esac
	case " $LHA_EXTS " in *\ $lc_ext\ *)
# Desktop/up -> ..
# lrwxrwxrwx     0/0           0       0 ****** -lhd- 0000 2009-05-03 16:59:03 [2]
		lha v -q -v  "$archive" | $AWK'
{
	if ($4 == "") { getlink($0); next }
	attr=$1
	getid($2)
	size=$4
	date=$8
	time=$9
	display()
}'
	esac
	case " $LZO_EXTS " in *\ $lc_ext\ *)
# ------         ------    ------  -----     ----    ----   ----
# LZO1X-1         10057      5675  56.4%  2005-07-25 16:26  path/file
		lzop -Plv "$archive" | $AWKU'
/-[0-9]+-/ {
	size=$2
	date=$5
	time=$6
	show($6 "  ")
}'
	esac
	exit 0
	;;
    -a|-n) # add to archive / new: create new archive
	update $opt "$@"
	while read exe args exts; do
		[ "$(which $exe)" ] || continue
		[ "$opt$exe" = "-nzip" ] && args="-r"
		case " $exts " in *\ $lc_ext\ *)
			# only add the file's basename, not the full path
			while [ "$1" ]; do
				cd "$(dirname "$1")"
				$exe $args "$archive" "$(basename "$1")"
				status=$?
				shift
			done
			exit $status
		esac
	done <<EOT
zip	-g\ -r		$ZIP_EXTS
rar	a		$RAR_EXTS
arj	a		$ARJ_EXTS
7zr	a\ -ms=off	$_7Z_EXTS
lha	a		$LHA_EXTS
EOT
	;;
    -r) # remove from archive passed files
	update $opt "$@"
	while read exe args exts; do
		[ "$(which $exe)" ] || continue
		case " $exts " in *\ $lc_ext\ *)
			$exe $args "$archive" "$@" | grep -q E_NOTIMPL && {
				echo -e "7z cannot delete files from solid archive." >&2
				exit $UNSUPPORTED
			}
			exit 0
		esac
	done <<EOT
zip	-d	$ZIP_EXTS
rar	d	$RAR_EXTS
arj	d	$ARJ_EXTS
lha	d	$LHA_EXTS
7zr	d	$_7Z_EXTS
EOT
	;;
    -e) # extract from archive passed files
	while read arch exts; do
		case " $exts " in *\ $lc_ext\ *)
			$DECOMPRESS "$archive" | $arch "$@"
			exit $?
		esac
	done <<EOT
tar\ -xf\ -	$TAR_EXTS $IPK_EXTS $XZ_EXTS $LRZIP_EXTS
cpio\ -idm	$CPIO_EXTS $CPIOXZ_EXTS $CPIOLRZIP_EXTS $RPM_EXTS $TAZPKG_EXTS
EOT
	while read exe x p exts; do
		[ "$(which $exe)" ] || continue
		case " $exts " in *\ $lc_ext\ *)
			[ "$x" != "N/A" ] && $exe $x "$archive" "$@"
			status=$?
			if [ "$p" != "N/A" -a $status -ne 0 ]; then
				echo Password protected, opening an x-term...
				$XTERM_PROG -e $exe $p "$archive" "$@"
				exit $?
			fi
			exit $status
		esac
	done <<EOT
unzip		-n		N/A		$ZIP_EXTS
dpkg-deb	-X		N/A		$DEB_EXTS
lha		x		N/A		$LHA_EXTS
lzop		-x		N/A		$LZO_EXTS
rar		x\ -o-\ -p-	x\ -o-		$RAR_EXTS
arj		x\ -y		x\ -y\ -g?	$ARJ_EXTS
7zr		x\ -y\ -p-	x\ -y		$_7Z_EXTS
unace		N/A		x\ -o\ -y	ace
cabextract	-q		N/A		cab
EOT
	loop_fs $opt "$@"
	;;
     *) cat <<EOT
error, option $opt not supported
use one of these:
-i			#info
-o archive		#open
-a archive files	#add
-n archive file		#new
-r archive files	#remove
-e archive files	#extract
EOT
esac
exit $UNSUPPORTED
