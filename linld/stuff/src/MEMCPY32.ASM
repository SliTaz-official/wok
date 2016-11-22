;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p386

        group   DGROUP  _TEXT,_DATA
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'
msg_badcpu      db      "I need 386+ CPU in real mode or under VCPI manager",0
        ends    _DATA

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;int _is_vm86();
;****** Return: AX=1 - it is a 386+ in virtual86 mode with vcpi
;******         AX=0 - it is a 386+ in real mode
;******         otherwise abort program
;****** Uses:   Flags
;***************************************************************
        global  _is_vm86:near
        proc    _is_vm86 near

; Check for oldies
		mov	ax, 0F000h
		pushf
		push	ax		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		popf
		add	dh,ah		; NS=386+, NC=286
		ifndef	NO386
                js	@@no_vcpi   	;it is a 86/186/286, not a 386+
		else
		js	@@ret
		endif
; Check for vm
                smsw    ax      ;SMSW cannot be trapped! :-)
                and     ax,1	;MSW_PE
; We're in vm
                jnz     check_vcpi

; It's a 386 in real mode, chk for paging (crazy but possible)
                mov     edx,cr0
                shl     edx,1   ;CR0_PG to CF
		jc	@@no_vcpi
@@ret:
                ret

;***************************************************************
;****** Helper: checks for vcpi
;***************************************************************
label   check_vcpi near
                push    ds
; Check whether it is safe to call 67h (we trust only known EMM managers)
                push    0
                pop     ds
                mov     ds,[word 67h*4+2]
                cmp     [dword 10+4],'0XXX'
                jne     @@skip
                mov     eax,[dword 10]
                cmp     eax,'XMME'
                je      @@skip
        ; this also works (as told by <J.S.Peatfield@damtp.cambridge.ac.uk>)
                cmp     eax,'QMME'
@@skip:
                pop     ds
                jne     @@no_vcpi
; Check emm manager status and version
                mov     ah,40h          ; get status
                int     67h
                test    ah,ah
                jnz     @@no_vcpi
                mov     ah,46h          ; get version
                int     67h
                test    ah,ah
                jnz     @@no_vcpi
                cmp     al,40h          ; version must be >= 4.0
                jb      @@no_vcpi
; Check vcpi manager status
              ;;mov     ax,5A01h        ; ALLOCATE RAW PAGES
              ;;mov     bx,4
              ;;int     67h
              ;;test    ah,ah
              ;;jnz     @@no_vcpi
              ;;push    dx              ;$ save handle
                mov     ax,0DE00h       ; check for vcpi present
                int     67h
                mov     al,1
                test    ah,ah
                jz      @@386vcpi
              ;;pop     dx              ;$ handle
              ;;mov     ax,4500h        ; DEALLOCATE PAGES
              ;;int     67h
@@no_vcpi:
		mov	bx,offset msg_badcpu
                extrn   die:near
		jmp	near die
@@386vcpi:
		mov	[_vcpi],al
                extrn	@init_vcpi$qv:near
                jmp	near @init_vcpi$qv

        endp    _is_vm86


;***************************************************************
;void dos_shutdown()
;***************************************************************
        global  dos_shutdown:near
        proc    dos_shutdown near

;TODO NO386
dos_shutdown:
		pusha
		xor	bx,bx
		mov	ds,bx
		push	[dword bx+4]		; save step
		mov	ax,sp
		push	ss
		push	ax
		pop	[dword cs:sssp]
		;cmp	[byte bx+7],0F0h
		;jnc	notdos
		mov	[word bx+4],offset step19
		mov	[bx+6],cs
		pushf
		pop	ax
		inc	ah			; set TF
		push	ax
		popf
		jmp	small [dword bx+4*19h]
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
		lss	sp,[dword cs:sssp]
		xor	bx,bx
		mov	ds,bx
		pop	[dword bx+4]		; restore step
		popa
		push	cs
		pop	ds
		ret

        endp    dos_shutdown


;***************************************************************
;void memcpy32(u16 dstseg,u32 dstofs,u16 srcseg,u32 srcofs,u32 size);
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  _memcpy32:near
        proc    _memcpy32 near

;TODO NO386
; rm32,imm16 helper
macro   addzx_e rm,i
        db      66h
        add     rm,i
        dw      0
endm
                arg     dstseg  :word,  \
                        dstofs  :dword, \
                        srcseg  :word,  \
                        srcofs  :dword, \
                        sz      :dword  = PARAM_SIZE

                local   GDTR    :pword, \
                        oldGDTR :pword  = TEMP_SIZE

;****** Init ***************************************************
                enter   TEMP_SIZE,0
                pushf
                push    es ds esi edi
                movzx   esi,[srcseg]
                shl     esi,4
                add     esi,[srcofs]
                movzx   edi,[dstseg]
                shl     edi,4
                add     edi,[dstofs]
	ifndef	pm_only
		mov	eax,00100000h
		cmp	esi,eax
                jnb     pmcopy
		cmp	edi,eax
                jnb     pmcopy
		mov	eax,esi
		shr	eax,4
		mov	ds,ax
		mov	edx,edi
		shr	edx,4
@@movlp:
		mov	ds,ax
		mov	es,dx
		and	si,0Fh
		and	di,0Fh
		mov	cx,08h
		cld
            rep movsw
		inc	ax
		inc	dx
                sub     [sz],10h
                ja	@@movlp
		jmp	done
	endif
pmcopy:
                mov     ecx,[sz]
		mov	dx,-1

	ifdef	keep_int15
                jecxz   godone
		test	[_vcpi],dl
		jne	with_movsw

		push	ss
		pop	es
		inc	ecx
		shr	ecx,1
		mov	bx,9318h
clear:
		push	0
		dec	bl
		jnz	clear
  		xchg	eax,esi
  		mov	si,sp
		mov	[si+12h],eax
		mov	[si+1Ah],edi
		mov	[si+10h],dx
		mov	[si+18h],dx
		mov	edi,ecx
		mov	dh,93h
		xchg	bx,[si+14h]
		xchg	dx,[si+1Ch]
mvlp:
		mov	[si+14h],bl
		mov	[si+17h],bh
		mov	[si+1Ch],dl
		mov	[si+1Fh],dh
		xor	ecx,ecx
		mov	ch,80h
		sub	edi,ecx
		pushf
		jnc	domv
		add	ecx,edi
domv:
	;push	bx dx si edi
		mov	ah,87h
		int	15h
	;pop	edi si dx bx
		inc	bx
		inc	dx
		popf
		jnc	mvlp
		add	sp,30h
godone:
		jmp	done
	else
                jecxz   done
	endif

with_movsw:
                cld
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
                mov     [word GDTR],dx          ;GDT limit = 0FFFFh
                mov     [dword GDTR+2],eax      ;GDT base
                lgdt    [GDTR]

;****** Go into pm *********************************************
                mov     eax,cr0
                or      al,01h          ;CR0_PE on
                mov     cr0,eax
                jmp     short $+2       ;*Required*!
                                        ;3+ NOPs also work fine (chkd on 386)
;****** Move data **********************************************
                push    0008h
                pop     ds              ;base=0, lim = 4gb
                push    ds              ;
                pop     es              ;
                db      66h     ;operand width override for ecx
                db      67h     ;address width override for esi/edi
            rep movsb
                cld

;****** Return to rm *******************************************
                dec     ax              ;CR0_PE off
                mov     cr0,eax         ;ds/es limits are *not* reset to 64kb
                                        ;  but who cares :-)
                jmp     short $+2

;****** Return *************************************************
                lgdt    [oldGDTR]
done:
                cld
                pop     edi esi ds es
                popf
                leave
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

        global  _vcpi:byte
_vcpi		db	0

        endp    _memcpy32

        ends    _TEXT

        end

;###### END OF FILE ############################################
