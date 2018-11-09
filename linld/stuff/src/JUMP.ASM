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
;void dos_shutdown()
;***************************************************************

	macro	dos_shutdown
		xor	di,di
		mov	ds,di
		ifndef	NO386
		push	[dword di+4]		; save step
		mov	[word di+4],offset step19
		else
		mov	ax,offset step19
		xchg	ax,[word di+4]
		push	[word di+6]	
		push	ax			; save step
		endif
		mov	[word cs:sssp],sp
		;cmp	[byte di+7],0F0h
		;jnc	notdos
		mov	[di+6],cs
		pushf
		pushf
		pop	ax
		inc	ah			; set TF
		push	ax
		popf
		call	[dword di+4*19h]
notdos:
		ifndef	NO386
		lss	sp,[dword cs:sssp]
		else
		lds	ax,[dword cs:sssp]
		push	ds
		pop	ss
		xchg	ax,sp
		endif
		xor	di,di
		mov	ds,di
		pop	[dword di+4]		; restore step
	endm
	macro	step19code
step19:
		push	di
		push	ds
		mov	di,sp
		lds	di,[dword ss:di+4]	; read cs:ip
		cmp	[word di],19CDh		; int 19h ?
		pop	ds
		pop	di
		je	notdos
		iret
	endm


;***************************************************************
;void boot_kernel();
;****** Never returns
;***************************************************************
	global	_boot_kernel:near
        proc    _boot_kernel near
        
                p8086
		extrn	_heap_top:word
		global	sssp:dword
		ifdef	NO386
		extrn	_topseg:near
		call	near _topseg
		mov	cl,4
		org	$-4
sssp		dd	?
		mov	[word sssp+2],ax
		xchg	ax,bx
		mov	ax,[_heap_top]
		shr	ax,cl
		else
                p386
		mov	ax,[_heap_top]
		shr	ax,4
		mov	bx,9000h
		org	$-4
sssp		dd	?
		endif
		mov	es,bx
		mov	dx,cs
		add	ax,dx
		cmp	ax,bx
		jb	@@nooverflow
; Oops! We can stomp on our toes... better stop now
		mov	bx,offset overflow
		extrn	die:near
		call	near die
@@nooverflow:
		;cli				; we start doing destructive things to DOS
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
		ifdef	NO386
		add	bh,9
		push	bx			; topseg()+0x0900
		else
		push	9800h+(4096/16)		; 4096 bytes for cmdline
		endif
		cmp	al,cl			; load high ?
		pushf
		; finish loading
		extrn   @last_ditch$qv:near
		call	@last_ditch$qv
		dos_shutdown			; clear di; ds=0
		push	cs
		pop	ds
		popf
		; self move
		;cld
		pop	es			; min 2048 bytes for stack
		jne	@@isbzimage
		mov	cx,offset movedend
		xor	si,si			;  A000 -9000 -0800(>movedend)
		rep
		  movsb
		mov	ax,[word _imgs+2+2]	; get pm->fallback high word
		push	es
		call	near @@isbzimage	; pop cs ; ds=es=ss

		; prepare memcpy32 size & srcofs param to move zImage pm
		mov	dx,8
		cmp	ax,dx			; buf > 80000h ?
		ja	@@bufhigh
		sub	dx,ax
		inc	dx			; up to 90000h-1
@@bufhigh:
		push	dx			; size hi
		push	cx			; size lo=up to 512k
		push	ax			; src ofs ho = pm.fallback

		;in	al,70h
		;or	al,80h			; disable NMI
		;out	70h,al

		xor	di,di
		push	di			; src ofs lo
		push	di			; src seg=0
		ifdef	NO386
		inc	di
		push	di			; dst ofs hi
		dec	di
		else
		push	1			; dst ofs hi
		endif
		push	di			; dst ofs lo : 64k
		extrn   memcpy32:near
		call	memcpy32

		ifndef  noelks
		ifndef	NO386
		cmp	[dword 1E6h],'SKLE'
		jne	@@notelks
		xor	si,si
		else
		mov	si,1E6h
		lodsw
		cmp	ax,'LE'
		jne	@@notelks
		lodsw
		xor	ax,'SK'
		jne	@@notelks
		xchg	ax,si
		endif
		push	es
		pop	ss
		mov	cx,120h		; CS=0120
		push	cx
		push	si		; IP=0000
		mov	cl,0		; DS=ES=SS=0100
		mov	es,cx
		mov	ch,05h		; 500h mini
		rep
		  movsw
@@notelks:
		endif
@@isbzimage:
		push	ss
		pop	ds
		push	ss
		pop	es
		ifndef	NO386
		push	ss
		pop	fs
		push	ss
		pop	gs
		endif
		assume	nothing
		assume	cs:DGROUP
                retf

		step19code

        endp    _boot_kernel

movedend:

        ends    _TEXT

        end

;###### END OF FILE ############################################
