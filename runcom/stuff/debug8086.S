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

#define ADJESDI		16 bytes	add segment overflow support for e and d
#define ASCIIDUMP	20 bytes	display hexa and ascii datas
#define INPUTBUFFER	 2 bytes	overload init code with a 32+ bytes input buffer
//#define CPU186       -26 bytes	80186+ CPU

.macro pusham
	pushw	%ax
	pushw	%cx
	pushw	%dx
	pushw	%bx
	movw	%sp, %bx
	leaw	14(%bx), %bx	# adjust SP with [FLAGS CS IP AX CX DX BX] size
	pushw	%bx	# %sp
	pushw	%bp
	pushw	%si
	pushw	%di
.endm

.macro popam
	popw	%di
	popw	%si
	popw	%bp
	popw	%ax	# %sp
	popw	%bx
	popw	%dx
	popw	%cx
	popw	%ax
.endm

#ifdef INPUTBUFFER
//#define ABS(x)		(x-(setvectors-_start))
#define ABS(x)		(x-30)
#else
#define ABS(x)		(x)
#endif

#define SEGREGSZ	6
#define REGSZ	16
#define USER_SP		REGSZ+SEGREGSZ-10(%bp)
#define USER_FLAGS	REGSZ+SEGREGSZ+4(%bp)
#define USER_FLAGS_HIGH	REGSZ+SEGREGSZ+5(%bp)
#define USER_IP		REGSZ+SEGREGSZ(%bp)
#define USER_CS		REGSZ+SEGREGSZ+2(%bp)
#define USER_CSIP	REGSZ+SEGREGSZ(%bp)

.macro initcode
	movw	$0x0FC0, %di	# move (and jump) to 0FC0:0000
	subw	$_startz-_start, USER_IP
	movw	USER_IP, %ax
#ifdef CPU186
	cld			# ensure movsb will work
	shrw	$4, %ax		# _start MUST be aligned on paragraph
#else
	movb	$4, %cl
	shrw	%cl, %ax	# _start MUST be aligned on paragraph
#endif
	addw	USER_CS, %ax	# normalize %cs to have _start=0
	movw	%ax, %ds
.endm
	.text
	.code16
#ifdef CPU186
	.arch	i186
#else
	.arch	i8086
#endif
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
	movw	$setvectors, %si
	jmp	moveself
#endif

setvectors:
	xorw	%si, %si	# set interrupt vectors in 0 segment
	movw	%si, %ds
	movb	$0xF9, %ch	# skip nmi
hooklp:				# interrupts: 0=div0 1=step 2=nmi 3=brk 4=ov 5=bound 6=invalid
	movw	$ABS(dbgstart), (%si)	# set %cs:dbgstart
	lodsw			# %si += 2
	movw	%cs, (%si)	# to interrupt vector
skiphook:
	lodsw			# %si += 2
	shrb	$1,%ch
	jnc	skiphook
	jnz	hooklp		# note %cx will be cleared: SP will be untouched
#ifdef CPU186
	decw	(3-7)*4(%si)	# update int3 vector
#else
	movb	$ABS(int3), (3-7)*4(%si)	# update int3 vector
#endif
	jmp	dbgstartz	# registers are already pushed by startup code

regs:
	.ascii	"ss"
	.ascii	"es"
	.ascii	"ds"  
	.ascii	"di"  
	.ascii	"si"  
	.ascii	"bp"  
	.ascii	"sp"  
	.ascii	"bx"  
	.ascii	"dx"  
	.ascii	"cx"  
	.ascii	"ax"  
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
	.ascii	"oditsz?a?p c="	# flags bits

int3:
#ifdef CPU186
	.byte	0x68		# push $0x086A	OV UP DI NT PL ZR - NA - PO - NC
# interrupt entry point: the registers [FLAGS CS IP] are already pushed
dbgstart:
	.byte	0x6A, 0x08	# push $0x08	NV UP DI NT PL NZ - NA - PO - NC
	popf
init:
	pushaw		#    [FLAGS CS IP] AX CX DX BX SP BP SI DI [DS ES SS]
#else
	stc
	.byte	0x73		# jnc
# interrupt entry point: the registers [FLAGS CS IP] are already pushed
dbgstart:
	clc
	pushw	%ax
	sbbw	%ax,%ax		# copy CF to SF
	clc
	popw	%ax
init:
	cld			# ensure movsb will work
	pusham		#    [FLAGS CS IP] AX CX DX BX SP BP SI DI [DS ES SS]
#endif
	pushw	%ds
	pushw	%es
	pushw	%ss
	movw	%sp, %bp
#ifdef CPU186
	pushf
	addw	$6, USER_SP	# adjust SP with [FLAGS CS IP] size
	popf
#endif
	jc	isinit
	jns	notint3
	decw	USER_IP
	lesw	USER_CSIP, %di
#define OPCODE_BRK     0xCC
	.byte	0xB0		# movb $IM, %al
break:
	.byte	0xCC
	stosb
notint3:
dbgstartz:
dbgregslp:
	call	getcmd
	.byte	0x81, 0xC3	# addw	$0, %bx
offset_value:
	.word	0
	movw	%bx, %es
	xchgw	%ax, %di
	subb	$'m', %al
	jne	isinotmove
#ifdef INPUTBUFFER
ismove:
	xchgw	%ax, %si
moveself:
#else
isinit:
	jmp	ismove
	initcode
ismove:
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

isinotmove:
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
	movb	$0x01, %dh	# the data has 2 digits
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
	popw	%es
	popw	%ds
#ifdef CPU186
	popaw
#else
	popam
#endif
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
#	movw	_start-ABS(regs)-2(%bp,%si), %ax
	.byte	0x8b, 0x42, _start-ABS(regs)-2
putax:
	movb	$0x07, %dh	# the data has 4 digits
putx:
putxlp:  
#ifdef CPU186
	rolw	$4, %ax
#else
	pushw	%cx
	movb	$4, %cl
	rolw	%cl, %ax
	popw	%cx
#endif
	pushw	%ax
	andb	$0xf, %al
	addb	$0x90, %al
	daa
	adcb	$0x40, %al
	daa
	call	dbgputc
	popw	%ax
	shrb	$1, %dh
	jc	putxlp
dbgputcbit:
	jc	dbgputc  
	mov	$0x20, %al
dbgputc:
	movw	$7, %bx
	mov	$0xE, %ah
	int	$0x10
	xchgw	%ax, %bx
	ret

getline:
	movw	$ABS(regs), %si
	movw	$13, %cx
regslp:
	call	putreg		# display register name and value
	loop	regslp
	movw	USER_FLAGS, %dx
	pushw	%si
	movb	$13, %cl
	stc			# add trailing =
	rcrw	%cl, %dx
nextbit:
	lodsb
	shlw	$1, %dx
	call	dbgputcbit	# display active flags bits
	loop	nextbit
	popw	%si
	movb	$8, %cl
stacklp:
	lodsw			# si += 2
	call	putr16		# display flags and the beginning of the stack
	loop	stacklp
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

getcmd:
	pushw	%cs
	popw	%ds
	call	getline
	lodsb
	xchgw	%ax, %di
# get value in DX:AX, BX is segment CX is digits count.
getval:
	xorw	%bx, %bx
	xorw	%cx, %cx
getvalz:
	pushw	%bx			# save segment
	xorw	%bx, %bx
	mul	%bx			# clear %dx:%ax
	decw	%cx
isx:
	incw	%cx
	orb	$0xE0, %dh
getvalbit:
	shlw	$1, %bx
	rclw	$1, %dx
	jc	getvalbit
	orb	%al, %bl
gotspc:
	lodsb
	cmpb	$0x20, %al		# space ?
	jne	notspc
	jcxz	gotspc
notspc:
	sub	$'0', %al
	cmpb	$10, %al		# in 0..9 ?
	jb	isx
	sub	$'a'-'0'-10, %al
	cmpb	$16, %al		# in a..f ?
	jb	isx
	cmpb	$':'-'a'+10, %al
	popw	%ax
	je	getvalz			# store segment in %bx
	xchgw	%ax, %bx
	pushw	%dx
#ifdef CPU186
	shlw	$12, %dx
#else
	pushw	%cx
	movb	$12, %cl
	shlw	%cl, %dx
	popw	%cx
#endif
	addw	%dx, %bx
	popw	%dx
	ret

crlf:
	.byte	13,10
_end:
buffer:

	.org	510
	.byte	0x55, 0xAA

