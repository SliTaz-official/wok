// This file is distributed under GPL
//
// LINLD main() lives here

#include "crtl.h"
#include "common.h"
#include "iso9660.h"

extern char bzimagestr[];
const char* cmdstr[4] = {"auto",bzimagestr,NULL,NULL};
u32 cmdnum[5];

inline void syntax() {
    die("Syntax:" NL
        "LINLD [image=file] [initrd=files] [vga=mode] [root=num] [mem=max] [cl=cmdline] [iso=file]" NL
        "vga mode: ask,extended,normal or dec/oct/hex number" NL
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
	"\tLINLD "
	"-b 64m "
        "initrd=rootfs4.gz,rootfs3.gz,rootfs2.gz,rootfs1.gz "
	"\"cl=root=/dev/null video=-32\""
	NL NL "\tLINLD image=memtest"
#endif
    );
}

extern char buf_cmdline[128];
int main(int argc, char *argv[]) {

    (void) argc;

    ((u16*) &base_himem)[1] |= (_1m+_64k)>>16;	// base_himem = _1m+_64k
    puts("LINLD v" VERSION_STR "+");

    // Parse command line
    if (!*++argv) syntax();
    const char **clp = &cmdline;
    do {
        if ((*(u16 *)*argv|2) == 0x362F) {	// -64 /64
	    if (cpuhaslm() != 0) continue;
	    exit();
	}
	if (argstr(*argv,"cl|image|initrd|iso",clp) == (int) clp) continue;
	if (argnum(*argv,"root|vga|mem|-b|-f*",&root_dev) >= (int) &base_himem) continue;
	if (fileexist(*argv) != -1) {
            kernel_name=*argv;
	    continue;
	}
	*clp = (const char *) buf_cmdline + 1;
	strcatb((const char *) buf_cmdline,*argv);
    } while (*++argv);
    puts(*clp);
    if (isofile) setiso(isofile);
    set_cmdline(*clp);
    load_kernel();
    load_initrd();
    boot_kernel();

    // Let compiler be happy
    return _AX;
}
