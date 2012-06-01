#!/bin/sh

HOTSPOT="hotspot"
DIRDATA="/var/lib/awstats/$HOTSPOT"

if [ "$1" == "--install" ]; then
	cp /etc/awstats/awstats.model.conf /etc/awstats/awstats.$HOTSPOT.conf
	while read line; do
		sed -i "s,^${line%=*}.*,$line," /etc/awstats/awstats.$HOTSPOT.conf
	done <<EOT
LogFile="$0 < /var/log/squid/access.log |"
LogFormat="%code %time4 %bytesd %method %query %host %url"
SiteDomain="$HOTSPOT"
DirData="$DIRDATA"
LevelForBrowsersDetection=0
LevelForOSDetection=0
LevelForRefererAnalyze=0
LevelForRobotsDetection=0
LevelForSearchEnginesDetection=0
LevelForKeywordsDetection=0
ShowRobotsStats=0
ShowOSStats=0
ShowBrowsersStats=0
ShowOriginStats=0
ShowKeyphrasesStats=0
ShowKeywordsStats=0
ShowMiscStats=0
ShowHTTPErrorsStats=0
EOT
else
	while read time skip1 iprouter skip2 bytesd method query skip3 ; do
		host=$(echo $query | sed 's#.*//\([^/]*\)/.*#\1#')
		url=$(echo $query | sed 's#.*//##')
		echo "200 ${time%.*} $bytesd $method $query $host $url"
	done
fi
