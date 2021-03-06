# $Id$
# recommanded by debian install guide
DESTDIR=

PACKAGE=rpmrestore

SHELL = /bin/sh
VERSION=$(shell grep Version rpmrestore.lsm | awk '{print $$2}')

BINDIR = $(DESTDIR)/usr/bin
LOGETC = $(DESTDIR)/etc/
MANDIR = $(DESTDIR)/usr/share/man
MAN1DIR = $(MANDIR)/man1
# on some distribution it is $(PACKAGE)-$(VERSION) (fedora), on others $(PACKAGE) (mandriva)
# we force it with a define in rpm target to be able to build on any host the same way
DOCDIR=$(DESTDIR)/usr/share/doc/$(PACKAGE)-$(VERSION)

DOC = Authors Changelog COPYING NEWS Todo $(PACKAGE).lsm $(PACKAGE).spec Makefile Readme rpmrestorerc.sample test_rpmrestore.pl

PROGS =  $(PACKAGE) rpmrestore_all
MANPAGES1 := $(addsuffix .1, $(PROGS))
HTMLPAGES := $(addsuffix .1.html, $(PROGS))
SCRIPTS := $(addsuffix .pl, $(PROGS) ) 

# file with keyword
KEYWORD_FILES = $(SCRIPTS) Makefile Readme rpmrestorerc.sample

# convert pod to other doc format
%.1 : %.pl
	pod2man $^ > $@

%.1.html : %.pl
	pod2html --header $^ | sed -f html.sed > $@
	tidy -m -i -asxhtml -utf8 --doctype strict $@ || echo "tidy"

# loop to check all perl scripts
define check_perl_script
	for fic in $(SCRIPTS);do	\
		perl -cw $$fic || exit;		\
		perlcritic --verbose 10 -3 $$fic || exit;	\
	done;
endef

# loop to make links on all programs
define make_links
	for fic in $(PROGS);do        \
		cd $(BINDIR) && ln -s $$fic.pl $$fic;	\
	done;
endef


# default
help :
	@echo "available target are :"
	@echo "make all : same as make install"
	@echo "make help : this help"
	@echo "make install : install software"
	@echo "make uninstall : remove software"
	@echo "### for project packagers only ###########"
	@echo "make alldist : build all packages"
	@echo "make check : check perl syntaxe"
	@echo "make clean : remove temporary files"
	@echo "make dist : build a tar.gz package"
	@echo "make html : build html doc from pod"
	@echo "make man : build man page from pod"
	@echo "make rpm : build an rpm package"
	@echo "make test : test rpmrestore software (need to be root for full test"

all: install

# install perl scripts
install : $(DOC) $(MANPAGES1) $(SCRIPTS)
	mkdir -p		$(BINDIR)
	install -m 755 $(SCRIPTS) $(BINDIR)
	mkdir -p                $(MAN1DIR)
	install -m 644 ${MANPAGES1} $(MAN1DIR)
	mkdir -p		$(LOGETC)
	install -m 644 rpmrestorerc.sample $(LOGETC)/rpmrestorerc
	mkdir -p		$(DOCDIR)
	install -m 644 ${DOC}	$(DOCDIR)

uninstall :
	cd $(BINDIR) && rm $(SCRIPTS) $(PROGS)
	cd $(MAN1DIR) && rm ${MANPAGES1}
	rm -f $(LOGETC)/rpmrestorerc
	rm -rf $(DOCDIR)

################################################################################
# targets for project packagers
################################################################################

# build all packages
alldist : check dist rpm html

# check perl script syntax
check : $(SCRIPTS)
	$(check_perl_script)

# build man pages
man : $(MANPAGES1)

# build tar.gz package
dist : $(DOC) man $(SCRIPTS) expand
	mkdir $(PACKAGE)-$(VERSION)
	cp -a $(DOC) $(MANPAGES1) $(SCRIPTS) $(PACKAGE)-$(VERSION)
	tar cvfz $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)
	~/bin/gensign.sh $(PACKAGE)-$(VERSION).tar.gz

# build rpm package
rpm : dist
	rpmbuild -ta --sign --define '_docdir_fmt %%{NAME}-%%{VERSION}' $(PACKAGE)-$(VERSION).tar.gz

# clean temp files
clean : unexpand
	rm -f $(MANPAGES1)
	rm -f $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION).tar.gz.sig
	rm -f pod2*
	rm -f *.html

# build man page in html for web site
html : $(HTMLPAGES)
	mv *.html ../web

# expand svn keywords just for publish
expand: $(KEYWORD_FILES)
	git tag -f "$(PACKAGE)-$(VERSION)"
	git-svn-keyword-expand $(KEYWORD_FILES)

# remove svn keywords to keep repository clean
unexpand: $(KEYWORD_FILES)
	git-svn-keyword-unexpand $(KEYWORD_FILES)

# to be done on root account juster after the package install
test :
	./test_rpmrestore.pl
