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

CMDNUMCNT	=	5
	ifdef	MINRAM
CMDNUMCNT	=	CMDNUMCNT+1
	endif
	ifdef	CPUTYPE
CMDNUMCNT	=	CMDNUMCNT+1
	endif
	ifdef	QUICK_BOOT
CMDNUMCNT	=	CMDNUMCNT+2
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
		ifdef	CPUTYPE
	global	_cputype:word
_cputype	dw	?
		endif
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
		ifdef	CPUTYPE
		mov	ax,bx
		mov	cl,32+7		; 186+ masks with 31
		shr	ah,cl
		endif
		push	bx		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0, cld, cli
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		add	dh,bh		; 160:NS=386+, 0F0:NC=286, 1E0:PO=86/186
		ifndef	NO386
		mov	bx,offset msg_badcpu
                js	godie   	;it is not a 386+, die
		else
		ifdef	CPUTYPE
		jc	not286
		mov	ah,2
not286:
                js	jmp_endcpu86   	;it is not a 386+, try ELKS & co
		else
                js	endcpu86   	;it is not a 386+, try ELKS & co
		endif
		endif
                p386
		ifdef	VCPI
                mov     edx,cs
                shl     edx,4		; edx for prepare_vcpi (edx[31-20]=0) [1]
		else
 		 ifndef	LARGE_ZIMAGE
                mov     edx,cs
                shl     edx,4		; edx for memcpy32 (edx[31-20]=0) [1]
		 endif
		endif
		ifndef	LARGE_ZIMAGE
		extrn	gdt_base_memcpy:word	; gdt_base for memcpy32
		add	[dword gdt_base_memcpy],edx
		endif

; Check for vm
                smsw    bx      ;SMSW cannot be trapped! :-)
                shr	bx,1	;MSW_PE
; We're in vm
		jc	check_vcpi

check_rm_paging:
; It's a 386 in real mode, chk for paging (crazy but possible)
                mov     ebx,cr0
                inc     ebx             ;CR0_PG to S
		jns	endcpu386
		ifndef	NO386
                p8086
                extrn   die:near
godie:
		call	near die
		else
jmp_endcpu86:
		jmp	endcpu86	;386+ rm will fake 186+
		endif


;***************************************************************
; checks for vcpi
;***************************************************************
label   check_vcpi near
                p386
		ifdef	VCPI
                mov     ah,0DEh		; check for vcpi present
                int     67h
                or	ah,ah
		jnz	no_vcpi
is386vcpi:
                extrn   prepare_vcpi:near
		call	prepare_vcpi	; assume ES = DS
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
		ifdef	CPUTYPE
		xor	al,24h		; toggle CPUID feature bit & AC bit
		else
		xor	al,20h		; toggle CPUID feature bit 21 (=> pentium+)
		endif
		push	ax		;  (toggle AC: bit 18 => 486+)
		push	dx
		popfd
		pushfd
		pop	dx
		pop	dx
		xor	al,dl		; clear C; 00=P5+=PE+Z 20=486=PO 24=386=PE
		ifdef	CPUTYPE
		 ifndef	VCPI
 		  ifdef	LARGE_ZIMAGE
		cdq			; 386 and 486 are not 64 bits
		  endif
		 endif
		mov	ax,0400h
		jpo	is486
		mov	ah,3
is486:
		jne	set_cputype	; edx[31-20]=0 see [1]; edx.26=lm=0
		xchg	ax,si		; si=0300h
basicCPUID:
		xor	eax,eax
		inc	ax
		cpuid			; Basic cpuid (late 486 or Pentium)
		inc	si
		jpo	basicCPUID	; again cause of Nasty EMM386s	
		push	eax
		shr	edx,1+26	; test bit 26 (sse2), clear bit 29 (avoid tm/lm confusion)
		jnc	baseInfo
		else
		jne	@@no_cpuid	; CPUID feature bit changed ?
		endif
		mov	eax,80000001h	; Extended Processor Info and Feature Bits (Pentium 4 or newer)
		cpuid			; Extended cpuid (Pentium 4)
		ifdef	CPUTYPE
baseInfo:
		pop	ax		; base FamilyID[11-8] & base ModelID[7-4]
		pop	bx		; extended FamilyID[11-4] & extended ModelID[3-0]
		mov	cx,0F04h
		and	ah,ch
		and	bh,ch
		rol	bx,cl		; extended FamilyID in bh, extended ModelID in bl[7-4]
		shr	al,cl		; set base ModelID
		cmp	ah,ch
		jz	SetModelID
		cmp	ah,06h
		jnz	ModelIDset
		mov	bh,0		; remove extended FamilyID
SetModelID:
		add	ax,bx		; use extended FamilyID & extended ModelID
ModelIDset:
set_cputype:
		endif
		mov	dl,-1		; set 386 flag
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
		ifdef	CPUTYPE
		mov	[_cputype],ax	; _cputype: FFMM or 0[1-4]00=80[1-4]86 or 0000=8086/8088
		endif
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
		mov	ax,640			; 640k => 9000h
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
