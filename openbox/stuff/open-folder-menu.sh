#!/bin/sh
#
# Openbox pipe menu to launch PCmanFM using GTK bookmarks.
#

echo '<openbox_pipe_menu>'

# Home
echo '<item label="Home">'
echo '<action name="Execute"><execute>'
echo "pcmanfm ~"
echo '</execute></action></item>'

# ~/Desktop
echo '<item label="Desktop">'
echo '<action name="Execute"><execute>'
echo "pcmanfm ~/Desktop"
echo '</execute></action></item>'

# GTK bookmarks
for dir in `sed 's/[ ][^ ]*$//' .gtk-bookmarks`
do
	echo '<item label="'`basename $dir`'">'
	echo '<action name="Execute"><execute>'
	echo "pcmanfm $dir"
	echo '</execute></action></item>'
done

echo '</openbox_pipe_menu>'
