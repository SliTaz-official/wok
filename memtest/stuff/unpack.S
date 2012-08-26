#define TOP		0x8FD00
#define SYSTEM		0x10000
#define SETUP		4

#define CHANGE_STACK	1
#define LINUX_HEADER	0

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
#if CHANGE_STACK
	movw	$0xFFFE, %ax
	movw	%ss, %bx
	pushw	$0
	popw	%ss
	xchgw	%ax, %sp
	pushw	%bx		// %ss
	pushw	%ax		// %sp
#endif
	call	unpack		// unpack setup
	pushw	$SYSTEM/16
	popw	%es
	xorw	%di,%di
	call	unpack		// unpack system
#if CHANGE_STACK
	popw	%ax		// %sp
	popw	%ss
	xchgw	%ax, %sp
#endif
	popw	%es
	popw	%ds
	popal
	iret

unpack:
#include "unlzma.S"

end:
