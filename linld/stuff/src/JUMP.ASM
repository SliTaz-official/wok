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
		xor	bx,bx
		mov	ds,bx
		ifndef	NO386
		push	[dword bx+4]		; save step
		mov	[word bx+4],offset step19
		else
		mov	ax,offset step19
		xchg	ax,[word bx+4]
		push	[word bx+6]	
		push	ax			; save step
		endif
		mov	[word cs:sssp],sp
		;cmp	[byte bx+7],0F0h
		;jnc	notdos
		mov	[bx+6],cs
		pushf
		pushf
		pop	ax
		inc	ah			; set TF
		push	ax
		popf
		call	[dword bx+4*19h]
notdos:
		ifndef	NO386
		lss	sp,[dword cs:sssp]
		else
		lds	ax,[dword cs:sssp]
		push	ds
		pop	ss
		xchg	ax,sp
		endif
		xor	bx,bx
		mov	ds,bx
		ifndef	NO386
		pop	[dword bx+4]		; restore step
		else
		pop	[word bx+4]		; restore step
		pop	[word bx+6]
		endif
	endm
	macro	step19code
step19:
		push	bx
		push	ds
		mov	bx,sp
		lds	bx,[dword ss:bx+4]	; read cs:ip
		cmp	[word bx],19CDh		; int 19h ?
		pop	ds
		pop	bx
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
		global	sssp
		ifdef	NO386
sssp:
		extrn	_topseg:near
		call	near _topseg
		mov	[word sssp+2],ax
		xchg	ax,bx
		mov	ax,[_heap_top]
		inc	ah
		mov	cl,4
		shr	ax,cl
		else
                p386
		mov	ax,[_heap_top]
		inc	ah
		;shr	ax,4
		db	0C1h,0E8h
sssp:
		db	4
		mov	bx,9000h
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
		cmp	al,cl			; load high ?
		ifdef  noelks
		jne	@@isbzimage
		else
		jne	@@isbzimagez
		endif
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
		push	ax
		push	es
		dos_shutdown			; clear bx
		call	near @@isbzimage	; pop cs ; ds=es=ss
		;in	al,70h
		;or	al,80h			; disable NMI
		;out	70h,al
		pop	dx
		; move zImage pm
		mov	ax,8
		cmp	dx,ax			; buf > 80000h ?
		ja	@@bufhigh
		sub	ax,dx
		inc	ax			; up to 90000h-1
@@bufhigh:
		push	ax
		push	bx			; size=up to 512k
		push	dx			; src ofs= pm.fallback
		push	bx
		push	bx			; srcseg=0
		ifdef	NO386
		inc	bx
		push	bx			; dst
		dec	bx
		else
		push	1			; dst	
		endif
		push	bx			;    ofs=64k
		extrn   _memcpy32:near
		call	_memcpy32
		add	sp,14

		ifndef  noelks
		ifndef	NO386
		cmp	[dword 1E6h],'SKLE'
		jne	@@notelks
@@isbzimagez:
		jne	@@isbzimage
		else
		cmp	[word 1E6h],'LE'
		jne	@@notelks
@@isbzimagez:
		jne	@@isbzimage
		cmp	[word 1E8h],'SK'
		jne	@@notelks
		endif
		mov	cx,100h		; DS=ES=SS=0100
		mov	es,cx
		mov	ch,05h		; 500h mini
		xor	si,si
		xor	di,di
		rep
		  movsw
		push	es
		pop	ss
		ifdef	NO386
		mov	ax,120h		; CS=0120
		push	ax
		else
		push	120h		; CS=0120
		endif
		push	cx		; IP=0000
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
movedend:
        endp    _boot_kernel

        ends    _TEXT

        end

;###### END OF FILE ############################################
