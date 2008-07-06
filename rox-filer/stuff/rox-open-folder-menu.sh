#!/bin/sh
#
# Openbox pipe menu to launch rox-filer using GTK bookmarks.
#

echo '<openbox_pipe_menu>'

# Home
echo '<item label="Home">'
echo '<action name="Execute"><execute>'
echo "rox-filer ~"
echo '</execute></action></item>'



# GTK bookmarks
for dir in `sed 's/[ ][^ ]*$//' .gtk-bookmarks | sed 's!file://!!'`
do
	echo '<item label="'`basename $dir`'">'
	echo '<action name="Execute"><execute>'
	echo "rox-filer $dir"
	echo '</execute></action></item>'
done

echo '</openbox_pipe_menu>'
