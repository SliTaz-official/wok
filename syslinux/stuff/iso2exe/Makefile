GCC=gcc -m32
BCC=bcc -ansi -O -0 -C-t
BCCFLAGS=-D__MSDOS__ -Md

all: isohybrid.exe iso2exe meminfo.exe tazboot.exe taziso.built

taziso.built: bootloader.bin ifmem.bin taziso
	./taziso --build
	touch taziso.built

meminfo.exe: meminfo.S
	cc -o meminfo.o -Wa,-a=meminfo.lst -c meminfo.S
	objcopy --only-section=.text -O binary meminfo.o meminfo.exe
	chmod +x $@

iso2exe: iso2exe.sh bootiso.bin win32.exe
	cp iso2exe.sh $@
	chmod +x $@
	./$@ --build bootiso.bin win32.exe init

isohybrid.res: isohybrid.rc isohybrid.ico
	i586-pc-mingw32-windres $< -O coff -o $@

iso2exe.h: iso2exe
	chmod +x iso2exe.sh
	./iso2exe.sh --array ../mbr/isohdpfx.bin > $@

iso2exe.com: iso2exe.c iso2exe.h
	$(BCC) $(BCCFLAGS) -o $@ iso2exe.c && upx --ultra-brute --8086 $@

iso2exe.exe: iso2exe.c iso2exe.h isohybrid.res
	i586-pc-mingw32-gcc -Os -s -o $@ iso2exe.c isohybrid.res -lws2_32

isohybrid.exe: iso2exe.sh mvcom.bin iso2exe.com iso2exe.exe
	./iso2exe.sh --exe mvcom.bin iso2exe.com iso2exe.exe > $@
	chmod +x $@

tazboot.exe: taziso.built linld.com
	./mktazboot linld.com $@
	chmod +x $@

win32.res: win32.rc win32.ico
	i586-pc-mingw32-windres $< -O coff -o $@

win32.exe: win32.c win32.res
	i586-pc-mingw32-gcc -Os -s -o $@ $< win32.res -mwindows -lws2_32 -lcomctl32 && upx --ultra-brute $@

%.o: %.c
	$(BCC) $(BCCFLAGS) -A-l -A$*.lst -c -o $@ $<

%.bin: %.S
	$(GCC) -D__ASSEMBLY__ -DMULTI_INITRD -Wa,-acghlnm=$*.lst -c -o $*.o $<
	objcopy --only-section=.text -O binary $*.o $@
	chmod +x $@

%.lst: %.bin
	objdump -D -Mintel,i8086 -b binary -m i386 --adjust-vma=0x7C00 $< > $@

clean:
	rm -f *.bin *.o *~ 
