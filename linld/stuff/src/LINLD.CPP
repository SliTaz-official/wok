// This file is distributed under GPL
//
// LINLD main() lives here

#include "crtl.h"
#include "common.h"

static struct image_himem image;
static const char msg_cmdline[] = "Error reading cl=@file";
static char* read_cmdline_or_die(const char* fn) {
    image.errmsg = msg_cmdline;
    open_image(fn, &image);
    u16 size=image.size;
    char *cmdline_buf;
    if(size>=PAGE_SIZE ||
       !(cmdline_buf=(char *)malloc(size)) ||
       read(image.fd, cmdline_buf, size) != size)
        die(msg_cmdline);
    // Strip any trailing cr/lf
    char *p=cmdline_buf+size;
    char c='\0';
    do {
        // Replace all other cr/lfs with spaces
        if(*--p>=' ') c=' ';
	else *p = c;
    } while (p>cmdline_buf);
    return cmdline_buf;
}

const char* kernel_name = "bzImage";
const char* initrd_name;
const char* cmdline = "auto";
u16 root_dev;
u16 vid_mode;           // -3 = ask
                        // -2 = Extended VGA
                        // -1 = Normal VGA
                        //  n = as "n" was pressed

inline void syntax() {
    die("Syntax:" NL
        "LINLD [image=file] [initrd=files] [vga=mode] [root=num] [mem=max] [cl=cmdline]" NL
        "vga mode: ask,extended,normal or dec/oct/hex number" NL
        "Defaults:" NL
        "\timage=bzImage" NL
        "\tinitrd,vga,root=(void)" NL
        "\tmem=256m" NL
        "\tcl=auto" NL
        "Use quotes: \"cl=...\" if you need spaces in cmdline" NL
        "Use cl=@filename to take cmdline from file"
#if 1
        NL NL "Examples:" NL
        "\tlinld initrd=rootfs4.gz,rootfs3.gz,rootfs2.gz,rootfs1.gz \"cl=rw root=/dev/null video=-32\""
	NL NL "\tlinld image=memtest"
#endif
    );
}

int main(int argc, char *argv[]) {
    // Believe it or not - this enables A20
    // on my box! Must be DOS in HMA...   -vda
    puts("LINLD v" VERSION_STR "+");

    // Parse command line

    if(argc<2) {
dosyntax:
        syntax();
    }
    {for(int i=1;i<argc;i++) {
	char *s=argv[i];
        if(strhead(s,"image=") == 0) {
            kernel_name=s+6;
        }
        else if(strhead(s,"initrd=") == 0) {
            initrd_name = s+7;
        }
        else if(strhead(s,"cl=") == 0) {
            cmdline=s+3;
            if (cmdline[0] == '@') {
                cmdline=read_cmdline_or_die(cmdline+1);
                puts("Kernel command line:");
                puts(cmdline);
            }
        }
        else if(strhead(s,"vga=") == 0) {
	    s+=4;
	    const char c = *s|0x20;
            if (c == 'a') vid_mode = -3;
            else if (c == 'e') vid_mode = -2;
            else if (c == 'n') vid_mode = -1;
            else vid_mode = strtol(s);
        }
        else if(strhead(s,"root=") == 0) {
            root_dev = strtol(s+5);
        }
        else if(strhead(s,"mem=") == 0) {
            topmem = strtol(s+4);
        }
        else if(strhead(s,"-f") == 0) {
            extern int skip_xmmalloc;
            skip_xmmalloc++;
        }
        else
            goto dosyntax;
    }}

    puts(load_kernel());
    load_initrd();
    boot_kernel();

    // Let compiler be happy
    return _AX;
}
