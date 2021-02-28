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
	setdirpage(x->dirpage, (* (unsigned long *) (isostate.buffer + 0x9E))); \
	x->dirsize = filesize2dirsize(* (unsigned long *) (isostate.buffer + 0xA6)); \
}

#if !defined(BASIC_ISO9660) && !defined(ROCKRIDGE)
#define  ROCKRIDGE
#endif
static int isoreaddir(void)
{
	char *p;

	struct isostate *x=&isostate;

	p = x->buffer;
	if (x->curpos >= SECTORSZ || * (short *) (p + x->curpos) == 0) {
		if ((x->curdirsize =- DIRSECTORSZ) < 0) return -1;
		isoreadsector(&x->curdirofs);	// x->filepos = 0
		//x->curdirofs += SECTORSZ;
		*(int *)((char *) &x->curdirofs+1) += SECTORSZ/256;
		x->curpos = 0;
	}
	p += x->curpos;
	x->fileofs = (* (unsigned long *) (p + 2)) << SECTORBITS;
	if ((x->entrysize = * (short *) p) == 0) {
		return -1;
	}
	// x->filename = "";
	x->filesize = * (unsigned long *) (p + 10);
	x->filemod = 0x81ED; if (p[25] & 2) ((char *)&(x->filemod))[1] = 0x41;
	p = x->buffer + 34 + ((p[32] + x->curpos) & -2);
	x->curpos += x->entrysize;
#ifdef ROCKRIDGE
	do {
		register len = p[2];
		if (* (short *) p == 0x4D4E) {
			x->filename = p + 5;
			p[len] = 0;
			goto found;
		}
		p += len;
	} while (x->buffer + x->curpos - 3 >= p);
#endif
#ifdef BASIC_ISO9660
	char *s;
	p = x->buffer + 33; p += x->curpos;
	s = ".."+1-p[0];
	p--;
	if (((* (short *) p) & 0xFEFF) -1 != 0) {
		s = p + 1; p += *p;
		if (* (short *) (p-1) != 0x313B) p+=2; // no ;1 to remove
		if (*p != '.') p++;
		*p = 0;
	}
	x->filename = s;
#endif
found:
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

#ifdef ISOHOOK
	_64bits = cpuhaslm();
  _32bits:
#endif
	s = (char *) x->filename2open;
	if (*s == '/') {
		s++;
		isoroot();
		//if (strncmp(x->buffer+1,"CD001,5) == -1) return -1;
		//if (*(int*)(x->buffer+1) != 0x4443) return -1;
	}
  next:
	isoreaddir_reset();
	name = s;
	do s++; while (*s && *s != '/');
	c = *s; *s = 0;
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
	*s++ = c;
#define IS_DIR(x)( (*((char*) &x + 1) & (char)0676) == (char)0)
	if (IS_DIR(x->filemod)) {
		cpytodirpage(x->dirpage, x->fileofs);
		x->dirsize = filesize2dirsize(x->filesize);
		if (c) goto next;
	}
	isolseek(&x->fileofs);
	return x->fd;
}
#endif
