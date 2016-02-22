	.text
	.code16
	
ORGCOM	=	0x100

	.org	0

	.globl	_start
_start:
	movw	$0, %cx		// .com size
	movw	$0, %si		// .com loc
	movw	$0x100, %bx
	leaw	15(%bx,%si), %di
	andw	$-16, %di
	addw	%cx, %si
	addw	%cx, %di
	incw	%cx
	std
	rep
	  movsb
	incb	%ch
	movw	%cx, %si	
	decw	%si
	rep
	  movsb
	cld
	incw	%di
	shrw	$4, %di		// 186
	movw	%cs, %ax
	addw	%di, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %ss
	popw	%dx
	pushw	%cx
	pushw	%ax
	pushw	%bx
	retf
	.ascii	"www.slitaz.org"
	
//	.org	64
