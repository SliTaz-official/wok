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
#define ftruncate(a,b)
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

static int fd, forced, uninstall, status = 1;
static char *append, *initrd;
static char tazlitoinfo[0x8000U - BOOTISOSZ];
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

static unsigned long getcustomsector(void)
{
	readsector(16UL);
	return 16UL + LONG(buffer + 80);
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

//#define rotl32(x,n) (((x) << (n)) | ((x) >> (32 - (n))))
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
			//uint64_t t = total64 << 3;
			uint32_t *t = (uint32_t *) (&wbuffer[64 - 8]);
			/* wbuffer is suitably aligned for this */
			//*(uint64_t *) (&wbuffer[64 - 8]) = t;
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
			sectors = LONG(buffer + 80);
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

static void clear_config(unsigned i)
{
	for (;i % 512; i++) {
		/* clear custom config */
		write(fd, buffer + 2048, 2048);
	}
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
#ifdef __MSDOS__
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
			write(fd, buffer + n, 1024);
		}
		i = getcustomsector();
		lseek(fd, i * 2048UL, SEEK_SET);
		clear_config(i);
		ftruncate(fd, i * 2048UL);
		close(fd);
		status = 0;
		return UNINSTALLMSG;
	}

	if (append || initrd) {
		unsigned long pos = getcustomsector() * 2048UL;
		lseek(fd, pos, SEEK_SET);
		clear_config(pos);
		lseek(fd, pos, SEEK_SET);
		write(fd, "#!boot 00000000000000000000000000000000\n", 40);
		md5_begin();
		if (append) {
			writenhash("append=", 7);
			writenhash(append, strlen(append));
			writenhash("\n", 1);
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
				writenhash("initrd:", 7);
				i = number - p + sizeof(number);
				writenhash(p, i);
				lseek(data, 0UL, SEEK_SET);
				do {
					i = read(data, buffer, BUFFERSZ);
					if (i <= 0)
						break;
					if (i > end)
						i = end;
					writenhash(buffer, i);
					end -= i;
				} while (end != 0);
			}
			close(data);
		}
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
	}

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

int main(int argc, char *argv[])
{
	int i;
	char *s;
	
	while (argc > 2) {
		s = argv[1];
		if (*s != '-') break;
		while (*s == '-') s++;
		switch (*s | 0x20) {
		case 'a' : append=argv[2]; break;
		case 'i' : initrd=argv[2]; break;
		}
		argv += 2;
		argc -= 2;
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
