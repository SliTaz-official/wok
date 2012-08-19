/*
 * Lz4Decode:
#ifndef FLAT32
 *   input   ds:si=inStream, es:di=outStream
 *   output  outStream[], ds:si, es:di
	.code16
#else
 *   input   esi=inStream, edi=outStream
 *   output  outStream[], esi, edi
	.code32
#endif
 */
 
#define ARCHIVE_MAGICNUMBER 0x184C2102

lz4main:
	cld
	lodsl			// get chunkSize
	cmpl	$ARCHIVE_MAGICNUMBER, %eax
	je	lz4main
	orl	%eax, %eax	// end of file ?
	je	lz4quit
	xchgl	%eax, %edx
lz4chunk:			// uncompress chunk
	lodsb			// get token
	decl	%edx
	movzbl	%al, %ebx
	shrb	$4, %al
	call	lz4len		// get literal length, %eax < 255
	incl	%ecx
	stc
	sbbl	%ecx, %edx
	pushf	
	call	lz4mov		// copy literals
	popf
	js	lz4main
	lodsw			// get string address
#ifndef FLAT32
	pushw	%bx
	movw	%di, %bx
	subl	%eax, %ebx
	popw	%ax
	call	lz4len		// get string length
	pushw	%ds
	pushw	%si
	pushw	%es
	popw	%ds
	movw	$0xF, %si
	andw	%bx, %si
	shrl	$4, %ebx
	addl	$4+1, %ecx
	movw	%bx, %bp
	call	lz4mov2		// copy string
	popw	%si
	popw	%ds
#else
	negl	%eax
	xchgl	%eax, %ebx
	addl	%edi, %ebx
	call	lz4len		// get string length
	pushl	%esi
	xchgl	%ebx, %esi
	call	lz4mov		// copy string
	popl	%esi
#endif
	jmp	lz4chunk

lz4len:				// get length in %ecx
	andl	$0xF, %eax
	movl	%eax, %ecx
	cmpb	$0xF, %al
	jne	lz4quit
lz4len2:
	lodsb
	decl	%edx		// remaining chunk size
	addl	%eax, %ecx
	cmpb	$0xFF, %al
	je	lz4len2
lz4quit:
	ret

lz4movlp:
	movsb
#ifndef FLAT32
	movw	$0x800, %bp
	orw	%di, %di
	jns	lz4di
	subw	$0x8000, %di
	movw	%es, %ax
	addw	%bp, %ax
	movw	%ax, %es
lz4di:
	orw	%si, %si
	jns	lz4si
	subw	$0x8000, %si
lz4mov2:
	movw	%ds, %ax
	addw	%bp, %ax
	movw	%ax, %ds
lz4si:
#endif
lz4mov:
	decl	%ecx
	jnz	lz4movlp
	ret
