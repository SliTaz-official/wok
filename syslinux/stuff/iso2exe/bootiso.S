	.text
	.code16
	.arch	i8086
	.org	0

CODESZ	=	0x8000			// 16 sectors = 32Kb
#define EXEADRS(x)	x+0xC0
#define EXELOC(x)	x-0x40
#define EXESTR(x)	x-0x7F40

	.globl	_start
_start:
	decw	%bp			// Magic number: MZ
	popw	%dx
	jmp	start0			// Bytes on last page of file
	.word	(CODESZ+511)/512	// Pages in file
	.word	0			// Relocations
	.word	(end_header-_start)/16	// Size of header in paragraphs
	.word	4064-(CODESZ/16)	// Minimum extra paragraphs needed
	.word	4064-(CODESZ/16)	// Maximum extra paragraphs needed
	.word	0xFFF0			// Initial (relative) SS value
	.word	0xFFFE			// Initial SP value
magic:
	.word	0			// Checksum
	.word	EXEADRS(exestart)	// Initial IP value
	.word	0xFFF0			// Initial (relative) CS value
initramfssize:
	.word	0			// File address of relocation table
fdcnt:					// Overlay number
	.byte	0			// Bootstrap floppy sector count
	.ascii	"slitaz"

/////////////////////// Master Boot Record code //////////////////////////////

moved	=	0x8000
start0:
	//pushw	%dx			// restore %sp
	//incw	%bp			// restore %bp
	movw	%ds, %ax
	xorw	%bx, %bx
	movw	%bx, %ds
	movb	$0x7C, %bh
	pushw	%ds
	popw	%ss
	movw	%bx, %sp
	pushw	%bx			// return address
	pushw	%di
	pushw	%es			// save %es:%di
	pushw	%si
	cld
	call	setreg
	rep
	  movsw
	movw	$0x80, %dx
	ljmp	$0, $moved+start2
	.byte	0
//	.org	60
//	.long	0x0080			// PE header offset
	.org	64
end_header:
comstart:
	.word	0
	
	.org	66
start2:
	pushw	%ax			// original %ds
	sti
dxloop:
	call	readsector1		// look for the boot device
	repe
	cmpsw
	je	dxfound
	movb	$0, %cl			// ch = 0
	addb	$0x7D, %dl		// try every hard disk
	jno	dxloop

dxfound:
	call	readsectorX		// read isolinux boot sector
	cmpw	(%bx), %cx
	movw	$moved+nobsmsg, %si
	jnc	puts			// read fail or no isohydrid boot sector
	call	bootpartition		// assume DS=SS SI=BX=7C00 CX=0100 DL=<drive> DI=table+66
	popw	%ds
	popw	%si
	popw	%es
	popw	%di			// isolinux boot needs %es:%di and %dx
putsret:
	ret

putstrlp:
	movw	$7, %bx
	movb	$0xE, %ah
	int	$0x10
puts:
	lodsb
	cmp	$0, %al
	jnz	putstrlp
halt:
	hlt
	jmp	halt
nobsmsg:
	.asciz	"No isolinux."

	.org	0x0080,0xEE
////////////////////////////// EXE/PE header //////////////////////////////////
	.org	0x0178,0xFF
////////////////////////// partition boot code ////////////////////////////////
// assume DS=SS SI=BX=7C00 CX=0100 DL=<drive> DI=table+66

bootpartition:
	movw	$4,%cx
	movw	$16,%ax
next:
	subw	%ax,%di
	cmpb	%ch,-2(%di)		// boot flag ?
	loope	next
	cmpw	$63,2-2(%di)		// empty or isolinux partition ?
	jbe	default
	.arch	i486
	pushl	$0
	pushl	8-2(%di)
	pushw	%cs
	pushw	%bx
	pushw	$1
	pushw	%ax
	movw	%sp,%si			// assume %ds = %ss
	movb	$0x42,%ah
	int	$0x13
	add	$16,%sp
	.arch	i8086
default:
	ret

	.org	0x01A0,0xFF
readsectorX:				// read isolinux boot sector
	movb	$3, %cl			// isolinux/512
readsector1:
	andb	$0x83, %dl		// disk and floppy disk
	movw	%cx, (%bx)
	incw	%cx
	movw	$0x201, %ax
	int	$0x13
setreg:
	pushw	%ds
	popw	%es
	movw	%bx, %si
	movw	$moved, %di
	movw	$0x0100, %cx
	ret
	.org	0x01B8,0xEE		// partition table

	.org	0x0270,0xFF

////////////////////////////// DOS EXE code ///////////////////////////////////

cmdline:
	.ds.b	128,0
linldofs:				// offset of linld.com in iso
	.long	0			// Updated by iso2exe
linldsz:				// size-1
	.word	0			// Updated by iso2exe
exestart:
	movb	$0x30,%ah		// get DOS version
	int	$0x21
	cmpb	$3,%al
	jc	abort

// load linld.com

	cld
linldbuf	=	0x8000
isopath		=	0x7000
	movw	$0x8000,%cx		// clear 8000-FFFF
	movw	%cx,%di
	movb	%cl,%al
	rep
	  stosb

	movw	%di,%ax
	movw	0x2C(%di),%es
	decw	%cx
scalp:
	repne
	  scasb
	scasb
	jne	scalp
	scasw				// %es:%di = programme pathname
	pushw	%es
	pushw	%cs
	popw	%es
	popw	%ds
#define CONONICALIZE_FILENAME	insert obsolute path
#ifdef CONONICALIZE_FILENAME
	movw	%di,%si			// %ds:%si = programme pathname
	movw	$EXEADRS(isopath),%di	// to filename %es:%di
	movb	$0x60,%ah		// canonicalize filename
	int	$0x21
	pushw	%es
	popw	%ds
#endif
	movw	%di,%si			// %ds:%si = programme pathname
#define LONG_FILENAME
#ifdef LONG_FILENAME
	pushw	%si
	movw	$0x716C,%ax
	xorw	%bx,%bx			// R/O
	xorw	%cx,%cx			// attributes
	cwd				// action = open
	stc
	int	$0x21
	jnc	opened
	popw	%dx
#else
	movw	%si,%dx
#endif
	pushw	%si
	movw	$0x3D00,%ax
//	movb	$0,%cl
	int	$0x21
	jc	popNabort
opened:
	xchgw	%ax,%bx			// fd = %bx
	movw	$32,%cx
	movw	$EXEADRS(headbuf),%dx
	movb	$0x3F,%ah
	int	$0x21			// read(%bx,%dx,%cx)
	jc	popNabort
	les	EXEADRS(linldofs),%dx
	movw	%es,%cx
	movw	$0x4200,%ax		// lseek(%bx,%cx:%dx,SEEK_SET)
	int	$0x21
	jc	popNabort
	movw	EXEADRS(linldsz),%cx
	jcxz	popNabort
	movw	$EXEADRS(linldbuf),%dx
	movw	%cx,%di
	addw	%dx,%di
	movb	$0x3F,%ah
	int	$0x21			// read(%bx,%dx,%cx)
	jnc	copycmdline
popNabort:
	popw	%si
abort:
	movw	$EXEADRS(stopmsg),%dx
	movb	$9,%ah
	int	$0x21
	int	$0x20
	
// installed args (ex: image=/boot/bzImage initrd=rootfs4.gz,! autologin rdinit=/init.exe)

copycmdline:
	pushw	%ds
	popw	%es
	movw	$EXEADRS(cmdline),%si
	movw	%di,%bx

copylp:
	lodsb
	stosb
	orb	%al,%al
	jnz	copylp

// magic=<magic> arg

	decw	%di
	movw	$7,%cx
	movw	$EXEADRS(magicstr),%si
	rep
	  movsb
	movw	EXEADRS(headbuf+18),%ax		// magic
	movw	$10,%bp
magiclp1:
	xorw	%dx,%dx
	divw	%bp
	pushw	%dx
	incw	%cx
	orw	%ax,%ax
	jnz	magiclp1
magiclp2:
	popw	%ax
	addb	$'0',%al
	stosb				// store magic
	loop	magiclp2

// iso=<file> arg

	movb	$5,%cl
	//movw	$EXEADRS(isostr),%si
	rep
	  movsb
	popw	%si
isolp:
	lodsb
	stosb
	orb	%al,%al
	jne	isolp
	decw	%di

// append user args

	movw	$0x80,%si
	lodsb
	movb	$0xFF,-1(%si)		// long cmdline flag
	cbw
	xchgw	%ax,%cx
	rep
	  movsb
	movb	$0,(%di)

// set cmdline size

	movw	%di,%ax
	subw	%bx,%ax
	incw	%ax
	movb	%al,-1(%bx)

// run linld.com

	movw	$EXEADRS(mvNjump),%si
	incw	%di
	movb	$endmvNjump-mvNjump,%cl
mvNjump:
	pushw	%di
	rep
	  movsb
	movw	$EXEADRS(linldbuf),%si
	movw	$0x0100,%di
	popw	%cx
	pushw	%cx
	subw	%si,%cx
	ret
endmvNjump:

magicstr:	.ascii	" magic="
isostr:		.ascii	" iso="

	.org	0x0400,0xEE
headbuf:
	.org	0x0600,0xFF
isolinux:

	.arch	i486
#define PARTITION_SUPPORT
/* -----------------------------------------------------------------------
 *
 *   Copyright 2007-2009 H. Peter Anvin - All Rights Reserved
 *   Copyright 2009 Intel Corporation; author: H. Peter Anvin
 *
 *   Permission is hereby granted, free of charge, to any person
 *   obtaining a copy of this software and associated documentation
 *   files (the "Software"), to deal in the Software without
 *   restriction, including without limitation the rights to use,
 *   copy, modify, merge, publish, distribute, sublicense, and/or
 *   sell copies of the Software, and to permit persons to whom
 *   the Software is furnished to do so, subject to the following
 *   conditions:
 *
 *   The above copyright notice and this permission notice shall
 *   be included in all copies or substantial portions of the Software.
 *
 *   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 *   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 *   OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 *   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 *   HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 *   WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 *   OTHER DEALINGS IN THE SOFTWARE.
 *
 * ----------------------------------------------------------------------- */

HYBRID_MAGIC			= 0x7078c0fb
isolinux_start_hybrid		= 0x7c00+64+4

isolinux_hybrid_signature	= 64

stack		= 0x7c00
ebios_flag	= (stack-20)

BIOS_page	= 0x462

_start2:
	.byte	0x33, 0xed	/* xorw	%bp, %bp */

	/* Check to see if we have a partition table entry */
#ifdef PARTITION_SUPPORT
	xorl	%ebx, %ebx
	xorl	%ecx, %ecx
	andw	%si, %si		/* %si == 0 -> no partition data */
	jz	1f
	testb	$0x7f, (%si)		/* Invalid active flag field? */
	jnz	1f
	orb	4(%si), %cl		/* Partition type zero == invalid? */
	je	1f

	cmpb	$0xed, %cl		/* EFI partition type? */

	/* Get non-GPT partition information */
	movl	8(%si), %ecx

	jne	1f
	cmpl	$0x58504721, %eax	/* !GPT signature in EAX? */
	jne	1f
	
	/* We have GPT partition information */
	movl	(32+20)(%si), %ecx
	movl	(36+20)(%si), %ebx
#endif
1:
	movw	%bp, %ds
	movw	$stack, %sp

	/* We have no partition information */
#ifdef PARTITION_SUPPORT
	pushl	%ebx			/*  -4: partoffset_hi */
	pushl	%ecx			/*  -8: partoffset_lo */
#else
	pushl	$0			/*  -4: partoffset_hi */
	pushl	$0			/*  -8: partoffset_lo */
#endif
partoffset	= -8
	pushw	%es			/* -10: es:di -> $PnP header */
	pushw	%di			/* -12: es:di -> $PnP header */

	
	//ADJUST_DRIVE
	pushw	%dx			/* -14: dl -> drive number */
driveno		= -14

	pushw	%ds
	popw	%es

	/* Copy down to 0:0x600 */
	movw	$2f-0x600+0x7C00, %si
	movw	$2f, %di
	movb	$(512 >> 8), %ch
	pushw	%es
	pushw	%di
	rep; movsb

	retf
2:

	/* Check to see if we have EBIOS */
	pushw	%dx		/* drive number */
	movb	$0x41, %ah	/* %al == 0 already */
	movw	$0x55aa, %bx
	//xorw	%cx, %cx
	xorb	%dh, %dh
	int	$0x13
	andw	$1,%cx		/* Bit 0 = fixed disk subset */
	jz	1f
	decw	%cx		/* Clear EBIOS flag. */
	cmpw	$0xaa55, %bx
	jne	1f
	incw	%cx		/* Set EBIOS flag. */

	/* We have EBIOS; patch in the following code at
	   read_sector_cbios: movb $0x42, %ah ;  jmp read_common */
	movl	$0xeb42b4+((read_common-read_sector_cbios-4) << 24), \
		(read_sector_cbios)
1:
	popw	%dx
	pushw	%cx		/* EBIOS flag */

	/* Get (C)HS geometry */
	movb	$0x08, %ah
	int	$0x13
	popw	%bx		/* EBIOS flag */
	movzbw	%dh, %ax	/* dh = max head */
	incw	%ax		/* From 0-based max to count */
	pushw	%ax		/* -16: Save heads on the stack */
heads		= -16
	andw	$0x3f, %cx	/* Sector count */
	pushw	%cx		/* -18: Save sectors on the stack */
sectors		= -18
	mulw	%cx		/* Heads*sectors -> sectors per cylinder */

	pushw	%bx		/* -20: EBIOS flag */

	/* Save sectors/cylinder in %esi */
	pushw	%dx
	pushw	%ax
	popl	%edi

	/*
	 * Load sectors.  We do this one at a time mostly to avoid
	 * pitfalls and to share code with the stock MBR code.
	 */
	movw	$0x7c00, %bx
	movw	%bx, %bp
	xorl	%eax, %eax
	cdq
	movb	$17*4, %al	/* EL TORITO spec */
	call	read_sector
	movl	71(%bx), %eax	/* catalog */
	shll	$2, %eax
	call	read_sector
	movl	40(%bx), %eax	/* boot code */
	shll	$2, %eax
	movb	$4, %cl		/* Sector count */

2:
	call	read_sector
	incl	%eax
	addb	$(512 >> 8), %bh
	loopw	2b

	/*
	 * Okay, that actually worked... update the stack pointer
	 * and jump into isolinux.bin...
	 */
	cmpl	$HYBRID_MAGIC,isolinux_hybrid_signature(%bp)
	jne	error_os

	cli
	//movw	$ebios_flag, %sp

	/*
	 * Use a ljmpw here to work around a bug in some unknown version
	 * of gas or ld when it comes to jumping to an absolute symbol...
	 *
	 * Look more closely into it if we ever are short on space.
	 */
	//ljmpw	$0, $isolinux_start_hybrid
	pushw	$isolinux_start_hybrid
	ret

/*
 * read_sector: read a single sector pointed to by %eax to %es:%bx.
 * All registers saved.
 */
read_sector:
	pushal
#ifdef PARTITION_SUPPORT
	addl	partoffset(%bp), %eax
	adcl	partoffset+4(%bp), %edx
#endif
	pushl	%edx	/* MSW of LBA */
	pushl	%eax	/* LSW of LBA */
	pushw	%es	/* Buffer segment */
	pushw	%bx	/* Buffer offset */
	pushw	$1	/* Sector count */
	pushw	$16	/* Size of packet */
	movw	%sp, %si

	/* This chunk is skipped if we have ebios */
	/* Do not clobber %eax before this chunk! */
	/* This also relies on %bx and %edx as set up above. */
read_sector_cbios:
	divl	%edi
	shlb	$6, %ah
	xchgb	%al, %ah
	xchgw	%ax, %cx
	xchgw	%dx, %ax
	divb	sectors(%bp)
	movb	%al, %dh
	orb	%ah, %cl
	incw	%cx	/* Sectors are 1-based */
	movw	$0x0201, %ax

read_common:
	movb	driveno(%bp), %dl
	int	$0x13
	movw	$disk_error, %si
	jc	error
	addw	$16, %sp	/* Drop DAPA */
	popal
	ret

/*
 * Print error messages.  This is invoked with "call", with the
 * error message at the return address.
 */
error_os:
	movw	$bad_signature, %si
error:
	lodsb
	movb	$0x0e, %ah
	movb	(BIOS_page), %bh
	movb	$0x07, %bl
	int	$0x10		/* May destroy %bp */
	cmpb	$10, %al	/* Newline? */
	jne	error

	int	$0x18		/* Boot failure */
die:
	hlt
	jmp	die

bad_signature:
	.ascii	"isolinux.bin "
	.ascii	"missing or corrupt.\r\n"
disk_error:
	.ascii	"Operating system "
	.ascii	"load error.\r\n"

	.org	0x0750,0xBB
stopmsg:
	.ascii	"This program cannot be run in DOS mode.$"
	.org	0x0778,0xEE

	.macro	apple_partition	count=2, start=1, size=2, name, namesz, type, typesz, start_data, size_data, status
	.byte	0x50, 0x4D, 0, 0	/* PM */
#define BE(x) (((x)>>24)|((((x)>>16)&255)<<8)|((((x)>>8)&255)<<16)|(((x)&255)<<24))
	.long	BE(\count)
	.long	BE(\start)
	.long	BE(\size)
	.ascii	"\name"
	.ds.b	32-\namesz, 0
	.ascii	"\type"
	.ds.b	32-\typesz, 0
	.long	BE(\start_data)
	.long	BE(\size_data)
	.long	BE(\status)
	.ds.b	44,0			/* boot code & processor info */
	.endm

	.org	0x800,0
	apple_partition 2, 1, 2, "Apple", 5, "Apple_partition_map", 19, 0, 2, 3 /* valid, allocated */
	.org	0x1000,0
	apple_partition 2, 1, 2, "EFI", 3, "Apple_HFS", 9, 0, 0, 0x40000013 /* valid, allocated, readable, automatically mount at startup */

	.end
