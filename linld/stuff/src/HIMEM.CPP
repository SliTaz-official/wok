// This file is distributed under GPL
//
// High mem handling routines
// C++ part of VCPI madness is here

#include "crtl.h"
#include "common.h"

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
        u16 size = read_image(m, xfer_buf, PAGE_SIZE);
        if(s16(size) <= 0) break;
        memcpy32(*bufv, seg(xfer_buf), ofs(xfer_buf), PAGE_SIZE);
	if (bufv != &buf) bufv++;
        buf += size;
    } while (*bufv);
    if(m->remaining) die("Read error");
    close(m->fd2close);
}

