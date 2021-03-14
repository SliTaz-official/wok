;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
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

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;void dos_shutdown()
;***************************************************************

	macro	dos_shutdown
		xor	si,si
                ifdef   QUICK_BOOT
		extrn	_cmdnum:dword
quickboot	=	(word _cmdnum+20)
		cmp	si,[quickboot]
		mov	ds,si
		jne	skip_shutdown
		else
		mov	ds,si
		endif
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
skip_shutdown:
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
		mov	ax,[sssp+2]
		mov	es,ax
		extrn	_cmdstr:word
_cmdline	=	_cmdstr+0
		mov	si,[_cmdline]
		mov	di,8000h
		mov	cx,2000h		; 4k for cmdline + 4k up to sp
		rep
		  movsb
		push	es
		pop	ss
		mov	sp,di

		ifdef	LINUX001
		mov	dx,2000h
		global	_csip_hilo:word
		org	$-2
_csip_hilo	dw	?
		xchg	al,dh	; 9020 / 9000
		else
		mov	al,20h	; 9020:0
		xor	dx,dx
		endif
		push	ax
		push	dx	; 0000 / 0042

		mov	cl,1			; load high ?
		org	$-1
		global	_pm_low:byte
_pm_low		db	?
		push	cx
		ifdef	IPXE
		mov	ax,[word ss:024Ch]
		xor	ax,2b30h		; ipxe ?
		loopne	@@notipxe
		else
		loop	@@truebzimage
		endif

		; finish loading
		extrn   @last_ditch$qv:near
		push	cs
		call	@last_ditch$qv
		ifdef	SHUTDOWN
		dos_shutdown			; clear si; ds=0; kill VCPI
		push	cs
		pop	ds
		else
		xor	si,si
		endif

@@truebzimage:
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

		include	"himem.inc"

		extrn	_imgs:image_himem
		push	[_imgs.fallback]	; src ofs = pm.fallback

		;in	al,70h
		;or	al,80h			; disable NMI
		;out	70h,al

		push	si			; src seg=0
		inc	cx
		push	cx			; dst ofs hi
		push	si			; dst ofs lo : 64k = 0x10000

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

		ifdef ELKS
		call	near @@movsb@jmp	; movsb; pop cs ; ds=es=ss
		elseifdef MOVE_SETUP
		call	near @@movsb@jmp	; movsb; pop cs ; ds=es=ss
		else
		xor	di,di
		rep
		  movsb
		call	near @@isbzimage	; movsb; pop cs ; ds=es=ss
		endif

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

		ifdef   ELKS
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
		 ifdef   ELKS
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

		ifdef	SHUTDOWN
		step19code
		endif

        endp    _boot_kernel

        ends    _TEXT

        end

;###### END OF FILE ############################################
