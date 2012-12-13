#ifndef __LIBDOS_H
#define __LIBDOS_H
#undef  __SLEEP
# ifdef __MSDOS__
// extern void sleep(int seconds);
extern char *progname(void);
extern int chdir(char *path);
extern int chdirname(char *path);
# else
#define progname() argv[0]
#define chdirname(x) chdir(dirname(x))
# endif
#endif
