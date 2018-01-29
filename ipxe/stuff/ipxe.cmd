#!ipxe

set menu-timeout 3000
dhcp && console --picture http://mirror.slitaz.org/pxe/ipxe/slitaz.png ||

:menu
menu SliTaz net boot menu
item --key b boot	Local boot
item --gap
item --gap Network boot
item --key l lan	Your PXE boot ${filename}
item --key w web	SliTaz WEB boot
item --key r rolling	SliTaz development version
item --gap
item --gap Configuration
isset ${ip} || item --key i ipset	IP settings
item --key c config	iPXE configuration
item --key e exit	iPXE command line
choose --timeout ${menu-timeout} --default web target || goto exit
set menu-timeout 0
isset ${dns} || set dns 8.8.8.8
goto ${target}

:boot
exit

:exit
help
echo Type 'exit' to get the back to the menu
shell
goto menu

:ipset
echo -n IP address: && read net0/ip
set net0/netmask 255.255.255.0
echo -n Subnet mask: ${} && read net0/netmask
echo -n Default gateway: && read net0/gateway
echo -n DNS server: ${} && read dns
goto menu

:web
isset ${ip} || dhcp || echo No DHCP
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
isset ${ip} || dhcp || echo No DHCP
autoboot ||
goto menu

:rolling
isset ${ip} || dhcp || echo No DHCP
sanboot http://mirror.slitaz.org/iso/rolling/slitaz-rolling.iso ||
goto menu

:config
config
goto menu
