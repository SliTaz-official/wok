<?php
$version='cooking';
$wok='wok';
if (isset($_GET['stable'])) {
	$version='stable';
	$wok='wok-stable';
}
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
<body>

<!-- Header -->
<div id="header">
    <a href="http://bb.slitaz.org/"><img id="logo"
		src="pics/website/logo.png"
		title="bb.slitaz.org" alt="bb.slitaz.org" /></a>
    <p id="titre">#!/Build/Bot<?php if ($version == 'stable') echo '/stable'; ?></p>
</div>

<!-- Content -->
<div id="content-full">

<!-- Block begin -->
<div class="block">
	<!-- Nav block begin -->
	<div id="block_nav">
		<h3><img src="pics/website/development.png" alt="devel.png" />Developers</h3>
		<ul>
			<li><a href="http://www.slitaz.org/en/devel/">Website/devel</a></li>
			<li><a href="http://labs.slitaz.org/">Laboratories</a></li>
			<li><a href="http://hg.slitaz.org/">Mercurial Repos</a></li>
			<li><a href="http://people.slitaz.org/">People Stuff</a></li>
			<li><a href="http://scn.slitaz.org/">Community Network</a></li>
		</ul>
	<!-- Nav block end -->
	</div>
	<!-- Top block begin -->
	<div id="block_top">
		<h1>Cooklog</h1>
		<p>
			The BuildBot generated cooklog file to help debug packages
			and check the build process.
		</p>
	<!-- Top block end -->
	</div>
<!-- Block end -->
</div>

<h2>Search</h2>

<p>
<form action="log.php" method="get">
	<input type="text" name="package" style="width: 300px;" />
	<!-- <input type="submit" value="Show" /> -->
<?php

if ($_GET['package']) {
	$pkg = $_GET["package"];
	if (file_exists("$log_dir/$pkg.log")) {
		echo " Package $pkg: ";
		echo '<a href="' . "log/$pkg.log" . '">Raw log</a> ' . "\n";
		echo '</form></p>';
		echo '<pre class="log">' . "\n";
		echo date ("F d Y H:i:s", filemtime("log/$pkg.log"))."\n";
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

<!-- End of content -->
</div>

<!-- Footer -->
<div id="footer">
	<div class="right_box">
	<h4>SliTaz Network</h4>
		<ul>
			<li><a href="http://www.slitaz.org/">Main Website</a></li>
			<li><a href="http://doc.slitaz.org/">Documentation</a></li>
			<li><a href="http://forum.slitaz.org/">Support Forum</a></li>
			<li><a href="http://scn.slitaz.org/">Community Network</a></li>
			<li><a href="http://labs.slitaz.org/">Laboratories</a></li>
			<li><a href="http://twitter.com/slitaz">SliTaz on Twitter</a></li>
		</ul>
	</div>
	<h4>SliTaz Website</h4>
	<ul>
		<li><a href="#header">Top of the page</a></li>
		<li>Copyright &copy; <span class="year"></span>
			<a href="http://www.slitaz.org/">SliTaz</a></li>
		<li><a href="http://www.slitaz.org/en/about/">About the project</a></li>
		<li><a href="http://www.slitaz.org/netmap.php">Network Map</a></li>
		<li>Page modified the <?php echo (date( "d M Y", getlastmod())); ?></li>
		<li><a href="http://validator.w3.org/check?uri=referer"><img
		src="pics/website/xhtml10.png" alt="Valid XHTML 1.0"
		title="Code validé XHTML 1.0"
		style="width: 80px; height: 15px; vertical-align: middle;" /></a></li>
	</ul>
</div>

</body>
</html>
