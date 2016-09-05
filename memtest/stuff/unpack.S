#define TOP		(0x90000+_start-end)
#define SYSTEM		0x10000
#define SETUP		4
#define SYSSIZE		0x1F4
#define SETUPSIZE	0x1F1

#define CHANGE_STACK		0
#define LINUX_HEADER		0
#define UPDATE_SYSSIZE		1
#define HARDCODED_SYSSIZE	1
#define HARDCODED_SETUPSIZE	1
#define HARDCODED_IP		1
#define FLAT16			1
//#define FLAT16OUT		0

	.text
	.code16
	.org	0

	.globl	_start
_start:
#if LINUX_HEADER
	jmp	start2
	.ascii	"HdrS"		// 202 magic
	.word	0x200		// 206 version 2.00
	.long	0		// 208 realmode_swtch
	.word	SYSTEM/16	// 20C start_sys_seg
	.word	0		// 20E kernel_version
	.byte	0		// 210 type_of_loader
	.byte	0		// 211 loadflags
	.word	0		// 212 setup_move_size
	.long	SYSTEM		// 214 code32_start
	.long	0		// 218 ramdisk_image
	.long	0		// 21C ramdisk_size
	.long	0		// 220 bootsect_kludge
start2:
#endif
	pushf
	pushw	%cs
#if HARDCODED_IP
	pushw	$0
#else
	call	getip
getip:
#endif
	pushal
#if !FLAT16
#undef FLAT16
#if HARDCODED_SYSSIZE
packed_syssize:
	movw	$0, %bx		// system size
#else
	movw	SYSSIZE, %bx
#endif
#endif
#if HARDCODED_SETUPSIZE == 0
	xorw	%dx, %dx
	movb	SETUPSIZE, %dh
#endif
#if HARDCODED_IP
	xorw	%si, %si
#else
	movw	%sp, %bp
#define START_IP	32(%bp)
	subw	$getip-_start, START_IP
	movw	START_IP, %si
#endif
	pushw	%ds
	pushw	%es

	cld

#if FLAT16
flat16mv:
#if CHANGE_STACK
STKSZ=0x9000-0x0990
	pushw	$(TOP-STKSZ)/16-0x1000
#else
	pushw	$TOP/16-0x1000
#endif
	popw	%es
	pushw	%es			// moved
	.byte	0x6A, moved-_start	//   unpack code
	pushw	%cs
	popw	%ds	
	xorw	%di, %di
#if HARDCODED_SETUPSIZE
	movw	$SETUP*256, %cx
#else
	xorw	%cx, %cx
	movw	SETUPSIZE, %ch
#endif
	pushw	%si
	rep
	movsw			// move header part
	movw	$0x1000, %bp
	movw	%bp, %ds
	xorw	%si, %si
	subw	%di, %cx
	rep
	movsb			// move system part
	popw	%di
	movw	$end-_start, %si
#else	
#if CHANGE_STACK
STKSZ=0x9000-0x0990
	movw	$(TOP-STKSZ)/16, %ax
#else
	movw	$TOP/16, %ax
#endif
	movw	%ax, %es
	pushw	%es			// moved
	.byte	0x6A, moved-_start	//   unpack code
	pushw	%cs
	popw	%ds	
	xorw	%di, %di
	movw	$end-_start, %cx
	pushw	%cx
	pushw	%si
	rep
	movsb			// move upack code to $TOP

	leaw	SYSTEM/16(%bx), %bp
movlp:
	decw	%bp
	movw	%bp, %ds
	decw	%ax
	movw	%ax, %es
	xorw	%si, %si
	xorw	%di, %di
	movb	$8, %cl
	rep
	movsw			// move system part
	decw	%bx
	jnz	movlp

	pushw	%cs
	popw	%ds
	popw	%si
	xorw	%di, %di
#if HARDCODED_SETUPSIZE
	movb	$SETUP, %ch
	subw	$SETUP*32, %ax
#else
	movb	%dh, %ch
	shrw	$3, %dx
	subw	%dx, %ax
#endif
	movw	%ax, %es
	pushw	%si
	rep
	movsw			// move header part
	popw	%di
	popw	%si
#endif
	pushw	%es
	popw	%ds
	pushw	%cs
	popw	%es		// restore setup seg
	retf

moved:
#if CHANGE_STACK
	movw	$STKSZ, %ax	// trick: %ss = %sp
	movw	%ss, %bx
	pushw	%ax
	popw	%ss
	xchgw	%ax, %sp
	pushw	%bx		// %ss
	pushw	%ax		// %sp
#endif
	pushw	%bp		// SYSTEM/16
	call	unpack		// unpack setup
	popw	%es
	xorw	%di,%di
	call	unpack		// unpack system
#if CHANGE_STACK
	popw	%ax		// %sp
	popw	%ss
	xchgw	%ax, %sp
#endif
#if UPDATE_SYSSIZE
# if HARDCODED_SYSSIZE
original_syssize:
	movw	$0, %ax
# else
	addw	$15, %di
	shrw	$4, %di
	movw	%es, %ax
	addw	%di, %ax
	subw	$SYSTEM/16, %ax
# endif
#endif
	popw	%es
	popw	%ds
#if UPDATE_SYSSIZE
	movw	%ax, SYSSIZE
# if HARDCODED_SETUPSIZE
original_setupsize:
	movb	$4, SETUPSIZE
# endif
#endif
	popal
	iret

unpack:
#define NO_LZMA_HEADER
#include "unlzma.S"

end:
