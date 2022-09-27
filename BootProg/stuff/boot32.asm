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
;; - FAT32 supported using BIOS int 13h function 42h (IOW, it will only     ;;
;;   work with modern BIOSes supporting HDDs bigger than 8 GB)              ;;
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
ClusterMask             equ     1               ; +9 bytes
NullEntryCheck          equ     0               ; +5 bytes
ReadRetry               equ     1               ; +7 bytes
LBA48bits               equ     1               ; +15 bytes
CHSsupport              equ     1               ; +27 bytes
CHSupTo8GB              equ     1               ; +11 bytes
CHSupTo32MB             equ     1               ; +7 bytes
SectorOf512Bytes        equ     1               ; -5 bytes
Always2FATs             equ     0               ; -4 bytes

[BITS 16]

ImageLoadSeg            equ     60h     ; <=07Fh because of "push byte ImageLoadSeg" instructions
StackSize               equ     1536

[SECTION .text]
[ORG 0]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

boot:
DriveNumber             equ     boot+0
HiLBA                   equ     boot+2
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
bsVolumeLabel          times 11 DB      " "             ; 0x47 "NO NAME    "
bsFileSystemName       times 8  DB      " "             ; 0x52 "FAT32   "

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
        push    es
        mov     [si(DriveNumber)], dx  ; store BIOS boot drive number
        rep     movsw

;;;;;;;;;;;;;;;;;;;;;;
;; Jump to the copy ;;
;;;;;;;;;;;;;;;;;;;;;;

        push    byte main
        retf

main:
        push    cs
        pop     ds

        xor     ebx, ebx

%if ClusterMask != 0
        and     byte [bx(bsRootDirectoryClusterNo+3)], 0Fh ; mask cluster value
%endif
        mov     esi, [bx(bsRootDirectoryClusterNo)] ; esi=cluster # of root dir

        push    byte ImageLoadSeg
        pop     es

RootDirReadContinue:
        call    ReadClusterSector       ; read one sector of the root dir

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Look for the COM/EXE file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        xor     di, di                  ; es:di -> root entries array

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Looks for a file/dir by its name      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  DS:SI -> file name (11 chars) ;;
;;         ES:DI -> root directory array ;;
;;         BP = paragraphs in sector     ;;
;; Output: ESI = cluster number          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FindNameCycle:
%if NullEntryCheck != 0
        cmp     byte [es:di], bh
        je      ErrFind                 ; end of root directory (NULL entry found)
%endif
        pusha
        mov     cl, NameLength
        mov     si, ProgramName         ; ds:si -> program name
        repe    cmpsb
        je      FindNameFound
        popa
        add     di, byte 32
        dec     bp
        dec     bp
        jnz     FindNameCycle           ; next root entry
        loop    RootDirReadContinue     ; next sector in cluster
        cmp     esi, 0FFFFFF6h          ; carry=0 if last cluster, and carry=1 otherwise
        jnc     RootDirReadContinue     ; continue to the next root dir cluster
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
        call    ReadClusterSector       ; read one sector of the boot file
        dec     cx
        mov     di, es
        add     di, bp
        mov     es, di                  ; es:bx updated
        pop     di

        sub     di, bp
        jae     FileReadContinue
        xor     ax, ax
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
        int     16h                     ; wait for a key...
        int     19h                     ; bootstrap

Stop:
        hlt
        jmp     short Stop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a FAT32 sector         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Inout:  ES:BX -> buffer      ;;
;;         EAX = prev sector    ;;
;; CX = rem sectors in cluster  ;;
;;         ESI = next cluster   ;;
;; Output: EAX = current sector ;;
;; CX = rem sectors in cluster  ;;
;;         ESI = next cluster   ;;
;;         BP -> para / sector  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadClusterSector:
%if SectorOf512Bytes != 0
        mov     bp, 32                          ; bp = paragraphs per sector
%else
        mov     bp, [bx(bpbBytesPerSector)]
        shr     bp, 4                           ; bp = paragraphs per sector
%endif
        mov     dx, 1                           ; adjust LBA for next sector
        inc     cx
        loop    ReadSectorLBA

        mul     ebx                             ; edx:eax = 0
%if SectorOf512Bytes != 0
        mov     al, 128                         ; ax=# of FAT32 entries per sector
%else
        imul    ax, bp, byte 4                  ; ax=# of FAT32 entries per sector
%endif
        lea     edi, [esi-2]                    ; esi=cluster #
        xchg    eax, esi
        div     esi                             ; eax=FAT sector #, edx=entry # in sector

        imul    si, dx, byte 4                  ; si=entry # in sector, clear C
%if LBA48bits != 0
        xor     dx, dx
%endif
        call    ReadSectorLBAfromFAT            ; read 1 FAT32 sector

%if ClusterMask != 0
        and     byte [es:si+3], 0Fh             ; mask cluster value
%endif
        mov     esi, [es:si]                    ; esi=next cluster #

%if Always2FATs != 0
        imul    eax, dword [bx(bsSectorsPerFAT32)], 2
%else
        movzx   eax, byte [bx(bpbNumberOfFATs)]
        mul     dword [bx(bsSectorsPerFAT32)]
%endif

        xchg    eax, edi
        movzx   ecx, byte [bx(bpbSectorsPerCluster)] ; 8..128
        mul     ecx                             ; edx:eax=sector number in data area
        add     eax, edi
%if LBA48bits != 0
        adc     dx, bx
%endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a sector form the start of FAT ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadSectorLBAfromFAT:
        add     eax, [bx(bpbHiddenSectors)]
%if LBA48bits != 0
        adc     dx, bx
        mov     word [bx(HiLBA)], dx
%endif
        mov     dx, [bx(bpbReservedSectors)]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a sector using BIOS Int 13h fn 42h ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  EAX = LBA                        ;;
;;         CX    = sector count             ;;
;;         ES:BX -> buffer address          ;;
;; Output: CF = 0 if no more sectors        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadSectorLBA:
        add     eax, edx
%if LBA48bits != 0
        adc     word [bx(HiLBA)], bx
%endif
        mov     dx, [bx(DriveNumber)]   ; restore BIOS boot drive number
        pusha

        push    bx
%if LBA48bits != 0
        push    word [bx(HiLBA)]        ; 48-bit LBA
%else
        push    bx
%endif
        push    eax
        push    es
        push    bx
        push    byte 1 ; sector count word = 1
        push    byte 16 ; packet size byte = 16, reserved byte = 0

%if CHSsupport != 0
 %if CHSupTo8GB != 0
        push    eax
        pop     cx                      ; save low LBA
        pop     ax                      ; get high LBA
        cwd                             ; clear dx (assume LBA offset <1TB)
        idiv    word [bx(bpbSectorsPerTrack)] ; up to 8GB disks, avoid divide error

        xchg    ax, cx                  ; restore low LBA, save high LBA / SPT
 %else
; Busybox mkdosfs creates fat32 for floppies.
; Floppies may support CHS only.
  %if CHSupTo32MB != 0
        xor     dx, dx                  ; clear dx (LBA offset <32MB)
  %else
        cwd                             ; clear dx (LBA offset <16MB)
  %endif
        xor     cx, cx                  ; high LBA / SPT = 0
 %endif
        idiv    word [bx(bpbSectorsPerTrack)]
                ; ax = LBA / SPT
                ; dx = LBA % SPT         = sector - 1
        inc     dx

        xchg    cx, dx                  ; restore high LBA / SPT, save sector no.
        idiv    word [bx(bpbHeadsPerCylinder)]
                ; ax = (LBA / SPT) / HPC = cylinder
                ; dx = (LBA / SPT) % HPC = head

        xchg    ch, al                  ; clear al
                ; ch = LSB 0...7 of cylinder no.
 %if CHSupTo8GB != 0 || CHSupTo32MB != 0
        shr     ax, 2
        or      cl, al
                ; cl = MSB 8...9 of cylinder no. + sector no.
 %endif
        mov     dh, dl
                ; dh = head no.
        mov     dl, [bx(DriveNumber)]   ; restore BIOS boot drive number
%endif

ReadSectorRetry:
        mov     si, sp
        mov     ah, 42h                 ; ah = 42h = extended read function no.
        int     13h                     ; extended read sectors (DL, DS:SI)
        jnc     ReadSuccess             ; CF = 0 if no error

%if CHSsupport != 0
        mov     ax, 201h                ; al = sector count = 1
                                        ; ah = 2 = read function no.
        int     13h                     ; read sectors (AL, CX, DX, ES:BX)

        jnc     ReadSuccess             ; CF = 0 if no error
%endif
%if ReadRetry != 0
 %if CHSsupport != 0
        cbw                             ; ah = 0 = reset function
 %else
        xor     ax, ax                  ; ah = 0 = reset function
 %endif
        int     13h                     ; reset drive (DL)

        dec     bp                      ; up to 32 retries
        jnz     ReadSectorRetry
%endif

        call    Error
        db      "Read error."

ReadSuccess:

        popa                            ; sp += 16
        popa
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill free space with zeroes ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                times (512-13-($-$$)) db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Name of the file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ProgramName     db      "STARTUP BIN"   ; name and extension each must be
                times (510-($-$$)) db ' ' ; padded with spaces (11 bytes total)
NameLength      equ     $-ProgramName

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End of the sector ID ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

                dw      0AA55h          ; BIOS checks for this ID
