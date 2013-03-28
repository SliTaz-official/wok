#ifndef __BOOTLINUX_H
#define __BOOTLINUX_H
extern long loadkernel(void);
extern void loadinitrd(void);
extern void bootlinux(char *cmdline);
#endif
