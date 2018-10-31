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
msg_crlf	db	13,10,0
vcpi_alloc_err	db	"VCPI "
msg_malloc      db      "malloc error",0
	ifdef	EXTRA
tazboot_cmd	db	"tazboot.cmd",0
	endif

        ends    _DATA

        segment _BSS byte public use16 'BSS'

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
;char* strcpy(const char* a, const char* b);
;char* strcat(const char* a, const char* b);
;char* strcatb(const char* a, const char* b);
;***************************************************************
        global  _strcatb:near
        proc    _strcatb near

	ifdef	EXTRA
		mov	cl,7Fh
		db	0bbh			; mov	bx,imm opcode
        global  _strcat:near
_strcat:
		mov	cl,80h
		db	0bbh			; mov	bx,imm opcode
        global  _strcpy:near
_strcpy:
		xor	cx,cx
	endif
		pop	ax			;caller return address
                pop	dx			; a
                pop	bx			; b
                push	bx
                push	dx
                push	ax
                push	si
                mov	si,dx
	ifdef	EXTRA
		jcxz	@@nocat
	endif
@@catlp:
		lodsb
		cmp	al,0
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
		cmp	al,0
                jne	@@cpylp
strfound:
		xchg	ax,dx
strend:
                pop	si
		ret

        endp    _strcatb


	ifdef	EXTRA
                p8086
;***************************************************************
;char strstr(const char* a,const char* b);
;***************************************************************
        global  _strstr:near
        proc    _strstr near

		pop	ax			;caller return address
                pop	dx			; a
                pop	cx			; b
                push	cx
                push	dx
                push	ax
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

        endp    _strstr


;***************************************************************
;int strcmp(const char* a,const char* b);
;***************************************************************
        global  _strcmp:near
        proc    _strcmp near

		pop	cx			;caller return address
                pop	bx			; a
                pop	ax			; b
                push	ax
                push	bx
                push	cx
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

        endp    _strcmp
	endif


;***************************************************************
;void puts(const char* s):
;***************************************************************
        global  _puts:near
        proc    _puts near

		pop	ax			;caller return address
                pop	bx			; s
                push	bx
                push	ax
;        global  puts:near			; puts(bx)
puts:
		call	@@putsz
                mov	bx,offset msg_crlf
		jmp	@@putsz
@@putcz:
		mov	ah,2
		int	21h
@@putsz:
		mov	dl,[bx]
		inc	bx
		or	dl,dl
		jne	@@putcz			; ZF=1  (for malloc failure)
		ret

        endp    _puts


;***************************************************************
;int fileattr(const char* name);
;***************************************************************
        global  _fileattr:near
        proc    _fileattr near

		pop	ax			;caller return address
                pop	dx			; name
                push	dx
                push	ax
                mov	ax,4300h
                int	21h
		xchg	ax,cx
		jmp	chkc

        endp    _fileattr


;***************************************************************
;int open(const char* name, int flags=O_RDONLY);
;***************************************************************
        global  _open:near
        proc    _open near

		pop	ax			;caller return address
                pop	bx			; name
                push	bx
                push	ax
        global  open:near			; open(bx)
open:
                mov	dx,bx
		;mov	cl,0			; attribute mask
                mov	ax,3d00h		; read-only+compatibility
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

        endp    _open


;***************************************************************
;int close(int fd);
;***************************************************************
        global  _close:near
        proc    _close near

		pop	ax			;caller return address
                pop	bx			; fd
                push	bx
                push	ax
        global  close:near			; close(bx)
close:
		mov	ah,3Eh
		or	bx,bx
		jnz	dos
		ret

        endp    _close


;***************************************************************
;int read(int fd, void* data, int sz);
;int write(int fd, const void* data, int sz);
;***************************************************************
        global  _read:near
        proc    _read near

		ifdef	WRITE
                stc
		db	0B0h			; mov al,im
        global  _write:near
                clc
		endif
		pop	ax			;caller return address
                pop	bx			; fd
                pop	dx			; data
                pop	cx			; sz
                push	cx
                push	dx
                push	bx
                push	ax
		ifdef	WRITE
                mov	ah,40h
		sbb	ah,0
		else
                mov	ah,3Fh
		endif
                jcxz	fail
		jmp	dos

        endp    _read

        proc    _lseekset near
		;ifdef EXTRA
;***************************************************************
;long lseekset(int fd, unsigned long sz);
;***************************************************************

        global  _lseekset:near

		pop	ax			;caller return address
                pop	bx			; fd
                pop	dx			; sz lo
                pop	cx			; sz hi
                push	cx
                push	dx
                push	bx
                push	ax
		;endif
;        global  lseekset:near
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

        endp    _lseekset

		ifdef	EXTRA
struc		isostate	; struct isostate {
fd		dw	?	; 0	int fd;
fileofs		dd	?	; 2	unsigned long fileofs;
filesize	dd	?	; 6	unsigned long filesize;
filemod		dw	?	;10	unsigned short filemod;
filename	dw	?	;12	char *filename;
dirofs		dd	?	;14	unsigned long dirofs;
dirsize		dd	?	;16	unsigned long dirsize;
curdirofs	dd	?	;20	unsigned long curdirofs;
curdirsize	dd	?	;24	unsigned long curdirsize;
curpos		dd	?	;28	unsigned long curpos;
ends				; } isostate;
;***************************************************************
;unsigned long isolseek(const unsigned long *offset);
;***************************************************************
        global  _isolseek:near
        proc    _isolseek near

		pop	ax
		pop	bx
		push	bx
		push	ax
		mov	dx,[bx]
		mov	cx,[bx+2]
		extrn	_isostate:isostate
		mov	bx,[_isostate.fd]
		jmp	lseekset		; (bx=fd, sz=cx:dx)
		
        endp    _isolseek
		endif


;***************************************************************
;int strhead(const char* a,const char* b);
;***************************************************************
        global  _strhead:near
        proc    _strhead near

		pop	cx			;caller return address
                pop	bx			; a
                pop	ax			; b
                push	ax
                push	bx
                push	cx
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

        endp    _strhead


;***************************************************************
;char* malloc_or_die(unsigned size);
;***************************************************************
        global  _malloc_or_die:near
        proc    _malloc_or_die near

		pop	ax			;caller return address
                pop	cx			; size
                push	cx
                push	ax
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

        endp    _malloc_or_die


;***************************************************************
;int die(const char* msg);
;int exit();
;int abort();
;***************************************************************
        global  _die:near
        proc    _die near

		pop	ax			;caller return address
                pop	bx			; s
                push	bx
                push	ax
        global  die:near			; die(bx)
die:
		call	puts
;        global  _exit:near
_exit:
		mov	al,[_no_exit]
		cmp	al,0
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

        endp    _die

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
		mov	bx,[(image_himem di).fd]
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
		cmp	al,0
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
;u32* malloc_bufv_or_die(struct image_himem *m);
;***************************************************************
        global  _malloc_bufv_or_die:near
        proc    _malloc_bufv_or_die near

                p386
		pop	bx			;caller return address
		pop	ax
		push	ax
		push	bx
		push	si
		xchg	ax,si
	ifdef	LARGE_IMAGES
		mov	cx,[word ((image_himem si).size) + 2]
		shr	cx,4			; pages index size = size >> 20
		add	cx,8+4096+8
		call	malloc_or_die
		mov	ecx,4096+4095		; cnt = 1+(m->size+PAGE_MASK)/PAGE_SIZE;
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

        endp    _malloc_bufv_or_die


;***************************************************************
; void memcpy_image(struct image_himem *m);
;***************************************************************
        global  _memcpy_image:near
        proc    _memcpy_image near

		pop	ax			;caller return address
		pop	bx
		push	bx
		push	ax
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
		extrn	_memcpy32:near
		call	near _memcpy32
		add	sp,14
@@skip:
		ret

        endp    _memcpy_image

;***************************************************************
;void storepage(u32 *dst, u16 src);
;***************************************************************
        global  _storepage:near
        proc    _storepage near

		pop	ax			;caller return address
		pop	bx
		pop	cx
		push	cx
		push	bx
		push	ax
		ifndef	NO386
		mov	edx,[bx]
		else
		mov	ax,[bx]
		mov	dx,[bx+2]
		endif
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

        endp    _storepage


	ifdef	LARGE_IMAGES
                p386
;***************************************************************
;void reset_bufv(u32 *p);
;***************************************************************
        global  _reset_bufv:near
        proc    _reset_bufv near

		pop	bx			;caller return address
		pop	ax
		push	ax
		push	bx
		mov	[curdata],ax
		and	[dword (data_himem bx).cacheidx],0
		ret

        endp    _reset_bufv

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
		sbb	ax,ax
		stc
		rcl	ax,1			; -1/+1
		xor	ecx,ecx
		push	si
		mov	si,[curdata]
		add	ax,[(data_himem si).cacheidx]
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
;void open_image(const char *name, struct image_himem *m);
;***************************************************************
        global  _open_image:near
        proc    _open_image near

		pop	cx			;caller return address
		pop	bx			; name
		pop	ax			; m
		push	ax
		push	bx
		push	cx
                push	di
		xchg	ax,di
		mov	[(image_himem di).next_chunk],offset next_chunk
                mov	[(image_himem di).state],bx
		push	bx
@@next:
                call	[(image_himem di).next_chunk]	; m->next_chunk()
		ifndef	NO386
		add	eax,3
		and	al,0FCh
		add	[(image_himem di).size],eax	; m->size += m->chunk_size
		or	eax,eax
		jnz	@@next
		else
		mov	cx,ax
		or	cx,dx
		add	ax,3
		adc	dx,0
		and	al,0FCh
		add	[word (image_himem di).size],ax	; m->size += m->chunk_size
		adc	[word ((image_himem di).size)+2],dx
		inc	cx			; jcxnz
		loop	@@next
		endif
                pop	[(image_himem di).state]
                call	[(image_himem di).next_chunk]	; m->next_chunk()
                pop	di
		ret

        endp    _open_image


;***************************************************************
;int read_image(struct image_himem *m, char* data, int sz);
;***************************************************************
        global  _read_image:near
        proc    _read_image near

		arg	m	:word,	\
			data	:word,	\
			sz	:word	= PARAM_SIZE

		push	bp
		mov	bp,sp
		push	di
		ifndef	NO386
		push	0		; return value
		else
		xor	ax,ax
		push	ax
		endif
		mov	di,[m]
@@loop:
		ifndef	NO386
		movzx	ecx,[word sz]
		mov	eax,[(image_himem di).chunk_size]
		cmp	ecx,eax
		jb	@@szok
		else
		mov	cx,[word sz]
		mov	ax,[word (image_himem di).chunk_size]
		cmp	cx,ax
		jb	@@szok
		cmp	[word ((image_himem di).chunk_size)+2],0	; hi m->chunk_size
		jne	@@szok
		endif
		xchg	ax,cx
@@szok:
		jcxz	image_done
		push	cx
		push	[word data]
		push	[word di]
		call	_read
		pop	dx
		pop	bx
		pop	cx
		jc	image_done
		add	bx,ax
		xor	cx,cx
		ifndef	NO386
		cwde				; ax < 8000h
		sub	[(image_himem di).chunk_size],eax
		else
		cwd				; ax < 8000h
		sub	[word (image_himem di).chunk_size],ax
		sbb	[word ((image_himem di).chunk_size)+2],dx
		jnz	@@fill
		cmp	[word (image_himem di).chunk_size],dx
		endif
		jnz	@@fill
		dec	cx
@@fill:
		test	al,3
		je	@@filled
		mov	[bx],dh
		inc	bx
		inc	ax
		jmp	@@fill
@@filled:
		ifndef	NO386
		sub	[(image_himem di).remaining],eax
		else
		sub	[word (image_himem di).remaining],ax
		sbb	[word ((image_himem di).remaining)+2],dx
		endif
		add	[bp-2-2],ax
		add	[word data],ax
		sub	[word sz],ax
		pushf
		jcxz	@@same_chunk
                call	[(image_himem di).next_chunk]
@@same_chunk:
		popf
		jnz	@@loop
image_done:
                pop	ax
                pop	di bp
		ret

        endp    _read_image


;***************************************************************
;unsigned long strtol(const char *s);
;***************************************************************
        global  _strtol:near
        proc    _strtol near

		ifndef	NO386
		pop	ax			;caller return address
                pop	cx			; s
		push	cx
		push	ax
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
		pop	ax			;caller return address
                pop	cx			; s
		push	cx
		push	ax
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
		ret

        endp    _strtol


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
;void chdirname(char *path)
;***************************************************************
        global  _chdirname:near
        proc    _chdirname near

		pop	ax
		pop	bx
		push	bx
		push	ax

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

        endp    _chdirname


;***************************************************************
;char *ultoa(unsigned long n);
;***************************************************************
        global  _ultoa:near
        proc    _ultoa near

		pop	ax
		pop	cx
		pop	dx
		push	dx
		push	cx
		push	ax		; DX:CX = n
		push	si
		mov	si,10
		mov	bx,offset ultoabuf+11
@@loop:
		dec	bx
		xchg	ax,dx
		xor	dx,dx
		div	si		; DX:AX = 0000:hi(n)
		xchg	ax,cx		; CX = hi(n)/10
		div	si		; DX:AX = hi(n)%10:lo(n)
		xchg	ax,cx		; CX = lo(n/10)
		xchg	ax,dx		; DX = hi(n)/10 = hi(n/10)
		add	al,'0'
		mov	[bx],al
		mov	ax,cx
		or	ax,dx
		jnz	@@loop
		xchg	ax,bx
		pop	si
		ret

        endp    _ultoa


;***************************************************************
;unsigned long kver2ul(char *kernel_version);
;***************************************************************
        global  _kver2ul:near
        proc    _kver2ul near

		pop	bx
		pop	ax
		push	ax
		push	bx
		push	si
		xchg	ax,si
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

        endp    _kver2ul


;***************************************************************
;void try_default_args();
;***************************************************************
        global  _try_default_args:near
        proc    _try_default_args near

		mov	bx,offset tazboot_cmd
		call	open
		jc	kver2ulret
		mov	cx,4096
		mov	di,[_heap_top]
		push	cx
		extrn	read_cmdline:near
		jmp	near read_cmdline	; read_cmdline(ax,di,cx)
		
        endp    _try_default_args

			endif

        ends    _TEXT

        end

;###### END OF FILE ############################################

