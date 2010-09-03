# recorder Makefile
INSTALL ?= install
MAKE ?= make
RM ?= rm
RMDIR ?= rmdir
prefix ?= /usr

PREFIX = $(DESTDIR)$(prefix)
BINDIR = $(PREFIX)/bin
APPDIR = $(PREFIX)/share/applications
ICONDIR = $(PREFIX)/share/pixmaps
LOCALEDIR = $(PREFIX)/share/locale

install:
	$(INSTALL) -m 755 -d $(BINDIR) $(APPDIR) $(ICONDIR)
	$(INSTALL) -m 644 recorder.png $(ICONDIR)
	$(INSTALL) -m 644 recorder.desktop $(APPDIR)
	$(INSTALL) -m 755 recorder $(BINDIR)

.PHONY: help install
