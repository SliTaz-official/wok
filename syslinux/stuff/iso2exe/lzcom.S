	.text
	.code16
	
ORGCOM	=	0x100
STKSZ	=	0x4000			// unlzma needs 16Kb
CODESZ	=	(0x10000-STKSZ)/2	//  max < 16 sectors = 32Kb

	.org	0

	.globl	_start
_start:
	cld
	movw	$packedcode-unpack, %ax
	movw	$packedcode+ORGCOM, %si
	movw	$-STKSZ-CODESZ, %di
	subw	%ax, %di
	pushw	%di
	movw	$CODESZ/2, %cx
	rep
	  movsw				// packed code
	movw	$unpack+ORGCOM, %si
	movw	%di, %bx
	xchgw	%ax, %cx
	rep
	  movsb				// decompressor
	movw	$ORGCOM, %di
	popw	%si
	pushw	%di
	pushw	%bx
	ret

unpack:
#define FLAT16
#include "unlzma.S"

packedcode:
