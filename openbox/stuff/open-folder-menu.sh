#!/bin/sh
#
# Openbox pipe menu to launch file-manager using GTK bookmarks.
#
echo '<openbox_pipe_menu>'

bookmarks="#$(whoami)
~/Desktop $(gettext gtk20 Desktop)
$(cat ~/.gtk-bookmarks)"

IFS='
'
for dir in $bookmarks; do
	cat << EOT
	<item label="$(echo $dir | sed -e 's|^[^ ]* ||' -e 's|#||')">
		<action name="Execute">
			<execute>file-manager $(echo $dir | awk '{print $1}')</execute>
		</action>
	</item>
EOT
done

echo '</openbox_pipe_menu>'
