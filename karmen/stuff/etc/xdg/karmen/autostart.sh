# This script is executed before Karmen session starts on SliTaz.
#

# Background color.
xsetroot -solid grey4 &

# Cursor setting.
xsetroot -cursor_name arrow &

# Start an Xterm.
xterm &

# Start Karmen configurator/menu
xterm -geometry 50x20 -e karmen-conf &

# Xclock
xclock &
