# echinus wm version
VERSION = 0.4.0

# Customize below to fit your system

# paths
PREFIX = /usr/
MANPREFIX = ${PREFIX}/share/man
CONF = /share/examples/echinus

X11INC = /usr/X11R6/include
X11LIB = /usr/X11R6/lib

# includes and libs
INCS = -I. -I/usr/include -I${X11INC} `pkg-config --cflags xft`
LIBS = -L/usr/lib -lc -L${X11LIB} -lX11 `pkg-config --libs xft`

# flags
CFLAGS = -Os ${INCS} -DVERSION=\"${VERSION}\" -DSYSCONFPATH=\"${PREFIX}/${CONF}\"
LDFLAGS = -s ${LIBS}

# XRandr (multihead support). Comment out to disable.
CFLAGS += -DXRANDR=1
LIBS += -lXrandr