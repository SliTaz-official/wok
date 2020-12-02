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

        segment _TEXT byte public use16 'CODE'
        ends    _TEXT

        segment _DATA byte public use16 'DATA'
        ends    _DATA

        segment _BSS byte public use16 'BSS'

		include	"isostate.inc"

		public	_isostate
_isostate	isostate	<?>
;		org	$-7

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

		global	fold:near
fold:
		org	130h-100h
	        global  _cpu_features:dword
_cpu_features	dd	?
		org	0F000h-100h
		global	unfold:near
unfold:
		jmp	iso_open
		extrn	@isoreaddir$qv
		dw	@isoreaddir$qv
		jmp	@readmenu$qv

		push	dx
		call	readfd
		push	ds
		pop	es
		mov	di,128h		; TABLE
		mov	ax,offset iso_close_hack
		stosw
		inc	ax	; iso_open_hack
		stosw
		add	al,offset iso_read_hack-offset iso_open_hack
		stosw
		add	al,offset iso_lseek_hack-offset iso_read_hack
		stosw
	ifdef	NO386
        global  N_LXLSH@ES:near
N_LXLSH@ES:
		mov	dx,es
        global  N_LXLSH@:near
N_LXLSH@:
		mov	ch,0
@@lp:
		shl	ax,1
		rcl	dx,1
		loop	@@lp
	endif
iso_close_hack:
		ret

;***************************************************************
;_fastcall int open(bx:const char* name);
;***************************************************************
iso_open_hack:
		extrn	@_isoopen$qv:near
		cmp	[byte bx],'!'
		je	@readmenu$qv
		xchg	ax,bx
iso_open:
		mov	[_isostate.filename2open],ax
		call	@_isoopen$qv
		cmp	al,1
		cmc
		ret


;***************************************************************
;_fastcall int read(bx:int fd=isostate.fd, dx:void* data, cx:int sz, ah=3Fh);
;***************************************************************
iso_read_hack:
		push	dx
		push	cx
		xor	cx,cx
		xor	dx,dx
		mov	al,01h
		call	doseek		; bx = _isostate.fileofs
	ifdef	NO386
		mov	cx,[bx+4]	; _isostate.filesize
		sub	cx,ax
		mov	ax,[bx+6]
		sbb	ax,dx
		pop	ax
		ja	@@axok
		je	@@rem
		xor	ax,ax
@@rem:
		cmp	cx,ax
		jb	@@cxok
@@axok:
	else
		push	dx
		push	ax
		pop	edx
		mov	eax,[bx+4]	; _isostate.filesize
		sub	eax,edx
		pop	cx
		ja	@@rem
		xor	cx,cx
@@rem:
		movzx	ecx,cx
		cmp	eax,ecx
		ja	@@cxok
	endif
		xchg	ax,cx
@@cxok:
		pop	dx		; buffer
		jmp	readfd


;***************************************************************
;_fastcall long lseek(ax:int fd=isostate.fd, cxdx:unsigned long offset, bl:whence, bh=42h);
;***************************************************************
iso_lseek_hack:
		xchg	ax,bx
	ifdef	SEEK_CUR
		cmp	al,1	; current
		je	doseek
	endif
		mov	bx,offset _isostate.fileofs
		add	dx,[bx]
		adc	cx,[bx+2]
		cmp	al,0	; start
		je	doseek
		add	dx,[bx+4]	; _isostate.filesize
		adc	cx,[bx+6]
		mov	al,0
doseek:
		call	lseek		; lseek(,,al)
sub_fileofs:
		mov	bx,offset _isostate.fileofs
		sub	ax,[bx]
		sbb	dx,[bx+2]
		ret


;***************************************************************
;_fastcall void readmenu(void);
;***************************************************************
	proc	@readmenu$qv near

		mov	dx,18
		xor	cx,cx
		call	lseekset
		mov	dx,offset _isostate.filemod
		mov	cl,10
		call	readfd ; // read x->filemod + x->fileofs & x->filesize
		mov	bx,offset _isostate.fileofs
		; x->fileofs = 0x7FF0 - (x->filesize &= 0xFFFF);
		mov	ax,7FF0h
		cwd
		mov	[word bx+6],dx
		sub	ax,[bx+4]
		mov	[word bx+2],dx
		mov	[bx],ax
		; //magic = x->filemod;

	endp	@readmenu$qv

;***************************************************************
;_fastcall void isolseek(bx:const unsigned long *offset);
;***************************************************************
        global  @isolseek$qpxul:near
        proc    @isolseek$qpxul near

isolseek:
		mov	dx,[bx]
		mov	cx,[bx+2]
lseekset:
		mov	al,00h			; bx=fd cx:dx=offset al=whence
lseek:
		mov	ah,42h
dosfd:
		mov	bx,[_isostate.fd]
dos:
		int	21h
failifc:
		jnc	dosok
fail:
		sbb	ax,ax
		cwd
dosok:
		ret

	endp	@isolseek$qpxul


;***************************************************************
;_fastcall int isoreadsector(bx:const unsigned long *offset);
;***************************************************************
        global  @isoreadsector$qpxul:near
        proc    @isoreadsector$qpxul near

		call	isolseek
		jc	fail
		mov	ch,9			; < 2560
		mov	dx,offset _isostate.buffer
readfd:
                mov	ah,3Fh
		jmp	dosfd

        endp    @isoreadsector$qpxul


;***************************************************************
;_fastcall int strhead(bx:const char* a, ax:const char* b);
;***************************************************************
        global  @strhead$qpxzct1:near
        proc    @strhead$qpxzct1 near

@@loop:
		xchg	ax,bx
                mov	cl,[bx]			; cl = *b++
                inc	bx
		xchg	ax,bx
		or	cl,cl			; clear C
		jz	fail			; return 0
                xor	cl,[bx]			; cl -= *a++
                inc	bx
		or	cl,cl
		stc
		jne	fail			; return -1
                jmp	@@loop

	endp	@strhead$qpxzct1


;***************************************************************
;_fastcall int strcmp(bx:const char* a, ax:const char* b);
;***************************************************************
        global  @strcmp$qpxzct1:near
        proc    @strcmp$qpxzct1 near

		call	@strhead$qpxzct1
		jne	dosok			; return -1
		cmp	cl,[bx]
		jmp	fail			; return 0 or -1

        endp    @strcmp$qpxzct1

        ends    _TEXT

	end
