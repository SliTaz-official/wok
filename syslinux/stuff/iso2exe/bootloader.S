BOOTSEG		= 0x07C0		/* original address of boot-sector */
SYSSEG		= 0x1000		/* historical load address >> 4 */
INITSEG		= 0x9000		/* boot address >> 4 */
SETUPSEG	= 0x9020		/* setup address >> 4 */
ASK_VGA		= -3

#ifndef SVGA_MODE
#define SVGA_MODE ASK_VGA
#endif

#ifndef RAMDISK
#define RAMDISK 0
#endif

#ifndef ROOT_RDONLY
#define ROOT_RDONLY 1
#endif

/* some extra features */
#define CMDLINE			kernel >= 2.4
#define OLDCMDLINE		kernel  < 2.4
#define MORETHAN16M		up to 4Gb RAM, not 16Mb
#define KEYBOARDLESS_SUPPORT	scan floppy swap each 5 seconds

#define EDIT_CMDLINE
#define	CMDLINE_SUPPORT
#define MOVE_CMDLINE
#define INITRD_SUPPORT
#define INITRD_AUTOADDR
#ifndef MULTI_INITRD
#define README_SUPPORT
#define COUNTER
#endif

	.code16
	.org	0

bootsect_start:

cur_initrd_size_ofs	= 494
ramdisk_image_ofs	= 0x218
ramdisk_image	=	bootsect_start+ramdisk_image_ofs
ramdisk_size_ofs	= 0x21C
ramdisk_size	=	bootsect_start+ramdisk_size_ofs
cmd_line_ptr_ofs	= 0x228
cmd_line_ptr	=	bootsect_start+cmd_line_ptr_ofs
setup_sects	=	bootsect_start+497
syssize		=	bootsect_start+500
boot_flag_ofs	= 510
boot_flag	=	bootsect_start+boot_flag_ofs


stacktop	= 0x9E00		# in 0x8000 .. 0xA000
zeroed		= 48+10			# gdt + zeroed registers
.macro	INIT_REGS
	movw	$stacktop-zeroed, %di	# stacktop is an arbitrary value >=
					# length of bootsect + length of
					# setup + room for stack;
					# 12 is disk parm size.
	pushw	$INITSEG
	popw	%ss			# %ss contain INITSEG
	movw	%di, %sp		# put stack at INITSEG:stacktop-...
	pushw	%ss
	popw	%es			# %es = %ss = INITSEG
	xorw	%ax, %ax		# %ax = 0
#if defined(CMDLINE)
	movw	$zeroed+1, %cx		# clear gdt + offset, %ds, limits, cmdline=""
	rep				# don't worry about cld
	stosb				# already done above
	//decw	%di
#else
	movw	$zeroed/2, %cx		# clear gdt + offset, %ds, limits
	rep				# don't worry about cld
	stosw				# already done above
#endif
	popw	%bx			# offset = 0
.endm

LOADSEG		= 0x8000		# 0x1000 multiple, up to 512K zImage
LOADSZ		= 0x10000

# bootsect_start:
	INIT_REGS
	popw	%ds			# %ds = 0
	movb	setup_sects+0x7C00, %al	# read bootsector + setup
	incw	%ax			# %ax = setup_sects+bootsect
	popw	%fs			# %fs = 0

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

	cli
	ldsw	0x78(%bx), %si		# %ds:%bx+0x78 is parameter table address
	popw	%di
	pushw	%es
	pushw	%di
#ifdef	CMDLINE_SUPPORT
	movw	$0, %bp			# patched by installer (7C22)
skipcmdline:
#define cmd_line_ptr	0x22
#endif
	movb	$6, %cl			# copy 12 bytes
	rep				# don't worry about cld
	  movsw				# already done above
	pushw	%ss
	popw	%ds			# now %ds = %es = %ss = INITSEG
	popl	%fs:0x78(%bx)		# update parameter table address
	movb	$63, 0x4-12(%di)	# patch sector count, %di = stacktop

	xchg	%ax, %di		# sector count
	popw	%ax			# limits = 0
	incw	%cx			# cylinder 0, sector 1, clear Z
	call	read_first_sectors	# read setup
#ifdef	README_SUPPORT
	xorw	%si, %si
	orw	readme, %si
	jz	readmeend
readmeloop:
	call	puts
	jz	readmeend
	call	wait4key
	cmpb	$27, %al
	jne	readmeloop
readmeend:
#endif
loadsys:
	movw	$0x200,%si
type_of_loader	=	0x10
loadflags	=	0x11
heap_end_ptr	=	0x24
	orw	$0x8020, type_of_loader(%si) # loader type = 0x20 = bootsect-loader
	movb	$(stacktop-0x300)/256, heap_end_ptr+1(%si)
	call	puts_version		# show which kernel we are loading

#ifdef	CMDLINE_SUPPORT
# The cmdline can be entered and modifed at boot time.
# Only characters before the cursor are passed to the kernel.

	xorw	%si, %si
	orw	(%bx), %si
	jz	nocmdline
#ifdef OLDCMDLINE
	movw	$0xA33F, -2(%bx)
#endif
	call	puts
#ifdef	EDIT_CMDLINE
cmdlp:
	movb	$0x20, %al		# clear end of line
cmdlpz:
	call	putc			#  with Space
	subb	$0x18, %al		#   and BackSpace
	jnc	cmdlpz
	decw	%si
cmdget:
#ifdef KEYBOARDLESS_SUPPORT
	call	wait4key
#else
	int	$0x16
	cbw				# %ah = 0, get keyboard character
#endif
	cmpb	$8, %al			# BackSpace ?
	je	cmdbs
	movb	%al, (%si)		# store char
	lodsw				# %si += 2
cmdbs:
	cmpw	%si, (%bx)
	je	cmdget
	call	putc
	cmpb	$10, %al		# Enter/linefeed ?
	jne	cmdlp
	movb	%bh,-2(%si)		# set end of string and remove CR
endcmdline:
#endif
#ifdef MOVE_CMDLINE
	pushw	%ss
	popw	%es
	movw	$0x8000, %di
	movw	%di, %si
	xchgw	%si, (%bx)
	movb	$0x2, %ch
	rep
	  movsb
#endif
nocmdline:
#endif

# This routine loads the system at address LOADSEG, making sure
# no 64kB boundaries are crossed. We try to load it as fast as
# possible, loading whole tracks whenever we can.

.macro	autoaddr base
#ifdef INITRD_AUTOADDR
	movb	$0x88, %ah
	int	$0x15
	//jc	NeedMoreRAM			# error code 80 or 86
	cmpw	$0xB000, %ax			# more than 45M ?
	jb	NeedMoreRAM
	movb	%ch, bootsect_dst_base_hi(%si)	# initramfs @ 32M
	movb	%ch, ramdisk_image_ofs+3-\base
NeedMoreRAM:
#endif
.endm

bootsect_src_limit	= 16
bootsect_dst_limit	= 24
bootsect_src_base	= 18
bootsect_dst_base	= 26		# bits  0..23
bootsect_dst_base_hi	= 31		# bits 24..31
	popw	%bx			# clear %bx
	movw	%sp, %si		# for bootsect_gdt
init_gdt:
	decw	bootsect_src_limit(%bx,%si)	# max 64Kb
	movw	$0x9300+(LOADSEG/0x1000), bootsect_src_base+2(%bx,%si)
	xorb	$bootsect_dst_limit-bootsect_src_limit, %bl
	jne	init_gdt
#ifdef INITRD_SUPPORT
	movw	$syssize, %bx
	movb	$5, %cl
code32_start	=	0x214
	movw	code32_start+1, %ax		# destination = 0x00100000 or 0x00010000
initrdlp:
	movl	(%bx), %ebx
	decl	%ebx
	shrl	%cl, %ebx
#else
code32_start	=	0x214
	movw	code32_start+1, %ax		# destination = 0x00100000 or 0x00010000
	movl	syssize, %ebx
	decl	%ebx
	shrl	$5, %ebx
#endif
#ifdef MORETHAN16M
	incl	%ebx
#else
	incw	%bx
#endif
syslp:
	movw	%ax, bootsect_dst_base+1(%si)
#ifdef MORETHAN16M
	movl	$LOADSZ/512, %edi	# size in sectors
	subl	%edi, %ebx
#else
	movw	$LOADSZ/512, %di	# size in sectors
	subw	%di, %bx
#endif
	pushf
	jnc	not_last
	addw	%bx, %di
not_last:
#ifdef MULTI_INITRD
	pushw	%di
#endif
	pushw	%ax
	pushw	%bx
	pushw	%si
	xorw	%bx,%bx
	pushw	$LOADSEG
	popw	%es
patchcall:
	call	read_sectors		# update %bp
	popw	%si
	popw	%bx
	movw	%es, %cx		# word count = LOADSZ/2 (= LOADSEG)
	movb	$0x87, %ah
	pushw	%ss
	popw	%es			# restore es
	int	$0x15			# max 16M, maybe more...
	popw	%ax
#ifdef MULTI_INITRD
	popw	%di
	shlw	$1,%di			# sectors to pages
	addw	%di, %ax
#ifdef MORETHAN16M
	adcb	%cl, bootsect_dst_base_hi(%si)	# breaks 16M limit ?
#endif
#else
#ifdef MORETHAN16M
	addw	$0x100, %ax		# next dest (ax+=LOADSZ/256)
	adcb	%cl, bootsect_dst_base_hi(%si)	# breaks 16M limit ?
#else
	incb	%ah			# next dest (ax+=LOADSZ/256)
#endif
#endif
	popf
	ja	syslp
#ifdef INITRD_SUPPORT
initrdlp2:
#ifdef INITRD_AUTOADDR
	movw	$0x209, %cx
#else
	movb	$9, %cl
#endif
#ifdef MULTI_INITRD
	movw	$cur_initrd_size_ofs, %di
	movw	(%di), %bx
	addw	$4, (%di)
	shrw	%cl, boot_flag_ofs-cur_initrd_size_ofs(%di)
	je	nextInitrd	
	orw	%bx, %bx
	je	bootit			# no initrd
	autoaddr	cur_initrd_size_ofs(%di)
	movw	ramdisk_image+1,%ax
	jmp	initrdlp
nextInitrd:
	pushw	%bx
	movl	-4(%bx), %ebx
	addl	%ebx, ramdisk_size_ofs-cur_initrd_size_ofs(%di)
	movb	$swap_floppy2-0x100, %cs:dpy_swap_floppy-2+0x7C00
	popw	%bx
	cmpb	2(%di), %bl
	jb	initrdlp
#else
	movw	$ramdisk_size, %bx
#ifdef MORETHAN16M
	cmpb	%cl, ramdisk_image+2-ramdisk_size(%bx)
	jb	bootit
	autoaddr	ramdisk_size_ofs(%bx)
	movw	ramdisk_image+1,%ax
	shrw	%cl, boot_flag-ramdisk_size(%bx)
	jne	initrdlp
#else
	movw	ramdisk_image+1,%ax
	cmpw	%ax, bootsect_dst_base+1(%si)
	jb	initrdlp
#endif
#endif
#endif
bootit:
#ifdef MULTI_INITRD
        jcxz	read_sectorslp
#endif

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

# read_sectors reads %di sectors into %es:0 buffer.
# %es:0 is updated to the next memory location.
# First, sectors are read sector by sector until
# sector per track count is known. Then they are
# read track by track.
# Assume no error on first track.

#define FLOPPY_CYLINDERS	80	
#define FLOPPY_HEADS		2	

.macro	putsmsg
#ifdef COUNTER
	movw	$msgdigit+1-msg, %bx
nextdigit:
	andb	$0xF0, (%bx,%si)
	decw	%bx
	incb	(%bx,%si)
	cmpb	$'9', (%bx,%si)
	ja	nextdigit
#endif
	call	puts
.endm

check_limits:
	popw	%dx
        cmpb    %cl, %al		# max sector known ?
        jbe	next_head		#   no -> store it
	#.byte	0xd6	# SALC		# sector by sector
	movb	$0, %al			# sector by sector
	pushaw
        int     $0x13			# reset controler
	stc
	call	putcdot			# print '-'
read_sectorslp:
	popaw
bdendlp:
	pushw	%dx			# some bios break dx...
        pushw   %ax			# limits
	subb	%cl, %al		# sectors remaining in track
	ja	tolastsect
	movb	$1, %al			# 1 sector mini
tolastsect:
	cmpw	%di, %ax
	jb	more1trk
	movw	%di, %ax		# sectors to read
more1trk:
	pushw	%ax			# save context
	movb	$2, %ah			# cmd: read chs
        int     $0x13
	popw	%dx			# save %ax
        popw    %ax			# limits
	jc	check_limits
	xchgw	%ax, %bp
	addw	%dx,%cx			# next sector
	movw	%cx, %gs
	addb	%dl,%bh
	addb	%dl,%bh			# next location
	subw	%dx,%di			# update sector counter
	popw	%dx
	jz	putcdot
read_sectors:
	movw	%gs, %cx
#   al is last sector+1
#   ah is 0
	xchgw	%ax, %bp
        cmpb    %al,%cl			# reach sector limit ?
        jne     bdendlp
next_head:
        movb    %cl,%al
        movb    $1, %cl			# first sector
inc_head:
        xorb    %cl, %dh		# next head
        jne	bdendlp			# reach head limit ?
        incb    %ch			# next cylinder
read_first_sectors:
        cmpb    $FLOPPY_CYLINDERS,%ch	# reach cylinder limit ?
        jne	bdendlp
next_floppy:
	movb	$0,%ch			# first cylinder
	pushaw
	movw	$swap_floppy,%si
dpy_swap_floppy:
#ifdef KEYBOARDLESS_SUPPORT
	pushw	%bx
	putsmsg
	popw	%bx
	movw	%si, %bp
waitfloppy:
	call	wait
	jne	waitfloppydone
#ifdef MULTI_INITRD
	decb	(%si)			# max_timeouts	
gobootit:
	//movw	ramdisk_size+2-max_timeouts(%si), %cx
	.byte	0x8B, 0x4C, ramdisk_size+2-max_timeouts
	jz	bootit
#endif
	pushw	%dx			# some bios break dx...
	cbw
	int	$0x13			# reset FDC
	movw	$0x201,%ax
	int	$0x13			# read first sector
	popw	%dx
	rclb	$1,%ah			# floppy changed 06=>0D no error 00
	cmpb	-2(%bp), %ah		# 0D then 00
	jne	waitfloppy		# no => try again
	incw	%bp
	decw	%ax			# was 0001 ?
	jne	waitfloppy
waitfloppydone:
#else
	putsmsg
	cbw				# %ah = 0, get keyboard character
	int	$0x16
#endif
#ifdef MULTI_INITRD
	orb	$0x20, %al
	cmp	$'b', %al
        jz	gobootit
#endif
        jmp	read_sectorslp

putcdot:
	movb	$'.'+3, %al	// . = success, - = failure
putclf:
	sbbb	$3, %al
putc:
	movb	$0xe, %ah
	movw	$7, %bx			#   one dot each 64k
 	int	$0x10
	cmp	$0xd, %al		# CR ?
	je	putclf
#ifdef	CMDLINE_SUPPORT
	movb	$cmd_line_ptr, %bl
#endif
	ret

#ifdef KEYBOARDLESS_SUPPORT
clock	= 0x46C
wait:
wait4key:
	movw	$clock, %di
#define DELAY 5
	movb	$257-(DELAY*182)/10, %fs:(%di)
waitkbd:
	movw	$0x10D, %ax		# test keyboard, timeout => CR
	cmpb	%fs:(%di),%ah
	je	waitdone
	int	$0x16
	jz	waitkbd
	cbw
	int	$0x16			# eat char
	movw	%di, %fs		# disable timeout
	incw	%di			# clear Z
waitdone:
	ret
#endif

#define kernel_version_offset	0xE
puts_version:
	addw	kernel_version_offset(%si),%si	# starting protocol 2.00, Kernel 1.3.73
puts:
	movb	$0xd, %al		# CR
putcs:
	call	putc
	lodsb
	cmpb	$0, %al			# end of string is any byte <= 0
	jg	putcs
	ret	

#ifdef MULTI_INITRD
swap_floppy2:
	.ascii	"B or "
#endif
swap_floppy:
#ifdef COUNTER
msg:
	.ascii	"Insert disk 00"
msgdigit:
	.ascii	"1 and Enter."
#else
	.ascii	"Next!"
#endif
	.byte	7,13,0			# swap detection needs 13, 0
#ifdef MULTI_INITRD
max_timeouts:
	.byte	20
table:
	.org	cur_initrd_size_ofs
cur_initrd_size:
	.word	table
	.byte	table+4-256
#endif
#ifdef	README_SUPPORT
	.org	0x1EF
readme:
	.word	0
#endif
	.org	0x1F1
