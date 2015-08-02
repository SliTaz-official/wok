#!/bin/sh
#
# Floppy set CGI interface
#
# Copyright (C) 2015 SliTaz GNU/Linux - BSD License
#

# Common functions from libtazpanel
. lib/libtazpanel
get_config


case "$1" in
	menu)
		TEXTDOMAIN_original=$TEXTDOMAIN
		export TEXTDOMAIN='floppy'

		#which bootloader > /dev/null &&
		cat <<EOT
<li><a data-icon="slitaz" href="floppy.cgi">$(_ 'Boot floppy')</a></li>
EOT
		export TEXTDOMAIN=$TEXTDOMAIN_original
		exit
esac


#
# Commands
#

error=
case " $(POST) " in
*\ doformat\ *)
	fdformat $(POST fd)
	which mkfs.$(POST fstype) > /dev/null 2>&1 &&
	mkfs.$(POST fstype) $(POST fd)
	;;
*\ write\ *)
	if [ "$(FILE fromimage tmpname)" ]; then
		dd if=$(FILE fromimage tmpname) of=$(POST tofd)
		rm -f $(FILE fromimage tmpname)
	else
		error="$(msg err 'Broken FILE support')"
	fi ;;
*\ read\ *)
	dd if=$(POST fromfd) of=$(POST toimage)
	;;
*\ build\ *)
	cmd=""
	toremove=""
	while read key file ; do
		[ "$(FILE $file size)" ] || continue
		for i in $(seq 1 $(FILE $file count)); do
			cmd="$cmd $key $(FILE $file tmpname $i)"
			toremove="$toremove $(FILE $file tmpname $i)"
		done
	done <<EOT
bootloader	kernel
--initrd	initrd
--initrd	initrd2
--info		info
EOT
	error="$(msg err 'Broken FILE support !')
		<pre>$(httpinfo)</pre>"
	if [ "$cmd" ]; then
		for key in cmdline rdev video format mem ; do
			[ "$(POST $key)" ] || continue
			cmd="$cmd --$key '$(POST $key)'"
		done 
		[ "$(POST edit)" ] || cmd="$cmd --dont-edit-cmdline"
		TITLE="$(_ 'TazPanel - floppy')"
		header
		xhtml_header
		cd $(POST workdir)
		eval $cmd 2>&1
		echo "</pre>"
		[ "$toremove" ] && rm -f $toremove && rmdir $(dirname $toremove)
		xhtml_footer
		exit 0
	fi
	;;
esac

listfd()
{
	echo "<select name=\"$1\">"
	ls /dev/fd[0-9]* | sed 's|.*|<option>&</option>|'
	echo "</select>"
}

TITLE="$(_ 'TazPanel - floppy')"
header
xhtml_header
echo "$error"

cat <<EOT
<form method="post" enctype="multipart/form-data">
EOT
[ -w /dev/fd0 ] && cat <<EOT
<section>
	<header>
		$(_ 'Floppy disk format')
	</header>
	<button type="submit" name="doformat" data-icon="start" >$(_ 'Format disk'  )</button>
	$(listfd fd) filesystem:
	<select name "fstype">
		<option>$(_ 'none')</option>
		$(ls /sbin/mkfs.* | sed '/dev/d;s|.*/mkfs.\(.*\)|<option>\1</option>|')
	</select>
</section>

<section>
	<header>
		$(_ 'Floppy disk transfert')
	</header>
<table>
	<tbody>
	<tr>
	<td>
	<button type="submit" name="write" data-icon="start" >$(_ 'Write image'  )</button>
	$(listfd tofd) &lt;&lt;&lt; <input name="fromimage" type="file">
	</td>
	</tr>
	<tr>
	<td>
	<button type="submit" name="read" data-icon="start" >$(_ 'Read image'  )</button>
	$(listfd fromfd) &gt;&gt;&gt; <input name="toimage" type="text" value="/tmp/floppy.img">
	<td>
	</tr>
	</tbody>
</table>
</section>
EOT
cat <<EOT
<section>
	<header>
		$(_ 'Boot floppy set builder')
	</header>

<table>
	<tbody><tr>
	<td>$(_ 'Linux kernel:')</td>
	<td><input name="kernel" size="37" type="file"> <i>$(_ 'required')</i></td>
	</tr>
	<tr>
	<td>$(_ 'Initramfs / Initrd:')</td>
	<td><input name="initrd[]" size="37" type="file" multiple> <i>$(_ 'optional')</i></td>
	</tr>
	<tr>
	<td>$(_ 'Extra initramfs:')</td>
	<td><input name="initrd2[]" size="37" type="file" multiple> <i>$(_ 'optional')</i></td>
	</tr>
	<tr>
	<td>$(_ 'Boot message:')</td>
	<td><input name="info" size="37" type="file"> <i>$(_ 'optional')</i></td>
	</tr>
	<tr>
	<td>$(_ 'Default cmdline:')</td>
	<td id="cmdline"><input name="cmdline" size="36" type="text"> <input name="edit" checked="checked" type="checkbox">$(_ 'edit')
	<i>$(_ 'optional')</i></td>
	</tr>
	<tr>
	<td>$(_ 'Root device:')</td>
	<td><input name="rdev" size="8" value="/dev/ram0" type="text">
	&nbsp;&nbsp;$(_ 'Flags:') <select name="flags">
		<option selected="selected" value="1">R/O</option>
		<option value="0">R/W</option>
	</select>
	&nbsp;&nbsp;VESA: <select name="video">
		<option value="-3">Ask</option>
<option value="-2">Extended</option>
<option value="-1" selected="selected">Standard</option>
<option value="0">0</option>
<option value="1">1</option>
<option value="2">2</option>
<option value="3">3</option>
<option value="4">4</option>
<option value="5">5</option>
<option value="6">6</option>
<option value="7">7</option>
<option value="8">8</option>
<option value="9">9</option>
<option value="10">10</option>
<option value="11">11</option>
<option value="12">12</option>
<option value="13">13</option>
<option value="14">14</option>
<option value="15">15</option>
<option value="3840">80x25</option>
<option value="3841">80x50</option>
<option value="3842">80x43</option>
<option value="3843">80x28</option>
<option value="3845">80x30</option>
<option value="3846">80x34</option>
<option value="3847">80x60</option>
<option value="778">132x43</option>
<option value="777">132x25</option>
<option value="824">320x200x8</option>
<option value="781">320x200x15</option>
<option value="782">320x200x16</option>
<option value="783">320x200x24</option>
<option value="800">320x200x32</option>
<option value="818">896x672x24</option>
<option value="915">320x240x15</option>
<option value="821">320x240x16</option>
<option value="917">320x240x24</option>
<option value="918">320x240x32</option>
<option value="819">896x672x32</option>
<option value="931">400x300x15</option>
<option value="822">400x300x16</option>
<option value="933">400x300x24</option>
<option value="934">400x300x32</option>
<option value="820">512x384x8</option>
<option value="947">512x384x15</option>
<option value="823">512x384x16</option>
<option value="949">512x384x24</option>
<option value="950">512x384x32</option>
<option value="962">640x350x8</option>
<option value="963">640x350x15</option>
<option value="964">640x350x16</option>
<option value="965">640x350x24</option>
<option value="966">640x350x32</option>
<option value="768">640x400x8</option>
<option value="899">640x400x15</option>
<option value="825">640x400x16</option>
<option value="901">640x400x24</option>
<option value="902">640x400x32</option>
<option value="769">640x480x8</option>
<option value="784">640x480x15</option>
<option value="785">640x480x16</option>
<option value="786">640x480x24</option>
<option value="826">640x480x32</option>
<option value="879">800x500x8</option>
<option value="880">800x500x15</option>
<option value="881">800x500x16</option>
<option value="882">800x500x24</option>
<option value="883">800x500x32</option>
<option value="771">800x600x8</option>
<option value="787">800x600x15</option>
<option value="788">800x600x16</option>
<option value="789">800x600x24</option>
<option value="827">800x600x32</option>
<option value="815">896x672x8</option>
<option value="816">1600x1200x8</option>
<option value="817">1600x1200x16</option>
<option value="874">1024x640x8</option>
<option value="875">1024x640x15</option>
<option value="876">1024x640x16</option>
<option value="877">1024x640x24</option>
<option value="878">1024x640x32</option>
<option value="773">1024x768x8</option>
<option value="790">1024x768x15</option>
<option value="791">1024x768x16</option>
<option value="792">1024x768x24</option>
<option value="828">1024x768x32</option>
<option value="869">1152x720x8</option>
<option value="870">1152x720x15</option>
<option value="871">1152x720x16</option>
<option value="872">1152x720x24</option>
<option value="873">1152x720x32</option>
<option value="775">1280x1024x8</option>
<option value="793">1280x1024x15</option>
<option value="794">1280x1024x16</option>
<option value="795">1280x1024x24</option>
<option value="829">1280x1024x32</option>
<option value="835">1400x1050x8</option>
<option value="837">1400x1050x16</option>
<option value="838">1400x1040x24</option>
<option value="864">1440x900x15</option>
<option value="866">1440x900x16</option>
<option value="867">1440x900x24</option>
<option value="868">1440x900x32</option>
<option value="893">1920x1200x8</option>
	</select>
	</td>
	</tr>
	<tr>
	<td>$(_ 'Output directory:')</td>
	<td id="workdir"><input name="workdir" size="36" type="text" value="/tmp"></td>
	</tr>
	<tr>
	<td>$(_ 'Floppy size:')</td>
	<td><select name="format">
		<optgroup label="5&frac14; SD">
		<option value="360">360 KB</option>
		</optgroup>
		<optgroup label="3&frac12; SD">
		<option value="720">720 KB</option>
		</optgroup>
		<optgroup label="5&frac14; HD">
		<option value="1200">1.20 MB</option>
		</optgroup>
		<optgroup label="3&frac12; HD">
		<option value="1440" selected="selected">1.44 MB</option>
		<option value="1600">1.60 MB</option>
		<option value="1680">1.68 MB</option>
		<option value="1722">1.72 MB</option>
		<option value="1743">1.74 MB</option>
		<option value="1760">1.76 MB</option>
		<option value="1840">1.84 MB</option>
		<option value="1920">1.92 MB</option>
		<option value="1968">1.96 MB</option>
		</optgroup>
		<optgroup label="3&frac12; ED">
		<option value="2880">2.88 MB</option>
		<option value="3360">3.36 MB</option>
		<option value="3444">3.44 MB</option>
		<option value="3840">3.84 MB</option>
		<option value="3936">3.92 MB</option>
		</optgroup>
		<option value="0">$(_ 'no limit')</option>
	</select>&nbsp;
	$(_ 'RAM used')&nbsp;<select name="mem">
		<option selected="selected" value="16">16 MB</option>
		<option value="15">15 MB</option>
		<option value="14">14 MB</option>
		<option value="13">13 MB</option>
		<option value="12">12 MB</option>
		<option value="11">11 MB</option>
		<option value="10">10 MB</option>
		<option value="9">9 MB</option>
		<option value="8">8 MB</option>
		<option value="7">7 MB</option>
		<option value="6">6 MB</option>
		<option value="5">5 MB</option>
		<option value="4">4 MB</option>
	</select>&nbsp;
	<button type="submit" name="build" data-icon="start" >$(_ 'Build floppy set'  )</button>
	</td>
	</tr>
</tbody></table>
<footer>
<p>
$(_ 'Note') 1: $(_ 'the extra initramfs may be useful to add your own configuration files.')
</p>
<p>
$(_ 'Note') 2: $(_ 'the keyboard is read for ESC or ENTER on every form feed (ASCII 12) in the boot message.')
</p>
</footer>
</section>
</form>
EOT

xhtml_footer
exit 0
