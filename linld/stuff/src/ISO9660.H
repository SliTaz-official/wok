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
	unsigned long fileofs;
	unsigned long filesize;
	unsigned long filepos;
	dirsizetype dirsize;
typedef unsigned dirpagetype;
	dirpagetype dirpage;           
	dirsizetype curdirsize;
	unsigned long curdirofs;
	char *filename;
	char _64bits;
	char c;
	int entrysize;
	const char *tmp;
#define SECTORSZ 2048
#define SECTORBITS 11
} isostate;
#define isofd isostate.fd
#define	isofileofs isostate.fileofs
#define	isofilesize isostate.filesize
#define	isofilename isostate.filename
extern _fastcall void isolseek(const unsigned long *offset);
extern _fastcall int isoreadsector(const unsigned long *offset);
extern int _isoopen(void);
extern int isoreaddir(void);
#define isolabel() do { isofileofs=0x8028; isofilesize=32; } while (0)
#define setiso(x) (isostate.fd = open(x))
extern u8 buf2k[2048];
#endif
