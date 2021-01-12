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

macro	lcr0	reg
	mov	cr0,reg
	jmp	short $+2	;*Required*!
				;3+ NOPs also work fine (chkd on 386)
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

			ifndef	NO386

		enter	0,0
		;cld
                pushf
                push    ds es
		pushad				; struct declared in VCPI.ASM
		mov	cl,4
                movzx   esi,[srcseg]
                shl     esi,cl
                add     esi,[srcofs]
                mov     [srcofs],esi		; for memcpy_vcpi
                mov     edi,[dstofs]

	ifndef	pm_only
		mov	eax,esi
		shr	eax,cl
		mov	edx,edi
		shr	edx,cl
		mov	ecx,esi
		or	ecx,edi
		shr	ecx,20			; >1mb ?
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

		push	bp
		mov	bp,sp
		;cld
                pushf
                push    ds es
		push	si
		xor	bx,bx
		xor	si,si
		mov	ax,[srcseg]
		extrn	N_LXLSH@4:near
		call	near ptr N_LXLSH@4
		add	[word srcofs],ax
		adc	[word srcofs+2],dx
@@2flat:
		les	ax,[dword si+srcofs]	; srcofs, dstofs
		mov	dx,es
		mov	cl,4
@@loop:
		shr	dx,1
		rcr	ax,1
		loop	@@loop
		or	bx,dx			; >=1mb flag
		push	ax			; srcseg, dstseg
		xor	si,-6
		jnz	@@2flat
		pop	dx			; dstseg
		pop	ax			; srcseg
		cmp	bx,si			; <1mb ?
                jne     @@pmcopy
		push	di
@@movlp:
		mov	ds,ax
		mov	es,dx
		inc	ax
		inc	dx
		mov	cl,0Fh
		mov	si,cx
		mov	di,cx
		and	si,[word srcofs]
		and	di,[word dstofs]
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
		pop	di
		jmp	@@done16
@@pmcopy:
                p386
		pushad				; struct declared in VCPI.ASM
                mov     esi,[srcofs]
                mov     edi,[dstofs]

			endif

                mov     ecx,[sz]
                jecxz   @@done

		smsw	ax
                and     al,1	;MSW_PE
		jz	@@real_mode
; Note: bp points to std stack frame now. bp will be passed to
; pm routine. This allows params to be passed on stack
		extrn	vcpi_pm_copy_routine:near
                call    near vcpi_pm_copy_routine ; Call pm copy routine via vcpi pm
		jmp	@@done
@@real_mode:
                cmp     esi,edi
                jae     @@do_copy
                add     esi,ecx         ;src<dst: we must do
                dec     esi             ;  copy backwards to avoid
                add     edi,ecx         ;  overwrite bug
                dec     edi             ;
                std                     ;
@@do_copy:
                cli
oldGDTR		=	(pword srcseg)	; don't need src seg/ofs anymore
                sgdt    [oldGDTR]

;****** Load gdtr **********************************************
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
                ;db      66h     ;operand width override for ecx
                db      67h     ;address width override for esi/edi
            rep movsb
		;cld

;****** Return to rm *******************************************
                dec     ax              ;CR0_PE off
		lcr0	eax
;****** Return *************************************************
                lgdt    [oldGDTR]
@@done:
                popad
                p8086
@@done16:
			ifdef	NO386
		pop	si
			endif
                pop     es ds
		popf			; restore I & D
			ifndef	NO386
                p386
		leave
			else
		pop	bp
			endif
                ret	14

;****** Const data *********************************************

		extrn	gdt_memcpy
label	GDTR	pword
gdt_limit	dw	0ffffh
		global	gdt_base_memcpy:word
gdt_base_memcpy dw	offset gdt_memcpy,0

        endp    memcpy32

        ends    _TEXT

        end

;###### END OF FILE ############################################
