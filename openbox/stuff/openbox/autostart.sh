# This shell script is run before Openbox launches.
# Environment variables set here are passed to the Openbox session.

#BG=/usr/share/images/slitaz-background.png
#BG=$HOME/Images/background.png

# Set a background color usin hsetroot (depends on imlib2) or xsetroot.
#if which hsetroot >/dev/null; then
	#hsetroot -fill $BG &
#else
	#if which xsetroot >/dev/null; then
		#xsetroot -solid "#222222" &
	#fi
#fi

# Start PCmanFM as deamon
if which pcmanfm >/dev/null; then
	pcmanfm -d &
fi

# Start the panel.
if which lxpanel >/dev/null; then
	lxpanel &
fi
