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
        "LINLD [image=file] [initrd=files] [vga=mode] [root=num] [mem=topLoad] [cl=cmdline] "
#ifdef ISO9660
	"[iso=file] "
#endif
	"..." NL
        "\tvga mode: ask,extended,normal or dec/oct/hex number" NL
	"\t-b baseLoad" NL
#ifdef MINRAM
	"\t-r minRAM" NL
#endif
#ifdef CPUTYPE
        "\t-c minCPU\tfamily*256+model" NL
#endif
#ifdef CPU64
        "\t-64\t\t64 bits cpu" NL
#endif
#ifdef WITH_XMM_ALLOC
	"\t-f\t\tskip XMMS alloc" NL
#endif
#ifdef QUICK_BOOT
# ifdef VCPI
	"\t-v\t\tV86 mode" NL
# endif
	"\t-q\t\tskip shutdown" NL
#endif
        "Defaults:\t"
        "image=bzImage "
        "mem=256m "
        "cl=auto " 
        "-b 1088k" NL
        "Use quotes \"cl=...\" for spaces in cmdline"
        ", cl=@filename to get it from a file"
#if 1
        NL NL "Examples:" NL
	"LINLD "
#ifdef MINRAM
	"-r 96m "
#endif
#ifdef CPUTYPE
	"-c 0x600 "
#endif
        "initrd=rootfs.gz,mycfg.gz "
	"\"cl=root=/dev/null video=-32\""
	NL "LINLD memtest"
	NL "LINLD @linld.cmd"
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
	if (argstr(*argv,"cl|image|initrd" CMDSTR_EXTRA,clp) == (int) clp) continue;
	if (argnum(*argv,"root|vga|mem|-b|" CMDNUM_EXTRA
#ifdef WITH_XMM_ALLOC
		"-f~"
#endif
		,&root_dev) >= (int) &base_himem) continue;
	if (fileexist(*argv) != -1) {
            kernel_name=*argv;
	    continue;
	}
	*clp = (const char *) heap_top +1;
	strcatb((const char *) heap_top,*argv);
    } while (*++argv);
#ifdef MINRAM
    if ((minram>>16) > (memtop()>>16)) exit();	
#endif
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
