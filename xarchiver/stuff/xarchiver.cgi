#!/bin/sh
# Web utility to show & install suggested packages for xarchiver
# Aleksej Bobylev <al.bobylev@gmail.com>, 2014.

. /usr/lib/slitaz/httphelper.sh
. /etc/slitaz/slitaz.conf
. /lib/libtaz.sh
. /etc/locale.conf; export LANG LC_ALL
export TEXTDOMAIN='tazpkg'

case "$(GET)" in
	img)
		header "HTTP/1.1 200 OK\nContent-type: image/png"
		case "$(GET img)" in
			yes) cat /usr/share/icons/SliTaz/actions/22/gtk-ok.png ;;
			not) cat /usr/share/icons/SliTaz/actions/22/gtk-remove.png ;;
			fav) cat /usr/share/icons/hicolor/16x16/apps/xarchiver.png ;;
			log) cat /usr/share/icons/hicolor/48x48/apps/xarchiver.png ;;
		esac ;;
	*)
		header
		cat << EOT
<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8" />
	<title>Xarchiver</title>
	<link rel="shortcut icon" type="image/png" href="?img=fav">
	<style type="text/css">
		*{font-family:sans}
		img{vertical-align:middle;}
		#installer{display:none}
	</style>
	<script type="text/javascript">
	function inst(actpkg) {
		document.getElementById("installer").src = "http://127.0.0.1:82/user/pkgs.cgi?do=" + actpkg
	}
	function on_load(iframe) {
		if (iframe.src !== "http://localhost/cgi-bin/xarchiver.cgi") {location.reload(false)}
	}
	</script>
</head>
<body>
<div style="border:1pt solid gray; border-radius:6pt; margin:6pt; padding:6pt;">
<table><tr><td style="vertical-align:top"><img src="?img=log" /></td>
<td>$(cat $INSTALLED/xarchiver/description.txt)</td></table>
</div>
<p>Here you can install some SliTaz packages using TazPanel on the background.
Note that you always have tiny versions of <strong>gzip</strong> and <strong>cpio</strong> (as part of Busybox), so you may not install its "official" versions.</p>
<table>
	<tbody>
EOT
		for pkg in ar arj bzip2 cpio gzip lha lzma lzop rar xz zip 7z xdg-utils; do

			case $pkg in
				ar) pkg2=binutils ;;
				7z) pkg2=p7zip-full ;;
				*)  pkg2=$pkg ;;
			esac

			if [ -d $INSTALLED/$pkg2 ]; then
				img=yes; act=Remove; desc="$(_ Remove)"
			else
				img=not; act=Install; desc="$(_ Install)"
			fi
			echo "<tr><td><img src=\"?img=$img\" /> $pkg</td></td><td><button type=\"submit\" onclick='inst(\"${act}&pkg=${pkg2}\")'>$desc</button></td></tr>"
		done
		cat << EOT
	</tbody>
</table>
<iframe id="installer" src="" onload="on_load(this)"></iframe>
</body>
</html>
EOT
		;;
esac
exit 0
