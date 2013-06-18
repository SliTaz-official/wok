#!/bin/sh
#
# Openbox pipe menu to launch SpaceFM using GTK bookmarks.
#

echo '<openbox_pipe_menu>'

# Home
echo '<item label="Home">'
echo '<action name="Execute"><execute>'
echo "spacefm ~"
echo '</execute></action></item>'

# ~/Desktop
echo '<item label="Desktop">'
echo '<action name="Execute"><execute>'
echo "spacefm ~/Desktop"
echo '</execute></action></item>'

# GTK bookmarks
for dir in `sed 's/[ ][^ ]*$//' .gtk-bookmarks`
do
	echo '<item label="'`basename $dir`'">'
	echo '<action name="Execute"><execute>'
	echo "spacefm $dir"
	echo '</execute></action></item>'
done

echo '</openbox_pipe_menu>'
