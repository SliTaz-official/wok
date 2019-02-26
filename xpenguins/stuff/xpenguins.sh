#!/bin/sh
icon=--window-icon=/usr/share/pixmaps/xpenguins.png
toons=$(xpenguins -l | yad --list --title="xpenguins settings (1/2)" $icon \
	--text="Select all the toons you want to display" --height=330 \
	--column="Theme name" --multiple --separator='')
[ $? -eq 0 ] || exit 1
[ -z $toons ] && toons=$(xpenguins -l)
themes=''
# double-quote theme names (some have spaces) then use xargs
while read theme ; do themes=$themes' -t "'$theme'"' ; done <<EOT
$toons
EOT
settings=$(LC_NUMERIC=C yad --form --title="xpenguins settings (2/2)" $icon \
	--field="Animation update delay (ms) (0 = default)":NUM \
	--field="Number of toons (-1 = default)":NUM \
	--field="Ignore popup windows":CHK --field="Don't show any blood":CHK \
	--field="Don't show any angel":CHK \
	--field="Destroy toons with mouseclick":CHK \
	--field="Duration (min) (0 = unlimited)":NUM \
	-- '0' '-1!-1..256' false false false true 0)
[ $? -eq 0 ] || exit 2
pid1=$(pgrep -fl 'spacefm --desktop'|cut -f1 -d' ')
pid2=$(pgrep -fl 'pcmanfm --desktop'|cut -f1 -d' ')
[ -n "$pid1" -o -n "$pid2" ] && yad --title=Warning $icon \
	--text="Your file manager windows will be closed, and your desktop icons \
temporarily removed. Continue?"
[ $? -eq 0 ] || exit 3
[ -n "$pid1" ] && kill $pid1
[ -n "$pid2" ] && kill $pid2
#add dummy var to gobble last |
IFS='|' read delay number nopopup noblood noangel squish duration dummy<<EOT
$settings
EOT
flags=''
[ $nopopup = TRUE ] && flags=$flags" -p"
[ $noblood = TRUE ] && flags=$flags" -b"
[ $noangel = TRUE ] && flags=$flags" -a"
[ $squish = TRUE ] && flags=$flags" -s"
printf '%s' "$themes" | xargs xpenguins -m ${delay%.*} -n ${number%.*} $flags \
	>/dev/null 2>&1 &
yad --button=gtk-stop --title='Stop xpenguins' $icon \
	--timeout=$((60*${duration%.*}))
pkill -x xpenguins
alias pcmanfm='pcmanfm --desktop 2>/dev/null &'
alias spacefm='spacefm --desktop 2>/dev/null &'
# restart filemanager(s)
if [ -n "$pid1" ]; then
	if [ -n "$pid2" ]; then
		# in case both were running
		if [ $pid1 -lt $pid2 ]; then
			spacefm
			pcmanfm
		else
			pcmanfm
			spacefm
		fi
	else
		spacefm
	fi
elif [ -n "$pid2" ]; then
	pcmanfm
fi
