;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 255
                %crefref
                %noincl
                %nomacs

	include	"common.inc"

		ifdef	NO386
                p8086
		else
                p386
		endif

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'

loaderr		db	"Load failure",0
msg_hang	db      "Himem broken",0
		ifdef	VCPI
vcpi_alloc_err	db	"VCPI"
		endif
		global	overflow:byte
overflow	db	"/"
msg_malloc      db      "Out of memory"
isorootofs	dd	16*2048

        ends    _DATA

        segment _BSS byte public use16 'BSS'

		ifdef	ISO9660
		global	_buf2k:byte
label	_buf2k	byte
		db	2048	dup (?)
		endif
		global	_buf4k:byte
label	_buf4k	byte
		db	4096	dup (?)

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

		ifdef	VCPI
                p386
;***************************************************************

struc   data_himem			;struct data_himem {
first		dd	?		;   0  u32 first;	*must* be the first one	assume zero'd in bss
cacheidx	dw	?		;   4  int cacheidx;	quad *			assume zero'd in bss
pageidx		dw	?		;   6  int pageidx;	byte *			assume zero'd in bss
cache		dd	1024 dup(?)	;   8  int cache;
page		dd	1024 dup(?)	;4104  int page;
ends	data_himem			;};

		include	"himem.inc"

;***************************************************************
;_fastcall u32* malloc_bufv_or_die(si:struct image_himem *m);
;***************************************************************
        global  @malloc_bufv_or_die$qp11image_himem:near
        proc    @malloc_bufv_or_die$qp11image_himem near

                p386
		;mov	ecx,[(image_himem si).size]
		;shr	ecx,20			; pages index size = size >> 20
		;mov	ax,cx
		;add	ax,size data_himem-4096
		mov	ax,size data_himem
		call	malloc_or_die
		;mov	cx,4096+4095		; cnt = 1+(m->size+PAGE_MASK)/PAGE_SIZE;
		mov	ecx,4096+4095		; cnt = 1+(m->size+PAGE_MASK)/PAGE_SIZE;
		add	ecx,[(image_himem si).size]
		shr	ecx,12
		mov	[(image_himem si).bufv],ax	; update m->bufv
		xchg	ax,di
@@vcpi_alloc:
                mov     ax,0DE04h		; allocate a 4K page => EDX
                int     67h
		or	ah,ah
		mov	bx,offset vcpi_alloc_err
		jnz	jmpdie
; for (i = cnt-1; i >= 0; i--)
; if (edx < pm.fallback+pm.size) again
		mov	bx,offset _imgs.fallback+size image_himem
		mov	eax,[bx-2+6-size image_himem]	; pm.size
		add	eax,[bx-2+2-size image_himem]
		cmp	eax,edx		; pm.fallback+pm.size <= edx ?
		ja	@@vcpi_alloc
		mov	eax,ecx
		dec	eax
		shl	eax,12		; i*_4k
; if (edx >= initrd.fallback+i*_4k && edx < initrd.fallback+initrd.size) again
		add	eax,[bx-2+2]	; +initrd.fallback
		cmp	eax,edx		; initrd.fallback+i*_4k > edx ?
		ja	@@initrdok
		mov	eax,[bx-2+6]	; initrd.size
		add	eax,[bx-2+2]	; +initrd.fallback
		cmp	eax,edx		; initrd.fallback+initrd.size > edx ?
@@ja_vcpi_alloc:
		ja	@@vcpi_alloc
@@initrdok:
		cmp	[(data_himem di).first],0	; zero'd in bss
		jne	@@notfirst
		mov	[(data_himem di).first],edx
@@notfirst:
		mov	bx,[(data_himem di).cacheidx]	; zero'd in bss
		cmp	bh,4
		jae	@@nextpage
		shl	bx,2
		inc	[(data_himem di).cacheidx]
		mov	[(data_himem bx+di).cache],edx	; cache[cacheidx++] = edx
		loopd	@@vcpi_alloc
		mov	[(data_himem bx+di).cache],ecx	; last is 0
@@nextpage:
		and	[(data_himem di).cacheidx],0
		mov	bx,[(data_himem di).pageidx]	; zero'd in bss
		mov	[(data_himem bx+di).page],edx
		add	[(data_himem di).pageidx],4
		push	cx
		lea	cx,[(data_himem di).cache]
		ifdef	NO386
		push	edx
		pop	ax			; to es:ax
		pop	es
		endif
		call	storepage		; storepage(edx/es:ax,cx)	
		pop	cx
		or	ecx,ecx			; clear C
		jnz	@@ja_vcpi_alloc

        endp    @malloc_bufv_or_die$qp11image_himem

;***************************************************************
;_fastcall void reset_bufv(di:u32 *p);
;***************************************************************
        global  @reset_bufv$qpul:near
        proc    @reset_bufv$qpul near

		mov	[curdata],di
		and	[dword (data_himem di).cacheidx],0	; and pageidx=0
		ret

        endp    @reset_bufv$qpul

;***************************************************************
;u32* di=prev_bufv();
;u32* di=prev_bufv();
;***************************************************************
        global  _prev_bufv:near
        global  _next_bufv:near
        proc    _prev_bufv near

		stc
		db	73h			; jnc
_next_bufv:
		clc
		push	si
		mov	bx,0
		org	$-2
curdata		dw	?
		sbb	ax,ax
		cmc
		adc	ax,[(data_himem bx).cacheidx]	; -1/+1
		mov	si,3ffh
		and	si,ax
		mov	[(data_himem bx).cacheidx],si
		shl	si,2
		xor	ecx,ecx
		test	ax,0fc00h
		jz	@@gotpage		; FFFF / 0400
		xchg	al,ah			; FFFC / 0004
		and	al,0fch
		add	[(data_himem bx).pageidx],ax
		mov	di,[(data_himem bx).pageidx]
		lea	di,[(data_himem bx+di).page]
		mov	edx,ds
		shl	edx,4
		lea	cx,[(data_himem bx).cache]		
		add	edx,ecx
		mov	eax,[di]
		or	eax,eax
		jz	@@ret
		mov	cx,4096			; get page
		call	memcpy_imagez		; memcpy_imagez(edx,eax,ecx)
@@gotpage:
		lea	ax,[(data_himem bx+si).cache]		
		or	si,[(data_himem bx).pageidx]	; !pageidx && !cacheidx
		jnz	@@notfirst2
		xchg	ax,bx				; &first
@@notfirst2:
		xchg	ax,di
@@ret:
		pop	si
		ret

        endp    _prev_bufv
		endif

		ifdef	NO386
                p8086
		endif

;***************************************************************
;_fastcall void memcpy_image_initrd(si:struct image_himem *m);
;_fastcall void memcpy_image_kernel(si:struct image_himem *m);
;_fastcall void memcpy_image(bx:struct image_himem *m);
;***************************************************************
	global	@memcpy_image_initrd$qv:near
@memcpy_image_initrd$qv:
		lea	bx,[si+size image_himem]
		db	0A9h			; test	ax,imm
	global	@memcpy_image_kernel$qv:near
@memcpy_image_kernel$qv:
		mov	bx,si
        proc    @memcpy_image$qp11image_himem near

		ifndef	NO386
		mov	edx,[(image_himem bx).fallback]
		mov	eax,[(image_himem bx).buf]
		cmp	eax,edx			; if (m->fallback != m->buf)
		jz	@@skip			;   memcpy32(m->fallback,0,m->buf,m->size)
		mov	ecx,[(image_himem bx).size]
		else
		les	cx,[((image_himem bx).buf)]
		mov	dx,es
		les	ax,[((image_himem bx).fallback)]
		cmp	ax,cx			; if (m->fallback != m->buf)
		jnz	@@do
		cmp	dx,[word ((image_himem bx).fallback)+2]
		jz	@@skip			;   memcpy32(m->fallback,0,m->buf,m->size)
@@do:
		push	[((image_himem bx).size)]
		xor	bx,bx
call_memcpy32:					; call_memcpy32(to=es:ax,fromseg=bx,fromofs=dx:cx,size)
		push	dx			; [word ((image_himem bx).buf)+2]
		push	cx			; [word ((image_himem bx).buf)]
		push	bx
		push	es			; push es:ax
		push	ax
		jmp	@@memcpy
		endif
memcpy_imagez:					; memcpy_imagez(edx,eax,ecx)
		p386
		push	ecx
		push	eax
		push	0
		ifndef	NO386
call_memcpy32:					; call_memcpy32(to=edx,fromseg,fromofs,size)
		endif
		push	edx
		ifdef	NO386
                p8086
		endif
@@memcpy:
		extrn	memcpy32:near
		call	near memcpy32
@@skip:
		ret

		global	movedend:near
movedend:

        endp    @memcpy_image$qp11image_himem

;***************************************************************
;_fastcall void storepage(di:u32 *dst);
;***************************************************************
        global  @storepage$qpul:near
        proc    @storepage$qpul near

		ifndef	NO386
		mov	edx,[di]
		else
		les	ax,[dword di]
		endif
		mov	cx,offset _buf4k
storepage:					; storepage(edx,cx)
		ifndef	NO386
		push	0
		push	4096
		push	0
		push	cx
		push	ds			; call_memcpy32(to=edx,fromseg,fromofs,size)
		else
		xor	dx,dx
		push	dx			; 0
		mov	bx,4096
		push	bx			; 4096
		mov	bx,ds			; call_memcpy32(to=es:ax,fromseg=bx,fromofs=dx:cx,size)
		endif
		jmp	call_memcpy32

        endp    @storepage$qpul

;***************************************************************
;_fastcall void strcatb(bx:const char* a, ax:const char* b);
;***************************************************************
        global  @strcatb$qpxzct1:near
        proc	@strcatb$qpxzct1 near

                push	si
                xchg	ax,si			; b
		dec	bx
@@catlp:
                inc	bx
                cmp	[byte bx],0		; a=bx
                jne	@@catlp
		db	0b8h,20h		; mov	ax,??20h
@@cpylp:
		lodsb
                mov	[bx],al
                inc	bx
		or	al,al
                jne	@@cpylp
                pop	si
catret:
		ret

        endp	@strcatb$qpxzct1


		ifdef	NO386
                p8086
		endif

	ifndef ISO9660
;***************************************************************
;_fastcall int:C open(bx:const char* name, int flags=O_RDONLY);
;_fastcall int:C openargs(bx:const char* name, int flags=O_RDONLY);
;***************************************************************
        global  openargs:near			; openargs(bx)
openargs:
		cmp	[byte bx],'@'
		jne	fail
		inc	bx

        global  @open$qpxzc:near
@open$qpxzc:
	endif
opendos:
	ifdef	LONG_FILENAME
		;xchg	ax,cx			; attributes
		mov	ax,716Ch
		push	bx si
		mov	si,bx
		xor	bx,bx			; R/O
		cwd				; action = open
		stc
                int	21h
		pop	si dx
                jnc	openok
                mov	ax,3d00h		; read-only+compatibility
	else
                mov	ah,3dh			; read-only+compatibility
                mov	dx,bx			; open(DS:DX=filename,al=access,cl=attributes)
	endif
		;mov	cl,0			; attribute mask
		call	dos
	ifdef ISO9660
		jc	catret
openok:
		xchg	ax,bx
		mov	ax,4202h
		cwd
		xor	cx,cx
                int	21h
		mov	[word _isostate.filesize],ax
		mov	[(word _isostate.filesize)+2],dx
		xchg	ax,bx
		;xor	cx,cx
		cwd
		call	seeksetpos0		; filepos = 0
	else
openok:
	endif
		xchg	ax,bx			; fd
		ret

	ifdef ISO9660

		include	"isostate.inc"
		extrn	_isostate:isostate

;***************************************************************
;_fastcall int:C open(bx:const char* name, int flags=O_RDONLY);
;_fastcall int:C openargs(bx:const char* name, int flags=O_RDONLY);
;***************************************************************
        global  openargs:near			; openargs(bx)
openargs:
		cmp	[byte bx],'@'
		jne	fail
		inc	bx

        global  @open$qpxzc:near
@open$qpxzc:
		ifdef	LONG_FILENAME
		mov	cx,[_isostate.fd]
		jcxz	opendos
		xchg	ax,cx
		else
		mov	ax,[_isostate.fd]
		or	ax,ax
		je	opendos
		endif
		ifdef ISOHOOK
		cmp	[byte bx],'!'
		je	@readmenu$qv
		endif
		extrn	@_isoopen$qv:near
		mov	[word _isostate.filename2open],bx
		jmp	@_isoopen$qv		; filepos = 0
	endif


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
		mov	bh,3Eh			; close(BX:handle)
	ifdef ISO9660
		mov	cx,[_isostate.fd]
		jcxz	dosbx
	endif
		jmp	fail

        endp    @close$qi


;***************************************************************
;_fastcall int readrm(si:struct himem *m, ax:int sz);
;***************************************************************
        global  @readrm$qp11image_himemi:near
@readrm$qp11image_himemi:
		xchg	ax,dx		; sz
		mov	ax,[si]		; fd
		mov	bx,[si-2]	; data
        proc    @read$qipvi near

@read$dxbxax:
		xchg	ax,bx			; fd
@read$dxaxbx:
		xchg	ax,dx			; data
		xchg	ax,cx			; sz
	global	@read$cxdxbx:near
@read$cxdxbx:
	ifdef ISO9660
		push	bx
		mov	bx,offset _isostate.filepos
		push	cx
		mov	cx,[bx-4]		; filesize
		sub	cx,[bx]			; filepos
		mov	ax,[bx-2]
		sbb	ax,[bx+2]
		pop	ax
		ja	@@axok
		;je	@@rem
		;xor	ax,ax
@@rem:
		cmp	cx,ax
		jb	@@cxok
@@axok:
		xchg	ax,cx
@@cxok:
		add	[bx],cx
		adc	[(word bx)+2],0
		pop	bx
	endif
readfd:
                mov	ah,3Fh			; read(BX=handle,DS:DX=to,CX=count)
                ;jcxz	fail
dos:
                int	21h
                jnc	doret
fail:
		stc
failifc:
                sbb	ax,ax			; ax=-1 CF
doret:
                ret

        endp    @read$qipvi

;***************************************************************
;_fastcall long rewind(ax:int fd);
;***************************************************************

        global  @rewind$qi:near			; fd=ax
        proc    @rewind$qi near

rewind:
	ifdef ISO9660
		mov	bx,offset _isostate.fileofs
		jmp	lseek
	else
		mov	bl,0
lseek0:
		xor	cx,cx
		xor	dx,dx
		jmp	lseek
	endif

        endp    @rewind$qi


		ifdef ISOHOOK
;***************************************************************
;_fastcall int:bx readmenu(void);
;***************************************************************
	proc	@readmenu$qv near

		mov	dx,20
		xor	cx,cx
		call	seeksetpos0		; filepos = 0
		mov	dx,offset _isostate.fileofs
		mov	cl,8
		push	dx
		call	readfd ; // read x->fileofs & x->filesize
		pop	bx
		; x->fileofs = 0x7FF0 - (x->filesize &= 0xFFFF);
		mov	ax,7FF0h		; old way : up to md5 signature
@@oldway:
		xor	ax,6FF0h		; new way : between Apple partitions = up to 1000h
		neg	word ptr [bx+4]		; fix x->filesize
		js	@@oldway
		cwd
		mov	[word bx+6],dx
		sub	ax,[bx+4]
		mov	[word bx+2],dx
		mov	[bx],ax
		call	isolseek		; filepos = 0
		xchg	ax,bx			; fd
		ret

	endp	@readmenu$qv
		endif

;***************************************************************
;_fastcall void isolseek(bx:const unsigned long *offset);
;***************************************************************
        global  @isolseek$qpxul:near
        proc    @isolseek$qpxul near

	ifdef ISO9660
isolseek:
		mov	ax,[_isostate.fd]
lseek:
		les	dx,[dword bx]
		mov	cx,es
seeksetpos0:
		xor	bx,bx
		mov	[word _isostate.filepos],bx
		mov	[(word _isostate.filepos)+2],bx
	else
lseek:
	endif
		mov	bh,42h			; bx=fd cx:dx=offset al=whence
dosbx:
		xchg	ax,bx
		jmp	dos			; bx = fd

	endp	@isolseek$qpxul

	ifdef ISO9660
;***************************************************************
;_fastcall int isoreadsector(bx:const unsigned long *offset);
;_fastcall int isoreadrootsector(void);
;***************************************************************
        global  @isoreadrootsector$qv:near
@isoreadrootsector$qv:
		mov	bx,offset isorootofs
        global  @isoreadsector$qpxul:near
        proc    @isoreadsector$qpxul near

		call	isolseek		; filepos = 0
		jc	fail
		mov	cx,2048
		mov	dx,offset _buf2k
		jmp	readfd			; read(fd,buf2k,2048)

        endp    @isoreadsector$qpxul
	endif


	ifdef ISO9660
		ifdef ISOHOOK
;***************************************************************
;_fastcall int strhead(ax:const char* a, bx:const char* b);
;***************************************************************
        global  @strhead$qpxzct1:near
        proc    @strhead$qpxzct1 near

@@loop:
                mov	dh,[bx]			; dh = *b++
                inc	bx
		xchg	ax,bx
		or	dh,dh			; clear C
		jz	failifc			; return 0, bx=a tail, dh=0
                xor	dh,[bx]			; dh -= *a++
		jne	fail			; return -1
                inc	bx
		xchg	ax,bx
                jmp	@@loop

	endp	@strhead$qpxzct1


;***************************************************************
;_fastcall int strcmp(ax:const char* a, bx:const char* b);
;***************************************************************
        global  @strcmp$qpxzct1:near
        proc    @strcmp$qpxzct1 near

		call	@strhead$qpxzct1
		jne	fail			; return -1
		xor	dh,[bx]			; clear C
		jne	fail			; return -1
		jmp	failifc			; return 0, dh=0

        endp    @strcmp$qpxzct1

		else

;***************************************************************
;_fastcall int strcmp(bx:const char* a, ax:const char* b);
;***************************************************************
        global  @strcmp$qpxzct1:near
        proc    @strcmp$qpxzct1 near

@@loop:
		xchg	ax,bx
                mov	dl,[bx]			; dl = *b++
                inc	bx
		xchg	ax,bx
                xor	dl,[bx]			; dl ^= *a++
	    ifndef RAW_ISO9660
		ifndef  ROCKRIDGE
		and	dl,0dfh			; case insensitive
		endif
	    endif
		jne	fail			; return -1
                inc	bx
		or	dl,dl			; clear C
		jz	failifc			; return 0
                jmp	@@loop

        endp    @strcmp$qpxzct1
		endif
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
do_int21h:
		int	21h
		ret


;***************************************************************
;_fastcall char* malloc_or_die(ax:unsigned size);
;***************************************************************
xchg_heap_top:
		xchg	ax,[bx]
		ret

        proc    @malloc_or_die$qui near

malloc_or_die: 				; ax = malloc_or_die(ax)
		extrn	_heap_top
		mov	bx,offset _heap_top
		add	ax,[bx]
		jnc	xchg_heap_top
		mov	bx,offset msg_malloc

        endp    @malloc_or_die$qui


;***************************************************************
;_fastcall int die(bx:const char* msg);
;int exit(ax:int status);
;int abort(void);
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
		extrn	_imgs:image_himem
		mov	cx,[(word _imgs.buf)+2]	; no_exit ?
                mov	ah,4Ch
		jcxz	do_int21h
		mov	bx, offset msg_hang
		call	puts
;        global  _abort:near
_abort:
		cli
		hlt
		jmp	_abort

	endp	@die$qpxzc

;***************************************************************
;_fastcall void open_image(si:struct image_himem *m, ax:const char *name);
;***************************************************************

        global  @open_image$qp11image_himempxzc:near
        proc    @open_image$qp11image_himempxzc near

                mov	[(image_himem si).state],ax
		push	ax
@@next:
		call	next_chunk
		ifndef	NO386
		add	eax,3
		and	al,0FCh
		add	[(image_himem si).size],eax	; m->size += m->chunk_size	size zero'd in bss
		or	eax,eax
		else
		add	ax,3
		adc	dx,0
		and	al,0FCh
		add	[word (image_himem si).size],ax	; m->size += m->chunk_size	size zero'd in bss
		adc	[word ((image_himem si).size)+2],dx
		or	ax,dx
		endif
		jnz	@@next
                pop	[(image_himem si).state]

        endp    @open_image$qp11image_himempxzc


;***************************************************************
;static long next_chunk(struct image_himem *si);
;***************************************************************
        proc    next_chunk near

		ifndef	NO_CLOSE
		mov	ax,[(image_himem si).fd]
		call	close
		endif
		ifndef	NO386
		xor	eax,eax
		else
		xor	ax,ax
		cwd
		endif
		mov	[(image_himem si).fd],ax
		mov	bx,[(image_himem si).state]
		cmp	al,[bx]			; ""
		jz	@@end
		dec	bx
		push	di
@@scan:
		inc	bx
		mov	al,[bx]
		mov	di,bx
		or	al,al
		jz	@@eos
		sub	al,','
		jnz	@@scan
		inc	bx
@@eos:
		xchg	[(image_himem si).state],bx	; set start of string
		mov	[current_file],bx
		xchg	[di],ax			; set temp eos (ax == 0)
		push	ax
		call	@open$qpxzc
		pop	[word di]		; restore string
		pop	di
		jnc	@@opened
loadfailure:
;***************************************************************
;_fastcall void loadfailure(void);
;***************************************************************
	global	@loadfailure$qv:near
@loadfailure$qv:
		mov	bx,0
		org	$-2
current_file	dw	?
		call	puts
		mov	bx,offset loaderr
jmpdie:
		jmp	die
@@opened:
		mov	[(image_himem si).fd],ax
		ifndef	NO_CLOSE
		mov	[(image_himem si).fd2close],ax
		endif
	ifdef ISO9660
		ifndef	NO386
		mov	eax,[_isostate.filesize]
		else
		les	ax,[_isostate.filesize]
		mov	dx,es
		endif
	else
		mov	bl,02h			; SEEK_END
		call	lseek0
		ifndef	NO386
		push	eax
		mov	ax,[(image_himem si).fd]
		call	rewind
		pop	eax
		else
		push	ax
		push	dx
		mov	ax,[(image_himem si).fd]
		call	rewind
		pop	dx
		pop	ax
		endif
	endif
@@end:
		ifndef	NO386
		mov	[(image_himem si).chunk_size],eax
		else
		mov	[word (image_himem si).chunk_size],ax
		mov	[word ((image_himem si).chunk_size)+2],dx
		endif
		ret

        endp    next_chunk


;***************************************************************
;_fastcall int read_image(si:struct image_himem *m);
;***************************************************************
        global  @read_image$qp11image_himem:near
        proc    @read_image$qp11image_himem near

		push	di
		xor	di,di
@@loop:
		ifndef	NO386
		xor	ecx,ecx
		mov	ch,4096/256
		sub	cx,di
		mov	eax,[(image_himem si).chunk_size]
		cmp	ecx,eax
		jb	@@szok
		else
		mov	cx,4096
		sub	cx,di
		mov	ax,[word (image_himem si).chunk_size]
		cmp	cx,ax
		jb	@@szok
		cmp	[word ((image_himem si).chunk_size)+2],0	; hi m->chunk_size
		jne	@@szok
		endif
		xchg	ax,cx
@@szok:
		jcxz	image_done
		lea	dx,[di+_buf4k]
		mov	bx,[(image_himem si).fd]
		call	@read$cxdxbx
		jb	image_done
		add	di,ax
		ifndef	NO386
		cwde				; ax < 8000h
		cdq
		sub	[(image_himem si).chunk_size],eax
		else
		cwd				; ax < 8000h
		sub	[word (image_himem si).chunk_size],ax
		sbb	[word ((image_himem si).chunk_size)+2],dx
		endif
@@fill:
		test	al,3
		je	@@filled
		mov	[di+_buf4k],dl
		inc	di
		inc	ax
		jmp	@@fill
@@filled:
		ifndef	NO386
		sub	[(image_himem si).remaining],eax
		or	edx,[word (image_himem si).chunk_size]
		else
		sub	[word (image_himem si).remaining],ax
		sbb	[word ((image_himem si).remaining)+2],dx
		mov	ax,[word (image_himem si).chunk_size]
		or	ax,[word ((image_himem si).chunk_size)+2]
		endif
		jnz	@@same_chunk
		call	next_chunk
@@same_chunk:
		jmp	@@loop
image_done:
		xchg	ax,di
                pop	di
		ret

        endp    @read_image$qp11image_himem

;***************************************************************
;_fastcall const char **argstr(bx:const char *s, ax:const char keywords[], dx:const char **var);
;_fastcall unsigned long *argnum(bx:char *s, ax:const char keywords[], dx:unsigned long *var);
;***************************************************************
	global	@argstr$qpxzcxt1ppxzc:near
	proc	@argstr$qpxzcxt1ppxzc near

		mov	cl,2
		db	0a9h			; test	ax,#
	global	@argnum$qpzcxpxzcpul:near
@argnum$qpzcxpxzcpul:
		mov	cl,4
		push	bx
		xchg	ax,bx			; keywords -> bx
		xchg	ax,cx			; s -> cx
		cbw				; argstr:0002 argnum:0004
		xchg	ax,dx			; vars -> ax
		push	si di
		xchg	ax,di			; vars => di
		dec	bx
		sub	di,dx
@@loop:
		add	di,dx
		mov	si,cx			; s
@@match:
		lodsb				; *s++
		or	al,20h			; locase
		cmp	al,'/'			; 2f
		jne	@@notopt
		mov	al,'-'
@@notopt:
		inc	bx			; keywords++
		cmp	al,[bx]
		je	@@match
		cmp	[byte bx],dh
		je	@@lastal
		cmp	[byte bx],'|'
		je	@@testal
		jl	@@notsw			; } ~ <del>
		;mov	dl,1
		cmp	al,20h			; EOS or 20h
		jne	@@loop			; assume [bx] = '|'
@@notsw:
		mov	al,-1
		jne	@@notopt
		jmp	@@setnum2
@@testal:
		cmp	al,-1
		jz	@@loop
@@lastal:
		cmp	al,'='
		xchg	ax,cx			; return s if failure
		jne	@@nokeyword
		dec	dx
		dec	dx
		je	@@done
@strtol$qpxzc:
		ifndef	NO386
		xor	ecx,ecx
		xor	ebx,ebx
		else
		xor	bx,bx
		xor	cx,cx
		xor	dx,dx
		endif
		lodsb
		or	al,20h
		cmp	al,'a'
		jb	@@notvga
		sub	al,'o'
@@vgaloop:
		dec	cx
		add	al,6
		jnb	@@vgaloop		; vga=normal,extended,ask
@@vga:
		xchg	ax,cx
		;cwd
		jmp	@@end
@@endstrtol:
		mov	cl,10
		cmp	al,'k'-'a'+10
		je	@@shift
		mov	cl,20
		cmp	al,'m'-'a'+10
		je	@@shift
		mov	cl,30
		cmp	al,'g'-'a'+10
		ifndef	NO386
		jne	@@noshift
@@shift:
		shl	ebx,cl
@@noshift:
		popf
		jnc	@@end2
		neg	ebx
@@end2:
		push	ebx
		pop	ax
		pop	dx
		else
@@shift:
		xchg	ax,bx
		jne	@@noshift
		extrn	N_LXLSH@:near
		call	N_LXLSH@
@@noshift:
		popf
		jne	@@end
		not	dx
		neg	ax
		jne	@@end
		inc	dx
		endif
@@end:
@@setnum:
		mov	[di+2],dx
@@setnum2:
		xchg	ax,si
@@done:
		or	[di],si
		xchg	ax,di
@@nokeyword:
		pop	di si bx
		ret

@@notvga:
		mov	cl,10			; radix
		cmp	al,'-'
		jne	@@radixkeep
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
		cbw
		ifndef	NO386
		cwde
		xchg	eax,ebx
		mul	ecx
		add	ebx,eax
		else
		push	ax
		xchg	ax,dx
		mul	cx
		xchg	ax,bx
		mul	cx
		add	dx,bx
		pop	bx
		add	bx,ax
		adc	dx,0
		endif
		jmp	@@strtollp

	endp	@argstr$qpxzcxt1ppxzc


        ends    _TEXT

        end

;###### END OF FILE ############################################

