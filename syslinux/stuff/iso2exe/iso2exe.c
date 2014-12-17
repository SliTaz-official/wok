#ifdef __TURBOC__
#include <io.h>
#endif
#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef WIN32
#include <windows.h>
#endif
#include "iso2exe.h"

static int fd, forced, status = 1;
static char tazlitoinfo[10*1024];
#define buffer tazlitoinfo
#define BUFFERSZ 2048
#define WORD(n)	* (unsigned short *) (n)
#define LONG(n)	* (unsigned long *)  (n)

static void readsector(unsigned long sector)
{
	if (lseek(fd, sector * BUFFERSZ, SEEK_SET) == -1 ||
	    read(fd, buffer, BUFFERSZ) != BUFFERSZ) {
		puts(bootiso+READSECTORERR);
		exit(1);
	}
}

static unsigned install(char *filename)
{
#define heads 64
#define sectors 32
#define partition 446
#define trksz (512UL * heads * sectors)
	unsigned long size, catalog, lba;
	int cylinders, i, j, isohybrid;
	unsigned n;
#ifndef WIN32
	for (bootiso = (char *) install;
	     bootiso[0] != 'M' || bootiso[1] != 'Z' || bootiso[2] != '\xEB';
	     bootiso++) if (bootiso < (char *) install) {
		bootiso = "No bootiso data";
		return 0;
	}
#endif
	if (!filename)
		return USAGE;
	fd = open(filename,O_RDWR|O_BINARY);
	if (fd == -1)
		return OPENERR;

	if (forced == 0) {
		status = 2;
		/* Install hybridiso boot sector */
		readsector(17UL);
		if (strncmp(buffer+7, bootiso+ELTORITOERR+ELTORITOOFS, 23))
			return ELTORITOERR;
		catalog = LONG(buffer + 71);
		readsector(catalog);
		if (LONG(buffer) != 1 || LONG(buffer + 30) != 0x88AA55UL)
		    	return CATALOGERR;
		lba = LONG(buffer + 40);
		readsector(lba);
		if (LONG(buffer + 64) != 1886961915UL)
			return HYBRIDERR;
		isohybrid = bootiso[69] * 512;
		LONG(bootiso + isohybrid + 432) = lba * 4;
		LONG(bootiso + isohybrid + 440) = rand();
		LONG(bootiso + isohybrid + partition) = 0x10080UL;
		WORD(bootiso + isohybrid + 510) = 0xAA55U;
		size = lseek(fd, 0UL, SEEK_END);
		cylinders = (size + trksz - 1) / trksz;
		bootiso[isohybrid + partition + 4] = 23; /* "Windows hidden IFS" */
		bootiso[isohybrid + partition + 5] = heads - 1;
		bootiso[isohybrid + partition + 6] = (((cylinders - 1) & 0x300) >> 2) + sectors;
		bootiso[isohybrid + partition + 7] = (cylinders - 1) & 0xFF;
		LONG(bootiso + isohybrid + partition + 8) = 0;
		LONG(bootiso + isohybrid + partition + 12) = cylinders * sectors * heads;

		/* Copy the partition table */
		memcpy(bootiso + 0x1BE, bootiso + isohybrid + 0x1BE, 66);
	}

	/* Install iso2exe boot sector */
	WORD(bootiso + 26) = rand();

	/* read tazlito flavor data */
	lseek(fd, 1024UL, SEEK_SET);
	read(fd, tazlitoinfo, sizeof(tazlitoinfo));

	/* Update iso image */
	n = (bootiso[69] + 1) * 512;
	lseek(fd, 0UL, SEEK_SET);
	write(fd, bootiso, n); /* EXE/PE + isohybrid mbr */
	write(fd, tazlitoinfo, ((0x8000U - BOOTISOSZ) > sizeof(tazlitoinfo)) 
		? sizeof(tazlitoinfo) : (0x8000U - BOOTISOSZ));
	write(fd, bootiso + n, BOOTISOSZ - n); /* COM + rootfs + EXE/DOS */

	/* Compute the checksum */
	lseek(fd, 0UL, SEEK_SET);
	for (i = 66, n = 0, j = 0; j < 16; j++, i = 0) {
		if (read(fd, buffer, BUFFERSZ) != BUFFERSZ)
			goto nochksum;
		for (; i < BUFFERSZ; i += 2)
			n += WORD(buffer + i);
	}
	WORD(bootiso + 64) = -n;
	lseek(fd, 0UL, SEEK_SET);
	write(fd, bootiso, 512);
nochksum:
	close(fd);
	status = 0;
	return SUCCESSMSG;
}

int main(int argc, char *argv[])
{
	forced = (argc > 2);
	puts(bootiso + install(argv[1]));
	if (status > 1)
		puts(bootiso + FORCEMSG);
#ifdef WIN32
	Sleep(2000);
#endif
	return status;
}
