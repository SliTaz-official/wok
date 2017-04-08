// This file is distributed under GPL
//
#define NULL 0
extern "C" char* strcpy(const char* a,const char* b);
extern "C" char* strcat(const char* a,const char* b);
extern "C" int strcmp(const char* a,const char* b);
extern "C" int strlen(const char* s);
extern "C" char* strstr(const char* a,const char* b);
extern "C" char *progname(void);
extern "C" void chdirname(char *path);
extern "C" unsigned long kver2ul(char *kernel_version);
extern "C" char *ultoa(unsigned long n);
extern "C" void try_default_args();
extern char cpu_features[];
#define cpuhaslm() (cpu_features[3]&0x20)
