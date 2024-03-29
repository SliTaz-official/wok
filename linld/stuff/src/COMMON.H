//#define WITH_XMM_ALLOC	add himem.sys driver
//#define INT15_E820	add int15/eax=E820 driver
//#define LARGE_ZIMAGE	may load system in high memory temporarily 
#define CLEAN_ISO9660	remove ';1' or '.' trailers for  non rockridge name
#define BASIC_ISO9660	non rockridge support
#define ROCKRIDGE	iso 9660 posix name support
#define ISO9660		iso= support
#define QUICK_BOOT	/q bypass shutdown hack, /v keeps v86
#define ISOHOOK		iso image dos boot helper
#define MOVE_SETUP	spare few Kb in setup location for zImage system
#define NO386		8088 support
#define CPU64		/64 support
#define LONG_FILENAME	look for Win95+ long file name too
#define SHUTDOWN	disable int19 hooked drivers
#define VCPI		v86 mode support with VCPI 4.0+
#define LINUX001	linux 0.01 support
#define ELKS		elks support
#define IPXE		ipxe support
#define CPUTYPE		detect cpu family and model
#define MINRAM		detect RAM size
/* End of the optional features */

#ifdef ISOHOOK
#ifndef ROCKRIDGE
#define ROCKRIDGE
#endif
#ifndef CPU64
#define CPU64
#endif
#endif
#if defined(ROCKRIDGE) || defined(BASIC_ISO9660) || defined(CLEAN_ISO9660)
#ifndef ISO9660
#define ISO9660
#endif
#endif

// This file is distributed under GPL
//
// Common defs not belonging to CRTL

#if defined(__BORLANDC__) && !defined(NO386)
#pragma option -3
	asm{
		.386p
	}
#endif

#define NL "\n"
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
    u32 chunk_size;
    u16 state;
    u16 fd2close;
} imgs[2];
#define pm (imgs[0])
#define initrd (imgs[1])
#define pm2initrd(p) (p+1)

extern u8 pm_low;

extern u8 buf4k[4096];

extern u32 far *initrd_desc;
#ifdef ISO9660
#define CMDSTR_EXTRA	"|iso"
#else
#define CMDSTR_EXTRA	""
#endif
#define cmdline		(cmdstr[0])
#define kernel_name	(cmdstr[1])
#define initrd_name	(cmdstr[2])
#define isofile		(cmdstr[3])
extern const char* cmdstr[4];

#define root_dev	(cmdnum[0])
#define vid_mode	(cmdnum[1])	// -3 = ask, -2 = Extended VGA, -1 = Normal VGA,  n = as "n" was pressed
#define topmem		(cmdnum[2])
#define base_himem	(cmdnum[3])
#define CMDNUM	4
#define CMDNUM_EXTRA	""
extern u32 cmdnum[CMDNUM
#ifdef MINRAM
#define minram		(cmdnum[CMDNUM])
#undef CMDNUM_EXTRA
#define CMDNUM_EXTRA	"-r|"
#undef CMDNUM
#define CMDNUM		5
	+1
#endif
#ifdef CPUTYPE
#define mincpu		(* (short *) &cmdnum[CMDNUM])
#undef CMDNUM
#undef CMDNUM_EXTRA
# ifdef MINRAM
#define CMDNUM_EXTRA	"-r|-c|"
#define CMDNUM		6
# else
#define CMDNUM_EXTRA	"-c|"
#define CMDNUM		5
# endif
	+1
#endif
#ifdef QUICK_BOOT
#undef CMDNUM
#undef CMDNUM_EXTRA
# ifdef MINRAM
#  ifdef CPUTYPE
#   ifdef VCPI
#define CMDNUM_EXTRA	"-r|-c|-q~-v~"
#define CMDNUM		8
#   else
#define CMDNUM_EXTRA	"-r|-c|-q~"
#define CMDNUM		7
#   endif
#  else
#   ifdef VCPI
#define CMDNUM_EXTRA	"-r|-q~-v~"
#define CMDNUM		7
#   else
#define CMDNUM_EXTRA	"-r|-q~"
#define CMDNUM		6
#   endif
#  endif
# else
#  ifdef CPUTYPE
#   ifdef VCPI
#define CMDNUM_EXTRA	"-c|-q~-v~"
#define CMDNUM		7
#   else
#define CMDNUM_EXTRA	"-c|-q~"
#define CMDNUM		6
#   endif
#  else
#   ifdef VCPI
#define CMDNUM_EXTRA	"-q~-v~"
#define CMDNUM		6
#   else
#define CMDNUM_EXTRA	"-q~"
#define CMDNUM		5
#   endif
#  endif
# endif
# ifdef VCPI
	+2
# else
	+1
# endif
#endif
#ifdef WITH_XMM_ALLOC
	+1
#define	skip_alloc	(* (char *) &cmdnum[CMDNUM])
#endif
	];
#ifdef CPUTYPE
extern unsigned cputype;
#endif

extern _fastcall void memcpy_image_kernel();
extern _fastcall void memcpy_image_initrd();
extern _fastcall void storepage(u32 *dst);
extern _fastcall void reset_bufv(unsigned long *p);
extern "C" unsigned long* prev_bufv();
extern "C" unsigned long* next_bufv();
#define next(p)	 p = next_bufv()
#define prev(p)	 p = prev_bufv()
extern char vcpi;
extern char version_string[];
// External asm helpers
#ifdef	WITH_XMM_ALLOC
extern _fastcall void xmm_alloc(struct image_himem *m);
#endif
extern "C" u32 topload();
extern "C" u32 memtop();
extern "C" void enable_a20_or_die();
extern "C" void far vm2rm();
extern "C" void hook_int15_88();

// C++ helpers
#ifdef DEBUG
extern "C" void hang();
#endif

void load_image(struct image_himem *m);
extern _fastcall void open_image(struct image_himem *m, const char *name);
extern _fastcall int read_image(struct image_himem *m);
void load_kernel();
void load_initrd();
extern "C" void boot_kernel();
