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
	call	bootpartition		// assume DS=SS SI=BX=7C00 CX=0100 DL=<drive> DI=table+66
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

	.org	0x0080,0xEE
////////////////////////////// EXE/PE header //////////////////////////////////
	.org	0x0178,0xFF
////////////////////////// partition boot code ////////////////////////////////
// assume DS=SS SI=BX=7C00 CX=0100 DL=<drive> DI=table+66

bootpartition:
	movw	$4,%cx
	movw	$16,%ax
next:
	subw	%ax,%di
	cmpb	%ch,-2(%di)		// boot flag ?
	loope	next
	cmpw	$63,2-2(%di)		// empty or isolinux partition ?
	jbe	default
	.arch	i486
	pushl	$0
	pushl	8-2(%di)
	pushw	%cs
	pushw	%bx
	pushw	$1
	pushw	%ax
	movw	%sp,%si			// assume %ds = %ss
	movb	$0x42,%ah
	int	$0x13
	add	$16,%sp
	.arch	i8086
default:
	ret

	.org	0x01A0,0xFF
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
	.org	0x01B8,0xEE		// partition table

	.org	0x0270,0xFF

////////////////////////////// DOS EXE code ///////////////////////////////////

bootdir:
	.asciz	"/boot"
linld:
	.asciz	"linld.com"
cmdline:
	.ascii	"-f "
//	.ascii	"image=\boot\"
//	.ascii	"bzImage "
	.ascii	"initrd="
rootfs:
	.ascii	"rootfs"
dotgz:
	.ascii	".gz,!            "
//	.ascii	".gz,rootfs4.gz,! "
args:
//	.ascii	" rw "
//	.ascii	" mode=menu"
	.ascii	" autologin rdinit=/init.exe magic="
magicstr:
	.ascii	"0     bootfrom="
//	.ascii	"65535 bootfrom="
filename:
exestart:
	movb	$0x30,%ah		// get DOS version
	int	$0x21
	cmpb	$3,%al
	jc	goabort

	cld
	movw	EXEADRS(comstart),%si
	movw	$0xF000,%di
	movb	$4,%ch			// 2k min
	rep
	  movsw				// helper
	movw	$129,%si
	leaw	args-cmdline(%si),%di
	movb	-1(%si),%cl
	pushw	%si
	rep
	  movsb				// user args
	xchgw	%ax,%di
	popw	%di
	movw	$EXEADRS(cmdline),%si
	movb	$args-cmdline,%cl
	rep
	  movsb				// files
	xchgw	%ax,%di
	movb	$filename-args,%cl
	rep
	  movsb				// end
	pushw	%di			// filename

#define ISOSTATE	0xF000
#define ISO_OPEN	iso_open
#define ISO_READDIR	*0xF004
#define ISO_READMENU 	iso_readmenu
#define RUN_LINLD	run_linld
	movw	ISOSTATE,%bp
	xorw	%ax,%ax
	movw	%bp,%di
	movb	$64,%cl
	rep
	  stosb				// clear BSS

	movw	%ax,%di
	movw	0x2C(%di),%es
	decw	%cx
scalp:
	repne
	  scasb
	scasb
	jne	scalp
	scasw
	movw	%di,%si			// %es:%di = programme pathname

	pushw	%es
	pushw	%ds
	popw	%es
	popw	%ds
	popw	%di			// filename
	pushw	%di
	movb	$0x60,%ah		// canonicalize filename
	int	$0x21
	pushw	%es
	popw	%ds
#define LONG_FILENAME
#ifdef LONG_FILENAME
	popw	%si
	pushw	%si
	movw	$0x716C,%ax
	xorw	%bx,%bx			// R/O
	xorw	%cx,%cx			// attributes
	cwd				// action = open
	stc
	int	$0x21
	jnc	opened
#endif
	popw	%dx
	pushw	%dx
	movw	$0x3D00,%ax
//	movb	$0,%cl
	int	$0x21
goabort:
	jc	abort
opened:
	movw	%ax,4(%bp)		// fd

	call	ISO_READMENU
	movw	6(%bp),%ax		// magic = filemod
	popw	%bx
	leaw	magicstr-filename(%bx),%di
	movb	$10,%bl
	xorw	%cx,%cx
lp1:
	xorw	%dx,%dx
	divw	%bx
	pushw	%dx
	incw	%cx
	orw	%ax,%ax
	jnz	lp1
lp2:
	popw	%ax
	addb	$'0',%al
	stosb				// store magic
	loop	lp2

	movw	$EXEADRS(bootdir),%ax
	call	ISO_OPEN
	orw	$-1,18(%bp)		// curdirsize = -1
	xorw	%ax,%ax
found:
	incb	%ah
patchtest:
	pushw	%ax
	call	ISO_READDIR
	pushw	%ds
	popw	%es
	incw	%ax
	popw	%ax
	movw	$EXEADRS(rootfs),%si
	je	dopatch
	movw	%si,%di
	movw	16(%bp),%si		// filename
	movw	$9,%cx
	rep
	  cmpsb
	jcxz	found
	cmpb	$3,%cl
	ja	patchtest
	decw	%si
	cmpb	(%si),%al
	ja	patchtest
	lodsb
	jmp	patchtest
done:
	movw	$128,%ax
	subw	%ax,%si
	xchgw	%ax,%si
	decw	%ax
	movb	%al,(%si)		// cmdline length

	movw	$EXEADRS(linld),%ax
	call	ISO_OPEN
	jc	abort
	movw	12(%bp),%cx		// filesize
	movw	$0x100,%dx
	call	RUN_LINLD
abort:
	movw	$EXEADRS(stopmsg),%dx
	movb	$9,%ah
	int	$0x21
	int	$0x20
dopatch:
	pushw	%si
	cmpw	$0x200,%ax
	je	initrddone
	movw	$EXEADRS(dotgz),%di
	decb	%ah
	je	modify
	scasw
	scasw				// addw	$4,%di
	movsw
	movsw
	movsw
modify:
	stosb
	movw	$129+dotgz-cmdline,%si
	movsb
	movsw
	movsw
initrddone:
	movw	$129+rootfs-cmdline,%di
	popw	%si
	movw	$args-rootfs,%cx
	rep
	  movsb

shrink0:
	movw	$129,%si
shrink:
	movw	%si,%di
	lodsb
	cmpb	$0,%al
	je	done
	cmpb	$' ',%al
	jne	shrink
	cmpb	(%si),%al
	jne	shrink
pack:
	lodsb
	stosb
	cmpb	$0,%al
	jne	pack
	jmp	shrink0
	
	.org	0x0400,0xEE
	.org	0x0600,0xFF
	.org	0x0750,0xBB
stopmsg:
	.ascii	"This program cannot be run in DOS mode.$"
	.org	0x0778,0xEE
	.org	0xF002-0xC0
iso_open:
	.word	0
	.word	0
iso_readmenu:
	.word	0
run_linld:

	.end
