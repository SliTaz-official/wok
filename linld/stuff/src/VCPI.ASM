;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
;VDPI init:
;Call  char* prepare_vcpi(void *pagebuf)  first to
;initialize paging tables needed for vm86.
;pagebuf needs to be 8k+4 bytes. Returns ptr to 1st unused byte.
;Then call  int get_vcpi_interface().  Returns 1 if ok, 0 if bad.
;
;VCPI use:
;u32* malloc_vcpi(u32 size)  - source in HIMEM.CPP
;  Returns ptr to mallocated zero-terminated list of 4k page addrs
;  Addresses are sorted in ascending order
;  Never fails (will die if not enough mem)
;void read2vcpi(int fd, u32* vp, u32 size,
;void* xfer_buf, u16 xfer_size)  - source in HIMEM.CPP
;  Reads opened fd data into malloc_vcpi'ed memory
;  Dies if file isn't exactly 'size' bytes long
;  Needs intermediate buffer of exactly Nx4k bytes
;void memcpy_vcpi(u32 dstofs,u16 srcseg,u32 srcofs)
;  copies 4k from conventional memory to VCPI
;void _vm2rm()
;  switches you from vm86 to plain real mode


                ideal
		%PAGESIZE 1000
                %crefref
                %noincl
                %nomacs
                p386

;****** Stuff for declaring descriptors
struc   descr
limit           dw    ?
base0           dw    ?
base16          db    ?
type            db    ?
limit16         db    ?
base24          db    ?
ends    descr
macro   descriptor name,typ,plevel,present,limit,gran,base
      ;;name    descr <limit and 0ffffh,base and 0ffffh,low (base shr 16),typ or plevel or present,(limit shr 16) or gran,high (base shr 16)>
        name    descr <limit and 0ffffh,base           ,0                ,typ or plevel or present,(limit shr 16) or gran,0                 >
endm
; decriptor types (bit0..4 of descr.type )
tss386_avail    = 09h
data_seg        = 00010000b   ; data segment
  expand_down   = 00000100b   ; =1 limit counts down from base
  writable      = 00000010b   ; =1 if write access allowed to data segment
code_seg        = 00011000b   ; code segment
  conforming    = 00000100b   ; =1 code can be accesses and executed at any PL
  readable      = 00000010b   ; =1 if code also can be read (cannot be ovwritten)
; privilege levels (bit5..6 of descr.type )
priv0           = 00000000b
priv1           = 00100000b
priv2           = 01000000b
priv3           = 01100000b
; segment present bit (bit7 of descr.type )
is_present      = 10000000b
not_present     = 00000000b
;definition of granularity ( bits6..7 in descr.limit16 )
gran_byte       = 00000000b
gran_page       = 10000000b  ; 4k granularity
use_16          = 00000000b
use_32          = 01000000b

;****** rm32,imm16 helper
macro	movzx_e	rm,i
	db	66h
	mov	rm,i
	dw	0
endm

macro	pushd	sreg
	db	66h
	push	sreg
endm

        group   DGROUP  _TEXT
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'

;***************************************************************
;int get_vcpi_interface();
;****** Return: Z  - page mapping for low 640k is 1:1
;******         NZ - otherwise (it's bad)
;****** Uses:   Flags
;***************************************************************
        ;global  _get_vcpi_interface:near
        proc    _get_vcpi_interface near

                ;push    si di

; Get and save VCPI pm interface
                ;mov     si,offset gdt_vcpi      ;DS:DI => 3 GDT entries for VCPI
                ;mov     di,[si+page0_ofs-gdt_vcpi]          ;ES:DI => page0
                ;push    ds
                ;pop     es
                ;push    di
                ;mov     ax,0DE01h               ;get vcpi pm interface
                int     67h
                xchg    [si+vcpi_pm_entry-gdt_vcpi],ebx	; bx=((640*1024) shr 12)

; Check that mapping for low 640k is 1:1
                pop     si			; [page0_ofs]
                ;cld
		mov	cx,bx
@@map_chk:
		lodsd
		shr	eax,12
		add	ax,cx
		;cmp	eax,ebx			; ((640*1024) shr 12)
		cmp	ax,bx			; ((640*1024) shr 12)
		loope	@@map_chk
		;pop	di si
                ret

        endp    _get_vcpi_interface


;***************************************************************
;char* prepare_vcpi(void *pagebuf);
;****** Return: AX=>first unused byte in pagebuf
;****** Uses:   Flags
;***************************************************************
        global  prepare_vcpi:near
        proc    prepare_vcpi near

;Calculate pagedir/page0 addrs, initialize cr3 and pagedir[0]
;    heap_top = prepare_vcpi(malloc_or_die(8*1024+4)); 

                ;mov     edx,cs
                ;shl     edx,4           ;edx = linear addr of CS
                mov     si,offset gdt_vcpi
; Fix up base of some gdt descriptors
; Note: 'add [dword xx.base0],edx' actually updates 24 bit quantity!
; Do NOT replace with mov!
		mov	bx,10000h-28h
                add     [dword si+sw2pm_addr-gdt_vcpi],edx
                add     [dword si+sw2pm_idtr_ptr-gdt_vcpi],edx
@@fixup:
                add     [dword bx+si+(gdt_code.base0)-gdt_vcpi+28h],edx
		add	bx,8
		js	@@fixup
		mov	bh,10h
		extrn	_heap_top:word
		;movzx	eax,[_heap_top]
		mov	ax,[_heap_top]
		add	ax,bx		; assume _heap_top < 0f000h
                add     eax,edx
		and	ax,0f000h       ;eax = 4k aligned linear addr of pagebuf
                add     [si+sw2pm_cr3-gdt_vcpi],eax	;eax=page0 linear addr
                mov     edi,eax
                sub     edi,edx
                mov     al,3            ;add present+writable bits
                mov     [bx+di],eax     ;stuff it into pagedir[0]
                push    ds
                pop     es              ;es:di->page0,es:di+1000h->pagedir
                        ;page directory will use only one entry (4 bytes):
                        ;cr3 => pagedir => page0  => ########
                        ;      (1 entry)  (1024   => #  4M  #
                        ;                 entries)=> # page #
                        ;                         => ########
; Return
                lea     ax,[bx+di+4]
		mov	[_heap_top],ax
                ;ret
                push    di
                mov     ax,0DE01h               ;get vcpi pm interface
		jmp	_get_vcpi_interface

        endp    prepare_vcpi

		org	$-40
tss             dd      ?,?     ;enough, we'll never use it anyway
label   gdt     byte
gdt_null        descr   <?>     ;0000
gdt_vcpi        descr   <?>     ;0008
gdt_vcpi2       descr   <?>     ;0010
gdt_vcpi3       descr   <?>     ;0018
		org	$-8
	global	gdt_memcpy:descr
gdt_memcpy      descr   <?>	;null + gdt_abs
descriptor      gdt_abs ,(data_seg+writable),priv0,is_present,0fffffh,(gran_page+use_32),0
;Note: code/data segs must be flagged use16 (i.e. use ip/sp, not eip/esp)
;Note: base addrs will be fixed up in prepare_vcpi()
descriptor      gdt_code,(code_seg+readable),priv0,is_present,0fffffh,(gran_page+use_16),0
	global	gdt_data:descr
descriptor      gdt_data,(data_seg+writable),priv0,is_present,0fffffh,(gran_page+use_16),0
descriptor      gdt_tss ,tss386_avail       ,priv0,is_present,0ffh   ,gran_byte         ,<offset tss>
SEL_VCPI        = (gdt_vcpi - gdt_null)
SEL_TSS         = (gdt_tss  - gdt_null)
SEL_ABS         = (gdt_abs  - gdt_null)
SEL_CODE        = (gdt_code - gdt_null)
SEL_DATA        = (gdt_data - gdt_null)

label   gdtr    pword
gdt_lim         dw      0ffffh
gdt_base        dw      offset gdt,0

;Note: layout dictated by vcpi api, don't rearrange!
label sw2pm_params byte
;Note: base addrs will be fixed up in prepare_vcpi()
label	pagedir_laddr   dword
sw2pm_cr3       dd      1000h
sw2pm_gdtr_ptr  dw      offset gdtr,0
sw2pm_idtr_ptr  dw      offset idtr,0
sw2pm_ldtr      dw      0       ;we don't need it
sw2pm_tr        dw      SEL_TSS ;vcpi thinks we need it... can't set to 0
sw2pm_jumpaddr  dw      offset pmode,0
                dw      SEL_CODE

vcpi_pm_entry   dd      ((640*1024) shr 12)
                dw      SEL_VCPI

label   idtr    pword
idt_lim         dw      03ffh   ;we won't enable ints,
idt_base        dd      0       ;  so let's leave it the same as for rm


;***************************************************************
;void memcpy_vcpi(u32 dstofs,u16 srcseg,u32 srcofs);
;***************************************************************
;****** Copies PAGE_SIZE bytes
;****** Uses:   Flags
;***************************************************************
        global  vcpi_pm_copy_routine:near
        proc    vcpi_pm_copy_routine near

struc   pm_regs
$$retaddr       dw      ?
$$edi           dd      ?
$$esi           dd      ?
$$ebp           dd      ?
$$esp           dd      ?
$$ebx           dd      ?
$$edx           dd      ?
$$ecx           dd      ?
$$eax           dd      ?
ends

;***************************************************************
;****** Helper: goes into 16bit pm and calls routine (addr on stk)
;***************************************************************
                mov     bp,sp           ; ss:bp => struct pm_regs

		mov	bx,5		; IRET stack for return to vm
@@push_sreg:
		pushd	ss		; fake pushd gs fs ds es ss
		dec	bx
		jnz	@@push_sreg	;   (9 dwords)
                push    ebp             ; esp
                pushfd                  ; eflags: IF saved here
                pushd   cs              ;
                push    bx              ;\eip
                push    offset vcpi_ret ;/

		mov	edx,esi
switch_to_pm:
		movzx_e	si,<offset sw2pm_params>
		org	$-4
sw2pm_addr	dd	?
                mov     ax,0DE0Ch       ; vcpi: switch to pm
                cli			; load GDTR LDTR TR need 16 bytes in SS:ESP
                int     67h		; EAX, ESI, DS, ES, FS, GS destroyed
pmode:
                assume  nothing
                assume  cs:DGROUP

; Now we are in 16-bit protected mode
		push	SEL_DATA
		pop	ss
		test	bx,bx
		jnz	vm2rm_end

                ;lea     sp,[bp-8-9*4]
                lea     sp,[bp-9*4]

; Call the routine (bp points to params on stack if any)
                call    do_memcpy_vcpi	; set ds=all_addrspace

; Ok, let's return to vm
                mov     ax,0DE0Ch       ; maybe we need whole eax?
                cli     ; to be safe
                clts    ;
; Go to vm86 mode. Sregs, esp, eflags (IF) restored from IRET stack
                call	[pword cs:vcpi_pm_entry]
		ret
                ;jmp	[pword cs:vcpi_pm_entry]

;***************************************************************

;***************************************************************
;****** Helper: This is where real copy is done
;***************************************************************
label   do_memcpy_vcpi near

                push    SEL_ABS
                pop     ds
                push    ds
                pop     es
                assume  nothing
                assume  cs:DGROUP

        ; Set up target addr:
        ; replace page mapping for page at 0 so
        ; that it points to dstofs
		xchg	eax,edi
                mov     al,03h          ; writeable, present
		call	@@set_mapping
                xor     edi,edi         ;es:edi => remapped page

        ; Set up source addr
		mov	esi,edx

        ; Do copying
                db      67h     ;address width override for esi/edi
            rep movsb

@@set_mapping:
                mov     esi,[cs:sw2pm_cr3]
                xchg    [esi-1000h],eax ; restore page0[0]
                mov     esi,cr3         ; reload TLB cache
                mov     cr3,esi         ;
; Return
vcpi_ret:
                ret

        endp    vcpi_pm_copy_routine


;***************************************************************
;void _vm2rm();
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  _vm2rm:far
        proc    _vm2rm far

                assume  cs:DGROUP,ds:DGROUP
                push	ds
		extrn	sssp:dword
		mov	bx,offset sssp
                mov     [bx],sp
                ;mov     [bx+2],ss
                ifdef   QUICK_BOOT
		extrn	_cmdnum:dword
v86boot	=	(byte _cmdnum+24)
		test	[v86boot],bh
		jnz	@vm2rm_ret
		endif
                ifdef NO386
		extrn	_vcpi:byte
		test	[_vcpi],bh
                else
                smsw    ax      ;SMSW cannot be trapped! :-)
                and     al,1	;MSW_PE
                endif
		jz	@vm2rm_ret
		jmp	switch_to_pm	; EAX, ESI, DS, ES, FS, GS destroyed
vm2rm_end:
                assume  nothing
                assume  cs:DGROUP

		;push	ss
		;pop	ds

; Now we are in 16-bit protected mode
; Black magic here
                mov     eax,cr0
                and     eax,7ffffffeh   ; clear PG,P bits
                mov     cr0,eax         ; look mommy, we're in rm now!
                mov     cr3,eax         ; flush TLB cache

; Now we are in rm, but not yet: have to restore sregs:
                lss     sp,[cs:bx]	; SS
@vm2rm_ret:
		pop	ds		; DS
                retf                   	; CS

        endp    _vm2rm

        ends    _TEXT

        end

;###### END OF FILE ############################################
