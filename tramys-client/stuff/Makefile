# Makefile for tramys-client
#
LINGUAS?=ru

pot:
	xgettext -o po/tramys.pot -L Shell -k_ --package-name=tramys ./tramys2

msgmerge:
	@for l in $(LINGUAS); do \
		if [ -f "po/$$l.po" ]; then \
			echo -n "Updating $$l po file."; \
			msgmerge -U po/$$l.po po/tramys.pot ; \
		fi; \
	done

msgfmt:
	@for l in $(LINGUAS); do \
		if [ -f "po/$$l.po" ]; then \
			echo -n "Compiling tramys $$l mo file... "; \
			mkdir -p po/mo/$$l/LC_MESSAGES; \
			msgfmt -o po/mo/$$l/LC_MESSAGES/tramys.mo po/$$l.po ; \
			echo "done"; \
		fi; \
	done;

clean:
	rm -rf po/mo
	rm -f po/*~
	rm -f po/*.mo

help:
	@echo "make [ pot | msgmerge | msgfmt | clean ]"
