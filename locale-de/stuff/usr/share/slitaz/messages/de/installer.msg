# slitaz-installer: Deutsche Uebersetzung.

# Installation starten
START_INSTALL_MSG="\n
Willkommen zur SliTaz Installation.\n\n
\Z2Eine neue Installation starten oder upgraden?\Zn"

# CDRom mounten
MOUNT_CDROM_ERROR_MSG="\
Konnte die Datei rootfs.gz nicht finden"

# ask_for_target_dev
ASK_FOR_TARGET_DEV_MSG="\n
Bitte die Partition wählen, auf der SliTaz installiert werden soll.\n\n
\Z2Verwendete Partition:\Zn"

# ask_for_mkfs_target_dev
ASK_FOR_MKFS_TARGET_DEV_MSG="\n
SliTaz wird auf folgender Partition installiert: $TARGET_DEV\n\n
Der nächste Schritt wird die Zielpartition mit ext3 formatieren. Ext3 ist ein robustes, \
stabiles Journaling-Dateisystem. Wenn die Partition schon formatiert wurde, \
können Sie diesen Schritt überspringen. Achtung Das Formatieren wird alle Daten \
auf der Partition zerstören.\n\n
\Z2Möchten Sie die Partition mit ext3 formatieren ?\Zn" 

# ask_for_hostname
ASK_FOR_HOSTNAME_MSG="\n
Der Hostname legt den Namen des Rechners (in Netzwerken) fest. \
Er kann nach der Installation noch manuell geaendert werden. \
\n\n
\Z2Hostname:\Zn"

# grub_install
GRUB_INSTALL_MSG="\n
Sie haben nun die Möglichkeit den GRUB Bootloader zu installieren, \
der in der Lage ist jedes Betriebssystem zu booten. Wenn GRUB schon installiert ist \
überspringen sie diesen Schritt und fügen Sie der Konfigurationsdatei von GRUB \
(menu.lst) den SliTaz-Eintrag hinzu (Anleitung im SliTaz-Wiki). Ein Beispiel enthält \
zudem folgende Datei: /mnt/target/boot/grub/menu.lst.\n\n
\Z2Install GRUB on: $TARGET_DISK ?\Zn" 

# end_of_install
END_OF_INSTALL_MSG="\n
Die Installation ist erfolgreich beendet worden. Sie können den Installer nun \
schließen. Nach dem Neustart können Sie ihr neues SliTaz GNU/Linux System verwenden." 
