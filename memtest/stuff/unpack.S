#define TOP		(0x90000+_start-end)
#define SYSTEM		0x10000
#define SETUP		14
#define SYSSIZE		0x1F4
#define SETUPSIZE	0x1F1

#define LINUX_HEADER		0
#define UPDATE_SYSSIZE		1
#define HARDCODED_SYSSIZE	1
#define HARDCODED_SETUPSIZE	1
#define FLAT16			1
//#define FLAT16OUT		0
#define SAVEREGS		0 
#define VM2RM			1

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
#if SAVEREGS
	pushfw
	pushw	%cs
	pushw	$0
	pushal
	pushw	%ds
#else
	pushw	%cs
	pushw	$0
#endif
#if UPDATE_SYSSIZE
	pushw	%ds
#else
	pushw	%es
	pushw	%cs
#endif
	cld
#if FLAT16
# 1- move 9020..9020+stp -> 8000
# if HARDCODED_SETUPSIZE
setup_word:
	movw	$SETUP*256, %cx
# else
	xorw	%cx, %cx
	movb	SETUPSIZE, %ch
	movw	%cx, %dx
# endif
	pushw	%cx
	pushw	$0x8000
	popw	%es
	xorw	%si, %si
	xorw	%di, %di
	rep
	  movsw	%cs:(%si),%es:(%di)
	pushw	%es
	// pushw	$cont
	.byte	0x6A, cont
	lret
cont:
# 2- move 1000..1000+sys -> 8000+stp
	pushw	$0x1000
	popw	%ds
	xorw	%si, %si
	subw	%di, %cx
	rep
	  movsb
# 3- unlz(8000+stp:end, 1000-stp:0)
	pushw	%es
# if HARDCODED_SETUPSIZE
setup_seg:
#  if UPDATE_SYSSIZE
	pushw	$0x1000-(SETUP*32)-32
#  else
	pushw	$0x1000-(SETUP*32)
#  endif
	popw	%es
# else
#  if UPDATE_SYSSIZE
	incb	%dh
#  endif
	shrw	$3, %dx
	movw	%ds, %ax
	subw	%dx, %ax
	movw	%ax, %es
# endif
#else
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
# 2- move 9020..9020+stp -> 9000-sys-stp
	
# if HARDCODED_SETUPSIZE
setup_byte:
	movb	$SETUP, %ch
setup_para:
	subw	$SETUP*32, %dx
# else
	movb	%ss:SETUPSIZE, %ch
	movw	%cx, %ax
	shrw	$3, %ax
	subw	%ax, %dx
# endif
	pushw	%cx
	movw	%dx, %es
	xorw	%si, %si
	xorw	%di, %di
	rep
	  movsw	%cs:(%si),%es:(%di)
	pushw	%es
# 3- reloc itself in 0x7C00
	pushw	$0x07C0
	popw	%es
	xorw	%si, %si
	xorw	%di, %di
	movw	$end-_start, %cx
	rep
	  movsb	%cs:(%si),%es:(%di)
	pushw	%es
	// pushw	$cont
	.byte	0x6A, cont
	lret
cont:
# 4- unlz(9000-sys-stp:end, 1000-stp:0)
# if HARDCODED_SETUPSIZE
setup_seg:
#  if UPDATE_SYSSIZE
	pushw	$0x1000-(SETUP*32)-32
#  else
	pushw	$0x1000-(SETUP*32)
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
#endif
	popw	%ds
	movw	$end-_start, %si
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
	movw	%si, %di
	popw	%cx
#if UPDATE_SYSSIZE
// not need with memtest	movb	$(512-SYSSIZE)/2, %cl
#endif
	popw	%es
# 5- move 1000-stp..1000 -> 9020
	rep
	  movsw
#if UPDATE_SYSSIZE == 0
	popw	%es
#endif
#if SAVEREGS
	popw	%ds
	popal
	iret
#else
	lret
#endif

#if VM2RM
#define EXEADRS(x)	(x+0x2E0)
#define BOOTEXEADRS(x)	(x+0xE0)
vm2rm:
pagebuf		=	0x96000
gdt_abs		=	0x18e		// see bootloader.lst
sw2pm_params	=	gdt_abs+30
sw2pm_cr3	=	sw2pm_params
sw2pm_idtr_ptr	=	sw2pm_params+8
saved_ss_sp	=	gdt_abs-44
saved_sp	=	gdt_abs-44
saved_ss	=	gdt_abs-42
tss		=	gdt_abs-40
gdt		=	gdt_abs-32
gdt_null	=	gdt_abs-32
gdt_vcpi	=	gdt_abs-24
gdt_vcpi2	=	gdt_abs-16
gdt_vcpi3	=	gdt_abs-8
gdt_code_base	=	gdt_abs+10
fixuprange	=	0x20
	pushaw
	pushw	%es
	pushw	%ds
	movl	%cs,%edx
	shll	$4,%edx
	movw	$BOOTEXEADRS(gdt_vcpi),%si
	movw	$-fixuprange,%bx
	addl	%edx,sw2pm_idtr_ptr-gdt_vcpi(%si)
fixup:
	addl	%edx,fixuprange+gdt_code_base-gdt_vcpi(%bx,%si)
	addw	$8,%bx
	jne	fixup
	pushw	$pagebuf/16
	popw	%es
	movl	$pagebuf+3,%es:0x1000
	xorw	%di,%di
	movw	$0xDE01,%ax	// EBX = getiface(DS:SI, ES:DI)
	int	$0x67
	movw	$BOOTEXEADRS(saved_sp),%bx
	movw	%ss,2(%bx)
	movw	%sp,(%bx)
	leal	BOOTEXEADRS(sw2pm_params)(%edx),%esi
	movw	$0xDE0C, %ax	// switchpm(ESI)
	cli
	int	$0x67
pm_code:
	movl	%cr0,%eax
	andl	$0x7FFFFFFE,%eax
	movl	%eax,%cr0
	movl	%eax,%cr3
	lssw	%cs:(%bx),%sp	
	popw	%ds
	popw	%es
	popaw
	retf
#endif

unpack:
#define NO_LZMA_HEADER
#include "unlzma.S"

end:
