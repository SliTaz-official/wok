#!/bin/sh

swap() {
    awk 'BEGIN { n=0 } { l[n++]=$0 } END {
 for (i = 0; i < length(l[0]); i++) {
   for (j = 0; j < n; j++) printf "%s", substr(l[j],i+1,1)
   print ""
 }}'
}

filter() {
    sed 's| _|  |;s|_ |  |;s|^_| |;s|_$| |'
}

check() {
    grep -Eq ' _|_ |^_|_$'
}

[ -z "$1" ] && echo "$0 set1.slc ..." && exit 1
[ ! -s "main.htm" ] && echo "$PWD/main.htm not found" && exit 2

while [ "$1" ]; do
	file="$1"
	set="$(basename $1 .slc)"
	shift
	[ -d "$set" ] && continue
	echo "$set"
	grep -q "<option>$set</option>" main.htm || sed -i "s|</select>|<option>$set</option>\");\n    document.write(\"&|" main.htm
	mkdir "$set"
	comment=""; state=""; level=0
	while read line; do
		case "$line" in
		*\<Url\>*) echo "$line" | sed 's|.*<Url>||;s|</Url>.*||' >> "$set/description.txt" ;;
		*\<Title\>*) echo "$line" | sed 's|.*<Title>||;s|</Title>.*||' >> "$set/description.txt" ;;
		*\<Description\>) state="Description"; continue ;;
		*\</Description\>) state="" ;;
		*\<LevelCollection*)
                        maxwidth="$(echo "$line" | sed 's|.*MaxWidth="||;s|".*||')"
			col=16; [ $maxwidth -gt $col ] && col=$maxwidth
                        maxheight="$(echo "$line" | sed 's|.*MaxHeight="||;s|".*||')"
			row=16; [ $maxheight -gt $row ] && row=$maxheight
                        echo "$line" | sed '/Copyright=/!d;s|.*Copyright="|copyright |;s|".*||' >> "$set/description.txt" ;;
		*\<Level*) state="Level"
                        id="$(echo "$line" | sed 's|.*Id="||;s|".*||')"
                        width="$(echo "$line" | sed 's|.*Width="||;s|".*||')"
			fmt="                                               "
			fmt="${fmt:0:$((($col-$width)/2))}%-$(($col-($col-$width)/2))s"
                        height="$(echo "$line" | sed 's|.*Height="||;s|".*||')"
			height=$((($row-$height)/2))
			l=0
			echo -n "" > $set/tmp0
			while [ $height -gt $l ]; do
				printf "$fmt\n" "" >> "$set/tmp0"
				l=$(($l+1))
			done
			cat > "$set/level$level.htm" <<EOT
<html>
<head>
</head>
<body>
<form action="">
<script type="text/javascript">
<!--
if (parent.frames[0] == null) { document.location = "../sokojs.htm"  }
l = new Array(
// $id ${maxwidth}x$maxheight+$((($col-$width)/2))+$height
EOT
			continue ;;
		*\</Level\>) state=""
			while [ $row -gt $l ]; do
				printf "$fmt\n" "" >> "$set/tmp0"
				l=$(($l+1))
			done
			while swap < $set/tmp0 | check || check < $set/tmp0 ; do
				swap < $set/tmp0 | filter | swap | filter > $set/tmp1
				mv -f $set/tmp1 $set/tmp0
			done
			x=$(($(sed '/[@+]/{s|[@+].*||;q}' $set/tmp0 |\
				 wc -cl | sed 's|^|-|;s|......$|+&|')))
			sed 's|.*|"&",|;$s|,$|);|' $set/tmp0 >> "$set/level$level.htm"
			cat >> "$set/level$level.htm" <<EOT

Row=$row
Col=$col
for  (x = 0; x < Row; x++)
  for  (y = 0; y < Col; y++)
    document.write("<INPUT TYPE=\"button\" value=\"",
      ' _#*$.'.indexOf(l[x].substring(y, y + 1).replace('+','.').replace('@','_')), "\">")
document.write("<INPUT TYPE=\"button\" value=\"$x\">",
               "<INPUT TYPE=\"button\" value=\"$level\"><\/FORM>")

document.write("<FORM ACTION=\"\">")
document.write("<INPUT TYPE=\"button\" value=\""+Row+"\">",
               "<INPUT TYPE=\"button\" value=\""+Col+"\">",
               "<INPUT TYPE=\"button\" value=\"$set\">",
               "<INPUT TYPE=\"button\" value=\"COUNT\"><\/FORM>")
parent.frames[1].location = "../main.htm"
//-->
</script></form>
</body>
</html>
EOT
			rm -f $set/tmp*
			level=$(($level+1))
			continue ;;
		esac
		case "$state" in
		Description)
			echo "$line" >> "$set/description.txt" ;;
		Level)
			printf "$fmt\n" "$(echo "$line" | sed 's|.*<L>||;s|</L>||;:a;s|\([#.+@$\*]_*\) |\1_|;ta')" >> "$set/tmp0"
			l=$(($l+1))
		esac
	done < "$file"
	sed -i "s|COUNT|$(($level-1))|" "$set"/level*.htm
done
