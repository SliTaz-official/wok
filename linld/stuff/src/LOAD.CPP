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

struct first1k_t {
                            // these two set by rm setup:
    u16     curr_curs;      // 0000 saved cursor position
    u16     ext_mem_size;   // 0002 extended memory size in Kb (from int 0x15 fn 0x88)
    u8      pad00[0x20-4];
                            // old-style cmdline (not used in LINLD (yet?))
    u16     cl_magic;       // 0020 commandline magic number (=0xA33F)
    u16     cl_ofs;         // 0022 commandline offset
    u8      pad10[0x80-0x24];
                            // these two set by rm setup:
    u8      hd0_disk_par[16]; // 0080 hd0-disk-parameter from intvector 0x41
    u8      hd1_disk_par[16]; // 0090 hd1-disk-parameter from intvector 0x46
    u8      pad20[0x01e0-0xa0];
                            // this is set by rm setup:
    u32     alt_mem_size;   // 01E0 extended memory size in Kb (from int 0x15 fn 0xe801)
    u8      pad28[0x01f1-0x1e4];

    u8      setup_sects;    // 01F1 The size of the setup in sectors
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

#if sizeof(first1k_t)!=0x400
#error BUG: Bad first1k
#endif

const u32 HdrS = 'H' + ('d'<<8) + (u32('r')<<16) + (u32('S')<<24);

u8* rm_buf;
static u16 rm_size;
u8 pm_high;
struct image_himem pm;
struct image_himem initrd;

static void memcpy_image(struct image_himem *m) {
    if (m->fallback != m->buf)
        memcpy32(
            0, m->fallback, // dst seg,ofs
            0, m->buf,      // src seg,ofs
            m->size         // size
        );
}

// Called from inside kernel just before rm->pm
// _loadds _saveregs: done by hand
void far last_ditch() {
    cli();  // we start doing *really* destructive things to DOS/BIOS
            // it means: do not even try to enable ints
            // or call BIOS services after this
    asm {
        push    ds
        push    cs
        pop     ds
#ifndef NO386
        pusha
#else
        push	ax
        push	bx
        push	cx
        push	dx
#endif
    }
    if(pm.fallback > _1m) pm.fallback = _1m;
    if(vcpi==0) {
        // Move kernel
        memcpy_image(&pm);
        // Move initrd
        memcpy_image(&initrd);
    } else { //vcpi
        vm2rm();
        // Move kernel
        // 'Gathering' copy in chunks of PAGE_SIZE
        // No risk of overlapping: kernel is copied from above to 1m mark
        pm.size = PAGE_SIZE;
        u32 *p = pm.bufv;
        if (p) while(*p) {
            pm.buf = *p;
            memcpy_image(&pm);
            p++; pm.fallback+=PAGE_SIZE;
        }
        // Move initrd
        if(initrd.fallback) {
            // This is tricky: copy initrd backwards to reduce
            // risk of overlapping: use the fact that initrd is copied
            // to the very top of ram
            // (overlapping still can happen with more than 256mb ram)
            // (generic solution for this overwrite problem, anyone?)
            p=initrd.bufv;
            initrd.size = PAGE_SIZE;
            do {
                p++; initrd.fallback+=PAGE_SIZE;
            } while(*p);
            do {
                p--; initrd.fallback-=PAGE_SIZE;
                initrd.buf = *p;
                memcpy_image(&initrd);
            } while(p != initrd.bufv);
        }
    }
    asm {
#ifndef NO386
        popa
#else
        pop	dx
        pop	cx
        pop	bx
        pop	ax
#endif
        pop     ds
    }
}

// register value to launch the kernel real mode code
#ifdef NO386
static u32 sssp;
static u32 csip;
extern "C" u16 topseg();
#else
const  u32 sssp=0x9000A000;
static u32 csip=0x90200000;
#define topseg() 0x9000
#endif

static const char kernel_file_error[] = "Can't use kernel file";
char* load_kernel() {

#ifdef NO386
    sssp=((u32)topseg()<<16)+0xA000;
    csip=((u32)(topseg()+0x20)<<16);
#endif
    // Open kernel, read first kb, check it
    pm.errmsg = kernel_file_error;
    open_image(kernel_name, &pm);

    char *version_string;
  {
    struct first1k_t *first1k;
    first1k = (first1k_t*) (rm_buf = malloc_or_die(_32k));
   {
    u16 rm_seek;

    // Do not use malloc below until heap_top adjustment (see <*>)
    if (read(pm.fd, rm_buf, rm_seek=0x400) != 0x400) {
  readfail:
        die(kernel_file_error);
    }

    if(!first1k->setup_sects) {
#if 1
        if(* (int *) &first1k->pad10[0x3F-0x24] == 0x3AE8) {
            lseek(pm.fd,rm_seek=0x200,SEEK_SET);
            csip=((u32)topseg()<<16)+0x0042;
        }
        else
#endif
        first1k->setup_sects=4;
    }
    rm_size = 0x200*(first1k->setup_sects+1); // 0th sector is not counted there
    if(rm_size>_32k || first1k->boot_flag != 0xAA55)
        die("It's not a kernel");
    heap_top = rm_buf+rm_size;  // <*>

    // Read remaining rm loader

    {
    u16 cnt = rm_size-rm_seek;
    if (read(pm.fd, rm_buf+rm_seek, cnt) != cnt) goto readfail;
    }
   }

    // Tell rm loader some info

    if(vid_mode) first1k->vid_mode = vid_mode;
    if(root_dev) first1k->root_dev = root_dev;
    version_string = 0;

#if 1
    if(first1k->header == HdrS) { // starting linux 1.3.73
	if(first1k->loadflags & 1) {
#else
    if((first1k->header != HdrS) || (first1k->loadflags & 1) == 0)
        die("I can't load bzImage low");
    {
        {
#endif
            pm_high++;

            // Hook on int15 to work around fn 88 DOS breakage
            hook_int15_88();

            // * will be called just before rm -> pm
            first1k->realmode_switch_ofs = ofs(last_ditch);
            first1k->realmode_switch_seg = seg(last_ditch);
        }
        if(first1k->kernel_version)
            version_string = (char *) first1k+first1k->kernel_version+0x200;
        first1k->type_of_loader = 0xff; // kernel do not know us (yet :-)
        if(first1k->version >= 0x201) {
            // * offset limit of the setup heap
            //   heap_end_ptr appears to be relative to the start of setup (ofs 0x0200)
            first1k->heap_end_ptr = _32k-0x0200;
            first1k->loadflags |= 0x80; // says to rm loader it's ok to use heap
        }
        // * if we will ever stop moving ourself to 0x90000
        //   we must say setup.S how much to move
        //first1k->setup_move_size = _32k;
        if(first1k->version >= 0x202) { // starting linux 2.4.0-test3-pre3
            first1k->cmd_line_ptr = (((u32)(topseg()+0x0800))<<4);
            goto cmd_line_ok;
        }
    }
    first1k->cl_magic = 0xA33F;
    first1k->cl_ofs   = 0x8000;
  }

cmd_line_ok:
    // Check and enable A20 if needed
    enable_a20_or_die();

    // Read remaining kernel (pm part)
    // Try to load kernel high, maybe even blindly storing it
    // in unallocated memory as a last resort

    pm.fallback = (u32((u16(_CS)+0x1FFF)&0xF000)<<4);
    pm.size -= rm_size;
    if(pm.fallback+pm.size > (((u32)topseg())<<4) || pm_high) {
        pm.fallback = _1m+_64k;
    }

    load_image(&pm);
    return version_string;
}

// Read initrd if needed

static const char msg_initrd[] = "Can't use initrd file";
void load_initrd() {
    struct image_himem *m = &initrd;
    if (!initrd_name && !initrd.fd) return;
    if (!pm.fd) {
noinitrd:
        puts(msg_initrd);
        return;
    }
    m->errmsg = msg_initrd;
    open_image(initrd_name, m);

    m->fallback = (memtop()-m->size) & (~PAGE_MASK);
    if (m->fallback < pm.fallback + pm.size) {
        close(m->fd);
	goto noinitrd;
    }

    load_image(m);
    struct first1k_t *first1k = (first1k_t*)rm_buf;
    if(first1k->header == HdrS) {
        first1k->initrd_buf  = m->fallback;
        first1k->initrd_size = m->size;
    }
}

void boot_kernel() {

    // Shrink stack: we won't need much of it now and have no malloc() plans
    {
        u16 new_SP=u16(heap_top)+0x100;
        if(_SP>new_SP) _SP=new_SP;
    }
    if( u16(_CS)+(u16(_SP)>>4) >= topseg() ) {
        // Oops! We can stomp on our toes... better stop now
        die("Loaded too close to 9000:0");
    }

    cli(); // we start doing destructive things to DOS

    // Move rm loader & commandline to 0x90000
    if(vcpi==0) {
        memcpy32(
            topseg(),0,
            seg(rm_buf),ofs(rm_buf),
            rm_size //_32k
        );
        memcpy32(
            topseg()+0x0800,0,
            seg(cmdline),ofs(cmdline),
            PAGE_SIZE
        );
    } else { //vcpi
        u32 dst=((u32)topseg()<<4);
        u16 pos=ofs(rm_buf);
        do {
            memcpy_vcpi(dst,seg(rm_buf),pos);
            dst+=PAGE_SIZE;
            pos+=PAGE_SIZE;
            rm_size-=PAGE_SIZE;
          } while(s16(rm_size) > 0);
        // overkill: copy PAGE_SIZE bytes
        memcpy_vcpi(((u32)(topseg()+0x0800)<<4),seg(cmdline),ofs(cmdline));
    }

    // Jump to kernel rm code
    set_sregs_jump_seg_ofs(csip, sssp);
}
