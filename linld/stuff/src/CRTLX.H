// This file is distributed under GPL
//
#define NULL 0
extern "C" int strcmp(const char* a,const char* b);
extern "C" int strlen(const char* s);
extern "C" char* strstr(const char* a,const char* b);
extern "C" int cpuhaslm();
extern "C" char *progname(void);
extern "C" int chdir(char *path);
extern "C" int chdirname(char *path);
extern "C" unsigned long kver2ul(char *kernel_version);
extern "C" char *ultoa(unsigned long n);
