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

overflow	db	"Loaded too close to 9000:0",0

        ends    _DATA

        segment _BSS byte public use16 'BSS'

        global  _imgs:dword

        ends    _BSS


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void boot_kernel();
;****** Never returns
;***************************************************************
	global	_boot_kernel:near
        proc    _boot_kernel near
        
; Shrink stack: we won't need much of it now and have no malloc() plans
		extrn	_heap_top:word
		mov	ax,[_heap_top]
		inc	ah
		cmp	ax,sp
		ja	@@samesp
		xchg	ax,sp
@@samesp:
		ifdef	NO386
		extrn	_topseg:near
		call	near _topseg
		mov	es,ax
		xchg	ax,bx
		mov	cl,4
		mov	ax,sp
		shr	ax,cl
		else
		mov	bx,9000h
		mov	es,bx
		mov	ax,sp
		shr	ax,4
		endif
		mov	dx,cs
		add	ax,dx
		cmp	ax,bx
		jb	@@nooverflow
; Oops! We can stomp on our toes... better stop now
		mov	bx,offset overflow
		extrn	die:near
		jmp	near die
@@nooverflow:
		cli				; we start doing destructive things to DOS
		push	es
		pop	ss
		mov	sp,0A000h
		extrn	_csip:dword
		push	[dword _csip]
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
		jne	@@isbzimage
		ifdef	NO386
		add	bh,9
		push	bx			; topseg()+0x0900
		else
		push	9800h+(4096/16)		; 4096 bytes for cmdline
		endif
		; finish loading
		extrn   @last_ditch$qv:near
		push	cs
		call	@last_ditch$qv
		mov	ax,[word _imgs+2+2]	; get pm->fallback high word
		; self move
		;cld
		pop	es			; min 2048 bytes for stack
		xor	si,si			;  A000 -9000 -0800(>movedend)
		xor	di,di			; set ZF
		mov	cx,offset movedend
		rep
		  movsb
		push	es
		call	near @@doretf		; mov cs,es
		push	ss
		pop	es
		push	cs
		pop	ds
		push	ax
		extrn	dos_shutdown:near
		call	near dos_shutdown
		;in	al,70h
		;or	al,80h			; disable NMI
		;out	70h,al
		pop	bx
		; move zImage pm
		mov	ax,8
		cwd				; clear dx
		cmp	bx,ax
		ja	@@bufhigh
		sub	ax,bx
		inc	ax
@@bufhigh:
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
		jne	@@notelks
		cmp	[word 1E8h],'SK'
		endif
		jne	@@notelks
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
@@notelks:
		endif
@@isbzimage:
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
@@doretf:
                retf

movedend:
        endp    _boot_kernel

        ends    _TEXT

        end

;###### END OF FILE ############################################
