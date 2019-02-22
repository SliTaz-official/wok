	.text
	.code16
	.arch	i8086
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
magic:
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
// assume DS=SS BX=7C00 CH=01 DL=<drive> SI=7DBE

	.org	0x7C00
	jmp	bootpartition
	.org	0x7C03
	.org	0x7DBE
table	=	moved+0x1BE
patch:
	.byte	0,0,0			// head of original bs
partcode:
	popw	%si
	xchgw	%si,%di
	call	movepartition
	pushw	%cx
	pushw	%cx
	decw	%di
	decw	%di
	movb	$4,%cl
	movw	$16,%ax
next:
	subw	%ax,%di
	cmpb	%ch,(%di)		// boot flag ?
	loope	next
	pushw	10(%di)
	pushw	8(%di)
	pushw	%cs
	pushw	%bx
	movb	$1,%cl
	pushw	%cx
	pushw	%ax
	movw	%sp,%si			// assume %ds = %ss
	pushw	%bx
	cmpw	$63,2(%di)		// empty or isolinux partition ?
	jbe	default
	movb	$0x42,%ah
	int	$0x13
default:
	ret
	.org	0x7DF0
bootpartition:
	pushw	%ds
	popw	%es
	pushw	%si
	movw	%bx,%di
	movsw
	movsb
	movw	$table-0x142,%di
	pushw	%di
movepartition:
	movb	$66,%cl			// 0142 and 0042
	rep
	  movsb
	ret
	.org	0x7E00

	.org	0x7F83
////////////////////////////// DOS EXE code ///////////////////////////////////

exestart:
	cld
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
	movb	$EXESTR(noDOS3), %al
	movw	$0x100, %di
	jc	tst386
abort:
goputs:
	jmp	puts

tst386:
	pushw	%sp
	popw	%ax
	xorw	%sp, %ax		// clear C
	movb	$EXESTR(vm86modemsg), %al
	jnz	is86			// 86/186 not a 286+
	.arch	i486
is386:
	smsww	%bx			// not privileged
	andb	$1, %bl			// clear C
	jne	isvm86
	movl	%cr0, %ebx		// privileged
	incl	%ebx
	.arch	i8086
	movb	$EXESTR(rmPaging), %al
	js	abort
is86:
	incw	%ax
	//movb	$EXESTR(realmodemsg), %al
isvm86:
	call	goputs
	movw	comstart-end_header(%di), %si		// .com address
	pushw	%di
	movb	$0x7C/2, %ch		// 31K-31.5K, > com length
	rep
	movsw
	ret

vm86modemsg:
// --------------- Must be in 7F40 7FFF range ------------------------
	.ascii	"v"			// v86 mode
	.ascii	"86"			// 86 mode
	.byte	EXESTR(mode)
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
