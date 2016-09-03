SYSSEG		= 0x1000
INITSEG		= 0x9000
SETUPSEG	= 0x9020

	.text
	.code16
	.org	0
	.globl	_start
_start:

#define CODESZ 512		/* patched by installer */

/* some extra features */
#define EXE_SUPPORT		real mode dos .exe file support
#define CMDLINE	0x9E00
#define HELP			store help message for /? argument
#define CHECK_REALMODE		does not support vm86
#define SHUTDOWNDOS		shutdown DOS services

/* some contraints to reduce the size */
//#define FLOPPY_1440K_ONLY	1.44M floppies support only
#define NO_CURSOR_DEFINITION

#ifdef EXE_SUPPORT
#define EXEADRS(x)	(x+0xE0)
stacktop	= 0x9E00		# in 0x8000 .. 0xA000
	decw	%bp			// Magic number: MZ
	popw	%dx
	jmp	start			// Bytes on last page of file
	.word	(CODESZ+511)/512	// Pages in file
	.word	0			// Relocations
	.word	(end_header-_start)/16	// Size of header in paragraphs
	.word	4096			// Minimum extra paragraphs needed
	.word	-1			// Maximum extra paragraphs needed
	.word	(CODESZ+15)/16		// Initial (relative) SS value
	.word	stacktop		// Initial SP value
	.word	0			// Checksum
	.word	EXEADRS(comstart)	// Initial IP value
	.word	0xFFF0			// Initial (relative) CS value
//	.word	0x001C			// File address of relocation table
//	.word	0,0,0			// Overlay number
	.ascii  "(SliTaz)"
end_header:
comstart:
	cld				# assume nothing
#ifdef CMDLINE
	movw	$stacktop, %di
#else
#undef HELP
#endif
	pushw	$INITSEG
	popw	%es
#ifdef CMDLINE
	movw	$0x80, %si
	lodsb
	cbw
	xchgw	%ax, %cx
	jcxz	nocmdline
	movw	$0xA33F, 0x7F(%si)
skipspace:
	lodsb
	cmpb	$0x20, %al
	je	skipspace
	decw	%si
	rep
	  movsb
# ifdef HELP
# define PUTS
	movw	$EXEADRS(helpmsg), %si
	cmpb	$'/'+1, %al
#  ifdef CHECK_REALMODE
	js	jsputs
#  else
	js	puts
#  endif
# endif
nocmdline:
#endif
	movw	$SYSSEG, %ax
#ifdef CHECK_REALMODE
#define PUTS
	movw	$EXEADRS(realmode_expected), %si
		// bits  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
		// flags  0 NT  IOPL OF DF IF TF SF ZF  0 AF  0 PF  1 CF
	//movb	$0x10, %ah	// DF = IF = TF = 0
	pushw	%ax
	popfw			// < 286 : flags[12..15] are forced 1
	pushfw			// = 286 : flags[12..15] are forced 0
	popw	%dx		// > 286 : only flags[15] is forced 0
	cmpb	%ah, %dh	// test Fx and 0x cases
jsputs:
	js	puts		// S= not 386+
	smsww	%dx
	shrw	$1, %dx
	jc	puts
	//movw	syssize-realmode_expected(%si), %bp
	.byte	0x8B, 0x6C, syssize-realmode_expected
	//movb	setup_sects-realmode_expected(%si), %ch
	.byte	0x8A, 0x6C, setup_sects-realmode_expected
#else
	movw	EXEADRS(syssize), %bp
	movb	EXEADRS(setup_sects), %ch
#endif
	movb	$(512-(end_header-_start))/2, %cl
	movw	$0x100, %si
	movw	$end_header, %di
	rep
	  movsw
#ifndef SHUTDOWNDOS
	ljmp	$INITSEG, $movesys
#else
	pushaw
	pushw	%es
	xorw	%si, %si
	movw	%si, %ds		# %ds = 0
	pushl	4(%si)
	movw	%sp, %es:loadsp19+1(%si)
	movw	$step19, 4(%si)
	movw	%es, 6(%si)
	pushfw
	popw	%ax
	incb	%ah			# set TF
	pushw	%ax
	popfw
	ljmp	*4*0x19(%si)
#endif
start:
	pushw	%dx
#else
#undef HELP
#undef CMDLINE
#undef CHECK_REALMODE
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
	decw	%di
	shrw	$9-4, %di
	incw	%di
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

jmp_setup:
	ljmp	$SETUPSEG, $0

#ifdef PUTS
#define PUTC
putslp:
	call	putc
puts:
	lodsb
	orb	%al, %al
	jne	putslp	
	int	$0x20			// dos exit
#endif
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
	mov	%si, %ds
	popl	4*0x19(%si)
loadsp19:
	movw	$0, %sp
	popl	4(%si)
	popw	%es
	popaw
#endif
movesys:				// %ax = SYSSEG
	pushw	%es
	popw	%ss
	movw	%ds, %bx
	shrw	$4, %si
	addw	%si, %bx
	subw	%ax, %bx
	jnc	forward
	addw	%bp, %ax
forward:
	movw	%ax, %es
	movw	%ax, %dx
	addw	%bx, %dx
	movw	%dx, %ds
	sbbw	%dx, %dx		// %dx = 0 : -1
	cmc				//  C  = 1 :  0
	adcw	%dx, %ax
	xorw	%si, %si
	xorw	%di, %di
	movb	$8, %cl
	rep
	  movsw
	decw	%bp
	jns	forward
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
putcdot:
#ifdef PUTC
	movb	$0x2E, %al
putc:
	movb	$0xE, %ah
	movw	$7, %bx
	int	$0x10
#endif
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

#ifdef HELP
helpmsg:
	.ascii	"No help available."
	.byte	13,10
	.byte	0
#endif
#ifdef CHECK_REALMODE
	.org	475
realmode_expected:
helpend:
	.ascii	"386 real mode only."
	.byte	13,10,0
#endif
	.org	497
setup_sects:
	.byte	0
	.org	500
syssize:
	.word	0

