#include "libdos.h"
#asm
		use16	86
#endasm

char *progname(void)
{
#asm
		.bss
._name	lcomm	80
		.text
		push	es
		seg	cs
		mov	es, [0x2C]
		mov	cx, #-1
		xor	di, di
		xor	al, al
loop1:
		repne
		scasb
		scasb
		jne	loop1
		lea	si, [di+2]
		push	ds
		push	ds
		push	es
		pop	ds
		pop	es
		mov	di, ._name
		push	di
loop2:
		lodsb
		stosb
		or	al, al
		jnz	loop2
		pop	ax
		pop	ds
		pop	es
#endasm
}

#ifdef __SLEEP
void sleep(int seconds)
{
	unsigned long n;
	
	n = (seconds * 182) / 10;
#asm
		push	es
		push	#0
		pop	es
		mov	di, #0x46C
sleeplp:	
		mov	cx, #0x8000
		or	dx, dx
		jne	siok
		mov	cx, ax
		jcxz	done
siok:
		sub	ax, cx
		sbb	dx, #0
		seg	es
		add	cx, [di]
zzz:
		seg	es
		cmp	cx, [di]
		jne	zzz
		jmp	sleeplp
done:
		pop	es
#endasm
}
#endif

int chdirname(char *path)
{
#asm
		pop	ax
		pop	bx
		push	bx
		push	ax
		cmp	byte ptr [bx+1], #0x3A
		jne	nodisk
		mov	dl, [bx]
		or	dl, #0x20
		sub	dl, #0x61
		mov	ah, #0x0E
		push	bx
		int	0x21
		pop	bx
		inc	bx
		inc	bx
nodisk:
		mov	dx, bx
		xor	cx, cx
next:
		mov	al, [bx]
		cmp	al, #0x5C
		jne	tsteos
		mov	cx, bx
tsteos:
		inc	bx
		or	al, al
		jnz	next
		cbw
		jcxz	quit
		mov	bx, cx
		push	[bx]
		mov	[bx], al
		push	bx
		call	chdir
		pop	bx
		pop	[bx]
quit:
		ret
	
// int chdir(char *path)
_chdir:
		pop	ax
		pop	dx
		push	dx
		push	ax
chdir:
		stc
		mov	ax, #0x713B
		int	0x21
		jnc	chdireturn
		mov	ah, #0x3B
		int	0x21
chdireturn:
		sbb	ax, ax
#endasm
}

void dosshutdown(void)
{
#asm
		push	bp
		push	si
		push	di
		push	ds
		seg	cs
		mov	stack+2, ss
		seg	cs
		mov	stack,sp
		xor	bx, bx
		mov	ds, bx		// ds = 0
		mov	[bx+4], #step
		mov	[bx+6], cs
		pushf
		pop	ax
		or	ax, #0x100	// set TF
		push	ax
		popf
		jmp	far [bx+4*0x19]
stack:
		.long	0
stepagain:
		iret
step:
		push	si
		push	ds
		mov	si, sp
		seg	ss
		lds	si, [si+4]
		cmp	word ptr [si], #0x19CD
		pop	ds
		pop	si
		jne	stepagain
		seg	cs
		lds	di, stack
		push	ds
		pop	ss
		mov	sp, di
		pop	ds
		pop	di
		pop	si
		pop	bp
#endasm
}

int versiondos;
int dosversion(void)
{
#asm
		mov	ah, #0x30
		int	0x21
		cbw
		mov	_versiondos, ax
#endasm
}

void copycmdline(char store[])
{
#asm
		pop	cx
		pop	ax
		push	ax
		push	cx
		push	si
		push	di
		push	ds
		pop	es
		mov	si, #0x81
		xchg	ax, di
space:
		seg	cs
		lodsb
		cmp	al, #0x20
		je	space
		dec	si
		mov	cx, #0x80/2
		rep
		 seg	cs
		  movsw
		pop	di
		pop	si
#endasm
}
