# Initial spec file created by autospec ver. 0.8 with rpm 3 compatibility
Summary: rpmrestore
# The Summary: line should be expanded to about here -----^
#Summary(fr): (translated summary goes here)
Name: rpmrestore
Version: 0.8
Release: 1
Group: Applications/System
#Group(fr): (translated group goes here)
License: GPL
Source: rpmrestore.tar.gz
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
The rpm database store user, group, time, mode for all files,
and offer a command to display the changes between install state (database)
and current disk state. rpmrestore will help you to restore install attributes

#%description -l fr
#(translated description goes here)

%prep
%setup
#%patch

%build
echo "build"
make

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT install

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf "$RPM_BUILD_ROOT"

%files
%defattr(-,root,root)
%dir %{_bindir}
%{_bindir}/rpmrestore.pl
%dir %{_mandir}/man1
%doc %{_mandir}/man1/rpmrestore.1*
%doc rpmrestore.lsm
%doc Authors
%doc COPYING
%doc Changelog
%doc NEWS
%doc Todo
%doc Makefile
%doc Readme
%doc rpmrestorerc.sample

%changelog
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
