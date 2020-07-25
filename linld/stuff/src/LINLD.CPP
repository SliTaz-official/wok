// This file is distributed under GPL
//
// LINLD main() lives here

#include "crtl.h"
#include "common.h"

const char* cmdline = "auto";
const char* kernel_name = "bzImage";
#ifdef	USE_ARGSTR
const char* initrd_name = NULL;
#else
const char* initrd_name;
#endif
u32 root_dev;
u32 vid_mode;		// -3 = ask
			// -2 = Extended VGA
			// -1 = Normal VGA
			//  n = as "n" was pressed
u32 topmem;
u32 base_himem;

inline void syntax() {
    die("Syntax:" NL
        "LINLD [image=file] [initrd=files] [vga=mode] [root=num] [mem=max] [cl=cmdline]" NL
        "vga mode: ask,extended,normal or dec/oct/hex number" NL
        "-f force" NL
        "-64 for cpu64 only" NL
        "Defaults:" NL
        "\timage=bzImage" NL
        "\tinitrd,vga,root=(void)" NL
        "\tmem=256m" NL
        "\tcl=auto" NL
        "\t-b 1088k" NL
        "Use quotes: \"cl=...\" if you need spaces in cmdline" NL
        "Use cl=@filename to get it from a file"
#if 1
        NL NL "Examples:" NL
	"\tLINLD -f -b 64m "
        "initrd=rootfs4.gz,rootfs3.gz,rootfs2.gz,rootfs1.gz "
	"\"cl=root=/dev/null video=-32\""
	NL NL "\tLINLD image=memtest"
#endif
    );
}

static char buf_cmdline[128];
int main(int argc, char *argv[]) {

    (void) argc;

    ((u16*) &base_himem)[1] |= (_1m+_64k)>>16;	// base_himem = _1m+_64k
    puts("LINLD v" VERSION_STR "+");

    // Parse command line
#ifdef	USE_ARGSTR
    if (!argv[1]) syntax();
    for (;;) {
	const char **clp = &cmdline;
	argv++;
	if (!*argv) goto boot;
        if ((*(u16 *)*argv|2) == 0x362F) {	// -64 /64
	    if (cpuhaslm() == 0) exit();
	}
        if ((*(u16 *)*argv|0x2002) == 0x662F) {	// -F /f
	    skip_alloc--;
	}
	else if (argstr(*argv,"cl|image|initrd",clp) != -1);
	else if (fileexist(*argv) != -1)
            kernel_name=*argv;
	else if (argnum(*argv,"root|vga|mem|-b",&root_dev) != -1);
	else {
	    *clp = (const char *) buf_cmdline + 1;
	    do strcatb((const char *) buf_cmdline,*argv++); while (*argv);
	boot:
            puts(*clp);
	    set_cmdline(*clp);
	    load_kernel();
	    puts(version_string);
	    load_initrd();
	    boot_kernel();
        }
    }
#else
    if (!argv[1]) syntax();
    while (1) {
	char *s;
    next:
	argv++;
	s=*argv;
	if (!s) {
	    load_kernel();
	    puts(version_string);
	    load_initrd();
	    boot_kernel();
	}
        if(strhead(s,"initrd=") != -1) {
            initrd_name=s+7;
        }
        else if(strhead(s,"vga=") != -1) {
            *(u16*)&vid_mode = (u16)strtol(s+7);	// support normal, extended & ask
        }
        else switch (*(u16 *)s|0x2002) {
        case 0x362F:	// -64 /64
	    if (cpuhaslm() == 0) exit();
	    goto next;
	case 0x662F:	// -F /f
	    skip_alloc--;
	    goto next;
	case 0x622F:	// -B /b
	    argv++;
	    ((u16 *)&base_himem)[1] = (u16)(strtol(*argv)>>16);
	    goto next;
	default:
	    if(strhead(s,"cl=") != -1) {
		cmdline=s+=3;
		if (*s == '@') {
		    static struct image_himem image;
		    char c;

		    s++;
		    image.errmsg = "Error in cl=@file";
		    open_image(&image, s);
		    s+=read(image.fd, (void *)cmdline=s=
			(char *)malloc_or_die(image.size), image.size);
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
            else if(strhead(s,"root=") != -1) {
		*(u16*)&root_dev = (u16)strtol(s+5);
		goto addincmdline;
	    }
	    else if(strhead(s,"mem=") != -1) {
		((u16 *)&topmem)[1] = (u16)(strtol(s+4)>>16);
		goto addincmdline;
	    }
            else if(strhead(s,"image=") != -1) {
	        s+=6;
	    set_kernel_name:
                kernel_name=s;
            }
	    else {
	addincmdline:
		if(cmdline == (const char *) buf_cmdline + 1) {
		    strcatb(buf_cmdline,*argv);
		}
		else {
		    if(fileexist(s) != -1) goto set_kernel_name;
		    cmdline = (const char *) buf_cmdline + 1;
		    goto addincmdline;
		}
	    }
	}
    }
#endif

    // Let compiler be happy
    //return _AX;
}
