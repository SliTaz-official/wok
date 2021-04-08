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

macro	lcr0	reg
	mov	cr0,reg
	jmp	short $+2	;*Required*!
				;3+ NOPs also work fine (chkd on 386)
endm

macro   addzx_e rm,i
        db      66h
        add     rm,i
        dw      0
endm

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void memcpy32(u32 dstofs,u16 srcseg,u32 srcofs,u32 size);
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  memcpy32:near
        proc    memcpy32 near

                arg     dstofs  :dword, \
                        srcseg  :word,  \
                        srcofs  :dword, \
                        sz      :dword  = PARAM_SIZE

;****** Init ***************************************************

		push	bp
		mov	bp,sp
		;cld
                pushf
                push    ds

			ifndef	NO386

		pushad				; struct declared in VCPI.ASM
		mov	cl,4
                movzx   esi,[srcseg]
                shl     esi,cl
                add     esi,[srcofs]
                mov     edi,[dstofs]

	ifndef	pm_only
		mov	eax,esi
		shr	eax,cl
		mov	edx,edi
		shr	edx,cl
		lea	ecx,[eax+edx]
		shr	ecx,16			; >1mb ?
                jnz     @@pmcopy
@@movlp:
		mov	ds,ax
		mov	es,dx
		inc	ax
		inc	dx
		mov	cl,0Fh
		and	si,cx
		and	di,cx
		inc	cx
                sub     [sz],ecx
		jae	@@movpara
		add	ecx,[sz]
@@movpara:
            rep movsb
                ja	@@movlp
		jmp	@@done
	endif
@@pmcopy:
			else

		push	si
		push	di
		xor	si,si
		mov	ax,[srcseg]
		extrn	N_LXLSH@4:near
		call	near ptr N_LXLSH@4
		add	[word srcofs],ax
		adc	[word srcofs+2],dx
@@2flat:
		les	dx,[dword si+srcofs]	; srcofs, dstofs
		mov	di,dx			; dstofs
		mov	ax,es
		mov	cl,4
@@loop:
		shr	ax,1			; high
		rcr	dx,1			; low
		loop	@@loop
		push	dx			; srcseg, dstseg
		xchg	ax,bx			; save/restore high srcreg
		xor	si,-6
		jnz	@@2flat
		or	bx,ax			; srcseg & dstseg < 1mb ? clear C
		pop	dx			; dstseg
		pop	ax			; srcseg
                jnz	@@pmcopy
@@movlp:					; bx=cx=0
		mov	ds,ax
		mov	es,dx
		inc	ax
		inc	dx
		mov	cl,0Fh
		mov	si,cx
		and	di,cx
		and	si,[word srcofs]
		inc	cx
                sub     [word sz],cx
		;jae	@@movpara
		sbb	[word sz+2],bx
		jae	@@movpara
		add	cx,[word sz]
		;stc
@@movpara:
            rep movsb
		jae	@@movlp
@@pmcopy:
		pop	di
		pop	si
		jc	@@done16
                p386
		pushad				; struct declared in VCPI.ASM
                mov     esi,[srcofs]
                mov     edi,[dstofs]

			endif

                mov     ecx,[sz]
                jecxz   @@done
                cli

		ifdef	VCPI
		smsw	ax
                and     al,1	;MSW_PE
		jz	@@real_mode
; Note: bp points to std stack frame now. bp will be passed to
; pm routine. This allows params to be passed on stack
		extrn	vcpi_pm_copy_routine:near
                call    near vcpi_pm_copy_routine ; Call pm copy routine via vcpi pm
		jmp	@@done
		endif
@@real_mode:
oldGDTR		=	(pword srcseg)	; don't need src seg/ofs anymore
                sgdt    [oldGDTR]

;****** Load gdtr **********************************************
		ifdef	LARGE_ZIMAGE
		local	rflags: word, rds: word, \
			reax: dword, recx: dword, redx: dword, rebx: dword, \
			resp: dword, rebp: dword, resi: dword, redi: dword, \
			GDTR: pword = LOCAL_SIZE
		mov	eax,cs
		shl	eax,4
		addzx_e	ax,<offset gdt_memcpy>
		push	eax		; gdt_base_memcpy
		push	-1		; gdt_limit
		endif

                lgdt    [GDTR]

;****** Go into pm *********************************************
                mov     eax,cr0
                inc     ax		;CR0_PE on
		lcr0	eax
;****** Move data **********************************************
                push    0008h
                pop     ds              ;base=0, lim = 4gb
                push    ds              ;
                pop     es              ;
                cmp     esi,edi
                jae     @@do_copy
                add     esi,ecx         ;src<dst: we must do
                add     edi,ecx         ;  copy backwards to avoid
                std                     ;  overwrite bug
                db      67h		;address width override for esi/edi
		cmpsb			;  dec esi/edi
@@do_copy:
                ;db      66h     ;operand width override for ecx
                db      67h     ;address width override for esi/edi
            rep movsb
		;cld

;****** Return to rm *******************************************
                dec     ax              ;CR0_PE off
		lcr0	eax
;****** Return *************************************************
                lgdt    [oldGDTR]
		ifdef	LARGE_ZIMAGE
		add	sp,6
		endif
@@done:
                popad
                p8086
@@done16:
                pop     ds
		popf			; restore I & D
		pop	bp
                ret	14

;****** Const data *********************************************

		ifdef	VCPI
		extrn	gdt_memcpy
		else
		org	$-8	;save 8 bytes
;0000: unused
gdt_memcpy	dd	?,?
;0008: Data seg [0,FFFFFFFF]
		;	lim_lo              base_lo
		dw	1111111111111111b,  0000000000000000b
		db	00000000b,10010010b,10001111b,00000000b
		;	base_med  P  S D A  G ??l_hi  base_hi
		;	           Pl E W    D
		endif
		ifndef	LARGE_ZIMAGE
label	GDTR	pword
gdt_limit	dw	0ffffh
		global	gdt_base_memcpy:word
gdt_base_memcpy dw	offset gdt_memcpy,0
		endif

        endp    memcpy32

        ends    _TEXT

        end

;###### END OF FILE ############################################
