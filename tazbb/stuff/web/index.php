<?php
$version='cooking';
$notversion='stable';
$wok='wok';
if (isset($_GET['stable'])) {
	$version='stable';
	$notversion='cooking';
	$wok='wok-stable';
}
include("conf.php");
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <title>SliTaz Build Bot</title>
    <meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
    <meta name="description" content="Tazbb web interface" />
    <meta name="robots" content="index nofollow" />
    <link rel="shortcut icon" href="favicon.ico" />
    <link rel="stylesheet" type="text/css" href="slitaz.css" />
</head>

<body bgcolor="#ffffff">
<!-- Header -->
<div id="header">
    <a name="top"></a></a><?php if ($version == 'stable') { ?>
<!-- Access -->                                                                 
<div id="access">
    <a href="/<?php if ($version != 'stable')
echo "?stable"; ?>" title="Slitaz <?php
echo $notversion ?> packages"><?php echo $notversion ?></a>                          
</div>                                                                         
    <?php } ?>
    <a href="http://bb.slitaz.org/"><img id="logo"
    src="pics/website/logo.png" title="bb.slitaz.org" alt="bb.slitaz.org"
    style="border: 0px solid ; width: 200px; height: 74px;" /></a>
    <p id="titre">#!/bb/packages<?php if ($version == 'stable') echo '/stable'; ?></p>
</div>

<!-- Navigation menu -->
<div id="nav">

<div class="nav_box">
<h4>SliTaz Network</h4>
<ul>
	<li><a href="http://www.slitaz.org/">Main Website</a></li>
	<li><a href="http://doc.slitaz.org/">Documentation</a></li>
	<li><a href="http://forum.slitaz.org/">Community Forum</a></li>
	<li><a href="http://labs.slitaz.org/">SliTaz Labs</a></li>
	<li><a href="http://pkgs.slitaz.org/">Packages Database</a></li>
	<li><a href="http://twitter.com/slitaz">SliTaz on Twitter</a></li>
	<li><a href="http://www.distrowatch.com/slitaz">SliTaz on DistroWatch</a></li>
</ul>
</div>

<div class="nav_box">
<h4>SliTaz Developers</h4>
<ul>
	<li><a href="http://hg.slitaz.org/">Hg Repositories</a></li>
	<li><a href="http://tank.slitaz.org/">Tank Server</a></li>
	<li><a href="http://people.slitaz.org/">People Stuff</a></li>
	<li><a href="http://labs.slitaz.org/wiki/distro">Distro Wiki</a></li>
	
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

<h1><font color="#3E1220">Build Bot</font></h1>
<h2><font color="#DF8F06">/usr/bin/tazbb</font></h2>

<p>
Tazbb is a <a href="http://www.slitaz.org/">SliTaz GNU/Linux</a> Build Bot,
it automatically cooks and tests packages commited in the wok. SliTaz
<a href="http://pkgs.slitaz.org/">packages</a> are cooked on the project
main server: code name <a href="http://tank.slitaz.org">Tank</a>. This
web interface gives the current status of the build bot and the last report
about any packages modified by the SliTaz contributors in the Mercurial
repositories, aka <a href="http://hg.slitaz.org/">Hg repos</a>.
</p>

<p>
<form action="log.php" method="get">
<?php
	if ($version == 'stable')
		echo '<input type="hidden" name="stable" value="1" />';
?>	Show cooklog: <input type="text" name="package" />
	<!-- <input type="submit" value="Show" /> -->
</form>
</p>

<h3>Summary</h3>
<pre class="package">
<?php

// Check curent status (update in real time) and display summary.

if (file_exists($lockfile)) {
	echo "Status   : Running ";
	include("$db_dir/running");
}
else {
	echo "Status   : Not currently running\n";
}
include("$db_dir/summary");

?>
</pre>

<h3>Report</h3>
<pre class="package">
<?php
include("$db_dir/report");
?>
</pre>

<h3>Cooklist</h3>
<pre class="package">
<?php
include("$db_dir/cooklist");
?>
</pre>

<h3>Unbuilt</h3>
<pre class="package">
<?php
include("$db_dir/unbuilt");
?>
</pre>

<h3>Blocked</h3>
<pre class="package">
<?php
include("$db_dir/blocked.urls");
?>
</pre>

<h3>Corrupted</h3>
<pre class="package">
<?php
include("$db_dir/corrupted");
?>
</pre>

<h3>Last cooked packages</h3>
<pre class="package">
<?php
system("cd $packages && ls -1t *.tazpkg | head -20 | \
	while read file; do echo -n \$(stat -c '%y' $packages/\$file | \
	cut -d. -f1); echo '   '\$file; done"); ?>
</pre>

<h3>Last removed packages</h3>
<pre class="package">
<?php
include("$db_dir/removed");
?>
</pre>

<h3>Last cooked flavors</h3>
<pre class="package">
<?php
system("cd $packages && ls -1t *.flavor | head -20 | \
	while read file; do echo -n \$(stat -c '%y' $packages/\$file | \
	cut -d. -f1); echo '   '\$file; done"); ?>
</pre>

<!-- End of content with round corner -->
</div>

<!-- Start of footer and copy notice -->
<div id="copy">
<p>
Copyright &copy; 2010 <a href="http://www.slitaz.org/">SliTaz</a> -
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
