#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>
#include "iso2exe.h"

static int fd;
static char buffer[2048];

static void quit(char *msg)
{
	fprintf(stderr,"%s.\n", msg);
	exit(1);
}

static void readsector(unsigned long sector)
{
	if (lseek(fd, sector * sizeof(buffer), SEEK_SET) == -1 ||
	    read(fd, buffer, sizeof(buffer)) != sizeof(buffer))
		quit("read sector failure");
}

int main(int argc, char *argv[])
{
#define heads 64
#define sectors 32
#define partition 446
#define trksz (512 * heads * sectors)
	unsigned long size, catalog, lba;
	int cylinders, i, j;
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
	* (unsigned long *)  &bootiso[512 + 432] = lba * 4;
	* (unsigned long *)  &bootiso[512 + 440] = rand();
	* (unsigned long *)  &bootiso[512 + partition] = 0x10080;
	* (unsigned short *) &bootiso[512 + 510] = 0xAA55;
	size = lseek(fd, 0, SEEK_END);
	cylinders = (size + trksz - 1) / trksz;
	bootiso[512 + partition + 4] = 23; // "Windows hidden IFS"
	bootiso[512 + partition + 5] = heads - 1;
	bootiso[512 + partition + 6] = (((cylinders - 1) & 0x300) >> 2) + sectors;
	bootiso[512 + partition + 7] = (cylinders - 1) & 0xFF;
	* (unsigned long *) &bootiso[512 + partition + 8] = 0;
	* (unsigned long *) &bootiso[512 + partition + 12] = cylinders * sectors * heads;

	// Install iso2exe boot sector
	memcpy(bootiso + 512 - 66, bootiso + 1024 - 66, 66); 
	* (unsigned short *) (bootiso + 26) = rand();

	// Update iso image
	lseek(fd, 0, SEEK_SET);
	write(fd, bootiso, 1024);
	lseek(fd, 0x8400 - BOOTISOSZ, SEEK_SET);
	write(fd, bootiso + 1024, BOOTISOSZ - 1024);

	// Compute the checksum
	lseek(fd, 0, SEEK_SET);
	for (i = 66, n = 0, j = 0; j < 16; j++, i = 0) {
		if (read(fd, buffer, sizeof(buffer)) != sizeof(buffer))
			goto nochksum;
		for (; i < sizeof(buffer); i += 2)
			n += * (unsigned short *) (buffer + i);
	}
	* (unsigned short *) (bootiso + 64) = -n;
	lseek(fd, 0, SEEK_SET);
	write(fd, bootiso, 512);
nochksum:
	close(fd);
}
