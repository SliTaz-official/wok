;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                          ;;
;;         "BootProg" Loader v 1.5 by Alexey Frunze (c) 2000-2015           ;;
;;                           2-clause BSD license.                          ;;
;;                                                                          ;;
;;                                                                          ;;
;;                              How to Compile:                             ;;
;;                              ~~~~~~~~~~~~~~~                             ;;
;; nasm bootex.asm -f bin -o bootex.bin                                     ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                 Features:                                ;;
;;                                 ~~~~~~~~~                                ;;
;; - exFAT supported using BIOS int 13h function 42h.                       ;;
;;                                                                          ;;
;; - Loads a 16-bit executable file in the MS-DOS .COM or .EXE format       ;;
;;   from the root directory of a disk and transfers control to it          ;;
;;   (the "ProgramName" variable holds the name of the file to be loaded)   ;;
;;   Its maximum size can be up to 636KB without Extended BIOS Data area.   ;;
;;                                                                          ;;
;; - Prints an error if the file isn't found or couldn't be read            ;;
;;   ("File not found" or "Read error")                                     ;;
;;   and waits for a key to be pressed, then executes the Int 19h           ;;
;;   instruction and lets the BIOS continue bootstrap.                      ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                Known Bugs:                               ;;
;;                                ~~~~~~~~~~~                               ;;
;; - All bugs are fixed as far as I know. The boot sector has been tested   ;;
;;   on a 128MB qemu image.                                                 ;;
;;                                                                          ;;
;;                                                                          ;;
;;                               Memory Layout:                             ;;
;;                               ~~~~~~~~~~~~~~                             ;;
;; The diagram below shows the typical memory layout. The actual location   ;;
;; of the boot sector and its stack may be lower than A0000H if the BIOS    ;;
;; reserves memory for its Extended BIOS Data Area just below A0000H and    ;;
;; reports less than 640 KB of RAM via its Int 12H function.                ;;
;;                                                                          ;;
;;                                            physical address              ;;
;;                 +------------------------+ 00000H                        ;;
;;                 | Interrupt Vector Table |                               ;;
;;                 +------------------------+ 00400H                        ;;
;;                 |     BIOS Data Area     |                               ;;
;;                 +------------------------+ 00500H                        ;;
;;                 | PrtScr Status / Unused |                               ;;
;;                 +------------------------+ 00600H                        ;;
;;                 |      Loaded Image      |                               ;;
;;                 +------------------------+ nnnnnH                        ;;
;;                 |    Available Memory    |                               ;;
;;                 +------------------------+ A0000H - 2KB                  ;;
;;                 |       Boot Sector      |                               ;;
;;                 +------------------------+ A0000H - 1.5KB                ;;
;;                 |    1.5KB Boot Stack    |                               ;;
;;                 +------------------------+ A0000H                        ;;
;;                 |        Video RAM       |                               ;;
;;                                                                          ;;
;;                                                                          ;;
;;                   Boot Image Startup (register values):                  ;;
;;                   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~                  ;;
;;  ax = 0ffffh (both FCB in the PSP don't have a valid drive identifier),  ;;
;;  bx = 0, dl = BIOS boot drive number (e.g. 0, 80H)                       ;;
;;  cs:ip = program entry point                                             ;;
;;  ss:sp = program stack (don't confuse with boot sector's stack)          ;;
;;  COM program defaults: cs = ds = es = ss = 50h, sp = 0, ip = 100h        ;;
;;  EXE program defaults: ds = es = EXE data - 10h (fake MS-DOS psp),       ;;
;;  cs:ip and ss:sp depends on EXE header                                   ;;
;;  Magic numbers:                                                          ;;
;;    si = 16381 (prime number 2**14-3)                                     ;;
;;    di = 32749 (prime number 2**15-19)                                    ;;
;;    bp = 65521 (prime number 2**16-15)                                    ;;
;;  The magic numbers let the program know whether it has been loaded by    ;;
;;  this boot sector or by MS-DOS, which may be handy for universal, bare-  ;;
;;  metal and MS-DOS programs.                                              ;;
;;  The command line contains no arguments.                                 ;;
;;                                                                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define bx(label)       bx+label-boot
%define si(label)       si+label-boot
NullEntryCheck          equ     1               ; +3 bytes
ReadRetry               equ     1               ; +8 bytes

[BITS 16]
[CPU 386]

ImageLoadSeg            equ     60h
StackSize               equ     1536

[SECTION .text]
[ORG 0]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

boot:
DriveNumber:
        jmp     short   start                   ; Windows checks for this jump
        nop
bsOemName               DB      "EXFAT   "      ; 0x03
                        times   53 db 0         ; 0x0B

;;;;;;;;;;;;;;;;;;;;;
;; BPB starts here ;;
;;;;;;;;;;;;;;;;;;;;;

bpbSectorStart          DQ      0               ; 0x40 partition first sector
bpbSectorCount          DQ      0               ; 0x48 partition sectors count
bpbFatSectorStart       DD      0               ; 0x50 FAT first sector
bpbFatSectorCount       DD      0               ; 0x54 FAT sectors count
bpbClusterSectorStart   DD      0               ; 0x58 first cluster sector
bpbClusterCount         DD      0               ; 0x5C total clusters count
bpbRootDirCluster       DD      0               ; 0x60 first cluster of the root dir
bpbVolumeSerial         DD      0               ; 0x64 volume serial number
bpbFSVersionMinor       DB      0               ; 0x68
bpbFSVersionMajor       DB      0               ; 0x69
bpbVolumeStateFlags     DW      0               ; 0x6A 
bpbSectorSizeBits       DB      0               ; 0x6C sector size as (1 << n)
bpbSectorPerClusterBits DB      0               ; 0x6D sector per cluster as (1 << n)
bpbNumberOfFATs         DB      0               ; 0x6E always 1
bpbDriveNumber          DB      0               ; 0x6F alaways 0x80
bpbAllocatedPercent     DB      0               ; 0x70 percentage of allocated space

;;;;;;;;;;;;;;;;;;;
;; BPB ends here ;;
;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector code starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

start:
        cld

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; How much RAM is there? ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        int     12h             ; get conventional memory size (in KBs)
        mov     cx, 106h
        dec     ax
        dec     ax              ; reserve 2K bytes for the code and the stack
        shl     ax, cl          ; and convert it to 16-byte paragraphs

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve memory for the boot sector and its stack ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     es, ax                  ; cs:0 = ds:0 = ss:0 -> top - 512 - StackSize
        mov     ss, ax
        mov     sp, 512+StackSize       ; bytes 0-511 are reserved for the boot code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Copy ourselves to top of memory ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     si, 7C00h
        xor     di, di
        mov     ds, di
        push    es
        mov     [si(DriveNumber)], dx   ; store BIOS boot drive number
        rep     movsw                   ; move 512 bytes (+ 12)

;;;;;;;;;;;;;;;;;;;;;;
;; Jump to the copy ;;
;;;;;;;;;;;;;;;;;;;;;;

        push    word main
        retf

main:
        push    cs
        pop     ds

        xor     ebx, ebx

        mov     esi, [bx(bpbRootDirCluster)] ; esi=cluster # of root dir

        push    byte ImageLoadSeg
        pop     es                      ; cx = 0

RootDirReadContinue:
        call    ReadCluster             ; read one sector of root dir
        pushf                           ; save carry="not last sector" flag

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Look for the COM/EXE file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                                        ; es:di -> root entries array

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Looks for the file/dir ProgramName    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  ES:DI -> root directory array ;;
;; Output: ESI = cluster number          ;;
;;         dword [bx+FileSize] file size ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

CurNameSize     equ  3                  ; 1 byte
StartCluster    equ  14h                ; 4 bytes
FileSize        equ  18h                ; 8 bytes

FindNameCycle:
        pusha

%if NullEntryCheck != 0
        xor     ax, ax
        or      al, [es:di]
        je      FindNameFailed
%else
        movzx   ax, byte [es:di]
%endif

        cmp     al, 0c0h                ; EXFAT_ENTRY_FILE_INFO ?
        jne     NotFileInfo

        mov     bl, 31
CopyInfo:
        mov     al, [es:di+bx]
        mov     [bx], al
        dec     bx
        jnz     CopyInfo                ; keep BIOS boot drive number

NotFileInfo:
        mov     al, 0c1h                ; EXFAT_ENTRY_FILE_NAME ?
        mov     cx, NameLength+1
        mov     si, ProgramName         ; ds:si -> program name
CheckName:
        scasw                           ; compare UTF-16
        lodsb                           ; with ASCII
        loope   CheckName
        je      FindNameFound           ; cx = 0
        popa                            ; restore ax, cx, si, di

        add     di, byte 32
        cmp     di, bp
        jne     FindNameCycle           ; next root entry
        popf                            ; restore carry="not last sector" flag
        jc      RootDirReadContinue     ; continue to the next root dir cluster
FindNameFailed:                         ; end of root directory (dir end reached)
        mov     dl, [bx(DriveNumber)]   ; restore BIOS boot drive number
        call    Error
        db      "File not found."
FindNameFound:
        mov     esi, [bx+StartCluster]

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load the entire file ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

        push    es
        xor     bp, bp
FileReadContinue:
        shr     bp, 4                   ; bytes to paragraphs
        mov     di, es
        add     di, bp                  ; adjust segment for next sector
        mov     es, di                  ; es:0 updated
        call    ReadCluster             ; read one more sector of the boot file
        sub     [bx+FileSize], ebp      ; max FileSize is < 640KB : check low 32 bits only
        ja      FileReadContinue
        mov     dx, [bx(DriveNumber)]   ; restore BIOS boot drive number
        xchg    ax, di
        pop     bp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Type detection, .COM or .EXE? ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     ds, bp                  ; bp=ds=seg the file is loaded to

        add     bp, [bx+08h]            ; bp = image base
        mov     di, [bx+18h]            ; di = reloc table pointer

        cmp     word [bx], 5A4Dh        ; "MZ" signature?
        je      RelocateEXE             ; yes, it's an EXE program

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup and run a .COM program ;;
;; Set CS=DS=ES=SS SP=0 IP=100h ;;
;; AX=0ffffh BX=0 DX=drive and  ;;
;; cmdline=void                 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     di, 100h                ; ip
        mov     bp, ImageLoadSeg-10h    ; "org 100h" stuff :)
        mov     ss, bp
        xor     sp, sp
        push    bp                      ; cs, ds and es
        jmp     short Run

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Relocate, setup and run a .EXE program     ;;
;; Set CS:IP, SS:SP, DS, ES and AX according  ;;
;; to wiki.osdev.org/MZ#Initial_Program_State ;;
;; AX=0ffffh BX=0 DX=drive cmdline=void       ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReloCycle:
        add     [di+2], bp              ; item seg (abs)
        les     si, [di]                ; si = item ofs, es = item seg
        add     [es:si], bp             ; fixup
        scasw                           ; di += 2
        scasw                           ; point to next entry

RelocateEXE:
        dec     word [bx+06h]           ; reloc items, 32768 max (128KB table)
        jns     ReloCycle

        les     si, [bx+0Eh]
        add     si, bp
        mov     ss, si                  ; ss for EXE
        mov     sp, es                  ; sp for EXE

        lea     si, [bp-10h]            ; ds and es both point to the segment
        push    si                      ; containing the PSP structure

        add     bp, [bx+16h]            ; cs for EXE
        mov     di, [bx+14h]            ; ip for EXE
Run:
        pop     ds
        push    bp
        push    di
        push    ds
        pop     es
        mov     [80h], ax               ; clear cmdline
        dec     ax                      ; both FCB in the PSP don't have a valid drive identifier

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Set the magic numbers so the program knows that it   ;;
;; has been loaded by this bootsector and not by MS-DOS ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        mov     si, 16381 ; prime number 2**14-3
        mov     di, 32749 ; prime number 2**15-19
        mov     bp, 65521 ; prime number 2**16-15

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; All done, transfer control to the program now ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        retf

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a exFAT cluster         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  EDX:EAX = LBA         ;;
;;         EBX     = 0           ;;
;;         CX      = sector cnt  ;;
;;         ESI     = cluster no  ;;
;;         ES:0   -> buffer adrs ;;
;; Output: EBX     = 0           ;;
;;         CX      = next cnt    ;;
;;         EBP     = bytes/sector;;
;;         ES:0   -> next adrs   ;;
;;         C=0 for last sector   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadCluster:
        add     eax, byte 1

        inc     cx                              ; jcxnz
        loop    ReadSectorC

        mul     ebx                             ; edx:eax = 0
        mov     cl, -2
        add     cl, [bx(bpbSectorSizeBits)]
        bts     ax, cx                          ; eax=# of exFAT entries per sector
        lea     edi, [esi-2]                    ; edi=cluster #-2
        xchg    eax, esi
        div     esi                             ; eax=FAT sector #, edx=entry # in sector

        imul    si, dx, byte 4                  ; si=entry # offset in sector

        cdq
        add     eax, [bx(bpbFatSectorStart)]    ; sector # relative to exFAT
        call    ReadSectorFAT                   ; read 1 exFAT sector, keep edx=0, set C

        mov     esi, [es:si]                    ; esi=next cluster #

        mov     dl, [bx(bpbSectorPerClusterBits)]
        xor     ecx, ecx
        bts     ecx, edx                        ; 10000h max (32MB cluster)
        xchg    eax, edi                        ; get cluster #-2
        mul     ecx

        add     eax, [bx(bpbClusterSectorStart)]
ReadSectorC:
        mov     di, bx
ReadSectorFAT:
        adc     edx, ebx

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a sector using BIOS Int 13h ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  EDX:EAX = LBA             ;;
;;         BX      = 0               ;;
;;         CX      = sector count    ;;
;;         ES:0   -> buffer address  ;;
;; Output: BX      = 0               ;;
;;         CX      = next count      ;;
;;         EBP     = bytes/sector    ;;
;;         ES:0   -> next address    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        xor     ebp, ebp
        inc     bp

        pushad

        add     eax, [bx(bpbSectorStart)]
        adc     edx, [bx(bpbSectorStart)+4]

        push    edx
        push    eax
        push    es
        push    bx
        push    bp                      ; sector count word = 1
        push    byte 16                 ; packet size byte = 16, reserved byte = 0
ReadSectorRetry:        
        mov     si, sp
        mov     ah, 42h                 ; ah = 42h = extended read function no.
        mov     dl, [bx(DriveNumber)]   ; restore BIOS boot drive number
        int     13h                     ; extended read sectors (DL, DS:SI)

        jnc     ReadSuccess

%if ReadRetry != 0
        xor     ax, ax
        int     13h                     ; reset drive (DL)
        dec     bp
        jpe     ReadSectorRetry         ; up to 3 tries
%endif

        call    Error
        db      "Read error."

ReadSuccess:
        mov     cl, [bx(bpbSectorSizeBits)]
        shl     word [si+16+8], cl      ; (e)bp si+16: EDI ESI EBP ESP EBX EDX ECX EAX
        popa                            ; sp += 16
        popad                           ; real registers

        stc
        loop    ReadSectorNext

        cmp     esi, byte -10           ; carry=0 if last cluster, and carry=1 otherwise
ReadSectorNext:
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill free space with zeroes ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                times (512-13-20-($-$$)) db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Error Messaging Code ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

Error:
        pop     si

PutStr:
        mov     ah, 0Eh
        mov     bl, 7
        lodsb
        int     10h
        cmp     al, "."
        jne     PutStr

        cbw
        int     16h                     ; wait for a key...
        int     19h                     ; bootstrap

Stop:
        hlt
        jmp     short Stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Name of the file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ProgramName     db      "startup.bin"   ; name and extension
NameLength      equ     $-ProgramName

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End of the sector ID ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

                dw      0AA55h          ; BIOS checks for this ID
