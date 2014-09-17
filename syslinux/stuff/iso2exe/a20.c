#ifndef __A20
#define __A20

#define A20HOLDBUFFER	0x80000
static int a20buffer = 0;
static void movehia20(void)
{
	if ((mem.base - 0x100000UL) >= 0x10000UL) {
		movehi();
		return;
	}
	a20buffer = 1;
#asm
		pusha			// more than 1Mb => 286+
		push	#A20HOLDBUFFER/16
		pop	es
		mov	di, _mem	// mem.base & 0xFFFF
		mov	si, #_buffer
		mov	cx, #BUFFERSZ/2
		cld
		rep
		  movsw
		popa
#endasm
}
#define movehi movehia20

#define REALMODE_SWITCH _realmode_switch_a20
static void realmode_switch_a20(void)
{
	if (!a20buffer) return;
#asm
		pusha			// more than 1Mb => 286+
		xor	di, di		// 30
		mov	cx, #9		// 2E..1E
a20z1:
		push	di
		loop	a20z1
		push	#0x10
		push	di		// 1A 0x100000
		push	#-1		// 18
		push	di		// 16
		push	#A20HOLDBUFFER/0x10000
		push	di		// 12 A20HOLDBUFFER
		push	#-1		// 10
		mov	cl, #8		// 0E..00
a20z2:
		push	di
		loop	a20z2
		mov	ch, #0x10000/512
		push	ss
		pop	es
		mov	si, sp
		mov	ax, #0x8793
		mov	[si+0x15], al
		xchg	[si+0x1D], al
		xchg	[si+0x1F], al	// bits 24..31
		int	0x15
		add	sp, #0x30
		popa
#endasm
}

#endif
