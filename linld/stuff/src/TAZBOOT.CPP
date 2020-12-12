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
	m->chunk_size = 0;
	if (m->state >= initrd_state.cnt) return;
	struct initrd_info *i = &initrd_state.info[m->state];
	m->chunk_size = i->size;
	m->state++;
	lseekset2(m->fd,&i->ofs);
}

static u32 isofilesize4round()
{
	return (isofilesize+3)&-4;
}

static void addinitrd()
{
	u16 *pcnt = &initrd_state.cnt;
	if (*pcnt >= MAXINITRD) return;
	struct initrd_info *i = &initrd_state.info[(*pcnt)++];
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
	load_kernel();
	return version_string;
}

static char buf_cmdline[4096];
const char *cmdline = (const char *) buf_cmdline+1;
static void bootiso(char **iso)
{
	const char *init = " rdinit=/init.exe", *mode="menu";
	char c;
	static char rootfs[16], fallback[16], noauto;
	unsigned long magic;
	struct isostate *x=&isostate;
	
	if (isoreset(*iso) == -1) return;
#ifdef WITH_XMM_ALLOC
	skip_alloc--;
#endif
	base_himem = memtop() /2;
	//if (base_himem >= _64m) base_himem = _64m;
	if (* ((char *) &base_himem +3) >= 4) ((short *)&base_himem)[1] = _64m/_64k;
	isoopen("boot");
	if (iso[1] && !strcmp(mode = iso[1], "text"))
		init = "";
	if (isoopen(mode) == -1 || ++noauto == 0)	// custom
		isoopen("bzImage");			// SliTaz
	magic = kver2ul(isokernel());
	for (c = 0, x->curdirsize = 0xFFFF; isoreaddir() != -1;) {
		if (strstr(x->filename, ".gz"))
			strcpy(fallback, x->filename);
		if (strhead(x->filename, "rootfs") == -1
			|| c > x->filename[6]) continue;
		c = x->filename[6];
		strcpy(rootfs, x->filename);
	}

	strcatb(buf_cmdline,"autologin bootfrom=");
	strcat(buf_cmdline,*iso);
	if (magic < 0x20630)
		init = ""; // Does not support multiple initramfs

	if (noauto) {
		char *s;
		* (int *) buf_cmdline = 0;
		iso++;
		while ((s = *++iso) != NULL) {
			if (strhead(s,"initrd=") == -1) 
				strcatb(buf_cmdline,s);
			else if (isoopen(s+7) != -1)
				addinitrd();
		}
	}
	else if (magic != 0) {
		static const unsigned long initrddesc = 18L;

		if (isoopen("rootfs.gz") != -1 ||
		    isoopen(rootfs[0] ? rootfs : fallback) != -1) {
			addinitrd();
		}
		if (*init) {
			isolseek(&initrddesc);
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
		strcat(buf_cmdline,(char *)utoa(magic));
	}
	load_initrds();
	close(x->fd);
	boot_kernel();
}

u32 root_dev;
u32 vid_mode;
u32 topmem;
u32 base_himem;
const char* kernel_name = "bzImage";
const char* initrd_name;
static char* iso;

int main(int argc, char *argv[])
{
	((u16*) &base_himem)[1] |= (_1m+_64k)>>16;	// base_himem = _1m+_64k

	if (argc < 2) {
		try_default_args();
dousage:
		die("Usage: tazboot [[@commands]|"
#ifdef WITH_XMM_ALLOC
"[-f]"
#endif
"[-b base_himem][kernel=<bzImage>] [initrd=<rootfs>[,<rootfs2>...]] [bootfrom=<isofile>] ...]\n\n\
Defaults: tazboot kernel=bzImage auto\n\n\
Examples for tazboot.cmd:\n\n\
  bootfrom=\\isos\\slitaz-4.0.iso\n\
  kernel=boot/bzImage\n\
  initrd=boot/rootfs4.gz,boot/rootfs3.gz,boot/rootfs2.gz,boot/rootfs1.gz,\\slitaz\\extrafs.gz\n\
  root=/dev/null vga=normal autologin\n\n\
  kernel=\\slitaz\\elks\n\
  root=/dev/bda1 ro\n");
	}
	bootiso(argv + 1);	// iso ? parsing is /init.exe stuff !
	for (int i=0;;) {
		char *s;
	next:	argv++;
		s=*argv;
		i++;
		if (!s) {
			if (isoreset(iso) != -1) {
				s = (char *) initrd_name;
				if (isoopen((char *) kernel_name) != -1) {
					isokernel();
				}
				if (s) {
					do {
						char *p, c;
						for (p = s; *s && *s != ','; s++);
						c = *s; *s = 0;
						if (isoopen(p) != -1) {
							addinitrd();
						}
						*s = c;
						if (c) s++;
					} while (*s);
					load_initrds();
				}
			}
			else {
				load_kernel();
				load_initrd();
			}
			boot_kernel();
		}
#ifdef USE_ARGSTR
#ifdef WITH_XMM_ALLOC
	        if ((*(u16 *)s|0x2002) == 0x662F) {	// -F /f
			skip_alloc--;
			goto next;
		}
#endif
		if (argstr(s,"kernel/image|initrd|bootfrom/iso",&kernel_name) != -1);
		else if (argnum(s,"root|vga|mem/-e|-b",&root_dev) != -1);
		else if(i == 1 && fileexist(s) != -1) {
			kernel_name = s;
		}
		else strcatb(buf_cmdline,*argv);	// FIXME mem ?
	}
#else
		if (strhead(s,"initrd=") != -1) {
			s += 7;
			initrd_name = s;
		}
		else if (strhead(s,"bootfrom=") != -1) {
			s += 9;
			goto set_iso;
		}
		else if (strhead(s,"iso=") != -1) {
			s += 4;
	set_iso:
			iso = s;
		}
		else if (strhead(s,"image=") != -1) {
			goto set_kernel;
		}
		else if(strhead(s,"vga=") != -1) {
			*(u16*)&vid_mode = (u16)strtol(s+4);	// support normal, extended & ask
		}
		else if (strhead(s,"kernel=") != -1) {
			s++;
	set_kernel:
			s += 6;
	set_kernelz:
			kernel_name = s;
		}
	        else switch (*(u16 *)s|0x2002) {
#ifdef WITH_XMM_ALLOC
		case 0x662F:	// -F /f
			skip_alloc--;
			goto next;
#endif
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
			if(strhead(s,"root=") != -1) {
				*(u16*)&root_dev = (u16)strtol(s+5);
			}
			if(strhead(s,"mem=") != -1) {
				s += 4;
			set_topmem:
				((u16 *)&topmem)[1] = (u16)(strtol(s)>>16);
			}
		}}
	}
#endif
}
