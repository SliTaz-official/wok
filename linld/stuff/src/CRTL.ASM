;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
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
msg_hang	db      "High mem corrupted - not exiting to DOS",0
vcpi_alloc_err	db	"VCPI "
msg_malloc      db      "malloc error",0
	ifdef	EXTRA
tazboot_cmd	db	"tazboot.cmd",0
	endif

        ends    _DATA

        segment _BSS byte public use16 'BSS'

		ifdef EXTRA
;typedef unsigned dirsizetype;
struc		isostate		; struct isostate {
curpos		dw	?		; 0	unsigned curpos;
filename2open	dw	?		; 2	char *filename2open;
fd		dw	?		; 4	int fd;
filemod		dw	?		; 6	unsigned short filemod;
fileofs		dd	?		; 8	unsigned long fileofs;
filesize	dd	?		;12	unsigned long filesize;
filename	dw	?		;16	char *filename;
curdirsize	dw	?		;18	dirsizetype curdirsize;
dirsize		dw	?		;20	dirsizetype dirsize;
curdirofs	dd	?		;22	unsigned long curdirofs;
dirofs		dd	?		;26	unsigned long dirofs;
;overlap
entrysize	dw	?		;30	int entrysize;
tmp		dw	?		;32	const char *tmp;
c		db	?		;34	char c;
_64bits		db	?		;35	char _64bits;
buffer		db	?		;36	char buffer[2048+512];
ends		isostate		; } isostate;
		public	_isostate
_isostate	isostate	<?>
		org	$-7
		endif
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
;_fastcall void strcpy(bx:const char* a, ax:const char* b);
;_fastcall void strcat(bx:const char* a, ax:const char* b);
;_fastcall void strcatb(bx:const char* a, ax:const char* b);
;***************************************************************
	ifdef	EXTRA
        global  @strcat$qpxzct1:near
@strcat$qpxzct1:
		mov	cx,1h
		db	0bah			; mov	dx,imm opcode
	endif
        global  @strcatb$qpxzct1:near
        proc	@strcatb$qpxzct1 near

		mov	cl,7Fh
		db	0bah			; mov	dx,imm opcode
        global	@strcpy$qpxzct1:near
@strcpy$qpxzct1:
		xor	cx,cx
                push	si
                xchg	ax,si			; b
		jcxz	@@nocat
		dec	bx
@@catlp:
                inc	bx
                cmp	[byte bx],0		; a=bx
                jne	@@catlp
	ifdef	EXTRA
		mov	al,20h
		loop	@@cpyhead
	else
		db	0b8h,20h		; mov	ax,??20h
	endif
@@nocat:
@@cpylp:
		lodsb
@@cpyhead:
                mov	[bx],al
                inc	bx
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
;_fastcall int strstr(bx:const char* a, ax:const char* b);
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
;_fastcall int strcmp(bx:const char* a, ax:const char* b);
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
		or	al,[bx]
		jnz	@@lp
@@out:
		cbw
                pop	si
                ret

        endp    @strcmp$qpxzct1
	endif


;***************************************************************
;_fastcall void puts(bx:const char* s):
;***************************************************************
        global  @puts$qpxzc:near

;        global  puts:near			; puts(bx)
@putsz:
		call	@putc
@puts$qpxzc:
puts:
		mov	dl,[bx]
		inc	bx
		or	dl,dl
		jne	@putsz
		mov	dl,10
@putc:
		cmp	dl,10
		jne	@putcz
		call	@putcz2
@putcz2:
		xor	dl,7		; 10^13  1010^1101
@putcz:
		mov	ah,2
		int	21h
		ret


;***************************************************************
;_fastcall int open(bx:const char* name, int flags=O_RDONLY);
;_fastcall int openargs(bx:const char* name, int flags=O_RDONLY);
;***************************************************************
        global  openargs:near			; openargs(bx)
openargs:
		cmp	[byte bx],'@'
		jne	fail
		inc	bx

        global  @open$qpxzc:near
        proc    @open$qpxzc near

open:						; open(bx)
	ifdef	LONG_FILENAME
		mov	ax,716Ch
		push	bx si di
		mov	si,bx
		xor	bx,bx			; R/O
		xor	cx,cx			; attributes
		xor	di,di			; alias hint
		cwd				; action = open
		stc
                int	21h
		pop	di si bx
                jnc	doret
	endif
                mov	ax,3d00h		; read-only+compatibility
		;mov	cl,0			; attribute mask
                mov	dx,bx
		jmp	dos

        endp    @open$qpxzc


;***************************************************************
;_fastcall int fileexist(bx:const char* name);
;***************************************************************
	global	@fileexist$qpxzc:near
@fileexist$qpxzc:
		call	@open$qpxzc
		jc	fail

;***************************************************************
;_fastcall int close(ax:int fd);
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
;_fastcall int readrm(bx:struct himem *m, ax:int sz);
;_fastcall int read(ax:int fd, bx:void* data, dx:int sz);
;_fastcall int write(ax:int fd, bx:const void* data, dx:int sz);
;***************************************************************
        global  @readrm$qp11image_himemi:near
@readrm$qp11image_himemi:
		xchg	ax,dx		; sz
		mov	ax,[bx]		; fd
		mov	bx,[bx-2]	; data
        global  @read$qipvi:near
        proc    @read$qipvi near

		ifdef	WRITE
                stc
		db	0B0h			; mov al,im
        global  @write$qipvi:near
@write$qipvi:
                clc
		endif
@read$dxbxax:
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
dos:
                int	21h
chkc:
                jnc	doret
fail:
		stc
failifc:
                sbb	ax,ax			; ax=-1 CF
		cwd
doret:
		ifndef	NO386
		push	dx			; see next_chunk:lseek
		push	ax
		pop	eax
		endif
                ret

        endp    @read$qipvi

;***************************************************************
;_fastcall long lseekcur(ax:int fd, dx:int whence);
;***************************************************************

        global  @lseekcur$qii:near		; fd=ax whence=dx
        proc    @lseekcur$qii near

		mov	cl,1
		xchg	ax,bx
		xchg	ax,dx
		cwd
		xchg	ax,dx
		xchg	ax,cx
		jmp	lseek
rewind:						; rewind(ax)
		mov	bl,0
lseek0:						; lseek0(ax,bl=dir)
		xor	dx,dx
		xor	cx,cx
lseekset:
		xchg	ax,bx
lseek:
		mov	ah,42h			; bx=fd cx:dx=offset al=whence
		jmp	dos

        endp    @lseekcur$qii

		ifdef EXTRA
;***************************************************************
;_fastcall long isolseek(bx:const unsigned long *offset);
;_fastcall long lseekset2(ax:int fd, bx:unsigned long* whence);
;***************************************************************
        global  @isolseek$qpxul:near
        proc    @isolseek$qpxul near

isolseek:
		mov	ax,[_isostate.fd]
	global	@lseekset2$qipul:near
@lseekset2$qipul:
		les	dx,[dword bx]
		mov	cx,es
		mov	bl,0
		jmp	lseekset

	endp	@isolseek$qpxul

;***************************************************************
;_fastcall int isoreadsector(bx:const unsigned long *offset);
;***************************************************************
        global  @isoreadsector$qpxul:near
        proc    @isoreadsector$qpxul near

		call	isolseek
		jc	doret
		mov	dx,2560
		mov	bx,offset _isostate.buffer
		mov	ax,[_isostate.fd]
		jmp	@read$dxbxax		; read(fd,buffer,2560)

        endp    @isoreadsector$qpxul


;***************************************************************
;_fastcall int isoreset(bx:const char *name);
;***************************************************************
        global  @isoreset$qpzc:near
        proc    @isoreset$qpzc near

		or	bx,bx
		jz	fail
		call	near ptr @open$qpxzc
		mov	[_isostate.fd],ax
		extrn	@isoroot$qv:near
		jmp	@isoroot$qv

	endp	@isoreset$qpzc


;***************************************************************
;_fastcall int isoopen(bx:const char *name);
;***************************************************************
        global  @isoopen$qpxzc:near
        proc    @isoopen$qpxzc near

		extrn	@_isoopen$qv:near
		mov	[_isostate.filename2open],bx
		jmp	@_isoopen$qv

	endp	@isoopen$qpxzc

		endif


		ifdef	USE_ARGSTR
;***************************************************************
;_fastcall int argstr(bx:const char *s, ax:const char keywords[], dx:const char **var);
;_fastcall int argnum(bx:char *s, ax:const char keywords[], dx:unsigned long *var);
;***************************************************************
	global	@argstr$qpxzcxt1ppxzc:near
	proc	@argstr$qpxzcxt1ppxzc near

		mov	cl,2
		db	0a9h			; test	ax,#
	global	@argnum$qpzcxpxzcpul:near
@argnum$qpzcxpxzcpul:
		mov	cl,4
		xchg	ax,bx			; keywords -> bx
		xchg	ax,cx			; s -> cx
		cbw				; argstr:0002 argnum:0004
		xchg	ax,dx			; vars -> ax
		push	si di
		xchg	ax,di			; vars => di
		dec	bx
@@testalt:
		mov	al,-1
		sub	di,dx
@@test:
		cmp	al,'='
		je	@@found
		cmp	al,0			; eos, si=next argv
		je	@@found
		mov	si,cx			; s
		add	di,dx
@@match:
		inc	bx			; keywords++
		lodsb				; *s++
		or	al,20h
		cmp	al,[bx]
		je	@@match
		cmp	al,'/'			; 2f
		jne	@@notopt
		cmp	[byte bx],'-'
		je	@@match
@@notopt:
		ifdef	EXTRA
		cmp	[byte bx],'/'
		je	@@testalt
		endif
		cmp	[byte bx],'|'
		je	@@test
		inc	bx
		cmp	[byte bx-1],0
		jne	@@notopt
		stc
		jmp	@@nokeyword
@@found:
		mov	[di],si
		dec	dx
		dec	dx
		je	@@done
		;mov	bx,si
		call	@strtol$qpxzc
		mov	[di],ax
		mov	[di+2],dx
@@done:
		clc
@@nokeyword:
		sbb	ax,ax
		pop	di si
		ret

	endp	@argstr$qpxzcxt1ppxzc

		else

;***************************************************************
;_fastcall int strhead(bx:const char* a, ax:const char* b);
;***************************************************************
        global  @strhead$qpxzct1:near
        proc    @strhead$qpxzct1 near

@@loop:
		xchg	ax,bx
                mov	cl,[bx]			; cl = *b++
                inc	bx
		or	cl,cl			; clear C
		jz	failifc			; return 0
		xchg	ax,bx
                xor	cl,[bx]			; cl -= *a++
                inc	bx
		and	cl,0dfh			; case insensitive
		jne	fail			; return -1
                jmp	@@loop

	endp	@strhead$qpxzct1

		endif

;***************************************************************
;_fastcall char* strdup(bx:const char* a);
;_fastcall char* malloc_or_die(ax:unsigned size);
;***************************************************************
	global	@strdup$qpxzc:near
@strdup$qpxzc:
strdup:						; ax = strdup(bx)
		mov	ax,[_heap_top]
		xchg	ax,bx
		call	@strcpy$qpxzct1		; bx = strcpy(bx, ax) end +1
		xchg	ax,bx
xchg_heap_top:
		xchg	ax,[_heap_top]
		ret

        global  @malloc_or_die$qui:near
        proc    @malloc_or_die$qui near

        global  malloc_or_die:near		; ax = malloc_or_die(ax)
malloc_or_die:
		mov	bx,offset msg_malloc
		add	ax,[_heap_top]
		jnc	xchg_heap_top

        endp    @malloc_or_die$qui


;***************************************************************
;_fastcall int die(bx:const char* msg);
;int exit();
;int abort();
;***************************************************************
	global	@die$qpxzc:near
	proc	@die$qpxzc near
@die$qpxzc:
        global  die:near			; die(bx)
die:
		call	puts
        global  @exit$qv:near
@exit$qv:
_exit:
		mov	al,[_no_exit]
		or	al,al
		jne	@@hang
                mov	ah,4Ch
                int	21h
@@hang:
		mov	bx, offset msg_hang
		call	puts
;        global  _abort:near
_abort:
		cli
		hlt
		jmp	_abort

	endp	@die$qpxzc

		include	"himem.inc"

;***************************************************************
;static long next_chunk(struct image_himem *di);
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
		mov	bl,02h			; SEEK_END
		call	lseek0
@@die:
		mov	bx,[(image_himem di).errmsg]
		jc	die
		ifndef	NO386
		push	eax
		mov	ax,[(image_himem di).fd]
		call	rewind
		pop	eax
@@end:
		mov	[(image_himem di).chunk_size],eax
		else
		push	ax
		push	dx
		mov	ax,[(image_himem di).fd]
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
ends	data_himem			;}; // size=8200
	endif

;***************************************************************
;_fastcall u32* malloc_bufv_or_die(bx:struct image_himem *m);
;***************************************************************
        global  @malloc_bufv_or_die$qp11image_himem:near
        proc    @malloc_bufv_or_die$qp11image_himem near

                p386
		push	si
		mov	si,bx
	ifdef	LARGE_IMAGES
		movzx	eax,[word ((image_himem si).size) + 2]
		shr	ax,4			; pages index size = size >> 20
		add	ax,8+4096+8
		call	malloc_or_die
		mov	cx,4096+4095		; cnt = 1+(m->size+PAGE_MASK)/PAGE_SIZE;
		add	ecx,[(image_himem si).size]
		shr	ecx,12
		mov	[curdata],ax
	else
		mov	eax,[(image_himem si).size]
		dec	eax
		shr	eax,12
		inc	ax			; cnt = (m->size+PAGE_MASK)/PAGE_SIZE;
		push	ax
		inc	ax			; cnt+1
		shl	ax,2			; bufv => vcpi => vm86
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
;_fastcall void memcpy_image(bx:struct image_himem *m);
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
		les	ax,[dword ((image_himem bx).fallback)]
		mov	dx,es
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
;_fastcall void storepage(bx:u32 *dst);
;***************************************************************
        global  @storepage$qpul:near
        proc    @storepage$qpul near

		ifndef	NO386
		mov	edx,[bx]
		else
		les	ax,[dword bx]
		mov	dx,es
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
;_fastcall void reset_bufv(bx:u32 *p);
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
;_fastcall void open_image(bx:struct image_himem *m, ax:const char *name);
;***************************************************************

        global  @open_image$qp11image_himempxzc:near
        proc    @open_image$qp11image_himempxzc near

                push	di
		xchg	ax,bx
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
		mov	[(image_himem di).next_chunk],offset next_chunk
@@next:
		;push	di
                call	[(image_himem di).next_chunk]	; m->next_chunk()
		;pop	di
		else
@@next:
		call	next_chunk
		endif
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
		ifdef	EXTRA
		;push	di
                call	[(image_himem di).next_chunk]	; m->next_chunk()
		;pop	di
		else
		call	next_chunk
		endif
@@alreadydone:
                pop	di
		ret

        endp    @open_image$qp11image_himempxzc


;***************************************************************
;_fastcall int read_image(bx:struct image_himem *m);
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
		mov	dx,offset _xfer_buf+4096
		sub	dx,si
		mov	bx,[di]
		call	@read$cxdxbx
		jbe	image_done
		xor	cx,cx
		cwd				; ax < 8000h
		ifndef	NO386
		cwde				; ax < 8000h
		sub	[(image_himem di).chunk_size],eax
		xchg	eax,ebx
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
		sub	[(image_himem di).remaining],ebx
		else
		sub	[word (image_himem di).remaining],bx
		sbb	[word ((image_himem di).remaining)+2],dx
		endif
		sub	si,bx
		pushf
		ifdef	EXTRA
                and	cx,[(image_himem di).next_chunk]
		jcxz	@@same_chunk
		push	di
		call	cx
		pop	cx
		else
		jcxz	@@same_chunk
		call	next_chunk
		endif
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
;_fastcall unsigned long strtol(const char *s);
;***************************************************************
		ifndef	USE_ARGSTR
	global	@strtol$qpxzc:near
		endif
	proc	@strtol$qpxzc near

		ifndef	NO386
		ifndef	USE_ARGSTR
		push	si
		mov	si,bx
		endif
		xor	ecx,ecx
		xor	eax,eax
		xor	ebx,ebx
		or	si,si
		jz	@@end
		lodsb
		or	al,20h
		cmp	al,'a'
		jb	@@notvga
		sub	al,'n'
@@vgaloop:
		dec	cx
		add	al,6
		jb	@@vgaloop		; vga=normal,extended,ask
@@vga:
		dec	cx
		xchg	ax,cx
		cwd
		jmp	@@popsiret
@@notvga:
		mov	cx,10			; radix
		cmp	al,'-'
		ja	@@radixkeep
		cmc				; '+'=2B:C=0 '-'=2D:C=1
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
		ifndef	USE_ARGSTR
		pop	si
		endif
		else
		ifndef	USE_ARGSTR
		push	si di
		xor	ax,ax
		cwd
		or	bx,bx
		else
		push	di
		xor	ax,ax
		cwd
		or	si,si
		endif
		jz	@@goend
		xchg	ax,di
		ifndef	USE_ARGSTR
		mov	si,bx
		endif
		lodsb
		or	al,20h
		cmp	al,'a'
		jb	@@notvga
		xor	cx,cx
		sub	al,'n'
@@vgaloop:
		dec	cx
		add	al,6
		jb	@@vgaloop		; vga=normal,extended,ask
@@vga:
		xchg	ax,cx
@@goend:
		jmp	@@popdisiret
@@notvga:
		mov	cx,10			; radix
		cmp	al,'-'
		ja	@@radixkeep
		cmc				; '+'=2B:C=0 '-'=2D:C=1
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
		push	dx
		xchg	ax,bx
		mul	cx
		xchg	ax,bx
		xchg	ax,dx
		xchg	ax,di
		pop	ax
		mul	cx
		add	ax,di
		xchg	ax,dx
		pop	ax
		mov	ah,0
		add	bx,ax
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
		neg	bx
		jne	@@end
		inc	dx
@@end:
		xchg	ax,bx
@@popdisiret:
		ifndef	USE_ARGSTR
		pop	di si
		else
		pop	di
		endif
		endif
strtol_ret:
		ret

	endp	@strtol$qpxzc


		ifdef	USE_ARGSTR
;***************************************************************
;_fastcall void set_cmdline(bx:const char *filename);
;***************************************************************
        global  @set_cmdline$qpxzc:near
        proc	@set_cmdline$qpxzc near
		call	openargs
		jc	strtol_ret
		mov	cx,4096
		mov	di,[_heap_top]
		extrn	read_cmdline:near
		jmp	near read_cmdline	; read_cmdline(ax,di,cx)

        endp	@set_cmdline$qpxzc
		endif


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
;_fastcall char *ultoa(axdx:unsigned long n);
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
;_fastcall unsigned long kver2ul(bx:char *kernel_version);
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

