// This file is distributed under GPL
//
// TAZBOOT main() lives here

#include "crtl.h"
#include "crtlx.h"
#include "common.h"
#include "iso9660.h"

struct initrd_info {
	u32 ofs;
	u32 size;
};
#define MAXINITRD 10
static struct initrd_state {
	struct initrd_info info[MAXINITRD];
	u16 cnt;
} initrd_state;

static void next_chunk(struct image_himem *m)
{
	struct initrd_info *i = &initrd_state.info[m->state];
	m->chunk_size = 0;
	if (m->state >= initrd_state.cnt) return;
	lseekset2(m->fd,&i->ofs);
	m->chunk_size = i->size;
	m->state++;
}

static u32 isofilesize4round()
{
	return (isofilesize+3)&-4;
}

static void addinitrd()
{
	u16 *pcnt = &initrd_state.cnt;
	struct initrd_info *i = &initrd_state.info[*pcnt];
	if (*pcnt >= MAXINITRD) return;
	++*pcnt;
	i->size = isofilesize;
	i->ofs = isofileofs;
	initrd.size += isofilesize4round();
}

static void load_initrds()
{
	struct image_himem *m = &initrd;
	if (!m->size) return;
	m->next_chunk = next_chunk;
	m->fd = isofd;
	m->state = 0;
	next_chunk(m);
	load_initrd();
}

static char *isokernel()
{
	struct image_himem *m = &pm;
	m->chunk_size = m->size = isofilesize4round();
	m->fd = isofd;
	return load_kernel();
}

static char buf_cmdline[4096];
const char *cmdline = (const char *) buf_cmdline+1;
static void bootiso(char **iso)
{
	const char *init = " rdinit=/init.exe", *mode="menu";
	char c;
	static char rootfs[16], fallback[16], isknoppix, noauto;
	unsigned long magic;
	struct isostate *x=&isostate;
	
	if (!*iso || isoreset(*iso) < 0) return;
	skip_alloc++;
	base_himem = memtop() /2;
	//if (base_himem >= _64m) base_himem = _64m;
	if (* ((char *) &base_himem +3) >= 4) base_himem = _64m;
	isoopen("boot") >= 0 ||
	isoopen("live") >= 0 ||	// debian
	isoopen("casper") >= 0;	// ubuntu
	if (iso[1] && !strcmp(mode = iso[1], "text"))
		init = "";
	do {
		if ((isoopen(mode) >= 0 && ++noauto != 0) ||	// custom
		    isoopen("bzImage") >= 0		|| 	// SliTaz
		    isoopen("vmlinuz") >= 0		||	// misc
		    (isoopen("linux") >= 0 && ++isknoppix != 0)) {
			magic = kver2ul(isokernel());
			break;
		}
	} while (isoopen("isolinux") >= 0);		// Knoppix
	for (c = 0, x->curdirsize = 0xFFFF; isoreaddir() != -1;) {
		if (strstr(x->filename, ".gz"))
			strcpy(fallback, x->filename);
		if (strhead(x->filename, "rootfs") 
			|| c > x->filename[6]) continue;
		strcpy(rootfs, x->filename);
		c = x->filename[6];
	}

	strcatb(buf_cmdline,"rw root=/dev/null autologin bootfrom=");
	strcat(buf_cmdline,*iso);
	if (magic < 0x20630)
		init = ""; // Does not support multiple initramfs

	if (noauto) {
		char *s;
		* (int *) buf_cmdline = 0;
		iso++;
		while ((s = *++iso) != NULL) {
			if (strhead(s,"initrd=")) 
				strcatb(buf_cmdline,s);
			else if (isoopen(s+7) >= 0)
				addinitrd();
		}
	}
	else if (magic > 0) {
		char *initrdfilename = fallback;
		static const unsigned long initrddesc = 18L;

		if (rootfs[0]) {
			initrdfilename = rootfs;
			if (rootfs[6] != '.' && isoopen("rootfs.gz") >= 0)
				addinitrd();	// for loram
		}
		if (isoopen(initrdfilename) >= 0) {
			addinitrd();
		}
		if (*init && isolseek(&initrddesc) != 0) {
			read(x->fd, &x->filemod, 10); // + x->fileofs & x->filesize
			magic = x->filemod;
			x->fileofs = 0x7FF0 - (x->filesize &= 0xFFFF);
			if (((short *) &x->fileofs)[1] == 0) addinitrd();
			else init="";
		}
		strcat(buf_cmdline,init);
		strcatb(buf_cmdline,"mode=");
		strcat(buf_cmdline,mode);
		strcatb(buf_cmdline,"magic=");
		strcat(buf_cmdline,(char *)ultoa(magic));
	}
	load_initrds();
	if (isknoppix) {
		char *s = *iso;
		if (s[1] == ':')
			s += 2;
		for (; *s; s++)
			if (*s == '\\') *s = '/';
	}
	close(x->fd);
	boot_kernel();
}

u32 root_dev;
u32 vid_mode;
u32 topmem;
u32 base_himem;
const char* kernel_name = "bzImage";
const char* initrd_name;
char* iso;

int main(int argc, char *argv[])
{
	((u16*) &base_himem)[1] |= (_1m+_64k)>>16;	// base_himem = _1m+_64k
	argv[0] = progname();
	bootiso(argv);	// iso ? parsing is /init.exe stuff !

	if (argc < 2) {
		try_default_args();
dousage:
		die("Usage: tazboot [[@commands]|[-f][-b base_himem][kernel=<bzImage>] \
[initrd=<rootfs>[,<rootfs2>...]] [bootfrom=<isofile>] ...]\r\n\n\
Defaults: tazboot kernel=bzImage auto\r\n\n\
Examples for tazboot.cmd:\r\n\n\
  bootfrom=\\isos\\slitaz-4.0.iso\r\n\
  kernel=boot/bzImage\r\n\
  initrd=boot/rootfs4.gz,boot/rootfs3.gz,boot/rootfs2.gz,boot/rootfs1.gz,\\slitaz\\extrafs.gz\r\n\
  rw root=/dev/null vga=normal autologin\r\n\n\
  kernel=\\slitaz\\elks\r\n\
  root=/dev/bda1 ro\r\n");
	}
	bootiso(argv + 1);
	chdirname(*argv);
	for (int i=0;;) {
		char *s;
	next:	argv++;
		s=*argv;
		i++;
		if (!s) break;
#ifdef USE_ARGSTR
	        if ((*(u16 *)s|0x2002) == 0x662F) {	// -F /f
			skip_alloc++;
			goto next;
		}
		if (argstr(s,"kernel/image|initrd|bootfrom/iso",&kernel_name) != -1);
		else if (argnum(s,"root|vga|mem/-e|-b",&root_dev) != -1);
		else if(i == 1 && fileexist(s) != -1) {
			kernel_name = s;
		}
		else strcatb(buf_cmdline,*argv);	// FIXME mem ?
	}
#else
		if (strhead(s,"kernel=") == 0) {
			s++;
	set_kernel:
			s += 6;
	set_kernelz:
			kernel_name = s;
		}
		else if (strhead(s,"image=") == 0) {
			goto set_kernel;
		}
		else if (strhead(s,"initrd=") == 0) {
			s += 7;
			initrd_name = s;
		}
		else if (strhead(s,"bootfrom=") == 0) {
			s += 9;
	set_iso:
			iso = s;
		}
		else if (strhead(s,"iso=") == 0) {
			s += 4;
			goto set_iso;
		}
		else if(strhead(s,"vga=") == 0) {
			*(u16*)&vid_mode = (u16)strtol(s+4);	// support normal, extended & ask
		}
	        else switch (*(u16 *)s|0x2002) {
		case 0x662F:	// -F /f
			skip_alloc++;
			goto next;
		case 0x652F:	// -E /e
			s=*++argv;
			goto set_topmem;
		case 0x622F:	// -B /b
			argv++;
			((u16 *)&base_himem)[1] = (u16)(strtol(*argv)>>16);
			goto next;
		default:
		if(i == 1 && fileexist(s) != -1) {
			goto set_kernelz;
		}
		else {
			strcatb(buf_cmdline,*argv);
			if(strhead(s,"root=") == 0) {
				*(u16*)&root_dev = (u16)strtol(s+5);
			}
			if(strhead(s,"mem=") == 0) {
				s += 4;
			set_topmem:
				((u16 *)&topmem)[1] = (u16)(strtol(s)>>16);
			}
		}}
	}
#endif
	if (iso && isoreset(iso) >= 0) {
		char *s = (char *) initrd_name;
		if (isoopen((char *) kernel_name) >= 0) {
			isokernel();
		}
		if (s) {
			while (*s) {
				char *p, c;
				for (p = s; *s && *s != ','; s++);
				c = *s; *s = 0;
				if (isoopen(p) >= 0) {
					addinitrd();
				}
				*s = c;
				if (c) s++;
			}
			load_initrds();
		}
	}
	else {
		load_kernel();
		load_initrd();
	}
	boot_kernel();
	return _AX;
}
