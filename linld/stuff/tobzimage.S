
#define REALMODE_SWITCH
#define SHUTDOWNDOS
#define ELKS_SUPPORT
#define LINUX001_SUPPORT

	.code16
	.org	0

#define CODE32_START	0x100000
	jmp	start
	.ascii	"HdrS"
	.word	0x200		# version
	.long	0		# realmode_swtch
	.word	0x1000		# start_sys_seg
	.word	kernel_version
	.byte	0		# type of loader
	.byte	1		# loadflags
	.word	0x8000		# setup_move_size
	.long	CODE32_START	# code32_start
 	.long	0		# ramdisk_image
	.long	0		# ramdisk_size
	.long 	0		# bootsect_kludge
	.word	0		# heap_end_ptr	2.01+, patched by bootloader

start:
	pushf
	pushw	%cs
	pushw	$0
	pushaw
	xorw	%di, %di
	.byte	0x66, 0xC7, 0x05	# movl $?, (%di)
	rep
	  movsw
	popaw
doiret:
	iret
	pushw	%ds
	pushw	%di
#ifdef REALMODE_SWITCH
	movw	$0x0208, %si
	lodsw
	orw	(%si), %ax
	jz	norealmode_switch
	lcallw	*-2(%si)
norealmode_switch:
#endif

#ifdef SHUTDOWNDOS
	xorw	%si, %si
        movw	%si, %ds		# %ds = 0
	pushl	4(%si)
	movw	%sp, %cs:loadsp19+1(%si)
	cmpb	$0xF0, 7(%si)
	jnb	notdos
        movw	$step19, 4(%si)
        movw	%cs, 6(%si)
        pushfw
        popw	%ax
        incb	%ah			# set TF
        pushw	%ax
        popfw
        ljmp	*4*0x19(%si)
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
notdos:
loadsp19:
	movw	$0, %sp
	popl	4(%si)
	pushw	%ss
	popw	%ds
#else
	xorw	%si, %si
#endif
#if defined(ELKS_SUPPORT) || defined(LINUX001_SUPPORT)
	movw	%sp, %bx
#endif
	movw	$9, %cx
z1:
	pushw	%si		# 0000 0000 0000 0000 0000 0000 0000 0000 0000
	loop	z1
	movw	$0x9301, %ax
	cwd
	pushw	%ax		# 9301
	pushw	%si		# 0000
	pushw	%dx		# FFFF
	pushw	%si		# 0000
	movb	0x216, %al
	pushw	%ax		# 93xx
	pushw	%si		# 0000
	pushw	%dx		# FFFF
	movb	$8, %cl
z2:
	pushw	%si		# 0000 0000 0000 0000 0000 0000 0000 0000
	loop	z2
	movw	$0x200, %di
	movw	-12(%di), %dx
	pushw	%ss
	popw	%es
	movw	%sp, %si
mvlp:
	movw	$0x8000, %cx
	movb	$0x87, %ah
	int	$0x15
	incw	20(%si)
	incw	28(%si)
	subw	$0x1000, %dx
	ja	mvlp
	addw	$48, %sp
#ifdef ELKS_SUPPORT
	//cmpl	$0x534B4C45, -26(%di)
	movw	$0x100, %cx
elks_patch:
	jmp	notelks
	movb	%ch, 23(%bx)
	movw	%cx, %es
	pushw	%di
	xorw	%di, %di
	xorw	%si, %si
	movb	$0x6, %ch
	rep
	  movsw
	popw	%di
	pushw	%es
	popw	%ds
notelks:
#endif
	movw	$0x400, %si
	decb	-15(%di)
#ifdef LINUX001_SUPPORT
	//cmpw	$0x3AE8, 0x3F(%si)
linux001_patch:
	jmp	notlnx001
	movb	$0x42, (%bx)
	xorw	%di, %di
# ifndef ELKS_SUPPORT
	movw	$0x100, %cx
# endif
	rep
	  movsw
notlnx001:
#endif
	movb	-15(%di), %ch
	lret
endcode:
	
	.org	256
kernel_version:
	.asciz	"zImage"
	.org	512
oldsetup:



