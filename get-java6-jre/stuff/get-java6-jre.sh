#!/bin/sh 
# Get and install the SUN Java Runtime Environnement
#
# (C) 2007-2008 SliTaz - GNU General Public License v3.
#
# Author : Eric Joseph-Alexandre <erjo@slitaz.org>

PACKAGE="java6-jre"
VERSION="1.6.0_07"
URL="http://javadl.sun.com/webapps/download/AutoDL?BundleId=23103"
TARBALL="jre-6u7-linux-i586.bin"
TEMP_DIR="/tmp/$PACKAGE.$$"

# Check if we are root starting anything
if test $(id -u) != 0 ; then
	echo -e "\nYou must be root to run `basename $0`."
	echo -e "Please type 'su' and root password to become super-user.\n"
	exit 1
fi

# Avoid reinstall
if [ -d /var/lib/tazpkg/installed/$PACKAGE ]; then
	echo -e "\n$PACKAGE package is already installed.\n"
	exit 1
fi



# Create TEMP_DIR
test -d $TEMP_DIR || mkdir $TEMP_DIR
cd $TEMP_DIR

# Doanload the file
test -f $TARBALL || wget $URL -O $TARBALL

# Run the install file user may agree to SUN EULA
chmod +x  $TARBALL
./${TARBALL}


# Make the package
mkdir -p $PACKAGE-$VERSION/fs/usr/lib/java 
cp -a jre${VERSION} $PACKAGE-$VERSION/fs/usr/lib/java


#delete unecessary files
rm -rf $PACKAGE-$VERSION/fs/usr/lib/java/jre${VERSION}/man

# Create receipt

cat > $PACKAGE-$VERSION/receipt <<EOT
# SliTaz package receipt.

PACKAGE="$PACKAGE"
VERSION="$VERSION"
CATEGORY="non-free"
SHORT_DESC="SUN Java Runtime."
DEPENDS=""
WEB_SITE="http://www.java.com/"

post_install()
{
	echo "Processing post install commands..."
	for i in /usr/lib/firefox*; do
		[ -d $i ] || continue
		cd $i/plugins
		ln -s /usr/lib/java/jre\$VERSION/plugin/i386/ns7/libjavaplugin_oji.so
	done
	
	cd /usr/bin
	ln -s /usr/lib/java/jre\$VERSION/bin/java 
}

post_remove()
{
	rm -f /usr/lib/firefox*/plugins/libjavaplugin_oji.so
	rm -f /usr/bin/java
}
EOT

# Pack
tazpkg pack $PACKAGE-$VERSION

# Install pseudo package
tazpkg install $PACKAGE-$VERSION.tazpkg

# Clean
cd /tmp
rm -rf $TEMP_DIR






