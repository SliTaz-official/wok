<?php
include("conf.php");
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
    <title>Tazbb cooklog <?php echo $_GET['package']; ?></title>
    <meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
    <meta name="description" content="Tazbb web interface cooklog" />
    <meta name="robots" content="index nofollow" />
    <link rel="shortcut icon" href="favicon.ico" />
    <link rel="stylesheet" type="text/css" href="slitaz.css" />
</head>

<body bgcolor="#ffffff">
<!-- Header -->
<div id="header">
    <a name="top"></a>
<!-- Access -->
<div id="access">
	<a href="http://forum.slitaz.org/">Forum</a>
	<a href="http://wiki.slitaz.org/">Wiki</a>
	<a href="http://art.slitaz.org/">Art</a>
	<a href="http://labs.slitaz.org/">Labs</a>
	<a href="http://pkgs.slitaz.org/">Packages</a>
	<a href="http://hg.slitaz.org/">Hg</a>
</div>
    <a href="http://bb.slitaz.org/"><img id="logo"
    src="pics/website/logo.png" title="bb.slitaz.org" alt="bb.slitaz.org"
    style="border: 0px solid ; width: 200px; height: 74px;" /></a>
    <p id="titre">#!/bb/packages</p>
</div>

<!-- Content top. -->
<div id="content_top">
<div class="top_left"></div>
<div class="top_right"></div>
</div>

<!-- Content -->
<div id="content">

<h1><font color="#3E1220">Build Bot</font></h1>
<h2><font color="#DF8F06">Cooklog</font></h2>

<p>
<form action="log.php" method="get">
	Show cooklog: <input type="text" name="package" />
	<!-- <input type="submit" value="Show" /> -->
<?php

if ($_GET['package']) {
	$pkg = $_GET["package"];
	if (file_exists("$log_dir/$pkg.log")) {
		echo " Package $pkg: ";
		echo '<a href="' . "log/$pkg.log" . '">Raw log</a> ' . "\n";
		echo '</form></p>';
		echo '<pre class="log">' . "\n";
		include("$log_dir/$pkg.log");
		echo '</pre>';
	}
	else {
		echo " No log file found for: $pkg";
		echo '</form></p>';
	}
}
else {
	echo '</form></p>';
}

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
Copyright &copy; 2009 <a href="http://www.slitaz.org/">SliTaz</a> -
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
