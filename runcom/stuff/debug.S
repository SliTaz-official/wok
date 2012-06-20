// Usage:
//
// f DX:CX                 load one CHS sector to 0000:7C00
// t                       trace one step
// g <address>             go to adrs
// d <address>             display 16 bytes, CR for next 16 bytes...
// e <address> <words>...  enter memory byte/word/dword
// m <segment>             self move
// + <segment>             default segment offset
//
// Example:
// m 0FC0                  move debugger to 0FC0:0000 0FC0:01FF
// f 1			   read floppy boot sector to 0000:7C00
// f 80:1		   read hard disk master boot sector to 0000:7C00
// g 7C0E		   ...

#define REGS32		28 bytes	display FS, GS and 32 bits datas for AX..DI 
#define ADJESDI		16 bytes	add segment overflow support for e and d
#define ASCIIDUMP	20 bytes	display hexa and ascii datas
#define INPUTBUFFER	 3 bytes	overload init code with a 32+ bytes input buffer

.macro pushib val
	.byte	0x6A, \val-_start
.endm

#ifdef REGS32
#define SEGREGSZ	10
#define REGSZ	32
#define USER_SP		REGSZ+SEGREGSZ-28(%bp)
#define FIXSP		14
#else
#define SEGREGSZ	6
#define REGSZ	16
#define USER_SP		REGSZ+SEGREGSZ-14(%bp)
#define FIXSP		10
#endif
#define USER_FLAGS	REGSZ+SEGREGSZ+4(%bp)
#define USER_FLAGS_HIGH	REGSZ+SEGREGSZ+5(%bp)
#define USER_IP		REGSZ+SEGREGSZ(%bp)
#define USER_CS		REGSZ+SEGREGSZ+2(%bp)
#define USER_CSIP	REGSZ+SEGREGSZ(%bp)

#ifdef INPUTBUFFER
//#define ABS(x)		(x-(setvectors-_start))
#define ABS(x)		(x-32)
#else
#define ABS(x)		(x)
#endif
.macro initcode
	movw	$0x0FC0, %di	# move (and jump) to 0FC0:0000
	subw	$_startz-_start, USER_IP
	movw	USER_IP, %ax
	shrw	$4, %ax		# _start MUST be aligned on paragraph
	addw	USER_CS, %ax	# normalize %cs to have _start=0
	movw	%ax, %ds
.endm

	.text
	.code16
	.org	0

	.globl	_start
_start:
	pushf
	pushw	%cs
	stc
	call	init		# the start code will be overwritten by the input buffer
_startz:

#ifdef INPUTBUFFER
isinit:
	initcode
	addw	$FIXSP, USER_SP	# adjust SP with [FLAGS CS IP DS ES [FS GS]] size
	pushib	setvectors
	jmp	moveself
#endif

setvectors:
	xorw	%si, %si	# set interrupt vectors in 0 segment
	movw	%si, %ds
	movb	$0x7D, %cl	# skip nmi
hooklp:				# interrupts: 0=div0 1=step 2=nmi 3=brk 4=ov 5=bound 6=invalid
	pushw	%cs
	pushib	ABS(dbgstart)	# set %cs:dbgstart
	popl	(%si)		# to interrupt vector
skiphook:
	lodsl			# %si += 4
	shrb	$1,%cl
	jnc	skiphook
	jnz	hooklp		# note %cx will be cleared: SP will be untouched
	decw	(3-7)*4(%si)	# update int3 vector
	jmp	dbgstartz	# registers are already pushed by startup code

regs:
	.ascii	"ss"
	.ascii	"di"  
	.ascii	"si"  
	.ascii	"bp"  
	.ascii	"sp"  
	.ascii	"bx"  
	.ascii	"dx"  
	.ascii	"cx"  
	.ascii	"ax"  
#ifdef REGS32
	.ascii	"gs"
	.ascii	"fs"
#endif
	.ascii	"es"
	.ascii	"ds"  
	.ascii	"ip"  
	.ascii	"cs"  
# Bit   Label    Desciption
# ---------------------------
# 0      CF      Carry flag
# 2      PF      Parity flag
# 4      AF      Auxiliary carry flag
# 6      ZF      Zero flag
# 7      SF      Sign flag
# 8      TF      Trap flag
# 9      IF      Interrupt enable flag
# 10     DF      Direction flag
# 11     OF      Overflow flag
#ifdef REGS32
	.ascii	"odi|sz|a|p|c"	# flags bits
#else
	.ascii	"oditsz?a?p c="	# flags bits
#endif
# 12-13  IOPL    I/O Priviledge level
# 14     NT      Nested task flag
# 16     RF      Resume flag
# 17     VM      Virtual 8086 mode flag
# 18     AC      Alignment check flag (486+)
# 19     VIF     Virutal interrupt flag
# 20     VIP     Virtual interrupt pending flag
# 21     ID      ID flag

#ifdef INPUTBUFFER
ismove:
	pushw	%ax
moveself:
	popw	%si
#else
isinit:
	initcode
ismove:
	xorw	%si, %si
#endif
	movw	%di, %es	# move code to %di:0
	pushw	%di
#ifdef INPUTBUFFER
	xorw	%di, %di	# and jmp into (%di:setvectors) with retf
#else
	movw	$setvectors, %di	# and jmp into (%di:setvectors) with retf
	movw	%di, %si
#endif
	movw	$_end-setvectors, %cx
	pushw	%di
	rep	movsb
	retf

int3:
	.byte	0x68		# push $0x086A	OV UP DI NT PL ZR - NA - PO - NC
# interrupt entry point: the registers [FLAGS CS IP] are already pushed
dbgstart:
	.byte	0x6A, 0x08	# push $0x08	NV UP DI NT PL NZ - NA - PO - NC
	popf
init:
	pushw	%ds
	pushw	%es
#ifdef REGS32
	pushw	%fs
	pushw	%gs
	pushal		#    [FLAGS CS IP DS ES FS GS] EAX ECX EDX EBX ESP EBP ESI EDI [SS]
#else
	pushaw		#    [FLAGS CS IP DS ES] AX CX DX BX SP BP SI DI [SS]
#endif
	pushw	%ss
	movw	%sp, %bp
#ifndef INPUTBUFFER
	pushf
	addw	$FIXSP, USER_SP	# adjust SP with [FLAGS CS IP DS ES [FS GS]] size
	popf
#endif
	jc	isinit
	jnz	notint3
	decw	USER_IP
	lesw	USER_CSIP, %di
#define OPCODE_BRK     0xCC
	.byte	0xB0		# movb $IM, %al
break:
	.byte	0xCC
	stosb
notint3:
#ifdef INPUTBUFFER
	addw	$FIXSP, USER_SP	# adjust SP with [FLAGS CS IP DS ES [FS GS]] size
#endif
dbgstartz:
dbgregslp:
	pushw	%cs
	popw	%ds
	movw	$ABS(regs), %si
#ifdef REGS32
	subw	%si, %bp
	movw	$15, %cx
#else
	movw	$13, %cx
#endif
regslp:
	call	putreg		# display register name and value
	loop	regslp
#ifdef REGS32
	movw	(%bp,%si), %dx	# get flags
#else
	movw	USER_FLAGS, %dx
	pushw	%si
	stc			# add trailing =
#endif
	movb	$13, %cl
	rcrw	%cl, %dx
nextbit:
	lodsb
	shlw	$1, %dx
#ifdef REGS32
	jnc	skipflag
	cmpb	$'|', %al	# remove system flags
	je	skipflag
	call	dbgputc
skipflag:
#else
	call	dbgputcbit	# display active flags bits
#endif
	loop	nextbit
#ifdef REGS32
	movw	%sp, %bp
#else
	popw	%si
	movb	$8, %cl
stacklp:
	lodsw			# si += 2
	call	putr16		# display flags and the beginning of the stack
	loop	stacklp
#endif
	call	getline
	lodsb
	xchgw	%ax, %di
	call	getval
	.byte	0x81, 0xC3	# addw	$0, %bx
offset_value:
	.word	0
	movw	%bx, %es
	xchgw	%ax, %di
	subb	$'m', %al
	je	ismove
	subb	$'+'-'m', %al
	jne	not_offset
	movw	%di, ABS(offset_value)
not_offset:
	orb	$1, USER_FLAGS_HIGH	# set TF
	subb	$'t'-'+', %al
	je	done
	subb	$'d'-'t', %al
	xchgw	%ax, %cx
	jcxz	dump		# 'd' ?
	loop	noenter		# 'e' ?
nextval:
	call	getval
	jcxz	dbgregslp
	xchgb	%dl, %dh
mextmsb:
	stosb
	xchgw	%ax, %dx
	xchgb	%al, %dh
#ifdef ADJESDI
	call	adjustESDI
#endif
	decw	%cx
	loopne	mextmsb
	jmp	nextval
noenter:
	loop	not_floppy_load	# f DX:CX ?
	movw	%es, %dx
	movw	%cx, %es
	movw	%di, %cx
	movw	$0x0201, %ax
	movw	$0x7C00, %bx
	pushw	%bx
	int	$0x13
	popw	%di
godbgregslpifc:	
	jc	dbgregslp
dump:
	movw	%es, %ax
	call	putax
	movw	%di, %ax
	call	putax
	movw	$16, %cx
dhex:
	movb	%es:(%di), %ah
#ifdef ASCIIDUMP
	movb	%ah, (%si)
	incw	%si
#endif
#ifdef ADJESDI
	call	incESDI
#else
	incw	%di
#endif
#ifdef REGS32
	movb	$0x30, %dh	# the data has 2 digits
#else
	movb	$0x01, %dh	# the data has 2 digits
#endif
	call	putx
	loop	dhex
#ifdef ASCIIDUMP
	movb	$16, %cl
	subw	%cx, %si
dascii:
	lodsb
	cmpb	$0x7F, %al
	jnc	skipascii
	cmpb	$0x20, %al
	cmc
skipascii:
	call	dbgputcbit
	loop	dascii
#endif
	call	dbgputcr
	int	$0x16
	cmpb	$13, %al
	je	dump
notdump:
not_floppy_load:
	stc
	loop	godbgregslpifc	# g ?
isgo:
	andb	$0xfe, USER_FLAGS_HIGH	# clear TF
	xchgw	%ax, %cx
	jcxz	done
setbreak:
	movb	$OPCODE_BRK, %al
	xchgb	%al, %es:(%di)
	movb	%al, ABS(break)
done:
	popw	%ax  	# %ss
#ifdef REGS32
	popal
	popw	%gs
	popw	%fs
#else
	popaw
#endif
	popw	%es
	popw	%ds
	iret

#ifdef ADJESDI
adjustESDI:
	decw	%di
incESDI:
	incw	%di
	jnz	esok
	pushw	%es
	addb	$0x10,-3(%bp)
	popw	%es
esok:
	ret
#endif

putreg:
	call	dbgput2c
	movb	$'=', %al
	call	dbgputc
putr16:
#ifdef REGS32
	movl	-2(%bp,%si), %eax
	movw	$0x3FC0, %dx	# check bits 7..14
	shrw	%cl, %dx
putax:
	movb	$0xF0, %dh	# the data has 4 digits
	jnc	putx		# 16 bits register ?
	incw	%bp		# a 32 bits register, not 16 bits
	incw	%bp
	movb	$0xFF, %dh	# the data has 8 digits
	jmp	putx
putxlp:  
#else
#	movw	_start-ABS(regs)-2(%bp,%si), %ax
	.byte	0x8b, 0x42, _start-ABS(regs)-2
putax:
	movb	$0x07, %dh	# the data has 4 digits
putx:
putxlp:  
	rolw	$4, %ax
#endif
	pushw	%ax
	andb	$0xf, %al
	addb	$0x90, %al
	daa
	adcb	$0x40, %al
	daa
	call	dbgputc
	popw	%ax
#ifdef REGS32
putx:
	roll	$4, %eax
#endif
	shrb	$1, %dh
	jc	putxlp
#ifdef REGS32
	jnz	putx
#endif
dbgputcbit:
	jc	dbgputc  
	mov	$0x20, %al
dbgputc:
	movw	$7, %bx
	mov	$0xE, %ah
	int	$0x10
	xchgw	%ax, %bx
#	clc				# for putax
	ret

# get value in DX:AX, BX is segment CX is digits count.
getval:
	xorw	%ax, %ax
	xorw	%bx, %bx
	xorw	%cx, %cx
getvalz:
	xchgw	%ax, %bx
	cwd
	decw	%cx
isx:
	shll	$4, %edx
	orb	%al, %dl
	incw	%cx
gotspc:
getvallp:
	lodsb
	cmpb	$0x20, %al		# heat heading spaces
	jne	notspc
	jcxz	gotspc
notspc:
	subb	$'0', %al
	cmpb	$10, %al		# in 0..9 ?
	jb	isx
	subb	$'a'-'0'-10, %al
	cmpb	$16, %al		# in a..f ?
	jb	isx
	cmpb	$':'-'a'+10, %al
	pushl	%edx
	popw	%ax
	popw	%dx
	je	getvalz			# store segment in %bx
	pushw	%dx
	shlw	$12, %dx
	orw	%dx, %bx
	popw	%dx
	ret

getline:
	call	dbgputcr
getlinebs:
	cmpw	$ABS(buffer), %si
	je	getc
	decw	%si
getlinelp:
	call	dbgputc
getc:
	int	$0x16
	cmpb	$8, %al
	je	getlinebs
	orb	$0x20, %al
	movb	%al, (%si)
	inc	%si
	cmpb	$0x2D, %al
	jne	getlinelp
dbgputcr:
	movw	$ABS(crlf), %si
dbgput2c:
	call	dbgput1c
dbgput1c:
	lodsb
	jmp	dbgputc

crlf:
	.byte	13,10
_end:
buffer:

	.org	510
	.byte	0x55, 0xAA

