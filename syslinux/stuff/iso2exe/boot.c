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
[initrd=<rootfs>[,<rootfs2>...]] [bootfrom=<isofile>] ...]\n\n\
Defaults: %s @tazboot.cmd  or  %s kernel=bzImage auto\n\n\
Examples for tazboot.cmd:\n\n\
  bootfrom=\\isos\\slitaz-4.0.iso\n\
  kernel=boot/bzImage\n\
  initrd=boot/rootfs4.gz,boot/rootfs3.gz,boot/rootfs2.gz,boot/rootfs1.gz,\\slitaz\\extrafs.gz\n\
  rw root=/dev/null vga=normal autologin\n\n\
  kernel=\\slitaz\\vmlinuz\n\
  root=/dev/sda5 ro\n",iso,iso,iso);
	exit(1);
}

static void bootiso(char **iso)
{
	char *init = " rdinit=/init.exe", *mode="menu", *fmt="";
	char *s, c, rootfs[16], fallback[16], cmdline[256];
	int restart, isknoppix = 0;
	unsigned long magic;
	
	if (isoreset(*iso)) return;
	!isoopen("boot") ||
	!isoopen("live") ||	// debian
	!isoopen("casper") ||	// ubuntu
	!isoopen("isolinux");	// zeroshell
	if (iso[1] && !strcmp(mode = iso[1], "text"))
		init = "";
	do {
		if (!isoopen(mode)	||	// custom
		    !isoopen("bzImage")	|| 	// SliTaz
		    !isoopen("linux24")	||	// dsl
		    !isoopen("vmlinuz")	||	// misc
		    (!isoopen("linux") && ++isknoppix)) {
			magic = loadkernel();
			break;
		}
	} while (!isoopen("isolinux"));		// Knoppix
	fallback[0] = 0;
	for (c = 0, restart = 1; isoreaddir(restart) == 0; restart = 0) {
		if (strstr(isofilename, ".gz"))
			strcpy(fallback, isofilename);
		if (strncmp(isofilename, "rootfs", 6) 
			|| c > isofilename[6]) continue;
		strcpy(rootfs, isofilename);
		c = isofilename[6];
	}

	if (magic < 0x20630)
		init = ""; // Does not support multiple initramfs

	if (magic > 0) {
		char *initrd = fallback;

		fmt = "rw root=/dev/null bootfrom=%s%s magic=%lu mode=%s autologin";
		if (rootfs[0]) {
			initrd = rootfs;
			if (rootfs[6] != '.' && !isoopen("rootfs.gz"))
				loadinitrd();	// for loram
		}
		if (!isoopen(initrd)) {
			loadinitrd();
		}
		if (*init) {
			lseek(isofd, 24L, SEEK_SET);
			read(isofd, &magic, 4);
			isofilesize = magic & 0xFFFFL;
			isofileofs = 0x7EE0L - isofilesize;
			if (isofilesize) loadinitrd();
			else init="";
		}
	}
	if (isknoppix) {
		if (iso[0][1] == ':')
			*iso += 2;
		for (s = *iso; *s; s++)
			if (*s == '\\') *s = '/';
	}
	sprintf(cmdline, fmt, *iso, init, magic, mode);
	close(isofd);
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

static int chkstatus(int status, char *name)
{
	if (status == -1)
		printf("%s not found.\n",name);
	return status;
}

static char *iso;
static int fakeopen(char *file)
{
	if (file) {
		char *s = file;
		while (*s && *s != '\r' && *s != '\n') s++;
		*s = 0;
	}
	if (*file == '\\') {
		static fd = -1;
		if (fd >= 0) close(fd);
		fd = chkstatus(open(file, O_RDONLY), file);
		return fd;
	}
	if (iso) {
		chkstatus(isoreset(iso), iso);
		return chkstatus(isoopen(file), file);
	}
	close(isofd);
	isofd = chkstatus(open(file, O_RDONLY), file);
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
	bootiso(argv);	// iso ? parsing is /init.exe stuff !
	if (argc >= 2)
		bootiso(argv + 1);

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
		pop	es
		mov	si, #0x82
		mov	di, #_args
		mov	cx, #0x7E/2
		rep
		 seg	cs
		  movsw
#endasm
		}
	}
	if (cmdfile) {
		int fd;
		fd = chkstatus(open(cmdfile, O_RDONLY), cmdfile);
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
		else if (stricmp("bootfrom=", s) == 0)
			iso = s + 4;
		else {
			cmdline = s;
			break;
		}
		while (*s && *s != ' ') s++;
		*s = 0;
	}
	if (cmdline) {
		char *last;
		for (s = cmdline; *s && *s != '\r' && *s != '\n'; s++)
			if (*s != ' ') last = s;
		*++last = 0;
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
