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

        global  _topmem:dword

_topmem		dd	10000000h	; max 256m

        ends    _DATA

        segment _BSS byte public use16 'BSS'

saved15		dd	?

        ends    _BSS


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;u32 memtopz();
;***************************************************************
        global  _memtopz:near
        proc    _memtopz near
;***************************************************************
;u32 memtop_e801()
;***************************************************************
;        proc    _memtop_e801 near

                ;push    cx bx
                xor     cx,cx           ;fix to work around buggy
                xor     dx,dx           ;  BIOSes which dont clear/set
                stc                     ;  carry on pass/error of
                mov     ax,0E801h
                int     15h
                jc      @@err
                test    cx,cx           ;kludge to handle BIOSes
                jnz     @@use_cxdx      ;  which report their extended
                test    dx,dx           ;  memory in AX/BX rather than
                jnz     @@use_cxdx      ;  CX/DX.  The spec I have read
@@use_axbx:     mov     dx,bx           ;  seems to indicate AX/BX
                jmp     @@end_kludge    ;  are more reasonable anyway...
@@use_cxdx:     xchg    ax,cx
@@end_kludge:                   ;now: dx=64k units above 16m
                                ;     ax=1k units above 1m below 16m (max 3c00h)
                ;pop     bx cx
                test    dx,dx
                jz      tokb            ;dx=0 here, ax=kbs above 1m
                xor     ax,ax           ;ignore info on low 16M (assume full)
               ;add     dx,100h         ;account for low 16M
                inc     dh              ;account for low 16M (optimized)
                ret
@@err:
;                xor     ax,ax
;                cwd
;                ret
;        endp    _memtop_e801


;***************************************************************
;u32 memtop_88()
;***************************************************************
;        proc    _memtop_88 near

                mov     ah,88h
                int     15h             ;ax=kbs above 1m
                jnc     @@ok            ;  error: cf=1 or ax=0
                xor     ax,ax           ;
@@ok:
;                xor     dx,dx
                test    ax,ax           ;happens on big mem systems
                jz      @@fail
tokb:
                xor     dx,dx
                add     ah,4h           ;account for 1024 low kb
                adc     dx,dx           ;  (optimized to death)
		ifndef	NO386
                shld    dx,ax,10        ;multiply by 1024
                shl     ax,10           ;  (kbytes -> bytes)
		else
@@lp:
		mov	cx,10
                shl     ax,1            ;multiply by 1024
		rcl	dx,1
		loop	@@lp
		endif
;		mov	cx,ax
;		or	cx,dx		;update ZF
;@@fail:
                ret
;        endp    _memtop_88

@@fail:

;        proc    _memtopz near

;                call	_memtop_e801
;		jnz	@@ok
;                call	_memtop_88
;		jnz	@@ok

;***************************************************************
;u32 memtop_cmos()
;***************************************************************

                pushf
                cli
                call	rdcmos17
                popf
		jmp	tokb

rdcmos17:       mov     al,18h		; read bytes 17-18 from CMOS
                call    @@rdcmos
                mov     ah,al
                mov     al,17h
@@rdcmos:       out     70h,al
                call    @@ret
                in      al,71h
@@ret:
                ret


;***************************************************************
;u32 memtop();
;***************************************************************
        global  _memtop:near
_memtop:
		call	_memtopz
		mov	cx,40h		; min 4m
; If reported mem is ridiculously low, presume
; we had trouble detecting memory size
		cmp	dx,cx
		jb	@@set
		mov	cx,[word _topmem+2]	; max 256m ?
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

        endp    _memtopz

;***************************************************************
;void hook_int15_88();
;***************************************************************
        global  _hook_int15_88:near
        proc    _hook_int15_88 near

		ifndef  xmm_hook
                mov     ax,4300h
		ifdef	NO386
		cwd
		endif
                int     2fh
                cmp     al,80h			; 80h = XMS driver installed
                je      @@skip
		endif
		ifndef	NO386
		push	0
		pop	es
		mov	bx,15*4
		mov	eax,[bx]
		mov	[saved15],eax
		else
		mov	es,dx
		mov	bx,15*4
		mov	ax,[bx]
		mov	[word saved15],ax
		mov	ax,[bx+2]
		mov	[word saved15+2],ax
		endif
		mov	[word bx],offset int15_88
		mov	[bx+2],cs
@@skip:
		ret
int15_88:
                cmp     ah,88h
                je      @@do88
                jmp     [saved15]
@@do88:
                pushf
                call    [saved15]
                test    ax,ax
                jnz     @@iret

;****** Read extended mem size (CMOS bytes 17h,18h (lo,hi))
                call	rdcmos17
@@iret:
                iret

        endp    _hook_int15_88

        ends    _TEXT

        end

;###### END OF FILE ############################################
