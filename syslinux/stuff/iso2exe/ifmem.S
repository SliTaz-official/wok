	.code16
	.org	0
type_of_loader	=	0x10
	
	orw	$0x8020, type_of_loader(%si) # loader type = 0x20 = bootsect-loader
	pushal
	
	movw	$10+16, %cx
fillbuf:
	pushw	$0
	loop	fillbuf
	popal			// clear regiters
maploop:
	movw	%sp, %di	// %es = %ss
	movb	$20, %cl
	movw	$0xE820, %ax
	movl	$0x534d4150, %edx
	int	$0x15
	sbbl	%eax, %edx
	jne	mapdone
	decw	16(%di)	
	jne	notram
	addw	8+2(%di), %bp
notram:
	orw	%bx, %bx
	jnz	maploop
mapdone:
	addw	$20, %sp
	shrw	$20-16,%bp
	jnz	mapdone2
	movb	$0x88, %ah
	int	$0x15
	xchgw	%ax, %bp
	shrw	$10, %bp
mapdone2:
	incw	%bp
// %bp : nb Mb	
	call	here
here:
	popw	%di
	movw	$0x1EE, %si
	lodsw
sizeloop:
	scasw			// %di += 2
	addw	$4, %ax
	cmpb	%al, (%si)	
	jbe	sizedone
	cmpw	%bp, sizes-here(%di)
	jbe	sizeloop
	movb	%al, (%si)
sizedone:
	popal
	lret			// need %si
sizes:

