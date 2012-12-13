#include <sys/types.h>
#include <fcntl.h>
#include <stdio.h>
#include "iso9660.h"
#define __ROCKRIDGE

char *isofilename;
unsigned long isofileofs, isofilesize;
unsigned short isofilemod;
int isofd;

#define SECTORSZ 2048
#define SECTORBITS 11
static char buffer[SECTORSZ];

static int readsector(unsigned long offset)
{
	return (lseek(isofd, offset, SEEK_SET) != -1
		    && read(isofd, buffer, SECTORSZ) == SECTORSZ);
}

int isoread(char *data, unsigned size)
{
	int get, n;
	
	if (size > isofilesize)
		size = isofilesize;
	if (lseek(isofd, isofileofs, SEEK_SET) == -1)
		return -1;
	for (get = size; get; get -= n, data += n) {
		n = read(isofd,data,get);
		if (n < 0)
			return n;
		if (n == 0)
			break;
		isofileofs += n;
		isofilesize -= n;
	}
	return size - get;
}

static unsigned long isodirofs, isodirsize;
int isoreset(char *name)
{
	if (name)
		isofd = open(name, O_RDONLY);
	if (!readsector(16UL * 2048) || strncmp(buffer+1,"CD001",5))
		return -1;
	isodirofs = * (unsigned long *) (buffer + 0x9E);
	isodirofs <<= SECTORBITS;
	isodirsize = * (unsigned long *) (buffer + 0xA6);
	return 0;
}

int isoreaddir(int restart)
{
	static unsigned long pos, dirofs, dirsize;
	static char dots[] = "..";
	int size, n;
#ifdef __ROCKRIDGE
	char *endname;
#endif

	if (restart) {
		dirofs = isodirofs;
		dirsize = isodirsize;
		pos = SECTORSZ;
	}
	if (pos >= SECTORSZ) {
		if (dirsize < SECTORSZ) return -1;
		readsector(dirofs);
		dirofs += SECTORSZ;
		dirsize -= SECTORSZ;
		pos = 0;
	}
	size = * (short *) (buffer + pos);
	if (size == 0)
		return -1;
	isofileofs = (* (unsigned long *) (buffer + pos + 2)) << SECTORBITS;
	isofilesize = * (unsigned long *) (buffer + pos + 10);
	isofilemod = (buffer[pos + 25] & 2) ? 0040755 : 0100755;
#ifdef __ROCKRIDGE
	endname = NULL;
	n = (buffer[pos + 32] + pos + 34) & -2;
	do {
		int len = buffer[n + 2];
		switch (* (short *) (buffer + n)) {
		case 0x4D4E: // NM
			isofilename = buffer + n + 5;
			endname = buffer + n + len;
			break;
		case 0x5850: // PX
			isofilemod = * (short *) (buffer + n + 4);
			break;
		}
		n += len;
	}
	while (n + 2 < pos + size);
	if (endname)
		*endname = 0;
	else
#endif
	{
		isofilename = buffer + pos + 33;
		switch (* (short *) (isofilename - 1)) {
		case 0x0101:
			isofilename = dots;
			break;
		case 0x0001:
			isofilename = dots + 1;
			break;
		default:
			n = isofilename[-1];
			if (* (short *) (isofilename + n - 2) == 0x313B)
				n -= 2; // remove ;1
			if (isofilename[n - 1] == '.') n--;
			isofilename[n] = 0;
		}
	}
	pos += size;
	return 0;
}

#define IS_DIR(x)( ((x) & ~0777) == 040000)
int isoopen(char *name)
{
	int restart;
	char *s, c;

	while (*name == '/') {
		name++;
		isoreset(NULL);
	}
	s = name;
	while (1) {
		while (*s && *s != '/') s++;
		c = *s;
		*s = 0;
		for (restart = 1; isoreaddir(restart) == 0; restart = 0) {
			if (strcmp(name, isofilename)) continue;
			if (IS_DIR(isofilemod)) {
				isodirofs = isofileofs;
				isodirsize = isofilesize;
				if (c) {
					*s++ = c;
					name = s;
					goto next;
				}
			}
			return 0;
		}
		return -1;
	  next: ;
	}
}
