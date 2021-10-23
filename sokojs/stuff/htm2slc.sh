#!/bin/sh

case "$0" in
*2txt*)
  [ -z "$1" ] && echo "$0 file" && exit 1
  sed '/^"\|<L>\|<Level/!d;s|.*<Level Id="|; |;s| *<L>||;s|</L>||;s| *"[,)].*||;s|^"||;s|".*||;s|_| |g;/^$/d' "$1" | awk 'BEGIN {n=1000;h=0}
{ s[h++]=$0
  if (/^;/) next
  for (i=1;i<n && substr($0,i,1) == " ";i++);
  if (i<n) n=i
} END { for (i=0;i<h;i++) if (substr(s[i],1,1) == ";") print s[i]; else print substr(s[i],n) }'
  exit;;
esac

[ -z "$1" ] && echo "$0 set/" && exit 1
[ ! -s "$1/level0.htm" ] && echo "$1/level0.htm not found" && exit 2

cat <<EOT
<?xml version="1.0" encoding="utf-8"?>
<SokobanLevels xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="SokobanLev.xsd">
EOT
[ -s $1/description.txt ] && awk 'BEGIN { state=0 }
{ 
  if (state == 0) { state++; print "  <Title>" $0 "</Title>"; print "  <Description>" }
  else {
    if (/[A-Za-z0-9]@[A-Za-z0-9]/) s="  <Email>" $0 "</Email>"
    else if (/^http/) s="  <Url>" $0 "</Url>"
    else if (!/^copyright/) { print; next }
    else next
    if (state++ == 1) print "  </Description>"
    print s
  }
} END { if (state == 1) print "  </Description>" }' $1/description.txt
copyright="$(grep -s ^copyright $1/description.txt | sed 's|^copyright |Copyright="|;s|$|" |')"
maxwidth="$(sed '/^"/!d;s| *"[,)].*||;s|^" *||' $1/level*.htm | awk 'BEGIN{w=0}{if(w<length($0)) w=length($0)}END{print w}')"
maxheight="$(for i in $1/level*.htm; do sed '/^"/!d;s| *"[,)].*||;s|^" *||;/^$/d' $i | wc -l; done | awk 'BEGIN{h=0}{if(h<$0) h=$0}END{print h}')"
echo "  <LevelCollection ${copyright}MaxWidth=\"$maxwidth\" MaxHeight=\"$maxheight\">"
n=0
while [ -s "$1/level$n.htm" ]; do
   i="$1/level$((n++)).htm"
   id="$(sed '/^\/\/ /!d;/[0-9]x[0-9]*\+[0-9]*\+[0-9]/!d;s|^// ||;s| [0-9]*x[0-9]*.*||' $i)"
   sed '/^"/!d;s| *"[,)].*||;s|^"||;s|_| |g;/^$/d' $i | awk -vx="${id:-$(basename $i .htm)}" '
BEGIN {n=1000;w=0;h=0} {
 s[h]=$0
 for (i=1;i<n && substr($0,i,1) == " ";i++);
 if (i<n) n=i
 if (w<length($0)) w=length($0)
 h++
} END { print "    <Level Id=\"" x "\" Width=\"" w-n+1 "\" Height=\"" h "\">"
 for (i=0;i<h;i++) print "      <L>" substr(s[i],n) "</L>"
 print "    </Level>" }'
done
cat <<EOT
  </LevelCollection>
</SokobanLevels>
EOT
