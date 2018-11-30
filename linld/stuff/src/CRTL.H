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
extern char xfer_buf[4096];

void parse_cmdline();
extern _fastcall void strcatb(const char* a,const char* b);
extern _fastcall int strhead(const char* a,const char* head);
extern _fastcall int fileattr(const char* name);
//extern "C" int open(const char* name, int flags);
extern _fastcall int open(const char* name);
extern _fastcall int close(int fd);
extern _fastcall int read(int fd, void* data, int sz);
extern _fastcall long lseekcur(int fd, int where);
extern _fastcall int puts(const char* s);
extern pascal unsigned long strtol(const char *s);

// Extensions
#define cli() do { asm { cli } } while(0)
#define sti() do { asm { sti } } while(0)
#define int3() do { asm { db 0cch } } while(0)
#define nop() do { asm { db 90h } } while(0)
extern char no_exit;
extern _fastcall int die(const char* msg);
//extern "C" char* malloc_or_die(unsigned size);
//extern "C" unsigned long* malloc_bufv_or_die(struct image_himem *m);
extern _fastcall int malloc_or_die(unsigned size);
extern _fastcall int malloc_bufv_or_die(struct image_himem *m);
extern _fastcall void set_cmdline(const char *filename);
