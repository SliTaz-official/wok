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
        ends    _DATA

        segment _BSS byte public use16 'BSS'

        global  _bss_start:byte
        label   _bss_start byte
utoabuf		db	6 dup(?)

		include	"isostate.inc"

		extrn	_isostate:isostate

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

                org     100h
        global  _text_start:byte
        label   _text_start byte

		extrn	fold
		extrn	unfold
		mov	si,offset fold
		mov	di,offset unfold
		mov	ch,4
		cld
		rep
		  movsw

;***************************************************************
; clear bss
;***************************************************************

		mov	si,offset _bss_start
clearbss:
		mov	[byte si],cl	; clear bss + heap
		inc	si
		jne	clearbss

;***************************************************************
; build arg
;***************************************************************

		mov	bx,endbzimage-bzimage
		mov	si,80h
		mov	di,si
		lodsb
		add	[di],bl
		cbw
		mov	bp,-1
skipspace:
		inc	bp
		cmp	[byte bp+si]," "
		je	skipspace
		xchg	ax,cx
		add	si,cx
		dec	si
		lea	di,[bx+si]
		mov	[di+1],bh
		sub	cx,bp
		std
		rep
		  movsb
		push	di
		mov	si,offset endbzimage-1
		mov	cl,bl
		rep
		  movsb
		pop	si
		inc	si
		cld

	ifdef	LONG_FILENAME
		mov	ax,716Ch
		xor	bx,bx			; R/O
		;xor	cx,cx			; attributes
		cwd				; action = open
		stc
                int	21h
                jnc	opened
	endif
                mov	ax,3d00h		; read-only+compatibility
		;mov	cl,0			; attribute mask
                mov	dx,si
                int	21h
                jnc	opened

_abort:
		mov	dx,offset stopmsg
		mov	ah,9
		int	21h
		int	20h
opened:
		mov	[_isostate.fd],ax
		mov	ax,offset bootdir
		extrn	iso_open:near
		call	iso_open
jc_abort:
		jc	_abort

;***************************************************************

; patch magic
		extrn	@readmenu$qv:near
		call	@readmenu$qv
		mov	ax,[_isostate.filemod]
		mov	bx,10
		xor	cx,cx
@@loop1:
		xor	dx,dx
		div	bx		; DX:AX = n%10:n/10
		push	dx		; DL = n%10
		inc	cx
		or	ax,ax
		jnz	@@loop1
		push	ds
		pop	es
		lea	di,[bp+magic-bzimage+81h]
@@loop2:
		pop	ax
		add	al,'0'
		stosb
		loop	@@loop2

; patch initrd
		cwd
		or	[_isostate.curdirsize],-1
		jmp	patchtest
found:
		inc	dh
patchtest:
		push	dx
		extrn	@isoreaddir$qv:near
		call	@isoreaddir$qv
		pop	dx
		push	ds
		pop	es
		inc	ax
		jne	patchlp
		cmp	dx,100h
		je	initrddone
		lea	di,[bp+rootfs-bzimage+87h]
		or	dh,dh
		je	modify
		add	di,4
		mov	si,offset rootfs
		mov	cx,3
		rep
		  movsw
modify:
		xchg	ax,dx
		stosb
		mov	si,offset dotgz
		mov	cl,5
		rep
		  movsb
initrddone:
		
;***************************************************************

		mov	ax,offset linld
		call	iso_open
		jc	jc_abort
		mov	cx,[word _isostate.filesize]
		mov	dx,100h
		jmp	near unfold
patchlp:
		mov	si,[_isostate.filename]
		mov	di,offset rootfs
		mov	cx,9
		rep
		  cmpsb
		jcxz	found
		cmp	cl,3
		ja	patchtest
		dec	si
		cmp	dl,[si]
		ja	patchtest
		mov	dl,[si]
		jmp	patchtest

stopmsg:
		db	 "This program cannot be run in DOS mode$"
bootdir:
		db	"/boot",0
linld:
		db	"linld.com",0
bzimage:
		db	"-f "
		;db	"image=boot\bzImage "
		db	"initrd="
rootfs:
		db	"rootfs"
dotgz:
		db	".gz,!            "
		; 	".gz,rootfs4.gz,! "
		;db	"rw "
		db	"autologin rdinit=/init.exe mode=menu magic="
magic:
		db	"0     bootfrom="
		;	"65535 bootfrom="
endbzimage:


;***************************************************************

        ends    _TEXT


        end     _text_start

;###### END OF FILE ############################################
