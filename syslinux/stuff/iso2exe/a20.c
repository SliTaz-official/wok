#ifndef __A20
#define __A20

// http://www.win.tue.nl/~aeb/linux/kbd/A20.html
static void a20enable(void)
{
#asm
		call	a20test

		in	al, 0x92	// fast A20
		test	al, #0x2
		jnz	no92
		or	al, #0x2	// Enable A20
		and	al, #0xFE	// Do not reset machine
		out	0x92, al
		call	a20test
no92:
		call	empty_8042
		mov	al, #0xD1	// command write
		out	0x64, al 
		call	empty_8042
		mov	al, #0xDF	// Enable A20
		out	0x60, al 
		call	empty_8042

		mov	al, #0xFF	// Null command, but UHCI wants it
		out	0x64, al 
		call	empty_8042
		call	a20test
		
		mov	ax, #0x2401
		int	0x15
		call	a20test
		
		in	al, 0xEE	// fast enable A20
		jmp	a20test

empty_8042:
		mov	ah, #-32
wait_8042:
		in	al, 0x64
		inc	ax		// FF 32x : no kbd
		jz	enabled
		dec	ax
		shr	ax, #1		// Bit 0: input data
		jc	data
		shr	ax, #1		// Bit 1: buffer empty
		jc	wait_8042
		ret
data:
		in	al, 0x60	// read data
		jmp	wait_8042
a20test:
		push	ds
		xor	cx, cx
		xor	bx, bx
		mov	ds, cx		// ds = 0000
		dec	cx
		mov	gs, cx		// gs = FFFF
		cli
a1:
		mov	ax, [bx]
		not	ax
		mov	dx, ax
		seg	gs
		xchg	dx, [bx+10]
		cmp	ax, [bx]
		seg	gs
		mov	[bx+10], dx
		loopne	a1
		pop	ds
		xchg	ax, cx
		sti
		jne	enabled
		pop	cx		// quit a20enable
enabled:
		ret			// ax != 0 : enabled
#endasm
}

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
		pusha
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
	a20enable();
#asm
		pusha
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
