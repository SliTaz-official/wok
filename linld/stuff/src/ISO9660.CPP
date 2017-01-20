#include "crtl.h"
#include "crtlx.h"
#include "iso9660.h"
#define __ROCKRIDGE

#define SECTORSZ 2048
#define SECTORBITS 11
static char buffer[SECTORSZ];
struct isostate isostate;

static int readsector(unsigned long offset)
{
	return (isolseek(offset) != -1
		    && read(isostate.fd, buffer, SECTORSZ) == SECTORSZ);
}

int isoread(char *data, unsigned size)
{
	int get, n;
	
	struct isostate *x=&isostate;
	if (isolseek(x->fileofs) == -1)
		return -1;
	if (size < x->filesize)
		size = x->filesize;
	for (get = size; get; get -= n, data += n) {
		n = read(x->fd,data,get);
		if (n < 0)
			return n;
		if (n == 0)
			break;
		x->fileofs += n;
		x->filesize -= n;
	}
	return size - get;
}

int isoreset(char *name)
{
	struct isostate *x=&isostate;
	if (name)
		//x->fd = open(name, O_RDONLY);
		x->fd = open(name);
	if (!readsector(16UL * 2048) || strhead(buffer+1,"CD001")) {
		//close(x->fd);
		return -1;
	}
	x->dirofs = * (unsigned long *) (buffer + 0x9E);
	x->dirofs <<= SECTORBITS;
	x->dirsize = * (unsigned long *) (buffer + 0xA6);
	return 0;
}

int isoreaddir(int restart)
{
	static char dots[] = "..";
	int size;
	char *p;
#ifdef __ROCKRIDGE
	char *endname;
#endif
	struct isostate *x=&isostate;

	if (restart) {
		x->curpos = SECTORSZ;
		x->curdirofs = x->dirofs;
		x->curdirsize = x->dirsize;
	}
	if (x->curpos >= SECTORSZ || * (short *) (buffer + x->curpos) == 0) {
		if (x->curdirsize < SECTORSZ) return -1;
		readsector(x->curdirofs);
		x->curdirofs += SECTORSZ;
		x->curdirsize -= SECTORSZ;
		x->curpos = 0;
	}
	p = buffer + x->curpos;
	size = * (short *) p;
	if (size == 0)
		return -1;
	x->fileofs = (* (unsigned long *) (p + 2)) << SECTORBITS;
	x->filesize = * (unsigned long *) (p + 10);
	x->filemod = (p[25] & 2) ? 0040755 : 0100755;
#ifdef __ROCKRIDGE
	endname = NULL;
	// p += 34 + (p[32] & -2); ?
	p = buffer + 34 + ((p[32] + x->curpos) & -2);
	do {
		int len = p[2];
		switch (* (short *) p) {
		case 0x4D4E: // NM
			x->filename = p + 5;
			endname = p + len;
			break;
		case 0x5850: // PX
			x->filemod = * (short *) (p + 4);
			break;
		}
		p += len;
	}
	while (buffer + x->curpos + size > p + 2);
	if (endname)
		*endname = 0;
	else
#endif
	{
		p = x->filename = buffer + x->curpos + 33;
		p--;
		switch (* (short *) p) {
		case 0x0101:
			x->filename = dots;
			break;
		case 0x0001:
			x->filename = dots + 1;
			break;
		default:
			p += *p; p--;
			if (* (short *) (p) != 0x313B) {
				p++; p++; // no ;1 to remove
			}
			if (p[-1] == '.') p--;
			*p = 0;
		}
	}
	x->curpos += size;
	return 0;
}

#define IS_DIR(x)( ((x) & ~0777) == 040000)
int isoopen(char *filename)
{
	int restart;
	char *name, *s;
	int _64bits = cpuhaslm();
	struct isostate *x=&isostate;

retry32:
	name = filename;
	while (*name == '/') {
		name++;
		isoreset(NULL);
	}
	s = name;
	while (1) {
		char c;
		while (*s && *s != '/') s++;
		c = *s;
		*s = 0;
		for (restart = 1; isoreaddir(restart) == 0; restart = 0) {
			const char *n = name, *i = x->filename;
			if (_64bits) {
				if (strhead(x->filename, name)) continue;
				n = "64";
				i += strlen(name);
			}
			if (strcmp(n, i)) continue;
			if (IS_DIR(x->filemod)) {
				x->dirofs = x->fileofs;
				x->dirsize = x->filesize;
				if (c) {
					*s++ = c;
					name = s;
					goto next;
				}
			}
			isolseek(x->fileofs);
			return 0;
		}
		if (_64bits) {
			_64bits = 0;
			*s = c;
			goto retry32;
		}
		return -1;
	  next: ;
	}
}
