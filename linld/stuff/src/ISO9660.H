#ifndef __ISO9660_H
#define __ISO9660_H
extern char *isofilename;
extern unsigned long isofileofs, isofilesize;
extern unsigned short isofilemod;
extern int isofd;
extern int isoreset(char *name);
extern int isoopen(char *name);
extern int isoreaddir(int restart);
extern int isoread(char *data, unsigned size);
#define isolabel() do { isofileofs=0x8028; isofilesize=32; } while (0)
#endif
