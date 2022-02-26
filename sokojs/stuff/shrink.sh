#!/bin/sh

[ -z "$1" ] && echo "Usage: $0 level-files..." && exit 1
case "$0" in
*unshrink*)
	sed -i 's|.*//!||' $@ ;;
*)	for file in $@ ; do awk 'BEGIN { begin=9999; end=9999; tab=" " }
function scan(s) {
  i=2
  for (b=0;;i++) {
    c=substr(s,i,1)
    if (c != " ") break
    b++
  }
  if (c != "\"") line[row++]=s
  else if (row == 0) print "//!" s
  else line2[cut++]=s
  for (e=0;;i++) {
    c=substr(s,i,1)
    if (c == "\"") break
    if (c == " ") e++; else e=0
  }
  if (b < begin) begin=b
  if (e < end && line[row-1]==s) end=e
  col=i-2
}
function flush() {
  for (i=0;i<row;i++) {
    l=length(line[i])-end-begin-3
    if (i == row-1) { tail="\"); //!"
      if (end==0) l--
    } else tail="\",  //!"
    print "\"" tab substr(line[i],begin+2,l) tail line[i]
  }
  for (i=0;i<cut;i++) print "//!" line2[i]
}
{ if (/^"/) {
    scan($0); n++
    if (/");/) flush()
  } 
  else if (/^Row/) print "Row=" row " //!" $0
  else if (/^Col/) print "Col=" col-begin-end+length(tab) " //!" $0
  else if (/\\"[0-9]*\\">",$/ && n != 0) {
    s=$0; sub(/.*value=\\"/,"",s); sub(/\\">.*/,"",s)
    l=length(line[0])-3; n-=cut+row; begin-=length(tab)
    n=s - (l*n) - begin - ((begin+end)*(int(s/l)-n))
    print "document.write(\"<INPUT TYPE=\\\"button\\\" value=\\\"" n "\\\">\", //!" $0
    n=0
  }
  else print }' < $file | sed 's|"")|")|' > $file.$$
		mv -f $file.$$ $file
	done ;;
esac
