	.code16
	.org	0

	jmp	start
	.ascii	"HdrS"
	.word	0x200		# version
	.long	0		# realmode_swtch
	.word	0x1000		# start_sys_seg
	.word	kernel_version
	.byte	0		# type of loader
	.byte	1		# loadflags
	.word	0x8000		# setup_move_size
	.long	0x100000	# code32_start
 	.long	0		# ramdisk_image
	.long	0		# ramdisk_size
	.long 	0		# bootsect_kludge
	.word	0		# heap_end_ptr	2.01+, patched by bootloader
start:
	pushf
	cld
	pushw	%cs
	pushw	$0
	pushaw
	pushw	%ds
	popw	%es
	.byte	0x66, 0xB8	# movl $?, %eax
	rep
	  movsw
	popaw
	iret
	xorw	%di, %di
	pushw	%es
	pushw	%di
	stosl
	movw	$0x200, %di
	movw	%sp, %bp
	movw	$9, %cx
z1:
	pushw	$0
	loop	z1
	movw	$0x9301, %ax
	cwd			# %dx = -1
	pushw	%ax
	pushw	%cx
	pushw	%dx
	pushw	%cx
	movb	0x216, %al
	pushw	%ax
	pushw	%cx
	pushw	%dx
	movb	$8, %cl
z2:
	pushw	$0
	loop	z2
	movw	-12(%di), %dx
mvlp:
	movw	%sp, %si
	movw	$0x8000, %cx
	movb	$0x87, %ah
	int	$0x15
	incw	20(%si)
	incw	28(%si)
	subw	$0x1000, %dx
	ja	mvlp
	movw	%bp, %sp
	movw	$0x400, %si
	xorw	%cx, %cx
	decb	-15(%di)
	movb	-15(%di), %ch
	lret
kernel_version:
	.asciz	"zImage"
	.org	512
oldsetup:

