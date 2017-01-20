#ifndef __ISO9660_H
#define __ISO9660_H
extern struct isostate {
	int fd;
	unsigned long fileofs;
	unsigned long filesize;
	unsigned short filemod;
	char *filename;
//private
	unsigned long dirofs, dirsize;
	unsigned long curdirofs, curdirsize;
	unsigned curpos;
} isostate;
#define isofd isostate.fd
#define	isofileofs isostate.fileofs
#define	isofilesize isostate.filesize
#define	isofilemod isostate.filemod
#define	isofilename isostate.filename
extern "C" unsigned long isolseek(unsigned long offset);
extern int isoreset(char *name);
extern int isoopen(char *name);
extern int isoreaddir(int restart);
extern int isoread(char *data, unsigned size);
#define isolabel() do { isofileofs=0x8028; isofilesize=32; } while (0)
#endif
