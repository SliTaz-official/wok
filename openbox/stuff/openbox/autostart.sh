# This shell script is run before Openbox launches.
# Environment variables set here are passed to the Openbox session.

BG=/usr/share/images/slitaz-yellowshadow-1024x768.png
#BG=$HOME/Images/background.png

# Set a background color usin hsetroot (depends on imlib2) or xsetroot.
if which hsetroot >/dev/null; then
	hsetroot -fill $BG &
else
	if which xsetroot >/dev/null; then
		xsetroot -solid "#222222" &
	fi
fi

# Login sound.
alsaplayer -i text /usr/share/sounds/login.ogg || continue &

# Start the panel.
lxpanel || continue &
