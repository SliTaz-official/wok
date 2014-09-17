#include <stdio.h>
#include "libdos.h"
#include "iso9660.h"

static unsigned setup_version;
#define ELKSSIG		0x1E6
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

#define SYSTEM_SEGMENT	0x1000
#define SETUP_SEGMENT	0x9000
#define CMDLINE_OFFSET	0x9E00
#define SETUP_END	0x8200

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

static int iselks;
static int vm86(void)
{
#asm
		xor	ax, ax
		cmp	ax, _iselks
		jne	fakerealmode	// elks may run on a 8086
		smsw	ax		// 286+
		and	ax, #1		// 0:realmode	1:vm86
fakerealmode:
#endasm
} 

static struct {
	unsigned long base;
	int align;
} mem = { 0x100000, 0 };

static void movehi(void)
{
#asm
		push	si
		push	di

		mov	si, #_mem
		cmp	word ptr [si+2], #0x10
		jnc	movehiz
		mov	ax, [si+1]
		mov	cl, #4
		shl	ax, cl		// 8086 support for elks
		mov	es, ax
		mov	di, #0x00FF
		and	di, [si]
		mov	si, #_buffer
		mov	cx, #BUFFERSZ/2
		cld
		rep
		  movw
		jmp	movedone
movehiz:
		xor	di, di		// 30
		mov	cx, #9		// 2E..1E
zero1:
		push	di
		loop	zero1
		push	dword [si]	// 1A mem.base
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
movedone:
		pop	di
		pop	si
#endasm
}

#define ZIMAGE_SUPPORT
#define FULL_ZIMAGE

#ifdef ZIMAGE_SUPPORT
static unsigned zimage = 0;
static unsigned getss(void)
{
#asm
	mov	ax, ss
#endasm
}
#endif

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


#include "a20.c"

static void load(unsigned long size)
{
	if (vm86())
		die("Need real mode");
	switch (mem.align) {
	case 0:	// kernel
#ifdef __MSDOS__ 
		if ((unsigned) (dosversion() - 3) > 7 - 3) {
			printf("DOS %d not supported.\nTrying anyway...\n",
				versiondos);
		}
#endif
		mem.align = PAGE_SIZE;
		break;
	case PAGE_SIZE: // first initrd : keep 16M..48M for the kernel
		if (extendedramsizeinkb() > 0xF000U && mem.base < 0x3000000)
			mem.base = 0x3000000;
		initrd_addr = mem.base;
		mem.align = 4;
	}
#ifdef ALLOCMEM
	ALLOCMEM(size);
#endif
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

static unsigned setupseg = SETUP_SEGMENT;
static unsigned setupofs = 0;

void movesetup(void)
{
#asm
		push	si
		mov	es, _setupseg
		mov	si, #_buffer
		xchg	di, _setupofs
		mov	cx, #BUFFERSZ/2
		rep
		  movsw
		xchg	_setupofs, di
		pop	si
#endasm
}

static unsigned getcs(void)
{
#asm
	mov	ax, cs
#endasm
}

static unsigned long kernel_version = 0;
unsigned long loadkernel(void)
{
	unsigned setup, n = BUFFERSZ;
	unsigned long syssize = 0;

	do {
		isoread(buffer, n);
		if (setupofs == 0) {
			if (* (unsigned short *) (buffer + BOOTFLAG) != 0xAA55)
				die("The kernel is not bootable");
#asm
			int	0x12
			jc	has640k
			dec	ax
			and	al, #0xC0
			mov	cl, #6
			shl	ax, cl
			cmp	ax, _setupseg
			jnc	has640k
			mov	_setupseg, ax
has640k:
#endasm
			setup = (1 + buffer[SETUPSECTORS]) << 9;
			if (setup == 512) setup = 5 << 9;
			syssize = * (unsigned long  *) (buffer + SYSSIZE) << 4;
			if (!syssize) syssize = 0x7F000;
			setup_version = * (unsigned short *) (buffer + VERSION);
#define HDRS	0x53726448
			if (* (unsigned long *) (buffer + HEADER) != HDRS)
				setup_version = 0;
#define ELKS	0x534B4C45
			if (* (unsigned long *) (buffer + ELKSSIG) == ELKS)
				iselks = 1;
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
				zimage = getss() + 0x1000;
				mem.base = zimage * 16L; 
				if (mem.base + syssize > setupseg*16L - 32) {
#ifdef FULL_ZIMAGE
					zimage = 0x11;
					mem.base = 0x110000L;	// 1M + 64K HMA 
#else
					die("Out of memory");
#endif
				}
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
		push	si
		mov	si, #0x200
		cmp	si, _setup_version
		jae	noversion
		push	ds
		mov	ds, _setupseg		// setup > 2.00 => 386+
		xor	eax, eax
		cdq				// clear edx
		add	si, [si+14]
		mov	cx, #3
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
		mov	_kernel_version, edx
noversion:
		pop	si
#endasm
	load(syssize);
	return kernel_version;
}

void loadinitrd(void)
{
	if (setup_version)
		load(isofilesize);
}

void bootlinux(char *cmdline)
{
	dosshutdown();
#asm
	mov	es, _setupseg
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
#asm
	cld
	mov	ax, _mem
	mov	dx, _mem+2
	mov	bx, _zimage
	mov	bp, _iselks
	mov	si, #sysmove
	mov	di, #SETUP_END
	mov	cx, #endsysmove-sysmove
	or	bx, bx
	jz	notzimage
		push	cs
		pop	ds
		push	es
		push	di
		rep
		  movsb
		retf
sysmove:
#ifdef FULL_ZIMAGE
		cmp	dx, #0x0010
		jb	lowsys
// bx first 64k page, dx:ax last byte+1
		xchg	ax, cx			// clear ax
		jcxz	aligned
		inc	dx
aligned:
		mov	si, di
		mov	cx, #0x18
		rep
		  stosw
		push	es
		pop	ds
		dec	cx
		mov	[si+0x10], cx	// limit = -1
		mov	[si+0x18], cx	// limit = -1
		mov	cx, #0x9300+SYSTEM_SEGMENT/0x1000
		mov	bh, #0x93
mvdown:
		mov	[si+0x12+2], bx	// srce
		mov	[si+0x1A+2], cx	// dest
		pusha			// more than 1Mb => 286+
		mov	cx, #0x8000
		mov	ah, #0x87
		int	0x15
		popa
		inc	bx
		inc	cx
		cmp	dl, bl
		jne	mvdown
		jmp	notzimage
#endif
lowsys:
// bx first segment, dx:ax last byte+1 (paragraph aligned)
		mov	cl, #4
		shr	ax, cl
		mov	cl, #12
		shl	dx, cl
		or	ax, dx		// last segment+1
		mov	dx, #SYSTEM_SEGMENT
		sub	ax, bx		// ax = paragraph count
		sub	bx, dx
		jnc	sysmovelp
		add	dx, ax		// top down
		dec	dx
sysmovelp:		// move ax paragraphs from bx+dx:0 to dx:0
		mov	es, dx
		mov	cx, dx
		add	cx, bx
		mov	ds, cx
		sbb	cx, cx		// cx = 0 : -1
		cmc			// C  = 1 :  0
		adc	dx, cx
		xor	di, di
		xor	si, si
		mov	cx, #8
		rep
		  movsw
		dec	ax
		jne	sysmovelp
notzimage:
	or	bp, bp
	jz	notelks
	push	ss
	pop	ds
	mov	cx, #0x100
	mov	es, cx
	mov	ch, #0x78	// do not overload SYSTEM_SEGMENT
	xor	si, si
	xor	di, di
	push	es
	rep
	  movsw
	pop	ss
notelks:
#endasm
#endif
#asm
	mov	ax, ss
	mov	ds, ax
	mov	es, ax
	add	ax, #0x20
	push	ax
	xor	dx, dx
	push	dx
	retf
endsysmove:
#endasm
}
