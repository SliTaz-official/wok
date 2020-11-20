;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
                %crefref
                %noincl
                %nomacs
                p8086

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
		org	0EF00h
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
		mov	ax,offset iso_open_hack
		stosw
		mov	al,offset iso_read_hack-0F000h
		stosw
		mov	al,offset iso_lseek_hack-0F000h
		stosw
		mov	al,offset iso_close_hack-0F000h
		stosw
;		mov	al,offset iso_cleanup_hack-0F000h
;		stosw
		global	@_cpuhaslm$qv:near
@_cpuhaslm$qv:
		mov	ax,[132h+3]
		and	al,20h
		ret

iso_open_hack:
		pop	ax
		extrn	@_isoopen$qv:near
		cmp	[byte bx],'!'
		je	@readmenu$qv
		xchg	ax,bx
		global	iso_open:near
iso_open:
		mov	[_isostate.filename2open],ax
		call	@_isoopen$qv
		cmp	al,1
		cmc
		push	bx
iso_close_hack:
		pop	bx
		ret


	macro   curseek
		push	cx
		xor	cx,cx
		mov	ax,4201h
		cwd
		call	dosfd		; lseek(,0L,SEEK_CUR)
		call	@doseek2
	ifndef	NO386
		push	dx
		push	ax
		pop	eax
	endif
		pop	cx
	endm

;***************************************************************
;_fastcall void readmenu(void);
;***************************************************************
	global	@readmenu$qv:near
	proc	@readmenu$qv near

		mov	dx,18
		xor	cx,cx
		call	lseekset
		mov	dx,offset _isostate.filemod
		mov	cx,10
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
		mov	ax,4200h			; bx=fd cx:dx=offset al=whence
dosfd:
		mov	bx,[_isostate.fd]
dos:
		int	21h
failifc:
		jnc	@@dosok
fail:
		sbb	ax,ax
		cwd
@@dosok:
		ret

	endp	@isolseek$qpxul

;***************************************************************
;_fastcall int isoreadsector(bx:const unsigned long *offset);
;***************************************************************
        global  @isoreadsector$qpxul:near
        proc    @isoreadsector$qpxul near

		call	isolseek
		jc	fail
		mov	cx,2560
		mov	dx,offset _isostate.buffer
		global	readfd:near
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
		or	cl,cl			; clear C
		jz	failifc			; return 0
		xchg	ax,bx
                xor	cl,[bx]			; cl -= *a++
                inc	bx
		and	cl,0dfh			; case insensitive
		jne	fail			; return -1
                jmp	@@loop

	endp	@strhead$qpxzct1

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

iso_read_hack:
	ifdef	NO386
		push	dx
		curseek
		mov	bx,[word _isostate.filesize]
		sub	bx,ax
		mov	ax,[(word _isostate.filesize)+2]
		sbb	ax,dx
		ja	@@cxok
		je	@@rem
		xor	cx,cx
@@rem:
		cmp	bx,cx
		ja	@@cxok
		mov	cx,bx
@@cxok:
		pop	dx
	else
                p386
		push	edx
		curseek
		mov	edx,[_isostate.filesize]
		sub	edx,eax
		jnb	@@rem
		xor	cx,cx
@@rem:
		movzx	eax,cx
		cmp	edx,eax
		ja	@@cxok
		mov	cx,dx
@@cxok:
		pop	edx
	endif
		or	cx,cx
		pop	bx
		jmp	readfd

iso_lseek_hack:
		xchg	ax,bx
		pop	bx
	ifdef	SEEK_CUR
		cmp	al,1	; current
		jne	@@nocurrent
		call	dosfd		; lseek(,0L,SEEK_CUR)
		jmp	@doseek2
@nocurrent:
	endif
		add	dx,[word _isostate.fileofs]
		adc	cx,[(word _isostate.fileofs)+2]
		cmp	al,0	; start
		je	@@doseek
		add	dx,[word _isostate.filesize]
		adc	cx,[(word _isostate.filesize)+2]
@@doseek:
		call	lseekset	; lseek(,0L,SEEK_SET)
@doseek2:
		sub	ax,[word _isostate.fileofs]
		sbb	dx,[(word _isostate.fileofs)+2]
		ret

;iso_cleanup_hack:
;		mov	ah,3Eh		; close file
;		jmp	dosfd

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
		ret
	endif

        ends    _TEXT

	end
