#ifndef __A20
#define __A20

static void dosshutdowna20(void)
{
#asm
	call	_dosshutdown
	xor	ax, ax			// 30
	cmp	ax, _a20buffer
	je	no_a20buffer
		pusha			// more than 1Mb => 286+
		mov	cx, #9		// 2E..1E
a20z1:
		push	ax
		loop	a20z1
		push	#0x9310
		push	ax		// 1A 0x100000
		push	#-1		// 18
		push	ax		// 16
		push	#0x9300+A20HOLDBUFFER/0x10000
		push	ax		// 12 A20HOLDBUFFER
		push	#-1		// 10
		mov	cl, #8		// 0E..00
a20z2:
		push	ax
		loop	a20z2
		mov	ch, #0x10000/512
		push	ss
		pop	es
		mov	si, sp
		mov	ah, #0x87
		int	0x15
		add	sp, #0x30
		popa
no_a20buffer:
#endasm
}

#define dosshutdown dosshutdowna20

#endif
