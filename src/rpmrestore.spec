%define VERSION 1.6
Summary: rpmrestore restore file attributes from rpm database
# The Summary: line should be expanded to about here -----^
Summary(fr): rpmrestore restore les attributs d'installation
Name: rpmrestore
Version: %{VERSION}
Release: 1
Group: Applications/System
#Group(fr): (translated group goes here)
License: GPL
Source: rpmrestore-%{VERSION}.tar.gz
BuildRoot: %{_tmppath}/%{name}-root
# Following are optional fields
URL: http://rpmrestore.sourceforge.net
#Distribution: Red Hat Contrib-Net
#Patch: src-%{version}.patch
#Prefix: /usr
BuildArch: noarch
Requires: perl
Requires: rpm
#Obsoletes: 
#BuildRequires: 

%description
The rpm database store user, group, time, mode for all files.
Rpmrestore allow to display the change between the current state and the rpm 
database. Il also allow to restore this attribute to their install value.

rpmrestore_all.pl will work on all installed packages.

%description -l fr
La base de donn�es rpm conserve pour chaque fichier les attributs :
proprietaire, groupe, taille, date de modification, checksum.
Rpmrestore permet de comparer les attributs courants avec ceux de la base rpm, 
et de les restaurer � leur valeur originale.

rpmrestore_all.pl permet de travailler sur l'ensemble des packages rpm install�s.

%prep
%setup
#%patch

%build
#echo "build"
make

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT install

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf "$RPM_BUILD_ROOT"

%files
%defattr(-,root,root)
%{_bindir}/rpmrestore.pl
%{_bindir}/rpmrestore_all.pl
%doc %{_mandir}/man1/rpmrestore.1*
%doc %{_mandir}/man1/rpmrestore_all.1*
%config(noreplace) /etc/rpmrestorerc
%doc rpmrestore.lsm
%doc Authors
%doc COPYING
%doc Changelog
%doc NEWS
%doc Todo
%doc Makefile
%doc Readme
%doc rpmrestorerc.sample
%doc test_rpmrestore.pl

%changelog
* Wed Nov 21 2013 Eric Gerbier <gerbier@users.sourceforge.net> 1.6
- add rpmrestore_all.pl tool
- bugfix interactive mode
- check if file is owned by several packages

* Tue Aug 03 2012 Eric Gerbier <gerbier@users.sourceforge.net> 1.5
- change api to be more natural (-f/-p otions are deprecated)
- add global configuration file /etc/rpmrestorerc

* Tue Jul 27 2012 Eric Gerbier <gerbier@users.sourceforge.net> 1.4
- add capability option

* Tue Nov 13 2007 Eric Gerbier <gerbier@users.sourceforge.net> 1.3
- standardize man pages
- shell independance : can now work with c-shell*
- remove all perlcritic warnings

* Tue Mar 20 2007 Eric Gerbier <gerbier@users.sourceforge.net> 1.2
- rc file is now loaded in order : host, home, local
- change debug system (no more global var)
- apply some Conway coding rules
- fix a localisation problem
- split code in smaller subroutines
- improved documentation
- remove global variables

* Fri Jan 05 2007 Eric Gerbier <gerbier@users.sourceforge.net> 1.1
- fix a bug for directories

* Fri Dec 07 2006 Eric Gerbier <gerbier@users.sourceforge.net> 1.0
- add french translation in spec
- add perl syntaxe checking on "build" (makefile)

* Thu Nov 15 2006 Eric Gerbier <gerbier@users.sourceforge.net> 0.9
- add more tests (if package exists, if file exists ...)
- add more infos
- add regression tests (test_rpmrestore.pl)

* Thu Nov 08 2006 Eric Gerbier <gerbier@users.sourceforge.net> 0.8
- add info sub
- add doc for all attributes
- can use rcfile
- recode rollback to use options (batch, dryrun, attributes choice)
- default behavior is to work on all attributes
- attributes can now be negative (unselected)
- append on log file if it exists
- remove call to external touch program

* Thu Oct 26 2006 Eric Gerbier <gerbier@users.sourceforge.net> 0.3
- add md5 attribute (compare only)

* Thu Oct 6 2006  <gerbier@users.sourceforge.net> 0.2
- test for superuser

* Fri Sep 22 2006  <gerbier@users.sourceforge.net> 0.1
- Initial spec file created by autospec ver. 0.8 with rpm 3 compatibility
