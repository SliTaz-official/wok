plugin="Tables"
description_fr="Syntaxe de tables"
description="Table syntax"
   
formatBegin()
{
CONTENT=$(sed  -e 's/\[\([^]]*\)|\([^]]*\)|\([^]]*\)\]/[\1{WKP_TBL_BAR}\2{WKP_TBL_BAR}\3]/g' \
    -e 's/\[\([^]]*\)|\([^]]*\)\]/[\1{WKP_TBL_BAR}\2]/g' -e 's,|,||,g' \
    -e 's,^\( *|\)|,\1,' -e 's/|\( *\)$/\1/' <<EOT | awk '
{
  if (/^ *\|.*\|$/) {
    if (in_array == 0) printf "<table class=\"wikitable\">"
    in_array = 1
    s = $0
    printf "<tr>"
    while (match(s,/\|[^\|]*\|/)) {
      q = substr(s,RSTART+1,RLENGTH-2)
      s = substr(s,RSTART+RLENGTH)
      c=""; lr=""; tb=""
      if (match(q,/^[hlrtb]+ /)) {
        for (i = 0; i < RLENGTH; i++) {
          if (q ~ /^h/) c=" class=\"em\""
          if (q ~ /^l/) lr="text-align: left; "
          if (q ~ /^r/) lr="text-align: right; "
          if (q ~ /^t/) tb="vertical-align: top; "
          if (q ~ /^b/) tb="vertical-align: bottom; "
          q = substr(q,2)
        }
      }
      if (lr != "" || tb != "") c = c " style=\"" lr tb "\""
      if (match(q,/^[0-9]+ */)) {
        n = RLENGTH
        match(q,/^[0-9]+/)
        c = c " colspan=\"" substr(q,1,RLENGTH) "\""
        q = substr(q,n+1)
      }
      if (match(q,/^,[0-9]+ */)) {
        n = RLENGTH
        match(q,/^,[0-9]+/)
        c = c " rowspan=\"" substr(q,2,RLENGTH-1) "\""
        q = substr(q,n+1)
      }
      printf "  <td" c ">" q "</td>"
    }
    printf "</tr>"
  }
  else {
    if (in_array != 0) print "</table>"
    in_array = 0
    print
  }
} END { if (in_array != 0) print "</table>" }' | \
sed -e 's/{WKP_TBL_BAR}/|/g' -e 's,||,|,g'
$CONTENT
EOT
)
}
