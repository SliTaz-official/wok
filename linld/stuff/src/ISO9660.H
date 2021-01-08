#ifndef __ISO9660_H
#define __ISO9660_H
//typedef unsigned long dirsizetype;
//#define filesize2dirsize(x)	(x)
//#define DIRSECTORSZ	SECTORSZ
typedef short dirsizetype;
#define filesize2dirsize(x)	(*(dirsizetype *)((char *)&(x)+1))
#define DIRSECTORSZ	(SECTORSZ/256)
extern struct isostate {
	unsigned curpos;
	char *filename2open;
	int fd;
	unsigned short filemod;
	unsigned long fileofs;
	unsigned long filesize;
	unsigned long filepos;
	char *filename;
	dirsizetype curdirsize, dirsize;
typedef unsigned dirpagetype;
	dirpagetype dirpage;           
	unsigned long curdirofs;
	int entrysize;
	const char *tmp;
	char c;
	char _64bits;
#define SECTORSZ 2048
#define SECTORBITS 11
	char buffer[SECTORSZ+512];	// RR overflow
} isostate;
#define isofd isostate.fd
#define	isofileofs isostate.fileofs
#define	isofilesize isostate.filesize
#define	isofilemod isostate.filemod
#define	isofilename isostate.filename
extern _fastcall void isolseek(const unsigned long *offset);
extern _fastcall int isoreadsector(const unsigned long *offset);
extern int _isoopen(void);
extern int isoreaddir(void);
#define isolabel() do { isofileofs=0x8028; isofilesize=32; } while (0)
#define setiso(x) (isostate.fd = open(x))
#endif
