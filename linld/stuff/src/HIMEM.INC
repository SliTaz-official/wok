struc   image_himem			;struct image_himem {
fd		dw	?		; 0    int fd;
fallback	dd	?		; 2    u32 fallback;
size		dd	?		; 6    u32 size;	// assume zero'd in bss
remaining	dd	?		;10    u32 remaining;
buf		dd	?		;14    u32 buf;
bufv		dw	?		;18    u32 *bufv;
chunk_size	dd	?		;20    u32 chunk_size;
state		dw	?		;24    u16 state;
fd2close	dw	?		;26    u16 fd2close;
ends	image_himem			;};
