// This file is distributed under GPL
//
// Common defs not belonging to CRTL

#define NL "\r\n"
#define VERSION_STR "0.97"

#if 0       // DEBUG
 #undef  NDEBUG
 #define DEBUG
 #define static
#else       // not DEBUG
 #define NDEBUG
 #undef  DEBUG
#endif

typedef unsigned long  u32; typedef signed long  s32;
typedef unsigned short u16; typedef signed short s16;
typedef unsigned char  u8;  typedef signed char  s8;

const u16 _16k = 16*1024u;
const u16 _32k = 32*1024u;
const u32 _64k = 64*1024ul;
const u32 _1m = 1024ul*1024ul;
const u32 _32m = 32*1024ul*1024ul;
const u32 _64m = 64*1024ul*1024ul;

const PAGE_BITS = 12;
const PAGE_SIZE = 1<<PAGE_BITS;
const PAGE_MASK = PAGE_SIZE-1;

// WARNING!
// BC 3.1 bug: seg() will generate incorrect code if inlined!
// replaced by _dirty_ hack for now
// u16 seg(const void far* p) { return FP_SEG(p); }
inline u16 seg(const void far*) { return _DS; }

inline u16 ofs(const void* p) { return FP_OFF(p); }

extern struct image_himem {
    int fd;
    u32 fallback;
    u32 size;
    u32 remaining;
    u32 buf;
    u32 *bufv;
    const char *errmsg;
    u32 chunk_size;
    void (*next_chunk)(struct image_himem *);
    u16 state;
    u16 fd2close;
} imgs[2];
#define pm (imgs[0])
#define initrd (imgs[1])

extern int skip_alloc;
extern u32 base_himem;

extern "C" void memcpy_image(struct image_himem *m);
extern "C" void storepage(u32 *dst, u16 src);
#ifdef LARGE_IMAGES
extern "C" void reset_bufv(unsigned long *p);
extern "C" unsigned long* prev_bufv();
extern "C" unsigned long* next_bufv();
#define next(p)	 p = next_bufv()
#define prev(p)	 p = prev_bufv()
#else
#define reset_bufv(p)
#define next(p)	 ++p
#define prev(p)	 --p
#endif
extern char vcpi;
extern const char* kernel_name;
extern const char* initrd_name;
extern const char* cmdline;
extern u16 root_dev;
extern u16 vid_mode;
// External asm helpers
extern "C" void memcpy32(u32, u16,u32, u32);
extern "C" void rmcpy();
extern "C" void xmm_alloc(struct image_himem *m);
extern u32 topmem;
extern "C" u32 memtopz();
extern "C" u32 memtop();
extern "C" void enable_a20_or_die();
extern "C" int get_vcpi_interface();
extern "C" char* prepare_vcpi(void *pagebuf);
//extern "C" int call_pm_routine(void* f);
extern "C" void memcpy_vcpi(u32 dstofs,u16 srcseg,u32 srcofs);
extern "C" void vm2rm();
extern "C" void hook_int15_88();

// C++ helpers
#ifdef DEBUG
extern "C" void hang();
#endif

void load_image(struct image_himem *m);
extern "C" void open_image(const char *name, struct image_himem *m);
extern "C" int read_image(struct image_himem *m, void* data, int sz);
char* load_kernel();
void load_initrd();
extern "C" void boot_kernel();
