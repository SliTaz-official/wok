;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p386

        group   DGROUP  _TEXT,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _BSS byte public use16 'BSS'

        global  xmm_handler:dword
xmm_handler	dd	?

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void enable_a20_xmm();
;***************************************************************
        global  _enable_a20_xmm:near
        proc    _enable_a20_xmm near

                mov     ah,03h          ;global enable a20
                call    xmm_driver      ;
                mov     ah,05h          ;local enable a20
                ;jmp     xmm_driver      ;

        endp    _enable_a20_xmm

;***************************************************************
;Call xmm driver addr or 0 if no xmm
;void xmm_driver()
;***************************************************************
        global  xmm_driver:near
        proc    xmm_driver near

		cmp	[xmm_handler],0
		jne	@@gotit

		xchg	ax,cx			; save cmd
                mov     ax,4300h
                int     2fh
                mov     bx,offset xmm_fail
                push    cs
                pop     es
                cmp     al,80h
                jne     @@err
                mov     ax,4310h
                int     2fh
@@err:
		xchg	ax,cx			; restore cmd
		push	es
		push	bx
		pop	[xmm_handler]
@@gotit:
		call	[xmm_handler]
                ret
        endp    xmm_driver


;***************************************************************
;u32 xmm_alloc(void* drv, u32 size)
;***************************************************************
        global  _xmm_alloc:near
        proc    _xmm_alloc near

                pop     bx
		ifndef	NO386
                pop     edx
                push    edx
                dec     edx
                shr     edx,10          ; to Kb
		else
                pop     ax
                pop     dx
                push    dx
                push    ax
		sub	ax,1
		sbb	dx,0
		mov	cx,10
@@tokblp:
		shr	dx,1
		rcr	ax,1
		loop	@@tokblp
		endif
                inc     dx
                push    cs
                push    bx
                mov     ah,09h          ;allocate blk
                call    xmm_driver      ;
                dec     ax
                jnz     @@err
                                        ;now: dx=handle of the blk
                mov     ah,0Ch          ;lock blk
                call    xmm_driver      ;
                dec     ax
                                        ;now: dx:bx=addr of blk
                xchg    ax,bx
                jz      @@ok
@@err:
xmm_fail:
                xor     ax,ax
                cwd
@@ok:
                retf
        endp    _xmm_alloc

        ends    _TEXT

        end

;###### END OF FILE ############################################
