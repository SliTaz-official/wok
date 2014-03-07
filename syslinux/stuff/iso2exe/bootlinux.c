#include <stdio.h>
#include "iso9660.h"

static unsigned setup_version;
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
#define BUFFERSZ	2048		// lower than min setup
static char buffer[BUFFERSZ];
static unsigned long initrd_addr = 0, initrd_size;

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

static struct {
	unsigned long base;
	int align;
} mem = { 0x100000, 0 };

static void movehi(void)
{
#asm
		pusha
		xor	di, di		// 30
		mov	cx, #9		// 2E..1E
zero1:
		push	di
		loop	zero1
		push	dword [_mem]	// 1A mem.base
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
		xchg	[si+0x1F], al	// bits 24..31
		int	0x15
		add	sp, #0x30
		popa
#endasm
}

#define ZIMAGE_SUPPORT

#ifdef ZIMAGE_SUPPORT
static int zimage = 0;
static unsigned zimage_base;
static unsigned getss(void)
{
#asm
	mov	ax, ss
#endasm
}
#endif

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

static unsigned extendedramsizeinkb(void)
{
#asm
		mov	ah, #0x88
		int	0x15
		jnc	gottop
		xor	ax, ax
gottop:
#endasm
}

static void load(unsigned long size)
{
	if (vm86())
		die("Need real mode");
	switch (mem.align) {
	case 0:	// kernel
		switch (dosversion()) {
		case 3: case 4: case 6: case 7: break;
		default:
			printf("DOS %d not supported.\nTrying anyway...\n",
				versiondos);
		}
		mem.align = PAGE_SIZE;
		break;
	case PAGE_SIZE: // first initrd : keep 16M..48M for the kernel
		if (extendedramsizeinkb() > 0xF000U && mem.base < 0x3000000)
			mem.base = 0x3000000;
		initrd_addr = mem.base;
		mem.align = 4;
	}
	while (size) {
		int n, s = sizeof(buffer);
		for (n = 0; n < s; n++) buffer[n] = 0;
		if (s > size) s = size;
		if ((n = isoread(buffer, s)) < 0) break;
		movehi();
		mem.base += n;
		size -= n;
		if (s != n) break;	// end of file
	}
	initrd_size = mem.base - initrd_addr;
	mem.base += mem.align - 1;
	mem.base &= - mem.align;
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
	unsigned long syssize = 0, kernel_version = 0;

	do {
		isoread(buffer, n);
		if (setupofs == 0) {
			if (* (unsigned short *) (buffer + BOOTFLAG) != 0xAA55)
				die("The kernel is not bootable");
			setup = (1 + buffer[SETUPSECTORS]) << 9;
			if (setup == 512) setup = 5 << 9;
			syssize = * (unsigned long  *) (buffer + SYSSIZE) << 4;
			setup_version = * (unsigned short *) (buffer + VERSION);
#define HDRS	0x53726448
			if (* (unsigned long *) (buffer + HEADER) != HDRS)
				setup_version = 0;
			if (setup_version < 0x204)
				syssize &= 0x000FFFFFUL;
			if (setup_version) {
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
				mem.base =
					* (unsigned long *) (buffer + SYSTEMCODE);
				* (unsigned short *) (buffer + HEAPPTR) = 
					0x9B00;
				// buffer[LOADFLAGS] |= 0x80;
				* (unsigned short *) (buffer + LOADERTYPE) |= 
					0x80FF;
			}
			if (!setup_version || !(buffer[LOADFLAGS] & 1)) {
#ifdef ZIMAGE_SUPPORT
				zimage = 1;
				zimage_base = getss() + 0x1000L;
				mem.base = zimage_base * 16L; 
				if (mem.base + syssize > SETUP_SEGMENT*16L - 32)
					die("Out of memory");
#else
				die("Not a bzImage format");
#endif
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
		mov	.loadkernel.kernel_version[bp], edx
		push	ds
noversion:
		pop	ds
#endasm
	load(syssize);
	return kernel_version;
}

void loadinitrd(void)
{
	if (setup_version && zimage == 0)
		load(isofilesize);
}

void bootlinux(char *cmdline)
{
#asm
	push	#SETUP_SEGMENT
	pop	es
#endasm
	if (cmdline) {
		if (setup_version <= 0x201) {
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
	if (setup_version >= 0x200) {
#asm
		mov	eax, _initrd_addr
		mov	di, #0x218
		stosd
		mov	eax, _initrd_size
		stosd
#endasm
	}
#asm
	push	es
	pop	ss
	mov	sp, #CMDLINE_OFFSET
#endasm
#ifdef ZIMAGE_SUPPORT
	if (zimage) {
#asm
		mov	eax, _mem
		shr	eax, #4		// top
		mov	bx, _zimage_base
		mov	dx, #0x1000
		push	cs
		pop	ds
		mov	es, ax
		push	es
		mov	si, #sysmove
		xor	di, di
		push	di
		mov	cx, #endsysmove-sysmove
		rep
		  movsb
		retf
sysmove:
		mov	ds, bx
		mov	es, dx
		xor	di, di
		xor	si, si
		mov	cl, #8
		rep
		  movsw
		inc	bx
		inc	dx
		cmp	ax,bx
		jne	sysmove
#endasm
	}
#endif
#asm
	push	ss
	pop	ds
	push	ds
	pop	es
	jmpi	0, #0x9020
endsysmove:
#endasm
}
