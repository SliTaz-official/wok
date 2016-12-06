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

        global  _heap_top:word
	extrn	_bss_end
_heap_top	dw	_bss_end
msg_hang	db      "High mem corrupted - not exiting to DOS"
msg_crlf	db	13,10,0
vcpi_alloc_err	db	"vcpi "
msg_malloc      db      "malloc() failure",0

        ends    _DATA

        segment _BSS byte public use16 'BSS'

        global  _no_exit:byte
_no_exit	db	?
filecnt		db	?		; in fact 0 minus file count...
nextfilename	dw	?

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;char* strcpy(const char* a, const char* b);
;***************************************************************
        global  _strcpy:near
        proc    _strcpy near

		mov	dl,0
cat:
		pop	ax			;caller return address
                pop	cx			; a
                pop	bx			; b
                push	bx
                push	cx
                push	ax
                push	si
                mov	si,cx
		shr	dl,1
		jnc	@@nocat
@@catlp:
		lodsb
		cmp	al,0
                jne	@@catlp
		dec	si
		shr	dl,1
		jnc	@@nocat
		cmp	cx,si
		jz	@@nocat
		mov	[word si],20h
		inc	si
@@nocat:
                sub	bx,si
@@cpylp:
                mov	al,[bx+si]
                mov	[si],al
                inc	si
		cmp	al,0
                jne	@@cpylp
		mov	ax,cx
                pop	si
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
;char* strcatb(const char* a,const char* b);
;***************************************************************
        global  _strcatb:near
        proc    _strcatb near

		mov	dl,3
                jmp	cat

        endp    _strcatb


;***************************************************************
;void* malloc(unsigned sz);
;***************************************************************
        global  _malloc:near
        proc    _malloc near

		pop	ax			;caller return address
                pop	cx			; sz
		push	cx
		push	ax
        global  malloc:near			; malloc(cx)
malloc:
		mov	ax,[_heap_top]
		mov	bx,offset msg_malloc
		mov	dx,-1400h		; MIN_STACK=_1k+PAGE_SIZE
		add	dx,sp
		sub	dx,ax			; can't overflow
		cmp	dx,cx
		jb	puts
		add	[_heap_top],cx		; _BEG has zero'd heap
		;mov	bx,ax
@@zalloc:
		;mov	[byte bx],0
		;inc	bx			; ZF=0
		;loop	@@zalloc
		ret

        endp    _malloc


;***************************************************************
;void puts(const char* s):
;void putsz(const char* s):
;***************************************************************
        global  _puts:near
        proc    _puts near

		pop	ax			;caller return address
                pop	bx			; s
                push	bx
                push	ax
        global  puts:near			; puts(bx)
puts:
		call	putsz
                mov	bx,offset msg_crlf
		jmp	putsz

        global  _putsz:near
_putsz:
		pop	ax			;caller return address
                pop	bx			; s
                push	bx
                push	ax
        global  putsz:near			; putsz(bx)
putsz:
                push	bx
		call	strlen
		pop	dx
		xchg	ax,cx
		mov	bx,1
                mov	ah,40h
                int	21h
		xor	ax,ax			; ZF=1	(for malloc failure)
		ret

        endp    _puts


;***************************************************************
;int fileattr(const char* name);
;***************************************************************
        global  _fileattr:near
        proc    _fileattr near

		pop	ax			;caller return address
                pop	dx			; name
                push	dx
                push	ax
                mov	ax,4300h
                int	21h
		xchg	ax,cx
		jmp	chkc

        endp    _fileattr


;***************************************************************
;int open(const char* name, int flags=O_RDONLY);
;***************************************************************
        global  _open:near
        proc    _open near

		pop	ax			;caller return address
                pop	bx			; name
                push	bx
                push	ax
        global  open:near			; open(bx)
open:
                mov	dx,bx
                mov	ax,3d00h
dos:
                int	21h
chkc:
                jnc	doret
fail:
                sbb	ax,ax			; ax=-1 CF
		cwd
doret:
		ifndef	NO386
		push	dx			; see next_chunk:lseek
		push	ax
		pop	eax
		endif
                ret

        endp    _open


;***************************************************************
;int close(int fd);
;***************************************************************
        global  _close:near
        proc    _close near

		pop	ax			;caller return address
                pop	bx			; fd
                push	bx
                push	ax
        global  close:near			; close(bx)
close:
		mov	ah,3Eh
		or	bx,bx
		jnz	dos
		ret

        endp    _close


;***************************************************************
;int read(int fd, void* data, int sz);
;***************************************************************
        global  _read:near
        proc    _read near

                mov	ah,3fh
rwio:
		ifndef	NO386
		pop	dx			;caller return address
                pop	ebx			; fd & data
                pop	cx			; sz
                push	cx
                push	ebx
                push	dx
		else
		mov	bx,sp
		mov	cx,[bx+6]
		mov	dx,[bx+4]
		mov	bx,[bx+2]
		endif
                clc
                jcxz	fail
rwioz:
		ifndef	NO386
                push	ebx
                pop	bx
                pop	dx
		endif
		jmp	dos

        endp    _read


;***************************************************************
;int write(int fd, const void* data, int sz);
;***************************************************************
        global  _write:near
        proc    _write near

                mov	ah,40h
		jmp	rwio

        endp    _write


;***************************************************************
;long lseek(int fd, long sz, int dir);
;***************************************************************
        global  _lseek:near
        proc    _lseek near

		ifndef	NO386
		pop	ax			;caller return address
                pop	bx			; fd
                pop	ecx			; sz
                pop	dx			; dir
                push	dx
                push	ecx
                push	bx
                push	ax
		else
		mov	bx,sp
		mov	dx,[bx+8]
		mov	cx,[bx+6]
		mov	ax,[bx+4]
		mov	bx,[bx+2]
		endif
lseek:
		xchg	ax,dx			; dir
                mov	ah,42h
		ifndef	NO386
                push	ecx
                pop	dx
                pop	cx
		endif
		jmp	dos

        endp    _lseek


;***************************************************************
;int strlen(const char* s);
;***************************************************************
        global  _strlen:near
        proc    _strlen near

		pop	ax			;caller return address
                pop	bx			; s
                push	bx
                push	ax
        global  strlen:near			; strlen(bx)
strlen:
                mov	cx,bx
                jcxz	@@end
                dec	bx
@@lenlp:
                inc	bx
                cmp	[byte bx],0
                jne	@@lenlp
                sub	bx,cx
@@end:
                xchg	ax,bx
                ret

        endp    _strlen


;***************************************************************
;int strhead(const char* a,const char* b);
;***************************************************************
        global  _strhead:near
        proc    _strhead near

		pop	cx			;caller return address
                pop	ax			; a
                pop	bx			; b
                push	bx
                push	ax
                push	cx
@@loop:
                mov	cl,[bx]			; cl = *b++
                inc	bx
		or	cl,cl			; clear C
		jz	fail			; return 0
		xchg	ax,bx
                xor	cl,[bx]			; cl -= *a++
		and	cl,0dfh			; case insensitive
		stc
		jnz	fail			; return -1
                inc	bx
		xchg	ax,bx
                jmp	@@loop

        endp    _strhead


;***************************************************************
;char* malloc_or_die(unsigned size);
;***************************************************************
        global  _malloc_or_die:near
        proc    _malloc_or_die near

		pop	ax			;caller return address
                pop	cx			; size
                push	cx
                push	ax
        global  malloc_or_die:near		; malloc_or_die(cx)
malloc_or_die:
		call	malloc
		jz	_exit
		ret

        endp    _malloc_or_die


;***************************************************************
;int die(const char* msg);
;int exit();
;int abort();
;***************************************************************
        global  _die:near
        proc    _die near

		pop	ax			;caller return address
                pop	bx			; s
                push	bx
                push	ax
        global  die:near			; die(bx)
die:
		call	puts
        global  _exit:near
_exit:
		mov	al,[_no_exit]
		cmp	al,0
		jne	@@hang
		extrn	exit:near
		inc	ax
		jmp	near exit
@@hang:
		mov	bx, offset msg_hang
		call	puts
        global  _abort:near
_abort:
		cli
@@stop:
		hlt
		jmp	@@stop

        endp    _die

struc   image_himem		;struct image_himem {
fd		dw	?	; 0    int fd;
fallback	dd	?	; 2    u32 fallback;
size		dd	?	; 6    u32 size;
remaining	dd	?	;10    u32 remaining;
buf		dd	?	;14    u32 buf;
bufv		dw	?	;18    u32 *bufv;
errmsg		dw	?	;20    char *errmsg;
chunk_size	dd	?	;22    u32 chunk_size;
next_chunk	dw	?	;26    void (*next_chunk)(struct image_himem *);
state		dw	?	;28    u16 state;
fd2close	dw	?	;30    u16 fd2close;
ends				;};

;***************************************************************
;u32* malloc_bufv_or_die(struct image_himem *m);
;***************************************************************
        global  _malloc_bufv_or_die:near
        proc    _malloc_bufv_or_die near

		pop	bx			;caller return address
		pop	ax
		push	ax
		push	bx
		push	si
		xchg	ax,si
		mov	ecx,[(image_himem si).size]
		dec	ecx
		shr	ecx,12
		inc	cx			; cnt = (m->size+PAGE_MASK)/PAGE_SIZE;
		push	cx
		inc	cx			; cnt+1
		shl	cx,2			; bufv => vcpi => vm86
; our malloc zeroes allocated mem: bufv[cnt]=0;
; Allocate pages, storing addrs in addrbuf
		call	malloc_or_die
                pop	cx
		push	cx			; _sort:nel
		push	ax			; _sort:base
		mov	[(image_himem si).bufv],ax
		xchg	ax,bx
@@vcpi_alloc:
                xor     edx,edx
                mov     ax,0DE04h
                int     67h
		or	ah,ah
		jz	@@ok
		mov	bx,offset vcpi_alloc_err
		jmp	die
@@ok:
		mov	[bx],edx
		add	bx,4
		loop	@@vcpi_alloc
@@again:
		call	_sort
		extrn	_initrd
		cmp	si,offset _initrd
		jne	@@quit
		pop	ax
		pop	cx
		push	cx			; _sort:nel
		push	ax			; _sort:base = m->bufv
;again:
; for (i = cnt-1; i >= 0; i--) {
@@chkloop:
		mov	bx,cx
		dec	bx
;   if  (m->bufv[i] > m->fallback+i*_4k && m->bufv[i] < m->fallback+m->size) {
		shl	bx,2
		add	bx,ax			; m->bufv
		mov	edx,[bx]		; m->bufv[i]
		sub	edx,[(image_himem si).fallback]
		cmp	edx,[(image_himem si).size]
		jae	@@chknext
		shr	edx,12
		cmp	dx,cx
		jb	@@chknext
;     m->bufv[i] = vcpi_alloc_or_die();
;     sort(m->bufv,cnt);
;     goto again;
		mov	cx,1
		jmp	@@vcpi_alloc
;   }
; }
@@chknext:
		loop	@@chkloop
@@quit:
		pop	ax
		pop	cx
		pop	si
		ret

        endp    _malloc_bufv_or_die


;***************************************************************
;void next_chunk(struct image_himem *m);
;***************************************************************
        proc    _next_chunk near

		pop	bx
		pop	ax
		push	ax
		push	bx
		push	si di
		xchg	ax,di
		mov	bx,[(image_himem di).fd]
		call	close
		ifndef	NO386
		xor	eax,eax
		else
		xor	ax,ax
		endif
		cwd
		mov	[(image_himem di).fd],ax
		mov	bx,[(image_himem di).state]
		cmp	al,[bx]			; ""
		jz	@@end
		mov	si,bx
@@scan:
		lodsb
		mov	cx,si
		cmp	al,','
		jz	@@eos
		cmp	al,0
		jnz	@@scan
		dec	cx
@@eos:
		mov	[(image_himem di).state],cx
		dec	si
		push	[word si]
		mov	[byte si],dl		; set temp eos
		call	open
		pop	[word si]		; restore string
		jc	@@die
		mov	[(image_himem di).fd],ax
		mov	[(image_himem di).fd2close],ax
		mov	dx,2			; SEEK_END
		xchg	ax,bx
		ifndef	NO386
		xor	ecx,ecx
		else
		xor	ax,ax
		xor	cx,cx
		endif
		call	lseek
@@die:
		mov	bx,[(image_himem di).errmsg]
		jc	die
		mov	bx,[(image_himem di).fd]
		ifndef	NO386
		push	eax
		xor	ecx,ecx
		xor	dx,dx
		call	lseek			; rewind
		pop	eax
@@end:
		mov	[(image_himem di).chunk_size],eax
		else
		push	ax
		push	dx
		xor	ax,ax
		xor	cx,cx
		cwd
		call	lseek			; rewind
		pop	dx
		pop	ax
@@end:
		mov	[word (image_himem di).chunk_size],ax
		mov	[word ((image_himem di).chunk_size)+2],dx
		endif
		pop	di si
		ret

        endp    _next_chunk


;***************************************************************
;void open_image(const char *name, struct image_himem *m);
;***************************************************************
        global  _open_image:near
        proc    _open_image near

		arg	fname	:word,	\
			m	:word	= PARAM_SIZE

		push	bp
		mov	bp,sp
                push	si di
		ifndef	NO386
                xor	eax,eax			; 1st loop flag + eos
		else
                xor	ax,ax			; 1st loop flag + eos
		endif
                mov	di,[m]
		cmp	[(image_himem di).fd],ax
                jnz	@@alreadydone
		ifndef	NO386
		mov	[(image_himem di).size],eax	; m->size = 0L
		else
		mov	[word (image_himem di).size],ax	; m->size = 0L
		mov	[word ((image_himem di).size)+2],ax
		endif
		mov	[(image_himem di).next_chunk],offset _next_chunk
                mov	si,[fname]
                mov	[(image_himem di).state],si
@@next:
		push	di
                call	[(image_himem di).next_chunk]	; m->next_chunk()
		pop	di
		ifndef	NO386
		add	eax,3
		and	al,0FCh
		add	[(image_himem di).size],eax	; m->size += m->chunk_size
		or	eax,eax
		jnz	@@next
		else
		mov	cx,ax
		or	cx,dx
		add	ax,3
		adc	dx,0
		and	al,0FCh
		add	[word (image_himem di).size],ax	; m->size += m->chunk_size
		adc	[word ((image_himem di).size)+2],dx
		inc	cx			; jcxnz
		loop	@@next
		endif
                mov	[(image_himem di).state],si
		push	di
                call	[(image_himem di).next_chunk]	; m->next_chunk()
		pop	di
@@alreadydone:
                push	ax
image_done:
                pop	ax
                pop	di si bp
		ret

        endp    _open_image


;***************************************************************
;int read_image(struct image_himem *m, void* data, int sz);
;***************************************************************
        global  _read_image:near
        proc    _read_image near

		arg	m	:word,	\
			data	:word,	\
			sz	:word	= PARAM_SIZE

		push	bp
		mov	bp,sp
		push	si di
		ifndef	NO386
		push	0		; return value
		else
		xor	ax,ax
		push	ax
		endif
		mov	di,[m]
@@loop:
		ifndef	NO386
		xor	ecx,ecx
		mov	cx,[word sz]
@@chksz:
		mov	eax,[(image_himem di).chunk_size]
		cmp	ecx,eax
		jb	@@szok
		xchg	eax,ecx
		else
		mov	cx,[word sz]
@@chksz:
		mov	ax,[word (image_himem di).chunk_size]
		cmp	cx,ax
		jb	@@szok
		cmp	[word ((image_himem di).chunk_size)+2],0	; hi m->chunk_size
		jne	@@szok
		xchg	ax,cx
		endif
@@szok:
		jcxz	image_done
		push	cx
		push	[word data]
		push	[word di]
		call	_read
		pop	dx
		pop	bx
		pop	dx
		jc	image_done
		add	bx,ax
		xor	cx,cx
		ifndef	NO386
		cwde				; ax < 8000h
		cwd
		sub	[(image_himem di).chunk_size],eax
		else
		cwd				; ax < 8000h
		sub	[word (image_himem di).chunk_size],ax
		sbb	[word ((image_himem di).chunk_size)+2],dx
		jnz	@@fill
		cmp	[word (image_himem di).chunk_size],dx
		endif
		jnz	@@fill
		dec	cx
@@fill:
		test	al,3
		je	@@filled
		mov	[bx],dl
		inc	bx
		inc	ax
		jmp	@@fill
@@filled:
		ifndef	NO386
		sub	[(image_himem di).remaining],eax
		else
		sub	[word (image_himem di).remaining],ax
		sbb	[word ((image_himem di).remaining)+2],dx
		endif
		add	[bp-4-2],ax
		add	[word data],ax
		sub	[word sz],ax
		pushf
                and	cx,[(image_himem di).next_chunk]
		jz	@@same_chunk
		push	di
                call	cx			; m->next_chunk()
		pop	di
@@same_chunk:
		popf
		jnz	@@loop
		jmp	image_done

        endp    _read_image


;***************************************************************
;unsigned long strtol(const char *s);
;***************************************************************
        global  _strtol:near
        proc    _strtol near

		ifndef	NO386
		pop	ax			;caller return address
                pop	cx			; s
		push	cx
		push	ax
		xor	ebx,ebx
		jcxz	@@jncend
		push	si
		mov	si,cx
		xor	ecx,ecx
		xor	eax,eax
		lodsb
		mov	dl,20h
		or	dl,al
		cmp	dl,'n'			; vga=normal
		je	@@vga
		dec	cx
		cmp	dl,'e'			; vga=extended
		je	@@vga
		dec	cx
		cmp	dl,'a'			; vga=ask
		jne	@@notvga
@@vga:
		dec	cx
		xchg	ax,cx
		cwd
		jmp	popsiret
@@notvga:
		mov	cx,10			; radix
		cmp	al,'+'
		je	@@radixskip
		cmp	al,'-'
		clc
		jne	@@radixkeep
		stc
@@radixskip:
		lodsb
@@radixkeep:
		pushf
		cmp	al,'0'
		jne	@@radixok
		mov	cl,8
		lodsb
		mov	dl,20h
		or	dl,al
		cmp	dl,'x'
		jne	@@radixok
		mov	cl,16
@@strtollp:
		lodsb
@@radixok:
		sub	al,'0'
		jb	@@endstrtol
		cmp	al,9
		jbe	@@digitok
		or	al,20h
		cmp	al,'a'-'0'
		jb	@@endstrtol
		sub	al,'a'-'0'-10
@@digitok:
		cmp	al,cl
		jae	@@endstrtol
		xchg	eax,ebx
		mul	ecx
		add	eax,ebx
		xchg	eax,ebx
		jmp	@@strtollp
@@endstrtol:
		mov	cl,10
		cmp	al,'k'-'a'+10
		je	@@shift
		mov	cl,20
		cmp	al,'m'-'a'+10
		je	@@shift
		mov	cl,30
		cmp	al,'g'-'a'+10
		jne	@@noshift
@@shift:
		shl	ebx,cl
@@noshift:
		popf
@@jncend:
		jnc	@@end
		neg	ebx
@@end:
		push	ebx
		pop	ax
		pop	dx
popsiret:
		pop	si
		else
		pop	ax			;caller return address
                pop	cx			; s
		push	cx
		push	ax
		push	si
		push	di
		xor	ax,ax
		cwd
		xchg	ax,di
		jcxz	@@goend
		mov	si,cx
		lodsb
		mov	dl,20h
		or	dl,al
		mov	cx,-1
		cmp	dl,'n'			; vga=normal
		je	@@vga
		dec	cx
		cmp	dl,'e'			; vga=extended
		je	@@vga
		dec	cx
		cmp	dl,'a'			; vga=ask
		jne	@@notvga
@@vga:
		xchg	ax,cx
		cwd
		jmp	popsiret
@@goend:
		jmp	@@end
@@notvga:
		mov	cx,10			; radix
		cmp	al,'+'
		je	@@radixskip
		cmp	al,'-'
		clc
		jne	@@radixkeep
		stc
@@radixskip:
		lodsb
@@radixkeep:
		pushf
		cmp	al,'0'
		jne	@@radixok
		mov	cl,8
		lodsb
		mov	ah,20h
		or	ah,al
		cmp	ah,'x'
		jne	@@radixok
		mov	cl,16
@@strtollp:
		lodsb
@@radixok:
		sub	al,'0'
		jb	@@endstrtol
		cmp	al,9
		jbe	@@digitok
		or	al,20h
		cmp	al,'a'-'0'
		jb	@@endstrtol
		sub	al,'a'-'0'-10
@@digitok:
		cmp	al,cl
		jae	@@endstrtol

		push	ax
		push	si
		push	dx
		xchg	ax,di
		mul	cx
		xchg	ax,di
		xchg	ax,dx
		xchg	ax,si
		pop	ax
		mul	cx
		add	ax,si
		pop	si
		xchg	ax,dx
		pop	ax
		mov	ah,0
		add	di,ax
		adc	dx,0

		jmp	@@strtollp
@@endstrtol:
		mov	cl,10
		cmp	al,'k'-'a'+10
		je	@@shift
		mov	cl,20
		cmp	al,'m'-'a'+10
		je	@@shift
		mov	cl,30
		cmp	al,'g'-'a'+10
		jne	@@noshift
@@shift:
		rcl	di,1
		shl	dx,1
		loop	@@shift
@@noshift:
		popf
		jnc	@@end
		not	dx
		neg	di
		jne	@@end
		inc	dx
@@end:
		xchg	ax,di
		pop	di
popsiret:
		pop	si
		endif
		ret

        endp    _strtol


;***************************************************************
;>void sort(unsigned long  *base:BX!, size_t nel:CX)
;NO386 safe: only used by VCPI
;***************************************************************
        global  _sort:near
        proc    _sort near

		pop	ax			;caller return address
                pop	bx			; base
		pop	cx			; nel
		push	cx
		push	bx
		push	ax
        global  sort:near
sort:
	ifndef	fastsort
;  bubble sort
		push	si
		shl	cx,2
@@loop:
		xor	ax,ax
		mov	si,4
		cmp	cx,si
		jbe	popsiret
@@next:
		mov	edx,[bx+si-4]
		cmp	edx,[bx+si]
		jbe	@@ok
		xchg	edx,[bx+si]
		mov	[bx+si-4],edx
		mov	ax,si
@@ok:
		add	si,4
		cmp	si,cx
		jb	@@next
		xchg	ax,cx
		jmp	@@loop
	else
;  shell sort (c) uclibc GPL
		push	si di
; {
;>	size_t wgap:SI;
;
;	if (nel > 1) {
		cmp	cx,1
		jbe	@@end
;		wgap = 0;
		xor	ax,ax
;		do {
@@wgaplp:
		mov	si,ax
;			wgap = 3 * wgap + 1;
		mov	dx,3
		mul	dx
		inc	ax
;		} while (wgap < (nel-1)/3);
		cmp	ax,cx
		jb	@@wgaplp
;		/* From the above, we know that either wgap == 1 < nel or */
;		/* ((wgap-1)/3 < (int) ((nel-1)/3) <= (nel-1)/3 ==> wgap <  nel. */
;		wgap *= 4;			/* So this can not overflow if wnel doesn't. */
		shl	si,2
;		nel *= 4;			/* Convert nel to 'wnel' */
		shl	cx,2
;		do {
@@lp1:
;>	                size_t i:DI;
;			i = wgap;
		mov	di,si
;			do {
@@lp2:
;>	                	size_t j:DX;
;				j = i;
		mov	dx,di
;				do {
@@lp3:
;>					register char *a:BX!;
;
;					j -= wgap;
		sub	dx,si
;					a = j + ((char *)base);
		push	bx
		add	bx,dx
;					if (cmp(a, a + wgap) <= 0) {
		mov	eax,[bx]
		cmp	eax,[bx+si]
		jbe	@@brk3
;						break;
;					}
		xchg	eax,[bx+si]
		mov	[bx],eax
;					swap(a, a + wgap);
		pop	bx
;				} while (j >= wgap);
		cmp	dx,si
		jae	@@lp3
		push	bx
@@brk3:
		pop	bx
;				i += 4;
		add	di,4
;			} while (i < nel);
		cmp	di,cx
		jb	@@lp2
;			wgap = (wgap - 4)/3;
		sub	si,4
		xchg	ax,si
		cwd
		mov	si,3
		div	si	; kill dx
		xchg	ax,si
;		} while (wgap);
		or	si,si
		jnz	@@lp1
@@end:
;	}
;}
		pop	di si
		ret
endif

        endp    _sort


		ifdef	NO386
;***************************************************************
;u16 topseg();
;***************************************************************
        global  _topseg:near
        proc    _topseg near

		int	12h
		jnc	@@max640k
		mov	ax,640			; 9000
@@max640k:
		sub	ax,028h
		and	al,0C0h
		mov	cl,6
		shl	ax,cl
		ret

        endp    _topseg
		endif

;***************************************************************
;void rmcpy(void* rmbuf, u16 rmsize);
;***************************************************************
        global  _rmcpy:near
        proc    _rmcpy near

		pop	bx			;caller return address
                pop	ax			; rmbuf
		pop	cx			; rmsize
		push	cx
		push	ax
		push	bx
		push	si di es
		xchg	ax,si
		xor	di,di
		ifdef	NO386
		call	_topseg
		mov	es,ax
		else
		push	9000h
		pop	es
		endif
		cld
		rep
		  movsb
		extrn	_cmdline:word
		mov	si,[_cmdline]
		mov	di,8000h
		mov	ch,10h			; 4k
		rep
		  movsb
		pop	es di si
		ret

        endp    _rmcpy

        ends    _TEXT

        end

;###### END OF FILE ############################################
