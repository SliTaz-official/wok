// This file is distributed under GPL
//
// Bare bones of C runtime library

#define MK_FP(seg,ofs) ((void _seg *)(seg) + (void near *)(ofs))
#define FP_SEG(fp)     ((unsigned) (void _seg*) (void far*)(fp))
#define FP_OFF(fp)     ((unsigned) (fp))
#define NULL 0

const unsigned MIN_STACK = 0x400;
const unsigned MAX_MALLOC = 0xF000;

const char O_RDONLY = 0;     // for open()
const char O_BINARY = 0;

extern char text_start; extern char text_end;
extern char data_start; extern char data_end;
extern char bss_start;  extern char bss_end;
extern char* heap_top;
extern char xfer_buf[4096];

void parse_cmdline();
extern _fastcall void strcatb(const char* a,const char* b);
extern _fastcall void strcpy(const char* a,const char* b);
#ifdef USE_ARGSTR
extern _fastcall int argstr(const char *s, const char keywords[], const char **var);
extern _fastcall int argnum(char *s, const char keywords[], unsigned long *var);
extern _fastcall void set_cmdline(const char *filename);
#define strhead(a,b)	(strstr(a,b) != (int) (a))
#else
extern _fastcall int strhead(const char* a,const char* head);
#endif
extern _fastcall int fileexist(const char* name);
//extern "C" int open(const char* name, int flags);
extern _fastcall int open(const char* name);
extern _fastcall int close(int fd);
extern _fastcall int moverm(unsigned short *p);
extern _fastcall int readrm(struct image_himem *m, int sz);
extern _fastcall int read(int fd, void* data, int sz);
extern _fastcall long lseekcur(int fd, int whence);
extern _fastcall int puts(const char* s);
extern _fastcall unsigned long strtol(const char *s);

// Extensions
#define cli() do { asm { cli } } while(0)
#define sti() do { asm { sti } } while(0)
#define int3() do { asm { db 0cch } } while(0)
#define nop() do { asm { db 90h } } while(0)
extern void exit();
extern _fastcall int die(const char* msg);
//extern "C" char* malloc_or_die(unsigned size);
//extern "C" unsigned long* malloc_bufv_or_die(struct image_himem *m);
extern _fastcall int malloc_or_die(unsigned size);
extern _fastcall int malloc_bufv_or_die(struct image_himem *m);
extern char cpu_features[];
#define CPUMASKLM  (0x20)
#define cpuhaslm() (cpu_features[3]&CPUMASKLM)
