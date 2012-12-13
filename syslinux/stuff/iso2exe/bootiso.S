	.text
	.code16
	.org	0

CODESZ	=	0x8000			// 16 sectors = 32Kb
#define EXEADRS(x)	x+0xE0
#define EXESTR(x)	x-0x20

	.globl	_start
_start:
	decw	%bp			// Magic number: MZ
	popw	%dx
	jmp	start			// Bytes on last page of file
	.word	(CODESZ+511)/512	// Pages in file
	.word	0			// Relocations
	.word	(end_header-_start)/16	// Size of header in paragraphs
	.word	4064-(CODESZ/16)	// Minimum extra paragraphs needed
	.word	4064-(CODESZ/16)	// Maximum extra paragraphs needed
	.word	0xFFF0			// Initial (relative) SS value
	.word	0xFFFE			// Initial SP value
	.word	0			// Checksum
	.word	EXEADRS(fixseg)		// Initial IP value
	.word	0xFFF0			// Initial (relative) CS value
	.word	0x001C			// File address of relocation table
	.word	0			// Overlay number
initramfssize:
	.word	0
id:
	.word	0
end_header:

chksum:
	.long	0
comstart:
	.word	0

/////////////////////// Master Boot Record code //////////////////////////////

start:
	incw	%bp
	pushw	%dx			// restore SP
	pushaw
	movw	%sp, %bp
	pushf
	pushw	%ds
	pushw	%es
	pushw	$0
	popw	%ds
	call	setreg
	rep
	movsw
	ljmp	$0, $0x0600+start2
	
setreg:
	cld
	pushw	%ds
	popw	%es
	movw	$0x7C00, %si
	movw	%si, %bx
	movw	$0x0600, %di
	movw	$0x0100, %cx
return:
	ret
start2:
	movw	$0x80, %dx
dxloop:
	movw	$1, %cx
	movw	$0x201, %ax
	int	$0x13
	jc	next
	call 	setreg
	repe
	cmpsw
	je	dxfound
next:
	addb	$0x7D, %dl		// try every hard disk
	andb	$0x83, %dl		//   and floppy disk
	cmpb	$0x80, %dl
	jnz	dxloop
fail:
	int	$0x19
dxfound:
	movw	%dx, 10(%bp)
	movb	$2, %cl			// %ch = 0
	movw	$0x201, %ax
	int	$0x13
	jc	fail
	cmpw	$0xAA55, 0x7DFE
	jne	fail
	popw	%es
	popw	%ds
	popf
	popa
	ljmp	$0, $0x7C00

////////////////////////////// DOS EXE code ///////////////////////////////////

no386:
	.ascii	"No 386+$"
noDOS3:
	.ascii	"No DOS 3.0+$"
rmPaging:
	.ascii	"Broken paging.$"
ERRvcpi:
	.ascii	"No VCPI 4.0+$"
chkerr:
	.ascii	"Broken ISO.$"
realmodemsg:
	.ascii	"Real mode\r$"
vm86modemsg:
	.ascii	"Vm86\r$"
help:
	.ascii	"Linux kickstarter.\r\n$"
fixseg:
#if 1
	movb	$EXESTR(help), %dl
	movw	0x82, %ax
	cmpw	$0x3F2F, %ax		# /?
	je	abort
#endif
	pushf
	popw	%ax
	movw	$0xF0F0, %cx
	orb	%ah, %ch
	andb	$0xF, %ah
	
	pushw	%ax
	popf
	pushf
	popw	%ax
	andb	%cl, %ah
	
	cmp	%cl, %ah
	je	NotSupported	// 8086 family
	
	pushw	%cx
	popf
	pushf
	popw	%ax
	andb	%cl, %ah
	
	jnz	is386		// 80286 family
NotSupported:
	movb	$EXESTR(no386), %dl
abort:
puts:
	movb	$1, %dh
	movb	$9, %ah
	int	$0x21
	ret

is386:
	movb	$0x30, %ah
	int	$0x21
	cmpb	$3, %al
	movb	$EXESTR(noDOS3), %dl
	jb	abort
	smsw	%ax
	andb	$1, %al
	jne	tstvcpi
	movl	%cr0, %eax
	movb	$EXESTR(rmPaging), %dl
	shll	$1, %eax
	jc	abort
	jmp	realmode

tstvcpi:
	pushw	%ds
	pushw	$0
	popw	%ds
	movw	0x67*4+2, %ds
	std
	movw	$14, %si
	lodsl
	cmpl	$0x30585858, %eax	// 0XXX
	lodsl
	cld
	popw	%ds
NoVCPI:
	movb	$EXESTR(ERRvcpi), %dl
goabort:
	jne	abort
	shll	$8, %eax
	cmpl	$0x4D4D4500, %eax	// [XQ]MME
#if 1
	movw	$EXEADRS(CmdVCPI), %si
ChkVCPI:
	jne	NoVCPI
	lodsb
	shlw	$8, %ax
	je	VersionVCPI
	int	$0x67
	jmp	ChkVCPI
CmdVCPI:
	.byte	0x40			// status
	.byte	0xDE			// vcpi present ?
	.byte	0x46			// version
	.byte	0
VersionVCPI:
	cmpb	$0x40, %al		// >= 4.0 ?
	jb	NoVCPI
#else
	jne	NoVCPI
	movb	$0x40, %ah		// status
	int	$0x67
	testb	%ah, %ah
	jne	NoVCPI
	movb	$0x46, %ah		// version
	int	$0x67
	testb	%ah, %ah
	jne	NoVCPI
	cmpb	$0x40, %al		// >= 4.0 ?
	jb	NoVCPI
	movw	$0xDE00, %ax		// vcpi present ?
	int	$0x67
	testb	%ah, %ah
	jne	NoVCPI
#endif
realmode:
	movw	$0x100, %si
	lodsl
	xchgl	%eax, %edx
	orl	%edx, %edx
	jz	skip
	movw	$0x7FDC/4, %cx
chklp:
	lodsl
	addl	%eax, %edx
	loop	chklp
	orl	%edx, %edx
	movb	$EXESTR(chkerr), %dl
	jne	goabort
skip:
	movb	$EXESTR(realmodemsg), %dl
	smsww	%ax
	andb	$1, %al
	jz	isrealmode
	movb	$EXESTR(vm86modemsg), %dl
isrealmode:
	call	puts
	movw	EXEADRS(comstart), %ax			// .com address

	cld
	movw	$moveend-move, %cx
	movw	$EXEADRS(move), %si
	movw	$0xC000, %di
	jmp	move2

move:
	movb	$0x80, %ch
	xchgw	%ax, %si
	movw	$0x0100, %di
move2:
	pushw	%di
	rep
	movsb
	ret
moveend:
	
	.org	440
//////////////////////////// partition table //////////////////////////////////

