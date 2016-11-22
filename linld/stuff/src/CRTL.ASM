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

msg_hang	db      "High mem corrupted - not exiting to DOS",0
        global  _vcpi_alloc_err:byte
_vcpi_alloc_err	db	"vcpi "
msg_malloc      db      "malloc() failure",0
msg_crlf	db	13,10,0

        ends    _DATA

        segment _BSS byte public use16 'BSS'

        global  _heap_top:word
_heap_top	dw	?
        global  _no_exit:byte
_no_exit	db	?
filecnt		db	?		; in fact 0 minus file count...
nextfilename	dw	?

        ends    _BSS

        segment _TEXT byte public use16 'CODE'

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
		jmp	dos

        endp    _puts


;***************************************************************
;int open(const char* name, int flags);
;***************************************************************
        global  _open:near
        proc    _open near

		pop	cx			;caller return address
                pop	bx			; name
                pop	ax			; flags
                push	ax
                push	bx
                push	cx
        global  open:near			; open(bx,al)
open:
                mov	dx,bx
                mov	ah,3dh
dos:
                int	21h
                jnc	doret
fail:
                sbb	ax,ax			; ax=-1 CF
		cwd
doret:
		ifndef	NO386
                push	dx
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
;long rewind(int fd);
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

        global  _rewind:near
_rewind:
		pop	ax			;caller return address
                pop	bx			; fd
                push	bx
                push	ax
rewind:
		ifndef	NO386
		xor	ecx,ecx
		xor	dx,dx
		else
		xor	ax,ax
		xor	cx,cx
		cwd
		endif
		jmp	lseek

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
		jz	_diez
		ret

        endp    _malloc_or_die


;***************************************************************
;int die(const char* msg);
;int diez();
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
        global  _diez:near
_diez:
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


;***************************************************************
;void next_chunk(struct image_himem *m);
;***************************************************************
        proc    _next_chunk near

		pop	bx
		pop	ax
		push	ax
		push	bx
		push	di
		xchg	ax,di
		mov	bx,[di]			; m->fd
		call	close
		ifndef	NO386
		xor	eax,eax
		else
		xor	ax,ax
		endif
		cwd
		mov	[di],ax			; m->fd
		mov	bx,[di+28]		; m->state
		cmp	al,[bx]			; ""
		jz	@@end
		push	si
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
		mov	[di+28],cx		; m->state
		dec	si
		push	[word si]
		mov	[byte si],dl		; set temp eos
		xchg	ax,dx			; O_RDONLY
		call	open
		pop	[word si]		; restore string
		pop	si
		jc	@@die
		mov	[di],ax			; m->fd
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
		mov	bx,[di+20]		; m->errmsg
		jc	die
		mov	bx,[di]			; m->fd
		ifndef	NO386
		push	eax
		call	rewind
		pop	eax
@@end:
		mov	[di+22],eax		; m->chunk_size
		else
		push	ax
		push	dx
		call	rewind
		pop	dx
		pop	ax
@@end:
		mov	[di+22],ax		; m->chunk_size
		mov	[di+24],dx
		endif
		pop	di
		ret

        endp    _next_chunk


;***************************************************************
;void open_image(const char *name, struct image_himem *m);
;struct image_himem {
; 0    int fd;
; 2    u32 fallback;
; 6    u32 size;
;10    u32 remaining;
;14    u32 buf;
;18    u32 *bufv;
;20    char *errmsg;
;22    u32 chunk_size;
;26    void (*next_chunk)(struct image_himem *);
;28    u16 state;
;};
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
                cmp	[di],ax			; m->fd
                jnz	@@alreadydone
		ifndef	NO386
		mov	[di+6],eax		; m->size = 0L
		else
		mov	[di+6],ax		; m->size = 0L
		mov	[di+8],ax
		endif
		mov	[word di+26],offset _next_chunk
                mov	si,[fname]
                mov	[di+28],si		; m->state
@@next:
		push	di
                call	[word di+26]		; m->next_chunk()
		pop	di
		ifndef	NO386
		add	eax,3
		and	al,0FCh
		add	[di+6],eax		; m->size += m->chunk_size
		or	eax,eax
		jnz	@@next
		else
		mov	cx,ax
		or	cx,dx
		add	ax,3
		adc	dx,0
		and	al,0FCh
		add	[di+6],ax		; m->size += m->chunk_size
		adc	[di+8],dx
		inc	cx
		loop	@@next
		endif
                mov	[di+28],si		; m->state
		push	di
                call	[word di+26]		; m->next_chunk()
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
		mov	ax,[word sz]
		mov	cx,[di+22]	; m->chunk_size
		cmp	ax,cx
		jb	@@szok
		cmp	[word di+24],0	; hi m->chunk_size
		jne	@@szok
		xchg	ax,cx
@@szok:
		push	ax
		push	[word data]
		push	[word di]
		call	_read
		pop	cx
		pop	bx
		add	bx,ax
		pop	cx
		xor	cx,cx
		sub	[di+22],ax
		sbb	[di+24],cx
@@fill:
		test	al,3
		je	@@filled
		mov	[bx],cl
		inc	bx
		inc	ax
		jmp	@@fill
@@filled:
		add	[bp-4-2],ax
		add	[word data],ax
		sub	[word sz],ax
		jz	image_done
		mov	cx,[di+22]		; lo m->chunk_size
		or	cx,[di+24]		; hi m->chunk_size
		jnz	image_done
                or	cx,[di+26]		; m->next_chunk
		jz	image_done
		push	di
                call	cx			; m->next_chunk()
		pop	di
		mov	cx,[di+22]		; lo m->chunk_size
		or	cx,[di+24]		; hi m->chunk_size
		jz	image_done
		jmp	@@loop

        endp    _read_image


;***************************************************************
;unsigned long strtol(const char *s);
;***************************************************************
        global  _strtol:near
        proc    _strtol near

;TODO NO386
		ifndef	NO386
		pop	ax			;caller return address
                pop	cx			; s
		push	cx
		push	ax
		xor	ebx,ebx
		jcxz	@@end
		push	si
		mov	si,cx
		xor	ecx,ecx
		xor	eax,eax
		mov	cl,10			; radix
		lodsb
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
		jcxz	@@end
		mov	si,cx
		mov	cx,10			; radix
		lodsb
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
		cmp	cx,2
		jl	popsiret
		shl	cx,2
@@loop:
		xor	ax,ax
		jcxz	popsiret
		mov	si,4
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
		mov	bx,sp
		sub	bh,14h			; MIN_STACK=_1k+PAGE_SIZE
		sub	bx,cx
		jb	@@outofmem
		cmp	bx,ax
		jb	@@outofmem
		add	[_heap_top],cx		; _BEG has zero'd heap
		;mov	bx,ax
@@zalloc:
		;mov	[byte bx],0
		;inc	bx			; ZF=0
		;loop	@@zalloc
		ret
@@outofmem:
		mov	bx,offset msg_malloc
		call	puts
		xor	ax,ax			; ZF=1
		ret

        endp    _malloc


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
		sub	al,040h
		and	al,0C0h
		mov	cl,6
		shl	ax,cl
		ret

        endp    _topseg
		endif


        ends    _TEXT

        end

;###### END OF FILE ############################################
