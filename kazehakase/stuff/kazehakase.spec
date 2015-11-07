# svnroot: http://svn.sourceforge.jp/svnroot/kazehakase/kazehakase/trunk
# To create svn based tarball, follow:
# $ svn ro $svnroot
# $ mv trunk %%name-%%version-svn%%svnver
# $ tar czf %%name-%%version-svn%%svnver.tar.gz %%name-%%version-svn%%svnver

# Filtering out unwanted Provides
%define		_use_internal_dependency_generator	0

%define		support_anthy	0
%define		support_ruby	1
%if 0%{?fedora} < 19
%define		rubyabi		1.9.1
%endif
%define		support_webkit	1

%define		usesvn		1
%define		need_autogen	0

%define		min_webkit_EVR	1.1.1

%if 0%{?fedora} >= 13
%define		Geckover	1.9.2.3
%endif

%if 0%{?usesvn} > 0
%define		need_autogen	1
%endif

%define		obsolete_plugin_ver	0.4.5-1

%define		repoid		43802
%define		svnver		3873_trunk


#
# When changing release number, please make it sure that
# the new EVR won't be higher than the one of higher branch!!
#
%define		fedorarel	17
%define		_release	%{fedorarel}%{?usesvn:.svn%svnver}

%if 0%{?fedora} < 1
# WebKit does not seem to be ready
%define		support_webkit	0
%endif

# Patch17 needs autotools
%define		need_autogen	1

Name:		kazehakase
Version:	0.5.8
#
# When changing release number, please make it sure that
# the new EVR won't be higher than the one of higher branch!!
#
Release:	%{_release}%{?dist}.2
Summary:	Kazehakase browser using Gecko rendering engine

Group:		Applications/Internet
License:	GPLv2+
URL:		http://kazehakase.sourceforge.jp/
Source0:	http://dl.sourceforge.jp/kazehakase/%{repoid}/%{name}-%{version}%{?usesvn:-svn%svnver}.tar.gz
Patch14:	kazehakase-0.5.6-rev3769-embed-vendor-version.patch
Patch17:	kazehakase-0.5.7-external-rev938-libegg-parallel_make.patch
Patch19:	kazehakase-rev3873-gtk222.patch
Patch20:	kazehakase-0.5.8-svn3873_trunk-default-to-webkit.patch
Patch21:	kazehakase-0.5.8-svn3873_trunk-ruby19.patch
Patch22:	kazehakase-0.5.8-svn3873_trunk-egg.patch
# http://lists.gnu.org/archive/html/gnutls-devel/2011-03/msg00034.html
# http://lists.fedoraproject.org/pipermail/devel/2013-February/178231.html
Patch23:	kazehakase-0.5.8-svn3873_trunk-gnutls3-gcry_control.patch

BuildRequires:	dbus-devel
BuildRequires:	expat-devel
BuildRequires:	gnutls-devel
BuildRequires:	gtk2-devel
BuildRequires:	libgcrypt-devel
BuildRequires:	libSM-devel
BuildRequires:	perl(XML::Parser)

BuildRequires:	hyperestraier-devel
%if %{support_anthy}
BuildRequires:	anthy-devel
BuildRequires:	mecab-devel
%endif
%if %{support_ruby}
BuildRequires:	rubygem(gettext)
BuildRequires:	rubygem-gtk2-devel
BuildRequires:	rubygems-devel
%if 0%{?fedora} < 19
BuildRequires:	ruby(abi) = %{rubyabi}
%endif
BuildRequires:	ruby-devel
%endif
%if %{support_webkit}
BuildRequires:	webkitgtk-devel %{?min_webkit_EVR:>= %{min_webkit_EVR}}
%endif

BuildRequires:	desktop-file-utils
BuildRequires:	gettext

Requires:	%{name}-base	= %{version}-%{release}

# GLib version dependency
# Borrowed from pidgin spec file

# Require Binary Compatible glib
# returns bogus value if glib2-devel is not installed in order for parsing to succeed
# bogus value wont make it into a real package
%define glib_ver %([ -a %{_libdir}/pkgconfig/glib-2.0.pc ] && pkg-config --modversion glib-2.0 || echo -n "999")
BuildRequires:	glib2-devel
# drop this for now
# Requires:	glib2 >= %{glib_ver}

BuildRequires:	gecko-devel %{?Geckover:>= %{Geckover}}
BuildRequires:	gecko-devel-unstable
%if 0%{?fedora} >= 15
Requires:	%{name}-webkit = %{version}-%{release}
%else
Requires:	gecko-libs %{?Geckover:>= %{Geckover}}
%endif

BuildRequires:	intltool
%if %{need_autogen}
BuildRequires:	libtool
BuildRequires:	automake
%endif

%description
Kazehakase is a Web browser which aims to provide 
a user interface that is truly user-friendly & fully customizable.

%if 0%{?fedora} >= 15
Note that kazehakase no longer supports Gecko and this
package will always pulls %{name}-webkit subpackage in.
%else
This package uses Gecko for HTML rendering engine.
%endif

%package	base
Summary:	Base package of Kazehakase
Group:		Applications/Internet
%if %{support_ruby} < 1
Obsoletes:	%{name}-ruby < %{version}-%{release}
%endif

%description	base
This package contains base files for Kazehakase.
To use Kazehakase, you also need to install a package
containing HTML rendering engine module for Kazehakase.


%package	hyperestraier
Summary:	Kazehakase search engine of hyperestraier
Group:		Applications/Internet
Requires:	%{name}-base = %{version}-%{release}
Obsoletes:	%{name}-plugins < %{obsolete_plugin_ver}
Obsoletes:	%{name}-plugins-hyperestraier < %{obsolete_plugin_ver}
Provides:	%{name}-plugins = %{version}-%{release}
Provides:	%{name}-plugins-hyperestraier = %{version}-%{release}

%description	hyperestraier
This package contains the search plugin of hyperstraier for
Kazehakase.

%if %{support_anthy}
%package	anthy
Summary:	Kazehakase search engine of Anthy
Group:		Applications/Internet
Requires:	%{name}-base = %{version}-%{release}
Obsoletes:	%{name}-plugins-anthy < %{obsolete_plugin_ver}
Provides:	%{name}-plugins-anthy = %{version}-%{release}

%description	anthy
This package contains the search plugin of Anthy for
Kazehakase.
%endif

%if %{support_ruby}
%package	ruby
Summary:	Ruby interpretter support for Kazehakase
Group:		Applications/Internet
Requires:	%{name}-base = %{version}-%{release}
Requires:	ruby(gtk2)
%if 0%{?fedora} >= 19
Requires:	ruby(release)
%else
Requires:	ruby(abi) = %{rubyabi}
%endif

%description	ruby
This package contains the binding of Kazehakase for
Ruby interpretter.
%endif

%if %{support_webkit}
%package	webkit
Summary:	Kazehakase browser using WebKit rendering engine
Group:		Applications/Internet
Requires:	%{name}-base = %{version}-%{release}
Requires:	webkitgtk %{?min_webkit_EVR:>= %{min_webkit_EVR}}

%description	webkit
Kazehakase is a Web browser which aims to provide 
a user interface that is truly user-friendly & fully customizable.

This package uses WebKit for HTML rendering engine.
%endif

%prep
%setup -q -n %{name}-%{version}%{?usesvn:-svn%svnver}

%patch14 -p1 -b .evr
%patch17 -p0 -b .libegg_mak
%patch19 -p1 -b .gtk
#%%patch18 -p0 -b .xul192
%patch20 -p1 -b .default
%if 0%{?fedora} >= 17
%patch21 -p1 -b .ruby19
%endif
%patch22 -p1 -b .egg
%patch23 -p1 -b .gnutls3

%if %{support_anthy}
%{__sed} -i.anthy -e '/^anthy_available/d' configure
%endif

for f in README.ja TODO.ja ; do
	iconv -f EUCJP -t UTF8 $f > ${f}.tmp && \
		( touch -r ${f} ${f}.tmp ; %{__mv} -f ${f}.tmp ${f} ) || \
		%{__rm} -f ${f}.tmp
done

# Filtering unwanted Provides
%{__cat} > %{name}-filter-provides.sh <<EOF
#!/bin/bash

unset exclude_provides
for f in \$(find %{buildroot}%{_libdir}/%{name}/*/ -type f -name '*.so' -or -name '*.so.*' )
do
	exclude_provides="\$exclude_provides \$(basename \$f)"
done

%{__find_provides} "\$@" | while read prov
do
	skip=0
	for f in \$exclude_provides
	do
		if echo "\$prov" | grep -q "\$f"
		then
			skip=1
			break
		fi
	done
	if [ \$skip = 1 ] ; then continue ; fi
	echo \$prov
done
EOF

%{__sed} -e 's|provides|requires|' %{name}-filter-provides.sh \
	| %{__sed} -e 's|prov|req|' > %{name}-filter-requires.sh
%{__chmod} 0755 %{name}-filter-*.sh
%define	__find_provides	\
	%{_builddir}/%{name}-%{version}%{?usesvn:-svn%svnver}/%{name}-filter-provides.sh
%define	__find_requires	\
	%{_builddir}/%{name}-%{version}%{?usesvn:-svn%svnver}/%{name}-filter-requires.sh

# Enable deprecated for now
find . -name Makefile.am -or -name configure.ac | \
	xargs sed -i.deprecated -e 's|DISABLE_DEPRECATED|NOTDISABLE_DEPRECATED|g'

# Kill xulrunner for F-15+
sed -i.killxul -e '\@^embed_LTLIBRARIES@d' module/embed/gecko/Makefile.am

%build
%if %{need_autogen}
sh autogen.sh
%endif

export CFLAGS="%{optflags} -DVERSION_VENDOR=\\\"%{version}-%{release}\\\""

rm -rf builddir ; mkdir builddir
pushd builddir
ln -sf ../configure

%configure \
	--srcdir=$(pwd)/.. \
	--enable-migemo \
%if %{support_ruby} < 1
	--with-ruby=no \
%endif
	--with-gecko-engine=libxul \
	--disable-gtkmozembed

%{__make} %{?_smp_mflags} -k V=1
popd

%install
%{__rm} -rf $RPM_BUILD_ROOT

pushd builddir
%{__make} install DESTDIR=$RPM_BUILD_ROOT \
	INSTALL="%{__install} -c -p"
popd

%{__rm} -f $RPM_BUILD_ROOT%{_libdir}/%{name}/lib*.so
find $RPM_BUILD_ROOT%{_libdir}/%{name} -name \*.la | xargs %{__rm} -f

desktop-file-install \
%if 0%{?fedora} < 19
	--vendor fedora \
%endif
	--remove-category Application \
	--delete-original \
	--dir $RPM_BUILD_ROOT%{_datadir}/applications \
	$RPM_BUILD_ROOT%{_datadir}/applications/%{name}.desktop

%{find_lang} %{name}

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files -f %{name}.lang base
%defattr(-,root,root,-)
%doc AUTHORS COPYING* README* TODO*

%dir %{_sysconfdir}/%{name}/
%dir %{_sysconfdir}/%{name}/mozilla/
%config(noreplace) %{_sysconfdir}/%{name}/*.xml
%config(noreplace) %{_sysconfdir}/%{name}/*rc
%config(noreplace) %{_sysconfdir}/%{name}/mozilla/*.xml

%{_bindir}/%{name}
%{_bindir}/kz-embed-process
%dir %{_libdir}/%{name}/
%dir %{_libdir}/%{name}/embed/
%dir %{_libdir}/%{name}/search/

%{_libdir}/%{name}/libkazehakase.so.*
%{_libdir}/%{name}/embed/per_process.so

%dir %{_datadir}/%{name}/
%if %{support_ruby}
%dir %{_libdir}/%{name}/ext/
%dir %{_datadir}/%{name}/ext/
%endif
%{_datadir}/%{name}/search-result.*
%{_datadir}/%{name}/*.png
%{_datadir}/%{name}/icons/
%{_datadir}/pixmaps/%{name}*.png
%{_datadir}/applications/*%{name}.desktop

%{_mandir}/man1/%{name}.1*

%files	hyperestraier
%defattr(-,root,root,-)
%{_libdir}/%{name}/search/hyper-estraier.so

%if %{support_anthy}
%files	anthy
%defattr(-,root,root,-)
%{_libdir}/%{name}/search/anthy*.so*
%endif

%if %{support_ruby}
%files	ruby
%defattr(-,root,root,-)
%{_libdir}/%{name}/ext/ruby.so
%{_datadir}/%{name}/ext/ruby/
%endif

%files
%defattr(-,root,root,-)
%if 0%{?fedora} < 15
%{_libdir}/%{name}/embed/gecko.so
%endif


%if %{support_webkit}
%files	webkit
%defattr(-,root,root,-)
%{_libdir}/%{name}/embed/webkit_gtk.so
%endif

%changelog
* Sat Aug 16 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.5.8-17.svn3873_trunk.2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_22_Mass_Rebuild

* Sun Jun 08 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.5.8-17.svn3873_trunk.1
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_Mass_Rebuild

* Thu Apr 24 2014 Vít Ondruch <vondruch@redhat.com> - 0.5.8-17.svn3873_trunk
- Rebuilt for https://fedoraproject.org/wiki/Changes/Ruby_2.1

* Tue Aug  6 2013 Mamoru TASAKA <mtasaka@fedoraproject.org> - 0.5.8-16.svn3873
- Add libgcrypt-devel to BR explicitly

* Sat Aug 03 2013 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.5.8-15.svn3873_trunk.3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_20_Mass_Rebuild

* Mon Apr  8 2013 Mamoru TASAKA <mtasaka@fedoraproject.org> - 0.5.8-15.svn3873_trunk
- Change webkitgtk dependency

* Thu Mar 21 2013 Mamoru TASAKA <mtasaka@fedoraproject.org> - 0.5.8-14.svn3873_trunk
- F-19: rebuild against ruby 2.0

* Sat Feb  9 2013 Mamoru TASAKA <mtasaka@fedoraproject.org> - 0.5.8-13.svn3873_trunk
- F-19: kill vendorization of desktop file (fpc#247)
- Patch for gnutls 3.1.7

* Thu Jul 19 2012 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.5.8-12.svn3873_trunk.1
- Rebuilt for https://fedoraproject.org/wiki/Fedora_18_Mass_Rebuild

* Wed Apr  4 2012 Mamoru Tasaka <mtasaka@fedoraproject.org> - 0.5.8-12.svn3873_trunk
- Actually change the default to webkit (bug 799019)
- Fix build with ruby19
- Fix type wrt thumbname related funtion

* Thu Jan  5 2012 Mamoru Tasaka <mtasaka@fedoraproject.org> - 0.5.8-11.svn3873_trunk
- F-17: rebuild against gcc47

* Tue Dec 06 2011 Adam Jackson <ajax@redhat.com> - 0.5.8-10.svn3873_trunk.1
- Rebuild for new libpng

* Wed Jul 13 2011 Mamoru Tasaka <mtasaka@fedoraproject.org> - 0.5.8-10.svn3873_trunk
- Kill xulrunner support

* Thu Sep  9 2010 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.8-9.svn3873_trunk
- Patch to compile with GTK >= 2.21.6

* Sat Jul  3 2010 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.8-8.svn3873_trunk
- Rebuild against new webkitgtk

* Tue May  4 2010 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.8-7.svn3873_trunk
- Update to the latest trunk

* Fri Nov 20 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.8-5.svn3870_trunk
- Just to make kazehakase built with xulrunner 1.9.2.1
  ( Does not work actually... However webkit support still works )

* Sat Nov  7 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- release++

* Sat Oct 17 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.8-2
- Fix crash when trying to view source or cert with no page loaded
  (bug 529334)

* Tue Sep 29 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.8-1
- Update to 0.5.8

* Tue Sep 29 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- rev 3859
- Enable ruby support again

* Mon Sep  7 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.7-3.svn3832_trunk
- Try rev 3832 for new dbus feature
- Kill ruby support until it gets compiled

* Sat Aug 29 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.7-1
- Update to 0.5.7

* Thu Aug 27 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- rev 3783

* Sun Jul 26 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- rev 3778

* Sat Jul 25 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-15.svn3773_trunk
- F-12: Mass rebuild

* Tue Jul 21 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-14.svn3773_trunk
- Attempt to compile with GTK 2.17.5

* Wed Jul  1 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- Rebuild

* Sun May 31 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- rev 3773

* Mon Apr 27 2009 Christopher Aillon <caillon@redhat.com> - 0.5.6-11.svn3771_trunk.1
- Rebuild against newer gecko

* Wed Apr 22 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-11.svn3771_trunk
- rev 3771
- Fix crash when downloading is cancalled
- Fix the issue that downloading won't work when file already exists.

* Mon Apr 20 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-10.svn3770_trunk
- rev 3770
- spec file cleanup

* Sun Apr 12 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-9.svn3769_trunk
- Prevent crash even if no modules are installed (related to bug 444569)
- Embed Vendor version information

* Sun Apr 12 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-8.svn3769_trunk
- Fix crash when kazehakase-webkit only is installed (bug 444569)

* Fri Mar 27 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-7.svn3769_trunk
- Fix Group tag (bug 486452)

* Mon Mar 23 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- Try rev 3769

* Sun Mar  8 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- Try rev 3766, along with WebKit soname bump

* Fri Feb 27 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-6.svn3761_trunk
- rev3756-compile.patch merged upstream

* Tue Feb 24 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- F-11: Mass rebuild

* Tue Feb 24 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-5.svn3756_trunk
- Filter out unwanted Provides

* Mon Feb 23 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- Try rev 3756

* Fri Jan 30 2009 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- Try rev 3598
- Now WebKit >= rev 39421 is needed

* Tue Dec 23 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- F-11: Rebuild against xulrunner 1.9.1

* Fri Oct 31 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.6-1
- 0.5.6
- -UGTK_DISABLE_DEPRECATED hack removed (hack introduced in upstream)

* Wed Sep 24 2008 Christopher Aillon <caillon@redhat.com>
- Rebuild against newer gecko (F-9/8)

* Tue Aug  5 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- Try rev. 3509

* Wed Jul 30 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.5-1
- 0.5.5

* Sat Jul 19 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.4-7.svn3506_trunk
- F-9+: relax gecko libs dependency (as GRE_GetGREPathWithProperties properly
  finds out GRE)
- F-10+: add -UGTK_DISABLE_DEPRECATED temporarily

* Tue Jul 15 2008 Christopher Aillon <caillon@redhat.com>
- Rebuild against newer gecko (F-8)

* Wed Jul 02 2008 Christopher Aillon <caillon@redhat.com>
- Rebuild against newer gecko (F-8)

* Sat Jun 28 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.4-6.svn3506_trunk
- Try rev 3506
- Workaround for bug 447444 (xulrunner vs hunspell conflict) (F-9+)

* Wed Jun 25 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.4-5
- Apply xulrunner related patches from debian by Mike Hommey
  (debian bug 480796, rh bug 402641)
  This time kazehakase actually works with xulrunner!

* Tue Apr 29 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.4-4
- Remove redundant description per rel-eng team request

* Wed Apr 23 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.4-3
- F-9: temporizing fix for xulrunner
  * Enable gtk-mozembed - don't work at all, however does not crash
  * force to install WebKit version

* Wed Apr 16 2008 Christopher Aillon <caillon@redhat.com> - 0.5.4-2.1
- Rebuild against newer gecko (F-8/9)

* Mon Apr 14 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.4-2
- Rebuild for new WebKit (F-7/8: bug 438531)

* Sun Mar 30 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.4-1
- 0.5.4

* Fri Mar 28 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.3-6.svn3501_trunk
- Try svn 3501 (still not work against xulrunner :( )

* Tue Mar 25 2008 Christopher Aillon <caillon@redhat.com> - 0.5.3-5
- Rebuild against newer gecko (F-7/8)

* Wed Mar  5 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.3-4
- Create kazehakase-base, split gecko.so from -base package
  so that users can install only WebKit based package.

* Sun Mar  2 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.3-3
- Support WebGTK

* Sat Mar  1 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.3-1
- 0.5.3

* Fri Feb 29 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.2-8.svn3410_trunk
- More try to use xulrunner
  * GRE version fix
  * Remove seemingly undesirable linking

* Sun Feb 24 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.2-7.svn3391_trunk
- More try to use xulrunner
  * Fix linkage for gecko.so
  * Don't use MOZILLA_INTERNAL_API anymore
  * NS_NewStorageStream should be changed to use xpcom
    http://developer.mozilla.org/en/docs/Migrating_from_Internal_Linkage_to_Frozen_Linkage

* Sat Feb 23 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.2-2.svn3391_trunk
- F-9: Try latest svn for xulrunner

* Fri Feb 15 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.2-1.2.svn3358
- F-9: Try latest svn for xulrunner
  (Still build explicitly disabled. Now it builds, does not crash
   but hangs eternally...)

* Sat Feb  9 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- Rebuild for new gecko engine (F-7/F-8)

* Wed Jan 30 2008 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.2-1
- 0.5.2

* Tue Nov 27 2007 Christopher Aillon <caillon@redhat.com>
- F-7/8: Rebuild against newer gecko

* Wed Nov 12 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.0-2
- F-9: try to switch to xulrunner

* Tue Nov  6 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.0-1.dist.1
- Rebuild against new gecko engine
- Switch to use gecko virtual dependency (bug 352091)

* Mon Oct 29 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.5.0-1
- 0.5.0

* Fri Oct 26 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.9-2.svn3312
- Try svn 3312

* Tue Oct 23 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.9-2.dist.1
- Rebuild against new gecko engine.

* Mon Oct  8 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.9-2
- Readd accidentally deleted obsolete_plugin_ver macro

* Sat Sep 29 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.9-1
- 0.4.9

* Thu Aug 30 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.8-1
- 0.4.8

* Wed Aug 22 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-9.svn3228.dist.1
- Mass rebuild (buildID or binutils issue)

* Thu Aug  9 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-9.svn3228
- Rebuild against new gecko engine.

* Fri Aug  3 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-8.svn3228
- Try svn 3228
- Disable GTK_DISABLE_DEPRECATED for now
- License update

* Sat Jul 21 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-7.svn3227
- Try svn 3227 to drop GLib patch

* Wed Jun 18 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-5
- Rebuild against new gecko engine

* Tue Jun  5 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-3
- Patch to follow the newest GLib symbol

* Tue Jun  5 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-2
- Parse GLib version dependency 

* Wed May 30 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.7-1
- 0.4.7

* Mon May 28 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.6-5.svn3221
- Try svn 3221

* Tue May 22 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.6-4
- Workaround for glib 2.13.1+

* Tue May 22 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.6-2
- Support Ruby/Migemo

* Sun Apr 29 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.6-1
- 0.4.6

* Tue Apr 10 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.5-2
- Enable ruby-gtk2 support

* Tue Apr  3 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.5-1
- 0.4.5
- Clean up spec file (rename plugins, drop "plugins" string from name)
- Add ruby-gtk support (disabled until the review #232160 is completed)

* Sat Mar 24 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4.1-4
- gecko engine update

* Tue Feb 27 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4.1-3.dist.1
- gecko engine update

* Sat Feb 24 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>
- enable anthy/mecab support (currently disabled)

* Thu Feb 22 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4.1-3
- enable hyperestraier support.

* Sat Feb  4 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4.1-2.dist.1
- modify configure for split of mozilla-config.h for multilib

* Sat Feb  3 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4.1-2
- Remove -Werror staff

* Fri Feb  2 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4.1-1
- 0.4.4.1

* Fri Feb  2 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4-2
- Add more BuildRequires: anthy-devel, libSM-devel

* Tue Jan 30 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.4-1
- 0.4.4

* Thu Jan 18 2007 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.3-4
- Do not call autoconf, just fix configure.

* Sat Dec 23 2006 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.3-3
- Add firefox version dependency for gecko engine

* Wed Dec 13 2006 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.3-2
- Own %%{_libdir}/%%{name} correctly

* Tue Dec 12 2006 Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp> - 0.4.3-1
- Initial packaging to import to Fedora Extras.
