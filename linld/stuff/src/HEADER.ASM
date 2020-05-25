;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
                %crefref
                %noincl
                %nomacs
                p8086

        group   DGROUP  _TEXT
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'

                org     100h
        global  _text_start:byte
        label   _text_start byte

		mov	di,80h
		cmp	[byte di],1
		ja	notfound
	ifdef	WITH_LONG_FILENAME
		mov	si,offset tazboot_cmd
		mov	ax,716Ch
		xor	bx,bx			; R/O
		xor	cx,cx			; attributes
		cwd				; action = open
		stc
                int	21h
                jnc	found
		mov	dx,si
	else
		mov	dx,offset tazboot_cmd
	endif
                mov	ax,3d00h		; read-only+compatibility
		;mov	cl,0			; attribute mask
		int	21h
		jc	notfound
found:
		xchg	ax,bx
		mov	ah,3Eh
		int	21h
		mov	cx,endcmd-begcmd+1
		mov	si,offset default_arg
		rep
		  movsb
notfound:
		mov	di,9000h
		mov	si,offset tomove
		mov	ch,1
		jmp	move
tomove:
		cld
		mov	di,100h
		mov	si,offset endcmd
		mov	ch,40h
move:
		push	di
		rep
		  movsw
		ret

default_arg	db	endcmd-begcmd
begcmd		db	" @"
tazboot_cmd	db	"tazboot.cmd",0
endcmd:

;***************************************************************

        ends    _TEXT


        end     _text_start

;###### END OF FILE ############################################
