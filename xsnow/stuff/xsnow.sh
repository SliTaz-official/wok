#!/bin/sh
icon=--window-icon=/usr/share/pixmaps/xsnow.png
# egrep -v '[A-Z]|gray|[0-9]$' /usr/share/X11/rgb.txt |cut -f 3 |tr '\n' '!'
colors='snow!ghost white!white smoke!gainsboro!floral white!old lace!linen!antique white!papaya whip!blanched almond!bisque!peach puff!navajo white!moccasin!cornsilk!ivory!lemon chiffon!seashell!honeydew!mint cream!azure!alice blue!lavender!lavender blush!misty rose!white!black!dark slate grey!dim grey!slate grey!light slate grey!grey!light grey!midnight blue!navy!navy blue!cornflower blue!dark slate blue!slate blue!medium slate blue!light slate blue!medium blue!royal blue!blue!dodger blue!deep sky blue!sky blue!light sky blue!steel blue!light steel blue!light blue!powder blue!pale turquoise!dark turquoise!medium turquoise!turquoise!cyan!light cyan!cadet blue!medium aquamarine!aquamarine!dark green!dark olive green!dark sea green!sea green!medium sea green!light sea green!pale green!spring green!lawn green!green!chartreuse!medium spring green!green yellow!lime green!yellow green!forest green!olive drab!dark khaki!khaki!pale goldenrod!light goldenrod yellow!light yellow!yellow!gold!light goldenrod!goldenrod!dark goldenrod!rosy brown!indian red!saddle brown!sienna!peru!burlywood!beige!wheat!sandy brown!tan!chocolate!firebrick!brown!dark salmon!salmon!light salmon!orange!dark orange!coral!light coral!tomato!orange red!red!hot pink!deep pink!pink!light pink!pale violet red!maroon!medium violet red!violet red!magenta!violet!plum!orchid!medium orchid!dark orchid!dark violet!blue violet!purple!medium purple!thistle!dark grey!dark blue!dark cyan!dark magenta!dark red!light green'
settings=$(LC_NUMERIC=C yad --form --columns=2 --title="xsnow settings" $icon \
	--field="Number of snowflakes":NUM \
	--field="Snow color":CB --field="Set background color":CHK \
	--field="Background color":CB --field="Christmas trees color":CB \
	--field="Santa Claus's size":NUM --field="Sleigh speed (-1 = default)":NUM \
	--field="Sleigh refresh factor 1/":NUM --field="Snow update delay (ms)":NUM \
	--field="Smooth snow movement":CHK --field="Snow whirling speed (max)":NUM \
	--field="Snow drifting speed (max)":NUM \
	--field="Snow falling speed (max)":NUM \
	--field="Windy periods":CHK --field="Windy periods interval (s)":NUM \
	--field="Maximal snow depth on windows":NUM \
	--field="Maximal snow depth on screen bottom":NUM \
	--field="Vertical offset of snow layers":NUM \
	--field="Christmas trees":CHK --field="Santa Claus":CHK --field="Rudolf":CHK \
	--field="Snow layers on windows":CHK \
	--field="Snow layer on screen bottom":CHK \
	--field="Check this if snow layering doesn't work":CHK \
	--field="Duration (min) (0 = unlimited)":NUM \
	-- '100!1..1000' "$colors" 'true' SkyBlue3\!"$colors" \
	chartreuse\!"${colors/chartreuse!/}" '2!0..2' '-1!-1..inf' '3!1..inf' \
	50 true '3!1..inf' 2 10 true 30 15 50 0 true true true true true false 0)
[ $? -eq 0 ] || exit 1
pid1=$(pgrep -fl 'spacefm --desktop'|cut -f1 -d' ')
pid2=$(pgrep -fl 'pcmanfm --desktop'|cut -f1 -d' ')
[ -n "$pid1" -o -n "$pid2" ] && { yad --title=Warning $icon \
	--text="Your file manager windows will be closed, and your desktop icons \
temporarily removed. Continue?" || exit 2 ;}
[ -n "$pid1" ] && kill $pid1
[ -n "$pid2" ] && kill $pid2
# add dummy var to gobble last |
IFS='|' read sf sc back bc tc ssiz ssp suf delay smooth wf xs ys wind wtimer \
winsd scrsd off trees santa rud winsn scrsn popupsn duration dummy<<EOT
$settings
EOT
[ $back = FALSE ] && back=''
flags=''
[ $smooth = FALSE ] && flags=$flags" -unsmooth"
[ $wind = FALSE ] && flags=$flags" -nowind"
[ $trees = FALSE ] && flags=$flags" -notrees"
[ $santa = FALSE ] && flags=$flags" -nosanta"
[ $rud = FALSE ] && flags=$flags" -norudolf"
if [ $winsn = FALSE -a $scrsn = FALSE ]; then flags=$flags" -nokeepsnow"
elif [ $winsn = FALSE ]; then flags=$flags" -nokeepsnowonwindows"
elif [ $scrsn = FALSE ]; then flags=$flags" -nokeepsnowonscreen"
fi
[ $popupsn = TRUE ] && flags=$flags" -nonopopup"
xsnow -snowflakes ${sf%.*} -sc "$sc" ${back:+-solidbg -bg "$bc"} -tc "$tc" \
	-santa ${ssiz%.*} -santaspeed ${ssp%.*} -santaupdatefactor ${suf%.*} \
	-delay ${delay%.*} -whirl ${wf%.*} -xspeed ${xs%.*} -yspeed ${ys%.*} \
	-windtimer ${wtimer%.*} -wsnowdepth ${winsd%.*} -ssnowdepth ${scrsd%.*} \
	-offset ${off%.*} $flags >/dev/null 2>&1 &
yad --button=gtk-stop --title='Stop xsnow' $icon \
	--timeout=$((60*${duration%.*}))
pkill -x xsnow
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
