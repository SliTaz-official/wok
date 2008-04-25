# This shell script is run before Openbox launches.
# Environment variables set here are passed to the Openbox session.

# Start PCmanFM as deamon for Wallpaper and desktop icons.
if which pcmanfm >/dev/null; then
	pcmanfm -d &
fi

# Start the panel.
if which lxpanel >/dev/null; then
	lxpanel &
fi

# Start Pacellite clipboard.
if which parcellite >/dev/null; then
	parcellite &
fi

# Set a background color using hsetroot (depends on imlib2) or xsetroot.

#BG=/usr/share/images/slitaz-background.png
#BG=$HOME/Images/background.png

#if which hsetroot >/dev/null; then
	#hsetroot -fill $BG &
#else
	#if which xsetroot >/dev/null; then
		#xsetroot -solid "#222222" &
	#fi
#fi
