# This script is executed before Karmen session starts on SliTaz.
#

# Background color.
xsetroot -solid grey4 &

# Cursor setting.
xsetroot -cursor_name arrow

# Wbar icons panel with a custom config file for Karmen providing
# a settings and logout function.
(sleep 2 && wbar -config $HOME/.config/karmen/wbar -pos top center \
	-jumpf 0 -zoomf 1.8 -isize 24 -bpress -balfa 0) &
