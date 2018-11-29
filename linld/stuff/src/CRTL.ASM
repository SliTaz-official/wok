;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
		ifdef	NO386
                p8086
		else
                p386
		endif

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'

		global	_heap_top
		extrn	_bss_end
_heap_top	dw	_bss_end
msg_hang	db      "High mem corrupted - not exiting to DOS"
msg_lf		db	10,0
vcpi_alloc_err	db	"VCPI "
msg_malloc      db      "malloc error",0
	ifdef	EXTRA
tazboot_cmd	db	"tazboot.cmd",0
	endif

        ends    _DATA

        segment _BSS byte public use16 'BSS'

_xfer_buf	db	4096	dup (?)
        global  _no_exit:byte
_no_exit	db	?
filecnt		db	?		; in fact 0 minus file count...
nextfilename	dw	?
	ifdef	LARGE_IMAGES
curdata		dw	?
	endif
	ifdef	EXTRA
ultoabuf	db	12	dup (?)
	endif

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;_fastcall void strcpy(const char* a, const char* b);
;_fastcall void strcat(const char* a, const char* b);
;_fastcall void strcatb(const char* a, const char* b);
;***************************************************************
        global  @strcatb$qpxzct1:near
        proc	@strcatb$qpxzct1 near

	ifdef	EXTRA
		mov	cl,7Fh
		db	0bah			; mov	dx,imm opcode
        global  @strcat$qpxzct1:near
@strcat$qpxzct1:
		mov	cl,80h
		db	0bah			; mov	dx,imm opcode
        global	@strcpy$qpxzct1:near
@strcpy$qpxzct1:
		xor	cx,cx
	endif
                push	si
                mov	si,bx			; a
		xchg	ax,dx			; b
	ifdef	EXTRA
		jcxz	@@nocat
	endif
@@catlp:
		lodsb
		or	al,al
                jne	@@catlp
		dec	si
	ifdef	EXTRA
		cmp	dx,si
		adc	al,cl		; set S when dx != si or cl = 80
		mov	al,20h
		jns	@@cpyhead
	endif
@@nocat:
@@cpylp:
                mov	al,[bx]
                inc	bx
@@cpyhead:
                mov	[si],al
                inc	si
		or	al,al
                jne	@@cpylp
strfound:
		xchg	ax,dx
strend:
                pop	si
		ret

        endp	@strcatb$qpxzct1


	ifdef	EXTRA
                p8086
;***************************************************************
;_fastcall char strstr(const char* a,const char* b);
;***************************************************************
        global  @strstr$qpxzct1:near
        proc    @strstr$qpxzct1 near

                xchg	ax,cx			; b
                mov	dx,bx			; a
                push	si
@@loop:
		xor	ax,ax
		mov	si,dx
		cmp	[si],al			; *a
		jz	strend			; return ax = NULL
		mov	bx,cx
@@match:
		or	ah,[bx]			; *b
		jz	strfound
		inc	bx
		lodsb
		sub	ah,al
		jz	@@match
		inc	dx
		jmp	@@loop

        endp    @strstr$qpxzct1


;***************************************************************
;_fastcall int strcmp(const char* a,const char* b);
;***************************************************************
        global  @strcmp$qpxzct1:near
        proc    @strcmp$qpxzct1 near

                push	si
		xchg	ax,si
		dec	bx
@@lp:
		inc	bx
		lodsb
		sub	al,[bx]
		jnz	@@out
		or	al,al
		jnz	@@lp
@@out:
		cbw
                pop	si
                ret

        endp    @strcmp$qpxzct1
	endif


;***************************************************************
;_fastcall void puts(const char* s):
;***************************************************************
        global  @puts$qpxzc:near
        proc    @puts$qpxzc near

;        global  puts:near			; puts(bx)
puts:
		call	@@putsz
                mov	bx,offset msg_lf
		mov	dl,13
@@putcz:
		mov	ah,2
		int	21h
@@putsz:
		mov	dl,[bx]
		inc	bx
		or	dl,dl
		jne	@@putcz			; ZF=1  (for malloc failure)
		ret

        endp    @puts$qpxzc


;***************************************************************
;_fastcall int fileattr(const char* name);
;***************************************************************
        global  @fileattr$qpxzc:near
        proc    @fileattr$qpxzc near

                mov	ax,4300h
		call	dos_filename
		xchg	ax,cx
		jmp	chkc

        endp    @fileattr$qpxzc


;***************************************************************
;_fastcall int open(const char* name, int flags=O_RDONLY);
;***************************************************************
        global  openargs:near			; openargs(bx)
openargs:
		cmp	[byte bx],'@'
		stc
		jne	fail
		inc	bx

        global  @open$qpxzc:near
        proc    @open$qpxzc near

        global  open:near			; open(bx)
open:
                mov	ax,3d00h		; read-only+compatibility
		;mov	cl,0			; attribute mask
dos_filename:
                mov	dx,bx
dos:
                int	21h
chkc:
                jnc	doret
fail:
                sbb	ax,ax			; ax=-1 CF
		cwd
doret:
		ifndef	NO386
		push	dx			; see next_chunk:lseek
		push	ax
		pop	eax
		endif
                ret

        endp    @open$qpxzc


;***************************************************************
;_fastcall int close(int fd);
;***************************************************************
        global  @close$qi:near
        proc    @close$qi near

        global  close:near			; close(ax)
close:
		xchg	ax,bx
		mov	ah,3Eh
		or	bx,bx
		jnz	dos
		ret

        endp    @close$qi


;***************************************************************
;_fastcall int read(int fd, void* data, int sz);
;_fastcall int write(int fd, const void* data, int sz);
;***************************************************************
        global  @read$qipvi:near
        proc    @read$qipvi near

		ifdef	WRITE
                stc
		db	0B0h			; mov al,im
        global  @write$qipvi:near
@write$qipvi:
                clc
		endif
		xchg	ax,bx			; fd
		xchg	ax,dx			; data
		xchg	ax,cx			; sz
		ifdef	WRITE
                mov	ah,40h
		sbb	ah,0
		else
	global	@read$cxdxbx:near
@read$cxdxbx:
                mov	ah,3Fh
		endif
                jcxz	fail
		jmp	dos

        endp    @read$qipvi

;***************************************************************
;_fastcall long lseekset(int fd, unsigned sz);
;***************************************************************

        global  @lseekset$qiui:near
        proc    @lseekset$qiui near

		xchg	ax,bx			; fd
		xor	cx,cx			; sz hi
lseekset:
		clc
		db	0B0h			; mov al,im
;        global  rewind:near
rewind:						; rewind(bx)
		stc
		mov	ax,4200h
		jnc	dos
lseek0:						; lseek0(bx,ax=dir)
		cwd
		xor	cx,cx
		jmp	dos

        endp    @lseekset$qiui

		ifdef EXTRA

;typedef unsigned dirsizetype;
struc		isostate		; struct isostate {
fd		dw	?		; 0	int fd;
filemod		dw	?		; 2	unsigned short filemod;
fileofs		dd	?		; 4	unsigned long fileofs;
filesize	dd	?		; 8	unsigned long filesize;
filename	dw	?		;12	char *filename;
curdirsize	dw	?		;14	dirsizetype curdirsize;
dirsize		dw	?		;16	dirsizetype dirsize;
curdirofs	dd	?		;18	unsigned long curdirofs;
dirofs		dd	?		;22	unsigned long dirofs;
curpos		dw	?		;26	unsigned curpos;
buffer		db	2560	dup(?)	;28	char buffer[2048+512];
ends					; } isostate;
;***************************************************************
;_fastcall long isolseek(const unsigned long *offset);
;***************************************************************
        global  @isolseek$qpxul:near
        proc    @isolseek$qpxul near

isolseek:
		mov	dx,[bx]
		mov	cx,[bx+2]
		extrn	_isostate:isostate
		mov	bx,[_isostate.fd]
		jmp	lseekset

	endp	@isolseek$qpxul

;***************************************************************
;_fastcall int isoreadsector(const unsigned long *offset);
;***************************************************************
        global  @isoreadsector$qpxul:near
        proc    @isoreadsector$qpxul near

		call	isolseek
		and	ax,dx
		inc	ax
		jz	@@fail
		mov	cx,2560
		mov	dx,offset _isostate.buffer
		mov	bx,[_isostate.fd]
		call	@read$cxdxbx		; read(fd,buffer,2560)
@@fail:
		cmp	ax,2048
		sbb	ax,ax
		ret

        endp    @isoreadsector$qpxul

		endif


;***************************************************************
;_fastcall int strhead(const char* a,const char* b);
;***************************************************************
        global  @strhead$qpxzct1:near
        proc    @strhead$qpxzct1 near

@@loop:
		xchg	ax,bx
                mov	cl,[bx]			; cl = *b++
                inc	bx
		or	cl,cl			; clear C
		jz	fail			; return 0
		xchg	ax,bx
                xor	cl,[bx]			; cl -= *a++
                inc	bx
		and	cl,0dfh			; case insensitive
                jz	@@loop
		ret				; return b (is not 0)

	endp	@strhead$qpxzct1


;***************************************************************
;_fastcall char* malloc_or_die(unsigned size);
;***************************************************************
        global  @malloc_or_die$qui:near
        proc    @malloc_or_die$qui near

                xchg	ax,cx			; size
        global  malloc_or_die:near		; malloc_or_die(cx)
malloc_or_die:
		mov	ax,[_heap_top]		; return value
		mov	bx,sp
		add	bh,-14h			; MIN_STACK=_1k+PAGE_SIZE
		sub	bx,ax			; can't overflow
		cmp	bx,cx
		mov	bx,offset msg_malloc
		jb	die
		add	[_heap_top],cx		; _BEG has zero'd heap
		ret

        endp    @malloc_or_die$qui


;***************************************************************
;_fastcall int die(const char* msg);
;int exit();
;int abort();
;***************************************************************
	global	@die$qpxzc:near
	proc	@die$qpxzc near
@die$qpxzc:
        global  die:near			; die(bx)
die:
		call	puts
;        global  _exit:near
_exit:
		mov	al,[_no_exit]
		or	al,al
		jne	@@hang
		extrn	exit:near
		inc	ax
		jmp	near exit
@@hang:
		mov	bx, offset msg_hang
		call	puts
;        global  _abort:near
_abort:
		cli
@@stop:
		hlt
		jmp	@@stop

	endp	@die$qpxzc

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
ends				;};

;***************************************************************
;long next_chunk(struct image_himem *di);
;***************************************************************
        proc    next_chunk near

		push	si
		mov	ax,[(image_himem di).fd]
		call	close
		ifndef	NO386
		xor	eax,eax
		else
		xor	ax,ax
		cwd
		endif
		mov	[(image_himem di).fd],ax
		mov	bx,[(image_himem di).state]
		cmp	al,[bx]			; ""
		jz	@@end
		mov	si,bx
@@scan:
		lodsb
		mov	cx,si
		cmp	al,','
		jz	@@eos
		or	al,al
		jnz	@@scan
		dec	cx
@@eos:
		mov	[(image_himem di).state],cx
		dec	si
		push	[word si]
		mov	[byte si],ah		; set temp eos
		call	open
		pop	[word si]		; restore string
		jc	@@die
		mov	[(image_himem di).fd],ax
		mov	[(image_himem di).fd2close],ax
		xchg	ax,bx
		mov	ax,4202h		; SEEK_END
		call	lseek0
@@die:
		mov	bx,[(image_himem di).errmsg]
		jc	die
		mov	bx,[(image_himem di).fd]
		ifndef	NO386
		push	eax
		call	rewind
		pop	eax
@@end:
		mov	[(image_himem di).chunk_size],eax
		else
		push	ax
		push	dx
		call	rewind
		pop	dx
		pop	ax
@@end:
		mov	[word (image_himem di).chunk_size],ax
		mov	[word ((image_himem di).chunk_size)+2],dx
		endif
		pop	si
		ret

        endp    next_chunk


	ifdef	LARGE_IMAGES
struc   data_himem			;struct data_himem {
first		dd	?		;   0  u32 first;
cacheidx	dw	?		;   4  int cacheidx;
pageidx		dw	?		;   6  int pageidx;
cache		dd	1024 dup(?)	;   8  int cache;
page		dd	1024 dup(?)	;4104  int page;
ends					;}; // size=8200
	endif

;***************************************************************
;_fastcall u32* malloc_bufv_or_die(struct image_himem *m);
;***************************************************************
        global  @malloc_bufv_or_die$qp11image_himem:near
        proc    @malloc_bufv_or_die$qp11image_himem near

                p386
		push	si
		mov	si,bx
	ifdef	LARGE_IMAGES
		movzx	ecx,[word ((image_himem si).size) + 2]
		shr	cx,4			; pages index size = size >> 20
		add	cx,8+4096+8
		call	malloc_or_die
		mov	cx,4096+4095		; cnt = 1+(m->size+PAGE_MASK)/PAGE_SIZE;
		add	ecx,[(image_himem si).size]
		shr	ecx,12
		mov	[curdata],ax
	else
		mov	ecx,[(image_himem si).size]
		dec	ecx
		shr	ecx,12
		inc	cx			; cnt = (m->size+PAGE_MASK)/PAGE_SIZE;
		push	cx
		inc	cx			; cnt+1
		shl	cx,2			; bufv => vcpi => vm86
; our malloc zeroes allocated mem: bufv[cnt]=0;
; Allocate pages, storing addrs in addrbuf
		call	malloc_or_die
		pop	cx
		push	ax
	endif
		mov	[(image_himem si).bufv],ax
		xchg	ax,si
@@vcpi_alloc:
                xor     edx,edx
                mov     ax,0DE04h
                int     67h
		or	ah,ah
		mov	bx,offset vcpi_alloc_err
		jnz	die
; for (i = cnt-1; i >= 0; i--)
	ifdef	LARGE_IMAGES
		mov	eax,ecx
		dec	eax
	else
		mov	ax,cx
		dec	ax
		cwde
	endif
		shl	eax,12		; i*_4k
; if (edx < pm.fallback+i*_4k && edx >= pm.fallback) again
		extrn	_imgs
		mov	bx,offset _imgs+2
		push	eax
		add	eax,[bx-2+2]
		cmp	eax,edx		; pm.fallback+i*_4k <= edx ?
		pop	eax		; i*_4k
		jbe	@@pmok
		cmp	edx,[bx-2+2]	; edx >= pm.fallback ?
		jae	@@vcpi_alloc
@@pmok:
; if (edx >= initrd.fallback+i*_4k && edx < initrd.fallback+initrd.size) again
		extrn	_imgs
		mov	bx,offset _imgs+32+2
		add	eax,[bx-2+2]	; +initrd.fallback
		cmp	eax,edx		; initrd.fallback+i*_4k > edx ?
		ja	@@initrdok
		mov	eax,[bx-2+6]	; initrd.size
		add	eax,[bx-2+2]	; +initrd.fallback
		cmp	eax,edx		; initrd.fallback+initrd.size > edx ?
@@jnc_vcpi_alloc:
		ja	@@vcpi_alloc
@@initrdok:
	ifdef	LARGE_IMAGES
		cmp	[(data_himem si).first],0
		jne	@@notfirst
		mov	[(data_himem si).first],edx
@@notfirst:
		mov	bx,[(data_himem si).cacheidx]
		cmp	bh,4
		jae	@@nextpage
		shl	bx,2
		inc	[(data_himem si).cacheidx]
		mov	[(data_himem bx+si).cache],edx
		loopd	@@vcpi_alloc
		mov	[(data_himem bx+si).cache],ecx	; last is 0
@@nextpage:
		and	[(data_himem si).cacheidx],0
		mov	bx,[(data_himem si).pageidx]
		mov	[(data_himem bx+si).page],edx
		add	[(data_himem si).pageidx],4
		push	cx
		lea	cx,[(data_himem si).cache]
		ifdef	NO386
		push	edx
		pop	dx
		pop	ax
		endif
		call	storepage		; storepage(edx,cx)	
		pop	cx
		or	ecx,ecx			; clear C
		jnz	@@jnc_vcpi_alloc
		mov	[dword (data_himem si).cacheidx],ecx
		xchg	ax,si
	else
		mov	[si],edx
		lodsd				; si=+4
		loop	@@vcpi_alloc
		pop	ax
	endif
		pop	si
		ret
		ifdef	NO386
                p8086
		endif

        endp    @malloc_bufv_or_die$qp11image_himem


;***************************************************************
;_fastcall void memcpy_image(struct image_himem *m);
;***************************************************************
        global  @memcpy_image$qp11image_himem:near
        proc    @memcpy_image$qp11image_himem near

		ifndef	NO386
		mov	edx,[(image_himem bx).fallback]
		mov	eax,[(image_himem bx).buf]
		cmp	eax,edx			; if (m->fallback != m->buf)
		jz	@@skip			;   memcpy32(m->fallback,0,m->buf,m->size)
	ifdef	LARGE_IMAGES
		mov	ecx,[(image_himem bx).size]
memcpy_imagez:					; memcpy_imagez(edx,eax,ecx)
		push	ecx
	else
		push	[(image_himem bx).size]
	endif
		push	eax
		push	0
call_memcpy32:
		push	edx
		else
		mov	ax,[word ((image_himem bx).fallback)]
		mov	dx,[word ((image_himem bx).fallback)+2]
		mov	cx,[word ((image_himem bx).buf)]
		cmp	ax,cx			; if (m->fallback != m->buf)
		jnz	@@do
		cmp	dx,[word ((image_himem bx).buf)+2]
		jz	@@skip			;   memcpy32(m->fallback,0,m->buf,m->size)
@@do:
		push	[word ((image_himem bx).size)+2]
		push	[word ((image_himem bx).size)]
		push	[word ((image_himem bx).buf)+2]
		push	cx
		xor	cx,cx
		push	cx
call_memcpy32:
		push	dx
		push	ax
	ifdef	LARGE_IMAGES
		jmp	@@memcpy
memcpy_imagez:					; memcpy_imagez(edx,eax,ecx)
		p386
		push	ecx
		push	eax
		push	0
		push	edx
		ifdef	NO386
                p8086
		endif
	endif
		endif
@@memcpy:
		extrn	memcpy32:near
		call	near memcpy32
@@skip:
		ret

        endp    @memcpy_image$qp11image_himem

;***************************************************************
;_fastcall void storepage(u32 *dst);
;***************************************************************
        global  @storepage$qpul:near
        proc    @storepage$qpul near

		ifndef	NO386
		mov	edx,[bx]
		else
		mov	ax,[bx]
		mov	dx,[bx+2]
		endif
		mov	cx,offset _xfer_buf
storepage:					; storepage(edx,cx)
		ifndef	NO386
		push	0
		push	4096
		push	0
		else
		xor	bx,bx
		push	bx
		mov	bh,4096/256
		push	bx
		xor	bx,bx
		push	bx
		endif
		push	cx
		push	ds
		jmp	call_memcpy32

        endp    @storepage$qpul


	ifdef	LARGE_IMAGES
                p386
;***************************************************************
;_fastcall void reset_bufv(u32 *p);
;***************************************************************
        global  @reset_bufv$qpul:near
        proc    @reset_bufv$qpul near

		mov	[curdata],bx
		and	[dword (data_himem bx).cacheidx],0
		ret

        endp    @reset_bufv$qpul

;***************************************************************
;u32* prev_bufv();
;u32* prev_bufv();
;***************************************************************
        global  _prev_bufv:near
        global  _next_bufv:near
        proc    _prev_bufv near

		stc
		db	73h			; jnc
_next_bufv:
		clc
		push	si
		mov	si,[curdata]
		sbb	ax,ax
		cmc
		adc	ax,[(data_himem si).cacheidx]	; -1/+1
		xor	ecx,ecx
		test	ax,0fc00h
		jz	@@gotpage
		push	ax			; FFFF / 0400
		sar	ax,8			; FFFC / 0004
		and	al,0fch
		add	[(data_himem si).pageidx],ax
		mov	bx,[(data_himem si).pageidx]
		lea	bx,[(data_himem bx+si).page]
		mov	edx,ds
		shl	edx,4
		lea	cx,[(data_himem si).cache]		
		add	edx,ecx
		mov	eax,[bx]
		or	eax,eax
		jnz	@@pageok
		pop	ax
		xchg	ax,bx
		pop	si
		ret
@@pageok:
		mov	cx,4096
		call	memcpy_imagez		; get page
		pop	ax			; FFFF / 0400
		cbw
		shr	ax,6			; 03FF / 0000
@@gotpage:
		mov	[(data_himem si).cacheidx],ax
		shl	ax,2
		xchg	ax,bx
		lea	ax,[(data_himem bx+si).cache]		
		or	bx,[(data_himem si).pageidx]	; !pageidx && !cacheidx
		jnz	@@notfirst2
		xchg	ax,si				; &first
@@notfirst2:
		pop	si
		ret

        endp    _prev_bufv
	endif

		ifdef	NO386
                p8086
		endif

;***************************************************************
;_fastcall void open_image(const char *name, struct image_himem *m);
;***************************************************************
        global  @open_image$qpxzcp11image_himem:near
        proc    @open_image$qpxzcp11image_himem near

                push	di
		xchg	ax,di
		ifdef	EXTRA
		cmp	[(image_himem di).fd],0		; iso image/kernel ?
		jnz	@@alreadydone
		endif
                mov	[(image_himem di).state],bx
		push	bx
		ifdef	EXTRA
		cmp	[(image_himem di).next_chunk],0	; iso image/initrd ?
		jnz	@@next
		endif
		mov	[(image_himem di).next_chunk],offset next_chunk
@@next:
                call	[(image_himem di).next_chunk]	; m->next_chunk()
		ifndef	NO386
		add	eax,3
		and	al,0FCh
		add	[(image_himem di).size],eax	; m->size += m->chunk_size
		or	eax,eax
		else
		add	ax,3
		adc	dx,0
		and	al,0FCh
		add	[word (image_himem di).size],ax	; m->size += m->chunk_size
		adc	[word ((image_himem di).size)+2],dx
		or	ax,dx
		endif
		jnz	@@next
                pop	[(image_himem di).state]
                call	[(image_himem di).next_chunk]	; m->next_chunk()
@@alreadydone:
                pop	di
		ret

        endp    @open_image$qpxzcp11image_himem


;***************************************************************
;_fastcall int read_image(struct image_himem *m);
;***************************************************************
        global  @read_image$qp11image_himem:near
        proc    @read_image$qp11image_himem near

		push	si di
		mov	di,bx
		mov	si,4096
		push	si		; original size
@@loop:
		ifndef	NO386
		movzx	ecx,si
		mov	eax,[(image_himem di).chunk_size]
		cmp	ecx,eax
		jb	@@szok
		else
		mov	cx,si
		mov	ax,[word (image_himem di).chunk_size]
		cmp	cx,ax
		jb	@@szok
		cmp	[word ((image_himem di).chunk_size)+2],0	; hi m->chunk_size
		jne	@@szok
		endif
		xchg	ax,cx
@@szok:
		jcxz	image_done
		mov	dx,offset _xfer_buf
		mov	bx,[di]
		call	@read$cxdxbx
		jc	image_done
		xor	cx,cx
		cwd				; ax < 8000h
		ifndef	NO386
		cwde				; ax < 8000h
		sub	[(image_himem di).chunk_size],eax
		mov	bx,ax
		else
		sub	[word (image_himem di).chunk_size],ax
		xchg	ax,bx
		sbb	[word ((image_himem di).chunk_size)+2],dx
		jnz	@@fill
		cmp	[word (image_himem di).chunk_size],dx
		endif
		jnz	@@fill
		dec	cx
@@fill:
		test	bl,3
		je	@@filled
		mov	[bx+_xfer_buf],dh
		inc	bx
		jmp	@@fill
@@filled:
		ifndef	NO386
		sub	[(image_himem di).remaining],eax
		else
		sub	[word (image_himem di).remaining],bx
		sbb	[word ((image_himem di).remaining)+2],dx
		endif
		sub	si,ax
		pushf
                and	cx,[(image_himem di).next_chunk]
		jcxz	@@same_chunk
		call	cx
@@same_chunk:
		popf
		jnz	@@loop
image_done:
                pop	ax		; original size
		sub	ax,si
                pop	di si
		ret

        endp    @read_image$qp11image_himem


;***************************************************************
;pascal unsigned long strtol(const char *s);
;***************************************************************
	global	@strtol$qpxzc:near
	proc	@strtol$qpxzc near

		pop	ax
                pop	bx			; s
		push	ax
		ifndef	NO386
		xor	ebx,ebx
		push	si
		jcxz	@@end
		mov	si,cx
		xor	ecx,ecx
		xor	eax,eax
		lodsb
		mov	dx,ax
		or	al,20h
		cmp	al,'n'			; vga=normal
		je	@@vga
		dec	cx
		cmp	al,'e'			; vga=extended
		je	@@vga
		dec	cx
		cmp	al,'a'			; vga=ask
		jne	@@notvga
@@vga:
		dec	cx
		xchg	ax,cx
		cwd
		jmp	@@popsiret
@@notvga:
		mov	cx,10			; radix
		xchg	ax,dx
		cmp	al,'+'
		je	@@radixskip
		cmp	al,'-'
		clc
		jne	@@radixkeep
		stc
@@radixskip:
		lodsb
@@radixkeep:
		pushf
		cmp	al,'0'
		jne	@@radixok
		mov	cl,8
		lodsb
		or	al,20h
		cmp	al,'x'
		jne	@@radixok
		mov	cl,16
@@strtollp:
		lodsb
@@radixok:
		or	al,20h
		sub	al,'0'
		jb	@@endstrtol
		cmp	al,9
		jbe	@@digitok
		cmp	al,'a'-'0'
		jb	@@endstrtol
		sub	al,'a'-'0'-10
@@digitok:
		cmp	al,cl
		jae	@@endstrtol
		xchg	eax,ebx
		mul	ecx
		add	eax,ebx
		xchg	eax,ebx
		jmp	@@strtollp
@@endstrtol:
		mov	cl,10
		cmp	al,'k'-'a'+10
		je	@@shift
		mov	cl,20
		cmp	al,'m'-'a'+10
		je	@@shift
		mov	cl,30
		cmp	al,'g'-'a'+10
		jne	@@noshift
@@shift:
		shl	ebx,cl
@@noshift:
		popf
		jnc	@@end
		neg	ebx
@@end:
		push	ebx
		pop	ax
		pop	dx
@@popsiret:
		pop	si
		else
		push	si
		push	di
		xor	ax,ax
		cwd
		jcxz	@@goend
		xchg	ax,di
		mov	si,cx
		lodsb
		mov	bx,ax
		or	al,20h
		mov	cx,-1
		cmp	al,'n'			; vga=normal
		je	@@vga
		dec	cx
		cmp	al,'e'			; vga=extended
		je	@@vga
		dec	cx
		cmp	al,'a'			; vga=ask
		jne	@@notvga
@@vga:
		xchg	ax,cx
@@goend:
		jmp	@@popdisiret
@@notvga:
		mov	cx,10			; radix
		xchg	ax,bx
		cmp	al,'+'
		je	@@radixskip
		cmp	al,'-'
		clc
		jne	@@radixkeep
		stc
@@radixskip:
		lodsb
@@radixkeep:
		pushf
		cmp	al,'0'
		jne	@@radixok
		mov	cl,8
		lodsb
		or	al,20h
		cmp	al,'x'
		jne	@@radixok
		mov	cl,16
@@strtollp:
		lodsb
@@radixok:
		or	al,20h
		sub	al,'0'
		jb	@@endstrtol
		cmp	al,9
		jbe	@@digitok
		cmp	al,'a'-'0'
		jb	@@endstrtol
		sub	al,'a'-'0'-10
@@digitok:
		cmp	al,cl
		jae	@@endstrtol

		push	ax
		push	si
		push	dx
		xchg	ax,di
		mul	cx
		xchg	ax,di
		xchg	ax,dx
		xchg	ax,si
		pop	ax
		mul	cx
		add	ax,si
		pop	si
		xchg	ax,dx
		pop	ax
		mov	ah,0
		add	di,ax
		adc	dx,0

		jmp	@@strtollp
@@endstrtol:
		mov	cl,10
		cmp	al,'k'-'a'+10
		je	@@shift
		mov	cl,20
		cmp	al,'m'-'a'+10
		je	@@shift
		mov	cl,30
		cmp	al,'g'-'a'+10
		jne	@@noshift
@@shift:
		rcl	di,1
		shl	dx,1
		loop	@@shift
@@noshift:
		popf
		jnc	@@end
		not	dx
		neg	di
		jne	@@end
		inc	dx
@@end:
		xchg	ax,di
@@popdisiret:
		pop	di
		pop	si
		endif
strtol_ret:
		ret

	endp	@strtol$qpxzc


		ifdef	NO386
;***************************************************************
;u16 topseg();
;***************************************************************
        global  _topseg:near
        proc    _topseg near

		int	12h
		jnc	@@max640k
		mov	ax,640			; 9000
@@max640k:
		dec	ax
		and	al,0C0h
		mov	cl,6
		shl	ax,cl
		ret

        endp    _topseg
		endif

		ifdef	EXTRA
                p8086
;***************************************************************
;char *progname(void)
;***************************************************************
        global  _progname:near
        proc    _progname near

		push	si di es
		mov	ah,30h
		int	21h
		xor	di,di
		cmp	al,3
		mov	ax,di
		jb	@@skip
		;mov	es,[cs:2Ch]
		mov	es,[di+2Ch]
		mov	cx,sp			; big enough
@@loop:
		repne
		  scasb
		scasb
		jne	@@loop
		inc	di
		inc	di
		mov	si,di			; progname @es:di
		repne
		  scasb
		mov	cx,di
		sub	cx,si			; progname len
		call	malloc_or_die		; keep cx
		mov	di,ax
		push	ds
		push	es
		pop	ds
		pop	es
		rep
		  movsb
		push	es
		pop	ds
@@skip:
		pop	es di si
		ret

        endp    _progname


;***************************************************************
;_fastcall void chdirname(char *path)
;***************************************************************
        global  @chdirname$qpzc:near
        proc    @chdirname$qpzc near

		cmp	[byte bx+1],3Ah		; ':'
		jne	@@nodisk
		mov	dl,20h
		or	dl,[bx]
		sub	dl,61h
		mov	ah,0Eh
		int	21h
		inc	bx
		inc	bx
@@nodisk:
		xor	cx,cx
@@next:
		mov	al,[bx]
		cmp	al,5Ch
		jne	@@tsteos
		mov	dx,bx
		inc	cx
@@tsteos:
		inc	bx
		or	al,al
		jnz	@@next
		jcxz	@@end
		mov	bx,dx
		push	[word bx]
		mov	[bx],al
		stc
		mov	ax,713Bh		; chdir long filename (ds:dx)
		int	21h
		mov	ah,3Bh			; chdir(ds:dx)
		jnc	@@chdirdone
		int	21h
@@chdirdone:
		pop	[word bx]
@@end:
		ret

        endp    @chdirname$qpzc


;***************************************************************
;_fastcall char *ultoa(unsigned long n);
;***************************************************************
        global  @ultoa$qul:near
        proc    @ultoa$qul near

		xchg	ax,cx
		xchg	ax,dx		; AX:CX = n
		push	si
		mov	si,10
		mov	bx,offset ultoabuf+11
@@loop:
		dec	bx
		xor	dx,dx
		div	si		; DX:AX = 0000:hi(n)
		xchg	ax,cx		; CX = hi(n)/10
		div	si		; DX:AX = hi(n)%10:lo(n)
		xchg	ax,cx		; CX = lo(n/10)
					; AX = hi(n)/10 = hi(n/10)
		mov	[byte bx],'0'
		add	[bx],dl		; DL = n%10
		mov	dx,ax
		or	dx,cx
		jnz	@@loop
		xchg	ax,bx
		pop	si
		ret

        endp    @ultoa$qul


;***************************************************************
;_fastcall unsigned long kver2ul(char *kernel_version);
;***************************************************************
        global  @kver2ul$qpzc:near
        proc    @kver2ul$qpzc near

		push	si
		mov	si,bx
		xor	bx,bx
		mov	cx,304h
@@number:
		xor	ax,ax
		cwd
@@digit:
		shl	al,cl
		shl	ax,cl
		lodsb
		sub	al,30h
		cmp	al,9
		jbe	@@digit
		mov	dl,bh
		mov	bh,bl
		mov	bl,ah
		dec	ch
		jnz	@@number
		xchg	ax,bx
		pop	si
kver2ulret:
		ret

        endp    @kver2ul$qpzc

			endif

;***************************************************************
;void try_default_args();
;_fastcall void set_cmdline(const char *filename);
;***************************************************************
	ifdef	EXTRA

        global  _try_default_args:near
        proc    _try_default_args near

		mov	bx,offset tazboot_cmd
		call	open
		jc	kver2ulret
		mov	cx,4096
		mov	di,[_heap_top]
		extrn	read_cmdline:near
		jmp	near read_cmdline	; read_cmdline(ax,di,cx)
		
        endp    _try_default_args

	endif

        ends    _TEXT

        end

;###### END OF FILE ############################################

