#!/bin/sh
#
[ -z $(which yad) ] && exec yad && exit 0

case $(id -u) in
	0) path=/etc/xdg ;;
	*) path=${XDG_CONFIG_HOME:-$HOME/.config}
		[ -f "$path/autostart" ] && mv $path/autostart $path/autostart.bak
		[ -d "$path/autostart" ] || mkdir -p $path/autostart ;;
esac

AutostartFile="$path/autostart/xset-screensaver.desktop"
launcher='/usr/share/applications/xorg-xset.desktop' # Must be same as package name

exec_d()
{
	cmd=$(cat $AutostartFile | grep Exec | sed 's/Exec=//') ; $cmd
}

[ -f $AutostartFile ] && exec_d

case $LC_ALL in
	C|POSIX|en*) lang='=' ;;
	*) lang='\['${LC_ALL%_*}
	grep -q '\['${LC_ALL%_*} $launcher || lang='=' ;;
esac



val=$(yad --title="$(cat $launcher | grep Name$lang | cut -d'=' -f2)" \
	--scale --max-value=18000 --mark="1h.":3600 --buttons-layout=spread \
	--mark="$(cat $launcher | grep Comment$lang | cut -d'=' -f2 | cut -d',' -f1)":0 \
	--mark="120min.(2h.)":7200 --mark="180min.(3h.)":10800 \
	--mark="240min.(4h.)":14400 --mark="300min.(5h.)":18000 \
	--page=1800 --step=60 --geometry=630x42+10+100 \
	--value=$(xset q | grep timeout | cut -d' ' -f5) \
	--window-icon="preferences-desktop-screensaver" )

[ -z $val ] || cat > $AutostartFile <<EOT
[Desktop Entry]
Type=Application
Name=xset screensaver timeout
Exec=xset dpms $val $val $val s $val $val
EOT

exec_d

# Notes: 'xset s' max val is 32767, 'xset dpms' limit is unknown
exit 0
