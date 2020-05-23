// This file is distributed under GPL
//
extern _fastcall long lseekset2(int fd, unsigned long* whence);
extern _fastcall void strcat(const char* a,const char* b);
extern _fastcall int strcmp(const char* a,const char* b);
//extern "C" char* strstr(const char* a,const char* b);
extern _fastcall int strstr(const char* a,const char* b);
extern _fastcall unsigned long kver2ul(char *kernel_version);
//extern "C" char *utoa(unsigned n);
extern _fastcall int utoa(unsigned n);
extern "C" void try_default_args();
