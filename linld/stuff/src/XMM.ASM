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
;void xmm_driver(ah)
;***************************************************************
        proc    xmm_driver near

		push	si
		mov	si,offset xmm_handler
		ifndef	NO386
		cmp	[dword si],0
		else
		mov	cx,[word si]
		or	cx,[word si+2]
		endif
		jne	@@gotit

		push	ax			; save cmd
                mov     ax,4300h		; installation check in al
                int     2fh
                mov     bx,offset xmm_fail
                push    ds
                pop     es
                cmp     al,80h
                jne     @@err
                mov     ax,4310h		; get driver address in es:bx
                int     2fh
@@err:
		pop	ax			; restore cmd
		mov	[si],bx
		mov	[si+2],es
@@gotit:
		call	[dword si]		; far ptr [si]
                dec     ax			; Z=1=OK
		pop	si
                ret
xmm_fail:
                xor     ax,ax
                cwd
                retf

        endp    xmm_driver


struc   image_himem		;struct image_himem {
fd		dw	?	; 0    int fd;
fallback	dd	?	; 2    u32 fallback;
size		dd	?	; 6    u32 size;
remaining	dd	?	;10    u32 remaining;
buf		dd	?	;14    u32 buf;
bufv		dw	?	;18    u32 *bufv;
errmsg		dw	?	;20    char *errmsg;
chunk_size	dd	?	;22    u32 chunk_size;
next_chunk	dw	?	;26    void (*next_chunk)(struct image_himem *);
state		dw	?	;28    u16 state;
fd2close	dw	?	;30    u16 fd2close;
ends				;};

;***************************************************************
;_fastcall void xmm_alloc(struct image_himem *m)
;***************************************************************
        global  @xmm_alloc$qp11image_himem:near
        proc    @xmm_alloc$qp11image_himem near

		ifndef	NO386
		mov	edx,[(image_himem bx).size]		; m->size
                ;dec     edx
                shr     edx,10          ; to Kb
                inc     edx
                mov     ah,89h          ;allocate blk of EDX kilobytes
		else
		;mov	ax,-1
		;cwd
		;add	ax,[word (image_himem bx).size]		; lo m->size
		;adc	dx,[word (image_himem bx+2).size]	; hi m->size
		les	ax,[dword (image_himem bx).size]	; m->size
		mov	cl,16-10
		extrn	N_LXLSH@ES:near
		call	N_LXLSH@ES
                inc     dx
                mov     ah,9h          ;allocate blk of DX kilobytes (<64Mb)
		endif
		push	bx
                call    xmm_driver      ;
                jnz     @@goerr
                                        ;now: dx=handle of the blk
                mov     ah,0Ch          ;lock blk
                call    xmm_driver      ;
                                        ;now: dx:bx=addr of blk
                xchg    ax,bx
@@goerr:
		pop	bx
                jnz     @@err
		mov	[word (image_himem bx).buf],ax		; lo m->buf
		mov	[word (image_himem bx+2).buf],dx	; hi m->buf
@@err:
                ret

        endp    @xmm_alloc$qp11image_himem

        ends    _TEXT

        end

;###### END OF FILE ############################################
