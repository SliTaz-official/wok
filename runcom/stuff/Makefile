CC=gcc -m32
CFLAGS= -O2 -Wall -fno-builtin -fno-stack-protector #-march=i386 
HOST_CFLAGS=-O2 -Wall
# modify to set the kernel path
KERNEL_PATH=../linux-2.6.20

all: debug.bin debug8086.bin dbg8086.bin new.bin dbg.bin runcom

%.bin: %.o
	objcopy -O binary $< $@
	chmod +x $@

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(CC) -D__ASSEMBLY__ -Wa,-acghlnm=$*.lst -c -o $@ $<

clean:
	rm -f *.bin runcom *.o *~ 
