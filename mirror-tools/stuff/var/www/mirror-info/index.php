<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<title>SliTaz Mirror</title>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
	<meta name="description" content="slitaz mirror server" />
	<meta name="robots" content="index, nofollow" />
	<meta name="author" content="SliTaz Contributors" />
	<link rel="shortcut icon" href="favicon.ico" />
	<link rel="stylesheet" type="text/css" href="slitaz.css" />
</head>

<body bgcolor="#ffffff">
<!-- Header -->
<div id="header">
    <a name="top"></a>
	<a href="http://mirror-info.slitaz.org/"><img id="logo"
	src="pics/website/logo.png" title="mirror-info.slitaz.org" alt="mirror-info.slitaz.org"
	style="border: 0px solid ; width: 200px; height: 74px;" /></a>
	<p id="titre">#!/project/mirror</p>
</div>

<!-- Navigation menu -->
<div id="nav">

<div class="nav_box">
<h4>About Mirror</h4>
<p>
This is the SliTaz GNU/Linux main mirror. The server runs naturally SliTaz 
(stable) in an lguest virtual machine provided by 
<a href="http://www.ads-lu.com/">Allied Data Sys. (ADS)</a>.
</p>

</div>

<div class="nav_box">
<h4>SliTaz Network</h4>
<ul>
	<li><a href="http://www.slitaz.org/">Main Website</a></li>
	<li><a href="http://doc.slitaz.org/">Documentation</a></li>
	<li><a href="http://forum.slitaz.org/">Community Forum</a></li>
	<li><a href="http://community.slitaz.org/">Community Platform</a></li>
	<li><a href="http://labs.slitaz.org/">SliTaz Laboratories</a></li>
	<li><a href="http://pkgs.slitaz.org/">Packages Database</a></li>
	<li><a href="http://boot.slitaz.org/">SliTaz Web Boot</a></li>
	<li><a href="http://tank.slitaz.org/">SliTaz main server</a></li>
	<li><a href="http://bb.slitaz.org/">SliTaz Build Bot</a></li>
	<li><a href="http://hg.slitaz.org/">SliTaz Repositories</a></li>
	<li><a href="http://twitter.com/slitaz">SliTaz on Twitter</a></li>
	<li><a href="http://www.distrowatch.com/slitaz">SliTaz on DistroWatch</a></li>
</ul>
</div>

<!-- End navigation menu -->
</div>

<!-- Content top. -->
<div id="content_top">
<div class="top_left"></div>
<div class="top_right"></div>
</div>

<!-- Content -->
<div id="content">

<h1><font color="#3E1220">Server</font></h1>
<h2><font color="#DF8F06">Codename: mirror</font></h2>

<p>
Mirror CPU is a <?php system("sed -e '/^model name/!d;s/.*Intel(R) //;" .         
"s/@//;s/(.*)//;s/CPU //;s/.*AMD //;s/.*: //;s/Processor //' </proc/cpuinfo |" .
" awk '{ s=$0; n++ } END { if (n == 2) printf \"dual \";" .
"if (n == 4) printf \"quad \"; print s }' ")?> -
<?php system("free | awk '/Mem:/ { x=2*$2-1; while (x >= 1024) { x /= 1024; ".
"n++ }; y=1; while (x > 2) { x /= 2; y *= 2}; ".
"printf \"%d%cB RAM\",y,substr(\"MG\",n,1) }' ")?> -
Located in France next to Roubaix. This page has real time statistics 
provided by PHP <code>system()</code>. Mirror is also monitored by RRDtool 
which provides <a href="graphs.php">graphical stats</a>.
</p>

<h3><a href="graphs.php">
	<img title="Mirror RRDtool graphs" src="pics/website/monitor.png" alt="graphs" />
    </a>System stats</h3>

<h4>Uptime</h4>

<pre class="package">
<?php
system("uptime | sed 's/^\s*//'");
?>
</pre>

<h4>Disk usage</h4>
<pre class="package">
<?php
system("df -h | sed '/^rootfs/d' | grep  '\(^/dev\|Filesystem\)'");
?>
</pre>

<h4>Network</h4>
<pre class="package">
<?php
system("ifconfig eth0 | awk '{ if (/X packet/ || /X byte/) print }' | sed 's/^\s*//'");
?>
</pre>

<?php if (isset($_GET["all"])) { ?>
<h4>Logins</h4>
<pre class="package">
<?php
system("last");
?>
</pre>

<h4>Processes</h4>
<pre class="package">
<?php
system("top -n1 -b");
?>
</pre>
<?php } ?>

<a name="vhosts"></a>
<h3><a href="http://mirror.slitaz.org/awstats.pl?config=info.mirror.slitaz.org" target="_blank">
	<img title="Mirror Virtual hosts" alt="vhosts"
    src="pics/website/vhosts.png" /></a>Virtual hosts</h3>

<ul>
	<li><a href="http://mirror.slitaz.org/">mirror.slitaz.org</a> - SliTaz Mirror.
	(<a href="http://mirror.slitaz.org/stats" target="_blank">stats</a>)</li>
	<li><a href="http://pizza.slitaz.org/">pizza.slitaz.org</a> - SliTaz Flavor builder.
	(<a href="http://mirror.slitaz.org/awstats.pl?config=pizza.mirror.slitaz.org" target="_blank">stats</a>)</li>
	<li><a href="https://ajaxterm.slitaz.org/">ajaxterm.slitaz.org</a> - Slitaz Web Console.
	(<a href="http://mirror.slitaz.org/awstats.pl?config=ajaxterm.slitaz.org" target="_blank">stats</a>)</li>
</ul>

<a name="replicas"></a>
<h3><a href="http://mirror.slitaz.org/awstats.pl?config=replicas.mirror.slitaz.org" target="_blank">
         <img title="Tank replicas" alt="replicas"
    src="pics/website/vhosts.png" /></a>Tank replicas</h3>

<ul>
	<li><a href="http://mirror.slitaz.org/www/">www.slitaz.org</a> - SliTaz Website.
	(<a href="http://www.slitaz.org/" target="_blank">main</a>)</li>
	<li><a href="http://mirror.slitaz.org/doc/">doc.slitaz.org</a> - Documentation.
	(<a href="http://doc.slitaz.org/" target="_blank">main</a>)</li>
	<li><a href="http://mirror.slitaz.org/pkgs/">pkgs.slitaz.org</a> - Packages Web interface.
	(<a href="http://pkgs.slitaz.org/" target="_blank">main</a>)</li>
	<li><a href="http://mirror.slitaz.org/hg/">hg.slitaz.org</a> - Mercurial repositories (read only).
	(<a href="http://hg.slitaz.org/" target="_blank">main</a>
	<a href="http://hg.tuxfamily.org/mercurialroot/slitaz/" target="_blank">tuxfamily</a>)</li>
	<li><a href="http://mirror.slitaz.org/webboot/">boot.slitaz.org</a> - gPXE Web boot.
	(<a href="http://boot.slitaz.org/" target="_blank">main</a>)</li>
</ul>

<a name="mirrors"></a>
<h3><a href="http://mirror.slitaz.org/awstats.pl?config=rsync" target="_blank">
	<img title="Secondary mirrors" src="pics/website/vhosts.png" 
	 alt="mirrors" /></a>Mirrors</h3>
	Most mirrors are updated using the url: <b>rsync://mirror.slitaz.org/slitaz/</b>
	(<a href="http://mirror.slitaz.org/awstats.pl?config=rsync">stats</a>)
<ul>
	<li><a href="http://en.utrace.de/?query=mirror.switch.ch">
		<img title="map" src="pics/website/ch.png" alt="map" /></a>
		<a href="http://mirror.switch.ch/ftp/mirror/slitaz/">
		http://mirror.switch.ch/ftp/mirror/slitaz/</a> or
		<a href="ftp://mirror.switch.ch/mirror/slitaz/">ftp</a></li>
	<li><a href="http://en.utrace.de/?query=www.gtlib.gatech.edu">
		<img title="map" src="pics/website/us.png" alt="map" /></a>
		<a href="http://www.gtlib.gatech.edu/pub/slitaz/">
		http://www.gtlib.gatech.edu/pub/slitaz/</a> or
		<a href="ftp://ftp.gtlib.gatech.edu/pub/slitaz/">ftp</a> or
		<a href="rsync://www.gtlib.gatech.edu/slitaz/">rsync</a></li>
	<li><a href="http://en.utrace.de/?query=download.tuxfamily.org">
		<img title="map" src="pics/website/fr.png" alt="map" /></a>
		<a href="http://download.tuxfamily.org/slitaz/">
		http://download.tuxfamily.org/slitaz/</a> or
		<a href="ftp://download.tuxfamily.org/slitaz/">ftp</a> or
		<a href="rsync://download.tuxfamily.org/pub/slitaz/">rsync</a></li>
	<!-- li><a href="http://www.linuxembarque.com/slitaz/mirror/">
		<img title="map" src="pics/website/fr.png" alt="map" /></a>
		<a href="http://www.linuxembarque.com/slitaz/mirror/">
		http://www.linuxembarque.com/slitaz/mirror/</a></li -->
	<li><a href="http://en.utrace.de/?query=mirror.lupaworld.com">
		<img title="map" src="pics/website/cn.png" alt="map" /></a>
		<a href="http://mirror.lupaworld.com/slitaz/">
		http://mirror.lupaworld.com/slitaz/</a></li>
	<li><a href="http://en.utrace.de/?query=slitaz.c3sl.ufpr.br">
		<img title="map" src="pics/website/br.png" alt="map" /></a>
		<a href="http://slitaz.c3sl.ufpr.br/">
		http://slitaz.c3sl.ufpr.br/</a> or
		<a href="ftp://slitaz.c3sl.ufpr.br/slitaz/">ftp</a> or
		<a href="rsync://slitaz.c3sl.ufpr.br/slitaz/">rsync</a></li>
	<li><a href="http://en.utrace.de/?query=slitaz.mirror.garr.it">
		<img title="map" src="pics/website/it.png" alt="map" /></a>
		<a href="http://slitaz.mirror.garr.it/mirrors/slitaz/">
		http://slitaz.mirror.garr.it/mirrors/slitaz/</a> or
		<a href="ftp://slitaz.mirror.garr.it/mirrors/slitaz/">ftp</a> or
		<a href="rsync://slitaz.mirror.garr.it/mirrors/slitaz/">rsync</a></li>
	<!-- li><a href="http://mirror.drustvo-dns.si/slitaz/">
		http://mirror.drustvo-dns.si/slitaz/</a></li -->
	<li><a href="http://en.utrace.de/?query=ftp.pina.si">
		<img title="map" src="pics/website/si.png" alt="map" /></a>
		<a href="ftp://ftp.pina.si/slitaz/">
		ftp://ftp.pina.si/slitaz/</a></li>
	<li><a href="http://en.utrace.de/?query=distro.ibiblio.org">
		<img title="map" src="pics/website/us.png" alt="map" /></a>
		<a href="http://distro.ibiblio.org/pub/linux/distributions/slitaz/">
		http://distro.ibiblio.org/pub/linux/distributions/slitaz/</a> or
		<a href="ftp://distro.ibiblio.org/pub/linux/distributions/slitaz/">ftp</a></li>
	<li><a href="http://en.utrace.de/?query=ftp.vim.org">
		<img title="map" src="pics/website/nl.png" alt="map" /></a>
		<a href="http://ftp.vim.org/ftp/os/Linux/distr/slitaz/">
		http://ftp.vim.org/ftp/os/Linux/distr/slitaz/</a> or
		<a href="ftp://ftp.vim.org/mirror/os/Linux/distr/slitaz/">
		ftp</a></li>
	<li><a href="http://en.utrace.de/?query=ftp.nedit.org">
		<img title="map" src="pics/website/nl.png" alt="map" /></a>
		<a href="http://ftp.nedit.org/ftp/ftp/pub/os/Linux/distr/slitaz/">
		http://ftp.nedit.org/ftp/ftp/pub/os/Linux/distr/slitaz/</a> or
		<a href="ftp://ftp.nedit.org/ftp/ftp/pub/os/Linux/distr/slitaz/">
		ftp</a></li>
	<li><a href="http://en.utrace.de/?query=ftp.ch.xemacs.org">
		<img title="map" src="pics/website/ch.png" alt="map" /></a>
		<a href="http://ftp.ch.xemacs.org/ftp/pool/2/mirror/slitaz/" />
		http://ftp.ch.xemacs.org/ftp/pool/2/mirror/slitaz/</a> or
		<a href="ftp://ftp.ch.xemacs.org//pool/2/mirror/slitaz/" />
		ftp</a></li>
</ul>

<a name="builds"></a>
<h3><img title="Daily builds" src="pics/website/monitor.png" alt="builds" />
    Daily builds</h3>

<?php
function display_log($file,$anchor,$url)
{
echo '<a name="'.$anchor.'"></a>';
echo "<a href=\"$url\">";
system("stat -c '<h4>%y %n</h4>' ".$file." | sed -e 's/.000000000//' -e 's|/var/log/\(.*\).log|\\1.iso|'");
echo "</a>";
echo "<pre>";
system("cat ".$file." | sed -e 's/.\[[0-9][^mG]*.//g' | awk '".
'{ if (/\[/) { n=index($0,"["); printf("%s%s%s\n",substr($0,1,n-1),'.
'substr("\t\t\t\t\t\t\t",1,9-(n/8)),substr($0,n)); } else print }'."'");
echo "</pre>";
}

display_log("/var/log/packages-stable.log", "buildstable", "/iso/stable/packages-3.0.iso");
display_log("/var/log/packages-cooking.log","buildcooking","/iso/cooking/packages-cooking.iso");
?>
<!-- End of content with round corner -->
</div>
<div id="content_bottom">
<div class="bottom_left"></div>
<div class="bottom_right"></div>
</div>

<!-- Start of footer and copy notice -->
<div id="copy">
<p>                                                                          
Last update : <?php echo date('r'); ?>
</p> 
<p>
Copyright &copy; <?php echo date('Y'); ?> <a href="http://www.slitaz.org/">SliTaz</a> -
<a href="http://www.gnu.org/licenses/gpl.html">GNU General Public License</a>
</p>
<!-- End of copy -->
</div>

<!-- Bottom and logo's -->
<div id="bottom">
<p>
<a href="http://validator.w3.org/check?uri=referer"><img
   src="pics/website/xhtml10.png" alt="Valid XHTML 1.0"
   title="Code validé XHTML 1.0"
   style="width: 80px; height: 15px;" /></a>
</p>
</div>

</body>
</html>
