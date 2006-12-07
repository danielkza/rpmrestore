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

DOC = Authors  Changelog  COPYING NEWS Todo $(PACKAGE).lsm $(PACKAGE).spec Makefile Readme rpmrestorerc.sample test_rpmrestore.pl
MANPAGES1 = $(PACKAGE).1
SCRIPTS = $(PACKAGE).pl

# convert pod to other doc format
%.1 : %.pl
	pod2man $^ > $@

%.1.html : %.pl
	pod2html --header $^ > $@

# default target : build man
# and check syntaxe
man : $(MANPAGES1)
	perl -cw $(SCRIPTS)

all: install

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

dist : $(DOC) $(MANPAGES1) $(SCRIPTS)
	mkdir $(PACKAGE)-$(VERSION)
	cp $(DOC) $(MANPAGES1) $(SCRIPTS) $(PACKAGE)-$(VERSION)
	tar cvfz $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)

rpm : dist
	rpmbuild -ta --sign $(PACKAGE)-$(VERSION).tar.gz
	
clean :
	rm -f $(MANPAGES1)
	rm -f $(PACKAGE)-$(VERSION).tar.gz
	rm -f pod2*
	

# to be done on root account juster after the package install
test :
	./test_rpmrestore.pl

html : rpmrestore.1.html

help :
	@echo "available target are :"
	@echo "make : build files"
	@echo "make man : build man page from pod"
	@echo "make install : install software"
	@echo "make all : same as make install"
	@echo "make uninstall : remove software"
	@echo "make dist : build a tar.gz package"
	@echo "make rpm : build an rpm package"
	@echo "make clean : remove temporary files"
	@echo "make test : test rpmrestore software (need to be root for full test"
	@echo "make html : build html doc from pod"
	@echo "make help : this help"
