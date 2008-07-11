PREFIX          = /usr
CFLAGS          = -DuseXaw -DONLINE_HELP -DSOUND -DGFX2
CFLAGS         += -DLIBDIR=\"/usr/share/xpat2\"
CFLAGS         += -DSCOREFILE=\"/var/games/xpat2/xpat.log\"
LDFLAGS         = -lX11 -lXaw

STDOBJS         = rules.o commands.o messages.o hints.o layout.o \
                  arrows.o loadsave.o util.o moves.o \
                  r_Klondike.o r_Spider.o r_Delight.o r_MonteCarlo.o \
                  r_Midnight.o r_Gypsy.o r_Seahaven.o r_FreeCell.o \
                  r_Calculatio.o r_Michaels.o r_Royal.o r_Canfield.o \
                  r_mdCanfield.o r_Bakers.o r_Oonsoo.o r_BlueMoon.o

XOBJS		= X-events.o X-layout.o X-expose.o X-cards.o \
		  X-markcard.o X-arrows.o X-widget.o $(GFXOBJ) \
		  Xaw-help.o Xaw-main.o X-sound_SUN.o X-gfx2.o

OBJS            = $(STDOBJS) $(XOBJS)

MYPROG          = xpat2

all: $(MYPROG)

$(MYPROG): $(OBJS)
	gcc -o $(MYPROG) $(LDFLAGS) $(OBJS)
	
install:
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 xpat2 $(DESTDIR)$(PREFIX)/bin
	install -d $(DESTDIR)$(PREFIX)/share/xpat2/default
	install -m 644 ../lib/help* ../lib/hlp* ../lib/keys $(DESTDIR)$(PREFIX)/share/xpat2
	install -m 644 ../lib/default/* $(DESTDIR)$(PREFIX)/share/xpat2/default

clean:
	rm $(MYPROG) *.o
