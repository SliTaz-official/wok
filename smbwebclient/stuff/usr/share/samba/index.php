<?php
	$SMBWEBCLIENT_CLASS = 'smbwebclient_config';
	include '/usr/share/samba/smbwebclient-2.9.php';
	include '/etc/samba/smbwebclient.conf';
	$swc = new smbwebclient_config;
	$swc->Run();
?>
