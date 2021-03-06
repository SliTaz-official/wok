// This file is distributed under GPL
//
// LINLD main() lives here

#include "crtl.h"
#include "common.h"
#include "iso9660.h"

extern char bzimagestr[];
const char* cmdstr[4] = {"auto",bzimagestr,NULL,NULL};

inline void syntax() {
    die("Syntax:" NL
        "LINLD [image=file] [initrd=files] [vga=mode] [root=num] [mem=max] [cl=cmdline] "
#ifdef ISO9660
	"[iso=file] "
#endif
	"..." NL
        "vga mode: ask,extended,normal or dec/oct/hex number" NL
#ifdef CPUTYPE
        "-m mincpu	family*256+model" NL
#endif
#ifdef CPU64
        "-64 for cpu64 only" NL
#endif
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
	"\tLINLD "
	"-b 64m "
#ifdef CPUTYPE
	"-m 0x600 "
#endif
        "initrd=rootfs4.gz,rootfs3.gz,rootfs2.gz,rootfs1.gz "
	"\"cl=root=/dev/null video=-32\""
	NL "\tLINLD memtest"
#endif
    );
}

int main(int argc, char *argv[]) {

    (void) argc;

    ((u16*) &base_himem)[1] |= (_1m+_64k)>>16;	// base_himem = _1m+_64k
    puts("LINLD v" VERSION_STR "+");

    // Parse command line
    if (!*++argv) syntax();
    const char **clp = &cmdline;
    do {
#ifdef CPU64
        if ((*(u16 *)*argv|2) == 0x362F) {	// -64 /64
	    if (cpuhaslm() == 0) exit();
	}
#endif
#ifdef ISO9660
	if (argstr(*argv,"cl|image|initrd|iso",clp) == (int) clp) continue;
#else
	if (argstr(*argv,"cl|image|initrd",clp) == (int) clp) continue;
#endif
	if (argnum(*argv,"root|vga|mem|-b|"
#ifdef CPUTYPE
		"-m|"
#endif
		"-f~"
#ifdef QUICK_BOOT
		"-q~-v~"
#endif
		,&root_dev) >= (int) &base_himem) continue;
	if (fileexist(*argv) != -1) {
            kernel_name=*argv;
	    continue;
	}
	*clp = (const char *) heap_top +1;
	strcatb((const char *) heap_top,*argv);
    } while (*++argv);
#ifdef CPUTYPE
    if (mincpu > cputype) exit();
#endif
    puts(*clp);
    asm{
	xchg	ax,bx
	mov	bx,offset _heap_top
	cmp	ax,[bx]
	jc	skip
	mov	[bx],ax
    }
skip:
#ifdef ISO9660
    if (isofile) setiso(isofile);
#endif
    set_cmdline(*clp);
    load_kernel();
    load_initrd();
    //boot_kernel();

    // Let compiler be happy
    return _AX;
}
