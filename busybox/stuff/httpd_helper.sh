#!/bin/sh
#
# busybox/httpd helper for shell cgi scripts
#
# GET [var] | POST [var] | FILE [var {name|tmpname|size|type}]
# urlencode string | htmlentities string | httpinfo

alias urlencode='httpd -e'

# Send headers, example :
# header "Content-type: text/html" "Set-Cookie: name=value; HttpOnly"
header()
{
[ -z "$1" ] && set -- "Content-type: text/html"
for i in "$@" "" ; do echo -e "$i\r"; done
}

htmlentities()
{
echo $1 | sed 's|&|\&amp;|g;s|<|\&lt;|g;s|>|\&gt;|g;s|"|\&quot;|g'
}

GET()
{
local n
n=$2
[ -n "$n" ] || n=1
[ -z "$1" ] && echo $GET__NAMES ||
	[ -n "$GET__NAMES" ] && eval echo \$GET_${1}_$n
}

POST()
{
local n
n=$2
[ -n "$n" ] || n=1
[ -z "$1" ] && echo $POST__NAMES ||
	[ -n "$POST__NAMES" ] && eval echo \$POST_${1}_$n
}

FILE()
{
[ -z "$1" ] && echo $FILE__NAMES || [ -n "$FILE__NAMES" ] && eval echo \$FILE_${1}_$2
}

httpinfo()
{
local i
local x
for i in SERVER_PROTOCOL SERVER_SOFTWARE SERVER_NAME SERVER_PORT AUTH_TYPE \
	 GATEWAY_INTERFACE REMOTE_HOST REMOTE_ADDR REMOTE_PORT \
	 HTTP_REFERER HTTP_HOST HTTP_USER_AGENT HTTP_ACCEPT \
	 HTTP_ACCEPT_LANGUAGE HTTP_COOKIE AUTH_TYPE REMOTE_USER REMOTE_IDENT \
	 REQUEST_METHOD REQUEST_URI QUERY_STRING CONTENT_LENGTH CONTENT_TYPE \
	 SCRIPT_NAME SCRIPT_FILENAME PATH_INFO PATH_TRANSLATED \
	 USER HOME LOGNAME SHELL PWD ; do
	eval x=\$$i
	[ -n "$x" ] && echo "$i='$x'"
done
for i in $GET__NAMES ; do
	if [ $(GET $i count) -gt 1 ]; then
		for j in $(seq 1 $(GET $i count)); do
			echo "GET[$i][$j]='$(GET $i $j)'"
		done
	else
		echo "GET[$i]='$(GET $i)'"
	fi
done
for i in $POST__NAMES ; do
	if [ $(POST $i count) -gt 1 ]; then
		for j in $(seq 1 $(POST $i count)); do
			echo "POST[$i][$j]='$(POST $i $j)'"
		done
	else
		echo "POST[$i]='$(POST $i)'"
	fi
done
for i in $FILE__NAMES ; do
	for j in name size type tmpname ; do
		echo "FILE[$i][$j]='$(FILE $i $j)'"
	done
done
}

read_query_string()
{
local i
local names
local cnt
names=""
IFS="&"
for i in $QUERY_STRING ; do
	var=${i%%=*}
	case " $names " in
	*\ $var\ *)
		eval cnt=\$${1}_${var}_count ;;
	*)	
		cnt=0
		names="$names $var" ;;
	esac
	eval ${1}_${var}_count=$((++cnt))
	eval ${1}_${var}_$cnt=\'$(httpd -d "${i#*=}" | sed "s/'/\'\\\\\'\'/g")\'
done
unset IFS
eval ${1}__NAMES=\'${names# }\'
}

[ -z "$GET__NAMES" ] && read_query_string GET

ddcut()
{
page=4096
skip=$1
count=$(($2 - $1 -2))
tmp=$(($skip / $page))
[ $tmp -ne 0 ] && dd bs=$page skip=$tmp count=0 
skip=$(($skip - ($tmp * $page) ))
dd bs=1 skip=$skip count=0
tmp=$(( ($page - $skip) % $page ))
if [ $tmp -ne 0 -a $tmp -le $count ]; then
	dd bs=1 count=$tmp
	count=$(($count - $tmp))
fi
tmp=$(($count / $page))
[ $tmp -ne 0 ] && dd bs=$page count=$tmp
dd bs=1 count=$(($count - ($tmp * $page) ))
}

if [ "$REQUEST_METHOD$POST__NAMES" == "POST" ]; then
	prefix=/tmp/httpd_post
	mkdir $prefix$$
	now=$(stat -c %Y $prefix$$)
	for i in $prefix* ; do
		[ $(stat -c %Y $i) -lt $(($now - 3600)) ] && rm -rf $i
	done
	post=$prefix$$/post
	n=1
	cat > ${post}0
	read delim < ${post}0
	case "$delim" in
	-*)	awk "/${delim%?}/ { o+=index(\$0,\"$delim\")-1; print o }
	   		  { o+=1+length() }" < ${post}0 | while read offset; do
		    if [ $offset -ne 0 ]; then
			ddcut $last $offset < ${post}0 > $post$n 2> /dev/null
			n=$(($n+1))
		    fi
		    last=$offset
		done
		rm -f ${post}0
		CR=`printf '\r'`
		for i in $post* ; do
		    head -n 2 $i | grep -q filename= || echo '' >> $i
		    filename=
		    while read line; do
			case "$line" in
			*Content-Disposition*)
			    name=$(echo $line | sed 's/.* name="\([^"]*\)".*$/\1/')
			    case "$line" in
			    *filename=*) filename=$(echo $line | sed 's/.* filename="\([^"]*\)".*$/\1/') ;;
			    esac ;;
			*Content-Type*)
			    type=$(echo $line | sed 's/.*-Type: \(.*\).$/\1/') ;;
			$CR)
			    if [ -n "$filename" ]; then
				tmp=$(mktemp $prefix$$/uploadXXXXXX)
				cat > $tmp
				FILE__NAMES="$FILE__NAMES $name"
				FILE__NAMES="${FILE__NAMES# }"
				eval FILE_${name}_tmpname=$tmp
				eval FILE_${name}_name=$filename
				eval FILE_${name}_size=$(stat -c %s $tmp)
				eval FILE_${name}_type=$type
			    elif [ -n "$name" ]; then
				eval var=\$POST_${name}
				while read line; do
					[ -n "$var" ] && var="$var
"
					var="$line"
				done
				eval POST_${name}="\$var"
				case " $POST__NAMES " in
				*\ $name\ *) ;;
				*) POST__NAMES="$POST__NAMES $name"
				   POST__NAMES="${POST__NAMES# }" ;;
				esac
			    fi
			    break ;;
			*)
			esac
		    done < $i
		    rm -f $i
		done
		rmdir $(dirname $post) ;;
	*)	export QUERY_STRING="$delim"
		rm -rf $(dirname $post)
		read_query_string POST ;;
	esac
fi
