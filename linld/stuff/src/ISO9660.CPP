#include "crtl.h"
#include "common.h"
#include "iso9660.h"

#ifdef ISO9660
#define setdirpage(to,sec)	((to) = *(int*)&(sec)<<(SECTORBITS-8))
#define cpytodirpage(to,from)	((to) = *(int*)((char*)&(from)+1))
#define cpyfromdirpage(to,from)	(*(int*)((char*)&(to)+1) = (from))

#define isoroot() \
{ \
	extern void isoreadrootsector(void); \
	isoreadrootsector(); \
	setdirpage(x->dirpage, (* (unsigned long *) (buf2k + 0x9E))); \
	x->dirsize = filesize2dirsize(* (unsigned long *) (buf2k + 0xA6)); \
}

#if !defined(BASIC_ISO9660) && defined(CLEAN_ISO9660)
#define BASIC_ISO9660
#endif
#if !defined(BASIC_ISO9660) && !defined(ROCKRIDGE)
#define BASIC_ISO9660
#endif
static int isoreaddir(void)
{
	char *p;

	struct isostate *x=&isostate;

	p = buf2k;
	if (x->curpos >= SECTORSZ || * (short *) (p + x->curpos) == 0) {
		x->curpos = 0;
		if ((x->curdirsize =- DIRSECTORSZ) < 0) return -1;
		isoreadsector(&x->curdirofs);	// x->filepos = 0
		//x->curdirofs += SECTORSZ;
		*(int *)((char *) &x->curdirofs+1) += SECTORSZ/256;
	}
	p += x->curpos;
	x->fileofs = (* (unsigned long *) (p + 2)) << SECTORBITS;
	if ((x->entrysize = * (short *) p) == 0) {
		return -1;
	}
#ifdef CHECKISOFILETYPE
	x->c = p[25];
#endif
	register char *s;
	x->filesize = * (unsigned long *) (p + 10);
	s = ".."+1-p[33];
#ifdef ROCKRIDGE
	p = buf2k + 34 + ((p[32] + x->curpos) & -2);
	x->curpos += x->entrysize;
	do {
		register len = p[2];
		if (* (short *) p == 0x4D4E) {
			s = p + 5;
			p[len] = 0;
			goto found;
		}
		p += len;
	} while (buf2k - 3 + x->curpos >= p);
#endif
#ifdef BASIC_ISO9660
# ifdef ROCKRIDGE
	p = buf2k + 32 + x->curpos - x->entrysize;
# else
	x->curpos += x->entrysize;
	p += 32;
# endif
	if (((* (short *) p) & 0xFEFF) -1 != 0) {
		s = p + 1; p += *p;
# ifdef CLEAN_ISO9660
		if (* (short *) (p-1) == 0x313B) p-=2; // remove ;1
		if (*p != '.') p++;
# endif
		*p = 0;
	}
#endif
found:
	x->filename = s;
	return 0;
}

#define isoreaddir_reset() \
{ \
	x->curdirsize = x->dirsize; \
	cpyfromdirpage(x->curdirofs, x->dirpage); \
	x->curpos = -1; \
}

int _isoopen(void)
{
//	char *name, *s, c;
//	char _64bits = cpuhaslm();
	struct isostate *x=&isostate;
#define name (x->filename2open)
#define c (x->c)
#define _64bits (x->_64bits)
	char *s;

	s = (char *) x->filename2open;
	if (*s == '/') {
		isoroot();
		//if (strncmp(buf2k+1,"CD001",5) == -1) return -1;
		//if (*(int*)(buf2k+1) != 0x4443) return -1;
  next:
		s++;
	}
	name = s;
	do s++; while (*s && *s != '/');
	c = *s; *s = 0;
#ifdef ISOHOOK
	_64bits = cpuhaslm();
  _32bits:
#endif
	isoreaddir_reset();
	do {
		if (isoreaddir() == -1) {
#ifdef ISOHOOK
			if ((_64bits ^= CPUMASKLM) == 0) goto _32bits;
#endif
			return -1;
		}
		const char *n = name;
#define i (x->tmp)
		i = x->filename;
#ifdef ISOHOOK
		if (_64bits) {
			if (strhead(i, n) == -1) continue;
			n = "64";
			i += s - name; // strlen(name);
		}
#endif
		if (strcmp(i, n) != -1) break;
	} while (1);
	*s = c;
	if (c) {
#ifdef CHECKISOFILETYPE
		if ((x->c & 2) == 0) return -1;
#endif
		cpytodirpage(x->dirpage, x->fileofs);
		x->dirsize = filesize2dirsize(x->filesize);
		goto next;
	}
	isolseek(&x->fileofs);
	return x->fd;
}
#endif
