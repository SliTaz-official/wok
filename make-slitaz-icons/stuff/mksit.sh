#!/bin/sh
# Make SliTaz icon theme
# Aleksej Bobylev <al.bobylev@gmail.com>, 2014-2016
# (Started in November 2014)

VERSION="161031"

. /lib/libtaz.sh


### Functions ###

# Usage of utility

usage() {
	cat <<EOT
$(basename $0), v. $VERSION
Make icon theme for SliTaz GNU/Linux

Usage:
$(basename $0) [OPTIONS ...]

Options:
-f <path>  The path to the original theme from which the icons will be taken
           Note that this folder contains the file index.theme
-t <path>  The path where the folder with a new theme will created
           Note that existing folder will be silently removed
-s <path>  Path to icon substitution definitions. Where <path> can point to file
           or to folder containing file <original theme name>.sub
-n 'name'  The name of the new theme (default will be taken from -t path)

+is  -is   Whether to use Inkscape to convert svg icons to png (default: +is)
+op  -op   Whether to use Optipng to optimize png icons (default: +op)
+sl  -sl   Whether to replace the same icons by symlinks (default: +sl)

-opmax     Maximal settings for Optipng (slow but save maximum bytes)

-nocolor   Don't use color in the log
EOT
}


# Color output
colored() {
	if [ "$color" = 'yes' ]; then
		colorize $@
	else
		echo $2
	fi
}


# Find icon (use pre-generated list of icon files)

findi() {
	grep -e "/$1.png" -e "/$1.svg" $ICONSLIST
}


# Copy icon

c() {
	for SIZE in $SIZES; do
		FOUND=''
		for ICON in $(echo "$@" | sed 's|\([^ ]*\)|& gnome-mime-& gnome-dev-&|'); do
			FINDICON=$(findi $ICON | sed "s|$FROM||g" | grep -e "/$SIZE/" -e "/${SIZE}x$SIZE/")

			if [ -n "$FINDICON" ]; then
				if [ $(echo "$FINDICON" | wc -l) != "1" ]; then
					# Multiple choice
					if [ "$(md5sum $(echo "$FINDICON" | sed 's|^.*$|'$FROM'&|g') | awk '{print $1}' | sort | uniq | wc -l)" != "1" ]; then
						# note: really different icons with different md5sum
						colored 33 "? $1($SIZE): Multiple choice:"
						echo "$FINDICON" | sed 's|^.*$|  * &|g'
					fi
					FINDICON="$(echo "$FINDICON" | head -n1)"
				fi
				mkdir -p $TO/${SIZE}x${SIZE}/$CATEGORY

				BASE_FINDICON="$(basename $FINDICON .png)"
				BASE_FINDICON="$(basename $BASE_FINDICON .svg)"

				if [ "$1" = "$BASE_FINDICON" ]; then
					colored 32 "+ $1($SIZE)"
				else
					colored 34 "+ $1($SIZE) <= $(basename $FINDICON)"
				fi

				EXT=${FINDICON##*.}
				cp -aL $FROM/$FINDICON $TO/${SIZE}x${SIZE}/$CATEGORY/$1.$EXT

				FOUND='yes'
				break
			fi
		done
		if [ -z "$FOUND" ]; then
			colored 31 "- $1($SIZE) NOT FOUND!"
		fi
	done
}


# Maybe copy stock icon

s() {
	if [ "${BASED_ON%%-*}" != "Faenza" ]; then
		c $@
	else
		echo ". $1"
	fi
}


# Return shortest line

shortest_line() {
	S=$1; shift
	for L in $@; do
		[ "${#L}" -lt "${#S}" ] && S="$L"
	done
	echo "$S"
}


# Replace the same files by symlinks, $@ - list of identical files

make_symlinks() {
	S=$(shortest_line $@)
	for file in $@; do
		[ "$S" != "$file" ] && ln -sf $S $file
	done
}


# Calculate size in bytes

size() {
	echo -n "size: "
	find "$TO" -type f -exec stat -c %s {} \; | awk 'BEGIN{SUM=0}{SUM+=$1}END{print SUM}'
}


# Print out category

echo_cat() {
	echo
	colored 35 $CATEGORY
	colored 35 $(echo -n $CATEGORY | tr -c '' '-')
}





case "$1" in
	-h|--help) usage; exit 0 ;;
	-V|--version) echo "$(basename $0) v. $VERSION"; exit 0 ;;
esac


# Default parameters:

IS='yes'; OP='yes'; SL='yes'; PNGOPT=''; SUBS=''; color='yes'

while [ "x$1" != "x" ]; do
	case "$1" in
		-f)  FROM="$2"; shift; BASED_ON="$(basename ${FROM%/})" ;;
		-t)  TO="$2";   shift; NAME="$(basename ${TO%/})" ;;
		-s)  SUBS="$2"; shift; if [ -d "$SUBS" ]; then SUBS="${SUBS%/}/$BASED_ON.sub"; fi ;;
		-n)  NAME="$2"; shift ;;
		-is) IS='no'  ;;
		+is) IS='yes' ;;
		-op) OP='no'  ;;
		+op) OP='yes' ;;
		-sl) SL='no'  ;;
		+sl) SL='yes' ;;
		-opmax) PNGOPT="-o7 -zm1-9" ;;
		-nocolor) color='no' ;;
	esac
	shift
done

if [ "x$FROM" = "x" -o "x$TO" = "x" ]; then
	echo "There are no required parameters (-f or -t)!"; exit 1
fi

echo "Check components..."
if [ $IS = 'yes' ]; then
	echo -n "Inkscape: "
	if [ -x "$(which inkscape)" ]; then
		echo "$(which inkscape)"
	else
		colored 31 "not found! Force '-is'"; IS='no'
	fi
fi
if [ $OP = 'yes' ]; then
	echo -n "Optipng:  "
	if [ -x "$(which optipng)" ]; then
		echo "$(which optipng)"
	else
		colored 31 "not found! Force '-op'"; OP='no'
	fi
fi
echo -n "Symlinks: "
if [ -x "$(which symlinks)" ]; then
	echo "$(which symlinks)"
else
	colored 31 "not found! Abort."; exit 1
fi
echo

echo "Options: Inkscape=\"$IS\" Optipng=\"$OP\" Symlinks=\"$SL\""
echo "From:    \"$FROM\""
echo "To:      \"$TO\""
echo "Subs:    \"$SUBS\""
echo "Name:    \"$NAME\""
echo


rm -rf $TO

# make files list
ICONSLIST=$(mktemp)
find $FROM -type f -o -type l > $ICONSLIST





#########################
# Standard Action Icons #
#########################
CATEGORY='actions'; SIZES='16'; echo_cat

c address-book-new
c application-exit dialog-close			# gtk_stock 16,24; Transmission (GTK+3) needs it	# elementary hack
c appointment-new
c call-start
c call-stop process-stop										# elementary hack
c contact-new
s document-new				# gtk_stock 16,24
c document-open				# gtk_stock 16,24; Transmission (GTK+3) needs it
s document-open-recent		# gtk_stock 16,24
c document-page-setup
s document-print			# gtk_stock 16,24
s document-print-preview	# gtk_stock 16,24
s document-properties		# gtk_stock 16,24
s document-revert			# gtk_stock 16,24
s document-save				# gtk_stock 16,24
s document-save-as document-save		# gtk_stock 16,24		# elementary hack
c document-send document-export									# elementary hack
c edit-clear remove						# gtk_stock 16,24; Yad:tazbox new-file needs it		# elementary hack
c edit-copy					# gtk_stock 16,24; Transmission (GTK+3) needs it
s edit-cut					# gtk_stock 16,24
c edit-delete				# gtk_stock 16,24; Transmission (GTK+3) needs it
s edit-find					# gtk_stock 16,24
s edit-find-replace edit-find			# gtk_stock 16,24		# elementary hack
s edit-paste				# gtk_stock 16,24
s edit-redo					# gtk_stock 16,24
c edit-select-all			# gtk_stock 16,24; Transmission (GTK+3) needs it
s edit-undo					# gtk_stock 16,24
c folder-new
s format-indent-less		# gtk_stock 16,24
s format-indent-more		# gtk_stock 16,24
s format-justify-center		# gtk_stock 16,24
s format-justify-fill		# gtk_stock 16,24
s format-justify-left		# gtk_stock 16,24
s format-justify-right		# gtk_stock 16,24
c format-text-direction-ltr
c format-text-direction-rtl
s format-text-bold			# gtk_stock 16,24
s format-text-italic		# gtk_stock 16,24
s format-text-underline		# gtk_stock 16,24
s format-text-strikethrough	# gtk_stock 16,24
s go-bottom					# gtk_stock 16,24
c go-down					# gtk_stock 16,24 but Yad:scp-box needs it
c go-first					# gtk_stock 16,24
s go-home					# gtk_stock 16,24
s go-jump					# gtk_stock 16,24
c go-last					# gtk_stock 16,24
c go-next					# gtk_stock 16,24
c go-previous				# gtk_stock 16,24
s go-top					# gtk_stock 16,24
c go-up						# gtk_stock 16,24 but Yad:scp-box needs it
c help-about				# gtk_stock 16,24; Transmission (GTK+3) needs it
c help-contents				# gtk_stock 16,24; Transmission (GTK+3) needs it
c help-faq help-hint											# elementary hack
c insert-image
c insert-link
c insert-object
c insert-text
c list-add					# gtk_stock 16,24; Transmission (GTK+3) needs it
c list-remove				# gtk_stock 16,24; Transmission (GTK+3) needs it
c mail-forward
c mail-mark-important
c mail-mark-junk
c mail-mark-notjunk
c mail-mark-read
c mail-mark-unread
c mail-message-new
c mail-reply-all
c mail-reply-sender
c mail-send
c mail-send-receive
c media-eject list-remove									# Matrilineare hack
c media-playback-pause		# gtk_stock 16,24 but Audacious needs it
c media-playback-start		# gtk_stock 16,24 but Audacious needs it
c media-playback-stop		# gtk_stock 16,24 but Audacious needs it
s media-record				# gtk_stock 16,24
s media-seek-backward go-previous		# gtk_stock 16,24		# Matrilineare hack
s media-seek-forward go-next			# gtk_stock 16,24		# Matrilineare hack
c media-skip-backward		# gtk_stock 16,24 but Audacious needs it
c media-skip-forward		# gtk_stock 16,24 but Audacious needs it
c object-flip-horizontal
c object-flip-vertical
c object-rotate-left
c object-rotate-right
s process-stop				# gtk_stock 16,24
c system-lock-screen lock									# Matrilineare hack
c system-log-out contact-new								# Matrilineare hack
c system-run				# gtk_stock 16,24; Transmission (GTK+3) needs it
c system-search find										# Matrilineare hack
c system-reboot system-run									# Matrilineare hack
c system-shutdown system-shutdown-panel						# Matrilineare hack
s tools-check-spelling		# gtk_stock 16,24
s view-fullscreen			# gtk_stock 16,24
c view-refresh				# gtk_stock 16,24 but Yad:tazbox manage-i18n needs it
s view-restore				# gtk_stock 16,24
s view-sort-ascending		# gtk_stock 16,24
s view-sort-descending		# gtk_stock 16,24
c window-close				# gtk_stock 16,20,24; Transmission (GTK+3) needs it
c window-new
s zoom-fit-best				# gtk_stock 16,24
s zoom-in					# gtk_stock 16,24
s zoom-original				# gtk_stock 16,24
s zoom-out					# gtk_stock 16,24
#---------------------------
# PCManFM panel and menu
c tab-new
c view-choose preferences-desktop
c view-filter
c view-sidetree

c gtk-execute			# LXPanel menu: run
c system-shutdown-panel-restart	# LXPanel menu: logout
c gtk-close			# Yad close button
c gtk-go-forward gtk-go-forward-ltr # tazbox tz Yad dialog
c bookmark-new		# Midori
c empty			# Yad:tazbox new-file
c extract-archive	# tazpkg-box, xarchiver...
c package-install	# tazpkg-box

SIZES='16 48'
c document-new		# Yad:tazbox new-file
c document-properties	# Yad:tazbox locale, tazbox manage-i18n


############################
# Standard Animation Icons #
############################
CATEGORY='animations'; SIZES='16'; echo_cat

c process-working



##############################
# Standard Application Icons #
##############################
CATEGORY='apps'; SIZES='16 48'; echo_cat

c accessories-calculator
c accessories-character-map
c accessories-dictionary
c accessories-text-editor
c help-browser
c multimedia-volume-control									# audio-volume-high
c preferences-desktop-accessibility
c preferences-desktop-font
c preferences-desktop-keyboard										# keyboard
c preferences-desktop-locale
c preferences-desktop-multimedia					# applications-multimedia
c preferences-desktop-screensaver
c preferences-desktop-theme
c preferences-desktop-wallpaper
c system-file-manager
c system-software-install											# synaptic
c system-software-update									# update-notifier
c utilities-system-monitor
c utilities-terminal
#-------------------
c gcolor2						# gcolor2.desktop
c gnome-glchess					# chess.desktop
c gpicview						# gpicview.desktop
c tazcalc gnumeric				# tazcalc.desktop
c alsaplayer gnome-audio		# alsaplayer.desktop
c leafpad						# leafpad.desktop
c midori						# midori.desktop
c mtpaint						# mtpaint.desktop
c xterm							# xterm.desktop
c burn-box brasero				# burn-box.desktop
c iso-image-burn				# burn-iso.desktop
c system-log-out				# lxde-logout.desktop
c sudoku gnome-sudoku			# sudoku.desktop
c utilities-log-viewer			# bootlog.desktop
c preferences-desktop-display	# lxrandr.desktop
c tazbug bug-buddy				# tazbug.desktop
c applets-screenshooter			# mtpaint-grab.desktop
c tazwikiss zim					# tazwikiss.desktop
c system-software-installer		# tazpanel-pkgs.desktop
c session-properties			# lxsession-edit.desktop
c terminal						# sakura.desktop
c user_auth						# passwd.desktop
c preferences-system-time		# tazbox-tz.desktop
c text-editor					# vi.desktop
c drive-harddisk-usb			# tazusb-box.desktop
c drive-optical					# tazlito-wiz.desktop
c network-wireless				# wifi-box.desktop
c gparted						# gparted.desktop
c epdfview acroread				# epdfview.desktop
c menu-editor					# libfm-pref-apps.desktop
c preferences-system-windows	# obconf.desktop
c twitter						# twitter.desktop
c network-server				# httpd.desktop
c pcmanfm system-file-manager	# pcmanfm.desktop
c preferences-desktop-default-applications	# tazbox tazapps
c multimedia-video-player mplayer	# tazbox-video.desktop tazbox-video-fullscreen.desktop


###########################
# Standard Category Icons #
###########################
CATEGORY='categories'; SIZES='16 48'; echo_cat

c applications-accessories
c applications-development
c applications-engineering gnome-do
c applications-games
c applications-graphics eog									# Matrilineare hack
c applications-internet web-browser							# Matrilineare hack
c applications-multimedia
c applications-office
c applications-other
c applications-science
c applications-system
c applications-utilities
c preferences-desktop
c preferences-desktop-peripherals
c preferences-desktop-personal
c preferences-other
c preferences-system
c preferences-system-network
c system-help help-contents



#########################
# Standard Device Icons #
#########################
CATEGORY='devices'; SIZES='16'; echo_cat

c audio-card
c audio-input-microphone gnome-sound-recorder
c battery
c camera camera-photo
c camera-photo
c camera-video
c camera-web
c computer
c drive-harddisk
c drive-optical
c drive-removable-media drive-harddisk-removable			# Matrilineare hack
c input-gaming
c input-keyboard
c input-mouse
c input-tablet
c media-flash drive-removable-media-usb
s media-floppy					# gtk_stock 16,24
s media-optical drive-optical	# gtk_stock 16,24			# Matrilineare hack
c media-tape
c modem
c multimedia-player
c network-wired
c network-wireless
c pda
c phone ekiga
c printer
c scanner
c video-display
#---------------------------
c camera camera-photo										# Matrilineare hack

# Big drive icons on the PCManFM Desktop
SIZES='48'
c drive-harddisk
c drive-optical
c drive-removable-media drive-harddisk-removable			# Matrilineare hack
c video-display		# LXPanel - About


#########################
# Standard Emblem Icons #
#########################
CATEGORY='emblems'; SIZES='16'; echo_cat

c emblem-default
c emblem-documents x-office-document						# Matrilineare hack
c emblem-downloads
c emblem-favorite
c emblem-important
c emblem-mail
c emblem-photos image-jpeg
c emblem-readonly
c emblem-shared
c emblem-symbolic-link
c emblem-synchronized emblem-ubuntuone-synchronized
c emblem-system
c emblem-unreadable



##########################
# Standard Emotion Icons #
##########################
CATEGORY='emotions'; SIZES='16'; echo_cat

c face-angel
c face-angry
c face-cool
c face-crying
c face-devilish
c face-embarrassed
c face-kiss
c face-laugh
c face-monkey
c face-plain
c face-raspberry
c face-sad
c face-sick
c face-smile
c face-smile-big
c face-smirk
c face-surprise
c face-tired
c face-uncertain
c face-wink
c face-worried



################################
# Standard International Icons #
################################

#flag-aa
#flag-RU
#flag-UA



############################
# Standard MIME Type Icons #
############################
CATEGORY='mimetypes'; SIZES='48 16'; echo_cat
A='application'

# generic icons described in the /usr/share/mime/packages/freedesktop.org.xml
c application-x-executable
c audio-x-generic
c font-x-generic
c image-x-generic
c package-x-generic
c text-html
c text-x-generic			# gtk_stock 16,24   but...
c text-x-generic-template
c text-x-script
c video-x-generic
c x-office-address-book
c x-office-calendar
c x-office-document
c x-office-presentation
c x-office-spreadsheet
#--------------------------------------
# special types
c $A-octet-stream
c $A-x-zerosize empty

# archives
c $A-gzip $A-x-gzip
c $A-x-compressed-tar
c $A-x-7z-compressed
c $A-x-ace
c $A-x-arc
c $A-x-archive
c $A-x-rar
c $A-x-tar
c $A-zip
c $A-vnd.ms-cab-compressed $A-x-archive
c $A-x-alz $A-x-archive
c $A-x-arj
c $A-x-bcpio $A-x-archive
c $A-x-bzip
c $A-x-bzip-compressed-tar
c $A-x-lha
c $A-x-lzma $A-x-archive
c $A-x-lzma-compressed-tar $A-x-archive
c $A-x-lzop $A-x-archive
c $A-x-tzo $A-x-archive
c $A-x-xar $A-x-archive
c $A-x-xz $A-x-archive
c $A-x-xz-compressed-tar $A-x-archive

# packages
c $A-vnd.android.package-archive
c $A-x-deb
c $A-x-java-archive
c $A-x-rpm
c $A-x-source-rpm $A-x-rpm
c $A-x-tazpkg package-x-generic

c $A-illustrator
c $A-javascript
c $A-mbox
c $A-pdf
c $A-pgp-signature $A-pgp-keys
c $A-rtf
c $A-x-apple-diskimage $A-x-cd-image
c $A-x-cbr comix
c $A-x-cd-image
c $A-x-core emblem-danger
c $A-x-designer
c $A-x-desktop

c $A-x-theme
c $A-x-emerald-theme $A-x-theme
c $A-x-openbox-theme $A-x-theme

c $A-x-generic $A-x-executable
c $A-x-object $A-octet-stream
c $A-x-sharedlib $A-octet-stream

c $A-x-gettext-translation preferences-desktop-locale
c text-x-gettext-translation preferences-desktop-locale
c text-x-gettext-translation-template text-x-generic-template

c $A-x-gtk-builder $A-x-glade
c $A-x-m4
c $A-xml
c $A-x-ms-dos-executable

c $A-x-perl text-x-script
c $A-x-python-bytecode
c $A-x-shellscript
c $A-x-sqlite3
c $A-x-trash
c $A-x-x509-ca-cert $A-pgp-keys

c audio-mpeg
c audio-x-vorbis+ogg
c audio-x-wav
c image-x-eps
c image-x-xcursor ccsm
c inode-blockdevice block-device
c inode-chardevice chardevice
c inode-directory
c inode-mount-point drive-removable-media
c inode-symlink emblem-symbolic-link
c inode-x-generic emblem-generic
c text-css
c text-plain
c text-richtext
c text-x-authors
c text-x-changelog
c text-x-chdr
c text-x-copying
c text-x-csrc
c text-x-install
c text-x-log text-x-changelog
c text-x-makefile
c text-x-markdown text-x-source
c text-x-patch
c text-x-python
c text-x-readme
c text-x-tazpkg-receipt text-x-script

c application-x-shockwave-flash			# Midori
c unknown								# for unknown mimetypes in PCManFM

SIZES='16'
c package package-x-generic				# for Midori: Sidepanel


########################
# Standard Place Icons #
########################
CATEGORY='places'; SIZES='16 48'; echo_cat

c folder			# gtk_stock 16,24
c folder-remote		# gtk_stock 16,24
c network-server
c network-workgroup
c start-here
c user-bookmarks
c user-desktop		# gtk_stock 16,24
c user-home			# gtk_stock 16,24
c user-trash
#------------------
# PCManFM XDG home sub-folders
c folder-documents
c folder-download
c folder-music
c folder-pictures
c folder-publicshare
c folder-templates
c folder-videos



#########################
# Standard Status Icons #
#########################
CATEGORY='status'; SIZES='22'; echo_cat

c appointment-missed
c appointment-soon
c audio-volume-high			# gtk_stock 24
c audio-volume-low			# gtk_stock 24
c audio-volume-medium		# gtk_stock 24
c audio-volume-muted		# gtk_stock 24
c battery-caution notification-battery-empty
c battery-low notification-battery-low
c dialog-error				# gtk_stock 48
c dialog-information		# gtk_stock 16,24,48
c dialog-password			# gtk_stock 48
c dialog-question			# gtk_stock 48
c dialog-warning			# gtk_stock 48
c folder-drag-accept
c folder-open
c folder-visiting
c image-loading
c image-missing				# gtk_stock 16,24
c mail-attachment
c mail-unread
c mail-read
c mail-replied
c mail-signed
c mail-signed-verified
c media-playlist-repeat
c media-playlist-shuffle
c network-error
c network-idle				# gtk_stock 16,24
c network-offline
c network-receive
c network-transmit
c network-transmit-receive
c printer-error				# gtk_stock 16,24
c printer-printing
c security-high
c security-medium
c security-low
c software-update-available
c software-update-urgent
c sync-error
c sync-synchronizing
c task-due
c task-past-due
c user-available
c user-away
c user-idle
c user-offline
#c user-trash-full
c weather-clear
c weather-clear-night
c weather-few-clouds
c weather-few-clouds-night
c weather-fog
c weather-overcast
c weather-severe-alert
c weather-showers
c weather-showers-scattered
c weather-snow
c weather-storm
#------------------
c system-shutdown-restart-panel		# LXPanel logout icon (slitaz-logout.desktop)

SIZES="48 16"
c user-trash-full			# PCManFM desktop
c dialog-password			# tazbox su default icon
c dialog-error				# tazbox su error icon
c dialog-information
c dialog-password
c dialog-question
c dialog-warning
c appointment-soon			# Yad:tazbox manage-i18n

# LXPanel status icons
SIZES="22"
c gnome-netstatus-0-24    nm-signal-25
c gnome-netstatus-25-49   nm-signal-50
c gnome-netstatus-50-74   nm-signal-75
c gnome-netstatus-75-100  nm-signal-100
c gnome-netstatus-disconn network-error
c gnome-netstatus-error   network-error
c gnome-netstatus-idle    network-idle
c gnome-netstatus-rx      network-receive
c gnome-netstatus-tx      network-transmit
c gnome-netstatus-txrx    network-transmit-receive

# c avatar-default	# 16x16 with canvas 22x22: for "slitaz-logout.desktop"



#####

echo -n "Original     "; size

#####

if [ "$IS" = "yes" ]; then
		echo -n "Inkscape...  "
	# convert svg to png
	# rarely inkscape may fail, good that we leave original file
	find $TO -type f -iname '*.svg' \( -exec sh -c "export E={}; inkscape -z -f \$E -e \${E%svg}png" \; -exec rm {} \; \)
	size
fi

#####

if [ "$OP" = "yes" ]; then
	echo -n "Optipng...   "
	# re-compress png files
	find $TO -type f -iname '*.png' -exec optipng -quiet -strip all $PNGOPT {} \;
	size
fi

#####

if [ "$SL" = "yes" ]; then
	echo -n "Symlinks...  "
	MD5FILE=$(mktemp); find $TO -type f -exec md5sum {} \; | sort > $MD5FILE
	# substitute repeated files by symlinks
	for md in $(uniq -d -w32 $MD5FILE | cut -c1-32); do
		make_symlinks $(grep $md $MD5FILE | cut -c35-)
	done
	rm "$MD5FILE"
	# make all symlinks relative
	SL=$(symlinks -crs $TO 2> /dev/null)
	size
fi

#####

echo -n 'Make index.theme... '
{
	echo "[Icon Theme]"
	echo "Name=$NAME"

	echo -n "Directories="
	cd "$TO"
	FOLDERS=$(find . -type d -mindepth 2 | sort | sed "s|^\./||g")
	FOLDERS_COMMA=$(echo "$FOLDERS" | tr '\n' ',')
	echo ${FOLDERS_COMMA%,}

	for FOLDER in $FOLDERS; do
		echo
		echo "[$FOLDER]"
		echo -n "Size="; echo "$FOLDER" | sed 's|^\([0-9]*\).*|\1|'
		echo -n "Context="
		case ${FOLDER#*/} in
			actions)     echo 'Actions'       ;;
			animations)  echo 'Animations'    ;;
			apps)        echo 'Applications'  ;;
			categories)  echo 'Categories'    ;;
			devices)     echo 'Devices'       ;;
			emblems)     echo 'Emblems'       ;;
			emotes)      echo 'Emotes'        ;;
			filesystems) echo 'FileSystems'   ;;
			intl)        echo 'International' ;;
			mimetypes)   echo 'MimeTypes'     ;;
			places)      echo 'Places'        ;;
			status)      echo 'Status'        ;;
			*)           echo 'Other'         ;;
		esac
		echo "Type=Threshold"
	done
} > $TO/index.theme
echo 'Done'
