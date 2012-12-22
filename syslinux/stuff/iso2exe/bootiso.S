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
	.word	EXEADRS(exestart)	// Initial IP value
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
	pushw	$0
	popw	%ds
	movw	$0x7C00, %bx
	pushfw
	pushw	%ds
	pushw	%bx
	pushaw
	movw	%sp, %bp
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
	pushw	%ds
	popw	%es
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
	movw	$0x0600+noloader, %si
	call	putslp
stop:
	hlt
	jmp	stop
dxfound:
	movw	%dx, 10(%bp)
	call	readsector2
	lodsw
	shrw	$1, %ax
	jz	fail			// read fail or not isohydrid
	popw	%es
	popa
	iret

	
////////////////////////////// DOS EXE code ///////////////////////////////////

help:
	.ascii	"SliTaz GNU/L"		// SliTaz GNU/Linux boot loader
	.byte	EXESTR(iloader)
no386:
	.ascii	"No 386"		// No 386+
	.byte	EXESTR(plus)
ERRvcpi:
	.ascii	"No EMM386/VCPI 4"	// No EMM386/VCPI 4.0+
	.byte	EXESTR(dot0)
chkerr:
	.ascii	"Broken ISO image fil"	// Broken ISO image file.
	.byte	EXESTR(eeol)
vm86modemsg:
	.ascii	"vm86"			// vm86 mode.
	.byte	EXESTR(mode)
rmPaging:
	.ascii	"Invalid: paging + "	// Invalid: paging + real mode.
realmodemsg:
	.ascii	"real"			// real mode.
// --------------- Must be in 00A0 011F range ------------------------
mode:
	.ascii	" mod"
eeol:
	.ascii  "e"
	.byte	EXESTR(eol)
noloader:
	.ascii	"No isol"		// No isolinux boot loader
iloader:
	.ascii	"inux boot loader"
eol:
	.ascii	"."
eol2:
	.asciz	"\r\n"
noDOS3:
	.ascii	"No DOS 3"		// No DOS 3.0+
dot0:
	.ascii	".0"
plus:
	.ascii	"+"
	.byte	EXESTR(eol2)
// -------------------------------------------------------------------

exestart:
	cld
	movw	$0x100, %si
	movw	-127(%si), %ax
	cwd				// clear dx
	pushw	%dx			// dos exit
	cmpw	$0x2F20, %ax
	movw	$0x1000+EXESTR(help), %ax
	je	abort
	pushfw			// save flags
		// bits  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
		// flags  0 NT  IOPL OF DF IF TF SF ZF  0 AF  0 PF  1 CF
	// movb	$0x10, %ah
	pushw	%ax
	popfw			// < 286 : flags[12..15] are forced 1
	pushfw			// = 286 : flags[12..15] are forced 0
	popw	%cx		// > 286 : only flags[15] is forced 0
	popfw			// restore flags
	addb	%ah, %ch	// test F0 and 00 cases
	cmpb	%ah, %ch
	movb	$EXESTR(no386), %al
	jbe	abort		// C=8086/80186, Z=80286
#if 1
	movw	(%si), %cx
	jcxz	is386
#endif
	movw	$0x7FE0/2, %cx
chklp:
	lodsw
	addw	%ax, %dx
	loop	chklp
	movb	$EXESTR(chkerr), %al
	je	is386		// dx == 0 ?
abort:
puts:
	movb	$1, %ah
	xchgw	%ax, %si
putslp:
	lodsb
	orb	%al, %al
	jz	moveret
	js	puts
	movw	$7, %bx
	movb	$0xE, %ah
	int	$0x10
	jmp	putslp

is386:
	movl	%cr0, %eax
	andb	$1, %al
	jne	tstvcpi
	shll	$1, %eax
	movb	$EXESTR(rmPaging), %al
	jc	abort
	movb	$EXESTR(realmodemsg), %al
realmode:
	call	puts
	movb	$0x30, %ah
	int	$0x21
	cmpb	$3, %al
	movb	$EXESTR(noDOS3), %al
	jb	abort
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
moveret:
	ret
moveend:

VersionVCPI:
	cmpb	$0x40, %dl		// >= 4.0 ?
	jb	NoVCPI
	movb	$EXESTR(vm86modemsg), %al
	jmp	realmode
tstvcpi:
	pushw	%ds
	movw	%cx, %ds		// %cx = 0
	movw	0x67*4+2, %ds
	movw	$10, %si
	lodsw
	xorw	$0x4D45, %ax		// EM(MX) or EM(MQ)
	xchgw	%ax, %dx
	lodsw				// si += 2
	lodsw
	xorw	$0x5858, %ax		// XX
	orw	%ax, %dx
	lodsw
	popw	%ds
	xorw	$0x3058, %ax		// X0
	orw	%ax, %dx
	movw	$EXEADRS(CmdVCPI), %si
ChkVCPI:
NoVCPI:
	xchgw	%ax, %dx
	movb	$EXESTR(ERRvcpi), %al
	jne	abort
	lodsb
	shlw	$8, %ax
	je	VersionVCPI
	int	$0x67
	testb	%ah, %ah
	jmp	ChkVCPI
CmdVCPI:
	.byte	0x40			// status
	.byte	0xDE			// vcpi present ?
	.byte	0x46			// version
	.byte	0

	.org	440
//////////////////////////// partition table //////////////////////////////////

