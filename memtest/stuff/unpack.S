#define TOP	0x8FF00
#define SYSTEM	0x10000
#define SETUP	4

	.text
	.code16
	.org	0

	.globl	_start
_start:
	pushf
	pushw	%cs
	call	getip
getip:
	pushal
	movw	$0, %bx		// packed sizes
	movw	%sp, %bp
#define START_IP	32(%bp)
	pushw	%ds
	pushw	%es
	subw	$getip-_start, START_IP

	cld
	pushw	%cs
	popw	%ds	
	movw	$TOP/16, %ax
	movw	%ax, %es
	subw	%bx, %ax	// moved packed data
	movw	START_IP, %si
	movw	$moved-_start, %di
	addw	%si, %di
	pushw	%ds		// save setup seg
	pushw	%es		// moved
	pushw	%di		//   unpack code
	movw	%si, %di
	movw	$end-_start, %cx
	rep
	movsb			// move upack code to $TOP
	pushw	%si		// data offset
	movw	%ax, %es
	movw	$SETUP*512, %cx
	subw	$SETUP*32, %bx
	xorw	%si, %si
	xorw	%di, %di
	rep
	movsb			// move header part
	pushw	$SYSTEM/16
	popw	%ds
movlp:
	xorw	%si, %si
	movw	$8, %cx
	rep
	movsw			// move system part
	subw	$16, %di
	movw	%ds, %cx
	incw	%cx
	movw	%cx, %ds
	movw	%es, %cx
	incw	%cx
	movw	%cx, %es
	decw	%bx
	jns	movlp
	popw	%si		// data offset
	movw	%ax, %ds
	retf

moved:
	popw	%es		// restore setup seg
	movw	START_IP, %di
	call	unpack		// unpack setup
	pushw	$SYSTEM/16
	popw	%es
	xorw	%di,%di
	call	unpack		// unpack system
	popw	%es
	popw	%ds
	popal
	iret

unpack:
#include "unlz4.S"

end:
