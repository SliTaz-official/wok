;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
                %crefref
                %noincl
                %nomacs
                p8086

        group   DGROUP  _TEXT
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void enable_a20_xmm();
;***************************************************************
        global  _enable_a20_xmm:near
        proc    _enable_a20_xmm near

                mov     ch,03h          ;global enable a20
                call    xmm_driver      ;
                mov     ch,05h          ;local enable a20
                ;jmp     xmm_driver      ;

        endp    _enable_a20_xmm

;***************************************************************
;Call xmm driver addr (success: ax=1)
;void xmm_driver(ah)
;***************************************************************
        proc    xmm_driver near

		pop	bx			; \
		push	cs			; fake far call
		push	bx			; /
                mov     ax,4300h		; installation check in al
                int     2fh
                cmp     al,80h
                jne     @@xmm_fail	
                mov     ax,4310h		; get driver address in es:bx
                int     2fh
		xchg	ax,cx			; restore cmd

		push	es			; jmp far es:bx
		push	bx			; avoid 08h 0Fh 12h and 8Fh functions using bx
@@xmm_fail:
                retf

        endp    xmm_driver

		ifdef	WITH_XMM_ALLOC
		include	"himem.inc"

;***************************************************************
;_fastcall void xmm_alloc(si:struct image_himem *m)
;***************************************************************
        global  @xmm_alloc$qp11image_himem:near
        proc    @xmm_alloc$qp11image_himem near

		extrn	_cmdnum:dword
skip_alloc	=	(byte _cmdnum+16)
LARGE_XMM_ALLOC	=	1
		ifdef	LARGE_XMM_ALLOC
                mov     ch,89h          ;allocate blk of EDX kilobytes
		test	[skip_alloc],ch	; 89h & ('*'=2Ah) = 08h
		jne	@@err
		extrn	_cpu386:byte
		test	[_cpu386],ch
		je	@@not386
                p386
		mov	edx,[(image_himem si).size]		; m->size
                ;dec     edx
                shr     edx,10          ; to Kb
                inc     edx
                call    xmm_driver      ;
                dec     ax			; Z=OK
                jz     @@gotit
@@not386:
		mov	cl,16-10
		else
		mov	cl,16-10
		test	[skip_alloc],cl	; 06h & ('*'=2Ah) = 02h
		jne	@@err
		endif
                p8086
		;mov	ax,-1
		;cwd
		;add	ax,[word (image_himem si).size]		; lo m->size
		;adc	dx,[word (image_himem si+2).size]	; hi m->size
		les	ax,[dword (image_himem si).size]	; m->size
		extrn	N_LXLSH@ES:near
		call	N_LXLSH@ES
                inc     dx
                mov     ch,9h          ;allocate blk of DX kilobytes (<64Mb)
                call    xmm_driver      ;
                dec     ax			; Z=OK
                jnz     @@err
@@gotit:
                                        ;now: dx=handle of the blk
                mov     ch,0Ch          ;lock blk
                call    xmm_driver      ;
                                        ;now: dx:bx=addr of blk
                ;dec     ax			; Z=OK
                ;jnz     @@err
		mov	[word (image_himem si).buf],bx		; lo m->buf
		mov	[word (image_himem si+2).buf],dx	; hi m->buf
@@err:
                ret

        endp    @xmm_alloc$qp11image_himem
		endif

        ends    _TEXT

        end

;###### END OF FILE ############################################
