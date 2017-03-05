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

        group   DGROUP  _TEXT,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _BSS byte public use16 'BSS'

        global  _pm:dword

        ends    _BSS


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void set_sregs_jump_seg_ofs(u32 csip);
;****** Never returns
;***************************************************************
        global  _set_sregs_jump_seg_ofs:near
        proc    _set_sregs_jump_seg_ofs near

		extrn	dos_shutdown:near

		pop	ax			; caller return address
		ifdef	NO386
		extrn	_topseg:near
		call	near _topseg
		mov	es,ax
		xchg	ax,bx
		else
		push	9000h
		pop	es
		endif
		pop	dx			; ip
		pop	cx			; cs
		cli				; we start doing destructive things to DOS
		push	es
		pop	ss
		mov	sp,0A000h
		push	cx dx
		extrn	_rm_size:word
		mov	si,offset _rm_size	; _rm_size, _pm_high, _rm_buf
		lodsw
		xchg	ax,cx			; _rm_size
		lodsb				; _pm_high
		mov	si,[si]			; _rm_buf
		xor	di,di
		;cld
		rep
		  movsb
		extrn	_cmdline:word
		mov	si,[_cmdline]
		mov	di,8000h
		mov	ch,10h			; 4k
		rep
		  movsb
		cmp	al,cl			; load high ?
		jne	isbzimage
		ifdef	NO386
		add	bh,9
		push	bx			; topseg()+0x0900
		else
		push	9900h			; 4096 bytes for cmdline
	;push	9820h			; 512 bytes for cmdline
		endif
		; finish loading
		extrn   @last_ditch$qv:near
		push	cs
		call	@last_ditch$qv
		mov	ax,[word _pm+2+2]	; get pm->fallback high word
		; self move
		;cld
		pop	es			; min 2048 bytes for stack
		xor	si,si			;  A000 -9000 -0800(>movedend)
		xor	di,di			; set ZF
		mov	cx,offset movedend
        global  _bss_end:byte
	;mov	cx,offset _bss_end
		rep
		  movsb
		push	es
		call	near doretf		; mov cs,es
		push	ss
		pop	es
		push	cs
		pop	ds
		push	ax
		call	near dos_shutdown
		;in	al,70h
		;or	al,80h			; disable NMI
		;out	70h,al
		pop	bx
		; move zImage pm
		mov	ax,8
		cwd
		cmp	bx,ax
		ja	bufhigh
		sub	ax,bx
		inc	ax
bufhigh:
		push	ax
		push	dx			; size=up to 512k
		push	bx			; src ofs= pm.fallback
		push	dx
		push	dx			; srcseg=0
		ifdef	NO386
		inc	dx
		push	dx			; dst
		dec	dx
		else
		push	1			; dst	
		endif
		push	dx			;    ofs=64k
		extrn   _memcpy32:near
		call	_memcpy32
		add	sp,14

		ifndef  noelks
		push	ss
		pop	ds
		ifndef	NO386
		cmp	[dword 1E6h],'SKLE'
		else
		cmp	[word 1E6h],'LE'
		jne	notelks
		cmp	[word 1E8h],'SK'
		endif
		jne	notelks
		ifdef	NO386
		mov	cx,120h
		push	cx
		mov	cl,0h
		push	cx
		else
		push	120h
		push	100h
		endif
		pop	es
		xor	si,si
		xor	di,di
		mov	ch,05h
		rep
		  movsw
		push	es
		pop	ss
		push	cx
notelks:
		endif

isbzimage:
		push	ss
		pop	ds
		;push	ss
		;pop	es
		ifndef	NO386
		push	ss
		pop	fs
		push	ss
		pop	gs
		endif
		assume	nothing
		assume	cs:DGROUP

doretf:
                retf

movedend:
        endp    _set_sregs_jump_seg_ofs

        ends    _TEXT

        end

;###### END OF FILE ############################################
