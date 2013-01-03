	.text
	.code16
	
ORGCOM	=	0x100
STKSZ	=	0x4000			// unlzma needs 16Kb

#undef	USE_CX_LOADER			// CX should be set by loader
#undef	SETUP_SS			// extends max code size from 47k to 63k

#ifdef SETUP_SS
STKROOM = 256
#else
STKROOM = STKSZ
#endif

CODESZ	=	(0x10000-STKROOM)/2	//  max < 16 sectors = 32Kb
	.org	0

	.globl	_start
_start:
	movw	$ORGCOM, %ax
	pushw	%ax
	movw	$packedcode+ORGCOM-1, %si
#ifdef USE_CX_LOADER
	pushw	%cx
#endif
	movw	$-STKROOM-1, %di
	movw	$packedcode-unpack-1, %cx
	std
// *               max ~47k                  |     17k
// oouuuuppppppppppppppppppppp-------------------S---16k----
	rep
	  movsb				// decompressor
// oo----ppppppppppppppppppppp---------------uuuuS---16k----
#ifdef USE_CX_LOADER
	popw	%cx
	pushw	%di
	movsb
	movw	$packedcode+ORGCOM-1, %si
	addw	%cx, %si
#else
	pushw	%di
	movsb
#if (CODESZ % 256) == 0
	movb	$CODESZ/256, %ch
#else
	movw	$CODESZ, %cx		// the loader should update CX ...
#endif
	movw	$packedcode+ORGCOM+CODESZ-1, %si
//	unsigned char *code;		// But we can patch later:
//	size -= * (unsigned short *) (code + 19);
//	* (unsigned short *) (code + 19) += size;
//	* (unsigned short *) (code + 22) += size;
#endif
	rep
	  movsb				// packed code
// oo--------------------ppppppppppppppppppppuuuuS---16k----
//                                           *
	cld
	incw	%di
	xchgw	%ax, %di
	xchgw	%ax, %si
	ret
// xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx------uuuuS---16k----
// *               max ~47k                  |     17k

unpack:
#ifdef	SETUP_SS
	movw	%ss, %bx
	leaw	STKSZ/16(%bx), %ax
	movw	%ax, %ss
	pushw	%bx
	call	dounpack
	popw	%ss
	ret
dounpack:
#endif
#define FLAT16
#include "unlzma.S"

packedcode:
