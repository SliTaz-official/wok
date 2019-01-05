// This file is distributed under GPL
//
extern _fastcall long lseekset2(int fd, unsigned long* whence);
extern _fastcall void strcpy(const char* a,const char* b);
extern _fastcall void strcat(const char* a,const char* b);
extern _fastcall int strcmp(const char* a,const char* b);
//extern "C" char* strstr(const char* a,const char* b);
extern _fastcall int strstr(const char* a,const char* b);
extern "C" char *progname(void);
extern _fastcall void chdirname(char *path);
extern _fastcall unsigned long kver2ul(char *kernel_version);
//extern "C" char *ultoa(unsigned long n);
extern _fastcall int ultoa(unsigned long n);
extern "C" void try_default_args();
extern char cpu_features[];
#define CPUMASKLM  (0x20)
#define cpuhaslm() (cpu_features[3]&CPUMASKLM)
