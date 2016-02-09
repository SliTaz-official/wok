/*
	Copyright (C) 2000, Entity Cyber, Inc.

	Authors: Gary Byers (gb@thinguin.org)
		 Marty Connor (mdc@thinguin.org)

	This software may be used and distributed according to the terms
	of the GNU Public License (GPL), incorporated herein by reference.

	Description:	

	This is just a little bit of code and data that can get prepended
	to a ROM image in order to allow bootloaders to load the result
	as if it were a Linux kernel image.

	A real Linux kernel image consists of a one-sector boot loader
	(to load the image from a floppy disk), followed a few sectors
	of setup code, followed by the kernel code itself.  There's
	a table in the first sector (starting at offset 497) that indicates
	how many sectors of setup code follow the first sector and which
	contains some other parameters that aren't interesting in this
	case.

	We don't require much in the way of setup code.  Historically, the
	Linux kernel required at least 4 sectors of setup code.
	Therefore, at least 4 sectors must be present even though we don't
	use them.

*/

FILE_LICENCE ( GPL_ANY )

#define	SETUPSECS 4		/* Minimal nr of setup-sectors */
#define PREFIXSIZE ((SETUPSECS+1)*512)
#define PREFIXPGH (PREFIXSIZE / 16 )
#define	BOOTSEG  0x07C0		/* original address of boot-sector */
#define	INITSEG  0x9000		/* we move boot here - out of the way */
#define	SETUPSEG 0x9020		/* setup starts here */
#define SYSSEG   0x1000		/* system loaded at 0x10000 (65536). */

	.text
	.code16
	.arch i386
	.org	0
	.section ".prefix", "ax", @progbits
	.globl	_lkrn_start
_lkrn_start:

bootsector: 
_start:

/* some extra features */
#define EXE_SUPPORT		real mode dos .exe file support

#define EXEADRS(x)	(x+0xE0)

/* some contraints to reduce the size */
//#define FLOPPY_1440K_ONLY	1.44M floppies support only

#ifdef EXE_SUPPORT
/* Initial temporary stack size */
#define EXE_STACK_SIZE 0x400

/* Temporary decompression area (avoid DOS high memory area) */
#define EXE_DECOMPRESS_ADDRESS 0x110000

/* Fields within the Program Segment Prefix */
#define PSP_CMDLINE_LEN 0x80
#define PSP_CMDLINE_START 0x81

#define HEADER_SIZE	0x20

signature:
	decw	%bp			// Magic number: MZ
	popw	%dx
	jmp	start			// Bytes on last page of file
blocks:
	.word	0			// Pages in file
	.section ".zinfo.fixup", "a", @progbits /* Compressor fixups */
	.ascii	"ADDW"
	.long	blocks
	.long	512
	.long	0
	.previous
	.word	0			// Relocations
	.word	( HEADER_SIZE / 16 )	// Size of header in paragraphs
	.word	( EXE_STACK_SIZE / 16 )	// Minimum extra paragraphs needed
	.word	( EXE_STACK_SIZE / 16 )	// Maximum extra paragraphs needed
init_ss:
	.word	-( ( _exe_start - signature ) / 16 )	// Initial (relative) SS value
	.section ".zinfo.fixup", "a", @progbits /* Compressor fixups */
	.ascii	"ADDW"
	.long	init_ss
	.long	16
	.long	0
	.previous
	.word	EXE_STACK_SIZE		// Initial SP value
	.word	0			// Checksum
	.word	_exe_start		// Initial IP value
	/* Initial code segment (relative to start of executable) */
	.word	-( HEADER_SIZE / 16 )	// Initial (relative) CS value
//	.word	0x001C			// File address of relocation table
//	.word	0,0,0			// Overlay number
	.ascii	"(SliTaz)"

start:
	pushw	%dx
#endif
	cld				# assume nothing
stacktop	= 0x9E00		# in 0x8000 .. 0xA000
zeroed		= 12			# zeroed registers
	movw	$stacktop-12-zeroed, %di	# stacktop is an arbitrary value >=
					# length of bootsect + length of
					# setup + room for stack;
					# 12 is disk parm size.
	pushw	$INITSEG
	popw	%ss			# %ss contain INITSEG
	movw	%di, %sp		# put stack at INITSEG:stacktop-...

# Many BIOS's default disk parameter tables will not recognize
# multi-sector reads beyond the maximum sector number specified
# in the default diskette parameter tables - this may mean 7
# sectors in some cases.
#
# Since single sector reads are slow and out of the question,
# we must take care of this by creating new parameter tables
# (for the first disk) in RAM.  We can set the maximum sector
# count to 36 - the most we will encounter on an ED 2.88.  
#
# High doesn't hurt.  Low does.  Let's use the max: 63

	pushw	%ss
	popw	%es			# %es = %ss = INITSEG
	xorw	%ax, %ax		# %ax = 0
#ifdef EXE_SUPPORT
	cwd				# %dx = 0
#endif
	movw	$zeroed/2, %cx		# clear gdt + offset, %ds, limits
	rep				# don't worry about cld
	stosw				# already done above
	popw	%bx			# offset = 0
	popw	%ds			# %ds = 0
	popw	%fs			# %fs = 0

	movb	setup_sects+0x7C00, %al	# read bootsector + setup (%ds = 0)
	incw	%ax

	ldsw	0x78(%bx), %si		# %ds:%bx+0x78 is parameter table address
	pushw	%es
	pushw	%di
	movb	$6, %cl			# copy 12 bytes
	rep				# don't worry about cld
	movsw				# already done above
	pushw	%ss
	popw	%ds			# now %ds = %es = %ss = INITSEG
	popl	%fs:0x78(%bx)		# update parameter table address
	movb	$63, 0x4-12(%di)	# patch sector count, %di = stacktop
	cli

	xchg	%ax, %di		# sector count
	popw	%ax			# limits = 0
	incw	%cx			# cylinder 0, sector 1, clear Z
	call	read_first_sectors	# read setup

# This routine loads the system at address LOADSEG, making sure
# no 64kB boundaries are crossed. We try to load it as fast as
# possible, loading whole tracks whenever we can.

	popw	%bx			# clear %bx
	movw	syssize, %di
	addw	$(512/16)-1, %di
	shrw	$9-4, %di
	movw	$SYSSEG, %cx
	call	read_sectorsCX

# This procedure turns off the floppy drive motor, so
# that we enter the kernel in a known state, and
# don't have to worry about it later.

kill_motor:
	xchgw	%ax, %di		# reset FDC (%di < 128)
	int	$0x13

# After that (everything loaded), we jump to the setup-routine
# loaded directly after the bootblock:
# Segments are as follows: %ds = %ss = INITSEG

	ljmp	$SETUPSEG, $0

#ifdef EXE_SUPPORT
dosexit:
	movw	$0x4c00, %ax
	int	$0x21

_exe_start:
	pushw	$dosexit
	movw	$EXEADRS(need386), %si
	pushfw			// save flags
		// bits  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
		// flags  0 NT  IOPL OF DF IF TF SF ZF  0 AF  0 PF  1 CF
	movb	$0x10, %ah	// DF = IF = TF = 0
	pushw	%ax
	popfw			// < 286 : flags[12..15] are forced 1
	pushfw			// = 286 : flags[12..15] are forced 0
	popw	%cx		// > 286 : only flags[15] is forced 0
	popfw			// restore flags
	cmpb	%ah, %ch	// test Fx and 0x cases
	js	puts		// S= not 386+
//	smsww	%ax
//	andb	$1, %al
//	jne	puts

	/* Terminate command line with a NUL */
	movzbw	PSP_CMDLINE_LEN, %si
	movb	$0, PSP_CMDLINE_START(%si)
	cmpb	$'?', PSP_CMDLINE_START-1(%si)
	je	help
	pushw	%si

	/* Install iPXE.  Use a fixed temporary decompression area to
	 * avoid trashing the DOS high memory area.
	 */
	call	alloc_basemem
	movl	$EXE_DECOMPRESS_ADDRESS, %edi
	stc
	sbbl	%ebp, %ebp		/* Allow arbitrary relocation */
	xorl	%esi, %esi
	call	install_prealloc

	xorl	%ebp, %ebp
	xorl	%ecx, %ecx

	/* Calculate command line physical address */
	xorl	%edx, %edx
	movw	%ds, %dx
	shll	$4, %edx
	popw	%si
	orw	%si, %si
	jne	gotarg
	movw	$EXEADRS(default_config), %bp
	addl	%edx, %ebp
	movw	$0xA00-default_config, %cx
gotarg:
	addl	$PSP_CMDLINE_START, %edx
	
	jmp	start_ipxe

help:
	movw	$EXEADRS(helpmsg), %si
puts:
	lodsb
	orb	%al, %al
	je	exit
	call	putc
	jmp	puts
#endif

putcdot:
	movb	$0x2E, %al
putc:
	movb	$0xE, %ah
	movw	$7, %bx
	int	$0x10
exit:
	ret


# read_sectors reads %di sectors into %es:0 buffer.
# %es:0 is updated to the next memory location.
# First, sectors are read sector by sector until
# sector per track count is known. Then they are
# read track by track.
# Assume no error on first track.

#ifdef FLOPPY_1440K_ONLY
#define FLOPPY_HEADS		2	/* 2 heads */
#define FLOPPY_SECTORS		18	/* 18 sectors */
#else
#define FLOPPY_HEADS		2	/* 2 heads minimum */
#define FLOPPY_SECTORS		9	/* 9 sectors minimum */
#endif

check_limits:
#ifndef FLOPPY_1440K_ONLY
	popw	%dx
#ifdef FLOPPY_SECTORS
	cmpb	$FLOPPY_SECTORS+1, %cl	# minimum sector count
	jb	check_head
#endif
        cmpb    %al, %cl		# max sector known ?
        ja	next_head		#   no -> store it
check_head:
#ifdef FLOPPY_HEADS
	cmpb	$FLOPPY_HEADS, %dh	# 2 heads minimum
	jb	check_cylinder
#endif
        cmpb    %ah, %dh		# max head known ?
        ja	next_cylinder		#   no -> store it
check_cylinder:
#endif
	pushaw
#ifndef FLOPPY_1440K_ONLY
	cbw				# %ah = 0
#endif
        int     $0x13			# reset controler
	popaw
	movb	$1, %al			# sector by sector...
read_sectorslp:
	pushw	%dx			# some bios break dx...
#ifndef FLOPPY_1440K_ONLY
        pushw   %ax			# limits
	subb	%cl, %al		# sectors remaining in track
	ja	tolastsect
	movb	$1, %al			# 1 sector mini
tolastsect:
#else
	mov	$FLOPPY_SECTORS+1, %al
	subb	%cl, %al		# sectors remaining in track
#endif
	cbw
	cmpw	%di, %ax
	jb	more1trk
	movw	%di, %ax		# sectors to read
more1trk:
	pushw	%ax			# save context
	movb	$2, %ah			# cmd: read chs
        int     $0x13
#ifndef FLOPPY_1440K_ONLY
	popw	%dx			# save %ax
        popw    %ax			# limits
#else
	popw	%ax			# restore context
	popw	%dx
#endif
	jc	check_limits
#ifndef FLOPPY_1440K_ONLY
	xchgw	%ax, %bp
	addw	%dx,%cx			# next sector
	movw	%cx, %gs
	movw	%es, %cx
	pushw	%dx
	shlw	$5, %dx
	addw	%dx, %cx
	popw	%dx
	subw	%dx,%di			# update sector counter
	popw	%dx
read_sectorsCX:
	movw	%cx, %es		# next location
	jz	putcdot
#else
	addw	%ax,%cx			# next sector
	movw	%cx, %gs
	movw	%es, %cx
	pushw	%ax
	shlw	$5, %ax
	addw	%ax, %cx
	popw	%ax
	subw	%ax,%di			# update sector counter
read_sectorsCX:
	movw	%cx, %es		# next location
	jz	putcdot
#endif
read_sectors:
	movw	%gs, %cx
#ifndef FLOPPY_1440K_ONLY
#   al is last sector+1
#   ah is last cylinder+1
	xchgw	%ax, %bp
#endif
#ifndef FLOPPY_1440K_ONLY
        cmpb    %al,%cl			# reach sector limit ?
        jne     bdendlp
next_head:
        movb    %cl,%al
#else
        cmpb    $FLOPPY_SECTORS+1,%cl	# reach sector limit ?
        jne     bdendlp
#endif
        incb    %dh			# next head
        movb    $1,%cl			# first sector
#ifndef FLOPPY_1440K_ONLY
        cmpb    %ah, %dh		# reach head limit ?
        jne     bdendlp
next_cylinder:
        movb    %dh,%ah
#else
        cmpb    %cl,%dh			# reach head limit ?
        je	bdendlp
#endif
# NOTE : support 256 cylinders max
        incb    %ch			# next cylinder
        movb    $0,%dh			# first head
read_first_sectors:
bdendlp:
        jmp	read_sectorslp

#ifdef EXE_SUPPORT
need386:
	.ascii	"No 386+."
	.byte	13,10
	.byte	0
helpmsg:
	.ascii	"No help available."
	.byte	13,10
	.byte	0
#endif

/*
	The following header is documented in the Linux source code at
	Documentation/x86/boot.txt
*/
	.org	497
setup_sects: 
	.byte	SETUPSECS
root_flags: 
	.word	0
syssize: 
	.long	-PREFIXPGH

	.section ".zinfo.fixup", "a", @progbits	/* Compressor fixups */
	.ascii	"ADDL"
	.long	syssize
	.long	16
	.long	0
	.previous
	
ram_size: 
	.word	0
vid_mode: 
	.word	0
root_dev: 
	.word	0
boot_flag: 
	.word	0xAA55
jump:
	/* Manually specify a two-byte jmp instruction here rather
	 * than leaving it up to the assembler. */
	.byte	0xeb
	.byte	setup_code - header
header:
	.byte	'H', 'd', 'r', 'S'
version:
	.word	0x0207 /* 2.07 */
realmode_swtch:
	.long	0
start_sys:
	.word	0
kernel_version:
	.word	0
type_of_loader:
	.byte	0
loadflags:
	.byte	0
setup_move_size:
	.word	0
code32_start:
	.long	SYSSEG*16
ramdisk_image:
	.long	0
ramdisk_size:
	.long	0
bootsect_kludge:
	.long	0
heap_end_ptr:
	.word	0
pad1:
	.word	0
cmd_line_ptr:
	.long	0
initrd_addr_max:
	/* We don't use an initrd but some bootloaders (e.g. SYSLINUX) have
	 * been known to require this field.  Set the value to 2 GB.  This
	 * value is also used by the Linux kernel. */
	.long	0x7fffffff
kernel_alignment:
	.long	0
relocatable_kernel:
	.byte	0
pad2:
	.byte	0, 0, 0
cmdline_size:
	.long	0x7ff
hardware_subarch:
	.long	0
hardware_subarch_data:
	.byte	0, 0, 0, 0, 0, 0, 0, 0

/*
	We don't need to do too much setup.

	This code gets loaded at SETUPSEG:0.  It wants to start
	executing the image that's loaded at SYSSEG:0 and
	whose entry point is SYSSEG:0.
*/
setup_code:
	movl	ramdisk_image, %eax
	orl	%eax, %eax
	jnz	setup_done

	movw	$default_config, %di
	movw	$-1, %bx

	movw	$9, %cx
1:
	pushw	%ax
	loop	1b
	pushw	$0x9310
	pushw	%ax
	pushw	%bx
	pushw	%ax
	pushw	$0x9300+(INITSEG>>12)
	pushw	%di
	pushw	%bx
	movb	$8, %cl
1:
	pushw	%ax
	loop	1b
1:
	incw	%bx
	cmpb	%al, (%bx,%di)
	jne	1b
	movw	%bx, ramdisk_size
	movb	$0x10, ramdisk_image+2

	pushw	%ss
	popw	%es
	movw	%sp, %si
	movb	$0x87, %ah
	movw	$(run_ipxe-default_config)/2+1, %cx
	int	$0x15

setup_done:
	/* We expect to be contiguous in memory once loaded.  The Linux image
	 * boot process requires that setup code is loaded separately from
	 * "non-real code".  Since we don't need any information that's left
	 * in the prefix, it doesn't matter: we just have to ensure that
	 * %cs:0000 is where the start of the image *would* be.
	 */
	ljmp	$(SYSSEG-(PREFIXSIZE/16)), $run_ipxe

default_config:

	.org	PREFIXSIZE
/*
	We're now at the beginning of the kernel proper.
 */
run_ipxe:
	/* Set up stack just below 0x7c00 and clear direction flag */
	xorw	%ax, %ax
	movw	%ax, %ss
	movw	$0x7c00, %sp
	cld

	/* Retrieve command-line pointer */
	movl	%ds:cmd_line_ptr, %edx
	testl	%edx, %edx
	jz	no_cmd_line

	/* Set up %es:%di to point to command line */
	movl	%edx, %edi
	andl	$0xf, %edi
	rorl	$4, %edx
	movw	%dx, %es

	/* Find length of command line */
	pushw	%di
	movw	$0xffff, %cx
	repnz scasb
	notw	%cx
	popw	%si

	/* Make space for command line on stack */
	movw	%sp, %di
	subw	%cx, %di
	andw	$~0xf, %di
	movw	%di, %sp

	/* Copy command line to stack */
	pushw	%ds
	pushw	%es
	popw	%ds
	pushw	%ss
	popw	%es
	rep movsb
	popw	%ds

	/* Store new command-line pointer */
	movzwl	%sp, %edx
no_cmd_line:

	/* Calculate maximum relocation address */
	movl	ramdisk_image, %ebp
	testl	%ebp, %ebp
	jnz	1f
	decl	%ebp		/* Allow arbitrary relocation if no initrd */
1:

	/* Install iPXE */
	call	alloc_basemem
	xorl	%esi, %esi
	xorl	%edi, %edi
	call	install_prealloc

	/* Retrieve initrd pointer and size */
	movl	ramdisk_image, %ebp
	movl	ramdisk_size, %ecx

start_ipxe:
	/* Set up real-mode stack */
	movw	%bx, %ss
	movw	$_estack16, %sp

	/* Jump to .text16 segment */
	pushw	%ax
	pushw	$1f
	lret
	.section ".text16", "awx", @progbits
1:
	/* Set up %ds for access to .data16 */
	movw	%bx, %ds

	/* Store command-line pointer */
	movl	%edx, cmdline_phys

	/* Store initrd pointer and size */
	movl	%ebp, initrd_phys
	movl	%ecx, initrd_len

	/* Run iPXE */
	pushl	$main
	pushw	%cs
	call	prot_call
	popl	%ecx /* discard */

	/* Uninstall iPXE */
	call	uninstall

	/* Boot next device */
	int $0x18
