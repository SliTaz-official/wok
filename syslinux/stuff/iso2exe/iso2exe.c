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
#ifdef __MSDOS__
int ftruncate(int fd, long newsize)
{
	if (lseek(fd, newsize, SEEK_SET) != -1L)
		return write(fd, NULL, 0);
	return -1;
}
#endif
#ifdef __MINGW32__
#define ftruncate chsize
#endif
#if !defined(__MSDOS__) && !defined(WIN32)
#define O_BINARY 0
#endif
typedef unsigned char uint8_t;
typedef unsigned long uint32_t;
#include "iso2exe.h"

static int fd, forced, uninstall;
static unsigned status = 1;
static char *append, *initrd;
static char tazlitoinfo[0x8000U - BOOTISOSZ];
#define buffer tazlitoinfo
#define BUFFERSZ 2048
#define BYTE(n) * (unsigned char *)  (n)
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

static unsigned long getcustomsector(void)
{
	readsector(16UL);
	return LONG(buffer + 80);
}

static int skipmd5 = 0;
#define ALIGN1

typedef struct {
	uint32_t l;
	uint32_t h;
} uint64_t;
static uint8_t wbuffer[64]; /* always correctly aligned for uint64_t */
static uint64_t total64;    /* must be directly before hash[] */
static uint32_t hash[8];    /* 4 elements for md5, 5 for sha1, 8 for sha256 */

/* #define rotl32(x,n) (((x) << (n)) | ((x) >> (32 - (n)))) */
static uint32_t rotl32(uint32_t x, unsigned n)
{
	return (x << n) | (x >> (32 - n));
}

static void md5_process_block64(void);

/* Feed data through a temporary buffer.
 * The internal buffer remembers previous data until it has 64
 * bytes worth to pass on.
 */
static void common64_hash(const void *buffer, size_t len)
{
	unsigned bufpos = total64.l & 63;

	total64.l += len; if (total64.l < len) total64.h++;

	while (1) {
		unsigned remaining = 64 - bufpos;
		if (remaining > len)
			remaining = len;
		/* Copy data into aligned buffer */
		memcpy(wbuffer + bufpos, buffer, remaining);
		len -= remaining;
		buffer = (const char *)buffer + remaining;
		bufpos += remaining;
		/* clever way to do "if (bufpos != 64) break; ... ; bufpos = 0;" */
		bufpos -= 64;
		if (bufpos != 0)
			break;
		/* Buffer is filled up, process it */
		md5_process_block64();
		/*bufpos = 0; - already is */
	}
}

/* Process the remaining bytes in the buffer */
static void common64_end(void)
{
	unsigned bufpos = total64.l & 63;
	/* Pad the buffer to the next 64-byte boundary with 0x80,0,0,0... */
	wbuffer[bufpos++] = 0x80;

	/* This loop iterates either once or twice, no more, no less */
	while (1) {
		unsigned remaining = 64 - bufpos;
		memset(wbuffer + bufpos, 0, remaining);
		/* Do we have enough space for the length count? */
		if (remaining >= 8) {
			/* Store the 64-bit counter of bits in the buffer */
			/* uint64_t t = total64 << 3; */
			uint32_t *t = (uint32_t *) (&wbuffer[64 - 8]);
			/* wbuffer is suitably aligned for this */
			/* *(uint64_t *) (&wbuffer[64 - 8]) = t; */
			t[0] = total64.l << 3;
			t[1] = (total64.h << 3) | (total64.l >> 29);
		}
		md5_process_block64();
		if (remaining >= 8)
			break;
		bufpos = 0;
	}
}

/* These are the four functions used in the four steps of the MD5 algorithm
 * and defined in the RFC 1321.  The first function is a little bit optimized
 * (as found in Colin Plumbs public domain implementation).
 * #define FF(b, c, d) ((b & c) | (~b & d))
 */
#undef FF
#undef FG
#undef FH
#undef FI
#define FF(b, c, d) (d ^ (b & (c ^ d)))
#define FG(b, c, d) FF(d, b, c)
#define FH(b, c, d) (b ^ c ^ d)
#define FI(b, c, d) (c ^ (b | ~d))

/* Hash a single block, 64 bytes long and 4-byte aligned */
static void md5_process_block64(void)
{
	uint32_t *words = (void*) wbuffer;
	uint32_t A = hash[0];
	uint32_t B = hash[1];
	uint32_t C = hash[2];
	uint32_t D = hash[3];

	const uint32_t *pc;
	const char *pp;
	const char *ps;
	int i;
	uint32_t temp;


	pc = C_array;
	pp = P_array;
	ps = S_array - 4;

	for (i = 0; i < 64; i++) {
		if ((i & 0x0f) == 0)
			ps += 4;
		temp = A;
		switch (i >> 4) {
		case 0:
			temp += FF(B, C, D);
			break;
		case 1:
			temp += FG(B, C, D);
			break;
		case 2:
			temp += FH(B, C, D);
			break;
		case 3:
			temp += FI(B, C, D);
		}
		temp += words[(int) (*pp++)] + *pc++;
		temp = rotl32(temp, ps[i & 3]);
		temp += B;
		A = D;
		D = C;
		C = B;
		B = temp;
	}
	/* Add checksum to the starting values */
	hash[0] += A;
	hash[1] += B;
	hash[2] += C;
	hash[3] += D;

}
#undef FF
#undef FG
#undef FH
#undef FI

/* Initialize structure containing state of computation.
 * (RFC 1321, 3.3: Step 3)
 */
static void md5_begin(void)
{
	hash[0] = 0x67452301;
	hash[1] = 0xefcdab89;
	hash[2] = 0x98badcfe;
	hash[3] = 0x10325476;
	total64.l = total64.h = 0;
}

/* Used also for sha1 and sha256 */
#define md5_hash common64_hash

/* Process the remaining bytes in the buffer and put result from CTX
 * in first 16 bytes following RESBUF.  The result is always in little
 * endian byte order, so that a byte-wise output yields to the wanted
 * ASCII representation of the message digest.
 */
#define md5_end common64_end

static int writenhash(void *buffer, size_t len)
{
	md5_hash(buffer, len);
	return write(fd, buffer, len);
}

static void md5sum(void)
{
	unsigned long sectors = 0;
	int count;

	lseek(fd, 32768UL, SEEK_SET);

	md5_begin();
	while ((count = read(fd, buffer, BUFFERSZ)) > 0) {
		if (sectors == 0)
			sectors = LONG(buffer + 80) - 16UL;
		md5_hash(buffer, count);
		if (--sectors == 0)
			break;
	}

	if (count < 0)
		return;

	md5_end();

	lseek(fd, 32752UL, SEEK_SET);
	write(fd, hash, 16);
	memcpy(bootiso + BOOTISOSZ - 16, hash, 16);
}

static unsigned chksum(unsigned start, unsigned stop)
{
	unsigned i, n = 0;

	lseek(fd, 0UL /* (unsigned long) (start / BUFFERSZ) */, SEEK_SET);
	while (1) {
		if (read(fd, buffer, BUFFERSZ) != BUFFERSZ)
			return 0;
		for (i = start % BUFFERSZ; i < BUFFERSZ; i += 2, start += 2) {
			if (start >= stop)
				return - n;
			n += WORD(buffer + i);
		}
	}
}

static unsigned clear_config(unsigned i)
{
	for (;i % 512; i++) {
		/* clear custom config */
		write(fd, buffer + 2048, 2048);
	}
	return i;
}

static unsigned install(char *filename)
{
#define heads 64
#define sectors 32
#define partition (446+16)
#define trksz (512UL * heads * sectors)
	unsigned long size, catalog, lba;
	int cylinders, i, j, isohybrid;
	unsigned n;
	if (!filename)
		return USAGE;
	fd = open(filename,O_RDWR|O_BINARY);
	if (fd == -1)
		return OPENERR;

	if (uninstall) {
		struct { char check[sizeof(tazlitoinfo) - BUFFERSZ - 1024]; };
		readsector(0UL);
		n = BUFFERSZ;		/* fill with zeros */
		if (WORD(buffer) == 23117) {
			/* restore isolinux hybrid boot */
			readsector((unsigned long) buffer[417]);
			n = 0;		/* fill with hybrid boot */
		}
		lseek(fd, 0UL, SEEK_SET);
		for (i = 0; i < 32; i++, n = BUFFERSZ) {
			write(fd, buffer + n, BUFFERSZ);
		}
		lseek(fd, getcustomsector() << 11, SEEK_SET);
		i = clear_config(i);
		ftruncate(fd, i * 2048UL);
		close(fd);
		status = 0;
		return UNINSTALLMSG;
	}

	readsector(0UL);
	if (buffer[0] == 'M' && buffer[1] == 'Z') {
		if (forced == 0)
			return ALREADYEXEERR;
		n = (buffer[417] + 1) * 512;
		i = 0x8000 - 1024;
		if (i > sizeof(tazlitoinfo))
			i = sizeof(tazlitoinfo);
		if (lseek(fd, n, SEEK_SET) == -1 ||
		    read(fd, tazlitoinfo, sizeof(tazlitoinfo)) != sizeof(tazlitoinfo) ||
		    lseek(fd, 1024UL, SEEK_SET) == -1 ||
		    write(fd, tazlitoinfo, i) != i) {
			puts(bootiso+READSECTORERR);
			exit(1);
		}
	}

	do {
		/* Install hybridiso boot sector */
		readsector(17UL);
		status = ELTORITOERR;
		if (strncmp(buffer+7, bootiso+ELTORITOERR+ELTORITOOFS, 23))
			break;
		catalog = LONG(buffer + 71);
		readsector(catalog);
		status = CATALOGERR;
		if (LONG(buffer) != 1 || LONG(buffer + 30) != 0x88AA55UL)
			break;
		lba = LONG(buffer + 40);
		readsector(lba);
		status = HYBRIDERR;
		if (LONG(buffer + 64) != 1886961915UL)
			break;
		isohybrid = bootiso[417] * 512;
		LONG(bootiso + isohybrid + 432) = lba * 4;
		LONG(bootiso + isohybrid + 440) = rand();
		LONG(bootiso + isohybrid + partition) = 0x10080UL;
		WORD(bootiso + isohybrid + 510) = 0xAA55U;
#if 0
		size = lseek(fd, 0UL, SEEK_END);
		size += 0x000FFFFFUL;
		size &= 0xFFF00000UL;
#else
		for (size = 0x000FFFFFUL; /* 1M - 1 */
		     read(fd, tazlitoinfo, 1024) == 1024;
		     size += 1024);
		size &= 0xFFF00000UL; /* round */    
#endif
		cylinders = (size >> 20) - 1;
		bootiso[isohybrid + partition + 4] = 23; /* "Windows hidden IFS" */
		bootiso[isohybrid + partition + 5] = heads - 1;
		bootiso[isohybrid + partition + 6] = ((cylinders & 0x300) >> 2) + sectors;
		bootiso[isohybrid + partition + 7] = cylinders & 0xFF;
		LONG(bootiso + isohybrid + partition + 8) = 0;
		LONG(bootiso + isohybrid + partition + 12) = (size >> 9);

		/* Copy the partition table */
		memcpy(bootiso + 0x1BE, bootiso + isohybrid + 0x1BE, 66);
		status = 0;
	} while (0);

	if (forced == 0 && status)
		return status;

	status = 1;
	if (append || initrd) {
		unsigned long pos = getcustomsector() * 2048UL;
		lseek(fd, pos, SEEK_SET);
		clear_config(pos);
		lseek(fd, pos, SEEK_SET);
		write(fd, bootiso+CUSTOM_HEADER, 40);
		n = pos + 40;
		md5_begin();
		if (append) {
			i = strlen(append);
			writenhash(bootiso+CMDLINE_TAG, 7);
			writenhash(append, i);
			writenhash("\n", 1);
			n += i + 8;
		}
		if (initrd) {
			char number[16], *p;
			unsigned long end, x;
			int data = open(initrd,O_RDONLY|O_BINARY);
			if (data == -1)
				return OPENINITRDERR;
			for (end = 0;; end += i) {
				i = read(data, buffer, BUFFERSZ);
				if (i <= 0)
					break;
			}
			p = number + sizeof(number) -1;
			x = end; *p-- = '\n';
			do {
			     *p-- = '0' + (x % 10);
			     x /= 10;
			} while (x);
			if (*++p != '0') {
				writenhash(bootiso+INITRD_TAG, 7);
				i = number - p + sizeof(number);
				writenhash(p, i);
				n += i + 7;
				lseek(data, 0UL, SEEK_SET);
				do {
					i = read(data, buffer, BUFFERSZ);
					if (i <= 0)
						break;
					if (i > end)
						i = end;
					writenhash(buffer, i);
					n += i;
					end -= i;
				} while (end != 0);
			}
			close(data);
		}
		while (n & 0x000FFFFFUL) {
			unsigned long i = 0x100000UL - (n & 0x000FFFFFUL);
			if (i > BUFFERSZ)
				i = BUFFERSZ;
			i = write(fd, buffer + BUFFERSZ, i);
			if (i <= 0)
				break;
			n += i;
		}
		ftruncate(fd, n);
		md5_end();
		{
			static char h[] = "0123456789abcdef";
			char string[32], *s = string + 30;
			unsigned char *p = (void *) hash;

			lseek(fd, 7 + pos, SEEK_SET);
			for (p += 15; s >= string; p--, s -= 2) {
				s[1] = h[ *p & 15 ];
				s[0] = h[ *p >> 4 ];
			}
			write(fd, string, 32);
		}

		/* Update partition size */
		n = 1+((n - 1) >> 20);
		BYTE(bootiso + partition + 7) = 
		BYTE(bootiso + isohybrid + partition + 7) = n -1;
		LONG(bootiso + partition + 12) =
		LONG(bootiso + isohybrid + partition + 12) = n * 2048;
	}

	/* Install iso2exe boot sector */
	LONG(bootiso + 440) = time(NULL);

	/* read tazlito flavor data */
	lseek(fd, 1024UL, SEEK_SET);
	read(fd, tazlitoinfo, sizeof(tazlitoinfo));

	/* Update iso image */
	n = (bootiso[417] + 1) * 512;
	lseek(fd, 0UL, SEEK_SET);
	write(fd, bootiso, n); /* EXE/PE + isohybrid mbr */
	write(fd, tazlitoinfo, sizeof(tazlitoinfo));
	write(fd, bootiso + n, BOOTISOSZ - n); /* COM + rootfs + EXE/DOS */

	/* Compute the boot checksums */
	if (!skipmd5) {
		puts(bootiso + MD5MSG);
		md5sum();
		lseek(fd, 0UL, SEEK_SET);
		write(fd, bootiso, 512);
		n = WORD(bootiso + 2) - 512*(WORD(bootiso + 4) - 1);
		WORD(bootiso + 18) = chksum(0, (unsigned short) n) - 1;
	}
	lseek(fd, 0UL, SEEK_SET);
	write(fd, bootiso, 512);
	close(fd);
	status = 0;
	return SUCCESSMSG;
}

static unsigned short files[] = {
	WIN32_EXE,		/*  0 */
	SYSLINUX_MBR,		/*  1 */
	FLAVOR_INFO,		/*  2 */
	FLOPPY_BOOT,		/*  3 */
	ISOBOOT_COM,		/*  4 */
	ROOTFS_GZ,		/*  5 */
	DOSSTUB,		/*  6 */
	BOOT_MD5,		/*  7 */
	FS_ISO,			/*  8 */
	CUSTOM_MAGIC,		/*  9 */
	CUSTOM_APPEND,		/* 10 */
	CUSTOM_INITRD		/* 11 */
};

static long file_offset, file_size;
static void fileofs(int number)
{
	unsigned long i, c, stub;
	char *s;

	c = getcustomsector();
	readsector(0UL);
	i = 1024;
	if (WORD(buffer+1024) != 35615) i = 512 * (1 + BYTE(buffer+417));
	stub = WORD(buffer+20) - 0xC0;
	file_size = file_offset = 0;
	switch (files[number]) {
	case WIN32_EXE:		/* win32.exe */
		if (i != 1024) file_size = i - 512; break;
	case SYSLINUX_MBR:	/* syslinux.mbr */
		if (i != 1024) file_offset = i - 512;
		file_size = 512; break;
	case FLAVOR_INFO:	/* flavor.info */
		file_offset = i; file_size = 0; break;
	case FLOPPY_BOOT:	/* floppy.boot */
		file_size = BYTE(buffer+26)*512;
		file_offset = WORD(buffer+64) - 0xC0 - file_size; break;
	case ISOBOOT_COM:	/* isoboot.com */
		file_offset = WORD(buffer+64) - 0xC0;
		file_size = stub - WORD(buffer+24) - file_offset; break;
	case ROOTFS_GZ:		/* rootfs.gz */
		file_size = WORD(buffer+24);
		file_offset = stub - file_size; break;
	case DOSSTUB:		/* dosstub */
		file_offset = stub;
		file_size = 0x8000U - file_offset; break;
	case BOOT_MD5:		/* boot.md5 */
		file_offset = 0x7FF0U; file_size = 16; break;
	case FS_ISO:		/* fs.iso */
		file_offset = 0x8000U; file_size = 2048*c - file_offset; break;
	case CUSTOM_MAGIC:	/* custom.magic */
		readsector(c);
		if (!strncmp(buffer, bootiso+CUSTOM_HEADER, 6)) {
			file_size = 39; file_offset = 2048*c;
		}; break;
	case CUSTOM_APPEND:	/* custom.append */
		readsector(c);
		file_offset = 2048*c + 47; s = strstr(buffer, "append=");
		if (s) file_size = strchr(s,'\n') - s - 7;
		break;
	case CUSTOM_INITRD:	/* custom.initrd */
		readsector(c);
		s = strstr(buffer,"initrd:");
		if (!s) break;
		file_size = atoi(s + 7);
		s = strchr(s,'\n') + 1;
		file_offset = 2048*c + (s - buffer);
	}
}

static long heap = 0;
static void show_free(void)
{
	if (file_offset > heap && (file_offset - heap) > 16)
		printf(bootiso + FREE_FORMAT, file_offset - heap,
		       heap, file_offset);
}

static void list(void)
{
	int num;

	for (num = 0; num < sizeof(files)/sizeof(files[0]); num++) {
		fileofs(num);
		if (file_size <= 0 || file_offset > 0x3FFFFFFFUL) continue;
		readsector(file_offset / 2048);
		if (WORD(buffer + file_offset % 2048) == 0) continue;
		show_free();
		if (file_offset >= heap) heap = file_offset + file_size;
		printf(bootiso + USED_FORMAT, bootiso + files[num],
			 file_offset, file_size);
	}
#ifdef  __MSDOS__
	file_offset = (heap + 0xFFFFFUL) & 0xFFF00000UL;
#else
	file_offset=lseek(fd, 0UL, SEEK_END);
#endif
	show_free();
}

static void extract(char *name)
{
	int num;

	for (num = sizeof(files)/sizeof(files[0]) - 1;
	     strcmp(name,bootiso + files[num]); num--) if (num <= 0) return;
	fileofs(num);
	if (file_size == 0) return;
	lseek(fd, file_offset, SEEK_SET);
	num = open(name, O_WRONLY|O_BINARY|O_CREAT, 0x644);
	while (file_size > 0) {
		int n = read(fd, buffer, BUFFERSZ);
		if (n <= 0) break;
		if (n > file_size) n = file_size;
		write(num,buffer,n);
		file_size -= n;
	}
	close(num);
}

int main(int argc, char *argv[])
{
	int i;
	char *s;
	
	data_fixup();
	for (i = 0; argc > 2;) {
		s = argv[1];
		if (*s != '-') break;
		while (*s == '-') s++;
		switch (*s | 0x20) {
		case 'a' : append=argv[2]; break;
		case 'i' : initrd=argv[2]; break;
		case 'r' : case 'l' :
			i++; argv++; argc--; continue;
		}
		argv += 2;
		argc -= 2;
	}
	if (i != 0) {
		fd = open(argv[i],O_RDONLY|O_BINARY);
		if (fd == -1) puts(bootiso + OPENERR);
		else if (argc <= 2) list();
		else for (i = 2; i < argc; i++) extract(argv[i]);
		return 0;
	}
	for (i = 2; i < argc; i++) {
		char *s = argv[i];
		while ((unsigned)(*s - '-') <= ('/' - '-')) s++;
		switch (*s | 0x20) {
		case 'f' : forced++; break;
		case 'q' : skipmd5++; break;
		case 'u' : uninstall++; break;
		}
	}
	puts(bootiso + install(argv[1]));
	if (status > 1)
		puts(bootiso + FORCEMSG);
#ifdef WIN32
	Sleep(2000);
#endif
	return status;
}
