// This file is distributed under GPL
//
extern pascal void strcpy(const char* a,const char* b);
extern pascal void strcat(const char* a,const char* b);
extern pascal int strcmp(const char* a,const char* b);
//extern "C" char* strstr(const char* a,const char* b);
extern pascal int strstr(const char* a,const char* b);
extern "C" char *progname(void);
extern pascal void chdirname(char *path);
extern pascal unsigned long kver2ul(char *kernel_version);
//extern "C" char *ultoa(unsigned long n);
extern pascal int ultoa(unsigned long n);
extern "C" void try_default_args();
extern char cpu_features[];
#define CPUMASKLM  (0x20)
#define cpuhaslm() (cpu_features[3]&CPUMASKLM)
