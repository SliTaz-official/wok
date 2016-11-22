// This file is distributed under GPL
//
// TAZBOOT main() lives here

#include "crtl.h"
#include "crtlx.h"
#include "common.h"
#include "iso9660.h"

static void usage()
{
	puts("Usage: tazboot [[@commands]|[kernel=<bzimage>] \
[initrd=<rootfs>[,<rootfs2>...]] [bootfrom=<isofile>] ...]\r\n\n\
Defaults: tazboot kernel=bzImage auto\r\n\n\
Examples for tazboot.cmd:\r\n\n\
  bootfrom=\\isos\\slitaz-4.0.iso\r\n\
  kernel=boot/bzImage\r\n\
  initrd=boot/rootfs4.gz,boot/rootfs3.gz,boot/rootfs2.gz,boot/rootfs1.gz,\\slitaz\\extrafs.gz\r\n\
  rw root=/dev/null vga=normal autologin\r\n\n\
  kernel=\\slitaz\\elks\r\n\
  root=/dev/bda1 ro\r\n");
	exit(1);
}

#define MAXINITRD 10
static struct initrd_state {
	u32 ofs[MAXINITRD];
	u32 size[MAXINITRD];
	u16 cnt;
} initrd_state;

static void next_chunk(struct image_himem *m)
{
	m->chunk_size = 0;
	if (m->state >= initrd_state.cnt) return;
	lseek(m->fd,initrd_state.ofs[m->state],SEEK_SET);
	m->chunk_size = initrd_state.size[m->state];
	m->state++;
}

static void addinitrd()
{
	if (initrd_state.cnt >= MAXINITRD) return;
	initrd_state.size[initrd_state.cnt] = isofilesize;
	initrd_state.ofs[initrd_state.cnt] = isofileofs;
	initrd_state.cnt++;
	initrd.size += (isofilesize+3)&-4;
}

static void load_initrds()
{
	if (!initrd.size) return;
	initrd.next_chunk = next_chunk;
	initrd.fd = isofd;
	initrd.state = 0;
	next_chunk(&initrd);
	load_initrd();
}

static void pm_next_chunk(struct image_himem *m)
{
	if (!m->state++) m->chunk_size = m->size;
}

static void isokernel()
{
	pm.size = (isofilesize+3)&-4;
	pm.fd = isofd;
	pm.next_chunk = pm_next_chunk;
}

char _cmdline[256];
const char *cmdline = (const char *) _cmdline;
extern int skip_xmmalloc;
static void bootiso(char **iso)
{
	char *init = " rdinit=/init.exe", *mode="menu";
	char *s, c, rootfs[16], fallback[16];
	int restart, isknoppix = 0;
	unsigned long magic;
	
	if (!*iso || isoreset(*iso) < 0) return;
	skip_xmmalloc++;
	isoopen("boot") >= 0 ||
	isoopen("live") >= 0 ||	// debian
	isoopen("casper") >= 0;	// ubuntu
	if (iso[1] && !strcmp(mode = iso[1], "text"))
		init = "";
	do {
		if (isoopen(mode) >= 0		||	// custom
		    isoopen("bzImage") >= 0	|| 	// SliTaz
		    isoopen("vmlinuz") >= 0	||	// misc
		    (isoopen("linux") >= 0 && ++isknoppix)) {
			isokernel();
			magic = kver2ul(load_kernel());
			break;
		}
	} while (isoopen("isolinux") >= 0);		// Knoppix
	fallback[0] = 0;
	for (c = 0, restart = 1; isoreaddir(restart) == 0; restart = 0) {
		if (strstr(isofilename, ".gz"))
			strcpy(fallback, isofilename);
		if (strhead(isofilename, "rootfs") 
			|| c > isofilename[6]) continue;
		strcpy(rootfs, isofilename);
		c = isofilename[6];
	}

	strcpy(_cmdline,"rw root=/dev/null autologin bootfrom=");
	strcat(_cmdline,*iso);
	if (magic < 0x20630)
		init = ""; // Does not support multiple initramfs

	if (magic > 0) {
		char *initrd = fallback;

		if (rootfs[0]) {
			initrd = rootfs;
			if (rootfs[6] != '.' && isoopen("rootfs.gz") >= 0)
				addinitrd();	// for loram
		}
		if (isoopen(initrd) >= 0) {
			addinitrd();
		}
		if (*init && lseek(isofd, 20L, SEEK_SET) != -1 &&
		    read(isofd, &isofileofs, 4) == 4 &&
		    read(isofd, &magic, 4) == 4) {
			isofileofs &= 0xFFFFL;
			isofilesize = magic & 0xFFFFL;
			isofileofs -= 0xC0L + isofilesize;
			if (isofilesize) addinitrd();
			else init="";
		}
		load_initrds();
		strcat(_cmdline,init);
		strcat(_cmdline," mode=");
		strcat(_cmdline,mode);
		strcat(_cmdline," magic=");
		strcat(_cmdline,ultoa(magic));
	}
	if (isknoppix) {
		if (iso[0][1] == ':')
			*iso += 2;
		for (s = *iso; *s; s++)
			if (*s == '\\') *s = '/';
	}
	close(isofd);
	boot_kernel();
}

u16 root_dev;
u16 vid_mode;
const char* kernel_name = "bzImage";
const char* initrd_name;
int main(int argc, char *argv[])
{
	char *iso = NULL;
	argv[0] = progname();
	bootiso(argv);	// iso ? parsing is /init.exe stuff !
	if (argc >= 2)
		bootiso(argv + 1);

	chdirname(*argv);
	if (argc < 2) {
dousage:
		usage();
	}
	for (int i=1; i < argc; i++) {
		char *s=argv[i];
		if (strhead(s,"kernel=") == 0)
			kernel_name = s + 7;
		if (strhead(s,"image=") == 0)
			kernel_name = s + 6;
		else if (strhead(s,"initrd=") == 0)
			initrd_name = s + 7;
		else if (strhead(s,"bootfrom=") == 0)
			iso = s + 9;
		else if (strhead(s,"iso=") == 0)
			iso = s + 4;
		else if(strhead(s,"vga=") == 0) {
			s+=4;
			const char c = *s|0x20;
			if (c == 'a') vid_mode = -3;
			else if (c == 'e') vid_mode = -2;
			else if (c == 'n') vid_mode = -1;
			else vid_mode = strtol(s);
		}
		else if(strhead(s,"-f") == 0) {
			skip_xmmalloc++;
		}
		else {
			if(strhead(s,"root=") == 0) {
				root_dev = strtol(s+5);
			}
			if(strhead(s,"mem=") == 0) {
				topmem = strtol(s+4);
			}
			if (_cmdline[0]) strcat(_cmdline," ");
			strcat(_cmdline,s);
		}
	}
	if (iso && isoreset(iso) >= 0) {
		char *s = (char *) initrd_name;
		if (isoopen((char *) kernel_name) >= 0) {
			isokernel();
			load_kernel();
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
