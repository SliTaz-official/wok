#ifndef __LIBDOS_H
#define __LIBDOS_H
#undef  __SLEEP
# ifdef __MSDOS__
// extern void sleep(int seconds);
extern char *progname(void);
extern int chdir(char *path);
extern int chdirname(char *path);
extern void dosshutdown(void);
extern int versiondos;
extern int dosversion(void);
extern void copycmdline(char store[]);
# else
#define progname() (argv[0])
#define chdirname(x) chdir(dirname(x))
#define dosshutdown()
#define dosversion() (0)
#define copycmdline(x) { \
	int n; \
	char *s, *p; \
	for (n = 1, s = x; n < argc; n++, *s++ = ' ') \
		for (p = argv[n]; *p; *s++ = *p++); \
	*s = 0; \
}
# endif
#endif
