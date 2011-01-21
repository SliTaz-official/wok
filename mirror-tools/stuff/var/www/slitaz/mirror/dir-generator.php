<?php

$VERSION = "0.2-slitaz";

/*  Lighttpd Enhanced Directory Listing Script
 *  ------------------------------------------
 *  Authors: Evan Fosmark   <me@evanfosmark.com>,
 *           Pascal Bellard <pascal.bellard@slitaz.org>
 *           Christophe Lincoln <pankso@slitaz.org>
 *
 *
 *  GNU License Agreement
 *  ---------------------
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 *  http://www.gnu.org/licenses/gpl.txt
 */
 
// Get the path (cut out the query string from the request_uri)
list($path) = explode('?', $_SERVER['REQUEST_URI']);


// Get the path that we're supposed to show.
$path = ltrim(rawurldecode($path), '/');


if(strlen($path) == 0) {
	$path = "./";
}


// Can't call the script directly since REQUEST_URI won't be a directory
if($_SERVER['PHP_SELF'] == '/'.$path) {
	die("Unable to call " . $path . " directly.");
}


$vpath = ($path != "./")?$path:"";
// Make sure it is valid.
if(!is_dir($path)) {
//	die("<b>" . $path . "</b> is not a valid path.");
	$path = dirname($_SERVER["SCRIPT_FILENAME"]);
	list($vpath) = explode('?', $_SERVER['REQUEST_URI']);
	$vpath = ltrim(rawurldecode($vpath), '/');
}


//
// This function returns the file size of a specified $file.
//
function format_bytes($size, $precision=1) {
    $sizes = array('Y', 'Z', 'E', 'P', 'T', 'G', 'M', 'K', '');
    $total = count($sizes);

    while($total-- && $size > 1024) $size /= 1024;
    if ($sizes[$total] == '') {
    	$size /= 1024;
    	$total--;
    }
    return sprintf('%.'.$precision.'f', $size).$sizes[$total];
}


//
// Get some variables from /etc/lighttpd/lighttpd.conf
//
$conf_lightty = file_get_contents("/etc/lighttpd/lighttpd.conf");

function get_conf($var,$start,$stop,$default='') {
    global $conf_lightty;

    if (!preg_match('/'.$var.'/',$conf_lightty)) return $default;
    $filter = '/(.*\n)*'.$var.'\s*=\s*'.$start.'(([^'.$stop.']*\n*)*)'.$stop.'(.*\n)*/';
    return preg_replace($filter,'$2',$conf_lightty);
}

$encoding = get_conf('dir-listing.encoding','"','"','ascii');
$external_css = get_conf('dir-listing.external-css','"','"');

$show_hidden_files = false;
if (get_conf('dir-listing.hide-dotfile','"','"','disable') == "disable") {
	$show_hidden_files = true;
}
// get_conf('dir-listing.exclude','\(','\)');
// get_conf('dir-listing.set-footer','"','"');

$mime_types = array();
foreach (explode(',',get_conf('mimetype.assign','\(','\)')) as $item) {
	$filter = '/\s*"(.*)"\s*=>\s*"(.*)".*/';
	$val = explode(',',preg_replace($filter,'$1,$2',$item));
	if (isset($val[1])) $mime_types[$val[0]] = $val[1];
}

//
// This function returns the mime type of $file.
//
function get_file_type($file) {
	global $mime_types;
	
	$file = basename($file);
	$default_type = "application/octet-stream";
	if (isset($mime_types[$file])) {
		return $mime_types[$file];
	}
	$pos = strrpos($file, ".");
	if ($pos === false) {
		return $default_type;
	}
//FIXME .tar.gz
	$ext = '.'.rtrim(substr($file, $pos+1), "~");
	if (isset($mime_types[$ext])) {
		return $mime_types[$ext];
	}
	return $default_type;
}

//$slitaz_style = (dirname($_SERVER["PHP_SELF"]) == '/');
$slitaz_style = ($_SERVER["SERVER_NAME"] == "mirror.slitaz.org");
if ($slitaz_style) {
	$fvalue = "";
	if (isset($_GET[f])) $fvalue = 'value="'.$_GET[f].'"';
	print <<<EOT
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xml:lang="en" xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
	<title>Index of /$vpath</title>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
	<meta name="description" content=">Index of /$vpath" />
	<meta name="robots" content="index, nofollow" />
	<meta name="author" content="SliTaz Contributors" />
	<link rel="shortcut icon" href="/css/favicon.ico" />
	<link rel="stylesheet" type="text/css" href="/css/slitaz.css" />
	<style type='text/css'>
		div.list { background-color: white; padding-bottom: 14px;}
		table {width: 100% ;}
		th, td { font: 90% monospace; text-align: left;}
		th { font-weight: bold; padding-right: 14px; padding-bottom: 3px;}
		td {padding-right: 14px;}
		td.s, th.s {text-align: right;}
	</style>
</head>
<body>

<!-- Header -->
<div id="header">
	<a href="http://mirror.slitaz.org/"><img id="logo" 
		src="/css/pics/website/logo.png" 
		title="mirror.slitaz.org" alt="mirror.slitaz.org" /></a>
	<p id="titre">#!/Mirror/${vpath}</p>
</div>

<!-- Content -->
<div id="content-full">

<!-- Block begin -->
<div class="block">
	<!-- Nav block begin -->
	<div id="block_nav">
		<h3><img src="/css/pics/website/users.png" alt="users.png" />Community</h3>
		<ul>
			<li><a href="http://pizza.slitaz.org/">Live Builder</a></li>
			<li><a href="http://boot.slitaz.org/">Web Boot</a></li>
		</ul>
		<h3>Search</h3>
		<form class="search" action="${_SERVER["REQUEST_URI"]}" method="get" >
			<p><input type="text" name="f" $fvalue /></p>
		</form>
	<!-- Nav block end -->
	</div>
	<!-- Top block begin -->
	<div id="block_top">
		<h1>About Mirror</h1>
		<p>Welcome to Open Source!
EOT;
	if ($_SERVER["SERVER_NAME"] == "mirror.slitaz.org") print <<<EOT
		This is the SliTaz GNU/Linux main mirror. The server runs naturally SliTaz 
		(stable) in an lguest virtual machine provided by 
		<a href="http://www.ads-lu.com/">ADS</a>.	
EOT;
	print <<<EOT
		</p>
		<p><img src="/css/pics/website/network.png" 
			alt=".png" style="vertical-align:middle;"/>Mirrors: 
EOT;
	$mirrors = array(
	"switch.ch"     => "http://mirror.switch.ch/ftp/mirror/slitaz/",
	"gatech.edu"    => "http://www.gtlib.gatech.edu/pub/slitaz/",
	"tuxfamily.org" => "http://download.tuxfamily.org/slitaz/",
	"lupaworld.com" => "http://mirror.lupaworld.com/slitaz/",
	"ufpr.br"       => "http://slitaz.c3sl.ufpr.br/",
	"pina.si"       => "ftp://ftp.pina.si/slitaz/",
	"ibiblio.org"   => "http://distro.ibiblio.org/pub/linux/distributions/slitaz/",
	"vim.org"       => "http://ftp.vim.org/ftp/os/Linux/distr/slitaz/",
	"nedit.org"     => "http://ftp.nedit.org/ftp/ftp/pub/os/Linux/distr/slitaz/",
	"xemacs.org"    => "http://ftp.ch.xemacs.org/ftp/pool/2/mirror/slitaz/",
	"garr.it"       => "http://slitaz.mirror.garr.it/mirrors/slitaz/",
	);
	foreach($mirrors as $name => $url) {
		echo "<a href=\"$url$vpath\" title=\"$name mirror\">$name</a>\n";
	}
	print <<<EOT
		</p>
	<!-- Top block end -->
	</div>
<!-- Block end -->
</div>

EOT;
}
else {

// Print the heading stuff
print "<?xml version='1.0' encoding='$encoding'?>
<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.1//EN' 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd'>
<html xmlns='http://www.w3.org/1999/xhtml' xml:lang='en'>
	<head>
		<title>Index of /" .$vpath. "</title>
";
if ($external_css != '') {
print "	<link rel='stylesheet' type='text/css' href='".$external_css."' />
";
}
else {
print " <style type='text/css'>
		a, a:active {text-decoration: none; color: blue;}
		a:visited {color: #48468F;}
		a:hover, a:focus {text-decoration: underline; color: red;}
		body {background-color: #F5F5F5;}
		h2 {margin-bottom: 12px;}
		table {margin-left: 12px;}
		th, td { font: 90% monospace; text-align: left;}
		th { font-weight: bold; padding-right: 14px; padding-bottom: 3px;}
		td {padding-right: 14px;}
		td.s, th.s {text-align: right;}
		div.list { background-color: white; border-top: 1px solid #646464; border-bottom: 1px solid #646464; padding-top: 10px; padding-bottom: 14px;}
		div.foot { font: 90% monospace; color: #787878; padding-top: 4px;}
		</style>
";
}
print "	</head>
	<boby>
	<h2>Index of /" . $vpath ."</h2>
";
}

print "	<div class='list'>
	<table summary='Directory Listing' cellpadding='0' cellspacing='0'>
";



// Get all of the folders and files. 
$folderlist = array();
$filelist = array();
if($handle = @opendir($path)) {
	while(($item = readdir($handle)) !== false) {
		if ($item == "index.php") continue;
		if ($item == "dir-generator.php") continue;
		if (isset($_GET['f'])) {
			$filter = $_GET['f'];
			if (substr($filter,0,1) != '/')
				$filter = '/'.$filter.'/i';
			if (!preg_match($filter,$item)) continue;
		}
		if(is_dir($path.'/'.$item) and $item != '.' and $item != '..') {
			$folderlist[] = array(
				'name' => $item, 
				'size' => 0, 
				'modtime'=> filemtime($path.'/'.$item),
				'file_type' => "Directory"
			);
		}
		elseif(is_file($path.'/'.$item)) {
			if(!$show_hidden_files) {
				if(substr($item, 0, 1) == "." or substr($item, -1) == "~") {
					continue;
				}
			}
			$filelist[] = array(
				'name'=> $item, 
				'size'=> filesize($path.'/'.$item), 
				'modtime'=> filemtime($path.'/'.$item),
				'file_type' => get_file_type($path.'/'.$item)
			);
		}
	}
	closedir($handle);
}


if(!isset($_GET['s'])) {
	$_GET['s'] = 'name';
}

// Figure out what to sort files by
$file_order_by = array();
foreach ($filelist as $key=>$row) {
    $file_order_by[$key]  = $row[$_GET['s']];
}

// Figure out what to sort folders by
$folder_order_by = array();
foreach ($folderlist as $key=>$row) {
    $folder_order_by[$key]  = $row[$_GET['s']];
}

// Order the files and folders
$sort_type = SORT_ASC;
$order = "&amp;o=d";
if(isset($_GET['o'])) {
	$sort_type = SORT_DESC;
	$order = "";
}
array_multisort($folder_order_by, $sort_type, $folderlist);
array_multisort($file_order_by, $sort_type, $filelist);


// Show sort methods
print "<thead><tr>";

$sort_methods = array();
$sort_methods['name'] = "Name";
$sort_methods['modtime'] = "Last Modified";
$sort_methods['size'] = "Size";
$sort_methods['file_type'] = "Type";

foreach($sort_methods as $key=>$item) {
	if ($_GET['s'] == $key) $key = "$key$order";
	print "<th class='n'><a href='?s=$key'>$item</a></th>";
}
print "</tr></thead>\n<tbody>\n";



// Parent directory link
if($path != "./") {
	print "<tr><td class='n'><a href='..'>Parent Directory</a>/</td>";
	print "<td class='m'>&nbsp;</td>";
	print "<td class='s'>- &nbsp;</td>";
	print "<td class='t'>Directory</td></tr>\n";
}



// Print folder information
foreach($folderlist as $folder) {
	print "<tr><td class='n'><a href='" . addslashes($folder['name']). "'>" .htmlentities($folder['name']). "</a>/</td>";
	print "<td class='m'>" . date('Y-M-d H:m:s', $folder['modtime']) . "</td>";
	print "<td class='s'>- &nbsp;</td>";
	print "<td class='t'>" . $folder['file_type']                    . "</td></tr>\n";
}


// Print file information
foreach($filelist as $file) {
	print "<tr><td class='n'><a href='" . addslashes($file['name']). "'>" .htmlentities($file['name']). "</a></td>";
	print "<td class='m'>" . date('Y-M-d H:m:s', $file['modtime'])   . "</td>";
	print "<td class='s'>" . format_bytes($file['size'])           . "</td>";
	print "<td class='t'>" . $file['file_type']                      . "</td></tr>\n";
}

// Print ending stuff
$soft = explode('/',$_SERVER["SERVER_SOFTWARE"]);
$tag = get_conf('server.tag','"','"',$soft[0].' &lt;'.$soft[1].'&gt;');
print "</tbody>
	</table>
	</div>";
if ($slitaz_style) { ?>

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
			<li><a href="http://pkgs.slitaz.org/">Packages</a></li>
			<li><a href="http://labs.slitaz.org/">Laboratories</a></li>
		</ul>
	</div>
	<h4>SliTaz Website</h4>
	<ul>
		<li><a href="#header">Top of the page</a></li>
		<li>Copyright &copy; <span class="year"></span>
			<a href="http://www.slitaz.org/">SliTaz</a></li>
		<li><a href="about/">About the project</a></li>
		<li><a href="netmap.php">Network Map</a></li>
		<li>Page modified the <?php echo date('r'); ?></li>
		<li><a href="http://validator.w3.org/check?uri=referer"><img
		src="pics/website/xhtml10.png" alt="Valid XHTML 1.0"
		title="Code validé XHTML 1.0"
		style="width: 80px; height: 15px; vertical-align: middle;" /></a></li>
	</ul>
</div>

<?php }
else print "
	<form action='".$_SERVER["REQUEST_URI"]."' method='get'>
	<div class='foot'>".$tag."
		<input type='text' name='f'/>
		<!-- <input type='submit' value='Filter' /> -->
	</div>
	</form>
";
print "</body>
	</html>";
?>
