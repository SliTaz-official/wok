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

#ifdef ISOHOOK
void isoroot(void)
#else
int isoroot(void)
#endif
{
	static const unsigned long root = 16UL * 2048;
#ifdef ISOHOOK
	isoreadsector(&root);
	setdirofs(isostate.dirofs, (* (unsigned long *) (isostate.buffer + 0x9E)));
	isostate.dirsize = filesize2dirsize(* (unsigned long *) (isostate.buffer + 0xA6));
#else
	if (isoreadsector(&root) == -1 || strhead(isostate.buffer+1,"CD001") == -1) {
		//close(isostate.fd);
		return -1;
	}
	setdirofs(isostate.dirofs, (* (unsigned long *) (isostate.buffer + 0x9E)));
	isostate.dirsize = filesize2dirsize(* (unsigned long *) (isostate.buffer + 0xA6));
	return 0;
#endif
}

int isoreaddir(void)
{
	char *p;

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
	// p += 34 + (p[32] & -2); ?
	p = x->buffer + 34 + ((p[32] + x->curpos) & -2);
	do {
		register len = p[2];
		if (* (short *) p == 0x4D4E) {
			x->filename = p + 5;
			p[len] = 0;
			goto found;
		}
		p += len;
#ifndef ISOHOOK
	} while (x->buffer + x->curpos + x->entrysize - 2 > p);
#else
	} while (1);
#endif
#endif
#ifndef ISOHOOK
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
#endif
found:
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

#ifdef ISOHOOK
	extern int _cpuhaslm();
	_64bits = _cpuhaslm();
#else
	_64bits = cpuhaslm();
#endif
    do {
#ifdef ISOHOOK
	s = (char *) x->filename2open;
	if (*s == '/') {
		s++;
		isoroot();
	}
	name = s;
	while (*++s);
#else
	for (s = (char *) x->filename2open; *s == '/' ; s++) {
		isoroot();
	}
  next:
	name = s;
	do s++; while (*s && *s != '/');
	c = *s; *s = 0;
#endif
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
#ifndef ISOHOOK
		*s++ = c;
#endif
		if (IS_DIR(x->filemod)) {
			cpydirofs(x->dirofs, x->fileofs);
			x->dirsize = filesize2dirsize(x->filesize);
#ifndef ISOHOOK
			if (c) goto next;
#endif
		}
		isolseek(&x->fileofs);
		return 0;
	}
    } while ((_64bits ^= CPUMASKLM) == 0);
	return -1;
}
