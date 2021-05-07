// #define RC_NORMALIZE if (Range < kTopValue) { Range <<= 8; Code = (Code << 8) | RC_READ_BYTE; }
//
// #define IfBit0(p) RC_NORMALIZE; bound = (Range >> kNumBitModelTotalBits) * *(p); if (Code < bound)
// #define UpdateBit0(p) Range = bound; *(p) += (kBitModelTotal - *(p)) >> kNumMoveBits;
// #define UpdateBit1(p) Range -= bound; Code -= bound; *(p) -= (*(p)) >> kNumMoveBits;
//
//#define RC_GET_BIT2(p, mi, A0, A1) IfBit0(p) \
//  { UpdateBit0(p); mi <<= 1; A0; } else \
//  { UpdateBit1(p); mi = (mi + mi) + 1; A1; }
//
// #define RC_GET_BIT(p, mi) RC_GET_BIT2(p, mi, ; , ;)
//
// #define RangeDecoderBitTreeDecode(probs, numLevels, res) \
//  { int i = numLevels; res = 1; \
//  do { CProb *p = probs + res; RC_GET_BIT(p, res) } while(--i != 0); \
//  res -= (1 << numLevels); }
/*
 * Compression with : lzma e src dst -eos -pb2 -lp0 -lc3
 */

#define PROP_PB 2
#define PROP_LP 0
#define PROP_LC 3
#define PROPS (PROP_LC+(PROP_LP*9)+(PROP_PB*45))

// static const Byte *Buffer;
// static UInt32 bound, Code, Range;

/*
 * Buffer register DS:SI
 * all var based ws=ss:bp
 */

rep0		=	-4		// long
rep1		=	rep0-4		// long
rep2		=	rep0-8		// long
rep3		=	rep0-12		// long
state		=	-17		// byte, 0..11
posState 	=	state-1		// byte, 0..15
posState2 	=	posState-1	// byte, 0..15
scratched	=	rep0-16		// byte = 1
Code		=	-24		// long
outStream	=	-28		// long
nowPos		=	outStream	// long
Range		=	Code-8		// long
#define LOCALS		32

// int LzmaDecode(CLzmaDecoderState *vs,
//     const unsigned char *inStream, 
//     unsigned char *outStream)
// {
//   CProb *p = vs->Probs;
//   SizeT nowPos = 0;
//   #define posStateMask = (1 << (vs->Properties.pb)) - 1;
//   #define literalPosMask = (1 << (vs->Properties.lp)) - 1;
//   int lc = vs->Properties.lc, state = 0, len = 0;
//   UInt32 rep0 = 1, rep1 = 1, rep2 = 1, rep3 = 1;
// 
//   {
//     UInt32 i, numProbs = Literal /*1846*/
// 	    + ((UInt32)LZMA_LIT_SIZE /*768*/ << (lc + vs->Properties.lp));
//     for (i = 0; i < numProbs; i++) p[i] = kBitModelTotal /*2048*/ >> 1;

#define WS (1846+(768<<(PROP_LC+PROP_LP)))
#if (WS+WS+LOCALS) >= 65000
/* MAX WS = (1846+(768<<(8+4))) > 3MB! */
#error invalid (lc,lp,pb) : out of memory
#endif

ws1	=	WS
ws2	=	ws1*2
ws	=	ws2+LOCALS+15

#ifndef FLAT32
#define	AX	%ax
#define	BX	%bx
#define	CX	%cx
#define	DX	%dx
#define	SI	%si
#define	DI	%di
#define	BP	%bp
#define	SP	%sp
#define CWD	cwd
#else
#define	AX	%eax
#define	BX	%ebx
#define	CX	%ecx
#define	DX	%edx
#define	SI	%esi
#define	DI	%edi
#define	BP	%ebp
#define	SP	%esp
#define CWD	cdq
#endif
/*
 * LzmaDecode:
#ifndef FLAT32
 *   input   ds:si=inStream, es:di=outStream
 *   output  outStream[], ds:si, es:di
 	.code 16
#else
 *   input   esi=inStream, edi=outStream
 *   output  outStream[], esi, edi
 	.code 32
#endif
 */
 
	mov	$ws1, CX
#ifdef ONLY8086
	movw	$2048/2, %ax
lzd1:
	pushw	%ax
#else
lzd1:
	pushw	$2048/2
#endif
	loop	lzd1
	mov	SP, BP
	movb	$((LOCALS+3)/4)*2, %cl
#ifdef ONLY8086
	movw	$1, %ax
	cwd
initlocals:
	pushw	%dx
	pushw	%ax
#else
initlocals:
	pushl	$1
#endif
	loop	initlocals

#if !defined(FLAT32) && !defined(FLAT16OUT)
	movb	$4, %cl
	movw	%es, %bx
	shrw	%cl, %bx
	movw	%es, %dx
	shlw	%cl, %dx
	addw	%dx, %di
	movw	%di, outStream(%bp)
	adcb	%bh, outStream+2(%bp)
	incw	%cx
#else
	movb	$5, %cl
	mov	DI, outStream(BP)
#endif

//   Byte previousByte = 0;
	xor	BX, BX

// #define RC_INIT(buffer) 
//    Buffer = buffer; Code = 0; Range = 0xFFFFFFFF; 
//    { int i; for(i=0; i<5; i++) { Code = (Code<<8) | RC_READ_BYTE; }}
//   }
//   RC_INIT(inStream);

#ifndef NO_LZMA_HEADER
#ifdef CHECK_LZMA_HEADER
	cmp.w	$0x5A4C, (SI)	// lzip header ('LZIP' version:1 dicobits:1)
	je	lzip_header
	cmp.w	$0x5D, (SI)	// lzma header (0x5D dicosz:4 orgsz:8)
	jne	no_header
	add	$13-6, SI	// skip lzma header
lzip_header:
	add	$6, SI		// skip lzip header
no_header:
#else
	add	$13, SI		// skip lzma header (0x5D dicosz:4 orgsz:8)
#endif
#endif
setrep:
	call	RC_LOAD_BYTE
	decb	Range(BP)
	loop	setrep

lzdmainlp:
//   while(1) {
//     CProb *prob;
//     int posState = (int)((nowPos) & posStateMask);
// 
//     prob = p + IsMatch /*0*/ + (state << kNumPosBitsMax /*4*/) + posState;
//     if (Bit0(prob)) { /* char */

	xor	DX, DX
	call	Bit1state	// Bit1(dx + (state << kNumPosBitsMax /*4*/) + posState)
	mov	$state, DI
	jc	lzdstring

//       prob = p + Literal /*1846*/ + (LZMA_LIT_SIZE /*768*/ * 
// 	((((nowPos) & literalPosMask) << lc) + (previousByte >> (8 - lc))));

#if PROP_LC != 0
# ifdef ONLY8086
	movb	$8-PROP_LC, %cl
	shrb	%cl, %bl
# else
	shrb	$8-PROP_LC, %bl
# endif
#else
	xor	%bx,%bx
#endif

#if PROP_LP != 0
	movb	posState2(BP), %dl
# if PROP_LC != 0
#  ifdef ONLY8086
	movb	$PROP_LC, %cl
	shl	%cl, DX
#  else
	shl	$PROP_LC, DX
#  endif
	movb	$0, %bh
# endif
	add	BX, DX
#endif

	movb	$3, %ah
	mul	BX		// dx = 3*bh
	add	$1846, AX

//       int symbol = 1;

	CWD
	inc	DX		// symbol = 1
	xchg	AX, CX		// save prob

//       if (state >= kNumLitStates /*7*/) { /* previous was string */
//       if (state < 4) state = 0;

lzd6z:
	subb	$3, (BP, DI)

//       if (state < 4) state = 0;

	jnc	lzd6
	movb	%dh, (BP, DI)	// %dh = 0

lzd6:
//       else if (state < 10) state -= 3;

	cmpb	$10-3, (BP, DI)
	
//       else state -= 6;

	jnb	lzd6z
	cmpb	$7-3-1, (BP, DI)
	jbe	lzd3
	
//         int matchByte = outStream[nowPos - rep0];

	call	DicoRep02ESDI	// %bl = outStream[nowPos - rep0];
	
//         do {
//           int bit;
//           CProb *probLit;
//           matchByte <<= 1; bit = (matchByte & 0x100);

	movb	$1, %bh
lzd4:
	shlb	$1, %bl			// matchByte <<= 1
	sbb	DI, DI			// save bit=C

//           probLit = prob + 0x100 + bit + symbol;

	mov	CX, AX			// restore prob
	adcb	%bh, %ah		// + bit + 0x100
	
//           RC_GET_BIT2(probLit, symbol, if (bit) break, if (!bit) break)

	call	Bit1axdx		// C,%ax = Bit1(prob+%ax)
	rclb	$1, %dl			// symbol <<= 1; symbol |= C
	jc	lzd5			// if symbol >= 0x100
	cmp	DI, AX
	jz	lzd4			// if bit == Bit1(prob+%ax)

//         } while (symbol < 0x100);
//       }
lzd3:
//       while (symbol < 0x100) {
//         CProb *probLit = prob + symbol;
//         RC_GET_BIT(probLit, symbol)
//       }

	xor	BX, BX
	jmp	lzd4
lzd5:

//       outStream[nowPos++] = previousByte = (Byte)symbol;

	xchg	AX, DX
	call	outchar		// %bl = outStream[nowPos++] = %al;
	jmp	lzdmainlp

//     }

lzdstring:
	mov	$1, CX

//     else { /* string */
//       prob = p + IsRep /*192*/ + state;

	movb	$192, %dl
	addb	(BP, DI), %dl
	mov	$rep0, DI

//       if (Bit0(prob)) {

	call	Bit1dx		// Bit1(prob)
 	jc	lzd8

//         rep3 = rep2; rep2 = rep1; rep1 = rep0;
//         state = (state < kNumLitStates /*7*/) ? 0 : 3;

	stc

//         prob = p + LenCoder /*818*/;

	mov	$818, DX

//       }

	jmp	lzd11a

//       else {
lzd8:
//         prob += kNumStates /*12*/;
//         if (Bit0(prob)) {
	call	Bit1dx12	// prob += 12; Bit1(prob)
	jc	lzd11
//           prob = p + IsRep0Long /*240*/ + (state << kNumPosBitsMax /*4*/) 
// 		   + posState;
	movb	$240, %dl	// dh=0

//           if (Bit0(prob)) {

	call	Bit1state	// Bit1(dx + (state << kNumPosBitsMax /*4*/) + posState)
	jc	lzd12

//             // if (nowPos == 0) return LZMA_RESULT_DATA_ERROR;
//             state = (state < kNumLitStates /*7*/) ? 9 : 11;

	movb	$9, %dl

//             len++; goto string;
	jmp	lzd13string	// ax = 0
//           }
//         }
//         else {
lzd11:
//           UInt32 distance = rep1;
//           prob += kNumStates /*12*/;
//           if (!Bit0(prob)) {

	call	Bit1dx12	// prob += 12; Bit1(prob)
	jnc	lzd11z

//             prob += kNumStates /*12*/;
//             if (Bit0(prob)) distance = rep2;

	call	Bit1dx12	// prob += 12; Bit1(prob)
lzd11a:
	adcb	%cl, %cl
	
//             else { distance = rep3; rep3 = rep2; }
//             rep2 = rep1;
//           }
//           rep1 = rep0; rep0 = distance;

lzd11z:
# ifdef ONLY8086
	shl	$1, CX
	shl	$1, CX		// 8->32 bits
	sub	CX, DI		// &rep[cx]
	movw	(BP, DI), %ax
	pushw	2(BP, DI)
rotreplp:
	movb	4(BP, DI), %bl
	movb	%bl, (BP, DI)
	inc	DI
	loop	rotreplp
	popw	%bx
	testb	%dh, %dh
	jnz	lzd10
	movw	%ax, (BP, DI)
	movw	%bx, 2(BP, DI)
# else
	shl	$2, CX		// 8->32 bits
	sub	CX, DI		// &rep[cx]
	movl	(BP, DI), %eax
rotreplp:
	movb	4(BP, DI), %bl
	movb	%bl, (BP, DI)
	inc	DI
	loop	rotreplp
	testb	%dh, %dh
	jnz	lzd10
	movl	%eax, (BP, DI)
# endif

//         }
lzd12:
//         state = (state < kNumLitStates /*7*/) ? 8 : 11;

	movb	$0x08, %cl

//         prob = p + RepLenCoder /*1332*/;

	mov	$1332, DX

//       }
lzd10:
	push	CX		// CX = 0

//       { /* get len */
//         int numBits, offset;
//         CProb *probLen = prob + LenChoice /*0*/;
//         numBits = kLenNumLowBits /*3*/;

	movb	$8, %cl		// numBits : 3,3,8

//         if (Bit0(probLen)) {

	call	Bit1dx		// Bit1(prob)
	xchg	AX, BX
	inc	DX
	jnc	lzd15		// bx=0

//           probLen = prob + LenLow/*2*/ + (posState << kLenNumLowBits/*3*/);
//           offset = 0;
//         }
//         else {
//           probLen = prob + LenChoice2 /*1*/;

	call	Bit1dx		// Bit1(prob)
	add	AX, BX

#if PROP_PB != 0
	inc	AX		// ah=0
#endif
	jc	lzd16		// %ax=0, %bx=-2 
lzd15:
#if PROP_PB != 0
	movb	$8, %al
	mulb	posState(BP)
#endif

//           if (Bit0(probLen)) {
//             probLen = prob + LenMid/*130*/ + (posState << kLenNumMidBits/*3*/);

	movb	$3, %cl		// numBits : 3,3,8
lzd16:
#if PROP_PB != 0
	add	$2-128-1, AX	// probLen : 2,130,258
#else
	mov	$2-128-1, AX	// probLen : 2,130,258
#endif
	add	DX, AX
	mov	$-8+1, DX	// offset  : 0,8,16
lzdargslp:
	add	$8, DX
	add	$128, AX
	inc	BX
	jle	lzdargslp	// leave with bx=1

//             offset = kLenNumLowSymbols /*8*/;
//             //numBits = kLenNumMidBits /*3*/;
//           }
//           else {
//             probLen = prob + LenHigh /*258*/;
//             offset = kLenNumLowSymbols /*8*/ + kLenNumMidSymbols /*8*/;
//             numBits = kLenNumHighBits /*8*/;
//           }
//         }
//         RangeDecoderBitTreeDecode(probLen, numBits, len); len += offset;

	push	DX
	call	RangeDecoder	// %ax=probs, %cx=numLevels, %ax=res
	pop	DX
	add	DX, AX		// offset
	pop	DX		// 0
lzd13string:
	push	AX

// state = (state < kNumLitStates /*7*/) ? dl : dl|3;

	movb	$7, %cl
	cmpb	%cl, state(BP)
	jb	new_state
	orb	$3, %dl
new_state:
	movb	%dl, state(BP)

//       } /* get len */
//       if (state < 4) {

	cmpb	$4-1, %dl
	ja	lzd19

//         int posSlot;
//         state += kNumLitStates /*7*/;

	addb	%cl, state(BP)

//         prob = p + PosSlot /*432*/ + (((len < kNumLenToPosStates /*4*/) ? 
// 		len : kNumLenToPosStates - 1) << kNumPosSlotBits /*6*/);

	cmp	$4+1, AX
	jb	lzd21
	mov	$3+1, AX

lzd21:

	dec	CX		// cx = 6
	shl	%cl, AX
	add	$432-64, AX

//         RangeDecoderBitTreeDecode(prob, kNumPosSlotBits /*6*/, posSlot);

	call	RangeDecoder	// %ax=probs, %cx=numLevels, %ax=res

//         if (posSlot >= kStartPosModelIndex /*4*/) {
//           int numDirectBits = ((posSlot >> 1) - 1);

#ifndef FLAT32
	movw	%cx, 2(%bp, %di)	// %cx = 0
#endif
	mov	AX, (BP, DI)
	mov	AX, CX
	shrw	$1, CX
	dec	CX
	cmpb	$4, %al
	jb	lzd22

//           rep0 = (2 | ((UInt32)posSlot & 1));

	andb	%bl, (BP, DI)		// %bx=1
	orb	$2, (BP, DI)

//           if (posSlot < kEndPosModelIndex /*14*/) {

	cmpb	$14, %al
	jnb	lzd23

//             rep0 <<= numDirectBits;

	neg	AX
# ifdef ONLY8086
	pushw	%cx
	movb	$0, %ch
shllrep0:
	shlw	$1, (BP, DI)
	rclw	$1, 2(BP, DI)
	loop	shllrep0
	popw	%cx
# else
	shll	%cl, (BP, DI)
# endif
	add	(BP, DI), AX

//             prob = p + SpecPos /*688*/ + rep0 - posSlot - 1;

	add	$687, AX
	jmp	lzd24

//           }
//           else {
lzd23:
//             numDirectBits -= kNumAlignBits /*4*/;
//             do {
//               RC_NORMALIZE; Range >>= 1; rep0 <<= 1;
//               if (Code >= Range) { Code -= Range; rep0 |= 1; }

lzd23z:
	call	RC_NORMALIZE
# ifdef ONLY8086
	pushw	%dx
	shrw	$1, Range+2(BP)
	rcrw	$1, Range(BP)
	movw	Range(BP), %ax
	movw	Range+2(BP), %dx
	cmpw	Code+2(BP), %dx
	ja	lzd25
	jb	lzd25x
	cmpw	Code(BP), %ax
	ja	lzd25
lzd25x:
	subw	%ax, Code(BP)
	sbbw	%dx, Code+2(BP)
	stc
lzd25:
	popw	%dx
	rclw	$1, (BP, DI)
	rclw	$1, 2(BP, DI)
# else
	shrl	$1, Range(BP)
	movl	Range(BP), %eax
	cmpl	Code(BP), %eax
	ja	lzd25
	subl	%eax, Code(BP)
	stc
lzd25:
	rcll	$1, (BP, DI)
# endif

//             } while (--numDirectBits != 0);

	cmpb	$4+1, %cl
	loopne	lzd23z

//             prob = p + Align /* 802 */; numDirectBits = kNumAlignBits /*4*/;
//             rep0 <<= numDirectBits;

# ifdef ONLY8086
	pushw	%cx
	movb	$0, %ch
shlrep0:
	shlw	$1, (BP, DI)
	rclw	$1, 2(BP, DI)
	loop	shlrep0
	popw	%cx
# else
	shll	%cl, (BP, DI)
# endif
	mov	$802, AX
//           }

lzd24:
	call	RangeDecoder	// %ax=probs, %cx=numLevels, %ax=res

//           {
//             int i = 1, mi = 1;
//             do {
//               CProb *prob3 = prob + mi;
//               RC_GET_BIT2(prob3, mi, ; , rep0 |= i);

	orb	%dh, (BP, DI)	// update rep0 with DirectBits

//               i <<= 1;
//             } while(--numDirectBits != 0);
//           }
//         } else rep0 = posSlot;
lzd22:
//         if (++rep0 == (UInt32)(0)) break; /* EOF */

# ifdef ONLY8086
	incw	(BP, DI)
	jnz	lzd19
	incw	2(BP, DI)
# else
	incl	(BP, DI)
# endif

lzd19:
	pop	CX
	jz	lzdone

//       }
//       len += kMatchMinLen;/*2*/

	inc	CX

//     string: // if (rep0 > nowPos) return LZMA_RESULT_DATA_ERROR;
//       do {
lzd13z:
//         previousByte = outStream[nowPos - rep0];
//         outStream[nowPos++] = previousByte;

	call	outcharDico 	// %bl = outStream[nowPos++] = outStream[nowPos - rep0]

//       } while(--len != 0);

	loop	lzd13z

//     } /* char/string */
//   }

	jmp	lzdmainlp

lzdone:
//   //RC_NORMALIZE;
//   //*inSizeProcessed = (SizeT)(Buffer - inStream); *outSizeProcessed = nowPos;
//   return LZMA_RESULT_OK;
	call	Dico2ESDI	// set es & di (rep0 = 0)
	lea	ws2(BP), SP	// dealloc
	ret	
// }

// al = outStream[nowPos - rep0];

/*
 * output  es:di, al
 * scratch bh, cl, flags
 */

DicoRep02ESDI:
	stc

// bl = outStream[nowPos];

/*
 * output  es:di, bl
 * scratch bh, cl, flags
 */
 
Dico2ESDI:
#if !defined(FLAT32) && !defined(FLAT16OUT)
# ifdef ONLY8086
	pushw	%ax
	movw	nowPos(%bp), %bx
	movw	nowPos+2(%bp), %ax
	jnc	Dico2ESDIz
	subw	rep0(%bp), %bx
	sbbw	rep0+2(%bp), %ax
Dico2ESDIz:
	movw	$0xF, %di
	andw	%bx, %di
	pushw	%cx
	movb	$4, %cl
	shrw	%cl, %bx
	shlw	%cl, %ax
	popw	%cx
	addb	%al, %bh
	popw	%ax
# else
	movl	nowPos(%bp), %ebx
	jnc	Dico2ESDIz
	subl	rep0(%bp), %ebx
Dico2ESDIz:
	movw	%bx, %di
	xorw	%bx, %bx
	shrl	$4, %ebx
# endif
	movw	%bx, %es
#else
	mov	nowPos(BP), DI
	jnc	Dico2ESDIz
	sub	rep0(BP), DI
Dico2ESDIz:
#endif
#ifdef FLAT32
	movb	(DI), %bl
#else
	movb	%es:(%di), %bl
#endif
	ret

outcharDico:

// bl = outStream[nowPos++] = outStream[nowPos - rep0]

/*
 * output  es:di, bl
 * update  nowPos
 * scratch ax, dx, bh, cl, flags
 */

	call	DicoRep02ESDI	// %bl = outStream[nowPos - rep0]
	xchg	AX, BX
outchar:

// bl = outStream[nowPos++] = previousByte = al;

/*
 * output  bl
 * update  nowPos
 * scratch ax, dx, bh, di, cl, flags
 */

	clc
	call	Dico2ESDI
	stosb
	xchg	AX, BX		// previous byte

//	int posState = (int)((nowPos) & posStateMask);

#if PROP_PB != 0 && PROP_LP != 0
	addw	$0x0101, posState2(BP)
	andb	$(((1 << PROP_PB) -1)<<8)+((1 << PROP_LP) -1), posState2(BP)
#else
# if PROP_PB != 0
	incb	posState(BP)
	andb	$((1 << PROP_PB) -1), posState(BP)
# endif
# if PROP_LP != 0
	incb	posState2(BP)
	andb	$((1 << PROP_LP) -1), posState2(BP)
# endif
#endif
#ifdef ONLY8086
	incw	nowPos(BP)
	jnz	incnowPosDone
	incw	nowPos+2(BP)
incnowPosDone:
#else
	incl	nowPos(BP)
#endif
	ret

//  
// #define RC_NORMALIZE if (Range < kTopValue) 
//    { Range <<= 8; Code = (Code << 8) | RC_READ_BYTE; }

/*
 * update  Range, Code, ds:si
 * scratch flags
 */

RC_NORMALIZE:
	cmpb	$0, Range+3(BP)
	jne	RC_NORMALIZE_1
RC_LOAD_BYTE:
	push	AX
#ifdef ONLY8086
	movw	Range+1(BP), %ax
	movw	%ax, Range+2(BP)
	movw	Code+1(BP), %ax
	movw	%ax, Code+2(BP)
	xorw	%ax, %ax
	movb	Range(BP), %ah
	movw	%ax, Range(BP)
	movb	Code(BP), %ah
	movw	%ax, Code(BP)
#else
	shll	$8, Range(BP)
	shll	$8, Code(BP)
#endif
#if !defined(FLAT16) && !defined(FLAT32)
	testw	%si, %si
	jns	RC_READ_BYTE
	movw	%ds, %ax
	incw	%ax
	movw	%ax, %ds
	addw	$-16, %si
RC_READ_BYTE:
#endif
	lodsb
	movb	%al, Code(BP)
	pop	AX
RC_NORMALIZE_1:
	ret

// Bit1(dx + (state << kNumPosBitsMax /*4*/) + posState)

Bit1state:
	movb	$16, %al
	mulb	state(BP)
# if PROP_PB != 0
	addb	posState(BP), %al
# endif
Bit1axdx:
	add	DX, AX
	jmp	Bit1

// prob += 12; Bit1(prob)

Bit1dx12:
	add	$12, DX
Bit1dx:
	mov	DX, AX

// static int Bit1(CProb *p)

Bit1:
/*
 * input   ax=p
 * output  C, ax
 * update  bound, Range, Code, ds:si
 * scratch flags
 */
 
// {
// 	RC_NORMALIZE;

	call  RC_NORMALIZE		// kill %ax, update %si

#ifdef ONLY8086
	pushw	%ax
	pushw	%cx
	pushw	%dx
	pushw	%di
#else
	pushal
#endif

	xchg	AX, DI
	add	DI, DI			// short *
	

// 	bound = (Range>>kNumBitModelTotalBits /*11*/) * *(p);

#ifdef ONLY8086
	movw	Range(BP), %dx
	movw	Range+2(BP), %ax
	movw	$11, %cx
shr11lp:
	shrw	$1, %ax
	rcrw	$1, %dx
	loop	shr11lp
	movw	%dx, %cx
	mulw	(BP, DI)
	xchgw	%ax, %cx
	mulw	(BP, DI)
	addw	%cx, %dx
#else
	movl	Range(BP), %eax
	shrl	$11, %eax
	movzwl	(BP, DI), %edx
	mull	%edx
#endif

// 	if (Code < bound) {

#ifdef ONLY8086
	cmpw	Code+2(BP), %dx
	jb	Bit1_1
	ja	Bit1_1x
	cmpw	Code(BP), %ax
	jbe	Bit1_1
Bit1_1x:

//    		Range = bound;

	movw	%ax, Range(BP)
	movw	%dx, Range+2(BP)
#else
	cmpl	Code(BP), %eax
	jbe	Bit1_1

//    		Range = bound;

	movl	%eax, Range(BP)
#endif

// 		*(p) += (kBitModelTotal /*2048*/ - *(p)) >> kNumMoveBits /*5*/;

	movw	$2048, %ax

// 		return 0;

	jmp	Bit1_2

//	}
// 	else {

Bit1_1:

//    		Range -= bound; Code -= bound;

#ifdef ONLY8086
	subw	%ax, Range(BP)
	sbbw	%dx, Range+2(BP)
	subw	%ax, Code(BP)
	sbbw	%dx, Code+2(BP)
#else
	subl	%eax, Range(BP)
	subl	%eax, Code(BP)
#endif

// 		*(p) -= (*(p)) >> kNumMoveBits /*5*/;

	movw	$31, %ax

// 		return 1;

	stc
Bit1_2:
	pushf
	subw	(BP, DI), %ax
#ifdef ONLY8086
	movb	$5, %cl
	sarw	%cl, %ax
#else
	sarw	$5, %ax
#endif
	addw	%ax, (BP, DI)
	popf
#ifdef ONLY8086
	popw	%di
	popw	%dx
	popw	%cx
	popw	%ax
#else
	popal
#endif
	sbb	AX, AX

// 	}
// }

	ret

RangeDecoder:

/*
 * input   ax=probs cx=numLevels (< 8) bx=1
 * output  ax=res (backward), dh (forward)
 * update  bound, Range, Code, ds:si
 * scratch flags, cx=0, dl
 */
 
	push	BX
	
//   { int i = numLevels; res = 1; 
	mov	BX, DX		// res = 1
	
//   do { CProb *p = probs + res; RC_GET_BIT(p, res) } while(--i != 0); 

RangeDecoder_1:
	push	AX
	call	Bit1axdx		// C,%ax = Bit1(prob+%ax)
	rclb	$1, %dl			// res <<= 1; res |= C
	andb	%bl, %al		// current bit
	orb	%al, %bh		// store in bh
	shlb	$1, %bl			// update max
	pop	AX
	loop	RangeDecoder_1

//   res -= (1 << numLevels); }

	xchg	AX, BX			// move bh to dh
	xchg	AX, DX			// and dl to al
	sub	%dl, %al		// sub max
	pop	BX
	ret
