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

        group   DGROUP  _TEXT
        assume  cs:DGROUP,ds:DGROUP


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;u32 memtop();
;***************************************************************
        global  _memtop:near
        proc    _memtop near
;***************************************************************
;u32 memtop_e820()
;***************************************************************
;        proc    _memtop_e820 near

	ifdef	INT15_E820

struc   e820		;struct e820 {
base		dd	?,?	; 0    u64 base;
length		dd	?,?	; 8    u64 length;
type		db	?,?,?,?	;16    u32 type;	1=available
ends	e820		;};

                p386
		push	ds
		pop	es
		push	di
		xor	ebx,ebx
@@e820lp:
                mov     eax,0E820h
		mov	edx,534D4150h	; 'SMAP'
		xor	ecx,ecx
		mov	cl,size e820
		extrn	buf4k:byte
		mov	di,offset buf4k
                int     15h
                jc      @@err_e820
		;cmp	eax,534D4150h	; 'SMAP'
                ;jne	@@err_e820
		cmp	[(e820 di).type],1
		jnz	@@notavail
		mov	eax,[(e820 di).base]
		add	eax,[(e820 di).length]
		push	eax
		pop	ax
		pop	dx
		or	dh,dh			; > 16M
		je	@@notavail
		pop	di
		ret
@@notavail:
		or	bx,bx
		jne	@@e820lp
@@err_e820:
		pop	di
	endif

;        endp    _memtop_e820

;***************************************************************
;u32 memtop_e801()
;***************************************************************
;        proc    _memtop_e801 near

                xor     cx,cx           ;fix to work around buggy
                xor     dx,dx           ;  BIOSes which dont clear/set
                mov     ax,0E801h	;ax=1kbs in 1-16M bx=64kbs above 16M extended
                int     15h		;cx=1kbs in 1-16M dx=64kbs above 16M configured
		xchg	ax,cx		;kludge to handle BIOSes
		jcxz	@@use_cxdx	;  which report their extended
					;  memory in AX/BX rather than
					;  CX/DX.  The spec I have read
@@use_axbx:     mov     dx,bx           ;  seems to indicate AX/BX
                xchg	ax,cx		;  are more reasonable anyway...
@@use_cxdx:				;now: dx=64k units above 16m
					;     ax=1k units above 1m below 16m (max 3c00h)
                or	dx,dx
		jz	@@below16M
                xor     ax,ax           ;ignore info on low 16M (assume full)
                inc     dh              ;account for low 16M
                ret
@@below16M:
		or	ax,ax
                jnz	tokb		;dx=0 here, ax=kbs above 1m
@@err:
;                ret
;        endp    _memtop_e801


;***************************************************************
;u32 memtop_88()
;***************************************************************
;        proc    _memtop_88 near

                mov     ah,88h
                int     15h             ;ax=kbs above 1m
                test	ax,ax		;  error: ax=0
                jnz     tokb            ;happens on big mem systems

;***************************************************************
;u32 memtop_cmos()
;***************************************************************

;memtop_cmos:
                pushf
                call	rdcmos17
                popf
tokb:
		mov	cl,10		;multiply by 1024
		ifndef	NO386
                add     ah,4h           ;account for 1024 low kb
                setc    dl              ;  (optimized to death)
		shld    dx,ax,cl
		shl     ax,cl		;  (kbytes -> bytes)
		ret
		else
                xor     dx,dx
                add     ah,4h           ;account for 1024 low kb
                adc     dx,dx           ;  (optimized to death)
		db	0A9h		; test ax,0C28Ch
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
        global  N_LXLSH@4:near
N_LXLSH@4:
		xor	dx,dx
		mov	cl,4
		jmp	N_LXLSH@
		endif

;        endp    _memtop_88

;        proc    _memtop near

;                call	_memtop_e801
;		jnz	@@ok
;                call	_memtop_88
;		jnz	@@ok
;		jmp	memtop_cmos

rdcmos17:       cli
                mov     al,18h		; read bytes 17-18 from CMOS
                call    @@rdcmos
                mov     ah,al
                mov     al,17h
@@rdcmos:       out     70h,al
                call    @@ret
                in      al,71h
@@ret:
                ret


;***************************************************************
;u32 topload();
;***************************************************************
        global  _topload:near
_topload:
		call	_memtop
		mov	cx,40h		; min 4m
; If reported mem is ridiculously low, presume
; we had trouble detecting memory size
		cmp	dx,cx
		jb	@@set
		extrn	_cmdnum:dword
_topmem		=	_cmdnum+8
		mov	cx,[word _topmem+2]
		inc	cx			; jcxnz
		loop	@@topmemset
		mov	ch,10h			; default = max 256m
@@topmemset:
; Kernel can have trouble with initrd at very high addr:
; limit mem top to 256m
		cmp	dh,ch
		jb	@@done
@@set:
		xchg	ax,cx
		cwd
		xchg	ax,dx
@@done:
; Round down to page boundary.
; Or else initrd's tail may end up in last, partial page.
; Kernel will refuse to use such initrd.
		and	ax,0f000h
;@@ok:
		ret

        endp    _memtop

;***************************************************************
;void hook_int15_88();
;***************************************************************
        global  _hook_int15_88:near
        proc    _hook_int15_88 near

		ifndef  xmm_hook
                ;mov     ax,4300h
                ;int     2fh
                ;cmp     al,80h			; 80h = XMS driver installed
                ;je      @@skip
		endif
saved15:
		xor	bx,bx
		mov	es,bx
		ifndef	NO386
		push	cs
		push	offset int15_88
		pop	eax
		xchg	eax,[es:bx+15*4]
		mov	[dword saved15],eax
		else
		mov	ax,offset int15_88
		call	saved15z
		mov	ax,cs
		inc	bx
		inc	bx
saved15z:
		xchg	ax,[es:bx+15*4]
		mov	[word bx+saved15],ax
		endif
		;push	ds
		;pop	es
@@skip:
		ret
int15_88:
                cmp     ah,88h
                je      @@do88
                jmp     [dword saved15]
@@do88:
                pushf
                call    [dword saved15]
                or	ax,ax
                jnz     @@iret

;****** Read extended mem size (CMOS bytes 17h,18h (lo,hi))
                call	rdcmos17
@@iret:
                iret

        endp    _hook_int15_88

        ends    _TEXT

        end

;###### END OF FILE ############################################
