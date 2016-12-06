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

;****** rm32,imm16 helpers
macro   movzx_e rm,i
        db      66h
        mov     rm,i
        dw      0
endm
macro   addzx_e rm,i
        db      66h
        add     rm,i
        dw      0
endm


        group   DGROUP  _TEXT,_DATA
        assume  cs:DGROUP,ds:DGROUP

        segment _DATA byte public use16 'DATA'

tss             dd      0,0     ;enough, we'll never use it anyway

label   gdt     byte
gdt_null        descr   <?>     ;0000
gdt_vcpi        descr   <?>     ;0008
gdt_vcpi2       descr   <?>     ;0010
gdt_vcpi3       descr   <?>     ;0018
descriptor      gdt_abs ,(data_seg+writable),priv0,is_present,0fffffh,(gran_page+use_32),0
;Note: code/data segs must be flagged use16 (i.e. use ip/sp, not eip/esp)
;Note: base addrs will be fixed up in prepare_vcpi()
descriptor      gdt_code,(code_seg+readable),priv0,is_present,0fffffh,(gran_page+use_16),0
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
label   idtr    pword
idt_lim         dw      03ffh   ;we won't enable ints,
idt_base        dd      0       ;  so let's leave it the same as for rm

;Note: layout dictated by vcpi api, don't rearrange!
label sw2pm_params byte
;Note: base addrs will be fixed up in prepare_vcpi()
sw2pm_cr3       dd      ?
sw2pm_gdtr_ptr  dw      offset gdtr,0
sw2pm_idtr_ptr  dw      offset idtr,0
sw2pm_ldtr      dw      0       ;we don't need it
sw2pm_tr        dw      SEL_TSS ;vcpi thinks we need it... can't set to 0
sw2pm_jumpaddr  dd      ?
                dw      SEL_CODE

;Pagedir/page0 addrs: linear, seg:0 and cs:ofs
pagedir_laddr   dd      ?
page0_laddr     dd      ?
;;pagedir_seg     dw      ?
;;page0_seg       dw      ?
pagedir_ofs     dw      ?
page0_ofs       dw      ?

vcpi_pm_entry   dd      ?
                dw      SEL_VCPI

label   saved_ss_sp dword
saved_sp        dw      ?
saved_ss        dw      ?


        ends    _DATA


        segment _TEXT byte public use16 'CODE'

;***************************************************************
;char* prepare_vcpi(void *pagebuf);
;****** Return: AX=>first unused byte in pagebuf
;****** Uses:   Flags
;***************************************************************
        global  _prepare_vcpi:near
        global  prepare_vcpi:near
        proc    _prepare_vcpi near

                ;pop     ax
                ;pop     bx		;pgbuf
                ;push    bx
                ;push    ax
prepare_vcpi:
                ;push    esi
                ;push    es

;Calculate pagedir/page0 addrs, initialize cr3 and pagedir[0]
                xor     eax,eax
;    heap_top = prepare_vcpi(malloc_or_die(8*1024+4)); 
		mov	cx,8*1024+4
                extrn   malloc_or_die:near
		call	malloc_or_die

		mov	cl,4
                mov     edx,cs
                shl     edx,cl          ;ebx = linear addr of CS
                mov     bx, offset page0_laddr
; Fix up base of some gdt descriptors
; Note: 'add [dword xx.base0],edx' actually updates 24 bit quantity!
; Do NOT replace with mov!
                add     [dword bx+gdt_base-page0_laddr],edx
                add     [dword bx+sw2pm_gdtr_ptr-page0_laddr],edx
                add     [dword bx+sw2pm_idtr_ptr-page0_laddr],edx
                add     [dword bx+(gdt_code.base0)-page0_laddr],edx
                add     [dword bx+(gdt_data.base0)-page0_laddr],edx
                add     [dword bx+(gdt_tss.base0)-page0_laddr],edx
                add     eax,edx
                mov     esi,0FFFh
                add     eax,esi
		inc	si		;esi=00001000h

                shr     eax,cl
                mov     al,0   ;eax = 4k aligned linear addr of pagebuf
                mov     es,ax           ;es:0->page0,es:1000h->pagedir
                shl     eax,cl          ;eax=page0 linear addr
                mov     [bx+page0_laddr-page0_laddr],eax
                mov     al,3            ;add present+writable bits
                mov     [es:si],eax     ;stuff it into pagedir[0]

                add     eax,esi
		mov	al,0
                mov     [bx+pagedir_laddr-page0_laddr],eax
                        ;page directory will use only one entry (4 bytes):
                        ;cr3 => pagedir => page0  => ########
                        ;      (1 entry)  (1024   => #  4M  #
                        ;                 entries)=> # page #
                        ;                         => ########
                mov     [bx+sw2pm_cr3-page0_laddr],eax
                sub     eax,edx         ;ax = offset in CS of pagedir
                mov     [bx+pagedir_ofs-page0_laddr],ax
                sub     ax,si   ;ax-=1000
                mov     [bx+page0_ofs-page0_laddr],ax
                push    ds
                pop     es
                mov     di,ax          ;ES:DI => page0
; Return
                ;pop     es
                ;pop     esi
                add     ax,1004h
		extrn	_heap_top:word
		mov	[_heap_top],ax
                ;ret

        endp    _prepare_vcpi


;***************************************************************
;int get_vcpi_interface();
;****** Return: AX=1 - page mapping for low 640k is 1:1
;******         AX=0 - otherwise (it's bad)
;****** Uses:   Flags
;***************************************************************
        global  _get_vcpi_interface:near
        proc    _get_vcpi_interface near

                ;push    si di

; Get and save VCPI pm interface
                mov     si,offset gdt_vcpi      ;DS:DI => 3 GDT entries for VCPI
                ;mov     di,[si+page0_ofs-gdt_vcpi]          ;ES:DI => page0
                ;push    ds
                ;pop     es
                mov     ax,0DE01h               ;get vcpi pm interface
                int     67h
                mov     [vcpi_pm_entry],ebx

; Check that mapping for low 640k is 1:1
                mov     si,[page0_ofs]
                xor     bx,bx
                cld
@@map_chk:
                lodsd
                shr     eax,12
                cmp     ax,bx
                stc
                jne     @@bad
                inc     bx
                cmp     ax,((640*1024) shr 12)-1
                jne     @@map_chk
; Return
@@bad:
                sbb     ax,ax
                inc	ax			; update Z
                ;pop     di si
                ret
        endp    _get_vcpi_interface


;***************************************************************
;void memcpy_vcpi(u32 dstofs,u16 srcseg,u32 srcofs);
;***************************************************************
;****** Copies PAGE_SIZE bytes
;****** Uses:   Flags
;***************************************************************
        global  call_pm_routine:near
        proc    call_pm_routine near

              arg     dstofs  :dword, \
                      srcseg  :word,  \
                      srcofs  :dword  = PARAM_SIZE

struc   pm_regs
$$retaddr       dw      ?
$$f             dw      ?
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

                xor     ax,ax           ; IRET stack for return to vm
                push    ax gs           ;   (9 dwords)
                push    ax fs           ;
                push    ax ds           ;
                push    ax es           ;
                push    ax ss           ;
                push    ebp             ; esp
                pushfd                  ; eflags: IF saved here
                push    ax cs           ;
                push    ax              ;\eip
                push    offset @@vm_ret ;/

                cli
              ;;mov     [saved_xx],xx   ;use if your vcpi trashes bp/etc

                movzx_e <[word sw2pm_jumpaddr]>,<offset @@pm_entry>
               ;mov     [word sw2pm_jumpaddr+4],SEL_CODE
                mov     esi,cs
                shl     esi,4
                addzx_e si,<offset sw2pm_params>
                mov     ax,0DE0Ch       ; vcpi: switch to pm
                int     67h
@@pm_entry:
; Now we are in 16-bit protected mode
                mov     ax,SEL_DATA
                mov     ss,ax
              ;;mov     ds,ax
              ;;mov     es,ax
              ;;mov     fs,ax
              ;;mov     gs,ax
                assume  nothing
                assume  cs:DGROUP

              ;;mov     xx,[saved_xx]   ;use if your vcpi trashes bp/etc
                lea     sp,[bp-9*4]     ;else we can do this trick with bp

; Call the routine (bp points to params on stack if any)
                mov     ax,[(pm_regs bp).$$f]   ; ss:bp => struct pm_regs
                mov     bp,[word (pm_regs bp).$$ebp]    ;ss:bp => params
                call    ax

; Ok, let's return to vm
                cli     ; to be safe
                clts    ;
                push    SEL_ABS         ; vcpi wants ds=all_addrspace
                pop     ds              ;
                mov     ax,0DE0Ch       ; maybe we need whole eax?
                call    [pword cs:vcpi_pm_entry]
@@vm_ret:
; Now we are in vm86 mode. Sregs, esp, eflags (IF) restored from IRET stack
                ret

;***************************************************************
;****** Helper: This is where real copy is done
;***************************************************************
	global	do_memcpy_vcpi:near
label   do_memcpy_vcpi near

; Note: ss:bp => params
; Move data
                mov     cx,SEL_ABS
                mov     ds,cx
                mov     es,cx
                assume  nothing
                assume  cs:DGROUP

        ; Set up target addr:
        ; replace page mapping for page at 0 so
        ; that it points to dstofs
                mov     esi,[cs:page0_laddr]
                mov     eax,[dstofs]
                mov     al,03h          ; writeable, present
                xchg    [esi],eax       ; replace page0[0]
               ;push    eax             ;X we'll need to restore mapping...
                mov     ecx,cr3         ; reload TLB cache
                mov     cr3,ecx         ;
                xor     edi,edi         ;es:edi => remapped page

        ; Set up source addr
                mov     esi,[srcofs]

        ; Do copying
                mov     ecx,4096/2
                cld
;;              cmp     esi,edi
;;              jae     @@do_copy
;;              add     esi,ecx         ;src<dst: we must do
;;              dec     esi             ;  copy backwards to avoid
;;              add     edi,ecx         ;  overwrite bug
;;              dec     edi             ;
;;              std                     ;
;;@@do_copy:
                db      67h     ;address width override for esi/edi
            rep movsw
;;              cld

        ; Restore page mapping for page at 0
               ;pop     eax             ;X
                mov     esi,[cs:page0_laddr]
                mov     [esi],eax       ; restore page0[0]
                mov     ecx,cr3         ; reload TLB cache
                mov     cr3,ecx         ;
; Return
                ret

        endp    call_pm_routine
                assume  cs:DGROUP,ds:DGROUP


;***************************************************************
;void _vm2rm();
;***************************************************************
;****** Uses:   Flags
;***************************************************************
        global  _vm2rm:near
        proc    _vm2rm near

                push	esi
              ;;pushf
              ;;cli
              ;;pushad
                push    cs      ;*
                push    ds
                mov     [saved_ss],ss
                mov     [saved_sp],sp

                movzx_e <[word sw2pm_jumpaddr]>,<offset @@pm_entry>
               ;mov     [word sw2pm_jumpaddr+4],SEL_CODE
                mov     esi,cs
                shl     esi,4
                addzx_e si,<offset sw2pm_params>
                mov     ax,0DE0Ch       ; vcpi: switch to pm
                int     67h
; Now we are in 16-bit protected mode
@@pm_entry:
                mov     ax,SEL_DATA     ; load data sregs with limit >=64k
                mov     ss,ax           ;   or you may get limit violations
                mov     ds,ax           ;   later in rm
                mov     es,ax           ;   (actually I prefer 4gig limits :-)
                mov     fs,ax           ;
                mov     gs,ax           ;

; Black magic here
                mov     eax,cr0
                and     eax,7ffffffeh   ; clear PG,P bits
                mov     cr0,eax         ; look mommy, we're in rm now!
              ;;jmp     short $+2
              ;;xor     eax,eax
                mov     cr3,eax         ; flush TLB cache

; Now we are in rm, but not yet: have to restore sregs:
                lss     sp,[saved_ss_sp]; SS
                pop     ds              ; DS
               ;push    cs      ;* done earlier
                push    offset @@next
                retf                    ; CS
@@next:
              ;;popad
              ;;popf
                pop	esi
                ret             ; We don't care much about rest (ES/FS/GS)
        endp    _vm2rm

        ends    _TEXT

        end

;###### END OF FILE ############################################
