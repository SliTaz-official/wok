// This file is distributed under GPL
//
// High mem handling routines
// C++ part of VCPI madness is here

#include "crtl.h"
#include "common.h"

extern u32 himem_buf;

void load_image(struct image_himem *m) {
    m->remaining = m->size;
    u32* bufv= &himem_buf;
#ifdef VCPI
#ifdef WITH_XMM_ALLOC
    m->buf = m->fallback;	// set no_exit btw: die() won't return to DOS
    if(((u16 *)&m->fallback)[1] >= 0x10) { // >= _1m ?
	if(vcpi) {
	    bufv = (u32 *)malloc_bufv_or_die(m);	// update m->bufv
	}
	else {
            xmm_alloc(m);			// update m->buf
	}
    }
    himem_buf = m->buf;
#else
    *bufv = m->buf = m->fallback;	// set no_exit btw: die() won't return to DOS
    if(((u16 *)&m->fallback)[1] >= 0x10) { // >= _1m ?
	if(vcpi) {
	    bufv = (u32 *)malloc_bufv_or_die(m);	// update m->bufv
	}
    }
#endif
#else
    m->buf = m->fallback;	// set no_exit btw: die() won't return to DOS
#ifdef WITH_XMM_ALLOC
    if(((u16 *)&m->fallback)[1] >= 0x10) { // >= _1m ?
        xmm_alloc(m);			// update m->buf
    }
    himem_buf = m->buf;
#endif
#endif
    do {
        u16 size;
	if(s16(size = read_image(m)) -1 < 0) break;
        storepage(bufv);
#ifdef VCPI
	if (bufv != &himem_buf) next(bufv);
#endif
        himem_buf += size;
    } while (*bufv);
    if(m->remaining) loadfailure();
    close(m->fd2close);
}

// Called just before rm->pm
void far last_ditch() {
    asm {
	pushf
	;cli
	push	ds
	push	es
	push	cs
	pop	ds
# ifdef NO386
	push	ax
	push	bx
	push	cx
	push	dx
# else
	pusha
# endif
    }
#ifdef VCPI
    vm2rm();
#endif
    struct image_himem *m = &pm;
#define KERNEL	0
#define INITRD	1
    if(((u16 *)&m[KERNEL].fallback)[1] >= 0x10) // >=	_1m ?
	((u16 *)&m[KERNEL].fallback)[1] = 0x10;
#ifdef VCPI
    u32 *q;
    q = m[KERNEL].bufv;
    if(q==0) {
#endif
        // Move kernel
        memcpy_image_kernel();
        // Move initrd
        memcpy_image_initrd();
#ifdef VCPI
    } else { //vcpi	FIXME: LARGE_ZIMAGE case
#if defined(__BORLANDC__) && defined(NO386)
#pragma option -3
	asm{
		.386p
		pushad
	}
#endif
        // Move kernel
        // 'Gathering' copy in chunks of PAGE_SIZE
        // No risk of overlapping: kernel is copied from above to 1m mark
        m[KERNEL].size = m[INITRD].size = PAGE_SIZE;
#define ADD_PAGE(x)	(*(unsigned long *)(((char *)&x)+1)+=PAGE_SIZE/256)
#define SUB_PAGE(x)	(*(unsigned long *)(((char *)&x)+1)-=PAGE_SIZE/256)
	reset_bufv(q);
	do {
            m[KERNEL].buf = *q;
            memcpy_image_kernel();
            next(q); ADD_PAGE(m[KERNEL].fallback);
        } while(*q);
        // Move initrd
        if(((u16 *)&m[INITRD].fallback)[1]) {
            // This is tricky: copy initrd backwards to reduce
            // risk of overlapping: use the fact that initrd is copied
            // to the very top of ram
            // (overlapping still can happen with more than 256mb ram)
            // (generic solution for this overwrite problem, anyone?)
            q=m[INITRD].bufv;
	    reset_bufv(q);
            do {
                next(q); ADD_PAGE(m[INITRD].fallback);
            } while(*q);
            do {
                prev(q); SUB_PAGE(m[INITRD].fallback);
                m[INITRD].buf = *q;
                memcpy_image_initrd();
            } while(q != m[INITRD].bufv);
        }
	asm{
		popad
        }
    }
#endif
    asm {
# ifdef NO386
	pop	dx
	pop	cx
	pop	bx
	pop	ax
# else
	popa
# endif
	pop	es
	pop	ds
	popf
    }
}
