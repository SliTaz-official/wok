# slitaz-installer: Magyar fordítás.

# start_install
START_INSTALL_MSG="\n
Üdvözöljük a Slitaz Telepítõben\n\n
\Z2Új installálás vagy frissítés ?\Zn"

# mount_cdrom
MOUNT_CDROM_ERROR_MSG="\
Nem található : rootfs.gz"

# ask_for_target_dev
ASK_FOR_TARGET_DEV_MSG="\n
Kérjük adja meg a célpartíciót!\n\n
\Z2Használandó partíció:\Zn"

# ask_for_mkfs_target_dev
ASK_FOR_MKFS_TARGET_DEV_MSG="\n
A Slitaz erre a partícióra települ : $TARGET_DEV\n\n
A következõ lépéssel a célpartíció ext3-ra formázható. Az ext3 egy fejlett, \
stabil naplózó fájlrendszer. Ha a partíciót már megformázta, akkor \
kihagyhatja ezt a lépést, ha nem, formázza meg. Figyelmeztetjük, hogy a formázás \
minden aktuális adatot töröl!\n\n
\Z2Meg akarja formázni a partíciót ext3-ra ?\Zn" 

# ask_for_hostname
ASK_FOR_HOSTNAME_MSG="\n
A hosztnévvel beállíthat egy speciális azonosítót a számítógépnek. A hosztnevet \
belsõleg használjuk a hoszt azonosítására az interneten. A név megváltoztatható \
a rendszer telepítése után is.\n\n
\Z2Hostname:\Zn"

# grub_install
GRUB_INSTALL_MSG="\n
Most van lehetõsége telepíteni a GRUB-boot töltõt, amivel elérhetõ a másik,  \
a gépen lévõ operációs rendszerek elindítása. Ha egy létezõ, telepített GRUB-ot\
akar használni, hagyja ki ezt a lépést, és adja hozzá a megfelelõ sorokat a GRUB \
konfigurációs fájlhoz (menu.lst). A SliTaz Telepítõ is létrehoz egy konfigurációs \
fájlt a célpartíción, melyet felhasználhat példaként. \
(/mnt/target/boot/grub/menu.lst).\n\n
\Z2Telepítsük-e a GRUB-ot erre: $TARGET_DISK ?\Zn" 

# end_of_install
END_OF_INSTALL_MSG="\n
A telepítés befejezõdött, most kiléphet a Telepítõbõl és újraindíthatja a friss\
SliTaz GNU/Linux operációs rendszerét." 
