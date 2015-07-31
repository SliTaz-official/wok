#!/bin/sh
#
# Hardware / power saving
#
# Copyright (C) 2011-2015 SliTaz GNU/Linux - BSD License
#

# Common functions from libtazpanel
. lib/libtazpanel
get_config

case "$1" in
	menu)
		cat <<EOT
<li><a data-icon="display" href="powersaving.cgi" data-root>$(_ 'Power saving')</a></li>
EOT
		exit
esac

header

TITLE=$(_ 'Hardware')

xhtml_header "$(_ 'Power saving')"

## DPMS ##
cat <<EOT
<section>
	<header>
		<span data-icon="display">DPMS (Display Power Management Signaling)</span>
	</header>

	<div>$(_ "DPMS enables power saving behaviour of monitors when the computer is not in use.")</div>
	<form method="post" class="wide">
		<input type="hidden" name="powersaving" value="set"/>
EOT

monitor_conf='/etc/X11/xorg.conf.d/50-Monitor.conf'
if [ ! -s "$monitor_conf" ]; then
	# Config is absent, so create it
	cat > "$monitor_conf" <<EOT
Section "Monitor"
	Identifier   "Monitor0"
	VendorName   "Monitor Vendor"
	ModelName    "Monitor Model"
	Option "DPMS" "true"
EndSection
EOT
fi

cat <<EOT
		<table class="wide zebra">
			<thead>
				<tr><td>$(_ 'Identifier')</td>
					<td>$(_ 'Vendor name')</td>
					<td>$(_ 'Model name')</td>
					<td>$(_ 'DPMS enabled')</td>
				</tr>
			</thead>
EOT

awk -F\" '{
	if ($1 ~ /^Section/) { I = V = M = D = ""; }
	if ($1 ~ /Identifier/) { I = $2; }
	if ($1 ~ /VendorName/) { V = $2; }
	if ($1 ~ /ModelName/)  { M = $2; }
	if ($1 ~ /Option/ && $2 ~ /DPMS/) { D = $4; }
	if ($1 ~ /EndSection/) {
		if (D == "false") { D = ""; } else { D = "checked"; }
		printf "<tr><td data-icon=\"display\">%s</td><td>%s</td><td>%s</td><td>", I, V, M;
		printf "<label><input type=\"checkbox\" name=\"%s\" %s/>DPMS</label>", I, D;
		printf "</td></tr>\n";
	}
}' $monitor_conf

layout_conf='/etc/X11/xorg.conf.d/10-ServerLayout.conf'

cat <<EOT
		</table>
		<input type="hidden" name="ids" value="$(
			awk -F\" '$1 ~ /Identifier/ { printf "%s ", $2; }' $monitor_conf)"/>

		<table>
			<tr><td>
					<fieldset>
						<legend>$(_ 'DPMS times (in minutes):')</legend>
						<table>
							<tr><td>Standby Time</td>
								<td><input type="number" name="StandbyTime" value="10"/></td></tr>
							<tr><td>Suspend Time</td>
								<td><input type="number" name="SuspendTime" value="20"/></td></tr>
							<tr><td>Off Time</td>
								<td><input type="number" name="OffTime"     value="30"/></td></tr>
						</table>
					</fieldset>
				</td>
				<td style="vertical-align: top">
					<fieldset>
						<legend>$(_ 'Manual edit')</legend>
						<a data-icon="conf" href="index.cgi?file=$monitor_conf">$(basename $monitor_conf)</a><br/>
						<a data-icon="conf" href="index.cgi?file=$layout_conf">$(basename $layout_conf)</a>
					</fieldset>
					<pre>$(for i in $(POST); do echo "$i: " $(POST $i); done)</pre>
				</td>
			</tr>
		</table>
		<footer>
			<button type="submit" data-icon="ok">$(_ 'Change')</button>
		</footer>
	</form>
</section>
EOT


## CPU ##

cpu=$(awk -F: '$1 ~ "model name" {
	gsub(/\(TM\)/,"™",$2); gsub(/\(R\)/,"®",$2);
	split($2,c,"@");
	print "<span data-icon=\"cpu\">" c[1] "</span>";
}' /proc/cpuinfo)
multiplier=$(echo "$cpu" | wc -l)
[ "$multiplier" -ne 1 ] && cpu="$multiplier × $(echo "$cpu" | head -n1)"

freq=$(awk -F: 'BEGIN{N=0}$1~"MHz"{printf "%d:<b>%s</b>MHz ",N,$2; N++}' /proc/cpuinfo)

cat <<EOT
<section>
	<header><span data-icon="cpu">$(_ 'CPU')</span></header>

	<div>$(_ "CPU frequency scaling enables the operating system to scale the \
CPU frequency up or down in order to save power. CPU frequencies can be scaled \
automatically depending on the system load, in responce to ACPI events, or \
manually by userspace programs.")</div>

	<table class="wide zebra">
		<tr><td>$(_ 'Model name')</td><td>$cpu</td></tr>
		<tr><td>$(_ 'Current frequency')</td><td>$freq</td></tr>
		<tr><td>$(_ 'Current driver')</td><td>$(cat '/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver')
		<tr><td>$(_ 'Current governor')</td><td>$(cat '/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor')
	</table>
</section>
EOT

# As of Kernel 3.4, the native CPU module is loaded automatically.
if [ -d "/lib/modules/$(uname -r)/kernel/drivers/cpufreq" ]; then
	cd /lib/modules/$(uname -r)/kernel/drivers/cpufreq
	cat <<EOT
<section>
	<header>$(_ 'Kernel modules')</header>
	<table class="wide zebra summary">
		<thead>
			<tr><td>$(_ 'Module')</td>
				<td>$(_ 'Description')</td>
			</tr>
		</thead>
EOT
	lsmod="$(lsmod | awk '{printf "%s " $1}') "

	for module in $(ls | grep -v 'mperf\|speedstep-lib'); do
		module="${module%.ko.xz}"; module="${module//-/_}"
		if echo $lsmod | grep -q " $module "; then icon='ok'; else icon='cancel'; fi
		echo "<tr><td><span data-icon=\"$icon\">$module</span></td><td>"
		modinfo $module | awk -F: '$1=="description"{
			gsub(/\(TM\)/,"™",$2); gsub(/\(R\)/,"®",$2);
			gsub(/VIA|C7|Cyrix|MediaGX|NatSemi|Geode|Transmeta|Crusoe|Efficeon|Pentium™ 4|Xeon™|AMD|K6-2\+|K6-3\+|K7|Athlon 64|Opteron|Intel/,"<b>&</b>",$2);
			print $2}'
		echo "</td></tr>"
	done
	cat <<EOT
	</table>
</section>
EOT
fi

xhtml_footer
exit 0
