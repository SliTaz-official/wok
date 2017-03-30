#ifndef __ISO9660_H
#define __ISO9660_H
//typedef unsigned long dirsizetype;
//#define filesize2dirsize(x)	(x)
//#define DIRSECTORSZ	SECTORSZ
typedef unsigned dirsizetype;
#define filesize2dirsize(x)	(*(unsigned *)((char *)&(x)+1))
#define DIRSECTORSZ	(SECTORSZ/256)
extern struct isostate {
	int fd;
	unsigned short filemod;
	unsigned long fileofs;
	unsigned long filesize;
	char *filename;
//private
	dirsizetype curdirsize, dirsize;
	unsigned long curdirofs, dirofs;
	unsigned curpos;
} isostate;
#define isofd isostate.fd
#define	isofileofs isostate.fileofs
#define	isofilesize isostate.filesize
#define	isofilemod isostate.filemod
#define	isofilename isostate.filename
extern "C" unsigned long isolseek(const unsigned long *offset);
extern int isoreset(char *name);
extern int isoopen(const char *name);
extern int isoreaddir(int restart);
#define isolabel() do { isofileofs=0x8028; isofilesize=32; } while (0)
#endif
