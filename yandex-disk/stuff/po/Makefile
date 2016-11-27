# Makefile for yandex-disk-helper
#
LINGUAS = ru uk

pot:
	xgettext -o yandex-disk-helper.pot -L Shell -k -k_ \
		--package-name="Yandex.Disk helper" \
		../usr/bin/yandex-disk-helper \
		../usr/libexec/yandex-disk/publish \
		../usr/libexec/yandex-disk/status \
		../usr/libexec/yandex-disk/unpublish

msgmerge:
	@for l in $(LINGUAS); do \
		if [ -f "$$l.po" ]; then \
			echo "Updating $$l po file."; \
			msgmerge -U $$l.po $$p.pot; \
		fi; \
	done;

msgfmt:
	@for l in $(LINGUAS); do \
		if [ -f "$$l.po" ]; then \
			echo -e "Compiling $$l mo file...\n"; \
			mkdir -p mo/$$l/LC_MESSAGES; \
			msgfmt -o mo/$$l/LC_MESSAGES/yandex-disk-helper.mo $$l.po; \
		fi; \
	done;

install: msgfmt
	mkdir -p   $(DESTDIR)/usr/share/locale
	cp -a mo/* $(DESTDIR)/usr/share/locale

clean:
	rm -rf  mo
	rm -f *.mo
	rm -f *.*~
