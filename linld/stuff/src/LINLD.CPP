// This file is distributed under GPL
//
// LINLD main() lives here

#include "crtl.h"
#include "common.h"

const char* kernel_name = "bzImage";
const char* initrd_name;
const char* cmdline = "auto";
u32 root_dev;
u32 vid_mode;		// -3 = ask
			// -2 = Extended VGA
			// -1 = Normal VGA
			//  n = as "n" was pressed
u32 topmem;

inline void syntax() {
    die("Syntax:" NL
        "LINLD [image=file] [initrd=files] [vga=mode] [root=num] [mem=max] [cl=cmdline]" NL
        "vga mode: ask,extended,normal or dec/oct/hex number" NL
        "-f force" NL
        "Defaults:" NL
        "\timage=bzImage" NL
        "\tinitrd,vga,root=(void)" NL
        "\tmem=256m" NL
        "\tcl=auto" NL
#ifdef	USE_ARGSTR
        "\t-b=1088k" NL
#else
        "\t-b 1088k" NL
#endif
        "Use quotes: \"cl=...\" if you need spaces in cmdline" NL
        "Use cl=@filename to get it from a file"
#if 1
        NL NL "Examples:" NL
#ifdef	USE_ARGSTR
        "\tLINLD -f -b=64m initrd=rootfs4.gz,rootfs3.gz,rootfs2.gz,rootfs1.gz \"cl=rw root=/dev/null video=-32\""
#else
        "\tLINLD -f -b 64m initrd=rootfs4.gz,rootfs3.gz,rootfs2.gz,rootfs1.gz \"cl=rw root=/dev/null video=-32\""
#endif
	NL NL "\tLINLD image=memtest"
#endif
    );
}

static char buf_cmdline[128];
int main(int argc, char *argv[]) {

    (void) argc;

    // Believe it or not - this enables A20
    // on my box! Must be DOS in HMA...   -vda
    puts("LINLD v" VERSION_STR "+");

    // Parse command line
#ifdef	USE_ARGSTR
    if (argv[1]) {for (;;) {
	const char **clp = &cmdline;
    next:
	argv++;
	if (!*argv) {
            puts(*clp);
	    set_cmdline(*clp);
	    puts(load_kernel());
	    load_initrd();
	    boot_kernel();
	}
        if ((*(u16 *)*argv|0x2002) == 0x662F) {	// -F /f
	    skip_alloc++;
	    goto next;
	}
	if (argstr(*argv,"cl|image|initrd",clp) == 0);
	else if (fileexist(*argv) >= 0)
            kernel_name=*argv;
	else if (*argv) {
	    argnum(*argv,"root|vga|mem|-b",&root_dev);
	    *clp = (const char *) buf_cmdline + 1;
	    strcatb((const char *) buf_cmdline,*argv);
	}
	else
	    break;
        }
    }
#else
    if (argv[1]) {for (char i=0;;) {
	char *s;
    next:
	argv++;
	s=*argv;
	i++;
	if (!s) {
	    puts(load_kernel());
	    load_initrd();
	    boot_kernel();
	}
        if(strhead(s,"image=") == 0) {
	    s+=6;
	set_kernel_name:
            kernel_name=s;
        }
        else if(strhead(s,"initrd=") == 0) {
	    s+=7;
            initrd_name=s;
        }
        else if(strhead(s,"vga=") == 0) {
	    s+=4;
            vid_mode = strtol(s);	// support normal, extended & ask
        }
        else switch (*(u16 *)s|0x2002) {
	case 0x662F:	// -F /f
	    skip_alloc++;
	    goto next;
	case 0x622F:	// -B /b
	    argv++;
	    base_himem = strtol(*argv);
	    goto next;
	default:
        if(strhead(s,"cl=") == 0) {
            cmdline=s+=3;
            if (*s == '@') {
		static struct image_himem image;
		char c;

		s++;
		image.errmsg = "Error in cl=@file";
		open_image(s, &image);
		cmdline=s=(char *)malloc_or_die(image.size);
		s+=image.size;
		read(image.fd, (void *)cmdline, image.size);
		// Strip any trailing cr/lf
		c='\0';
		do {
			// Replace all other cr/lfs with spaces
			s--;
			if(*s>=' ') c=' ';
			else *s = c;
		} while (s>cmdline);
                puts("Kernel command line:");
                puts(cmdline);
            }
        }
        else if(strhead(s,"root=") == 0) {
	    s+=5;
            root_dev = strtol(s);
	    goto addincmdline;
        }
        else if(strhead(s,"mem=") == 0) {
	    s+=4;
            topmem = strtol(s);
	    goto addincmdline;
        }
        else if(cmdline == (const char *) buf_cmdline + 1) {
addincmdline:
	    strcatb(buf_cmdline,*argv);
        }
	else if(i == 1 && fileexist(s) != -1) {
	    cmdline = (const char *) buf_cmdline + 1;
	    goto set_kernel_name;
        }
	else
	    break;
	}
    }}
#endif
    syntax();

    // Let compiler be happy
    return _AX;
}
