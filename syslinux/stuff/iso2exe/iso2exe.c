#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>
#include "iso2exe.h"

static int fd;
static char tazlitoinfo[10*1024];
#define buffer tazlitoinfo
#define BUFFERSZ 2048

static void quit(char *msg)
{
	fprintf(stderr,"%s.\n", msg);
	exit(1);
}

static void readsector(unsigned long sector)
{
	if (lseek(fd, sector * BUFFERSZ, SEEK_SET) == -1 ||
	    read(fd, buffer, BUFFERSZ) != BUFFERSZ)
		quit("read sector failure");
}

int main(int argc, char *argv[])
{
#define heads 64
#define sectors 32
#define partition 446
#define trksz (512 * heads * sectors)
	unsigned long size, catalog, lba;
	int cylinders, i, j, isohybrid;
	unsigned n;
#ifndef WIN32
	char *bootiso;
	for (bootiso = (char *) main;
	     bootiso[0] != 'M' || bootiso[1] != 'Z' || bootiso[2] != 0xEB;
	     bootiso++) if (bootiso < (char *) main) quit("bootiso not found");
#endif
	if (argc < 2)
		quit("Usage : isohybrid.exe file.iso");
	fd = open(argv[1],O_RDWR|O_BINARY);
	if (fd == -1)
		quit("Can't open rw");

	// Install hybridiso boot sector
	readsector(17UL);
	if (strncmp(buffer+7, "EL TORITO SPECIFICATION", 23))
		quit("No EL TORITO boot record found");
	catalog = * (unsigned long *) (buffer + 71);
	readsector(catalog);
	if (* (unsigned long *) buffer != 1 || 
	    * (unsigned long *) (buffer + 30) != 0x88AA55)
	    	quit("invalid boot catalog.");
	lba = * (unsigned long *) (buffer + 40);
	readsector(lba);
	if (* (unsigned long *) (buffer + 64) != 1886961915)
		quit("no isolinux.bin hybrid signature in bootloader");
	isohybrid = bootiso[69] * 512;
	* (unsigned long *)  &bootiso[isohybrid + 432] = lba * 4;
	* (unsigned long *)  &bootiso[isohybrid + 440] = rand();
	* (unsigned long *)  &bootiso[isohybrid + partition] = 0x10080;
	* (unsigned short *) &bootiso[isohybrid + 510] = 0xAA55;
	size = lseek(fd, 0UL, SEEK_END);
	cylinders = (size + trksz - 1) / trksz;
	bootiso[isohybrid + partition + 4] = 23; // "Windows hidden IFS"
	bootiso[isohybrid + partition + 5] = heads - 1;
	bootiso[isohybrid + partition + 6] = (((cylinders - 1) & 0x300) >> 2) + sectors;
	bootiso[isohybrid + partition + 7] = (cylinders - 1) & 0xFF;
	* (unsigned long *) &bootiso[isohybrid + partition + 8] = 0;
	* (unsigned long *) &bootiso[isohybrid + partition + 12] = cylinders * sectors * heads;

	// Copy the partition table
	memcpy(bootiso + 0x1BE, bootiso + isohybrid + 0x1BE, 66);

	// Install iso2exe boot sector
	* (unsigned short *) (bootiso + 26) = rand();

	// read tazlito flavor data
	lseek(fd, 1024UL, SEEK_SET);
	read(fd, tazlitoinfo, sizeof(tazlitoinfo));

	// Update iso image
	n = (bootiso[69] + 1) * 512;
	lseek(fd, 0UL, SEEK_SET);
	write(fd, bootiso, n); // EXE/PE + isohybrid mbr
	write(fd, tazlitoinfo, ((0x8000U - BOOTISOSZ) > sizeof(tazlitoinfo)) 
		? sizeof(tazlitoinfo) : (0x8000U - BOOTISOSZ));
	write(fd, bootiso + n, BOOTISOSZ - n); // COM + rootfs + EXE/DOS 

	// Compute the checksum
	lseek(fd, 0UL, SEEK_SET);
	for (i = 66, n = 0, j = 0; j < 16; j++, i = 0) {
		if (read(fd, buffer, BUFFERSZ) != BUFFERSZ)
			goto nochksum;
		for (; i < BUFFERSZ; i += 2)
			n += * (unsigned short *) (buffer + i);
	}
	* (unsigned short *) (bootiso + 64) = -n;
	lseek(fd, 0UL, SEEK_SET);
	write(fd, bootiso, 512);
nochksum:
	close(fd);
	printf("Note you can create a USB key with %s.\n"
	       "Simply rename it to a .exe file and run it.\n", argv[1]);
}
