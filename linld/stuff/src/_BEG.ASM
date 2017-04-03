;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p8086

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'

	macro   cpuid
        	db      0fh,0A2h
	endm

                org     100h
        global  _text_start:byte
        label   _text_start byte

;***************************************************************
; clear bss
;***************************************************************
		mov	bx,offset _bss_start
clearbss:
		mov	[byte bx],0		; clear bss + heap + sp
		inc	bx
		jne	clearbss
                cld

;***************************************************************
; check CPU
;***************************************************************

; Check for oldies
		ifndef	EXTRA
		push	sp
		pop	ax
		sub	ax,sp
		 ifndef	NO386
		mov	bx,offset msg_badcpu
                jnz	no_vcpi   	;it is a 86/186 not a 286+
		 else
                jnz	endcpu   	;it is a 86/186 not a 286+
		 endif
		else
		pushf
		mov	bh, 0F0h
		push	bx		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		popf
		add	dh,bh		; NS=386+, NC=286
		 ifndef	NO386
		mov	bx,offset msg_badcpu
                js	no_vcpi   	;it is not a 386+
		 else
                js	endcpu   	;it is not a 386+
		 endif
		endif
                p386
		ifdef	EXTRA
		pushfd
		pop	dx
		pop	ax
		mov	bl,al
		xor	al,20h		; toggle CPUID feature bit 21
		push	ax
		push	dx
		popfd
		pushfd
		pop	dx
		pop	ax
		xor	al,bl		; clear C
		je	@@check_vm	; CPUID feature bit changed ?
		mov	eax,80000001h	; Extended Processor Info and Feature Bits
		cpuid
		mov	[_cpu_features],edx
@@check_vm:
		endif
; Check for vm
                smsw    ax      ;SMSW cannot be trapped! :-)
                and     al,1	;MSW_PE
; We're in vm
		jz	check_rm_paging

;***************************************************************
; checks for vcpi
;***************************************************************
label   check_vcpi near
                push    ds
; Check whether it is safe to call 67h (we trust only known EMM managers)
		xor	bx,bx
                push    bx
                pop     ds
                mov     ds,[word 67h*4+2]
                cmp     [dword bx+10+4],'0XXX'
                jne     skip
		;mov	eax,'XMME'
		;xor	eax,[dword bx+10]
        ; QMME also works (as told by <J.S.Peatfield@damtp.cambridge.ac.uk>)
		;shl	eax,8
		mov	ax,'ME'
		xor	ax,[word bx+10]
skip:
                pop     ds
                jne     no_vcpi

; Check emm manager status and version
                ;mov     ah,40h          ; get status
                ;int     67h
                ;test    ah,ah
                ;jnz     no_vcpi
                mov     ah,46h          ; get version
                int     67h
                test    ah,ah
                jnz     no_vcpi
                cmp     al,40h          ; version must be >= 4.0
                jb      no_vcpi
; Check vcpi manager status
              ;;mov     ax,5A01h        ; ALLOCATE RAW PAGES
              ;;mov     bx,4
              ;;int     67h
              ;;test    ah,ah
              ;;jnz     no_vcpi
              ;;push    dx              ;$ save handle
                mov     ax,0DE00h       ; check for vcpi present
                int     67h
                test    ah,ah
		jnz	no_vcpi
is386vcpi:
		inc	[_vcpi]
                extrn   prepare_vcpi:near
		call	prepare_vcpi
;    get_vcpi_interface() || die("VCPI: low 640k: need 1:1 mapping");
                ;extrn   _get_vcpi_interface:near
		;call	_get_vcpi_interface
		mov	bx,offset msg_badmapping
		jz	endcpu
no_vcpi:
                p8086
              ;;pop     dx              ;$ handle
              ;;mov     ax,4500h        ; DEALLOCATE PAGES
              ;;int     67h
                extrn   die:near
godie:
		jmp	near die
check_rm_paging:
; It's a 386 in real mode, chk for paging (crazy but possible)
                p386
                mov     edx,cr0
                shl     edx,1   ;CR0_PG to CF
		jc	no_vcpi
endcpu:
                p8086

;***************************************************************
; build argv & argc
;***************************************************************
		extrn	_heap_top:word
		mov	di,[_heap_top]
		;xor	ax,ax
                ;push	ax			; envp (already cleared)
                ;mov	[word di],ax		; argv[0] = 0 (idem)
                mov	si,80h
                lodsb
                cmp	al,7Eh
                jbe	alok
                mov	al,7Eh
alok:
		cbw
		xchg	ax,bx
                mov	[bx+si],bh		; set eos
argbuild:
                mov	bx,2			; argc * 2
argeos:
                mov	dl,1			; look for a start of string
                mov	[byte si-1],bh		; mark eos
                mov	ah,20h			; space will be eos
arglp:
                lodsb
                cmp	al,0h
                je	argdone
                cmp	al,20h
                jb	argeos
                cmp	al,ah
                je	argeos
                cmp	al,27h
                je	isargstr
                cmp	al,22h
                je	isargstr
                or	dl,dl
                je	arglp			; not start of string
                dec	si
                ;jmp	newarg
		db	0B9h			; mov cx,im opcode
isargstr:
                mov	ah,al			; expected eos
newarg:
                mov	[word bx+di],si		; argv[argc++] = si
                inc	bx
                inc	bx
                dec	dx
                jmp	arglp
argdone:
                ;mov	[word bx+di],0		; argv[argc] = 0
		lea	ax,[bx+di+2]
		mov	[_heap_top],ax
                push	di			; argv
                shr	bx,1
                push	bx			; argc
	ifndef	filearg
                mov	bx,[di+2]		; argv[1]
                cmp	[byte bx],'@'
		jne	argend
                inc	bx
		extrn	open:near
		call	near open
		jc	argend
		pop	bx			; trash argc,  argv >> 1Kb !
	global	read_cmdline:near
read_cmdline:
		push	di
		push	ax
		extrn	_read:near
		call	near _read
                pop	bx			; fd for close
                pop	si			; si=buffer=argv
                add	di,ax
                pop	ax			; trash sizemax=argv
		extrn	close:near
		call	near close
                jmp	argbuild
argend:
	endif

;***************************************************************
                extrn   _main:near
                call    _main

;***************************************************************
	        global  exit:near
exit:
                mov	ah,4Ch
                int	21h
        ends    _TEXT

        segment _DATA byte public use16 'DATA'
        global  _data_start:byte
        label   _data_start byte
		ifndef	NO386
msg_badcpu      db      "I need 386+ CPU in real mode or under VCPI manager"
		endif
        global  _vcpi:byte
_vcpi		db	0
msg_badmapping  db      "VCPI: low 640k: need 1:1 mapping",0

        ends    _DATA

        segment _BSS byte public use16 'BSS'
        global  _bss_start:byte
        label   _bss_start byte
		ifdef	EXTRA
        global  _cpu_features:dword
_cpu_features	dd	?
		endif
        ends    _BSS

        end     _text_start

;###### END OF FILE ############################################
