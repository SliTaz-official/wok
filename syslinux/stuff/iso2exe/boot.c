#include <asm/limits.h>
#include <sys/types.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include "iso9660.h"
#include "bootlinux.h"
#include "libdos.h"

static void usage(char *iso)
{
	printf("Usage: %s [[@commands]|[kernel=<bzimage>] \
[initrd=<rootfs>[,<rootfs2>...]] [iso=<isofile>] ...]\n\n\
Defaults: %s @tazboot.cmd  or  %s kernel=bzImage auto\n\n\
Examples for tazboot.cmd:\n\n\
  iso=\\isos\\slitaz-4.0.iso\n\
  kernel=boot/bzImage\n\
  initrd=boot/rootfs4.gz,boot/rootfs3.gz,boot/rootfs2.gz,boot/rootfs1.gz\n\
  rw root=/dev/null vga=normal autologin\n\n\
  kernel=\\slitaz\\vmlinuz\n\
  root=/dev/sda5 ro\n",iso,iso,iso);
	exit(1);
}

static void bootiso(char **iso)
{
	char *init = "rdinit=/init.exe", *mode="menu";
	char c, *s, rootfs[16], cmdline[256];
	int fd, restart;
	unsigned long magic;
	
	if (isoreset(*iso) || isoopen("boot")) return;
	if (iso[1] && !strcmp(mode = iso[1], "text"))
		init = "";
	for (c = 0, restart = 1; isoreaddir(restart) == 0; restart = 0) {
		if (strncmp(isofilename, "rootfs", 6) || c > s[6]) continue;
		strcpy(rootfs, isofilename);
		c = s[6];
	}
	if (isoopen(mode))
		isoopen("bzImage");
	loadkernel();
	isoopen(rootfs);
	loadinitrd();
	lseek(isofd, 28, SEEK_SET);
	read(isofd, &magic, 4);
	isofilesize = magic & 0xFFFF;
	isofileofs = 0x8000 - isofilesize;
	loadinitrd();
	close(isofd);
	sprintf(cmdline,"rw root=/dev/null %s iso=%s magic=%lu mode=%s",
		init, *iso, magic, mode);
	bootlinux(cmdline);
}

static int stricmp(char *ref, char *s)
{
	char c;
	while (*ref) {
		c = *s++;
		if (c >= 'A' && c <= 'Z') c += 'a' - 'A';
		c -= *ref++;
		if (c) return c;
	}
	return 0;
}

static char *iso;
static int fakeopen(char *file)
{
	if (iso) {
		isoreset(iso);
		return isoopen(file);
	}
	close(isofd);
	isofd = open(file, O_RDONLY);
	if (isofd != -1) {
		isofileofs = 0;
		isofilesize = LONG_MAX;
	}
	return isofd;
}

static char args[2048];
int main(int argc, char *argv[])
{
	char *kernel, *initrd, *cmdline, *cmdfile, *s;
	
	argv[0] = progname();
	bootiso(argv);		// iso ? parsing is /init.exe stuff !

	chdirname(*argv);
	cmdfile = "tazboot.cmd";
	kernel  = "bzImage";
	initrd  = NULL;
	cmdline = "auto";
	if (argc > 1) {
		if (argv[1][0] == '@')
			cmdfile = argv[1] + 1;
		else {
			cmdfile = NULL;
#asm
		push	ds
		push	ds
		pop	es
		push	cs
		pop	ds
		mov	si, #0x82
		mov	di, #_args
		mov	cx, #0x7E/2
		rep
		  movsw
		pop	ds
#endasm
		}
	}
	if (cmdfile) {
		int fd;
		fd = open(cmdfile, O_RDONLY);;
		if (fd != -1) {
			read(fd, args, sizeof(args));
			close(fd);
			for (s = args; s < args + sizeof(args) -1; s++) {
				if (*s == '\r') *s++ = ' ';
				if (*s == '\n') *s   = ' ';
			}
		}
	}
	for (s = args; s < args + sizeof(args); s++) {
		if (*s == ' ') continue;
		if (stricmp("kernel=", s) == 0)
			kernel = s + 7;
		else if (stricmp("initrd=", s) == 0)
			initrd = s + 7;
		else if (stricmp("iso=", s) == 0)
			iso = s + 4;
		else {
			cmdline = s;
			break;
		}
		while (*s && *s != ' ') s++;
		*s = 0;
	}
	if (fakeopen(kernel) == -1)
		usage(argv[0]);
	loadkernel();
	if (initrd) {
		char *p, *q = initrd;
		while (1) {
			char c;
			for (p = q; *p && *p != ','; p++);
			c = *p;
			*p = 0;
			if (fakeopen(q) != -1)
				loadinitrd();
			if (c == 0)
				break;
			q = ++p;
		}
	}
	bootlinux(cmdline);
}
