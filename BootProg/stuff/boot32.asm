;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                          ;;
;;         "BootProg" Loader v 1.5 by Alexey Frunze (c) 2000-2015           ;;
;;                           2-clause BSD license.                          ;;
;;                                                                          ;;
;;                                                                          ;;
;;                              How to Compile:                             ;;
;;                              ~~~~~~~~~~~~~~~                             ;;
;; nasm boot32.asm -f bin -o boot32.bin                                     ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                 Features:                                ;;
;;                                 ~~~~~~~~~                                ;;
;; - FAT32 supported using BIOS int 13h function 42h or 02h.                ;;
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
;;   on my HDD and an 8GB USB stick.                                        ;;
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
;;  dl = BIOS boot drive number (e.g. 80H)                                  ;;
;;  cs:ip = program entry point                                             ;;
;;  ss:sp = program stack (don't confuse with boot sector's stack)          ;;
;;  COM program defaults: cs = ds = es = ss = 50h, sp = 0, ip = 100h        ;;
;;  EXE program defaults: ds = es = EXE data - 10h (fake MS-DOS psp),       ;;
;;  ax = 0ffffh (both FCB in the PSP don't have a valid drive identifier),  ;;
;;  cs:ip and ss:sp depends on EXE header                                   ;;
;;  Magic numbers:                                                          ;;
;;    si = 16381 (prime number 2**14-3)                                     ;;
;;    di = 32749 (prime number 2**15-19)                                    ;;
;;    bp = 65521 (prime number 2**16-15)                                    ;;
;;  The magic numbers let the program know whether it has been loaded by    ;;
;;  this boot sector or by MS-DOS, which may be handy for universal, bare-  ;;
;;  metal and MS-DOS programs.                                              ;;
;;                                                                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%define bx(label)       bx+label-boot

[BITS 16]

ImageLoadSeg            equ     60h     ; <=07Fh because of "push byte ImageLoadSeg" instructions
StackSize               equ     1536

[SECTION .text]
[ORG 0]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

boot:
HiLBA                   equ     boot+0
        jmp     short   start                   ; MS-DOS/Windows checks for this jump
        nop
bsOemName               DB      "BootProg"      ; 0x03

;;;;;;;;;;;;;;;;;;;;;;
;; BPB1 starts here ;;
;;;;;;;;;;;;;;;;;;;;;;

bpbBytesPerSector       DW      0               ; 0x0B
bpbSectorsPerCluster    DB      0               ; 0x0D
bpbReservedSectors      DW      0               ; 0x0E
bpbNumberOfFATs         DB      0               ; 0x10
bpbRootEntries          DW      0               ; 0x11
bpbTotalSectors         DW      0               ; 0x13
bpbMedia                DB      0               ; 0x15
bpbSectorsPerFAT        DW      0               ; 0x16
bpbSectorsPerTrack      DW      0               ; 0x18
bpbHeadsPerCylinder     DW      0               ; 0x1A
bpbHiddenSectors        DD      0               ; 0x1C
bpbTotalSectorsBig      DD      0               ; 0x20

;;;;;;;;;;;;;;;;;;;;
;; BPB1 ends here ;;
;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;
;; BPB2 starts here ;;
;;;;;;;;;;;;;;;;;;;;;;

bsSectorsPerFAT32               DD      0               ; 0x24
bsExtendedFlags                 DW      0               ; 0x28
bsFSVersion                     DW      0               ; 0x2A
bsRootDirectoryClusterNo        DD      0               ; 0x2C
bsFSInfoSectorNo                DW      0               ; 0x30
bsBackupBootSectorNo            DW      0               ; 0x32
bsreserved             times 12 DB      0               ; 0x34
bsDriveNumber                   DB      0               ; 0x40
bsreserved1                     DB      0               ; 0x41
bsExtendedBootSignature         DB      0               ; 0x42
bsVolumeSerialNumber            DD      0               ; 0x43
bsVolumeLabel                   DB      "NO NAME    "   ; 0x47
bsFileSystemName                DB      "FAT32   "      ; 0x52

;;;;;;;;;;;;;;;;;;;;
;; BPB2 ends here ;;
;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector code starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

start:
        cld

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; How much RAM is there? ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        int     12h             ; get conventional memory size (in KBs)
        dec     ax
        dec     ax              ; reserve 2K bytes for the code and the stack
        mov     cx, 106h
        shl     ax, cl          ; and convert it to 16-byte paragraphs

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve memory for the boot sector and its stack ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     es, ax          ; cs:0 = ds:0 = ss:0 -> top - 512 - StackSize
        mov     ss, ax
        mov     sp, 512+StackSize ; bytes 0-511 are reserved for the boot code

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Copy ourselves to top of memory ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     si, 7C00h
        xor     di, di
        mov     ds, di
        rep     movsw

;;;;;;;;;;;;;;;;;;;;;;
;; Jump to the copy ;;
;;;;;;;;;;;;;;;;;;;;;;

        push    es
        push    byte main
        retf

main:
        push    cs
        pop     ds

        xor     bx, bx
        mov     [bx(bsDriveNumber)], dx  ; store BIOS boot drive number

        and     byte [bx(bsRootDirectoryClusterNo+3)], 0Fh ; mask cluster value
        mov     esi, [bx(bsRootDirectoryClusterNo)] ; esi=cluster # of root dir

RootDirReadContinue:
        push    byte ImageLoadSeg
        pop     es
        call    ReadCluster             ; read one cluster of root dir
        pushf                           ; save carry="not last cluster" flag

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Look for the COM/EXE file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        xor     di, di                  ; es:di -> root entries array

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Looks for a file/dir by its name      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  DS:SI -> file name (11 chars) ;;
;;         ES:DI -> root directory array ;;
;;         DX = number of root entries   ;;
;;         BP = paragraphs in sector     ;;
;; Output: ESI = cluster number          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FindName:
FindNameCycle:
        cmp     byte [es:di], bh
        je      ErrFind                 ; end of root directory (NULL entry found)
FindNameNotEnd:
        pusha
        mov     cl, 11
        mov     si, ProgramName         ; ds:si -> program name
        repe    cmpsb
        je      FindNameFound
        popa
        add     di, byte 32
        dec     bp
        dec     bp
        jnz     FindNameCycle           ; next root entry
        popf                            ; restore carry="not last cluster" flag
        jc      RootDirReadContinue     ; continue to the next root dir cluster
ErrFind:
        call    Error                   ; end of root directory (dir end reached)
        db      "File not found."
FindNameFound:
        push    word [es:di+14h-11]
        push    word [es:di+1Ah-11]
        pop     esi                     ; esi = cluster no. cx = 0

        dec     dword [es:di+1Ch-11]    ; load ((n - 1)/256)*16 +1 paragraphs
        imul    di, [es:di+1Ch+1-11], byte 16 ; file size in paragraphs (full pages)

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load the entire file ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

        push    es
FileReadContinue:
        push    di
        call    ReadCluster             ; read one cluster of root dir
        mov     di, es
        add     di, bp
        mov     es, di                  ; es:bx updated
        pop     di

        sub     di, bp
        jae     FileReadContinue
        pop     bp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Type detection, .COM or .EXE? ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     ds, bp                  ; bp=ds=seg the file is loaded to
        add     bp, [bx+08h]            ; bp = image base
        mov     ax, [bx+06h]            ; ax = reloc items
        mov     di, [bx+18h]            ; di = reloc table pointer

        cmp     word [bx], 5A4Dh        ; "MZ" signature?

        je      RelocateEXE             ; yes, it's an EXE program

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup and run a .COM program ;;
;; Set CS=DS=ES=SP SP=0 IP=100h ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     bp, ImageLoadSeg-10h    ; "org 100h" stuff :)
        mov     ss, bp
        xor     sp, sp
        push    bp                      ; cs, ds and es
        mov     bh, 1                   ; ip
        jmp     short Run

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Relocate, setup and run a .EXE program     ;;
;; Set CS:IP, SS:SP, DS, ES and AX according  ;;
;; to wiki.osdev.org/MZ#Initial_Program_State ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReloCycle:
        add     [di+2], bp              ; item seg (abs)
        les     si, [di]                ; si = item ofs, es = item seg
        add     [es:si], bp             ; fixup
        scasw                           ; di += 2
        scasw                           ; point to next entry

RelocateEXE:
        dec     ax                      ; 32768 max (128KB table)
        jns     ReloCycle               ; leave with ax=0ffffh: both FCB in the
                                        ; PSP don't have a valid drive identifier
        les     si, [bx+0Eh]
        add     si, bp
        mov     ss, si                  ; ss for EXE
        mov     sp, es                  ; sp for EXE

        lea     si, [bp-10h]            ; ds and es both point to the segment
        push    si                      ; containing the PSP structure

        add     bp, [bx+16h]            ; cs for EXE
        mov     bx, [bx+14h]            ; ip for EXE
Run:
        pop     ds
        push    bp
        push    bx
        push    ds
        pop     es

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

ReadCluster:
        mov     bp, [bx(bpbBytesPerSector)]
        shr     bp, 4                           ; bp = paragraphs per sector
        inc     cx
        loop    ReadSectorLBA

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a FAT32 cluster        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Inout:  ES:BX -> buffer      ;;
;;           ESI = cluster no   ;;
;; Output:   ESI = next cluster ;;
;;         BP -> para / sector  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        imul    ax, bp, byte 2                  ; ax=# of FAT32 entries per sector
        cwde
        lea     edi, [esi-2]                    ; esi=cluster #
        xchg    eax, esi
        cdq
        div     esi                             ; eax=FAT sector #, edx=entry # in sector

        imul    si, dx, byte 4                  ; si=entry # in sector, clear C
        mov     word [bx(HiLBA)], bx
        call    ReadSectorLBAabsolute           ; read 1 FAT32 sector

        and     byte [es:si+3], 0Fh             ; mask cluster value
        mov     esi, [es:si]                    ; esi=next cluster #

        movzx   eax, byte [bx(bpbNumberOfFATs)]
        mul     dword [bx(bsSectorsPerFAT32)]
        mov     word [bx(HiLBA)], dx

        xchg    eax, edi
        movzx   ecx, byte [bx(bpbSectorsPerCluster)]
        mul     ecx				; edx:eax=sector number in data area

        add     eax, edi
        adc     word [bx(HiLBA)], dx

ReadSectorLBAabsolute:
        mov     dx, word [bx(bpbReservedSectors)]
        add     eax, edx
        adc     word [bx(HiLBA)], bx
        add     eax, [bx(bpbHiddenSectors)]
        adc     word [bx(HiLBA)], bx

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a sector using BIOS Int 13h fn 42h ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  EAX = LBA                        ;;
;;         CX    = sector count             ;;
;;         ES:BX -> buffer address          ;;
;; Output: CF = 0 if no more sectors        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadSectorLBA:
        pusha

        push    bx
        push    word [bx(HiLBA)]        ; 48-bit LBA
        push    eax
        push    es
        push    bx
        push    byte 1 ; sector count word = 1
        push    byte 16 ; packet size byte = 16, reserved byte = 0
        push    eax
        pop     cx                      ; low LBA
        pop     ax                      ; high LBA
        cwd                             ; clear dx (CHS disk <2TB)
        div     word [bx(bpbSectorsPerTrack)] ; up to 8GB CHS disks

        xchg    ax, cx                  ; restore low LBA, save high LBA / SPT
        div     word [bx(bpbSectorsPerTrack)]
                                        ; ax = LBA / SPT
                                        ; dx = LBA % SPT         = sector - 1
        inc     dx

        xchg    cx, dx                  ; restore high LBA / SPT, save sector no.
        div     word [bx(bpbHeadsPerCylinder)]
                                        ; ax = (LBA / SPT) / HPC = cylinder
                                        ; dx = (LBA / SPT) % HPC = head
        shl     ah, 6
        mov     ch, al
                                        ; ch = LSB 0...7 of cylinder no.
        or      cl, ah
                                        ; cl = MSB 8...9 of cylinder no. + sector no.
        mov     dh, dl
                                        ; dh = head no.

ReadSectorLBARetry:
        mov     dl, [bx(bsDriveNumber)] ; restore BIOS boot drive number
        mov     si, sp
        mov     ah, 42h                 ; ah = 42h = extended read function no.
        int     13h                     ; extended read sectors (DL, DS:SI)
        jnc     ReadSuccess             ; CF = 0 if no error

ReadSectorCHSRetry:
        mov     ax, 201h                ; al = sector count = 1
                                        ; ah = 2 = read function no.
        int     13h                     ; read sectors (AL, CX, DX, ES:BX)
        jnc     ReadSuccess             ; CF = 0 if no error

        cbw                             ; ah = 0 = reset function
        int     13h                     ; reset drive (DL)

        dec     bp
        jnz     ReadSectorLBARetry

        call    Error
        db      "Read error."

ReadSuccess:

        popa                            ; sp += 16

        popa

        add     eax, byte 1             ; adjust LBA for next sector
        adc     word [bx(HiLBA)], bx

        stc
        loop    ReadSectorNext

        cmp     esi, 0FFFFFF8h          ; carry=0 if last cluster, and carry=1 otherwise

ReadSectorNext:
        mov     dx, [bx(bsDriveNumber)] ; restore BIOS boot drive number
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Error Messaging Code ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

Error:
        pop     si
puts:
        mov     ah, 0Eh
        mov     bl, 7
        lodsb
        int     10h
        cmp     al, '.'
        jne     puts
        cbw
;        int     16h                     ; wait for a key...
;        int     19h                     ; bootstrap

Stop:
        hlt
        jmp     short Stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill free space with zeroes ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                times (512-13-($-$$)) db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Name of the file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ProgramName     db      "STARTUP BIN"   ; name and extension each must be
                                        ; padded with spaces (11 bytes total)

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End of the sector ID ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

                dw      0AA55h          ; BIOS checks for this ID
