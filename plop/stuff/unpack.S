#define SYSTEM		0x10000
#define SETUP		14
#define SYSSIZE		0x1F4
#define SETUPSIZE	0x1F1

#define KEEP_BOOTSECTOR		1
#define LINUX_HEADER		0
#define UPDATE_SYSSIZE		1
#define HARDCODED_SYSSIZE	1
#define HARDCODED_SETUPSIZE	1
#define FLAT16			1
#define FLAT16OUT		1
#define SAVEREGS		0 
#define ELKS			0

	.text
	.code16
	.org	0

#if KEEP_BOOTSECTOR
#undef UPDATE_SYSSIZE
#define UPDATE_SYSSIZE		0
#endif
#if defined(FLAT16OUT) && FLAT16OUT == 0
#undef FLAT16OUT
#endif
#if ELKS
	.arch	i8086
#define FLAT16			1
#define LINUX_HEADER		0
#define SAVEREGS		0 
#define TOPSEG		0x2000
#else
#define TOPSEG		0x8000
#endif

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
#if SAVEREGS
	pushfw
	pushw	%cs
	pushw	$0
	pushal
	pushw	%ds
	cld
#else
	pushw	%cs
# if FLAT16
	xorw	%di, %di
	pushw	%di
# else
	pushw	$0
# endif
#endif
#if ELKS
	movw	$0x100, %ax
	pushw	%ax
#else
# if UPDATE_SYSSIZE || KEEP_BOOTSECTOR
	pushw	%ds			// <A>
# else
	pushw	%cs			// <A>
# endif
#endif
#if FLAT16
# 1- move 9000/9020..9020+stp -> TOPSEG
#if ELKS
	movb	$TOPSEG/256, %ah
	movw	%ax, %es
#else
	pushw	$TOPSEG
	popw	%es
#endif
#if KEEP_BOOTSECTOR
	xorw	%si, %si
#else
	movw	$0x200, %si
#endif
#if SAVEREGS == 0
	pushw	%es
#if ELKS
# if KEEP_BOOTSECTOR
	movw	$cont+0x200, %ax
# else
	movw	$cont, %ax
# endif
	pushw	%ax
#else
# if KEEP_BOOTSECTOR
	pushw	$cont+0x200
# else
	// pushw	$cont
	.byte	0x6A, cont
# endif
#endif
	jmp	jumpinto
#else
# if HARDCODED_SETUPSIZE
setup_word:
#  if KEEP_BOOTSECTOR
#  else
	movw	$SETUP*256, %cx
#  endif
# else
#  if KEEP_BOOTSECTOR
	movw	$0x100, %cx
	addb	SETUPSIZE, %ch
#  else
	xorw	%cx, %cx
	movb	SETUPSIZE, %ch
#  endif
	movw	%cx, %dx
# endif
	pushw	%cx			// <B>
	pushw	%es
	pushw	%di
	rep
	  movsw
	lret
#endif
cont:
# 2- move 1000..1000+sys -> TOPSEG+stp
#if ELKS
	movw	$0x1000, %ax
	movw	%ax, %ds
#else
	pushw	$0x1000
	popw	%ds
#endif
	xorw	%si, %si
	subw	%di, %cx
	rep
	  movsb
# 3- unlz(TOPSEG+stp:end, 1000-stp:0)
	pushw	%es		// <C>
# if HARDCODED_SETUPSIZE
setup_seg:
#if ELKS
#  if KEEP_BOOTSECTOR
#   if UPDATE_SYSSIZE
	movw	$0x1000-(SETUP*32)-32-32, %ax
#   else
	movw	$0x1000-(SETUP*32)-32, %ax
#   endif
#  else
#   if UPDATE_SYSSIZE
	movw	$0x1000-(SETUP*32)-32, %ax
#   else
	movw	$0x1000-(SETUP*32), %ax
#   endif
#  endif
	movw	%ax, %es
#else
#  if KEEP_BOOTSECTOR
#   if UPDATE_SYSSIZE
	pushw	$0x1000-(SETUP*32)-32-32
#   else
	pushw	$0x1000-(SETUP*32)-32
#   endif
#  else
#   if UPDATE_SYSSIZE
	pushw	$0x1000-(SETUP*32)-32
#   else
	pushw	$0x1000-(SETUP*32)
#   endif
#  endif
	popw	%es
#endif
# else
#  if UPDATE_SYSSIZE
	incb	%dh
#  endif
#if ELKS
	shrw	$1, %dx
	shrw	$1, %dx
	shrw	$1, %dx
#else
	shrw	$3, %dx
#endif
	movw	%ds, %ax
	subw	%dx, %ax
	movw	%ax, %es
# endif
#else		// FLAT16
# 1- move 1000..1000+sys -> 9000-sys
# if HARDCODED_SYSSIZE
packed_syssize:
	movw	$0x1000+0, %ax
# else
	movw	SYSSIZE, %ax
	addw	$0x1000, %ax
# endif
	movw	%ds, %dx
mvsys:
	decw	%ax
	decw	%dx
	movw	%ax, %ds
	movw	%dx, %es
	xorw	%si, %si
	xorw	%di, %di
	movw	$8, %cx
	rep
	  movsw
	cmpw	$0x1000, %ax
	jne	mvsys
# 2- move 9000/9020..9020+stp -> 9000-sys-stp
	
# if HARDCODED_SETUPSIZE
#  if KEEP_BOOTSECTOR
setup_byte:
	movb	$SETUP+1, %ch
setup_para:
	subw	$SETUP*32+32, %dx
#  else
setup_byte:
	movb	$SETUP, %ch
setup_para:
	subw	$SETUP*32, %dx
#  endif
# else
	movb	%ss:SETUPSIZE, %ch
#  if KEEP_BOOTSECTOR
	incb	$ch
#  endif
	movw	%cx, %ax
#if ELKS
	shrw	$1, %ax
	shrw	$1, %ax
	shrw	$1, %ax
#else
	shrw	$3, %ax
#endif
	subw	%ax, %dx
# endif
	pushw	%cx			// <B>
	movw	%dx, %es
	xorw	%si, %si
	xorw	%di, %di
	rep
	  movsw	%cs:(%si),%es:(%di)
	pushw	%es
# 3- reloc itself in 0x7C00
	pushw	$0x07C0
	popw	%es
	movw	$cont, %si
	movw	%si, %di
	movw	$end-_start, %cx
	pushw	%es
	pushw	%di
	rep
	  movsb	%cs:(%si),%es:(%di)
	lret
cont:
# 4- unlz(9000-sys-stp:end, 1000-stp:0)
# if HARDCODED_SETUPSIZE
setup_seg:
#  if KEEP_BOOTSECTOR
#   if UPDATE_SYSSIZE
	pushw	$0x1000-(SETUP*32)-32-32
#   else
	pushw	$0x1000-(SETUP*32)-32
#   endif
#  else
#   if UPDATE_SYSSIZE
	pushw	$0x1000-(SETUP*32)-32
#   else
	pushw	$0x1000-(SETUP*32)
#   endif
#  endif
	popw	%es
# else
	negw	%ax
#  if UPDATE_SYSSIZE
	addw	$0x1000-32, %ax
#  else
	addw	$0x1000, %ax
#  endif
	movw	%ax, %es
# endif
#endif		// FLAT16
	popw	%ds			// <C>
#if KEEP_BOOTSECTOR
	movw	$0x200+end-_start, %si
#else
	movw	$end-_start, %si
#endif
#if UPDATE_SYSSIZE
	movw	$SYSSIZE, %di
#else
	xorw	%di, %di
#endif
	pushw	%di
	pushw	%es
	call	unpack
	popw	%ds
	popw	%si
#   if KEEP_BOOTSECTOR
setup_keep:
	xorw	%di, %di
#   else
	movw	%si, %di
#   endif
#   if SAVEREGS != 0
	popw	%cx			// <B>
#if UPDATE_SYSSIZE
// not need with memtest	movb	$(512-SYSSIZE)/2, %cl
#endif
	popw	%es			// <A>
# 5- move 1000-stp..1000 -> 9020
#   else
	popw	%es			// <A>
jumpinto:
# if HARDCODED_SETUPSIZE
setup_word:
#  if KEEP_BOOTSECTOR
	movw	$SETUP*256+256, %cx
#  else
	movw	$SETUP*256, %cx
#  endif
# else
#  if KEEP_BOOTSECTOR
	movw	$0x100, %cx
	addb	%ss:SETUPSIZE, %ch
#  else
	xorw	%cx, %cx
	movb	%ss:SETUPSIZE, %ch
#  endif
	movw	%cx, %dx
# endif
#  endif
	rep
	  movsw
#if SAVEREGS
	popw	%ds
	popal
	iret
#else
	lret
#endif

unpack:
#define NO_LZMA_HEADER
#if ELKS
#define ONLY8086	1
#endif
#include "unlzma.S"

end:
