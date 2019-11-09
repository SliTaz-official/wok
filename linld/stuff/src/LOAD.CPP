// This file is distributed under GPL

#include "crtl.h"
#include "common.h"

/***************
    Memory layout assumed by kernel boot process
    --------------------------------------------
    Note: claims that kernel setup is relocatable are
    still not 100% valid:
    bzImage decompressing trashes 10000-8ffff range,
    so rm loader -> pm kernel info is lost if it was here...
    So I had to stick to 90000.

10000000+------------------------+  <- 256m
        |  initrd                |      initrd is at top of mem, but
        |                        |      not higher than 256m
        +------------------------+
        +------------------------+
        |  bzImage               |      bzImage is at 1m
        |                        |      VCPI/XMS/64k offset tricks used...
00100000+------------------------+  <- 1m
        |  video, BIOS etc       |      Do not use.
000A0000+------------------------+
        |  Reserved for BIOS     |      Do not use.  Reserved for BIOS EBDA.
0009A000+------------------------+  <- stack top for kernel rm code
        |  Cmdline               |
00098000+------------------------+  <- heap top for kernel rm code
        |  Kernel setup          |      The kernel real-mode code.
00090200+------------------------+
        |  Kernel boot sector    |      The kernel legacy boot sector.
00090000+------------------------+
        |  Zapped by ungzip      |      Historically zImages were loaded here
        | (zImage once was here) |      bzImages use this space for ungzipping
00010000+------------------------+
        |  Boot loader           |  <- Boot sector entry point 0000:7C00
00001000+------------------------+
        |  Reserved for MBR/BIOS |
00000800+------------------------+
        |  Typically used by MBR |
00000600+------------------------+
        |  BIOS use only         |
00000000+------------------------+
*/

struct kernelparams_t {
    s8      setup_sects;    // 01F1 The size of the setup in sectors
                            //      boot sector is NOT included here
    u16     ro_flag;        // 01F2 If set, the root is mounted readonly
    u16     syssize;        // 01F4 DO NOT USE - for bootsect.S use only:
                            //      size of pm part of kernel
                            //      (in 16 byte units, rounded up)
    u16     swap_dev;       // 01F6 DO NOT USE - obsolete
    u16     ram_size;       // 01F8 DO NOT USE - for bootsect.S use only:
                            //      if nonzero then kernel
                            //      (driver/block/ramdisk.c: rd_load())
                            //      will try to load the contents for the ramdisk
                            //      from the "root_dev" which MUST then have the
                            //      floppyMAJOR
                            //      The file-system on that floppy must be MINIX
                            //      If rd_load() succeeds it sets the root_dev
                            //      to the ramdisk for mounting it
    u16     vid_mode;       // 01FA Video mode control
    u16     root_dev;       // 01FC Default root device number
    u16     boot_flag;      // 01FE 0xAA55 magic number
    u16     jump;           // 0200 Jump instruction
    u32     header;         // 0202 Magic signature "HdrS"
    u16     version;        // 0206 Boot protocol version supported
    u16     realmode_switch_ofs; // 0208 Hook called just before rm->pm
    u16     realmode_switch_seg;
    u16     start_sys_seg;  // 020E
    u16     kernel_version; // 020C Points to kernel version string
    u8      type_of_loader; // 0210 Boot loader identifier
    u8      loadflags;      // 0211 Boot protocol option flags
    u16     setup_move_size;// 0212 Move to high memory size (used with hooks)
    u32     code32_start;   // 0214 Boot loader hook (see below)
    u32     initrd_buf;     // 0218 initrd load address (set by boot loader)
    u32     initrd_size;    // 021C initrd size (set by boot loader)
    u32     bootsect_kludge;// 0220 DO NOT USE - for bootsect.S use only
    u16     heap_end_ptr;   // 0224 Free memory after setup end
    u16     pad1;           // 0226 Unused
    u32     cmd_line_ptr;   // 0228 32-bit pointer to the kernel command line
    u8      pad30[0x400-0x22c]; // 022C
                            // 02D0 up to 32 20-byte mem info structs from
                            // int 0x15 fn 0xe820
}; //__attribute((packed));

struct first1k_t {
                            // these two set by rm setup:
    u16     curr_curs;      // 0000 saved cursor position
    u16     ext_mem_size;   // 0002 extended memory size in Kb (from int 0x15 fn 0x88)
    u8      pad00[0x20-4];
                            // old-style cmdline (not used in LINLD (yet?))
    u32     cl_magic_ofs;
    //u16     cl_magic;       // 0020 commandline magic number (=0xA33F)
    //u16     cl_ofs;         // 0022 commandline offset
    u8      pad10[0x80-0x24];
                            // these two set by rm setup:
    u8      hd0_disk_par[16]; // 0080 hd0-disk-parameter from intvector 0x41
    u8      hd1_disk_par[16]; // 0090 hd1-disk-parameter from intvector 0x46
    u8      pad20[0x01e0-0xa0];
                            // this is set by rm setup:
    u32     alt_mem_size;   // 01E0 extended memory size in Kb (from int 0x15 fn 0xe801)
    u8      pad28[0x01f1-0x1e4];
    struct kernelparams_t params;
}; //__attribute((packed));

#if sizeof(first1k_t)!=0x400
#error BUG: Bad first1k
#endif

const u32 HdrS = 'H' + ('d'<<8) + (u32('r')<<16) + (u32('S')<<24);

// register value to launch the kernel real mode code
u32 csip;
#ifdef NO386
extern "C" u16 topseg();
#else
#define topseg() 0x9000
#endif
static u16 rm_size;
static u8* rm_buf;	// @ = @rm_size + 2, see A20.ASM
struct image_himem imgs[2];

static const char kernel_file_error[] = "Can't use kernel file";
void load_kernel() {

    struct	image_himem *m = &pm;
#define _rm_buf(m)	(((u8**)(m))[-1])
#define _rm_size	(((u16*)(m))[-2])
#define _csip		(((u32*)(m))[-2])
  {
    struct kernelparams_t *kernelparams;
    kernelparams = &(((first1k_t*) (_rm_buf(m) = (u8 *)heap_top))->params);
#define first1k		((first1k_t*)((u8 *)kernelparams-0x1F1))

    *((u16 *)&_csip+1)=topseg()|0x20;
    // Open kernel, read first kb, check it
    m->errmsg = kernel_file_error;
    open_image(m, kernel_name);

do {
 if (readrm(m, 0x200) == 0x200) {

    lseekcur(m->fd,-0x200);
    if(kernelparams->setup_sects == 0) {
#if 1
        if(* (int *) &first1k->pad10[0x3F-0x24] == 0x3AE8) {
            _csip+=0xFFE00042;
        }
        else
#endif
        kernelparams->setup_sects=4;
    }
    if((kernelparams->setup_sects)>=(_32k/512) || // 0th sector not counted
	 kernelparams->boot_flag != 0xAA55)
        die("Not a kernel");
    _rm_size=0x200*(kernelparams->setup_sects+1);
    m->size -= _rm_size;
    m->chunk_size -= _rm_size;

    // Read remaining rm loader
    if (readrm(m, _rm_size) == _rm_size) break;
 }
        die(kernel_file_error);
} while (0);

    // Tell rm loader some info

    if((int)vid_mode) kernelparams->vid_mode = vid_mode;
    if((int)root_dev) kernelparams->root_dev = root_dev;

    if(kernelparams->header == HdrS) { // starting linux 1.3.73
	if(kernelparams->loadflags & 1) { // zImage as pre 1.3.73
	    extern void far last_ditch();
	    kernelparams->realmode_switch_ofs = (u16) last_ditch;
	    kernelparams->realmode_switch_seg = _CS;
	    m->fallback = base_himem;
            pm_high++;

            // Hook on int15 to work around fn 88 DOS breakage
            hook_int15_88(); // break _ES
        }
        if (kernelparams->kernel_version)
            strcpy(version_string,(char *) first1k+kernelparams->kernel_version+0x200);
        kernelparams->type_of_loader = 0xff; // kernel do not know us (yet :-)
        if(kernelparams->version >= 0x201) {
            // * offset limit of the setup heap
            //   heap_end_ptr appears to be relative to the start of setup (ofs 0x0200)
            kernelparams->heap_end_ptr = _32k-0x0200;
            kernelparams->loadflags |= 0x80; // says to rm loader it's ok to use heap
            // * if we will ever stop moving ourself to 0x90000
            //   we must say setup.S how much to move
            //kernelparams->setup_move_size = _32k;
            if(kernelparams->version >= 0x202) { // starting linux 2.4.0-test3-pre3
                kernelparams->cmd_line_ptr = (((u32)(topseg()+0x0800))<<4);
                goto cmd_line_ok;
            }
        }
    }
    first1k->cl_magic_ofs = 0x8000A33F;
  }

cmd_line_ok:

    // Move setup & Check and enable A20 if needed
    moverm(m); // break _ES

    // Read remaining kernel (pm part)
    // Try to load kernel high, maybe even blindly storing it
    // in unallocated memory as a last resort

    load_image(m);
}

// Read initrd if needed
void load_initrd() {
    struct image_himem *m = &initrd;
    if (((int)initrd_name | m->fd) == 0) return; // !initrd_name && !m->fd
#if defined(__BORLANDC__) && defined(NO386)
#pragma option -3
    asm{
	.386p
    }
#endif
    m->errmsg = "Can't use initrd file";

    open_image(m, initrd_name);

    if ((m->fallback=(memtop()-m->size)&(~PAGE_MASK))-m[-1].fallback < m[-1].size) {
        close(m->fd);
        puts(m->errmsg);
        return;
    }

    load_image(m);

    if (*version_string) {
        initrd_desc[0] = m->fallback;
        initrd_desc[1] = m->size;
    }
}
