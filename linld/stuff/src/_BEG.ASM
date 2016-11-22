;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p386

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'

                org     100h
        global  _text_start:byte
        label   _text_start byte
		extrn	_bss_end
;***************************************************************
; clear bss
;***************************************************************
		xor	ax,ax
		mov	di,offset _bss_start
clearbss:
		mov	[di],al
		inc	di
		cmp	di,sp			; clear bss + heap
		jbe	clearbss
		mov	di,offset _bss_end
;***************************************************************
; build argv & argc
;***************************************************************
;               push	ax			; envp (int 20h do it for us)
                ;mov	[word di],ax		; argv[0] = 0
                mov	si,80h
                cld
                lodsb
                cmp	al,7Eh
                jbe	alok
                mov	al,7Eh
alok:
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
                jmp	newarg
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
		lea	si,[bx+di+2]
		extrn	_heap_top:word
		mov	[_heap_top],si
                push	di			; argv
                shr	bx,1
                push	bx			; argc
	ifndef	filearg
                mov	bx,[di+2]		; argv[1]
                cmp	[byte bx],'@'
		jne	argend
                inc	bx			; al=0 RDONLY
		extrn	open:near
		call	near open
		jc	argend
		pop	bx			; trash argc,  argv >> 1Kb !
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
                extrn   _is_vm86:near
                call    _is_vm86		; load_image needs that

;***************************************************************
                extrn   _main:near
                call    _main
                push	ax
                push	ax
;***************************************************************
;void exit(int n);
;***************************************************************
	        global  _exit:near
	        global  exit:near
_exit:
		pop	bx			;caller return address
                pop	ax			; n
exit:
                mov	ah,4Ch
                int	21h
        ends    _TEXT

        segment _DATA byte public use16 'DATA'
        global  _data_start:byte
        label   _data_start byte
        ends    _DATA

        segment _BSS byte public use16 'BSS'
        global  _bss_start:byte
        label   _bss_start byte
        ends    _BSS

        end     _text_start

;###### END OF FILE ############################################
