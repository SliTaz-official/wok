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
	movw	%cs, %ax
	movb	$4, %cl
	shrw	%cl, %di
	adcw	%di, %ax
	movw	%ax, %ds
	movw	%ax, %es
	popw	%dx
	movw	%ax, %ss
	pushw	%dx
	pushw	%ax
	pushw	%bx
	retf
	.ascii	"www.slitaz.org"
	
//	.org	64
