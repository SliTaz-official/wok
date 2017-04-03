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

		push	si
		mov	si,offset xmm_handler
		ifndef	NO386
		cmp	[si],0
		else
		mov	ax,[word si]
		or	ax,[word si+2]
		endif
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
		pop	[dword si]
@@gotit:
		call	[dword si]
		pop	si
                ret
xmm_fail:
                xor     ax,ax
                cwd
                retf

        endp    xmm_driver


;***************************************************************
;void xmm_alloc(struct image_himem *m)
;struct image_himem {
; 0    int fd;
; 2    u32 fallback;
; 6    u32 size;
;10    u32 remaining;
;14    u32 buf;
;18    u32 *bufv;
;20    char *errmsg;
;22    u32 chunk_size;
;26    void (*next_chunk)(struct image_himem *);
;28    u16 state;
;30    u16 fd2close;
;};
;***************************************************************
        global  _xmm_alloc:near
        proc    _xmm_alloc near

                pop     ax
                pop     bx
                push    bx
                push    ax
		ifndef	NO386
		mov	edx,[bx+6]		; m->size
                dec     edx
                shr     edx,10          ; to Kb
		else
		mov	ax,[bx+6]		; lo m->size
		mov	dx,[bx+8]		; hi m->size
		sub	ax,1
		sbb	dx,0
		mov	cl,10
		extrn	N_LXURSH@:near
		call	N_LXURSH@
		endif
                inc     dx
		push	bx
                mov     ah,09h          ;allocate blk
                call    xmm_driver      ;
                dec     ax
                jnz     @@goerr
                                        ;now: dx=handle of the blk
                mov     ah,0Ch          ;lock blk
                call    xmm_driver      ;
                dec     ax
                                        ;now: dx:bx=addr of blk
                xchg    ax,bx
@@goerr:
		pop	bx
                jnz     @@err
		mov	[bx+14],ax	; lo m->buf
		mov	[bx+16],dx	; hi m->buf
@@err:
                ret

        endp    _xmm_alloc

        ends    _TEXT

        end

;###### END OF FILE ############################################
