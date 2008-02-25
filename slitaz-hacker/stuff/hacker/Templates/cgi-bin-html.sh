#!/bin/sh
#

# Variables.
HOST=`cat /etc/hostname`
RELEASE=`uname -r`

# Content type.
echo -e "Content-Type: text/html\n"

# Header.
echo "<html>"
echo "<head>"
echo "  <title>cgi-bin</title>"
echo "</head>"
echo -e "<body bgcolor=\"#ffffff\">"

# Page content.
echo "<h1>HTML cgi-bin SHell script</h1>"
echo "<hr>"
echo "<p>"
echo "This script is runnig on $HOST with a Linux kernel $RELEASE."
echo "</p>"

# Footer.
echo "</body>";
echo "</html>"
