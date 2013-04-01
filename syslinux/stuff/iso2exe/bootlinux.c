#include <stdio.h>
#include "iso9660.h"

static unsigned version;
#define SETUPSECTORS	0x1F1
#define ROFLAG		0x1F2
#define SYSSIZE		0x1F4
#define VIDEOMODE	0x1FA
#define BOOTFLAG	0x1FE
#define HEADER		0x202
#define VERSION		0x206
#define RMSWOFS		0x208
#define RMSWSEG		0x20A
#define LOADERTYPE	0x210
#define LOADFLAGS	0x211
#define SYSTEMCODE	0x214
#define INITRDCODE	0x218
#define INITRDSIZE	0x21C
#define HEAPPTR		0x224
#define CMDLINE		0x228

#define SETUP_SEGMENT	0x9000
#define CMDLINE_OFFSET	0x9E00

#define PAGE_BITS	12
#define PAGE_SIZE	4096
#define BUFFERSZ	PAGE_SIZE
static char buffer[BUFFERSZ];
static unsigned long initrd_addr, initrd_size;

static int may_exit_dos = 1;
static void die(char *msg)
{
	printf("%s.\n", msg);
	if (may_exit_dos)
		exit(1);
	while (1);
}

static int vm86(void)
{
#asm
		smsw	ax
		and	ax, #1		// 0:realmode	1:vm86
#endasm
} 

static struct mem {
	unsigned long base;
	int align;
} kernelmem = { 0x100000, 0 };

#define initrdmem kernelmem

static void movehi(void)
{
#asm
		pusha
		xor	di, di		// 30
		mov	cx, #9		// 2E..1E
zero1:
		push	di
		loop	zero1
		push	dword [_kernelmem]	// 1A p->base
		push	#-1		// 18
		push	di		// 16
		xor	eax, eax
		cdq
		mov	dx, ds
		shl	edx, #4
		mov	ax, #_buffer
		add	edx, eax
		push	edx		// 12 linear_address(buffer)
		push	#-1		// 10
		mov	cl, #8		// 0E..00
zero2:
		push	di
		loop	zero2
		mov	ch, #BUFFERSZ/512
		push	ss
		pop	es
		mov	si, sp
		mov	ax, #0x8793
		mov	[si+0x15], al
		xchg	[si+0x1D], al
		mov	[si+0x1F], al	// bits 24..31, doesn't work for me :(
		int	0x15
		add	sp, #0x30
		popa
#endasm
}

#undef ZIMAGE_SUPPORT	/* Does not work... */

static int versiondos;
static int dosversion(void)
{
#asm
		mov	ah, #0x30
		int	0x21
		cbw
		mov	_versiondos, ax
#endasm
}

static void load(struct mem *p, unsigned long size)
{
	if (vm86())
		die("Need real mode");
	switch (p->align) {
	case 0:	// kernel
		switch (dosversion()) {
		case 3: case 4: case 6: break;
		default:
			printf("DOS %d not supported.\nTrying anyway...\n",
				versiondos);
		}
		p->align = PAGE_SIZE;
		break;
	case 4096: // first initrd
		initrd_addr = p->base;
		p->align = 4;
	}
	while (size) {
		int n, s = sizeof(buffer);
		for (n = 0; n < s; n++) buffer[n] = 0;
		if (s > size) s = size;
		n = isoread(buffer, s);
		movehi();
		if (n != -1) {
			p->base += n;
			size -= n;
		}
		if (s != n) break;
	}
	initrd_size = p->base - initrd_addr;
	p->base += p->align - 1;
	p->base &= - p->align;
}

static unsigned setupofs = 0;

void movesetup(void)
{
#asm
		pusha
		push	#SETUP_SEGMENT
		pop	es
		mov	si, #_buffer
		mov	di, _setupofs
		mov	cx, #BUFFERSZ/2
		rep
		  movsw
		mov	_setupofs, di
		popa
#endasm
}

static unsigned getcs(void)
{
#asm
	mov	ax, cs
#endasm
}

unsigned long loadkernel(void)
{
	unsigned setup, n = BUFFERSZ;
	unsigned long syssize = 0, version = 0;

	do {
		isoread(buffer, n);
		if (setupofs == 0) {
			if (* (unsigned short *) (buffer + BOOTFLAG) != 0xAA55)
				die("The kernel is not bootable");
			setup = (1 + buffer[SETUPSECTORS]) << 9;
			if (setup == 512) setup = 5 << 9;
			syssize = * (unsigned long  *) (buffer + SYSSIZE) << 4;
			version = * (unsigned short *) (buffer + VERSION);
#define HDRS	0x53726448
			if (* (unsigned long *) (buffer + HEADER) != HDRS)
				version = 0;
			if (version < 0x204)
				syssize &= 0x000FFFFFUL;
			if (version) {
#ifdef REALMODE_SWITCH
				extern int far_realmode_switch();
#asm
				jmp	end_realmode_switch
_far_realmode_switch:
				call	REALMODE_SWITCH
				cli
				mov	al, #0x80	// Disable NMI
				out	0x70, al
				retf
end_realmode_switch:
#endasm
				* (unsigned short *) (buffer + RMSWOFS) = 
					far_realmode_switch;
				* (unsigned short *) (buffer + RMSWSEG) = 
					getcs();
#endif
				kernelmem.base =
					* (unsigned long *) (buffer + SYSTEMCODE);
				* (unsigned short *) (buffer + HEAPPTR) = 
					0x9B00;
				// buffer[LOADFLAGS] |= 0x80;
				* (unsigned short *) (buffer + LOADERTYPE) |= 
					0x80FF;
			}
			if (!version || !(buffer[LOADFLAGS] & 1)) {
#ifdef ZIMAGE_SUPPORT
#asm
		pusha
		mov	cx, #0x8000
		mov	es, cx
		xor	si, si
		xor	di, di
		rep
		  movsw			// move 64K data
		push	es
		pop	ds
		push	es
		pop	ss
		mov	ch, #0x70
		mov	es, cx
		mov	ch, #0x80
		rep
		 seg	cs
		  movsw			// move 64K code
		popa
		jmpi	relocated, #0x7000
relocated:
#endasm
				kernelmem.base = 0x10000;
				if (syssize > 0x60000)	/* 384K max */
#endif
				die("Not a bzImage format");
			}
		}
		movesetup();
		setup -= n;
		n = (setup > BUFFERSZ) ? BUFFERSZ : setup;
	} while (setup > 0);

#asm
		push	ds
		push	#SETUP_SEGMENT
		pop	ds
		mov	si, #0x200
		mov	eax, #0x53726448	// HdrS
		cdq				// clear edx
		cmp	[si+2], eax
		jne	noversion
		add	si, [si+14]
		mov	cx, #3
		xor	ax, ax
nextdigit:
		shl	al, #4
		shl	ax, #4
next:
		lodsb
		sub	al, #0x30
		cmp	al, #9
		jbe	nextdigit
		shl	eax, #16
		shld	edx, eax, #8
		loop	next
		pop	ds
		mov	.loadkernel.version[bp], edx
noversion:
#endasm
	load(&kernelmem, syssize);
	return version;
}

void loadinitrd(void)
{
	if (version)
		load(&initrdmem, isofilesize);
}

void bootlinux(char *cmdline)
{
#asm
	push	#SETUP_SEGMENT
	pop	es
	mov	eax, _initrd_addr
	or	eax, eax
	jz	no_initrd
	mov	di, #0x218
	stosd
	mov	eax, _initrd_size
	stosd
no_initrd:
#endasm
	if (cmdline) {
		if (version <= 0x201) {
#asm
		mov	di, #0x0020
		mov	ax, #0xA33F
		stosw
		mov	ax, #CMDLINE_OFFSET
		stosw
#endasm
		}
		else {
#asm
		mov	di, #0x0228
		mov	eax, #SETUP_SEGMENT*16+CMDLINE_OFFSET
		stosd
#endasm
		}
#asm
		xchg	ax, di
		mov	si, .bootlinux.cmdline[bp]
copy:
		lodsb
		stosb
		or	al,al
		jne	copy
#endasm
	}
#asm
	push	es
	pop	ds
	push	ds
	pop	ss
	mov	sp, #CMDLINE_OFFSET
	jmpi	0, #0x9020
#endasm
}
