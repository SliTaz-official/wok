#!/bin/sh
#
# TazWikiss - A tiny Wiki for busybox/httpd
# Licence GNU/GPLv2 - http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
# Copyright (C) Pascal Bellard
# Based on WiKiss - http://wikiss.tuxfamily.org/

. /usr/bin/httpd_helper.sh

cd $(dirname $0)
CONFIG=config-${HTTP_ACCEPT_LANGUAGE%%,*}.sh
[ -r "$CONFIG" ] || CONFIG=config.sh
. ./$CONFIG

WIKI_VERSION="TazWiKiss 0.3"

# Initialisations
toc=''				# Table Of Content
CONTENT=''			# contenu de la page
HISTORY=''			# lien vers l'historique
plugins_dir="plugins/"		# repertoire ou stocker les plugins
template="template.html"	# Fichier template
PAGE_TITLE_link=true		# y-a-t-il un lien sur le titre de la page ?
editable=true			# la page est editable
urlbase="$SCRIPT_NAME"
#urlbase="./"
   
die()
{
	echo $@
	exit
}

redirect()
{
	awk '{ printf "%s\r\n",$0 }' <<EOT
HTTP/1.0 302 Found
location: $1

EOT
        exit
}

cache_auth()
{
	local tmp
	tmp="$(echo $1$(date +%d) | md5sum | cut -c1-8)"
	[ "$(POST sc)" == "$1" ] && AUTH=$tmp || [ "$AUTH" == "$tmp" ]
}

authentified()
{
	[ -n "$PASSWORDS" ] && for i in $PASSWORDS ; do
		cache_auth "$i" && return
	done
	cache_auth "$PASSWORD"
}

plugin_call_method()
{
	local status
	local name
	name=$1
	shift
	[ -d "$plugins_dir" ] || return
	status=false
	for i in $plugins_dir/*.sh ; do
		[ -x $i ] || continue
		grep -q "^$name()" $i || continue
		. $i
		eval $name "$@"
		[ $? == 0 ] && status=true
	done
	$status
}

curdate()
{
	date '+%Y-%m-%d %H:%M'
}

filedate()
{
	stat -c %y $1 | sed -e 's|-|/|g' -e 's/\(:..\):.*/\1/'
}

AUTH=$(GET auth)
[ -n "$AUTH" ] || AUTH=$(POST auth)
PAGE_TITLE="$(GET page)"
[ -n "$PAGE_TITLE" ] || PAGE_TITLE="$(POST page)"
if [ -z "$PAGE_TITLE" ]; then
	PAGE_TITLE="$START_PAGE"
	case "$(GET action)" in
	recent) PAGE_TITLE="$RECENT_CHANGES" ;;
	search)	PAGE_TITLE="$LIST"
	  [ -n "$(GET query)" ] && PAGE_TITLE="$SEARCH_RESULTS $(GET query)"
	esac
fi
case "$PAGE_TITLE" in
*/*|*\&*) PAGE_TITLE="$START_PAGE" ;;
esac
gtime=$(GET time)
case "$gtime" in
*/*|*\&*) gtime="" ;;
esac
action=$(GET action)
datew="$(curdate)"
content="$(POST content)"

# Ecrire les modifications, s'il y a lieu
PAGE_txt="$PAGES_DIR$PAGE_TITLE.txt"
if [ -n "$content" ]; then	# content => page
	if authentified; then
		sed 's/</\&lt;/g' > $PAGE_txt <<EOT
$POST_content
EOT
		if [ -n "$BACKUP_DIR" ]; then
			complete_dir_s="$BACKUP_DIR$PAGE_TITLE/"
			if [ ! -d "$complete_dir_s" ]; then
				mkdir -p $complete_dir_s
				chmod 777 $complete_dir_s
			fi
			cat >> "$complete_dir_s$(curdate).bak" <<EOT

// $datew / $REMOTE_ADDR
$(cat $PAGE_txt)
EOT
		fi
                plugin_call_method "writedPage" $PAGE_txt
        	PAGE_TITLE="$PAGE_TITLE&auth=$AUTH"
	else
        	PAGE_TITLE="$PAGE_TITLE&action=edit&error=1"
	fi
        redirect "$urlbase?page=$PAGE_TITLE"
fi

if [ -r "$PAGE_txt" -o -n "$action" ]; then
	CONTENT=""
	if [ -e "$PAGE_txt" ]; then
		TIME=$(filedate $PAGE_txt)
		CONTENT="$(cat $PAGE_txt)"
	fi
	# Restaurer une page
	[ -n "$(GET page)" -a -n "$gtime" -a "$(GET restore)" == 1 ] &&
	[ -r "$BACKUP_DIR$PAGE_TITLE/$gtime" ] && 
	CONTENT="$(cat $BACKUP_DIR$PAGE_TITLE/$gtime)"
	CONTENT="$(sed -e 's/\$/\&#036;/g' -e 's/\\/\&#092;/g' <<EOT
$CONTENT
EOT
)"
else
	CONTENT="$(sed -e "s#%page%#$PAGE_TITLE#" <<EOT
$DEFAULT_CONTENT
EOT
)"
fi

htmldiff()
{
	local files
	local old
	local new
	old="$BACKUP_DIR$(GET page)/$1"
	new="$BACKUP_DIR$(GET page)/$2"
	[ -s "$old" ] || old=/dev/null
	[ -n "$2" -a "$2" != "none" ] || new=$PAGES_DIR$(GET page).txt
	files="$old $new"
	[ "$old" -nt "$new" -a "$old" != "/dev/null" ] && files="$new $old"
	diff -aU 99999 $files | sed -e '1,3d' -e '/^\\/d' -e 's|$|<br/>|' \
	 -e 's|^-\(.*\)$|<font color=red>\1</font>|' \
	 -e 's|^+\(.*\)$|<font color=green>\1</font>|'
}

# Actions speciales du Wiki
case "$action" in
edit)
	editable=false
	HISTORY="<a href=\"$urlbase?page=$(urlencode $PAGE_TITLE)\&amp;action=history\" accesskey=\"6\" rel=\"nofollow\">$HISTORY_BUTTON</a><br />"
	CONTENT="<form method=\"post\" action=\"$urlbase\">
<textarea name=\"content\" cols=\"83\" rows=\"30\" style=\"width: 100%;\">
$CONTENT
</textarea>
<input type=\"hidden\" name=\"page\" value=\"$PAGE_TITLE\" /><br />
<p align=\"right\">"
	if authentified; then
		CONTENT="$CONTENT<input type=\"hidden\" value=\"$(POST password)\""
	else
		CONTENT="$CONTENT$MDP : <input type=\"password\""
	fi	
	CONTENT="$CONTENT name=\"sc\" /> <input type=\"submit\" value=\"$DONE_BUTTON\" accesskey=\"s\" /></p></form>"
	;;
history)
	complete_dir="$BACKUP_DIR$PAGE_TITLE/"
	if [ -n "$gtime" ]; then
		HISTORY="<a href=\"$urlbase?page=$PAGE_TITLE\&amp;action=history\" rel=\"nofollow\">$HISTORY_BUTTON</a>"
		if [ -r "$complete_dir$gtime" ]; then
			HISTORY="$HISTORY <a href=\"$urlbase?page=$PAGE_TITLE\&amp;action=edit\&amp;time=$gtime&amp;restore=1\" rel=\"nofollow\">$RESTORE</a>"
			CONTENT="$(cat $complete_dir$gtime | sed -e s/$(echo -ne '\r')//g -e 's|$|<br/>|g')"
		else
			HISTORY="$HISTORY -"
		fi
	else
		HISTORY="$HISTORY_BUTTON"
		CONTENT="$NO_HISTORY"
		if [ -d $complete_dir ]; then
			CONTENT="<form method=\"GET\" action=\"$urlbase\">\n<input type=hidden name=action value=diff><input type=hidden name=page value=\"$PAGE_TITLE\">" 
			for file in $(ls $complete_dir | sort -r); do
				CONTENT="$CONTENT
<input type=radio name=f1 value=$file><input type=radio name=f2 value=$file />
<a href=\"$urlbase?page=$PAGE_TITLE&amp;action=history&amp;time=$file\">$file</a><br />
"
			done
			CONTENT="$CONTENT<input type=submit value=diff></form>"
		fi
	fi ;;
diff)
	if [ -n "$(GET f1)" ]; then
		HISTORY="<a href=\"$urlbase?page=$(urlencode "$PAGE_TITLE")\&amp;action=history\">$HISTORY_BUTTON</a>"
		CONTENT="$(htmldiff "$(GET f1)" "$(GET f2)" )"
	else
		# diff auto entre les 2 dernières versions
		ls "$BACKUP_DIR$PAGE_TITLE/" | ( sort -r ; echo none ; echo ) | head -n 2 | while read f1 f2; do
			redirect "$urlbase?page=$(urlencode "$PAGE_TITLE")&action=$action&f1=$f1&f2=$f2"
		done
	fi ;;
search)
	PAGE_TITLE_link=false
	editable=false
	query="$(GET query)"
	n=0
	for file in $(ls $PAGES_DIR/*.txt 2> /dev/null | sort) ; do
		[ -e $file ] || continue
		echo $file | grep -qs "$query" $file /dev/stdin || continue
		file=$(basename $file ".txt")
		CONTENT="$CONTENT<a href=\"$urlbase?page=$file\">$file</a><br />
"
		n=$(($n + 1))
	done
	PAGE_TITLE="$PAGE_TITLE ($n)" ;;
recent)
	PAGE_TITLE_link=false
	editable=false
	n=0
	for file in $(ls -l $PAGES_DIR/*.txt 2> /dev/null | awk '{ print $9 }' | tail -n 10) ; do
		filename=$(basename $file ".txt")
		timestamp=$(filedate $file)
		CONTENT="$CONTENT<a href=\"$urlbase?page=$filename\">$filename</a> ($timestamp - <a href=\"$urlbase?page=$filename&amp;action=diff\">diff</a>)<br />
"
	done ;;
'') 	;;
*)
	plugin_call_method "action" $action || action="" ;;
esac
if [ -z "$action" ]; then
	if echo "$CONTENT" | grep -q '%html%\s'; then
		CONTENT="$(sed 's/%html%\s//' <<EOT
$CONTENT
EOT
)"
	else
		tmpdir=/tmp/tazwiki$$
		mkdir $tmpdir
		unesc="$(echo "$CONTENT" | sed 's/\^\(.\)/\n^\1\n/g' | grep '\^' |\
		  sort | uniq | grep -v "['[!]" | hexdump -e '"" 3/1 "%d " "\n"' |\
		  awk '{ printf "-e '\''s/\\^%c/\\&#%d;/g'\'' ",$2,$2}') \
		  -e 's/\\^'\\''/\\&#39;/g' -e 's/\^\!/\&#33;/g' \
		  -e 's/\^\[/\&#91;/g'"
		CONTENT="$(eval sed $unesc <<EOT | \
			sed -e 's/&/\&amp;/g'  -e s/$(echo -ne '\r')//g \
			-e 's/&amp;lt;/\&lt;/g'  -e 's/&amp;#\([0-9]\)/\&#\1/g' | \
			awk -v tmpdir=$tmpdir 'BEGIN { n=1; state=0 } {
s=$0
while (1) {
  if (state == 0) {
    if (match(s,/\{\{/)) {
      printf "%s<pre><code>{{CODE%s}}</code></pre>",substr(s,1,RSTART-1),n
      s=substr(s,RSTART+RLENGTH)
      state=1
    }
    else {
      print s
      break
    }
  }
  if (state == 1) {
    if (match(s,/\}\}/)) {
      printf "%s",substr(s,1,RSTART-1) >> tmpdir "/CODE" n
      s=substr(s,RSTART+RLENGTH)
      n++
      state=0
    }
    else {
      print s >> tmpdir "/CODE" n
      break
    }
  }
}
}'
$CONTENT
EOT
)"
		plugin_call_method formatBegin 
		CONTENT="$(sed -e 's/&lt;-->/\&harr;/g' -e 's/&lt;==>/\&hArr;/g'\
		 	-e 's/-->/\&rarr;/g'    -e 's/&lt;--/\&larr;/g' \
		 	-e 's/==>/\&rArr;/g'    -e 's/&lt;==/\&lArr;/g' \
		 	-e 's/([eE])/\&euro;/g' -e 's/([pP])/\&pound;/g' \
		 	-e 's/([yY])/\&yen;/g'  -e 's/([tT][mM])/\&trade;/g' \
		 	-e 's/([cC])/\&copy;/g' -e 's/([rR])/\&reg;/g' \
		 	-e 's/(&lt;=)/\&le;/g'  -e 's/(>=)/\&ge;/g' \
		 	-e 's/(!=)/\&ne;/g'     -e 's/(+-)/\&plusmn;/g' <<EOT
$CONTENT
EOT
)"
		rg_url="[0-9a-zA-Z\.\#/~\-\_%=\?\&,\+\:@;!\(\)\*\$']*" # TODO: verif & / &amp;
		rg_link_local="$rg_url"
		rg_link_http="https\?://$rg_url"
		rg_img_local="$rg_url\.jpe\?g\|$rg_url\.gif\|$rg_url\.png"
		rg_img_http="$rg_link_http\.jpe\?g\|$rg_link_http\.gif\|$rg_link_http\.png"

		# image, image link, link, wikipedia, email ...
		CONTENT="$(sed \
			-e "s#\[\($rg_img_http\)|*\([a-z]*\)*\]#<img src=\"\1\" alt=\"\1\" style=\"float:\2;\"/>#g" \
			-e "s#\[\($rg_img_local\)|*\([a-z]*\)*\]#<img src=\"\1\" alt=\"\1\" style=\"float:\2;\"/>#g" \
			-e "s#\[\($rg_img_http\)|\($rg_link_http\)|*\([a-z]*\)*\]#<a href=\"\2\" class=\"url\"><img src=\"\1\" alt=\"\1\" title=\"\1\"style=\"float:\3;\"/></a>#g" \
			-e "s#\[\($rg_img_http\)|\($rg_link_local\)|*\([a-z]*\)*\]#<a href=\"\2\" class=\"url\"><img src=\"\1\" alt=\"\1\" title=\"\1\"style=\"float:\3;\"/></a>#g" \
			-e "s#\[\($rg_img_local\)|\($rg_link_http\)|*\([a-z]*\)*\]#<a href=\"\2\" class=\"url\"><img src=\"\1\" alt=\"\1\" title=\"\1\"style=\"float:\3;\"/></a>#g" \
			-e "s#\[\($rg_img_local\)|\($rg_link_local\)|*\([a-z]*\)*\]#<a href=\"\2\" class=\"url\"><img src=\"\1\" alt=\"\1\" title=\"\1\"style=\"float:\3;\"/></a>#g" \
			-e "s#\[\([^]]*\)|\($rg_link_http\)\]#<a href=\"\2\" class=\"url\">\1</a>#g" \
			-e "s#\[\([^]]*\)|\($rg_link_local\)\]#<a href=\"\2\" class=\"url\">\1</a>#g" \
			-e "s#\[\($rg_link_http\)\]#<a href=\"\1\" class=\"url\">\1</a>#g" \
			-e "s#\([^>\"]\)\($rg_link_http\)#\1<a href=\"\2\" class=\"url\">\2</a>#g" \
			-e "s#\[?\([^]]*\)\]#<a href=\"http://$LANG.wikipedia.org/wiki/\1\" class=\"url\" title=\"Wikipedia\">\1</a>#g" \
			-e "s#\[\([^]]*\)\]#<a href=\"$urlbase?page=\1\">\1</a>#g" \
			-e 's#\([0-9a-zA-Z\./~\-\_][0-9a-zA-Z\./~\-\_]*@[0-9a-zA-Z\./~\-\_][0-9a-zA-Z\./~\-\_]*\)#<a href=\"mailto:\1\">\1</a>#g' \
			-e 's#^\*\*\*\(.*\)#<ul><ul><ul><li>\1</li></ul></ul></ul>#g' \
			-e 's#^\*\*\(.*\)#<ul><ul><li>\1</li></ul></ul>#g' \
			-e 's#^\*\(.*\)#<ul><li>\1</li></ul>#g' \
			-e 's,^\#\#\#\(.*\),<ol><ol><ol><li>\1</li></ol></ol></ol>,g' \
			-e 's,^\#\#\(.*\),<ol><ol><li>\1</li></ol></ol>,g' \
			-e 's,^\#\(.*\),<ol><li>\1</li></ol>,g' \
			-e "s/$(printf '\r')//" <<EOT | sed \
			-e ':x;/<\/ol>$/{N;s/\n//;$P;$D;bx;}' | sed \
			-e ':x;/<\/ul>$/{N;s/\n//;$P;$D;bx;}' | sed \
			-e ':x;s/<\/ul><ul>//g;tx' -e ':x;s/<\/ol><ol>//g;tx' \
			-e 's|----*$|<hr />|' -e 's|$|<br />|' \
			-e 's#</li>#&\n#g' -e 's#\(</h[123456]>\)<br />#\1#g' \
			-e "s#'--\([^']*\)--'#<del>\1</del>#g" \
			-e "s#'__\([^']*\)__'#<u>\1</u>#g" \
			-e "s#'''''\([^']*\)'''''#<strong><em>\1</em></strong>#g" \
			-e "s#'''\([^']*\)'''#<strong>\1</strong>#g" \
			-e "s#''\([^']*\)''#<em>\1</em>#g"
$CONTENT
EOT
)"
		while read link; do
			[ -s $PAGES_DIR$link.txt ] && continue
			CONTENT="$(sed "s/\\?page=$link\"/& class=\"pending\"/" <<EOT
$CONTENT
EOT
)"
		done <<EOT
$(grep "$urlbase?page=" <<EOM | sed -e 's/^.*\?page=\([^"]*\).*$/\1/' -e 's/&.*//'
$CONTENT
EOM
)
EOT
		while echo "$CONTENT" | grep -q '^  ' ; do
			CONTENT="$(sed 's/^\(  *\) \([^ ]\)/\1\&nbsp;\&nbsp;\&nbsp;\&nbsp;\2/' <<EOT
$CONTENT
EOT
)"
		done
		read hastoc <<EOT
$CONTENT
EOT
		CONTENT="$(sed -e 's/^ /\&nbsp;\&nbsp;\&nbsp;\&nbsp;/' -e '1s/^TOC//' <<EOT
$CONTENT
EOT
)"
		toc='<div id="toc">'
		i=1
		for pat in '^![^!]' '^!![^!]' '^!!![^!]' '^!!!![^!]' '^!!!!!' ; do
			while read line; do
				[ -n "$line" ] || continue
				label="$(echo $line | sed 's/[^\dA-Za-z]/_/g')"
				toc="$(cat <<EOT
$toc
	<h$i><a href="#$label">$line</a></h$i>
EOT
)"
				CONTENT="$(sed "s#^!!* *$line\$#<h$i><a name=\"$label\">$line</a></h$i>#" <<EOT
$CONTENT
EOT
)"
			done <<EOT
$(grep "$pat" <<EOM | sed -e 's/^!!*//' -e 's/#/\#/g' -e 's/&/\\\&/g'
$CONTENT
EOM
)
EOT
			i=$(( $i + 1 ))
		done
		toc="$(cat <<EOT
$toc
</div>
EOT
)"
		case "$hastoc" in
		TOC*) ;;
		*) toc='';;
		esac
		CONTENT="$(awk -v tmpdir=$tmpdir '{
s=$0
while (1) {
  if (match(s,/\{\{CODE[0-9]+\}\}/)) {
    printf "%s" substr(s,1,RSTART-1)
    system("cat " tmpdir "/" substr(s,RSTART+2,RLENGTH-4))
    s=substr(s,RSTART+RLENGTH)
  }
  else {
    print s
    break
  }
}
}' <<EOT
$CONTENT
EOT
)"
		rm -rf $tmpdir
		plugin_call_method formatEnd
	fi
fi

# Remplacement dans le template
RECENT="<a href=\"$urlbase?action=recent\" accesskey=\"3\">$RECENT_CHANGES</a>"
[ "$action" == "recent" ] && RECENT=$RECENT_CHANGES
HOME="<a href=\"$urlbase?page=$START_PAGE\" accesskey=\"1\">$HOME_BUTTON</a>"
[ "$PAGE_TITLE" == "$START_PAGE" -a "$action" != "search" ] && HOME=$HOME_BUTTON
HELP="\1<a href=\"$urlbase?page=$HELP_BUTTON\" accesskey=\"2\" rel=\"nofollow\">$HELP_BUTTON</a>\2"
[ "$action" != "edit" ] && HELP=""

[ -r "$template" ] || die "'$template' is missing!"
html="$(sed -e "s#{\([^}]*\)RECENT_CHANGES\([^}]*\)}#\1$RECENT\2#" \
           -e "s#{\([^}]*\)HOME\([^}]*\)}#\1$HOME\2#" \
           -e "s#{\([^}]*\)HELP\([^}]*\)}#$HELP#" \
           -e "s#{SEARCH}#<form method=\"get\" action=\"$urlbase?page=$(urlencode "$PAGE_TITLE" | sed 's/#/\\#/g')\"><div><input type=\"hidden\" name=\"action\" value=\"search\" /><input type=\"text\" name=\"query\" value=\"$(htmlentities $(GET query) )\" tabindex=\"1\" /> <input type=\"submit\" value=\"$SEARCH_BUTTON\" accesskey=\"q\" /></div></form>#" \
           < $template )"
[ "$action" != "" -a "$action" != "edit" -o ! -e "$PAGE_txt" ] && TIME="-"
plugin_call_method template
[ -n "$(GET error)" ] || ERROR=""
[ -n "$HISTORY" ] && HISTORY="\1$HISTORY\2"
PAGE_TITLE_str="$(htmlentities "$PAGE_TITLE")"
$PAGE_TITLE_link &&
PAGE_TITLE_str="<a href=\"$urlbase?page=$(urlencode "$PAGE_TITLE")\">$PAGE_TITLE_str</a>"
EDIT="$EDIT_BUTTON"
if $editable ; then
	EDIT="$PROTECTED_BUTTON"
	[ -w "$PAGE_txt" -o ! -e "$PAGE_txt" ] &&
        EDIT="<a href=\"$urlbase?page=$(urlencode "$PAGE_TITLE")\&amp;action=edit\" accesskey=\"5\" rel=\"nofollow\">$EDIT_BUTTON</a>"
fi
[ -n "$toc" ] && toc="\1$toc\2"
AUTH_GET=""
AUTH_POST=""
if authentified; then
	AUTH_GET="auth=$AUTH\&"
	AUTH_POST="\n<input type=\"hidden\" name=\"auth\" value=\"$AUTH\" />"
fi

header "Content-type: text/html"
sed	-e "s#{ERROR}#$ERROR#"		-e "s#{WIKI_TITLE}#$WIKI_TITLE#" \
	-e "s#{\([^}]*\)HISTORY\([^}]*\)}#$HISTORY#" \
	-e "s#{PAGE_TITLE}#$PAGE_TITLE_str#" \
	-e "s#{\([^}]*\)EDIT\([^}]*\)}#\1$EDIT\2#" \
	-e "s|{\([^}]*\)TOC\([^}]*\)}|$(awk '{ printf "%s\\n" $0 }' <<EOT | \
		sed -e 's/&/\\\&/g' -e 's/|/\\|/g'
$toc
EOT
)|" \
	-e "s#{PAGE_TITLE_BRUT}#$(htmlentities "$PAGE_TITLE")#" \
	-e "s#{LAST_CHANGE}#$LAST_CHANGES :#" \
	-e "s#{CONTENT}#$(awk '{ printf "%s\\n" $0 }' <<EOT | \
		sed -e 's/&/\\\&/g' -e 's/#/\\#/g'
$CONTENT
EOT
)#" \
	-e "s#{LANG}#$LANG#"		-e "s#href=\"?#href=\"$urlbase?#g" \
	-e "s#$urlbase?#&$AUTH_GET#g" -e "s#action=\"$urlbase\">#&$AUTH_POST#g" \
	-e "s#{WIKI_VERSION}#$WIKI_VERSION#" \
	-e "s#{TIME}#$TIME#"		-e "s#{DATE}#$datew#" \
	-e "s#{IP}#$REMOTE_ADDR#"	-e "s#{COOKIE}##" <<EOT
$html
EOT
