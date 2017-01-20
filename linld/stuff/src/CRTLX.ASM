;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p8086

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'

tazboot_cmd	db	"tazboot.cmd",0

        ends    _DATA

        segment _BSS byte public use16 'BSS'

ultoabuf	db	12	dup (?)

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;int strcmp(const char* a,const char* b);
;***************************************************************
        global  _strcmp:near
        proc    _strcmp near

		pop	cx			;caller return address
                pop	bx			; a
                pop	ax			; b
                push	ax
                push	bx
                push	cx
                push	si
		xchg	ax,si
                sub	bx,si
@@lp:
                mov	al,[si]
                sub	al,[bx+si]
		jnz	@@out
                lodsb
		cmp	al,0
                jne	@@lp
@@out:
		cbw
                pop	si
                ret

        endp    _strcmp


;***************************************************************
;char strstr(const char* a,const char* b);
;***************************************************************
        global  _strstr:near
        proc    _strstr near

		pop	ax			;caller return address
                pop	cx			; a
                pop	dx			; b
                push	dx
                push	cx
                push	ax
                push	si
@@loop:
		xor	ax,ax
		mov	si,cx
		cmp	[si],al			; *a
		jz	@@end			; return ax = NULL
		mov	bx,dx
		sub	bx,si
@@match:
		or	ah,[bx+si]		; *b
		jz	@@found
		lodsb
		sub	ah,al
		jz	@@match
		inc	cx
		jmp	@@loop
@@found:
		xchg	ax,cx
@@end:
                pop	si
		ret

        endp    _strstr


;***************************************************************
;int cpuhaslm(void)
;***************************************************************
        global  _cpuhaslm:near
        proc    _cpuhaslm near

		pushf
; Check for oldies
		mov	bh, 0F0h
		push	bx		; < 286 : flags[12..15] are forced 1
		popf			; = 286 : flags[12..15] are forced 0
		pushf			; > 286 : only flags[15] is forced 0
		pop	dx
		popf
		add	dh,bh		; NS=386+, NC=286
		clc
                js     @@bad   		;it is a 86/186/286, not a 386+
                p386
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
		shr	edx,1+29	; LM feature bit ?
@@bad:
                p8086
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
		jb	@@skip
		xor	di,di
		mov	es,[cs:2Ch]
		mov	cx,-1
		mov	ax,di
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

		pop	bx
		pop	ax
		push	ax
		push	bx
		push	bp si di
		xchg	ax,si
		xor	di,di
		push	di
		push	di
		mov	bp,sp
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
kver2ulret:
		ret

        endp    _kver2ul


;***************************************************************
;void try_default_args();
;***************************************************************
        global  _try_default_args:near
        proc    _try_default_args near

		mov	bx,offset tazboot_cmd
		extrn	open:near
		call	near open
		jc	kver2ulret
		mov	cx,4096
		extrn	_heap_top:word
		mov	di,[_heap_top]
		push	cx
		extrn	read_cmdline:near
		jmp	near read_cmdline	; read_cmdline(ax,di,cx)
		
        endp    _try_default_args

struc		isostate	; struct isostate {
fd		dw	?	; 0	int fd;
fileofs		dd	?	; 2	unsigned long fileofs;
filesize	dd	?	; 6	unsigned long filesize;
filemod		dw	?	;10	unsigned short filemod;
filename	dw	?	;12	char *filename;
dirofs		dd	?	;14	unsigned long dirofs;
dirsize		dd	?	;16	unsigned long dirsize;
curdirofs	dd	?	;20	unsigned long curdirofs;
curdirsize	dd	?	;24	unsigned long curdirsize;
curpos		dd	?	;28	unsigned long curpos;
ends				; } isostate;
;***************************************************************
;unsigned long isolseek(unsigned long offset);
;***************************************************************
        global  _isolseek:near
        proc    _isolseek near

		pop	ax
		pop	dx
		pop	cx
		push	cx
		push	dx
		push	ax
		extrn	_isostate:isostate
		mov	bx,[_isostate.fd]
		extrn	lseekset:near
		jmp	near lseekset		; (bx=fd, sz=cx:dx)
		
        endp    _isolseek

        ends    _TEXT

        end

;###### END OF FILE ############################################
