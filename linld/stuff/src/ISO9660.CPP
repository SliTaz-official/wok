#include "crtl.h"
#include "crtlx.h"
#include "iso9660.h"
#define __ROCKRIDGE

#if 1
#define setdirofs(to,sec)	(*(int*)((char*)&(to)+1) = *(int*)&(sec)<<(SECTORBITS-8))
#define cpydirofs(to,from)	(*(int*)((char*)&(to)+1) = *(int*)((char*)&(from)+1))
#else
#define setdirofs(to,sec)	(to = (sec)<<SECTORBITS)
#define cpydirofs(to,from)	((to) = (from))
#endif

int isoroot(void)
{
	static const unsigned long root = 16UL * 2048;
	struct isostate *x=&isostate;
	if (isoreadsector(&root) == -1 || strhead(x->buffer+1,"CD001") == -1) {
		//close(x->fd);
		return -1;
	}
	setdirofs(x->dirofs, (* (unsigned long *) (isostate.buffer + 0x9E)));
	x->dirsize = filesize2dirsize(* (unsigned long *) (isostate.buffer + 0xA6));
	return 0;
}

int isoreaddir(void)
{
	char *p;
#ifdef __ROCKRIDGE
	char *endname;
#endif
	struct isostate *x=&isostate;

	if (x->curdirsize == 0xFFFF) {
		x->curdirsize = x->dirsize;
		cpydirofs(x->curdirofs, x->dirofs);
		goto restarted;
	}
	if (x->curpos >= SECTORSZ || * (short *) (x->buffer + x->curpos) == 0) {
	restarted:
		if (x->curdirsize < DIRSECTORSZ) return -1;
		isoreadsector(&x->curdirofs);
		//x->curdirofs += SECTORSZ;
		*(int *)((char *) &x->curdirofs+1) += SECTORSZ/256;
		x->curdirsize -= DIRSECTORSZ;
		x->curpos = 0;
	}
	p = x->buffer; p += x->curpos;
	if ((x->entrysize = * (short *) p) == 0) {
		return -1;
	}
	x->fileofs = (* (unsigned long *) (p + 2)) << SECTORBITS;
	x->filesize = * (unsigned long *) (p + 10);
	x->filemod = 0x81ED; if (p[25] & 2) ((char *)&(x->filemod))[1] = 0x41;
	//x->filemod = (p[25] & 2) ? 0040755 : 0100755;
	//x->filemod = 0100755 - ((p[25] & (char)2) << 13);
#ifdef __ROCKRIDGE
	endname = NULL;
	// p += 34 + (p[32] & -2); ?
	p = x->buffer + 34 + ((p[32] + x->curpos) & -2);
	do {
		int len = p[2];
# if 0
		switch (* (short *) p) {
		case 0x5850: // PX
			x->filemod = * (short *) (p + 4);
			break;
		case 0x4D4E: // NM
# else
		if (* (short *) p == 0x4D4E) {
# endif
			x->filename = p + 5;
			endname = p + len;
		}
		p += len;
	} while (x->buffer + x->curpos + x->entrysize - 2 > p);
	if (endname)
		*endname = 0;
	else
#endif
	{
		p = x->buffer + 33; x->filename = p += x->curpos;
		p--;
		if (((* (short *) p) & 0xFEFF) -1 == 0) {
			x->filename = "..";
			if (--(* (short *) p) == 0)
				x->filename++;
		}
		else {
			p += *p; p--;
			if (* (short *) (p) != 0x313B) {
				p++; p++; // no ;1 to remove
			}
			if (p[-1] == '.') p--;
			*p = 0;
		}
	}
	x->curpos += x->entrysize;
	return 0;
}

//#define IS_DIR(x)( ((x) & ~0777) == 040000)
//#define IS_DIR(x)( (char)((x) >> 9) == (char)040)
//#define IS_DIR(x)( (*((char*) &x + 1) & (char)0776) == (char)0100)
#define IS_DIR(x)( (*((char*) &x + 1) & (char)0676) == (char)0)
int _isoopen(void)
{
//	char *name, *s, c;
//	char _64bits = cpuhaslm();
	struct isostate *x=&isostate;
#define name (x->filename2open)
#define c (x->c)
#define _64bits (x->_64bits)
	char *s;

	_64bits = cpuhaslm();
    do {
	for (s = (char *) x->filename2open; *s == '/' ; s++) {
		isoroot();
	}
  next:
	name = s;
	do s++; while (*s && *s != '/');
	c = *s; *s = 0;
	for (x->curdirsize = 0xFFFF; isoreaddir() != -1;) {
		const char *n = name;
#define i (x->tmp)
		i = x->filename;
		if (_64bits) {
			if (strhead(i, n) == -1) continue;
			n = "64";
			i += s - name; // strlen(name);
		}
		if (strcmp(i, n)) continue;
		*s++ = c;
		if (IS_DIR(x->filemod)) {
			cpydirofs(x->dirofs, x->fileofs);
			x->dirsize = filesize2dirsize(x->filesize);
			if (c) goto next;
		}
		isolseek(&x->fileofs);
		return 0;
	}
    } while ((_64bits ^= CPUMASKLM) == 0);
	return -1;
}
