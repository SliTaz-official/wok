// This file is distributed under GPL
//
// Bare bones of C runtime library

#define MK_FP(seg,ofs) ((void _seg *)(seg) + (void near *)(ofs))
#define FP_SEG(fp)     ((unsigned) (void _seg*) (void far*)(fp))
#define FP_OFF(fp)     ((unsigned) (fp))

const unsigned MIN_STACK = 0x400;
const unsigned MAX_MALLOC = 0xF000;

const A_RDONLY    = 1;     // for fileattr()
const A_HIDDEN    = 2;
const A_SYSTEM    = 4;
const A_LABEL     = 8;
const A_DIRECTORY = 16;
const A_ARCHIVE   = 32;


const O_RDONLY = 0;     // for open()
const O_BINARY = 0;

const SEEK_SET = 0;     // for lseek()
const SEEK_CUR = 1;
const SEEK_END = 2;

extern char text_start; extern char text_end;
extern char data_start; extern char data_end;
extern char bss_start;  extern char bss_end;
extern char* heap_top;

extern int ximage_size, ximage_fd;

void parse_cmdline();
extern "C" char* strcpy(const char* a,const char* b);
extern "C" char* strcat(const char* a,const char* b);
extern "C" char* strcatb(const char* a,const char* b);
extern "C" int strhead(const char* a,const char* b);
extern "C" int fileattr(const char* name);
extern "C" int open(const char* name, int flags);
extern "C" int close(int fd);
extern "C" void exit(int n);
extern "C" void abort();
extern "C" int read(int fd, void* data, int sz);
extern "C" int write(int fd, const void* data, int sz);
extern "C" long lseek(int fd, long sz, int dir);
extern "C" void* malloc(unsigned sz);
extern "C" void puts(const char* s);
extern "C" void putsz(const char* s);
extern "C" unsigned long strtol(const char *s);

// Extensions
//static void barrier() {}
//static void cli() { asm { cli } }
//static void sti() { asm { sti } }
#define barrier() do {} while(0)
#define cli() do { asm { cli } } while(0)
#define sti() do { asm { sti } } while(0)
#define int3() do { asm { db 0cch } } while(0)
#define nop() do { asm { db 90h } } while(0)
extern char no_exit;
extern "C" int die(const char* msg);
extern "C" char* malloc_or_die(unsigned size);
extern "C" unsigned long* malloc_bufv_or_die(struct image_himem *m);
