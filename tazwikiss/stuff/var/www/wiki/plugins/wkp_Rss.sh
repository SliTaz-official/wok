plugin="Rss"
description_fr="Génération d'un flux Rss des derniers changements"
description="Generate a Rss streams with last changes"

writedPage()
{
	# Attention, bug si https ou port différent de 80 ?
	ADR_ACCUEIL="http://$SERVER_NAME$SCRIPT_NAME"
	CONTENT_RSS=""      
	for file in $(ls -l $PWD/$PAGES_DIR/*.txt 2> /dev/null | awk '{ print $9 }' | tail -n 10) ; do
		filename=$(basename $file ".txt")
		timestamp=$(filedate $file)
		CONTENT="$CONTENT<a href=\"?page=$filename\">$filename</a> ($timestamp - <a href=\"./?page=$filename&amp;action=diff\">diff</a>)<br />"
CONTENT_RSS="$CONTENT_RSS<item>
<title>$filename</title>
<pubDate>$timestamp</pubDate>
<link>$ADR_ACCUEIL?page=$(urlencode '$filename')</link>
<description>$filename $timestamp</description>
</item>"
	done
	sed -e "s#{WIKI_TITLE}#$WIKI_TITLE#" \
	    -e "s#{ADR_ACCUEIL}#$ADR_ACCUEIL#" \
	    -e "s#{LANG}#$LANG#" \
	    -e "s#{WIKI_DESCRIPTION}#Flux RSS de $WIKI_TITLE#" \
	    -e "s#{CONTENT_RSS}#$CONTENT_RSS#" > rss.xml <<EOT
<rss version="0.91">
<channel>
<title>{WIKI_TITLE}</title>
<link>{ADR_ACCUEIL}</link>
<description>{WIKI_DESCRIPTION}</description>
<language>{LANG}</language>
{CONTENT_RSS}
</channel>
</rss>
EOT
}
   
template()
{
	html="$(sed 's#{RSS}#<link rel="alternate" type="application/rss+xml" title="RSS" href="rss.xml" />#' <<EOT
$html
EOT
)"
	return 0
}
