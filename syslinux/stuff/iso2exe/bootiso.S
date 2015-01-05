	.text
	.code16
	.org	0

CODESZ	=	0x8000			// 16 sectors = 32Kb
#define EXEADRS(x)	x+0xC0
#define EXELOC(x)	x-0x40
#define EXESTR(x)	x-0x7F40

	.globl	_start
_start:
	decw	%bp			// Magic number: MZ
	popw	%dx
	jmp	start0			// Bytes on last page of file
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
initramfssize:
	.word	0			// File address of relocation table
id:
	.word	0			// Overlay number
fdcnt:					// File address of relocation table
	.byte	0			// Bootstrap floppy sector count

/////////////////////// Master Boot Record code //////////////////////////////

start0:
	pushw	%dx			// restore %sp
	incw	%bp			// restore %bp
	xorw	%bx, %bx
	movw	%bx, %ds
	movb	$0x7C, %bh
	pushw	%bx			// return address
	pushaw
	movw	%sp, %bp
	pushw	%es			// save %es:%di
	cld
	sti
	pushw	%ds
	popw	%es
	call	setreg
	rep
	movsw
	movw	$0x80, %dx
	ljmp	$0, $0x0600+start2

	.org	60
	.long	0x0080			// PE header offset
end_header:
chksum:
	.word	0
comstart:
	.word	0
	
	.org	68
readsectorX:				// read isolinux boot sector
	movb	$0xA5, %cl		// patched by installer
readsector1:
	andb	$0x83, %dl		// disk and floppy disk
	movw	%cx, (%bx)
	incw	%cx
	movw	$0x201, %ax
	int	$0x13
setreg:
	movw	%bx, %si
	movw	$0x0600, %di
	movw	$0x0100, %cx
return:
	ret
dxloop:
start2:
	call	readsector1		// look for the boot device
	repe
	cmpsw
	je	dxfound
	movb	$0, %cl			// ch = 0
	addb	$0x7D, %dl		// try every hard disk
	jno	dxloop
dxfound:
	call	readsectorX		// read isolinux boot sector
	movw	%dx, 10(%bp)
	call	checkboot
	.asciz	"No isolinux bs"

	.org	0x0080
////////////////////////////// EXE/PE header //////////////////////////////////

	.org	0x01A0
checkboot:
	cmpw	%cx, (%bx)
	popw	%si
	jc	error			// read fail or no isohydrid boot sector
	popw	%es
	popa
putsret:
	ret
putstrlp:
	movw	$7, %bx
	movb	$0xE, %ah
	int	$0x10
error:
	lodsb
	cmp	$1, %al
	jg	putstrlp
	jz	putsret
putstr:
	movb	$0x80, %ah
	xchgw	%ax, %si
	jnc	error
halt:
	hlt
	jmp	halt
	.org	0x01BE

	.org	0x7F10
////////////////////////////// DOS EXE code ///////////////////////////////////

exestart:
	cld
	movw	$0x100, %si
	movw	-127(%si), %ax
	cmpb	$0x2F, %al
	je	ishelp
	cmpw	$0x2F20, %ax
ishelp:
	movw	$0x3000+EXESTR(help), %ax
	cwd				// clear dx
	pushw	%dx			// dos exit()
	je	abort
	int	$0x21			// get DOS version
	cmpb	$3, %al
	movb	$EXESTR(noDOS3), %al
	jb	abort
	movw	$(EXELOC(0x8000))/2, %cx
chklp:
	lodsw
	addw	%ax, %dx
	loop	chklp
chked:
	movw	$0x1000+EXESTR(chkerr), %ax
	je	tst386		// dx == 0 ?
abort:
puts:
	clc
	jmp	putstr

tst386:
	pushfw			// save flags
		// bits  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
		// flags  0 NT  IOPL OF DF IF TF SF ZF  0 AF  0 PF  1 CF
	// movb	$0x10, %ah
	pushw	%ax
	popfw			// < 286 : flags[12..15] are forced 1
	pushfw			// = 286 : flags[12..15] are forced 0
	popw	%bx		// > 286 : only flags[15] is forced 0
	popfw			// restore flags (IOPL)
	addb	%ah, %bh	// test F0 and 00 cases
	cmpb	%ah, %bh
	movb	$EXESTR(no386), %al
#undef NEED386
#ifdef NEED386
	jbe	abort		// C=8086/80186, Z=80286
#else
	jbe	is86		// C=8086/80186, Z=80286
#endif
is386:
	smsww	%ax		// not privileged
	andb	$1, %al
	jne	tstvcpi
	movl	%cr0, %eax	// privileged
	incl	%eax
	movb	$EXESTR(rmPaging), %al
	js	abort
	movb	$EXESTR(realmodemsg), %al
realmode:
is86:
	call	puts
	movw	$0x0100, %di
	movw	comstart-end_header(%di), %si		// .com address
	pushw	%di
	movb	$0x7C/2, %ch	// 31K-31.5K, > com length
	rep
	movsw
	ret

VersionVCPI:
	cmpb	$0x40, %dl		// >= 4.0 ?
	jb	NoVCPI
	xchgw	%ax, %si		// movb	$EXESTR(vm86modemsg), %al
	jmp	realmode
tstvcpi:
	pushw	%ds
	movw	%dx, %ds		// %dx = 0
	movw	0x67*4+2, %ds
	movw	$10, %si
	lodsw
	xorw	$0x4D45, %ax		// EM(MX) or EM(MQ)
	lodsw
	lodsw
	popw	%ds
	jne	NoVCPI
	xorw	$0x5858, %ax		// XX(X0)
	movw	$EXEADRS(CmdVCPI), %si
ChkVCPI:
NoVCPI:
	movb	$EXESTR(ERRvcpi), %al
	jne	abort
	lodsb
	shlw	$8, %ax
	je	VersionVCPI
	int	$0x67
	testb	%ah, %ah
	xchgw	%ax, %dx
	jmp	ChkVCPI
CmdVCPI:
	.byte	0x40			// status
	.byte	0xDE			// vcpi present ?
	.byte	0x46			// version
	.byte	0

vm86modemsg:
// --------------- Must be in 7F40 7FFF range ------------------------
	.ascii	"vm"			// vm86
	.byte	EXESTR(_86)
ERRvcpi:
	.ascii	"No VCPI-4.0/EMM"	// No VCPI-4.0/EMM386
	.byte	EXESTR(_386)
noDOS3:
	.ascii	"No DOS 3"		// No DOS 3
	.byte	EXESTR(eol)
chkerr:
	.ascii	"Broken c"		// Broken code
	.byte	EXESTR(ode)
rmPaging:
	.ascii	"Un"			// Unreal mode
realmodemsg:
	.ascii	"real m"		// real mode
// --------------- Must be in 7FC0 7FFF range ------------------------
ode:
	.ascii	"od"
eeol:
	.ascii  "e"
	.byte	EXESTR(eol)
no386:
	.ascii	"No "			// No 386
_386:
	.ascii	"3"
_86:
	.ascii	"86"
	.byte	EXESTR(eol)
help:
	.ascii	"SliTaz boot loader"	// SliTaz boot loader
eol:
	.ascii	"\r\n"
	.byte	1

	.space	16,0			// ISO md5
	.org	0x8000
////////////////////////// ISO9660 header /////////////////////////////////////
