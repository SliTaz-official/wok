struc   image_himem		;struct image_himem {
fd		dw	?	; 0    int fd;
fallback	dd	?	; 2    u32 fallback;
size		dd	?	; 6    u32 size;
remaining	dd	?	;10    u32 remaining;
buf		dd	?	;14    u32 buf;
bufv		dw	?	;18    u32 *bufv;
errmsg		dw	?	;20    char *errmsg;
chunk_size	dd	?	;22    u32 chunk_size;
next_chunk	dw	?	;26    void (*next_chunk)(struct image_himem *);
state		dw	?	;28    u16 state;
fd2close	dw	?	;30    u16 fd2close;
ends	image_himem		;};
