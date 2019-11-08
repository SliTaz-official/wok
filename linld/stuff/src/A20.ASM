;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
                %crefref
                %noincl
                %nomacs
                p8086

        group   DGROUP  _TEXT,_DATA
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'

        global  die:near
enable_a20_methods:
		dw	_enable_a20_fast, _enable_a20_kbd, _enable_a20_xmm, die
msg_a20		db	"Can't use A20",0
overflow	db	"Loaded too close to 9000:0",0
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

;***************************************************************
;_fastcall void moverm(bx:struct himem *m);
;***************************************************************

	global	@moverm$qp11image_himem:near
@moverm$qp11image_himem:
		push	si di
		extrn	_heap_top:word
		ifdef	NO386
		mov	ax,[_heap_top]
		mov	cl,4
		shr	ax,cl
		mov	dx,cs
		add	dx,ax
		extrn	_topseg:near
		call	near _topseg
		mov	[word sssp+2],ax
		else
                p386
		mov	ax,[_heap_top]
		shr	ax,4
		mov	dx,cs
		add	dx,ax
		mov	ax,9000h
		endif
		mov	es,ax
		cmp	dx,ax
		jb	@@nooverflow
; Oops! We can stomp on our toes... better stop now
		mov	bx,offset overflow
		call	near die
@@nooverflow:
		mov	cx,[bx-5]	; size
		mov	si,[bx-2]	; data
		xor	di,di
		ifdef	MOVE_SETUP
		extrn	_pm_high:byte
		cmp	[_pm_high],al
		jne	@@move_clear
		mov	di,8000h
		sub	di,cx
		extrn	_rm_offset:word
		mov	[_rm_offset],di
		endif
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
		cli
		mov	ax,0AA55h
		xchg	al,[bx]
		xchg	ah,[es:bx+10h]
		xchg	al,[bx]
		xchg	ah,[es:bx+10h]
		cmp	al,55h
		sti
a20ko:
		loopne	a20lp
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
