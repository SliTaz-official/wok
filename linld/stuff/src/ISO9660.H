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
#define SECTORSZ 2048
#define SECTORBITS 11
	char buffer[SECTORSZ+512];	// RR overflow
} isostate;
#define isofd isostate.fd
#define	isofileofs isostate.fileofs
#define	isofilesize isostate.filesize
#define	isofilemod isostate.filemod
#define	isofilename isostate.filename
extern pascal long isolseek(const unsigned long *offset);
extern pascal int isoreadsector(const unsigned long *offset);
extern int isoreset(char *name);
extern int isoopen(const char *name);
extern int isoreaddir(int restart);
#define isolabel() do { isofileofs=0x8028; isofilesize=32; } while (0)
#endif
