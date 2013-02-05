GCC=gcc -m32
BCC=bcc -ansi -O -0 -C-t
BCCFLAGS=-D__MSDOS__ -Md

iso2exe: iso2exe.sh boot.com bootiso.bin init win32.exe
	cp iso2exe.sh $@
	chmod +x $@
	./$@ --build boot.com bootiso.bin init win32.exe

OBJS = boot.o iso9660.o libdos.o bootlinux.o
boot.com: $(OBJS)
	$(BCC) $(BCCFLAGS) -o $@ $(OBJS) &&  upx --ultra-brute $@

boot.o: boot.c iso9660.h bootlinux.h libdos.h

bootlinux.o: bootlinux.c iso9660.h bootlinux.h

iso9660.o: iso9660.c iso9660.h

libdos.o: libdos.c libdos.h

win32.exe: win32.c
	i586-pc-mingw32-gcc -s -o $@ $< -lws2_32 && upx --ultra-brute $@
	
%.o: %.c
	$(BCC) $(BCCFLAGS) -A-l -A$*.lst -c -o $@ $<

%.bin: %.S
	$(GCC) -D__ASSEMBLY__ -Wa,-acghlnm=$*.lst -c -o $*.o $<
	objcopy -O binary $*.o $@
	chmod +x $@

clean:
	rm -f *.bin *.o *~ 
