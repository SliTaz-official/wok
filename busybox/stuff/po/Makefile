# Makefile for daemon.
#
prefix      ?= /usr
datarootdir ?= $(prefix)/share
localedir   ?= $(datarootdir)/locale
DESTDIR     ?=
LINGUAS     ?= $(shell cat LINGUAS)
POTFILES    ?= $(shell cat POTFILES)
VERSION     ?= 1.0

.PHONY: all pot msgmerge msgfmt

all: msgfmt

pot:
	xgettext -o daemon.pot -L Shell \
		--package-name=daemon \
		--package-version="$(VERSION)" \
		-kaction -k_ -k_n \
		$(POTFILES)

msgmerge:
	@for l in $(LINGUAS); do \
		if [ -f "$$l.po" ]; then \
			echo -n "Updating $$l po file."; \
			msgmerge -U $$l.po daemon.pot ; \
		fi; \
	done

msgfmt:
	@for l in $(LINGUAS); do \
		if [ -f "$$l.po" ]; then \
			echo -n "Compiling daemon $$l mo file... "; \
			msgfmt -o $$l.mo $$l.po ; \
			echo "done"; \
		fi; \
	done;

install: msgfmt
	@for l in $(LINGUAS); do \
		install -m 0755 -d $(DESTDIR)$(localedir)/$$l/LC_MESSAGES; \
		install -m 0644 $$l.mo \
			$(DESTDIR)$(localedir)/$$l/LC_MESSAGES/daemon.mo; \
	done;

clean:
	rm -f *~
	rm -f *.mo

help:
	@echo "make [ pot | msgmerge | msgfmt | all | install | clean ]"
