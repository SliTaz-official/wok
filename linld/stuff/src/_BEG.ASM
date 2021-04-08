;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 255
                %crefref
                %noincl
                %nomacs

	include	"common.inc"
	include "himem.inc"
	include	"isostate.inc"

	ifdef	QUICK_BOOT
CMDNUMCNT	=	7
	else
CMDNUMCNT	=	5
	endif

	macro	alloc_isostate
		public	_isostate
_isostate	isostate	<?>
		org	$-ISOSTATE_OVERLAP
	endm

	macro	alloc_image
rm_size		dw	?		; _imgs-4
rm_buf		dw	?		; _imgs-2
		global	_imgs:byte
label	_imgs	byte
img_kernel	image_himem	?
img_initrd	image_himem	?
	endm

	macro	alloc_cmdnum
		global	_cmdnum:word
label   _cmdnum	word
		dd	CMDNUMCNT	dup(?)
	endm

                p8086

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'
        ends    _TEXT

        segment _DATA byte public use16 'DATA'
        ;global  _data_start:byte
        label   _data_start byte
		ifndef	NO386
msg_badcpu      db      "I need a 386+ in real mode w/o paging"
		ifdef	VCPI
		db	" or "
msg_badmapping	db	"under VCPI 4.0+ manager with low 640k 1:1 mapping"
        global  _vcpi:byte
		endif
_vcpi		db	0
		endif

        ends    _DATA

        segment _BSS byte public use16 'BSS'

	ifdef ISO9660
		ifndef	VCPI
		alloc_isotate
		else
room_for_isostate	=	1
		endif
	endif

		ifdef	ISOHOOK
	extrn	_big_cmdline:byte
		db	254 dup(?)
		endif
        ;global  _bss_start:byte
        label   _bss_start byte
        global  stktop:byte
        global  _cpu386:byte
_cpu386		db	?
		ifdef	CPU64
		org	$-1
        global  _cpu_features:dword
_cpu_features	dd	?
room_for_image	=	1
		else
		alloc_image
		endif

;BSS_OVERLAP_BOOT	=	1

		ifndef	BSS_OVERLAP_BOOT

		ifdef	room_for_isostate
		alloc_isostate
		endif

		ifdef	room_for_image
		alloc_image
		endif

		alloc_cmdnum

		endif

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

	macro   cpuid
        	db      0fh,0A2h
	endm

                org     100h
        ;global  _text_start:byte
        label   _text_start byte

;***************************************************************
; clear bss
;***************************************************************
		mov	sp,offset stktop
		mov	bx, 0F000h	; cld ; cli & empty string
		mov	si,offset _bss_start
clearbss:
		mov	[si],bl		; clear bss + heap
		inc	si
		jne	clearbss

;***************************************************************
; check CPU
;***************************************************************

; Check for oldies
		push	bx		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0, cld
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		add	dh,bh		; NS=386+, S+NC=286, S+C=86/186
		ifndef	NO386
		mov	bx,offset msg_badcpu
                js	godie   	;it is not a 386+, die
		else
                js	endcpu86   	;it is not a 386+, try ELKS & co
		endif
                p386
		ifdef	VCPI
                mov     edx,cs
                shl     edx,4		; edx for prepare_vcpi
		else
 		 ifndef	LARGE_ZIMAGE
                mov     edx,cs
                shl     edx,4		; edx for memcpy32
		 endif
		endif
		ifndef	LARGE_ZIMAGE
		extrn	gdt_base_memcpy:word	; gdt_base for memcpy32
		add	[dword gdt_base_memcpy],edx
		endif

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
		ifndef	NO386
                p8086
                extrn   die:near
godie:
		call	near die
		else
		jmp	endcpu86
		endif


;***************************************************************
; checks for vcpi
;***************************************************************
label   check_vcpi near
                p386
		ifdef	VCPI
; Check whether it is safe to call 67h
		xor	eax,eax
		push	ds
                mov     ds,ax
                cmp     [dword 67h*4],eax
		pop	ds
                je      no_vcpi
                mov     ah,0DEh		; check for vcpi present
                int     67h
                or	ah,ah
		jnz	no_vcpi
is386vcpi:
                extrn   prepare_vcpi:near
		call	prepare_vcpi
;    get_vcpi_interface() || die("VCPI: low 640k: need 1:1 mapping");
                ;extrn   _get_vcpi_interface:near
		;call	_get_vcpi_interface
		ifndef	NO386
		mov	bx,offset msg_badmapping
		jnz	no_vcpi
		dec	[byte bx+_vcpi-msg_badmapping]
		else
		jnz	no_vcpi
		extrn	_vcpi:byte
		dec	[byte _vcpi]
		endif
		endif
no_vcpi:
endcpu386:
		ifdef	CPU64
		pushfd
		pop	dx
		pop	ax
		mov	bl,al
		xor	al,20h		; toggle CPUID feature bit 21 (=> pentium+)
		push	ax		;  (toggle AC: bit 18 => 486+)
		push	dx
		popfd
		pushfd
		pop	dx		; dx.1=flags.1=1
		pop	ax
		xor	al,bl		; clear C
		je	@@no_cpuid	; CPUID feature bit changed ?
		mov	eax,80000001h	; Extended Processor Info and Feature Bits
		cpuid
		mov	dl,-1		; set 386 flag (assume cpuid => fpu:bit0=1 ?)
		ifdef	NO386
		db	66h		; mov [_cpu_features],edx
@@no_cpuid:
		mov	[word _cpu_features],dx	; dl != 0
		else
		mov	[_cpu_features],edx
@@no_cpuid:
		endif
		else
		dec	[_cpu386]
		endif
endcpu86:
                p8086

;***************************************************************
; build argv & argc
;***************************************************************
                mov	si,80h
		ifdef	ISOHOOK
                mov	bx,offset _big_cmdline
		cmp	[byte si],2
		jnb	@@user_args
		call	@set_cmdline$qpxzc
@@user_args:
		endif
                lodsb				; size 0..127
		cbw
		ifdef	ISOHOOK
		inc	ax
		jnz	short_cmdline
		mov	si,bx
                lodsb				; size 0..254
short_cmdline:
		dec	ax
		endif
		xchg	ax,bx
                mov	[bx+si],bh		; set eos

;***************************************************************

		ifdef	BSS_OVERLAP_BOOT
		mov	di,offset clean-100h

		org	$-(CMDNUMCNT*4)			; alloc_cmdnum

		ifdef	room_for_image
		org	$-2-2-(2*size image_himem)	; alloc_image
		endif

		ifdef	room_for_isostate
		org	$+ISOSTATE_OVERLAP-size isostate
		alloc_isostate
		endif

		ifdef	room_for_image
		alloc_image
		endif

		alloc_cmdnum
clean:
		mov	[di+0FFh],bh
		dec	di
		jnz	clean
		endif

		org	$-4				; _himem_buf
		global	_himem_buf:dword
_himem_buf	dd	?

;***************************************************************
		extrn	_bss_end:word
		mov	di,offset _bss_end
		global	_heap_top
		org	$-2
_heap_top	dw	?
		;xor	dx,dx
                ;push	dx			; envp (already cleared)
                ;mov	[word di],dx		; argv[0] = 0 (idem)
argbuild:
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

;***************************************************************
;_fastcall void set_cmdline(bx:const char *filename);
;***************************************************************
        global  @set_cmdline$qpxzc:near
        proc	@set_cmdline$qpxzc near
		extrn	openargs:near
		call	openargs
		jc	@ret
		mov	ch,15			; cx<4096
		mov	di,[_heap_top]
		jmp	read_cmdline		; read_cmdline(ax,di,cx)

        endp	@set_cmdline$qpxzc

		ifdef	NO386
;***************************************************************
;u16 topseg();
;***************************************************************
        global  _topseg:near
        proc    _topseg near

		int	12h
		jnc	@@max640k
		mov	ax,640			; 9000
@@max640k:
		dec	ax
		and	al,0C0h
		mov	cl,6
		shl	ax,cl
@ret:
		ret

        endp    _topseg
		else
@ret:
		ret
		endif

;***************************************************************
argdone:
                ;mov	[word bx+di],0		; argv[argc] = 0
		lea	ax,[bx+di+2]
		mov	[_heap_top],ax
                ;push	di			; argv
                ;shr	bx,1
                ;push	bx			; argc
	ifndef	filearg
                mov	bx,[di+2]		; argv[1]
		extrn	openargs:near
		call	near openargs
		jc	argend
		;pop	bx			; trash argc,  argv >> 1Kb !
                ;pop	cx			; sizemax=argv
		dec	cx			; sizemax=0ffffh
read_cmdline:
		mov	dx,di
		push	dx
		xchg	ax,bx
		extrn	@read$cxdxbx:near	; read(fd=bx,buffer=dx,size=cx)
		call	near @read$cxdxbx
                pop	si			; si=buffer=argv
                add	di,ax
		ifndef	NO_CLOSE
		extrn	close:near
		call	near close
		endif
                jmp	argbuild
argend:
	endif

;***************************************************************
;                extrn	_main:near
;                call	_main
		;never return

;***************************************************************


        ends    _TEXT


        end     _text_start

;###### END OF FILE ############################################
