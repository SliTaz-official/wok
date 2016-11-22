// This file is distributed under GPL
//
// High mem handling routines
// C++ part of VCPI madness is here

#include "crtl.h"
#include "common.h"

// Returns physical addr of allocated himem chunk
// Never fails (will use fallback if not enough mem/no xmm)
// TODO: with proper cleanup it is possible to exit to DOS
// even after XMM alloc - do dealloc, then exit...
// don't forget to clean up the mess then, especially
// XMM handle which is lost inside xmm_alloc()...
// (don't drop fallback: use it if no XMM driver detected)
static void read2mem(struct image_himem *m) {
    u32 buf=m->buf;
    while(1) {
	u8 xfer_buf[PAGE_SIZE];
        u16 size = read_image(m, xfer_buf, sizeof(xfer_buf));
        if(s16(size) <= 0) break;
        memcpy32(0, buf, seg(xfer_buf), ofs(xfer_buf), size);
        buf += size;
        m->remaining -= size;
    }
}

extern "C" void sort(u32* v, int size);

// Returns ptr to mallocated zero-terminated list of physical page addrs
// Never fails (will die if not enough mem)
// Addresses are sorted in ascending order
// static void malloc_vcpi(struct image_himem *m) {
static void read2vcpi(struct image_himem *m) {
    u16 cnt = (m->size+PAGE_MASK)/PAGE_SIZE;
    u32* bufv = (u32*)malloc_or_die((cnt+1)*sizeof(u32));
    // our malloc zeroes allocated mem: buf[cnt]=0;
    // Allocate pages, storing addrs in addrbuf
    {for(int i=0;i<cnt;i++) {
        u32 v;
        asm {
                db      66h
                xor     dx,dx
                mov     ax,0DE04h
                int     67h
                db      66h
                mov     [word ptr v],dx
        }
        extern const char vcpi_alloc_err[];
        if(!v) die(vcpi_alloc_err);
        bufv[i] = v;
    }}
    // Sanitize addresses: ascending sort
    sort(bufv,cnt);
    m->bufv = bufv;
//}

// Reads opened fd data into malloc_vcpi'ed memory
// Dies if file isn't exactly 'size' bytes long
// Needs intermediate buffer of exactly Nx4k bytes
// static void read2vcpi(struct image_himem *m) {
    while(1) {
	u8 xfer_buf[PAGE_SIZE];
        u16 size = read_image(m, xfer_buf, PAGE_SIZE);
        if(s16(size) <= 0 || !*bufv) break;
        m->remaining -= size;
        memcpy_vcpi(*bufv++, seg(xfer_buf), ofs(xfer_buf));
    }
}

void init_vcpi() {
    heap_top = prepare_vcpi(malloc_or_die(8*1024+4));
    get_vcpi_interface() || die("VCPI: low 640k: need 1:1 mapping");
}

int skip_xmmalloc;
void load_image(struct image_himem *m) {
    no_exit++;       // die() won't return to DOS
    m->remaining = m->size;
    m->buf = m->fallback;
    if(m->fallback < _1m) {
        read2mem(m);
    } else if(vcpi==0) {
	if (!skip_xmmalloc) {
        	u32 v = xmm_alloc(m->size);
        	if(v) m->buf = v;
	}
        read2mem(m);
    } else {
        //malloc_vcpi(m);
        read2vcpi(m);
    }
    if(m->remaining) die("Read error");
//break iso case    close(m->fd);
}

