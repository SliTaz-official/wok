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
		jne	@@gotit
		push	ax			; save cmd
                mov     ax,4300h		; installation check in al
		else
		push	ax			; save cmd
		lodsw
		or	ax,[word si]
		jne	@@gotit
                mov     ah,43h			; installation check in al
		endif

                int     2fh
                mov     bx,offset xmm_fail
                push    ds
                pop     es
                cmp     al,80h
                jne     @@err
                mov     ax,4310h		; get driver address in es:bx
                int     2fh
@@err:
		ifndef	NO386
		pop	ax			; restore cmd
		mov	[si],bx
		mov	[si+2],es
@@gotit:
		call	[dword si]		; far ptr [si]
		else
		mov	[si-2],bx
		mov	[si],es
@@gotit:
		pop	ax			; restore cmd
		call	[dword si-2]		; far ptr [si-2]
		endif
                dec     ax			; Z=1=OK
		pop	si
                ret
xmm_fail:
                xor     ax,ax
                cwd
                retf

        endp    xmm_driver

		ifdef	WITH_XMM_ALLOC
		include	"himem.inc"

;***************************************************************
;_fastcall void xmm_alloc(si:struct image_himem *m)
;***************************************************************
        global  @xmm_alloc$qp11image_himem:near
        proc    @xmm_alloc$qp11image_himem near

		ifndef	NO386
		mov	edx,[(image_himem si).size]		; m->size
                ;dec     edx
                shr     edx,10          ; to Kb
                inc     edx
                mov     ah,89h          ;allocate blk of EDX kilobytes
		else
		;mov	ax,-1
		;cwd
		;add	ax,[word (image_himem si).size]		; lo m->size
		;adc	dx,[word (image_himem si+2).size]	; hi m->size
		les	ax,[dword (image_himem si).size]	; m->size
		mov	cl,16-10
		extrn	N_LXLSH@ES:near
		call	N_LXLSH@ES
                inc     dx
                mov     ah,9h          ;allocate blk of DX kilobytes (<64Mb)
		endif
                call    xmm_driver      ;
                jnz     @@goerr
                                        ;now: dx=handle of the blk
                mov     ah,0Ch          ;lock blk
                call    xmm_driver      ;
                                        ;now: dx:bx=addr of blk
                xchg    ax,bx
@@goerr:
                jnz     @@err
		mov	[word (image_himem bx).buf],ax		; lo m->buf
		mov	[word (image_himem bx+2).buf],dx	; hi m->buf
@@err:
                ret

        endp    @xmm_alloc$qp11image_himem
		endif

        ends    _TEXT

        end

;###### END OF FILE ############################################
