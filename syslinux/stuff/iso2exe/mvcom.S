	.text
	.code16
	
ORGCOM	=	0x100

	.org	0

	.globl	_start
_start:
	movw	$0, %si		// .com size
	movw	$0, %bx		// .com loc
#if 1
	pushw	%si
	leaw	1-64-256(%bx,%si), %cx
	leaw	(%bx,%si), %si
	movw	$0xF000, %di
	cmpw	%si, %di
	jc	skip
	std
	rep
	  movsb
	subw	%si, %di
	addw	%di, %bx
skip:
	popw	%si
#endif
	movw	$done-install, %cx
	leaw	(%bx,%si), %di
	pushw	%si
	call	move
install:
	popw	%cx
	movw	$ORGCOM, %di
	pushw	%bx
move:
	popw	%si
	pushw	%di
	cld
	rep
	  movsb
	ret
done:
//	.org	64
