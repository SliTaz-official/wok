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

        segment _DATA byte public use16 'DATA'
        ends    _DATA

        segment _BSS byte public use16 'BSS'

ultoabuf	db	12	dup (?)

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;char* strcpy(const char* a,const char* b);
;***************************************************************
        global  _strcpy:near
        proc    _strcpy near

		mov	dl,0
cat:
		pop	cx			;caller return address
                pop	ax			; a
                pop	bx			; b
                push	bx
                push	ax
                push	cx
                push	ax si
                xchg	ax,si
		shr	dl,1
		jnc	@@nocat
@@catlp:
		lodsb
		cmp	al,0
                jne	@@catlp
		dec	si
@@nocat:
                sub	bx,si
@@cpylp:
                mov	al,[bx+si]
		test	dl,1
		jnz	@@nocpy
                mov	[si],al
                inc	si
		cmp	al,0
                jne	@@cpylp
                pop	si ax
                ret
@@nocpy:
                sub	al,[si]
		jnz	@@out
                lodsb
		cmp	al,0
                jne	@@cpylp
@@out:
		cbw
                pop	si dx
                ret

        endp    _strcpy


;***************************************************************
;char* strcat(const char* a,const char* b);
;***************************************************************
        global  _strcat:near
        proc    _strcat near

		mov	dl,1
                jmp	cat

        endp    _strcat


;***************************************************************
;int strcmp(const char* a,const char* b);
;***************************************************************
        global  _strcmp:near
        proc    _strcmp near

		mov	dl,2
                jmp	cat

        endp    _strcmp


;***************************************************************
;char strstr(const char* a,const char* b);
;***************************************************************
        global  _strstr:near
        proc    _strstr near

		pop	ax			;caller return address
                pop	bx			; a
                pop	dx			; b
                push	dx
                push	bx
                push	ax
                push	di
@@loop:
		xor	ax,ax
		cmp	[bx],al
		jz	@@end
		mov	cx,bx
		mov	di,dx
		sub	di,bx
@@match:
		mov	al,[bx+di]
		or	al,al
		jz	@@found
		inc	bx
		cmp	al,[bx-1]
		jnz	@@loop
		jmp	@@match
@@found:
		xchg	ax,cx
@@end:
                pop	di
		ret

        endp    _strstr


;***************************************************************
;int cpuhaslm(void)
;***************************************************************
        global  _cpuhaslm:near
        proc    _cpuhaslm near

		pushf
; Check for oldies
		mov	ax, 0F000h
		push	ax		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		popf
		add	dh,ah		; NS=386+, NC=286
		cbw
		clc
                js     @@bad   		;it is a 86/186/286, not a 386+
		pushfd
		pushfd
		pop	ebx
		mov	ecx,ebx
		xor	ebx,00100000h	; toggle CPUID feature bit 21
		push	ebx
		popfd
		pushfd
		pop	ebx
		popfd
		xor	ebx,ecx
		shr	ebx,1+21	; CPUID feature bit ?
		jnc	@@bad
		mov	eax,80000001h	; Extended Processor Info and Feature Bits
		db	0Fh,0A2h	; cpuid
		xor	ax,ax
		shr	edx,1+29	; LM feature bit ?
@@bad:
		sbb	ax,ax
		ret

        endp    _cpuhaslm


;***************************************************************
;char *progname(void)
;***************************************************************
        global  _progname:near
        proc    _progname near

		push	si di es
		mov	ah,30h
		int	21h
		cmp	al,3
		mov	ax,0
		jb	@@skip
		mov	es,[cs:2Ch]
		mov	cx,-1
		xor	di,di
		xor	al,al
@@loop1:
		repne
		  scasb
		scasb
		jne	@@loop1
		lea	si,[di+2]
		mov	bx, si
		extrn	strlen:near
		call	near strlen
		xchg	ax,cx
		inc	cx
		extrn	malloc_or_die:near
		call	near malloc_or_die
		xchg	ax,di
		push	ds
		push	ds
		push	es
		pop	ds
		pop	es
		push	di
@@loop2:
		lodsb
		stosb
		or	al,al
		jnz	@@loop2
		pop	ax
		pop	ds
@@skip:
		pop	es di si
		ret

        endp    _progname


;***************************************************************
;int chdir(char *path);
;***************************************************************
        global  _chdir:near
        proc    _chdir near

		pop	ax
		pop	dx
		push	dx
		push	ax
chdir:
		stc
		mov	ax,713Bh
		int	21h
		jnc	@@end
		mov	ah,3Bh
		int	21h
@@end:
		sbb	ax,ax
		ret

        endp    _chdir


;***************************************************************
;int chdirname(char *path)
;***************************************************************
        global  _chdirname:near
        proc    _chdirname near

		pop	ax
		pop	bx
		push	bx
		push	ax

		cmp	[byte bx+1],3Ah
		jne	@@nodisk
		mov	dl,[bx]
		or	dl,20h
		sub	dl,61h
		mov	ah,0Eh
		push	bx
		int	21h
		pop	bx
		inc	bx
		inc	bx
@@nodisk:
		mov	dx,bx
		xor	cx,cx
@@next:
		mov	al,[bx]
		cmp	al,5Ch
		jne	@@tsteos
		mov	cx,bx
@@tsteos:
		inc	bx
		or	al,al
		jnz	@@next
		cbw
		jcxz	@@end
		mov	bx,cx
		push	[word bx]
		mov	[bx],al
		push	bx
		call	chdir
		pop	bx
		pop	[word bx]
@@end:
		ret

        endp    _chdirname


;***************************************************************
;char *ultoa(unsigned long n);
;***************************************************************
        global  _ultoa:near
        proc    _ultoa near

		pop	ax
		pop	cx
		pop	dx
		push	dx
		push	cx
		push	ax		; DX:CX = n
		push	si
		mov	si,10
		mov	bx,offset ultoabuf+11
@@loop:
		dec	bx
		xchg	ax,dx
		xor	dx,dx
		div	si		; DX:AX = 0000:hi(n)
		xchg	ax,cx		; CX = hi(n)/10
		div	si		; DX:AX = hi(n)%10:lo(n)
		xchg	ax,cx		; CX = lo(n/10)
		xchg	ax,dx		; DX = hi(n)/10 = hi(n/10)
		add	al,'0'
		mov	[bx],al
		mov	ax,cx
		or	ax,dx
		jnz	@@loop
		xchg	ax,bx
		pop	si
		ret

        endp    _ultoa


;***************************************************************
;unsigned long kver2ul(char *kernel_version);
;***************************************************************
        global  _kver2ul:near
        proc    _kver2ul near

		pop	ax
		pop	dx
		push	dx
		push	ax
		push	bp si di
		xor	di,di
		push	di
		push	di
		mov	bp,sp
		mov	si,dx
		inc	di
		inc	di
		mov	cl,4
@@number:
		xor	ax,ax
@@digit:
		shl	al,cl
		shl	ax,cl
		lodsb
		sub	al,30h
		cmp	al,9
		jbe	@@digit
		mov	[bp+di],ah
		dec	di
		jns	@@number
		pop	ax
		pop	dx
		pop	di si bp
		ret

        endp    _kver2ul

        global  N_LXURSH@:near
        proc    N_LXURSH@ near

		mov	ch,0
@@loop:
		shr	dx,1
		rcr	ax,1
		loop	@@loop
		ret

        endp    N_LXURSH@

        global  N_LXLSH@:near
        proc    N_LXLSH@ near

		mov	ch,0
@@loop:
		shl	ax,1
		rcl	dx,1
		loop	@@loop
		ret

        endp    N_LXLSH@

        ends    _TEXT

        end

;###### END OF FILE ############################################
