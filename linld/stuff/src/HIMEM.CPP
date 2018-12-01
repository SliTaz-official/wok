// This file is distributed under GPL
//
// High mem handling routines
// C++ part of VCPI madness is here

#include "crtl.h"
#include "common.h"

struct image_himem imgs[2];
int skip_alloc;

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
        u16 size;
	if(s16(size = read_image(m)) <= 0) break;
        storepage(bufv);
	if (bufv != &buf) next(bufv);
        buf += size;
    } while (*bufv);
    if(m->remaining) die("Read error");
    close(m->fd2close);
}

// Called just before rm->pm
void last_ditch() {
    struct image_himem *m = &pm;
    u32 *q;
    vm2rm();
    if(((u16 *)&m->fallback)[1] >= 0x10) m->fallback = _1m; // >= _1m ?
    q = m->bufv;
    if(q==0) {
        // Move kernel
        memcpy_image(m);
        // Move initrd
        memcpy_image(pm2initrd(m));
    } else { //vcpi
#if defined(__BORLANDC__) && defined(NO386)
#pragma option -3
	asm{
		.386p
	}
#endif
        // Move kernel
        // 'Gathering' copy in chunks of PAGE_SIZE
        // No risk of overlapping: kernel is copied from above to 1m mark
        m->size = pm2initrd(m)->size = PAGE_SIZE;
#define ADD_PAGE(x)	(*(unsigned long *)(((char *)&x)+1)+=PAGE_SIZE/256)
#define SUB_PAGE(x)	(*(unsigned long *)(((char *)&x)+1)-=PAGE_SIZE/256)
	reset_bufv(q);
	do {
            m->buf = *q;
            memcpy_image(m);
            next(q); ADD_PAGE(m->fallback);
        } while(*q);
        // Move initrd
	m = pm2initrd(m);
        if(((u16 *)&m->fallback)[1]) {
            // This is tricky: copy initrd backwards to reduce
            // risk of overlapping: use the fact that initrd is copied
            // to the very top of ram
            // (overlapping still can happen with more than 256mb ram)
            // (generic solution for this overwrite problem, anyone?)
            q=m->bufv;
	    reset_bufv(q);
            do {
                next(q); ADD_PAGE(m->fallback);
            } while(*q);
            do {
                prev(q); SUB_PAGE(m->fallback);
                m->buf = *q;
                memcpy_image(m);
            } while(q != m->bufv);
        }
    }
}
