;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 255
                %crefref
                %noincl
                %nomacs
                p8086

	include	"common.inc"

        group   DGROUP  _TEXT,_DATA
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'

        global  die:near
enable_a20_methods:
		dw	_enable_a20_fast, _enable_a20_kbd, _enable_a20_xmm, die
msg_a20		db	"A20 broken",0
		extrn	overflow:byte
		ifdef	NO386
bzimage86	db	"8086 "
		endif
	global	_bzimagestr:byte
_bzimagestr	db	"bzImage",0
	global	sssp:dword
	global	_initrd_desc:dword
_initrd_desc	dd	90000218h
		org	$-4
sssp		dd	?

        ends    _DATA

        segment _TEXT byte public use16 'CODE'

        global  xmm_driver:near
        global  _enable_a20_xmm:near

;***************************************************************
;void enable_a20_kbd();
;***************************************************************
        proc    _enable_a20_kbd near

                call    @@empty_8042
                mov     al,0D1h         ; command write
                out     64h,al
                call    @@empty_8042
                mov     al,0DFh         ; A20 on
                out     60h,al

; This routine checks that the keyboard command queue is empty
; (after emptying the output buffers)
; Some machines have delusions that the keyboard buffer is always full
; with no keyboard attached...
; If there is no keyboard controller, we will usually get 0xff
; to all the reads.  With each IO taking a microsecond and
; a timeout of 100,000 iterations, this can take about half a
; second ("delay" == out to port 0x80). That should be ok,
; and should also be plenty of time for a real keyboard controller
; to empty.

@@empty_8042:
                xor     cx,cx           ; 64K iterations
@@loop:
                call    @@delay         ; 8042 status port
                in      al,64h
                test    al,3            ; is output or input full?
                jz      @@break         ; no - break loop
                test    al,1            ;
                jz      @@no_output
                call    @@delay         ; yes: read it
                in      al,60h          ;
@@no_output:
                loop    @@loop
@@break:
                ret

@@delay:        out     80h,al
                ret

        endp    _enable_a20_kbd

;***************************************************************
;void enable_a20_fast();
;***************************************************************
        proc    _enable_a20_fast near

; You must preserve the other bits here. Otherwise embarrasing things
; like laptops powering off on boot happen. Corrected version by Kira
; Brown from Linux 2.2
                in      al,92h  ;
                or      al,02h  ; "fast A20" version
                out     92h,al  ; some chips have only this
                ret

        endp    _enable_a20_fast

	include	"himem.inc"

;***************************************************************
;_fastcall void moverm(bx:u16 *p);
;***************************************************************

	global	@moverm$qpus:near
@moverm$qpus:
		push	si di
		xor	di,di			; default setup 9000:0000
		extrn	_heap_top:word
		ifdef	NO386
		mov	ax,[_heap_top]
		mov	cl,4
		shr	ax,cl
		mov	dx,cs
		add	dx,ax			; last used segment
		mov	cx,0fffh
		extrn	_pm_low:byte
		test	[_pm_low],cl
		jne	@zimage
		extrn	_cpu386:byte
		test	[_cpu386],cl
		jne	@bzimage
		mov	bx,offset bzimage86	; no himem with 8086 !
@godie:
		call	near die
@zimage:
		xchg	ax,dx
		cmp	ax,cx
		jae	@sys@ok
		xchg	ax,cx			; segment min 1000h
@sys@ok:
		inc	ax			; first free segment
		extrn	N_LXLSH@4:near
		call	N_LXLSH@4
		mov	[word ((image_himem bx+4).fallback)],ax
		mov	[word ((image_himem bx+4).fallback)+2],dx
		add	ax,[word ((image_himem bx+4).size)]
		adc	dx,[word ((image_himem bx+4).size)+2]
		ifdef	MOVE_SETUP
		mov	di,8000h
		sub	di,[bx]			; rm_size
		extrn	_rm_offset:word
		mov	[_rm_offset],di
		sub	ax,di			; -rm_offset
		sbb	dx,cx
		endif
		mov	cl,12
		shl	dx,cl			; last sys segment
		ifndef	LARGE_ZIMAGE
		;jc	@jbe_overflow		; >= 1Mb ???
		else
		;jnc	@bzimage		; < 1Mb
		;mov	dh,-1
		endif
@bzimage:
		extrn	_topseg:near
		call	near _topseg
		mov	[word sssp+2],ax
		ifdef	VCPI
		and	ch,0			; vcpi flag
		org	$-1
		global	_vcpi:byte
_vcpi		db	?
		endif
		else
                p386
		movzx	eax,[word _heap_top]
		shr	ax,4
		mov	dx,cs
		add	ax,dx			; last used segment
		mov	cx,0fffh
		extrn	_pm_low:byte
		test	[_pm_low],cl
		je	@bzimage
		cmp	ax,cx
		jae	@sys@ok
		xchg	ax,cx			; segment min 1000h
@sys@ok:
		inc	ax			; first free segment
		shl	eax,4
		mov	[(image_himem bx+4).fallback],eax
		add	eax,[(image_himem bx+4).size]
		ifdef	MOVE_SETUP
		mov	di,8000h
		sub	di,[bx]			; rm_size
		extrn	_rm_offset:word
		mov	[_rm_offset],di
		movzx	ecx,di			; -rm_offset
		sub	eax,ecx
		endif
		shr	eax,4
		ifdef	VCPI
		mov	ch,0
		endif
@bzimage:
		xchg	ax,dx
		mov	ax,9000h
		ifdef	VCPI
		extrn	_vcpi:byte
		and	ch,[_vcpi]
		endif
		endif
		ifdef	VCPI
		add	dh,ch		; 60k room for malloc_bufv_or_die
		endif
		cmp	ax,dx
		ifdef	LARGE_ZIMAGE
		ja	@nooverflow0
	     extrn   _cmdnum:dword
base_himem	=	(dword _cmdnum+12)
		ifdef	NO386
		les	cx,[base_himem]
		mov	[word ((image_himem bx+4).fallback)],cx
		mov	[word ((image_himem bx+4).fallback)+2],es
		else
		mov	ecx,[base_himem]
		mov	[(image_himem bx+4).fallback],ecx
		endif
@nooverflow0:
		endif
		les	cx,[bx]		; rm_size
		mov	si,es		; rm_buf
		ifndef	LARGE_ZIMAGE
@jbe_overflow:
; Oops! We can stomp on our toes... better stop now
		mov	bx,offset overflow
		ifdef	NO386
		jbe	@godie
		else
		ja	@nooverflow
		call	near die
@nooverflow:
		endif
		endif
		mov	es,ax
@@move_clear:
		movsb
		mov	[byte si-1],al
		loop	@@move_clear
		;push	ds
		;pop	es
		;pop	di si
		pop	di

;***************************************************************
;void enable_a20_or_die();
;***************************************************************
        proc    _enable_a20_or_die near

		;push	si
		mov	si,offset enable_a20_methods
		jmp	@@check
@@loop:
		lodsw
		mov	bx,offset msg_a20
		call	ax
@@check:
		;call	_check_a20
;***************************************************************
;int check_a20();
;***************************************************************
        ;proc    _check_a20 near

; From linux kernel setup.S:
; wait until a20 really *is* enabled; it can take a fair amount of
; time on certain systems; Toshiba Tecras are known to have this
; problem.

                push    ds
		xor	bx,bx
		mov	ds,bx
		mov	cx,0FFFFh
		mov	es,cx
a20lp:
		cli			; A20 off	A20 on
		mov	ax,0AA55h	; al  ah [bx]	al  ah [bx] es:[bx+10h]
		xchg	al,[bx]		; ??  AA  55    ?1  AA  55  ?2
		xchg	ah,[es:bx+10h]	; ??  55  AA	?1  ?2  55  AA
		xchg	al,[bx]		; AA  55  ??    55  ?2  ?1  AA
		cmp	al,55h
		sti
		loopne	a20lp
		jne	a20ko	
		xchg	ah,[es:bx+10h]	; AA  ??  55	55  AA  ?1  ?2
a20ko:
		;xchg	ax,cx
                pop     ds
                ;ret

        ;endp    _check_a20

		jne	@@loop
		;push	ds
		;pop	es
		pop	si
                ret

        endp    _enable_a20_or_die

        ends    _TEXT

        end

;###### END OF FILE ############################################
