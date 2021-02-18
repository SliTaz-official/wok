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

        group   DGROUP  _TEXT
        assume  cs:DGROUP,ds:DGROUP


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;u32 memtopz();
;***************************************************************
        proc    _memtopz near
;***************************************************************
;u32 memtop_e801()
;***************************************************************
;        proc    _memtop_e801 near

                xor     cx,cx           ;fix to work around buggy
                xor     dx,dx           ;  BIOSes which dont clear/set
                stc                     ;  carry on pass/error of
                mov     ax,0E801h
                int     15h
                jc      @@err

		xchg	ax,cx		;kludge to handle BIOSes
		jcxz	@@use_cxdx	;  which report their extended
					;  memory in AX/BX rather than
					;  CX/DX.  The spec I have read
@@use_axbx:     mov     dx,bx           ;  seems to indicate AX/BX
                xchg	ax,cx		;  are more reasonable anyway...
@@use_cxdx:				;now: dx=64k units above 16m
					;     ax=1k units above 1m below 16m (max 3c00h)
                or	dx,dx
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
                cmc                     ;  error: cf=1 or ax=0
		sbb	dx,dx
                and     ax,dx           ;
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

;        proc    _memtopz near

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

        endp    _memtopz

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
