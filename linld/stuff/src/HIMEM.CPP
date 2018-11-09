// This file is distributed under GPL
//
// High mem handling routines
// C++ part of VCPI madness is here

#include "crtl.h"
#include "common.h"

struct image_himem imgs[2];
int skip_alloc;

// Called just before rm->pm
void last_ditch() {
    struct image_himem *m = &pm;
    vm2rm();
    if(((u16 *)&m->fallback)[1] >= 0x10) m->fallback = _1m; // >= _1m ?
    if(m->bufv==0) {
        // Move kernel
        memcpy_image(m);
        // Move initrd
        memcpy_image(&initrd);
    } else { //vcpi
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
}

void load_image(struct image_himem *m) {
    no_exit++;       // die() won't return to DOS
    m->remaining = m->size;
    m->buf = m->fallback;
    u32 buf;
    u32* bufv= &buf;
    if(((u16 *)&m->fallback)[1] >= 0x10 && !skip_alloc) { // >= _1m ?
	if(vcpi) {
	    bufv = (u32 *)malloc_bufv_or_die(m);	// update m->bufv
	}
	else {
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
