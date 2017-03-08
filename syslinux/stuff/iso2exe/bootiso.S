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
fdcnt:					// Overlay number
	.byte	0			// Bootstrap floppy sector count
	.ascii	"slitaz"

/////////////////////// Master Boot Record code //////////////////////////////

moved	=	0x8000
start0:
	//pushw	%dx			// restore %sp
	//incw	%bp			// restore %bp
	xorw	%bx, %bx
	movw	%bx, %ds
	movb	$0x7C, %bh
	pushw	%ds
	popw	%ss
	movw	%bx, %sp
	pushw	%bx			// return address
	pushw	%di
	pushw	%es			// save %es:%di
	cld
	sti
	pushw	%ds
	popw	%es
	call	setreg
	rep
	  movsw
	movw	$0x80, %dx
	ljmp	$0, $moved+start2
	.byte	0
//	.org	60
//	.long	0x0080			// PE header offset
	.org	64
end_header:
comstart:
	.word	0
	
	.org	66
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
	cmpw	(%bx), %cx
	jnc	puts			// read fail or no isohydrid boot sector
	movw	$patch,%si
	popw	%es
	popw	%di			// isolinux boot needs %es:%di and %dx
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
puts:
	movb	$0x80, %ah
	xchgw	%ax, %si
	jnc	error
halt:
	hlt
	jmp	halt
nobsmsg:
	.asciz	"No isolinux."

	.org	0x0080
////////////////////////////// EXE/PE header //////////////////////////////////

	.org	0x01A0
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
	movw	$moved, %di
	movw	$0x0100, %cx
	movb	$nobsmsg, %al
	ret
	.org	0x01B8

////////////////////////// partition boot code ////////////////////////////////
// assume CS=DS=SS=0 BX=7C00 DL=<drive> SI=7DBE

	.org	0x7C00
	jmp	bootpartition
	.org	0x7C03
	.org	0x7DBE
table	=	moved+0x1BE
patch:
	.byte	0,0,0			// head of original bs
partcode:
	popw	%di
	movw	$table,%si
	call	movepartition
	movb	$4,%cl
	movw	$table-16,%di
next:
	addw	$16,%di
	cmpb	%ch,(%di)		// boot flag ?
	loope	next
	pushw	%ds
	pushw	%ds
	pushl	8(%di)
	pushw	%ds
	pushw	%bx
	pushw	$1
	pushw	$0x10
	movw	%sp,%si			// assume %ds = %ss
	movb	$0x42,%ah
	pushw	%bx
	cmpw	$63,2(%di)		// empty or isolinux partition ?
	jbe	default
	int	$0x13
default:
	ret
	.org	0x7DEF
bootpartition:
	pushw	%ds
	popw	%es
	pushw	%si
	movw	%bx,%di
	movsw
	movsb
	movw	$partcode+0x100,%di
	pushw	%di
movepartition:
	movw	$66/2,%cx
	rep
	  movsw
	ret
	.org	0x7E00

	.org	0x7F48
////////////////////////////// DOS EXE code ///////////////////////////////////

exestart:
	cld
	movw	$EXEADRS(puts), %bp	
	movw	129, %ax
	cmpb	$0x2F, %al
	je	ishelp
	cmpw	$0x2F20, %ax
ishelp:
	movw	$0x3000+EXESTR(help), %ax
	cwd				// clear dx
	pushw	%dx			// dos exit()
	je	abort
	int	$0x21			// get DOS version
	addb	$-3, %al
	movw	$0xF000+EXESTR(noDOS3), %ax
	movw	$0x100, %di
	jc	tst386
abort:
	jmp	*%bp

tst386:
	pushfw				// save flags
		// bits  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
		// flags  0 NT  IOPL OF DF IF TF SF ZF  0 AF  0 PF  1 CF
	// movb	$0xF0, %ah
	pushw	%ax
	popfw				// < 286 : flags[12..15] are forced 1
	pushfw				// = 286 : flags[12..15] are forced 0
	popw	%bx			// > 286 : only flags[15] is forced 0
	popfw				// restore flags (IOPL)
	addb	%ah, %bh		// test F0 and 00 cases
	js	is86			// NS=386+, NC=286
is386:
	smsww	%ax			// not privileged
	andb	$1, %al
	movw	$10, %si
	jne	tstvcpi
	movl	%cr0, %eax		// privileged
	incl	%eax
	movb	$EXESTR(rmPaging), %al
	js	abort
	inc	%ax
	//movb	$EXESTR(realmodemsg), %al
realmode:
	call	*%bp
is86:
	movw	comstart-end_header(%di), %si		// .com address
	pushw	%di
	movb	$0x7C/2, %ch		// 31K-31.5K, > com length
	rep
	movsw
	ret

CallVCPI:
	int	$0x67
	testb	%ah, %ah
	xchgw	%ax, %cx
	pushw	%si
ScanVCPI:
	popw	%si
ChkVCPI:
NoVCPI:
	movb	$EXESTR(ERRvcpi), %al
	jne	abort
	lodsb
	shlw	$8, %ax
	jne	CallVCPI
VersionVCPI:
	xchgw	%ax, %si		// movb	$EXESTR(vm86modemsg), %al
	cmpb	$0x40, %cl		// EMM386 / VCPI 4.0 mini
	jnc	realmode		// %si = 0
tstvcpi:
	pushw	%ds
	movw	%si, %ds		// %si = 10
	movw	(0x67*4)+2-(16*10)-0x100(%di), %ds
	lodsw
	xorw	$0x4D45, %ax		// EM(MX) or EM(MQ)
	lodsw
	lodsw
	popw	%ds
	jne	NoVCPI
	xorw	$0x5858, %ax		// XX(X0)
	call	ScanVCPI
CmdVCPI:
	.byte	0x40			// status
	.byte	0xDE			// vcpi present ?
	.byte	0x46			// version
	.byte	0

vm86modemsg:
// --------------- Must be in 7F40 7FFF range ------------------------
	.ascii	"86"			// 86 mode
	.byte	EXESTR(mode)
ERRvcpi:
	.ascii	"VCPI4"			// VCPI4?
	.byte	EXESTR(need)
rmPaging:
	.ascii	"X"			// Xreal mode
realmodemsg:
	.ascii	"real"			// real mode
// --------------- Must be in 7FC0 7FFF range ------------------------
mode:
	.ascii	" m"
ode:
	.ascii	"ode"
	.byte	EXESTR(eol)
noDOS3:
	.ascii	"DOS3"			// DOS3?
need:
	.ascii	"?"
	.byte	EXESTR(eol)
help:
	.ascii	"SliTaz iso boot."	// SliTaz iso boot.
eol:
	.ascii	"\r\n"
	.byte	1			// puts will return

	.space	16,0			// ISO md5
	.org	0x8000
////////////////////////// ISO9660 header /////////////////////////////////////
