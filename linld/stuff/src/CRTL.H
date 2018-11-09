// This file is distributed under GPL
//
// Bare bones of C runtime library

#define MK_FP(seg,ofs) ((void _seg *)(seg) + (void near *)(ofs))
#define FP_SEG(fp)     ((unsigned) (void _seg*) (void far*)(fp))
#define FP_OFF(fp)     ((unsigned) (fp))
#define NULL 0

const unsigned MIN_STACK = 0x400;
const unsigned MAX_MALLOC = 0xF000;

const char A_RDONLY    = 1;     // for fileattr()
const char A_HIDDEN    = 2;
const char A_SYSTEM    = 4;
const char A_LABEL     = 8;
const char A_DIRECTORY = 16;
const char A_ARCHIVE   = 32;


const char O_RDONLY = 0;     // for open()
const char O_BINARY = 0;

extern char text_start; extern char text_end;
extern char data_start; extern char data_end;
extern char bss_start;  extern char bss_end;
extern char* heap_top;

void parse_cmdline();
extern pascal void strcatb(const char* a,const char* b);
extern pascal int strhead(const char* a,const char* head);
extern pascal int fileattr(const char* name);
//extern "C" int open(const char* name, int flags);
extern pascal int open(const char* name);
extern pascal int close(int fd);
extern pascal int read(int fd, void* data, int sz);
extern pascal long lseekset(int fd, unsigned long sz);
extern pascal int puts(const char* s);
extern pascal unsigned long strtol(const char *s);

// Extensions
#define cli() do { asm { cli } } while(0)
#define sti() do { asm { sti } } while(0)
#define int3() do { asm { db 0cch } } while(0)
#define nop() do { asm { db 90h } } while(0)
extern char no_exit;
extern pascal int die(const char* msg);
//extern "C" char* malloc_or_die(unsigned size);
//extern "C" unsigned long* malloc_bufv_or_die(struct image_himem *m);
extern pascal int malloc_or_die(unsigned size);
extern pascal int malloc_bufv_or_die(struct image_himem *m);
extern pascal void set_cmdline(const char *filename);
