;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                          ;;
;;         "BootProg" Loader v 1.5 by Alexey Frunze (c) 2000-2015           ;;
;;                           2-clause BSD license.                          ;;
;;                                                                          ;;
;;                                                                          ;;
;;                              How to Compile:                             ;;
;;                              ~~~~~~~~~~~~~~~                             ;;
;; nasm boot16.asm -f bin -o boot16.bin                                     ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                 Features:                                ;;
;;                                 ~~~~~~~~~                                ;;
;; - FAT12 and FAT16 supported using BIOS int 13h function 42h or 02h.      ;;
;;                                                                          ;;
;; - Loads a 16-bit executable file in the MS-DOS .COM or .EXE format       ;;
;;   from the root directory of a disk and transfers control to it          ;;
;;   (the "ProgramName" variable holds the name of the file to be loaded)   ;;
;;   Its maximum size can be up to 635KB without Extended BIOS Data area.   ;;
;;                                                                          ;;
;; - Prints an error if the file isn't found or couldn't be read            ;;
;;   ("File not found" or "Read error")                                     ;;
;;   and waits for a key to be pressed, then executes the Int 19h           ;;
;;   instruction and lets the BIOS continue bootstrap.                      ;;
;;                                                                          ;;
;; - cpu 8086 is supported                                                  ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                Known Bugs:                               ;;
;;                                ~~~~~~~~~~~                               ;;
;; - All bugs are fixed as far as I know. The boot sector has been tested   ;;
;;   on the following types of diskettes (FAT12):                           ;;
;;   - 360KB 5"25                                                           ;;
;;   - 1.2MB 5"25                                                           ;;
;;   - 1.44MB 3"5                                                           ;;
;;   on my HDD (FAT16).                                                     ;;
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
;;                 +------------------------+ A0000H - 512 - 3KB            ;;
;;                 |       Boot Sector      |                               ;;
;;                 +------------------------+ A0000H - 3KB                  ;;
;;                 |     3KB Boot Stack     |                               ;;
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
NullEntryCheck          equ     1               ; +2 bytes
ReadRetry               equ     1               ; +9 bytes
LBAsupport              equ     1               ; +16 bytes
Over2GB                 equ     1               ; +5 bytes
GeometryCheck           equ     1               ; +18 bytes
SectorOf512Bytes        equ     1               ; -4/-6 bytes

[BITS 16]
[CPU 8086]

ImageLoadSeg            equ     60h
StackSize               equ     3072            ; Stack + cluster list

[SECTION .text]
[ORG 0]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

boot:
DriveNumber:
        jmp     short   start                   ; MS-DOS/Windows checks for this jump
        nop
bsOemName               DB      "BootProg"      ; 0x03

;;;;;;;;;;;;;;;;;;;;;
;; BPB starts here ;;
;;;;;;;;;;;;;;;;;;;;;

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

;;;;;;;;;;;;;;;;;;;
;; BPB ends here ;;
;;;;;;;;;;;;;;;;;;;

bsDriveNumber           DB      0               ; 0x24
bsUnused                DB      0               ; 0x25
bsExtBootSignature      DB      0               ; 0x26
bsSerialNumber          DD      0               ; 0x27
bsVolumeLabel  times 11 DB      " "             ; 0x2B "NO NAME    "
bsFileSystem   times 8  DB      " "             ; 0x36 "FAT12   " or "FAT16   "

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
        shl     ax, cl          ; and convert it to 16-byte paragraphs

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve memory for the boot sector and its stack ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        sub     ax, (512+StackSize) /16 ; reserve bytes for the code and the stack
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

        mov     cl, byte main
        push    cx
        retf

main:
     %if ImageLoadSeg != main-boot
      %if ImageLoadSeg >= 100h
        mov     cx, ImageLoadSeg
      %else
        mov     cl, ImageLoadSeg
      %endif
     %endif
        push    cx

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Get drive parameters ;;
;; Update heads count   ;;
;; for current BIOS     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

%if GeometryCheck != 0
        mov     ah, 8
        int     13h                     ; may destroy SI,BP, and DS registers
%endif
                                        ; update AX,BL,CX,DX,DI, and ES registers
        push    cs
        pop     ds
        xor     bx, bx

%if GeometryCheck != 0
        and     cx, byte 3Fh
        cmp     [bx(bpbSectorsPerTrack)], cx
        jne     BadParams               ; verify updated and validity
        mov     al, dh
        inc     ax
        mov     [bpbHeadsPerCylinder], ax
BadParams:
%endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load FAT (FAT12: 6KB max, FAT16: 128KB max) ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        pop     es                      ; ImageLoadSeg
        push    es

        mul     bx                      ; dx:ax = 0 = LBA (LBA are relative to FAT)
        mov     di, word [bx(bpbSectorsPerFAT)]

        call    ReadDISectors           ; read fat; clear ax, cx, di; bp = SectorsPerFAT

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; load the root directory in ;;
;; its entirety (16KB max)    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%if SectorOf512Bytes != 0
        mov     di, word [bx(bpbRootEntries)]
        mov     cl, 4
        shr     di, cl                  ; di = root directory size in sectors
%else
        mov     al, 32

        mul     word [bx(bpbRootEntries)]
        div     word [bx(bpbBytesPerSector)]
        xchg    ax, di                  ; di = root directory size in sectors, clear ah
%endif

        mov     al, [bpbNumberOfFATs]
        mul     bp                      ; [bx(bpbSectorsPerFAT)], set by ReadDISectors

        push    es                      ; read root directory
        call    ReadDISectors           ; clear ax, cx, di; bp = first data sector
        pop     es

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Look for the COM/EXE file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                                        ; es:di -> root entries array

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Looks for the file/dir ProgramName    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  ES:DI -> root directory array ;;
;; Output: SI = cluster number           ;;
;;         AX = file sector count        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FindNameCycle:
        push    di
        mov     cl, NameLength
        mov     si, ProgramName         ; ds:si -> program name
        repe    cmpsb
        pop     di
        je      FindNameFound
%if NullEntryCheck != 0
        scasb				; Z == NC
        cmc
        lea     di, [di+31]
        dec     word [bx(bpbRootEntries)]
        ja      FindNameCycle           ; next root entry
%else
        add     di, byte 32
        dec     word [bx(bpbRootEntries)]
        jnz     FindNameCycle           ; next root entry
%endif

FindNameFailed:
        call    Error
        db      "File not found."

FindNameFound:
        push    si
        mov     si, [es:di+1Ah]         ; si = cluster no.
        les     ax, [es:di+1Ch]         ; file size
        mov     dx, es
        div     word [bx(bpbBytesPerSector)]
        cmp     bx, dx                  ; sector aligned ?
        adc     ax, bx                  ; file last sector
        pop     di                      ; di = ClusterList

        pop     es                      ; ImageLoadSeg
        push    ax

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; build cluster list         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  ES:0 -> FAT        ;;
;;         SI = first cluster ;;
;;         DI = cluster list  :;
;;         CH = 0             ;;
;; Output: SI = cluster list  ;;
;;         CH = 0             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FAT12          equ       1
FAT16          equ       1
TINYFAT16      equ       1
        push    di                      ; up to 2 * 635K / BytesPerCluster = 2540 bytes
%if FAT12 == 1
        mov     cl, 12
%endif
ClusterLoop:
        mov     [di], si
        add     si, si                  ; si = cluster * 2
%if FAT16 == 1
        mov     ax, es                  ; ax = FAT segment = ImageLoadSeg
        jnc     First64k
        mov     ah, (1000h+ImageLoadSeg)>>8 ; adjust segment for 2nd part of FAT16
First64k:
 %if FAT12 == 1
        mov     dx, 0FFF6h
  %if TINYFAT16 == 1
        test    [bx(bsFileSystem+4)], cl ; FAT12 or FAT16 ? clear C
        jne     ReadClusterFat16
  %else
        cmp     [bx(bpbSectorsPerFAT)], cx ; 1..12 = FAT12, 16..256 = FAT16
        ja      ReadClusterFat16
  %endif
        mov     dh, 0Fh
 %endif
%endif
%if FAT12 == 1
        add     si, [di]
        shr     si, 1                   ; si = cluster * 3 / 2
%endif
%if FAT16 == 1
ReadClusterFat16:
        push    ds
        mov     ds, ax
        lodsw                           ; ax = next cluster
        pop     ds
%else
        es lodsw
%endif
%if FAT12 == 1
        jnc     ReadClusterEven
        rol     ax, cl
ReadClusterEven:
        scasw                           ; di += 2
 %if FAT16 == 1
        and     ah, dh                  ; mask cluster value
        cmp     ax, dx
 %else
        and     ah, 0Fh                 ; mask cluster value
        cmp     ax, 0FF6h
 %endif
%else
        scasw                           ; di += 2
        cmp     ax, 0FFF6h
%endif
        xchg    ax, si
        jc      ClusterLoop
        pop     si
        pop     di                      ; file size in sectors

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load the entire file      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  ES:0 -> buffer    ;;
;;         SI = cluster list ;;
;;         DI = file sectors ;;
;;         CH = 0            ;;
;;         BP = 1st data sec ;;
;; Output: BP:0 -> buffer    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        push    es

ReadClusters:
        lodsw
        dec     ax
        dec     ax

        mov     cl, [bx(bpbSectorsPerCluster)] ; 1..128
        mul     cx                      ; cx = sector count (ch = 0)

        add     ax, bp                  ; LBA for cluster data
        adc     dx, bx                  ; dx:ax = LBA

        call    ReadSectors             ; clear ax, restore dx

        jne     ReadClusters            ; until end of file

        pop     bp                      ; ImageLoadSeg

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
                                        ; PSP don't have a valid drive identifier
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read sectors using BIOS Int 13h     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  DX:AX = LBA relative to FAT ;;
;;         BX    = 0                   ;;
;;         DI    = sector count        ;;
;;         ES:BX -> buffer address     ;;
;; Output: ES:BX -> next address       ;;
;;         BX    = 0                   ;;
;;         CX    = 0                   ;;
;;         DI    = 0                   ;;
;;         DL    = drive number        ;;
;;         DX:BP = next LBA from FAT   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadDISectors:
        mov     bp, di
        add     bp, ax                  ; adjust LBA for cluster data

        mov     cx, di                  ; no cluster size limit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read sectors using BIOS Int 13h     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  DX:AX = LBA relative to FAT ;;
;;         BX    = 0                   ;;
;;         CX    = sector count        ;;
;;         DI    = file sectors        ;;
;;         ES:BX -> buffer address     ;;
;; Output: ES:BX -> next address       ;;
;;         BX    = 0                   ;;
;;         CX or DI = 0                ;;
;;         DL    = drive number        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadSectors:
        add     ax, [bx(bpbHiddenSectors)]
        adc     dx, [bx(bpbHiddenSectors)+2]
        add     ax, [bx(bpbReservedSectors)]

        push    si
ReadSectorNext:
        adc     dx, bx
        push    di
        push    cx

%if LBAsupport != 0
        push    bx
        push    bx
%endif
        push    dx      ; 32-bit LBA: up to 2TB
        push    ax
        push    es
%if ReadRetry != 0 || LBAsupport != 0
        mov     di, 16  ; packet size byte = 16, reserved byte = 0
%endif
%if LBAsupport != 0
        push    bx
        inc     bx      ; sector count word = 1
        push    bx
        dec     bx
        push    di
%endif

%if Over2GB != 0
        xchg    ax, cx                  ; save low LBA
        xchg    ax, dx                  ; get high LBA
        cwd                             ; clear dx (LBA offset <1TB)
        idiv    word [bx(bpbSectorsPerTrack)] ; up to 8GB disks

        xchg    ax, cx                  ; restore low LBA, save high LBA / SPT
%else
        xor     cx, cx                  ; up to 2GB disks otherwise divide error interrupt !
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
        shr     ax, 1
        shr     ax, 1
        or      cl, al
                ; cl = MSB 8...9 of cylinder no. + sector no.
        mov     dh, dl
                ; dh = head no.

ReadSectorRetry:
        mov     dl, [bx(DriveNumber)]
                ; dl = drive no.
        mov     si, sp
%if LBAsupport != 0
        mov     ah, 42h                 ; ah = 42h = extended read function no.
        int     13h                     ; extended read sectors (DL, DS:SI)
        jnc     ReadSectorNextSegment
%endif

        mov     ax, 201h                ; al = sector count = 1
                                        ; ah = 2 = read function no.
        int     13h                     ; read sectors (AL, CX, DX, ES:BX)

        jnc     ReadSectorNextSegment
%if ReadRetry != 0
        cbw                             ; ah = 0 = reset function
        int     13h                     ; reset drive (DL)

        dec     di
        jnz     ReadSectorRetry         ; up to 15 extra attempt
%endif

        call    Error
        db      "Read error."

ReadSectorNextSegment:

%if LBAsupport != 0
        pop     ax                      ; al = 16
 %if SectorOf512Bytes != 0
        add     word [si+6], byte 32    ; adjust segment for next sector
 %else
        mul     byte [bx(bpbBytesPerSector)+1] ;  = (bpbBytesPerSector/256)*16
        add     [si+6], ax              ; adjust segment for next sector
 %endif
        pop     cx                      ; sector count = 1
        pop     bx
%else
 %if SectorOf512Bytes != 0
        add     word [si], byte 32      ; adjust segment for next sector
 %else
        mov     al, 16
        mul     byte [bx(bpbBytesPerSector)+1] ;  = (bpbBytesPerSector/256)*16
        add     [si], ax                ; adjust segment for next sector
 %endif
%endif
        pop     es                      ; es:0 updated
        pop     ax
        pop     dx
%if LBAsupport != 0
        pop     di
        pop     di
        add     ax, cx                  ; adjust LBA for next sector
%else
        add     ax, 1                   ; adjust LBA for next sector
%endif

        pop     cx                      ; cluster sectors to read
        pop     di                      ; file sectors to read
        dec     di                      ; keep C
        loopne  ReadSectorNext          ; until cluster sector count or file sector count
        pop     si
        mov     ax, bx                  ; clear ax
        mov     dx, [bx(DriveNumber)]   ; pass the BIOS boot drive to Run or Error

        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill free space with zeroes ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                times (512-13-($-$$)) db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Name of the file to load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NameLength      equ   11
ProgramName     times NameLength db 0   ; name and extension

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End of the sector ID ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

ClusterList     dw      0AA55h          ; BIOS checks for this ID
