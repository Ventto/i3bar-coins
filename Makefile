PKGNAME     = i3bar-coins
PKGDESC     = POSIX Shell script to show crypto-currency values in i3bar

SCRIPT      = $(PKGNAME).sh
MANPAGE     = $(PKGNAME).1.gz

LICENSEDIR  = $(DESTDIR)/usr/share/licenses/$(PKGNAME)
MANDIR      = $(DESTDIR)/usr/share/man/man1
BINDIR      = $(DESTDIR)/usr/bin
SHAREDIR    = $(DESTDIR)/usr/share/$(PKGNAME)

install :$(MANPAGE)
	mkdir -p $(LICENSEDIR)
	mkdir -p $(MANDIR)
	mkdir -p $(SHAREDIR)
	mkdir -p $(BINDIR)
	chmod 644 LICENSE
	chmod 644 $(PKGNAME).1.gz
	chmod 644 data/api_crypto_ids
	chmod 644 data/money_symbols
	chmod 755 $(PKGNAME).sh
	cp LICENSE $(LICENSEDIR)/LICENSE
	cp $(PKGNAME).1.gz $(MANDIR)/$(MANPAGE)
	cp -r data $(SHAREDIR)
	cp $(PKGNAME).sh $(BINDIR)/$(PKGNAME)

$(MANPAGE):
	help2man -N -n "$(PKGDESC)" -h -h -v -v ./$(SCRIPT) | gzip - > $@

uninstall:
	$(RM) -r $(LICENSEDIR) $(SHAREDIR)
	$(RM) $(MANDIR)/$(MANPAGE) $(BINDIR)/$(PKGNAME)

.PHONY: install uninstall
