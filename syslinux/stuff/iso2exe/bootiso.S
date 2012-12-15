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
	.word	0
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
	call	setreg
	rep
	movsw
	ljmp	$0, $0x0600+start2
	
readsector2:
	incw	%cx
readsector1:
	movw	%cx, (%bx)
	incw	%cx
	movw	$0x201, %ax
	int	$0x13
setreg:
	cld
	xorw	%bx, %bx		// Clear C
	movw	%bx, %ds
	movw	%bx, %es
	movb	$0x7C, %bh
	movw	%bx, %si
	movw	$0x0600, %di
	movw	$0x0100, %cx
return:
	ret
start2:
	movw	$0x80, %dx
dxloop:
	call	readsector1
	repe
	cmpsw
	je	dxfound
next:
	xorw	%cx, %cx
	xchgw	%ax, %dx
	addb	$0x7D, %al		// try every hard disk
	andb	$0x83, %al		//   and floppy disk
	cmpb	$0x80, %al
	xchgw	%ax, %dx
	jnz	dxloop
fail:
	int	$0x19
dxfound:
	movw	%dx, 10(%bp)
	call	readsector2
	lodsw
	decw	%ax
	jz	fail			// read fail or not isohydrid
	popw	%es
	popw	%ds
	popf
	popa
	ljmp	$0, $0x7C00

////////////////////////////// DOS EXE code ///////////////////////////////////

eol:
	.ascii	".\r\n$"
no386:
	.ascii	"No 386+$"
noDOS3:
	.ascii	"No DOS 3.0+$"
rmPaging:
	.ascii	"Broken paging$"
ERRvcpi:
	.ascii	"No EMM386/VCPI 4.0+$"
chkerr:
	.ascii	"Broken ISO file$"
realmodemsg:
	.ascii	"Real mode$"
vm86modemsg:
	.ascii	"VM86 mode$"
help:
	.ascii	"SliTaz GNU/Linux boot loader$"

fixseg:
	cld
	movb	$EXESTR(help), %dl
	movw	$0x100, %si
	cmpw	$0x3F2F, -126(%si)	# /? 
	je	abort
	movw	(%si), %cx
	jcxz	skip
	xorw	%dx, %dx
	movw	$0x7FE0/2, %cx
chklp:
	lodsw
	addw	%ax, %dx
	loop	chklp
	orw	%dx, %dx
	movb	$EXESTR(chkerr), %dl
	jne	abort
skip:
	pushf
	popw	%ax
	movw	$0xF0F0, %dx
	orb	%ah, %dh
	andb	$0xF, %ah
	pushw	%ax
	popf
	pushf
	popw	%ax
	andb	%dl, %ah
	cmp	%dl, %ah
	je	NotSupported	// 8086 family
	pushw	%dx
	popf
	pushf
	popw	%ax
	andb	%dl, %ah
	jnz	is386		// 80286 family
NotSupported:
	movb	$EXESTR(no386), %dl
abort:
puts:
	movb	$1, %dh
	call	puts2
	movw	$EXEADRS(eol), %dx
puts2:
	movb	$9, %ah
	int	$0x21
	ret

is386:
	movl	%cr0, %eax
	andb	$1, %al
	jne	tstvcpi
	movb	$EXESTR(rmPaging), %dl
	shll	$1, %eax
cabort:
	jc	abort
	movb	$EXESTR(realmodemsg), %dl
	jmp	realmode

tstvcpi:
	pushw	%ds
	movw	%cx, %ds		// %cx = 0
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
	jne	abort
	shll	$8, %eax
	cmpl	$0x4D4D4500, %eax	// [XQ]MME
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
	movb	$EXESTR(vm86modemsg), %dl
realmode:
	call	puts
	movb	$0x30, %ah
	int	$0x21
	cmpb	$3, %al
	movb	$EXESTR(noDOS3), %dl
	jb	cabort
	movw	EXEADRS(comstart), %ax			// .com address
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

