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

        global  _imgs:dword

        ends    _BSS


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void dos_shutdown()
;***************************************************************

	macro	dos_shutdown
		xor	si,si
		mov	ds,si
		ifndef	NO386
		push	[dword si+4]		; save step
		mov	[word si+4],offset step19
		else
		mov	ax,offset step19
		xchg	ax,[word si+4]
		push	[word si+6]	
		push	ax			; save step
		endif
		mov	[word cs:sssp],sp
		;cmp	[byte si+7],0F0h
		;jnc	notdos
		mov	[si+6],cs
		pushf
		pushf
		pop	ax
		inc	ah			; set TF
		push	ax
		popf
		call	[dword si+4*19h]
notdos:
		ifndef	NO386
		lss	sp,[dword cs:sssp]
		else
		lds	ax,[dword cs:sssp]
		push	ds
		pop	ss
		xchg	ax,sp
		endif
		xor	si,si
		mov	ds,si
		pop	[dword si+4]		; restore step
	endm
	macro	step19code
step19:
		push	si
		push	ds
		mov	si,sp
		lds	si,[dword ss:si+4]	; read cs:ip
		cmp	[word si],19CDh		; int 19h ?
		pop	ds
		pop	si
		je	notdos
		iret
	endm


;***************************************************************
;void boot_kernel();
;****** Never returns
;***************************************************************
	global	_boot_kernel:near
        proc    _boot_kernel near
        
		ifdef	NO386
                p8086
		else
                p386
		endif
		;cli				; we start doing destructive things to DOS
		extrn	sssp:word
		mov	es,[sssp+2]
		push	es
		pop	ss
		mov	sp,0A000h
		extrn	_csip:dword
		ifdef NO386
		mov	si,offset _csip
		lodsw
		push	[word si]
		push	ax
		else
		push	[dword _csip]
		endif

		ifdef	NO386
		mov	cx,ss
		add	ch,9
		push	cx			; topseg()+0x0900
		else
		push	9800h+(4096/16)		; 4096 bytes for cmdline
		endif

		extrn	_cmdline:word
		mov	si,[_cmdline]
		mov	di,8000h
		mov	ch,10h			; 4k
		rep
		  movsb

		mov	cl,0			; load high ?
		org	$-1
		global	_pm_high:byte
_pm_high	db	?
		inc	cx
		push	cx
		mov	ax,[word ss:024Ch]
		xor	ax,2b30h		; ipxe ?
		loopne	@@notipxe

		; finish loading
		extrn   @last_ditch$qv:near
		push	cs
		call	@last_ditch$qv
		dos_shutdown			; clear si; ds=0; kill VCPI
		push	cs
		pop	ds

@@notipxe:
		pop	cx
		pop	es			; min 2048 bytes for stack
		loop	@@isbzimage

		; self move
		;cld
		extrn	gdt_data
		mov	cx,offset gdt_data+8
		xor	di,di			;  A000 -9000 -0800(>movedend)
		rep
		  movsb
		mov	si,offset _imgs+2
		lodsw
		xchg	ax,bx			; get pm->fallback low word
		lodsw				; get pm->fallback high word
		ifdef	MOVE_SETUP
		mov	si,0
	global	_rm_offset:word
		org	$-2
_rm_offset	dw	?
		endif
		push	es
		call	near @@isbzimage	; pop cs ; ds=es=ss

		; prepare memcpy32 size & srcofs param to move zImage pm
		ifndef	NO386
		push	8			; size hi
		else
		mov	dx,8
		push	dx			; size hi
		endif
		push	cx			; size lo=up to 512k
		push	ax			; src ofs hi = pm.fallback

		;in	al,70h
		;or	al,80h			; disable NMI
		;out	70h,al

		push	bx			; src ofs lo
		xor	di,di
		push	di			; src seg=0
		inc	cx
		push	cx			; dst ofs hi
		push	di			; dst ofs lo : 64k
		extrn   memcpy32:near
		call	memcpy32

		ifdef	MOVE_SETUP
		;xor	di,di
		mov	cx,8000h
		;sub	cx,si
		rep
		  movsb
		endif

		ifndef  noelks
		ifndef	NO386
		cmp	[dword 1E6h],'SKLE'
		jne	@@notelks
		xor	si,si
		else
		mov	si,1E6h
		lodsw
		cmp	ax,'LE'
		jne	@@notelks
		lodsw
		xor	ax,'SK'
		jne	@@notelks
		xchg	ax,si
		endif
		ifdef	MOVE_SETUP
		mov	ch,1h		; DS=ES=SS=0100
		else
		mov	cx,100h		; DS=ES=SS=0100
		endif
		mov	ss,cx
		mov	es,cx
		mov	cl,20h		; CS=0120
		push	cx
		push	si		; IP=0000
		mov	ch,3Fh		; 05h min, 3Fh max
		rep
		  movsw
@@notelks:
		endif
@@isbzimage:
		push	ss
		pop	ds
		push	ss
		pop	es
		ifndef	NO386
		push	ss
		pop	fs
		push	ss
		pop	gs
		endif
		assume	nothing
		assume	cs:DGROUP
                retf

		step19code

        endp    _boot_kernel

movedend:

        ends    _TEXT

        end

;###### END OF FILE ############################################
