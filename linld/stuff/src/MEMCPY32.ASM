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

        group   DGROUP  _TEXT,_DATA
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'
        ends    _DATA

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void dos_shutdown()
;***************************************************************
        global  dos_shutdown:near
        proc    dos_shutdown near

dos_shutdown:
		ifndef	NO386
		;pusha
		else
		;push	bp si di
		endif
		xor	bx,bx
		mov	ds,bx
		ifndef	NO386
		push	[dword bx+4]		; save step
		mov	ax,sp
		push	ss
		push	ax
		pop	[dword cs:sssp]
		mov	[word bx+4],offset step19
		else
		mov	ax,offset step19
		xchg	ax,[word bx+4]
		push	[word bx+6]	
		push	ax			; save step
		mov	[word cs:sssp],sp
		mov	[word cs:sssp+2],ss
		endif
		;cmp	[byte bx+7],0F0h
		;jnc	notdos
		mov	[bx+6],cs
		pushf
		pop	ax
		inc	ah			; set TF
		push	ax
		popf
		jmp	[dword bx+4*19h]
doiret:
		iret
sssp:
		dd	0
step19:
		push	bx
		push	ds
		mov	bx,sp
		lds	bx,[dword ss:bx+4]	; read cs:ip
		cmp	[word bx],19CDh		; int 19h ?
		pop	ds
		pop	bx
		jne	doiret
notdos:
		ifndef	NO386
		lss	sp,[dword cs:sssp]
		else
		lds	ax,[dword cs:sssp]
		push	ds
		pop	ss
		xchg	ax,sp
		endif
		xor	bx,bx
		mov	ds,bx
		ifndef	NO386
		pop	[dword bx+4]		; restore step
		;popa
		else
		pop	[word bx+4]		; restore step
		pop	[word bx+6]
		;pop	di si bp
		endif
		push	cs
		pop	ds
		ret

        endp    dos_shutdown


;***************************************************************
;void memcpy32(u32 dstofs,u16 srcseg,u32 srcofs,u32 size);
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  _memcpy32:near
        proc    _memcpy32 near

; rm32,imm16 helper
macro   addzx_e rm,i
        db      66h
        add     rm,i
        dw      0
endm
                arg     dstofs  :dword, \
                        srcseg  :word,  \
                        srcofs  :dword, \
                        sz      :dword  = PARAM_SIZE

                local   GDTR    :pword, \
                        oldGDTR :pword  = TEMP_SIZE

;****** Init ***************************************************

			ifndef	NO386

		enter	TEMP_SIZE,0
		;cld
                pushf
                push    ds es
                pushad
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
            rep movsb
                ja	@@movlp
		jmp	@@done
	endif
@@pmcopy:
			else

		push	bp
		mov	bp,sp
		sub	sp,TEMP_SIZE
		;cld
                pushf
                push    ds es
		push	si
		xor	bx,bx
		xor	dx,dx
		xor	si,si
		mov	ax,[srcseg]
		mov	cl,4
		extrn	N_LXLSH@:near
		call	near N_LXLSH@
		add	[word srcofs],ax
		adc	[word srcofs+2],dx
@@2flat:
		mov	ax,[word si+srcofs]	; srcofs, dstofs lo
		mov	dx,[word si+srcofs+2]	; srcofs, dstofs hi
		extrn	N_LXURSH@4:near
		call	near N_LXURSH@4
		or	bx,dx			; >=1mb flag
		push	ax			; srcseg, dstseg
		xor	si,-6
		jnz	@@2flat
		pop	dx			; dstseg
		pop	ax			; srcseg
		dec	bx			; <1mb ?
                jns     @@pmcopy
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
            rep movsb
		ja	@@movlp
		dec	[word sz+2]
		jns	@@movlp			; mov 1-16 more bytes...
		pop	di
@@pmcopy:
		pop	si
		js	@@done16
                p386
                pushad
                mov     esi,[srcofs]
                mov     edi,[dstofs]

			endif

                mov     ecx,[sz]
                jecxz   @@done

		smsw	ax
		test	al,1
		jz	@@real_mode
; Note: bp points to std stack frame now. bp will be passed to
; pm routine. This allows params to be passed on stack
		extrn	do_memcpy_vcpi:near
                push    offset do_memcpy_vcpi
		extrn	call_pm_routine:near
                call    near call_pm_routine ; Call pm copy routine via vcpi pm
                pop     ax
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
                sgdt    [oldGDTR]

;****** Load gdtr **********************************************
                mov     eax,cs
                shl     eax,4
                addzx_e ax,<offset GDT>
                or      [word GDTR],-1          ;GDT limit = 0FFFFh
                mov     [dword GDTR+2],eax      ;GDT base
                lgdt    [GDTR]

;****** Go into pm *********************************************
                mov     eax,cr0
                inc     ax		;CR0_PE on
                mov     cr0,eax
                jmp     short $+2       ;*Required*!
                                        ;3+ NOPs also work fine (chkd on 386)
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
                mov     cr0,eax         ;ds/es limits are *not* reset to 64kb
                                        ;  but who cares :-)
                jmp     short $+2

;****** Return *************************************************
                lgdt    [oldGDTR]
@@done:
                popad
                p8086
@@done16:
                pop     es ds
                popf
			ifndef	NO386
                p386
		leave
			else
		mov	sp,bp
		pop	bp
			endif
                ret

;****** Const data *********************************************
                org     $-8     ;save 8 bytes - they are unused anyway
;0000: unused
GDT             dd      ?,?
;0008: Data seg [0,FFFFFFFF]
                ;       lim_lo              base_lo
                dw      1111111111111111b,  0000000000000000b
                db      00000000b,10010010b,10001111b,00000000b
                ;       base_med  P  S D A  G ??l_hi  base_hi
                ;                  Pl E W    D

        endp    _memcpy32

        ends    _TEXT

        end

;###### END OF FILE ############################################
