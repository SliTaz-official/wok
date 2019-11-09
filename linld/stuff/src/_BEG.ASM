;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
                %crefref
                %noincl
                %nomacs
                p8086

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'
        ends    _TEXT

        segment _DATA byte public use16 'DATA'
        global  _data_start:byte
        label   _data_start byte
		ifndef	NO386
msg_badcpu      db      "I need 386+ CPU in real mode or under VCPI manager",0
		endif
        global  _vcpi:byte
msg_badmapping  db      "VCPI: low 640k need 1:1 mapping"
_vcpi		db	0

        ends    _DATA

        segment _BSS byte public use16 'BSS'

STACK_SIZE = 1024

        global  _bss_start:byte
        label   _bss_start byte
        global  _version_string:byte
        label   _version_string byte
		db	STACK_SIZE-2 dup(?)
stktop		dw	?
        global  _cpu_features:dword
_cpu_features	dd	?
        ends    _BSS

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
		mov	sp,offset stktop
		mov	si,offset _bss_start
		mov	bx, 0F000h	; cld ; cli & empty string
clearbss:
		mov	[si],bl		; clear bss + heap + sp
		inc	si
		jne	clearbss

;***************************************************************
; check CPU
;***************************************************************

; Check for oldies
		push	bx		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		add	dh,bh		; NS=386+, S+NC=286, S+C=86/186
		ifndef	NO386
		mov	bx,offset msg_badcpu
                js	godie   	;it is not a 386+
		else
                js	endcpu86   	;it is not a 386+
		endif
                p386
; Check for vm
                smsw    ax      ;SMSW cannot be trapped! :-)
                and     al,1	;MSW_PE
; We're in vm
		jnz	check_vcpi

check_rm_paging:
; It's a 386 in real mode, chk for paging (crazy but possible)
                mov     eax,cr0
                inc     eax             ;CR0_PG to S
		jns	endcpu386
no_vcpi:
                p8086
                extrn   die:near
godie:
		call	near die

;***************************************************************
; checks for vcpi
;***************************************************************
label   check_vcpi near
                p386
                push    ds
; Check whether it is safe to call 67h (we trust only known EMM managers)
                push    si
                pop     ds
                mov     ds,[word 67h*4+2]
                cmp     [dword si+10+4],'0XXX'
                jne     skip
		;mov	eax,'XMME'
		;xor	eax,[dword si+10]
        ; QMME also works (as told by <J.S.Peatfield@damtp.cambridge.ac.uk>)
		;shl	eax,8
		mov	ax,'ME'
		xor	ax,[word si+10]
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
                extrn   prepare_vcpi:near
		call	prepare_vcpi
;    get_vcpi_interface() || die("VCPI: low 640k: need 1:1 mapping");
                ;extrn   _get_vcpi_interface:near
		;call	_get_vcpi_interface
		mov	bx,offset msg_badmapping
		jnz	no_vcpi
		inc	[byte bx+_vcpi-msg_badmapping]
endcpu386:
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
		je	@@no_cpuid	; CPUID feature bit changed ?
		mov	eax,80000001h	; Extended Processor Info and Feature Bits
		cpuid
		mov	[_cpu_features],edx
@@no_cpuid:
endcpu86:
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
		ifdef	DEBUG
                p386
		pusha
		mov	bx,si
		extrn	puts:near
		call	puts
		popa
		endif
                mov	bx,2			; argc * 2
argeos:
                mov	cx,1			; look for a start of string
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
                jcxz	arglp			; not start of string
                dec	si
                ;jmp	newarg
		db	0BAh			; mov dx,im opcode
isargstr:
                mov	ah,al			; expected eos
newarg:
                mov	[word bx+di],si		; argv[argc++] = si
                inc	bx
                inc	bx
                dec	cx
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
		extrn	openargs:near
		call	near openargs
		jc	argend
		pop	bx			; trash argc,  argv >> 1Kb !
	global	read_cmdline:near
                pop	cx			; sizemax=argv
read_cmdline:
		mov	dx,di
		push	dx
		push	ax
		xchg	ax,bx
		extrn	@read$cxdxbx:near	; read(fd=bx,buffer=dx,size=cx)
		call	near @read$cxdxbx
                pop	bx			; fd for close
                pop	si			; si=buffer=argv
                add	di,ax
		extrn	close:near
		call	near close
                jmp	argbuild
argend:
	endif

;***************************************************************
                extrn	_main:near
                call	_main
		;never return

;***************************************************************

        ends    _TEXT


        end     _text_start

;###### END OF FILE ############################################
