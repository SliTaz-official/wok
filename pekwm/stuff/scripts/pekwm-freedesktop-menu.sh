#!/bin/sh
#
# Freedesktop standard Dynamic menu for PekWM. Look into all files
# into /usr/share/applications and display Entry with Exec, no icons
# to speed-up menu generation. Created for SliTaz GNU/Linux project.
#

echo "Dynamic {"
for app in /usr/share/applications/*
do
	name=`grep ^Name= $app | sed s/Name=//`
	exec=`grep ^Exec= $app | sed s/Exec=//`
	echo "	Entry = \"$name\" { Actions = \"Exec $exec\" }"
done
echo "}"
