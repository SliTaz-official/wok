GCC=gcc -m32
BCC=bcc -ansi -O -0 -C-t
BCCFLAGS=-D__MSDOS__ -Md

iso2exe: iso2exe.sh bootiso.bin lzcom.bin boot.com init
	cp iso2exe.sh $@
	chmod +x $@
	lzma e boot.com boot.com.lzma -eos
	./$@ --build bootiso.bin lzcom.bin boot.com.lzma init

OBJS = boot.o iso9660.o libdos.o bootlinux.o
boot.com: $(OBJS)
	$(BCC) $(BCCFLAGS) -o $@ $(OBJS)

boot.o: boot.c iso9660.h bootlinux.h libdos.h

bootlinux.o: bootlinux.c iso9660.h bootlinux.h

iso9660.o: iso9660.c iso9660.h

libdos.o: libdos.c libdos.h

lzcom.bin: lzcom.S unlzma.S

%.o: %.c
	$(BCC) $(BCCFLAGS) -A-l -A$*.lst -c -o $@ $<

%.bin: %.S
	$(GCC) -D__ASSEMBLY__ -Wa,-acghlnm=$*.lst -c -o $*.o $<
	objcopy -O binary $*.o $@
	chmod +x $@

clean:
	rm -f *.bin *.o *~ 
