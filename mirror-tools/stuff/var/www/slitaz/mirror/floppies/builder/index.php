<?php
if (false) { // no php support on this mirror !
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xml:lang="en" xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
	<title>SliTaz Boot Floppies redirection</title>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
	<meta name="description" content="slitaz boot floppies builder redirection" />
	<meta name="robots" content="index, nofollow" />
	<meta name="author" content="SliTaz Contributors" />
	<meta http-equiv="Refresh" content="0;url=http://mirror.slitaz.org/floppies/builder/index.php">
</head>
<?php
}
ini_set('upload_max_filesize','16M');
ini_set('post_max_size','16M');
if (isset($_GET['id']) && is_file("/tmp/".$_GET['id']."/fd")) {

	// Download a floppy image
	
    	$size = $_GET['s'];
    	if ($size == 0)
    		$size = filesize("/tmp/".$_GET['id']."/fd");
	header("Content-Type: application/octet-stream");
	header("Content-Length: ".$size);
	header("Content-Disposition: attachment; filename=".
		sprintf("fd%03d.img",$_GET['n']));
	$cmd = "cat /tmp/".$_GET['id']."/fd";
	if ($_GET['s'] != 0) {
		$cmd .= " /dev/zero | dd count=1 bs=".$_GET['s'];
		if ($_GET['n'] > 1)
			$cmd .= " skip=".($_GET['n']-1);
	}
	echo `$cmd 2> /dev/null`;
	exit;
}
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xml:lang="en" xmlns="http://www.w3.org/1999/xhtml" lang="en">
<head>
	<title>SliTaz Boot Floppies</title>
	<meta http-equiv="content-type" content="text/html; charset=ISO-8859-1" />
	<meta name="description" content="slitaz boot floppies builder" />
	<meta name="robots" content="index, nofollow" />
	<meta name="author" content="SliTaz Contributors" />
	<link rel="shortcut icon" href="../../css/favicon.ico" />
	<link rel="stylesheet" type="text/css" href="../../css/slitaz.css" />
	<style>
input[type=text] {
	width: inherit;
}
	</style>
</head>
<body bgcolor="#ffffff">
<!-- Header -->
<div id="header">
    <a name="top"></a>
<!-- Access -->
<div id="access">
	<a href="bootloader" title="Build your floppy sets without Internet">Shell builder</a> |
	<a href="../../boot/floppy-grub4dos" title="Boot tools">Generic boot floppy</a>
</div>   
	<a href="http://www.slitaz.org/"><img id="logo" src="../../css/pics/website/logo.png" title="www.slitaz.org" alt="www.slitaz.org" style="border: 0px solid ; width: 200px; height: 74px;" /></a>
	<p id="titre">#!/boot/floppies/builder</p>
</div>

<!-- Navigation menu -->
<div id="nav">

<?php

	// Cleanup old sessions
	
	$dir = opendir("/tmp");
	while (($name = readdir($dir)) !== false) {
		if (preg_match('/^fdbuild/',$name) == 0) continue;
		if (filemtime("/tmp/$name") > strtotime("-1 hour")) continue;
		system("rm -rf /tmp/$name");
	}
	closedir($dir);

function get_long($file, $offset)
{
	$value = 0;
	if ($fp = fopen($file,"r")) {
		fseek($fp,$offset,SEEK_SET);
		for ($i = 0; $i < 32; $i += 8) {
			$value += ord(fgetc($fp)) << $i;
		}
		fclose($fp);
	}
	return $value;
}

function error($string, $title="Error")
{
	echo <<<EOT
<div class="nav_box">
<h4>$title</h4>
<p>
$string
</p>
</div>
EOT;
}

	$size = 0;
	$initrd_size = 0;
	
	// Upload kernel
	
	foreach($_FILES as $data) {
		$msg="The file ".$_FILES["kernel"]['name']." ";
		switch ($data["error"]) {
		case UPLOAD_ERR_INI_SIZE   : 
			error($msg."exceeds upload_max_filesize.");
			break;
		case UPLOAD_ERR_FORM_SIZE  : 
			error($msg."exceeds max_post_size.");
			break;
		case UPLOAD_ERR_PARTIAL    : 
			error($msg."was only partially uploaded.");
			break;
		case UPLOAD_ERR_NO_TMP_DIR : 
			error("Missing a temporary folder.");
			break;
		case UPLOAD_ERR_CANT_WRITE : 
			error("Failed to write file to disk.");
			break;
		}
	}
	if (isset($_FILES["kernel"]['tmp_name']) &&
	    is_uploaded_file($_FILES["kernel"]['tmp_name'])) {
		$tmp_dir = tempnam('','fdbuild');
		if (file_exists($tmp_dir)) unlink($tmp_dir);
		mkdir($tmp_dir);
		$tmp_dir .= '/';
		move_uploaded_file($_FILES["kernel"]['tmp_name'],
				   $tmp_dir."kernel");
		$kernel = $tmp_dir."kernel";
		$boot_version = get_long($kernel,0x206) & 255;
		$size = get_long($kernel,0x1F4);	// syssize paragraphs
		if ($boot_version < 4) $size &= 0xFFFF;	// 16 bits before 2.4
		$size = ($size + 0xFFF) & 0xFFFF000;	// round up to 64K
		$size <<= 4;				// paragraphs -> bytes
		if (get_long($kernel,0x202) != 0x53726448 ||	// 'HdrS' magic
		    (get_long($kernel,0x211) & 1 != 1)) {	// bzImage flag
			error("The file ".$_FILES["kernel"]['name'].
			      " is not a bzImage Linux kernel.");
			$size = 0;
		}
		else if ($boot_version < 2 && $_POST['cmdline']) { // before 2.2
			unset($_POST['cmdline']);
			error("This boot loader does not support Linux kernel ".
			      "prior 2.4.0-test3-pre3 command line.",
			      "Warning");
		}
		$msg = "The size of the file ".$_FILES["kernel"]['name'];
	}
	
	// Upload initrd
	
	if ($size && isset($_FILES["initrd"]['tmp_name']) &&
	    is_uploaded_file($_FILES["initrd"]['tmp_name'])) {
		move_uploaded_file($_FILES["initrd"]['tmp_name'],
				   $tmp_dir."initrd");
		$initrd_size = $_FILES["initrd"]['size'];
		$size += $initrd_size;
		$msg = "The total size of the files ".$_FILES["kernel"]['name'].
		       " and ".$_FILES["initrd"]['name'];
	}
	if ($initrd_size && isset($_FILES["initrd2"]['tmp_name']) &&
	    is_uploaded_file($_FILES["initrd2"]['tmp_name'])) {
		move_uploaded_file($_FILES["initrd2"]['tmp_name'],
				   $tmp_dir."initrd2");
		$initrd2_size = $_FILES["initrd2"]['size'];
		$size += $initrd2_size;
		$msg = "The total size of the files ".$_FILES["kernel"]['name'].
		       ", ".$_FILES["initrd"]['name'].
		       " and ".$_FILES["initrd2"]['name'];
	}
	if ($size >= 15 * 1024 * 1024) {
		error($msg." exceeds 15 MB.");
		$size = 0;
	}
	if ($size == 0) {
		if (isset($tmp_dir))
			system("rm -f $tmp_dir");
	}
	else {
		$cmd = "./bootloader ".$tmp_dir."kernel --prefix "
		     . $tmp_dir."fd --format 0 --flags ".$_POST['flags']
		     . " --video ".$_POST['video'];
		if ($_POST['cmdline'])
			$cmd .= " --cmdline '".$_POST['cmdline']."'";
		if (file_exists($_POST['rdev']))
			$cmd .= " --rdev ".$_POST['rdev'];
		if ($initrd_size)
			$cmd .= " --initrd ".$tmp_dir."initrd";
		if ($initrd2_size)
			$cmd .= " --initrd ".$tmp_dir."initrd2";
		switch ($_POST['size']) {
		case 1763328 : 
		case 2015232 : 
		case 3526656 :
		case 4030464 :
			$cmd .= " --tracks 82"; break;
		case 1784832 : 
			$cmd .= " --tracks 83"; break;
		}
		shell_exec($cmd);
		$count = 1;
		if ($_POST['size'] != 0) {
			$count += (filesize($tmp_dir."fd") -1) / $_POST['size'];
			$padding = $_POST['size'] - 
				(filesize($tmp_dir."fd") % $_POST['size']);
		}
	}
	$sizes = array(
		"368640" => "360 KB",   "737280" => "720 KB",
		"1228800" => "1.20 MB",
		"1474560" => "1.44 MB", "1638400" => "1.60 MB",
		"1720320" => "1.68 MB", "1763328" => "1.72 MB",
		"1784832" => "1.74 MB", "1802240" => "1.76 MB",
		"1884160" => "1.84 MB", "1966080" => "1.92 MB", 
		"2015232" => "1.96 MB", "2949120" => "2.88 MB",
		"3440640" => "3.36 MB", "3526656" => "3.44 MB",
		"3932160" => "3.84 MB", "4030464" => "3.92 MB",
		"0"       => "no limit"
	);

function show_size($size)
{
	global $sizes;
	if ($size != 0) return " ".$sizes[$size];
}
	if (!isset($count)) {
?>
<div class="nav_box">
<h4>How does it work ?</h4>
<p>
This tool updates the boot sector of your kernel with
<a href="http://hg.slitaz.org/wok/raw-file/b84ff32e3457/linux/stuff/linux-header-2.6.34.u">this patch</a>.
You may add a default cmdline and an initramfs. The cmdline can be edited at boot
time but the keyboard is not mandatory.
A <a href="bootloader"> standalone version</a> is available.
</p>
<p>
Each part (boot, setup, cmdline, kernel, initramfs) is aligned to 512 bytes.
The result is split to fit the floppy size.
The last floppy image is padded with zeros.
</p>
</div>
<?php
	}
	else {
?>
<div class="nav_box">
<h4>Download image<?php if ($count >= 2) echo "s"; ?></h4>
<ul>
<?php
		for ($i = 1; $i <= $count; $i++) {
			echo '	<li><a href="'.$_SERVER["PHP_SELF"].
			     "?id=".basename($tmp_dir)."&amp;n=$i&amp;s=".
			     $_POST["size"].'">'.sprintf("fd%03d.img",$i).
			     show_size($_POST["size"])."</a></li>\n";
		}
		echo "</ul>\n".floor($padding/1024)."KB padding.\n";
?>
</div>
<?php
	}
?>

<!-- End navigation menu -->
</div>

<!-- Content top. -->
<div id="content_top">
<div class="top_left"></div>
<div class="top_right"></div>
</div>

<!-- Content -->
<div id="content">

<h1><font color="#3e1220">Boot</font></h1>
<h2><font color="#df8f06">Floppy image set builder</font></h2>

<?php
	if (!isset($count)) {
		$max = rtrim(ini_get('upload_max_filesize'),"M");
		$max_post = rtrim(ini_get('post_max_size'),"M");
		if ($max_post < $max) $max = $max_post;
		$msg = "the tiny boot loader can't load more than 15 MB";
		if ($max < 16)
			$msg = "the web server can't upload more than $max MB";
?>
<form method="post" enctype="multipart/form-data" action="<?php echo $_SERVER["PHP_SELF"]; ?>">
<table>
	<tr>
	<td>Linux kernel:</td>
	<td><input type="file" name="kernel" size="25" /> <i>required</i></td>
	</tr>
	<tr>
	<td>Initramfs / Initrd:</td>
	<td><input type="file" name="initrd" size="25" /> <i>optional</i></td>
	</tr>
	<tr>
	<td>Extra initramfs:</td>
	<td><input type="file" name="initrd2" size="25" /> <i>optional</i></td>
	</tr>
	<tr>
	<td>Default cmdline:</td>
	<td><input type="text" name="cmdline" size="36" <?php 
		if (isset($_GET['cmdline'])) echo 'value="'.$_GET['cmdline'].'"';
	?>/> <i>optional</i></td>
	</tr>
	<tr>
	<td>Root device:</td>
	<td><input type="text" name="rdev" size="8" value="<?php
		if (isset($_GET['rdev'])) echo $_GET['rdev'];
		else echo "/dev/fd0";
	?>" />
	&nbsp;&nbsp;Root flags: <select name="flags">
		<option value="1">R/O</option>
		<option value="0" <?php
			if (isset($_GET['rdev']) && $_GET['rdev'] == "0")
				echo ' selected="selected"'
		?>>R/W</option>
	</select>
	&nbsp;&nbsp;VGA mode: <select name="video">
		<?php
			$selected=-1;
			if (isset($_GET['video'])) $selected = $_GET['video'];
			$options = array();
			$options[-3] = "Ask";
			$options[-2] = "Ext";
			$options[-1] = "Std";
			for ($i = 0; $i < 64; $i++) $options[$i] = $i;
			foreach ($options as $key => $value) {
				echo '<option value="'.$key.'"';
				if ($key == $selected || $value == $selected)
					echo ' selected="selected"';
				echo '>'.$value."</option>\n";
			}
		?>
	</select>
	</td>
	</tr>
	<tr>
	<td>Floppy size:</td>
	<td><select name="size">
<?php
	foreach ($sizes as $key => $value) {
		echo "		<option value=\"$key\"";
		if ($key == "1474560") echo " selected='selected'";
		echo ">$value</option>\n";
	}
?>
	</select>
		<input name="build" value="Build floppy set" type="submit" />
	</td>
	</tr>
</table>
</form>
<?php
		echo <<<EOT
<p>
Note 1: $msg of files (kernel and initramfs) in memory.
</p>
<p>
Note 2: the extra initramfs may be useful to add your own configuration files.
</p>
EOT;
	}
	else {
?>

<p>
You can write floppies with SliTaz <i>bootfloppybox</i>, 
<a href="http://en.wikipedia.org/wiki/RaWrite">Windows rawrite</a> or simply dd:
</p>
<pre># dd if=fd001.img of=/dev/fd0
</pre>

<p>
Start your computer with <i>fd001.img</i>. It will show the kernel version string and
the kernel cmdline line. You can edit the cmdline. Most users can just press Enter.
</p>

<?php
		if ($count >= 2) {
?>
<p>
The floppy is then loaded into memory (one dot each 64k) and you will be prompted to
insert the next floppy, <i>fd002.img</i>. And so on.
</p>

<p>
The floppy set detects disk swaps and can be used without keyboard.
</p>
<?php
		}
?>
<p>
Good luck.
</p>
<?php
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
Copyright &copy; <?php echo date('Y'); ?> <a href="http://www.slitaz.org/">SliTaz</a> -
<a href="http://www.gnu.org/licenses/gpl.html">GNU General Public License</a>
</p>
<!-- End of copy -->
</div>

<!-- Bottom and logo's -->
<div id="bottom">
<p>
<a href="http://validator.w3.org/check?uri=referer"><img src="../../css/pics/website/xhtml10.png" alt="Valid XHTML 1.0" title="Code validé XHTML 1.0" style="width: 80px; height: 15px;" /></a>
</p>
</div>

</body>
</html>
