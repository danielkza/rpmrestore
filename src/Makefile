# $Id$
# recommanded by debian install guide
DESTDIR=

PACKAGE=rpmrestore
SHELL = /bin/sh
VERSION=$(shell grep Version rpmrestore.lsm | awk '{print $$2}')

BINDIR = $(DESTDIR)/usr/bin
MANDIR = $(DESTDIR)/usr/share/man
MAN1DIR = $(MANDIR)/man1
DOCDIR=$(DESTDIR)/usr/share/doc/$(PACKAGE)-$(VERSION)

DOC = Authors  Changelog  COPYING NEWS Todo $(PACKAGE).lsm $(PACKAGE).spec Makefile Readme
MANPAGES1 = $(PACKAGE).1
SCRIPTS = $(PACKAGE).pl

%.1 : %.pl
	pod2man $^ > $@

all: $(MANPAGES1)

install : $(DOC) $(MANPAGES1) $(SCRIPTS)
	mkdir -p              $(BINDIR)
	install -m 755 $(SCRIPTS) $(BINDIR)
	mkdir -p                  $(MAN1DIR)
	install -m 644 ${MANPAGES1} $(MAN1DIR)
	mkdir -p                    $(DOCDIR)
	install -m 644 ${DOC}	$(DOCDIR)

uninstall :
	cd $(BINDIR) && rm $(SCRIPTS)
	cd $(MAN1DIR) && rm ${MANPAGES1}
	rm -rf $(DOCDIR)

man : $(MANPAGES1)

dist : $(DOC) $(MANPAGES1) $(SCRIPTS)
	mkdir $(PACKAGE)-$(VERSION)
	cp $(DOC) $(MANPAGES1) $(SCRIPTS) $(PACKAGE)-$(VERSION)
	tar cvfz $(PACKAGE).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)

rpm : dist
	rpmbuild -ta --sign $(PACKAGE).tar.gz
	
clean :
	rm $(MANPAGES1)
	rm $(PACKAGE).tar.gz

