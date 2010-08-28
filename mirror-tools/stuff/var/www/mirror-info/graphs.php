<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
	<title>Mirror RRD stats</title>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
	<meta name="description" content="slitaz mirror rrdtool graphs" />
	<meta name="robots" content="noindex" />
	<meta name="author" content="SliTaz Contributors" />
	<link rel="shortcut icon" href="favicon.ico" />
	<link rel="stylesheet" type="text/css" href="slitaz.css" />
</head>

<body bgcolor="#ffffff">
<!-- Header -->
<div id="header">
    <a name="top"></a>
	<a href="http://mirror.slitaz.org/"><img id="logo"
	src="pics/website/logo.png" title="mirror.slitaz.org" alt="mirror.slitaz.org"
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
<a href="http://www.ads-lu.com/">ADS</a>.
</p>

</div>

<div class="nav_box">
<h4>SliTaz Network</h4>
<ul>
	<li><a href="http://www.slitaz.org/">Main Website</a></li>
	<li><a href="http://forum.slitaz.org/">Community Forum</a></li>
	<li><a href="http://community.slitaz.org/">Community Platform</a></li>
	<li><a href="http://labs.slitaz.org/">SliTaz Laboratories</a></li>
	<li><a href="http://pkgs.slitaz.org/">Packages Database</a></li>
	<li><a href="http://boot.slitaz.org/">SliTaz Web Boot</a></li>
	<li><a href="http://tank.slitaz.org/">SliTaz main server</a></li>
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

<h1><font color="#3E1220">Mirror RRD stats</font></h1>
<h2><font color="#DF8F06">/usr/bin/rrdtool</font></h2>

<?php

$myurl="http://".$_SERVER['SERVER_NAME'].$_SERVER['SCRIPT_NAME'];

function one_graphic($img,$name)
{
	echo '<img src="pics/rrd/'.$img.'" title="'.
		$name.'" alt="'.$name.'" />'."\n";
}

function graphic($res, $img='')
{
	global $myurl;
	if (!$img) $img=$res;
	echo "<a name=\"".$res."\"></a>";
	echo "<a href=\"".$myurl."?stats=".$res."#".$res."\">\n";
	one_graphic($img."-day.png",$res." daily");
	echo "</a>";
	if (isset($_GET['stats']) && $_GET['stats'] == $res) {
		one_graphic($img."-week.png",$res." weekly");
		one_graphic($img."-month.png",$res." monthly");
		one_graphic($img."-year.png",$res." yearly");
	}
}

echo "<h3>CPU</h3>\n";
graphic("cpu");
echo "<h3>Memory</h3>\n";
graphic("memory");
echo "<h3>Disk</h3>\n";
graphic("disk");
echo "<h3>Network</h3>\n";
graphic("net","eth0");

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
