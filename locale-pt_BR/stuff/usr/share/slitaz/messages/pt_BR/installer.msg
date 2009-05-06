# slitaz-installer: Portuguese translation.

# start_install
START_INSTALL_MSG="\n
Bem-vindo ao instalador do SliTaz.\n\n
\Z2Iniciar uma nova instalação ou atualizar?\Zn"

# mount_cdrom
MOUNT_CDROM_ERROR_MSG="\
Arquivo não encontrado : rootfs.gz"

# ask_for_target_dev
ASK_FOR_TARGET_DEV_MSG="\n
Por favor, indique a partição alvo.\n\n
\Z2Partição a ser usada:\Zn"

# ask_for_mkfs_target_dev
ASK_FOR_MKFS_TARGET_DEV_MSG="\n
O SliTaz será instalado na partição: $TARGET_DEV\n\n
O próximo passo fará com que a partição seja formatada em ext3, um robusto \
e estável sistema de arquivos com suporte a journaling. Se a partição já \
estiver formatada você pode pular este estágio, caso contrário, confirme o passo. \
Aviso: a formatação da partição destruirá todos os dados contidos nela.\n\n
\Z2Você deseja formatar a partição em ext3?\Zn" 

# ask_for_hostname
ASK_FOR_HOSTNAME_MSG="\n
A configuração do nome do host (hostname) permite a você especificar o nome \
da máquina. Este nome é usado internamente para identificar a máquina numa rede. \
Este valor pode ser mudado depois que o sistema estiver instalado.\n\n
\Z2Nome do Host:\Zn"

# grub_install
GRUB_INSTALL_MSG="\n
Agora você tem a opção de instalar do gerenciador de boot GRUB, que é capaz \
de bootar quase todo tipo de sistema operacional. Se você quiser usar uma \
instalação existente do GRUB, pule este passo e adicione as linhas corretas \
ao seu arquivo de configuração do GRUB (menu.lst). Note que o instalador do \
SliTaz cria um arquivo de configuração na partiçaõ alvo que pode ser usado \
como exemplo (/mnt/target/boot/grub/menu.lst).\n\n
\Z2Instalar o GRUB em: $TARGET_DISK ?\Zn" 

# end_of_install
END_OF_INSTALL_MSG="\n
Instalação finalizada, você agora pode sair do instalador ou reiniciar o seu \
novo sistema operacional SliTaz GNU/Linux."