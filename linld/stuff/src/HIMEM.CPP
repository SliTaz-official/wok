// This file is distributed under GPL
//
// High mem handling routines
// C++ part of VCPI madness is here

#include "crtl.h"
#include "common.h"

struct image_himem pm;
struct image_himem initrd;

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
    struct image_himem *m = &pm;
    if(((u16 *)&m->fallback)[1] >= 0x10) m->fallback = _1m; // >= _1m ?
    if(vcpi==0) {
        // Move kernel
        memcpy_image(m);
        // Move initrd
        memcpy_image(&initrd);
    } else { //vcpi
        vm2rm();
        // Move kernel
        // 'Gathering' copy in chunks of PAGE_SIZE
        // No risk of overlapping: kernel is copied from above to 1m mark
        m->size = initrd.size = PAGE_SIZE;
        u32 *p = m->bufv;
	reset_bufv(p);
	if (p) do {
            m->buf = *p;
            memcpy_image(m);
            next(p); m->fallback+=PAGE_SIZE;
        } while(*p);
        // Move initrd
	m = &initrd;
        if(m->fallback) {
            // This is tricky: copy initrd backwards to reduce
            // risk of overlapping: use the fact that initrd is copied
            // to the very top of ram
            // (overlapping still can happen with more than 256mb ram)
            // (generic solution for this overwrite problem, anyone?)
            p=m->bufv;
	    reset_bufv(p);
            do {
                next(p); m->fallback+=PAGE_SIZE;
            } while(*p);
            do {
                prev(p); m->fallback-=PAGE_SIZE;
                m->buf = *p;
                memcpy_image(m);
            } while(p != m->bufv);
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

int skip_xmmalloc;
void load_image(struct image_himem *m) {
    no_exit++;       // die() won't return to DOS
    m->remaining = m->size;
    m->buf = m->fallback;
    u32 buf;
    u32* bufv= &buf;
    if(((u16 *)&m->fallback)[1] >= 0x10) { // >= _1m ?
	if(vcpi) {
	    bufv = malloc_bufv_or_die(m);	// update m->bufv
	}
	else if (!skip_xmmalloc) {
            xmm_alloc(m);			// update m->buf
	}
    }
    buf = m->buf;
    do {
	u8 xfer_buf[PAGE_SIZE];
        u16 size;
	if(s16(size = read_image(m, xfer_buf, PAGE_SIZE)) <= 0) break;
        storepage(bufv, ofs(xfer_buf));
	if (bufv != &buf) next(bufv);
        buf += size;
    } while (*bufv);
    if(m->remaining) die("Read error");
    close(m->fd2close);
}
