#!ipxe

set menu-timeout 3000
dhcp ||

:menu
menu SliTaz net boot menu
item --key b boot	Local boot
item --key l lan	Your PXE boot
item --key w web	SliTaz WEB boot
item --key r rolling	SliTaz development version
item --key c config	iPXE configuration
item --key e exit	iPXE command line
choose --timeout ${menu-timeout} --default web target || goto exit
set menu-timeout 0
goto ${target}

:boot
exit

:exit
help
echo Type 'exit' to get the back to the menu
shell
goto menu

:web
imgfree
set weburl http://mirror.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://mirror.switch.ch/ftp/mirror/slitaz/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://download.tuxfamily.org/slitaz/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://mirror1.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://mirror2.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
set weburl http://mirror3.slitaz.org/pxe/
chain --autofree ${weburl}ipxe/menu.ipxe && boot ||
goto menu

:lan
autoboot ||
goto menu

:rolling
sanboot http://mirror.slitaz.org/iso/rolling/slitaz-rolling.iso ||
goto menu

:config
config
goto menu
