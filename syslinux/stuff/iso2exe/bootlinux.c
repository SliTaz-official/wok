#include <stdio.h>
#include "libdos.h"
#include "iso9660.h"
#asm
		use16	86
#endasm

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
		mov	ax, _iselks
		dec	ax
		je	fakerealmode	// elks may run on a 8086
		use16	286
		smsw	ax		// 286+
		and	ax, #1		// 0:realmode	1:vm86
		use16	86
fakerealmode:
#endasm
} 

static struct {
	unsigned long base;
	int align;
} mem = { 0x100000, 0 };

#ifdef __MSDOS__ 
#define A20HOLDBUFFER	0x80000
static int a20buffer = 0;
#endif

static void movehi(void)
{
#asm
		push	si
		push	di

		xor	ax, ax
		mov	si, #_mem
		cmp	word ptr [si+2], #0x10
#ifdef __MSDOS__ 
		jne	nota20
		mov	ax, #A20HOLDBUFFER/16
		mov	_a20buffer, ax
		mov	di, [si]	// mem.base & 0xFFFF
		jmp	mvbuffer
nota20:
#endif
		jnc	movehiz
		lodsb
		xchg	ax, di
		lodsw
		mov	cl, #4
		shl	ax, cl		// 8086 support for elks
mvbuffer:
		mov	es, ax
		mov	si, #_buffer
		cld
		mov	cx, #BUFFERSZ/2
		rep
		  movw
		jmp	movedone
movehiz:				// 30
		use16	286		// more than 1Mb => 286+
		mov	cx, #9		// 2E..1E
zero1:
		push	ax
		loop	zero1
		push	word [si+2]
		push	word [si]	// 1A mem.base
		push	#-1		// 18
		push	ax		// 16
		mov	ax, ds
		mov	dx, ax
		shl	ax, #4
		shr	dx, #12
		add	ax, #_buffer
		adc	dx, #0
		push	dx
		push	ax
		push	#-1		// 10
		mov	cl, #8		// 0E..00
zero2:
		push	#0
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
		use16	86
movedone:
		pop	di
		pop	si
#endasm
}

static unsigned vgamode, zimage = 0;
static unsigned getss(void)
{
#asm
	mov	ax, ss
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
		xchg	di, _setupofs
		mov	si, #_buffer
		cld
		mov	cx, #BUFFERSZ/2
		rep
		  movsw
		xchg	di, _setupofs
		pop	si
#endasm
}

static unsigned getcs(void)
{
#asm
	mov	ax, cs
#endasm
}

#define WORD(x)	* (unsigned short *) (x)
#define LONG(x)	* (unsigned long *) (x)
static unsigned setup_version = 0;
static unsigned long kernel_version = 0;
unsigned long loadkernel(void)
{
	unsigned setup;
#define LINUX001_SUPPORT
#ifdef LINUX001_SUPPORT
	unsigned n = 512;
#else
	unsigned n = BUFFERSZ;
#endif
	unsigned long syssize = 0;

	do {
		isoread(buffer, n);
		if (setupofs == 0) {
			if (WORD(buffer + BOOTFLAG) != 0xAA55)
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
			syssize = LONG(buffer + SYSSIZE) << 4;
			if (!syssize) syssize = 0x7F000;
			setup = (1 + buffer[SETUPSECTORS]) << 9;
			vgamode = WORD(buffer + VIDEOMODE);
			if (setup == 512) {
#ifdef LINUX001_SUPPORT
				if (WORD(buffer + 0x3F) == 0x3AE8) /* linux 0.01 */
					goto linux001;
#endif
				setup = 5 << 9;
			}
#ifdef LINUX001_SUPPORT
			n = BUFFERSZ;
			isoread(buffer+512, BUFFERSZ-512);
#endif
#define HDRS	0x53726448
			if (LONG(buffer + HEADER) == HDRS)
				setup_version = WORD(buffer + VERSION);
#define ELKS	0x534B4C45
			if (LONG(buffer + ELKSSIG) == ELKS)
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
				WORD(buffer + RMSWOFS) =  far_realmode_switch;
				WORD(buffer + RMSWSEG) =  getcs();
#endif
				mem.base = LONG(buffer + SYSTEMCODE);
				WORD(buffer + HEAPPTR) = 0x9B00;
				// buffer[LOADFLAGS] |= 0x80;
				WORD(buffer + LOADERTYPE) |= 0x80FF;
			}
#ifdef LINUX001_SUPPORT
	linux001:
#endif
			if (!setup_version || !(buffer[LOADFLAGS] & 1)) {
				zimage = getss() + 0x1000;
				mem.base = zimage * 16L; 
				if (mem.base + syssize > setupseg*16L - 32) {
					zimage = 0x9311;
					mem.base = 0x110000L;	// 1M + 64K HMA 
				}
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
		mov	es, _setupseg
		seg	es
		add	si, [si+14]
		mov	bx, #2
		mov	cl, #4
nextnumber:
		xor	ax, ax
nextdigit:
		shl	al, cl
		shl	ax, cl
		seg	es
		lodsb
		sub	al, #0x30
		cmp	al, #9
		jbe	nextdigit
		mov	[bx+_kernel_version], ah
		dec	bx
		jns	nextnumber
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
	char *s;
	
	s = strstr(cmdline," vga=");
	if (s) {
		vgamode = -1;
		s += 5;
		switch (*s | 0x20) {
		case 'a' : vgamode--;
		case 'e' : vgamode--;
		case 'n' : break;
		default  : vgamode = atoi(s);
		}
	}
	dosshutdown();
#asm
	cld
	mov	es, _setupseg
	mov	ax, _vgamode
	seg	es
	mov	VIDEOMODE, ax
	mov	ax, _setup_version
	cmp	ax, #0x200
	jb	noinitrd
		mov	di, #0x218
		mov	si, #_initrd_addr
		movsw
		movsw
		mov	si, #_initrd_size
		movsw
		movsw
noinitrd:
	mov	si, [bp+4]	// .bootlinux.cmdline[bp]
	or	si, si
	jz	nocmdline
		cmp	ax, #0x201
		mov	di, #0x0020
		mov	ax, #0xA33F
		mov	bx, #CMDLINE_OFFSET
		push	bx
		jbe	oldcmdline
		mov	di, #0x0228
		mov	ax, es
		mov	cl, #12
		shr	ax, cl
		xchg	ax, bx
oldcmdline:
		stosw
		xchg	ax, bx
		stosw
		pop	di
copy:
		lodsb
		stosb
		or	al,al
		jne	copy
nocmdline:
	push	es
	pop	ss
	mov	sp, #CMDLINE_OFFSET
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
		//mov	bh, #0x93
mvdown:
		mov	[si+0x12+2], bx	// srce
		mov	[si+0x1A+2], cx	// dest
		use16	286		// more than 1Mb => 286+
		pusha
		mov	cx, #0x8000
		mov	ah, #0x87
		int	0x15
		popa
		use16	86
		inc	bx
		inc	cx
		cmp	dl, bl
		ja	mvdown
		jmp	notzimage
lowsys:
// bx first segment, dx:ax last byte+1 (paragraph aligned)
		mov	cl, #4		// elks may run on a 8086
		shr	ax, cl
		shl	dx, cl
		or	ah, dl		// last segment+1
		mov	dx, #SYSTEM_SEGMENT
		sub	ax, bx		// ax = paragraph count
		sub	bx, dx
		jnc	sysmovelp
		add	dx, ax		// top down
		dec	dx
sysmovelp:		// move ax paragraphs from bx+dx:0 to dx:0
		mov	es, dx
		mov	si, dx
		add	si, bx
		mov	ds, si
		sbb	si, si		// si = 0 : -1
		cmc			// C  = 1 :  0
		adc	dx, si
		mov	cl, #8
		xor	di, di
		xor	si, si
		rep
		  movsw
		dec	ax
		jne	sysmovelp
notzimage:
	mov	ax, ss
	mov	ds, ax
	dec	bp
	jnz	notelks
	mov	ah, #0x1
	mov	ss, ax
notelks:
	push	ss
	pop	es
	xor	di, di
	xor	si, si
#ifdef LINUX001_SUPPORT
	mov	cx, #0x0042
	cmp	word ptr [si+0x3F], #0x3AE8
	je	islinux001
#endif
	mov	cx, #0x7800	// do not overload SYSTEM_SEGMENT
	rep
	  movsw
	push	es
	pop	ds
	xor	al, #0x20
islinux001:
	push	ax
	push	cx
	retf
endsysmove:
#endasm
}
