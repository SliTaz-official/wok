	.text
	.code16
	.org	0
stacktop	= 0xFFFE

	.globl	_start
_start:
#if 1
#define EXEADRS(x)	x+0xE0
#define CODESZ 0x200
	decw	%bp			// Magic number: MZ
	popw	%dx
	jmp	start			// Bytes on last page of file
	.word	(CODESZ+511)/512	// Pages in file
	.word	0			// Relocations
	.word	(end_header-_start)/16	// Size of header in paragraphs
	.word	4096			// Minimum extra paragraphs needed
	.word	-1			// Maximum extra paragraphs needed
	.word	(CODESZ+15)/16		// Initial (relative) SS value
	.word	stacktop		// Initial SP value
	.word	0			// Checksum
	.word	EXEADRS(comstart)	// Initial IP value
	.word	0xFFF0			// Initial (relative) CS value
//	.word	0x001C			// File address of relocation table
//	.word	0,0,0			// Overlay number
start:
	pushw	%dx
	cld
	pushw	%cs
	call	comstart2
stop:
	hlt
	jmp	stop
end_header:
#endif
comstart:
	pushw	%cs
	call	comstart2
	int	$0x20
comstart2:
	call	here
here:
	popw	%ax
	subw	$here-_start, %ax
	shrw	$4, %ax
	movw	%cs, %dx
	addw	%ax, %dx
	pushw	%dx
	pushw	$go
	retf
go:
	pushw	%cs
	popw	%ds
	pushw	%cs
	popw	%es
#if 1
	pushfw			// save flags
		// bits  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
		// flags  0 NT  IOPL OF DF IF TF SF ZF  0 AF  0 PF  1 CF
	movb	$0x10, %ah
	pushw	%ax
	popfw			// < 286 : flags[12..15] are forced 1
	pushfw			// = 286 : flags[12..15] are forced 0
	popw	%bx		// > 286 : only flags[15] is forced 0
	popfw			// restore flags
	addb	%ah, %bh	// test F0 and 00 cases
	cmpb	%ah, %bh
	jbe	fail		// C=8086/80186, Z=80286
#endif
	xorl	%ebx, %ebx
e820lp:
	movl	$0xe820, %eax
	movl	$0x534d4150, %edx
	movl	$20, %ecx
	movw	$buffer, %di
	int	$0x15
	jc	fail
	cmpl	$0x534d4150, %eax
	jne	fail
	cmpl	$20, %ecx
	jc	fail
	pushl	%ebx
	movw	$header_e820, %si
	call	puts64
	movw	$usable, %si
	cmpl	$1, (%di)
	je	show_status
	movw	$acpi_reclaim, %si
	cmpl	$3, (%di)
	je	show_status
	movw	$acpi_nvs, %si
	cmpl	$4, (%di)
	je	show_status
	movw	$reserved, %si
show_status:
	call	putcs
	popl	%ebx
	orl	%ebx, %ebx
	jnz	e820lp
fail:
	movb	$10, %al
	call	putc
	movw	$8*4, %cx
	movw	$buffer, %di
	pushw	%di
	xorw	%ax, %ax
	rep
	  stosw
	movw	$0xE801, %ax
	int	$0x15
	popw	%di
	jc	fail2
	movb	$0x10, 0+2(%di)		// 1M
	movb	$0x10, 32+2(%di)	// 1M
	movb	$0x1, 16+3(%di)		// 16M
	movb	$0x1, 48+3(%di)		// 16M
	incb	%bh
	movw	%bx, 24+2(%di)
	incb	%dh
	movw	%dx, 56+2(%di)
	movw	%cx, %dx
	movb	$6, %cl
	shrw	%cl, %ax		// 1K -> 64K
	jz	e801_configured
	shrw	%cl, %dx		// 1K -> 64K
	addw	$0x10, %ax
	addw	$0x10, %dx
	movw	%ax, 8+2(%di)
	movw	%dx, 40+2(%di)
	movw	$extended, %si
	call	pute801
	call	pute801
e801_configured:
	movw	$buffer+32, %di
	movw	$configured, %si
	call	pute801
	call	pute801
	movb	$10, %al
	call	putc
fail2:
	movw	$8, %cx
	movw	$buffer, %di
	pushw	%di
	xorw	%ax, %ax
	rep
	  stosw
	movb	$0x88, %ah
	int	$0x15
	popw	%di
	jc	fail3
	movb	$0x10, 0+2(%di)		// 1M
	movb	$6, %cl
	shrw	%cl, %ax		// 1K -> 64K
	jz	fail3
	addw	$0x10, %ax
	movw	%ax, 8+2(%di)
	movw	$header_0088, %si
	call	puts64
	movb	$10, %al
	call	putc
fail3:
	retf

puts64:
	call	puts
	call	put64
	movw	$middle, %si
	call	putcs
put64:
	movw	$8, %cx
	addw	%cx, %di
	pushw	%di
put64lp:
	decw	%di
	movb	(%di), %al
	shrb	$4, %al
	call	putx
	movb	(%di), %al
	call	putx
	loop	put64lp
	popw	%di
	ret

pute801:
	pushw	%si
	movw	$header_e801, %si
	call	puts64
	popw	%si
	pushw	%si
	call	putcs
	popw	%si
	ret
putcs:
	movb	$0x20, %al
putslp:
	call	putc
puts:
	lodsb
	orb	%al, %al
	jnz	putslp
	ret

putx:
	andb	$0xF, %al
	addb	$0x90, %al
	daa
	adcb	$0x40, %al
	daa
putc:
	movw	$7, %bx
	movb	$0xE, %ah
	int	$0x10
	ret

header_0088:
	.byte	13,10
	.ascii  "BIOS-0088: "
	.byte	0
header_e801:
	.byte	13,10
	.ascii  "BIOS-e801: "
	.byte	0
extended:
	.ascii	"(extended)"
	.byte	0
configured:
	.ascii	"(configured)"
	.byte	0
header_e820:
	.byte	13,10
	.ascii  "BIOS-e820: "
	.byte	0
middle:
	.ascii	"- "
	.byte	0
usable:		// 1
	.ascii	"(usable)"
	.byte	0
reserved:	// 2
	.ascii	"(reserved)"
	.byte	0
acpi_reclaim:	// 3
	.ascii	"(ACPI Reclaim)"
	.byte	0
acpi_nvs:	// 4
	.ascii	"(ACPI NVS)"
	.byte	0
buffer:
	.org	510
	.word	0xAA55
