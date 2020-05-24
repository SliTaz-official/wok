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
        
		ifdef	ISOHOOK
		extrn	iso_cleanup_hack:word
		call	[iso_cleanup_hack]	; or ret
		endif
		ifdef	NO386
                p8086
		else
                p386
		endif
		;cli				; we start doing destructive things to DOS
		extrn	sssp:word
		mov	ax,[sssp+2]
		mov	es,ax
		extrn	_cmdline:word
		mov	si,[_cmdline]
		mov	di,8000h
		mov	cx,2000h		; 4k for cmdline + 4k up to sp
		rep
		  movsb
		push	es
		pop	ss
		mov	sp,di

		mov	dx,2000h
		global	_csip_hilo:word
		org	$-2
_csip_hilo	dw	?
		xchg	al,dh	; 9020 / 9000
		push	ax
		push	dx	; 0000 / 0042

		mov	cl,1			; load high ?
		org	$-1
		global	_pm_low:byte
_pm_low		db	?
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
		loop	@@isbzimage

		; prepare memcpy32 size & srcofs param to move zImage pm
		ifndef	NO386
		push	8			; size hi
		else
		mov	dx,8
		push	dx			; size hi
		endif
		push	si			; size lo=up to 512k
		push	[dword _imgs+2]		; src ofs = pm.fallback

		;in	al,70h
		;or	al,80h			; disable NMI
		;out	70h,al

		push	si			; src seg=0
		inc	cx
		push	cx			; dst ofs hi
		push	si			; dst ofs lo : 64k

		; self move
		extrn	gdt_data
		mov	cx,offset gdt_data+8
		;xor	di,di			;  A000 -9000 -0800(>movedend)

		ifdef	NO386
		mov	ax,ss
		add	ax,900h
		push	ax			; topseg()+0x0900
		else
		push	9800h+(4096/16)		; 4096 bytes for cmdline
		endif
		pop	es
		push	es

		call	near @@movsb@jmp	; movsb; pop cs ; ds=es=ss

		extrn   memcpy32:near
		call	memcpy32

		ifdef	MOVE_SETUP
		mov	si,0
	global	_rm_offset:word
		org	$-2
_rm_offset	dw	?
		;xor	di,di
		;mov	cx,8000h
		;sub	cx,si
		;rep
		;  movsb
		endif

		ifndef  noelks
		ifdef	MOVE_SETUP
		ifndef	NO386
		mov	eax,[dword si+1E6h]
		xor	eax,'SKLE'
		else
		mov	ax,[si+1E6h]
		xor	ax,'LE'
		jne	@@notelks
		mov	ax,[si+1E8h]
		xor	ax,'SK'
		endif
		else
		ifndef	NO386
		mov	eax,[dword 1E6h]
		xor	eax,'SKLE'
		else
		mov	ax,[1E6h]
		xor	ax,'LE'
		jne	@@notelks
		mov	ax,[1E8h]
		xor	ax,'SK'
		endif
		endif
		jne	@@notelks
		mov	cx,100h		; DS=ES=SS=0100
		mov	ss,cx
		push	ss
		pop	es
		mov	cl,20h		; CS=0120
		push	cx
		push	ax		; IP=0000
		endif
		ifdef	MOVE_SETUP
@@notelks:
		mov	ch,7Eh
@@movsb@jmp:
		xor	di,di
		rep
		  movsb
		else
		 ifndef  noelks
		xchg	ax,si
		mov	ch,7Eh		; 0Ah min, 7Eh max
@@movsb@jmp:
		xor	di,di
		rep
		  movsb
@@notelks:
		 endif
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
