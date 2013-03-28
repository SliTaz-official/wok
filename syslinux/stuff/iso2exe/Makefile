GCC=gcc -m32
BCC=bcc -ansi -O -0 -C-t
BCCFLAGS=-D__MSDOS__ -Md

all: isohybrid.exe iso2exe

iso2exe: iso2exe.sh boot.com bootiso.bin init win32.exe
	cp iso2exe.sh $@
	chmod +x $@
	./$@ --build boot.com bootiso.bin init win32.exe

iso2exe.h: iso2exe ../mbr/isohdpfx.bin
	chmod +x iso2exe.sh
	./iso2exe.sh --array ../mbr/isohdpfx.bin > $@

iso2exe.com: iso2exe.c iso2exe.h
	$(BCC) $(BCCFLAGS) -o $@ iso2exe.c

iso2exe.exe: iso2exe.c iso2exe.h
	i586-pc-mingw32-gcc -s -o $@ iso2exe.c -lws2_32

isohybrid.exe: iso2exe.sh mvcom.bin iso2exe.com iso2exe.exe
	./iso2exe.sh --exe mvcom.bin iso2exe.com iso2exe.exe > $@
	chmod +x $@

OBJS = boot.o iso9660.o libdos.o bootlinux.o
boot.com: $(OBJS)
	$(BCC) $(BCCFLAGS) -o $@ $(OBJS) &&  upx --ultra-brute $@

boot.o: boot.c iso9660.h bootlinux.h libdos.h

bootlinux.o: bootlinux.c iso9660.h bootlinux.h

iso9660.o: iso9660.c iso9660.h

libdos.o: libdos.c libdos.h

win32.res: win32.rc win32.ico
	i586-pc-mingw32-windres $< -O coff -o $@

win32.exe: win32.c winutils.c win32.res
	i586-pc-mingw32-gcc -s -o $@ $< win32.res -mwindows -lws2_32 && upx --ultra-brute $@

%.o: %.c
	$(BCC) $(BCCFLAGS) -A-l -A$*.lst -c -o $@ $<

%.bin: %.S
	$(GCC) -D__ASSEMBLY__ -Wa,-acghlnm=$*.lst -c -o $*.o $<
	objcopy -O binary $*.o $@
	chmod +x $@

clean:
	rm -f *.bin *.o *~ 
