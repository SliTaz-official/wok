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

COMSTART	=	100h
MAXCODESZ	=	0F000h			; < 64K - COMSTART - STKSZ 

                org     COMSTART
        global  _text_start:byte
        label   _text_start byte

		cld
		mov	dx,offset tazboot_cmd
		mov	di,80h
		cmp	[byte di],dh
		ja	notfound
                mov	ax,3d00h		; read-only+compatibility
		;mov	cl,0			; attribute mask
		int	21h
		jc	notfound
found:
		xchg	ax,bx
		mov	ah,3Eh			; close
		int	21h
		mov	si,offset default_arg	; di = 0080h
		mov	cx,di
		rep
		  movsb
notfound:
		mov	di,MAXCODESZ+offset endcmd
		mov	si,offset move
		mov	cx,COMSTART
		mov	ax,offset endcmd
move:
		push	di
		push	cx
		rep
		  movsb
		pop	di
		pop	cx
		;sub	cx,ax
		xchg	ax,si
		push	cx
		ret

default_arg	db	endcmd-begcmd
begcmd		db	" @"
tazboot_cmd	db	"tazboot.cmd",0
endcmd:

;***************************************************************

        ends    _TEXT


        end     _text_start

;###### END OF FILE ############################################
