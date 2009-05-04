# slitaz-installer: French translation.

# start_install
START_INSTALL_MSG="\n
Bienvenue dans l'installateur de SliTaz GNU/Linux. Vous pouvez utiliser \
les flèches du clavier et la touche ENTER ou la souris pour valider. Il vous \
suffira de répondre à quelques questions lors des différentes étapes \
d'installation ou de mise à jour. Dans le cas d'une nouvelle installation, \
l'installateur va vous demander la partition à utiliser comme racine du \
système et vous proposer de la formater. Ensuite il va copier les fichiers \
depuis le cdrom, les décompresser, les installer et va préconfigurer le \
système. Pour finir, vous aurez aussi la possibilité d'installer le \
gestionnaire de démarrage GRUB, si besoin est.\n\n
\Z2Commencer une installation ou une mise à jour ?\Zn"

# mount_cdrom
MOUNT_CDROM_ERROR_MSG="\
Impossible de trouver : rootfs.gz\n\n
L'archive du système de fichiers racine n'est pas présente sur le cdrom. \
Il se peut que cette erreur soit due au fait que le LiveCD de SliTaz ne soit \
pas inséré dans le premier lecteur CD/DVD et que le media n'as pas pu être \
correctement monté. Arrêt."

# ask_for_target_dev
ASK_FOR_TARGET_DEV_MSG="\n
Veuillez indiquer la partition à utiliser pour installer SliTaz GNU/Linux, \
exemple: '/dev/hda1'. Vous pouvez utiliser le bouton 'List' pour afficher \
une liste des partitions disponibles sur le ou les disques durs et revenir \
ensuite à cet écran. A noter qu'il faut au minimum 100 Mb pour le coeur du \
système et que si vous prévoyez d'installer de nouveaux paquets, vous serez \
plus à l'aise avec environ 400 Mb.\n\n
\Z2Partition à utiliser:\Zn"

# ask_for_mkfs_target_dev
ASK_FOR_MKFS_TARGET_DEV_MSG="\n
SliTaz va être installé sur la partition : $TARGET_DEV\n\n
Vous avez la possibilité de formater la partition en ext3 ou d'utiliser \
le système de fichiers déjà présent sur la partition. Le format ext3 est \
un système de fichiers propre à Linux, robuste, stable et jounalisé, c'est \
le format conseillé. Faites attention, si vous formatez toutes les données \
de cette partition seront définitivement détruites. Si vous conservez le \
système de fichiers actuel, la partition sera nettoyée et les données 
utilisateurs conservées (/home).\n\n
\Z2Faut t'il formater la partition en ext3 ?\Zn" 

# ask_for_hostname
ASK_FOR_HOSTNAME_MSG="\n
Veuillez indiquer le nom de machine à utiliser pour votre système SliTaz.\
Le nom de machine ou 'hostname' est utilisé pour identifier votre machine sur \
le réseau et en local par le système (defaut: slitaz). A noter que cette \
valeur peut aussi être modifiée une fois le système installé en utilisant
'netbox' graphiquement ou en ligne de commande.\n\n
\Z2Nom de machine:\Zn"

# grub_install
GRUB_INSTALL_MSG="\n
Avant de redémarrer sur votre nouveau système SliTaz GNU/Linux, veuillez \
vous assurer qu'un gestionnaire de démarrage est bien installé. Si ce n'est \
pas le cas vous pouvez répondre oui et installer GRUB. Si vous n'installez \
pas GRUB, un fichier de configuration (menu.lst) a été généré pendant \
l'installation, il contient les lignes qui permettent de démarrer SliTaz.\n\n
Une fois installé, GRUB peut facilement être reconfiguré et propose un SHell \
interactif au boot.\n\n
\Z2Faut t'il installer GRUB sur: $TARGET_DISK ?\Zn" 

# end_of_install
END_OF_INSTALL_MSG="\n
L'installation est terminée. Vous pouvez dès maintenant redémarrer (reboot) \
sur votre nouveau système SliTaz GNU/Linux et commencer à finement le \
configurer en fonction de vos besoins et préférences. Vous trouverez de l'aide \
ou un support technique gratuit via la liste de discussion et/ou le forum \
officiel du projet. Pour bien commencer à utiliser le système, vous pouvez \
vous référer aux documents du Handbook de SliTaz et utiliser le gestionnaire \
de paquets Tazpkg pour installer de nouveaux logiciels prêts à savourer." 
