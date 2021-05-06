// Image/zImage & tiny bzImage linux kernel boot sector, (C) SliTaz, GPL2.

SYSSEG		= 0x1000
setup_sects	= 497
syssize		= 500
cmd_line_ptr	= 0x228

	.text
	.code16
	.org	0
	.globl	_start
_start:

#define CODESZ 512		/* patched by installer */

// Default kernel format is 386 Image/zImage
#define BZIMAGE 0x207		/* setup version ; for bzImage < 512 Kb only */
//#define ELKS			/* 8086/286 linux port */

/* some extra features */
#define EXE_SUPPORT		real mode dos .exe file support	+208/264
#define  CMDLINE		dos kernel cmdline support	+45
#define  VCPI			VCPI 4.0 support (386+)		+109
#define  SHUTDOWNDOS		shutdown DOS services		+29

/* some contraints to reduce the code size */
//#define FLOPPY_1440K_ONLY	1.44M floppies support only	-26
//#define FLOPPY_HAS_2_SIDES	hardcoded heads count to 2	-15
//#define NO_CMDLINE_SHRINK	remove heading spaces ?		-6-21
//#define  NO_CMDLINE_FILE	remove @cmdline file support ?	-21
//#define NO_DOTS		show progression dots ?		-5
#ifndef BZIMAGE
//#define TINY_ZIMAGE		system < 64Kb ?			-11
//#define NO_MINSETUP		default setup (dos only) ?	-4
//#define NO_CURSOR_DEFINITION					-8
#endif

#ifdef ELKS
	.arch	i8086
INITSEG		= 0x0100
SETUPSEG	= 0x0120
#define ONLY8086
#undef BZIMAGE
#undef VCPI
#else
INITSEG		= 0x9000
SETUPSEG	= 0x9020
#endif

.macro	shlclw cnt,obj
#ifdef ONLY8086
	movb	\cnt,%cl
	shlw	%cl,\obj
#else
	shlw	\cnt,\obj
#endif
.endm

.macro	shrclw cnt,obj
#ifdef ONLY8086
	movb	\cnt,%cl
	shrw	%cl,\obj
#else
	shrw	\cnt,\obj
#endif
.endm

#ifdef EXE_SUPPORT
#define EXEADRS(x)	(x+0xE0)
#define FLAT20(x)	(x+16*INITSEG)

.macro	trace_int19
#ifdef ONLY8086
	xorw	%si, %si
	movw	%si, %ds
	pushw	4+2(%si)
	pushw	4(%si)
	movw	$step19, 4(%si)
	movw	$INITSEG, 4+2(%si)
#else
	pushl	$4
	popw	%si
	popw	%ds
	pushl	(%si)
	movl	$step19+(INITSEG<<16), (%si)
#endif
	pushfw
	popw	%ax
	incb	%ah			# set TF
	pushw	%ax
	popfw
	ljmp	*4*0x19-4(%si)
.endm

stacktop	= 0x9E00		# in 0x8000 .. 0xA000
	decw	%bp			// Magic number: MZ
	popw	%dx
	jmp	start			// Bytes on last page of file
	.word	(CODESZ+511)/512	// Pages in file			INSTALLER
	.word	0			// Relocations
	.word	(end_header-_start)/16	// Size of header in paragraphs
	.word	4096			// Minimum extra paragraphs needed
	.word	-1			// Maximum extra paragraphs needed
	.word	(CODESZ+15)/16		// Initial (relative) SS value		INSTALLER
	.word	stacktop		// Initial SP value
	.word	0			// Checksum				INSTALLER?
	.word	EXEADRS(comstart)	// Initial IP value
	.word	0xFFF0			// Initial (relative) CS value
//	.word	0x001C			// File address of relocation table
//	.word	0,0,0			// Overlay number
#else
#undef VCPI
#endif
start:
	xorw	%ax, %ax		# %ax = 0
zeroed		= 12			# zeroed registers
	movw	$zeroed/2, %cx		# clear gdt + offset, %ds, limits
stacktop	= 0x9E00		# in 0x8000 .. 0xA000 (+zeroed+12)
#ifdef ONLY8086
	movw	$INITSEG, %bx
#else
	pushw	$INITSEG
#endif
end_header:
	cld				# assume nothing
#if defined(BZIMAGE) && BZIMAGE >= 0x202
	popw	%es			# %es contain INITSEG
	movw	%es, %di
#else
					# cmdline offset at 0x22
	movw	$stacktop, %di		# stacktop is an arbitrary value >=
					# length of bootsect + length of
					# setup + room for stack;
					# 12 is disk parm size.
# ifdef ONLY8086
	pushw	%bx
# endif
	popw	%es			# %es contain INITSEG
#endif
	pushw	%es
	popw	%ss			# %es = %ss = INITSEG
	movw	%di, %sp		# put stack at INITSEG:stacktop-...
#ifdef EXE_SUPPORT
	cwd				# force %dx = 0 (floppy only)
#endif

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

	rep				# don't worry about cld
	stosw				# already done above
	popw	%bx			# offset = 0
	popw	%ds			# %ds = 0

	movb	setup_sects+0x7C00, %al	# read bootsector + setup (%ds = 0)
	incw	%ax

	ldsw	0x78(%bx), %si		# %ds:%bx+0x78 is parameter table address
	pushw	%es
	pushw	%di
	movb	$6, %cl			# copy 12 bytes
	rep				# don't worry about cld
	movsw				# already done above
	movw	%cx, %ds		# %ds = 0
#ifdef ONLY8086
	popw	0x78(%bx)		# update parameter table address
	popw	0x78+2(%bx)
#else
	popl	0x78(%bx)		# update parameter table address
#endif
	pushw	%ss
	popw	%ds			# now %ds = %es = %ss = INITSEG
	movb	$63, 0x4-12(%di)	# patch sector count, %di = stacktop

	xchg	%ax, %di		# sector count
	popw	%ax			# limits = 0
	incw	%cx			# cylinder 0, sector 1, clear Z
	call	read_first_sectors	# read setup

# This routine loads the system at address LOADSEG, making sure
# no 64kB boundaries are crossed. We try to load it as fast as
# possible, loading whole tracks whenever we can.

	movw	syssize, %di
	decw	%di
	shrclw	$9-4, %di
	incw	%di
	movw	$SYSSEG, %cx
#ifdef BZIMAGE
	push	%cx
#endif
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

#ifdef BZIMAGE
	popw	%bx
	popw	%si			// SYSSEG:0
movesys:				// %bx = DS, %si
	movw	$16, %ax
	mulw	%bx
	addw	%si, %ax
	adcw	$0x9300, %dx		// %dx:%ax src flat address
	movw	$9, %cx
zero1:
	pushw	$0			// 2E..1E
	loop	zero1
	//pushl	$0x93100000		// 1A: dest
	pushw	$0x9310
	pushw	%cx
	pushw	$-1			// 18
	pushw	%cx			// 16
	pushw	%dx			// src
	pushw	%ax
	pushw	$-1			// 10
	movb	$8, %cl
	movw	%cx, %bx		// will move 8*64 = 512Kb
zero2:
	pushw	$0			// 0E..00
	loop	zero2
	movw	%sp, %si
	pushw	%ss
	popw	%es
	pushw	%es
	popw	%ds
syslp:
	movb	$0x80, %ch	
	movb	$0x87, %ah
	int	$0x15
	incb	0x14(%si)
	incb	0x1C(%si)
	decw	%bx
	jne	syslp
#endif
jmp_setup:
	cli
	ljmp	$SETUPSEG, $0

#ifdef EXE_SUPPORT
#ifdef SHUTDOWNDOS
doiret:
	iret
step19:
	pushw	%si
	pushw	%ds
	movw	%sp, %si
	ldsw	%ss:4(%si), %si
	cmpw	$0x19CD, (%si)
	popw    %ds
	popw    %si
	jne	doiret
	xorw	%si, %si
	movw	%si, %ds
	pushw	%cs
	popw	%ss
	movw	$stacktop-4-16, %sp
#ifdef ONLY8086
	popw	4(%si)
	popw	4+2(%si)
	popw	%bp
	popw	%di
	popw	%si
	popw	%dx
	popw	%cx
	popw	%bx
	popw	%ax
#else
	popl	4(%si)
	popaw
#endif
#ifdef BZIMAGE
	jmp	movesys
#endif
#endif
#ifndef BZIMAGE
movesys:				// %ax = SYSSEG, %bx = DS, %si
	shrclw	$4, %si
	addw	%si, %bx
#ifdef TINY_ZIMAGE
	movw	$0xFFFF, %cx
	xorw	%si, %si
	xorw	%di, %di
	cmpw	%ax, %bx
	jnc	forward
	decw	%si
	decw	%di
	std
forward:
	movw	%ax, %es
	movw	%bx, %ds
	rep
	  movsb
	cld
#else
	subw	%ax, %bx
	jnc	forward
	//movw	$0x8FFF, %ax
	movb	$0x90, %ah
forward:
	movw	%ax, %es
	movw	%ax, %di
	addw	%bx, %di
	movw	%di, %ds
	sbbw	%di, %di		// %di = 0 : -1
	cmc				//  C  = 1 :  0
	adcw	%di, %ax
	xorw	%si, %si
	xorw	%di, %di
	movb	$0x10, %cl
	cmpb	%cl, %ah		// move 512k
	rep
	  movsb
	jns	forward
#endif
#ifndef NO_CURSOR_DEFINITION
	movb	$1, %ah
	movb	$0, %bh
	movb	$0x20, %ch	// 0x2000
	int	$0x10
#endif
	pushw	%ss
	popw	%ds
	jmp	jmp_setup
#endif
comstart:
	cld				# assume nothing
#ifdef ONLY8086
	movw	$INITSEG, %ax
	pushw	%ax
#else
	pushw	$INITSEG
#endif
	popw	%es
#ifdef CMDLINE
	movw	%sp, %di
	movw	$0x80, %si
	lodsb
	cbw
	xchgw	%ax, %cx
	jcxz	nocmdline
# if defined(BZIMAGE) && BZIMAGE >= 0x202
	movw	$INITSEG/16+stacktop/256, EXEADRS(cmd_line_ptr+1)
# else
	movw	$0xA33F, 0x7F(%si)
# endif
# ifndef NO_CMDLINE_SHRINK
skipspace:
	lodsb
	cmpb	$0x20, %al
	je	skipspace
#  ifndef NO_CMDLINE_FILE
	movw	%si,%dx
	decw	%si
	subb	$'@',%al
	jne	notafile
	movb	$0x3D,%ah
	int	$0x21
	jc	notafile
	xchgw	%ax,%bx
	//movw	%si,%dx		// ~320 bytes max
	movw	$EXEADRS(notafile)-130,%cx
	movb	$0x3F,%ah
	int	$0x21
	xchgw	%ax,%cx
notafile:
#  else
	decw	%si
#  endif
# endif
	rep
	  movsb
nocmdline:
	orb	EXEADRS(setup_sects), %ch
# ifndef NO_MINSETUP
#  ifndef BZIMAGE
	jnz	setupok
	mov	$4, %ch
setupok:
#  endif
# endif
#else
	movb	EXEADRS(setup_sects), %ch
#endif
	movb	$(512-(end_header-_start))/2, %cl
	movw	$0x100, %si
	movw	$end_header, %di
	rep
	  movsw
	movw	$SYSSEG, %ax
	movw	%ds, %bx
	pushw	%es
	popw	%ss
#ifndef SHUTDOWNDOS
	pushw	%es
	pushw	$movesys
#endif
#ifdef VCPI
	pushaw
	smsww	%ax
	andb	$1, %al
	je	isrm
	movw	$EXEADRS(gdt_vcpi),%si
	movw	$pagebuf-0x90000,%di	// %es = 0x9000
	movl	$pagebuf+3,%es:0x1000(%di)
call_vcpi:
	movb	$0xDE,%ah	// DE01, EBX = getiface(DS:SI, ES:DI)
	int	$0x67
	movl	$FLAT20(sw2pm_params),%esi
	movb	$0x0C,%al	// DE0C switchpm(ESI)
	jmp	call_vcpi
pm_code:
	movl	%cr0,%eax
	andl	$0x7FFFFFFE,%eax
	movl	%eax,%cr0
	movl	%eax,%cr3
isrm:
# ifdef SHUTDOWNDOS
	trace_int19
# else
	lssw	%cs:EXEADRS(saved_ss_sp),%sp	
	popaw
	retf
# endif
#else
# ifdef SHUTDOWNDOS
#  ifdef ONLY8086
	pushw	%ax
	pushw	%bx
	pushw	%cx
	pushw	%dx
	pushw	%si
	pushw	%di
	pushw	%bp
#  else
	pushaw
#  endif
	trace_int19
# endif
	retf
#endif
#endif

# read_sectors reads %di sectors into %es:0 buffer.
# %es:0 is updated to the next memory location.
# First, sectors are read sector by sector until
# sector per track count is known. Then they are
# read track by track.
# Assume no error on first track.

#ifdef FLOPPY_1440K_ONLY
#ifndef FLOPPY_HAS_2_SIDES
#define FLOPPY_HAS_2_SIDES	hardcore heads count to 2
#endif
#define FLOPPY_SECTORS		18	/* 18 sectors */
#else
#define FLOPPY_HEADS		2	/* 2 heads minimum */
#endif

return:
#ifndef NO_DOTS
	movw	$0xE2E,%ax
	int	$0x10
#endif
	ret

check_limits:
#ifndef FLOPPY_1440K_ONLY
	popw	%dx
        cmpb    %al, %cl		# max sector known ?
        ja	next_head		#   no -> store it
#ifndef FLOPPY_HAS_2_SIDES
#ifdef FLOPPY_HEADS
	cmpb	$FLOPPY_HEADS, %dh	# 2 heads minimum
	jb	check_cylinder
#endif
        cmpb    %ah, %dh		# max head known ?
        ja	next_cylinder		#   no -> store it
check_cylinder:
#endif
	pushw	%ax
	cbw				# %ah = 0
#else
	pushw	%dx
#endif
        int     $0x13			# reset controler
#ifndef FLOPPY_1440K_ONLY
	popw	%ax
	movb	$1, %al			# sector by sector...
#else
	movw	$1, %ax
	jmp	more1trk
#endif
read_sectorslp:
	pushw	%dx			# some bios break dx...
#ifndef FLOPPY_1440K_ONLY
        pushw   %ax			# limits
	subb	%cl, %al		# sectors remaining in track
	ja	tolastsect
	movb	$1, %al			# first track sector by sector
tolastsect:
#else
	movb	$FLOPPY_SECTORS+1, %al
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
	movw	%cx, %si
	pushw	%dx
	shlclw	$5, %dx
	movw	%es, %cx
	addw	%dx, %cx
	popw	%dx
	subw	%dx,%di			# update sector counter
	popw	%dx
#else
	addw	%ax,%cx			# next sector
	movw	%cx, %si
	pushw	%ax
	shlclw	$5, %ax
	movw	%es, %cx
	addw	%ax, %cx
	popw	%ax
	subw	%ax,%di			# update sector counter
#endif
read_sectorsCX:
	movw	%cx, %es		# next location
	jz	return
read_sectors:
	movw	%si, %cx
#ifndef FLOPPY_1440K_ONLY
#   al is last sector+1
#   ah is last head+1
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
        movb    $1,%cl			# first sector
#ifndef FLOPPY_HAS_2_SIDES
        incb    %dh			# next head
        cmpb    %ah, %dh		# reach head limit ?
        jne     bdendlp
next_cylinder:
        movb    %dh,%ah
        movb    $0,%dh			# first head
#else
        xorb    %cl,%dh			# next head
        jne	bdendlp			# reach head limit ?
#endif
# NOTE : support 256 cylinders max
        incb    %ch			# next cylinder
read_first_sectors:
bdendlp:
        jmp	read_sectorslp

#ifdef VCPI
pagebuf		=	0x98000
tss		=	gdt_abs-40
gdt		=	gdt_abs-32
gdt_null	=	gdt_abs-32
gdt_vcpi	=	gdt_abs-24
gdt_vcpi2	=	gdt_abs-16
gdt_vcpi3	=	gdt_abs-8
gdt_abs:
	.word	0xFFFF
	.long	0x92000000
	.byte	0xCF,0
gdt_code:
	.word	0xFFFF
gdt_code_base:
	.long	0x9A000000+FLAT20(0)
	.byte	0x8F,0
gdt_tss:
	.word	0x00FF
gdt_tss_base:
	.long	0x89000000+FLAT20(tss)
	.byte	0,0
gdtr:
gdt_lim:
	.word	0xFFFF
gdt_base:
	.long	FLAT20(gdt)
sw2pm_params:
sw2pm_cr3:
	.long	pagebuf+0x1000
sw2pm_gdtr_ptr:
	.long	FLAT20(gdtr)
sw2pm_idtr_ptr:
	.long	FLAT20(idtr)
sw2pm_ldtr:
	.word	0
sw2pm_tr:
SEL_TSS		= gdt_tss-gdt_null
	.word	SEL_TSS
sw2pm_jumpaddr:
	.long	pm_code
SEL_CODE	= gdt_code-gdt_null
	.word	SEL_CODE
idtr:
idt_lim:
	.word	0x03FF
idt_base:
	.long	0
# ifndef SHUTDOWNDOS
saved_ss_sp:
	.word	stacktop-4-16-4,INITSEG
# endif
#endif
#ifdef ELKS
	.org	0x1E3
	.byte	13,10,7
	.asciz	"ELKS Boot"
#endif
