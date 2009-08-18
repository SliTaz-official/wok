/* ----------------------------------------------------------------------- *
 *
 *   Copyright 2009 Pascal Bellard - All Rights Reserved
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
 *   Boston MA 02110-1301, USA; either version 2 of the License, or
 *   (at your option) any later version; incorporated herein by reference.
 *
 * ----------------------------------------------------------------------- */

/*
 * ifmem.c
 *
 * Run one command if the memory is large enought, and another if it isn't.
 *
 * Usage:
 *
 *    label boot_kernel
 *        kernel ifmem.c
 *        append size_in_KB boot_large [size_in_KB boot_medium] boot_small
 *
 *    label boot_large
 *        kernel vmlinuz_large_memory
 *        append ...
 *
 *    label boot_small
 *        kernel vmlinuz_small_memory
 *        append ...
 */

#include <inttypes.h>
#include <com32.h>
#include <console.h>
#include <stdio.h>
#include <string.h>
#include <alloca.h>
#include <stdlib.h>
#include <syslinux/boot.h>

static unsigned long memory_size(void)
{
  unsigned long res;
  com32sys_t ireg, oreg;

  memset(&ireg, 0, sizeof ireg);

  ireg.eax.w[0] = 0xe801;
  __intcall(0x15, &ireg, &oreg);

  res = oreg.ecx.w[0] + ( oreg.edx.w[0] << 6);
  if (!res) {
  	memset(&ireg, 0, sizeof ireg);
  	ireg.eax.w[0] = 0x8800;
  	__intcall(0x15, &ireg, &oreg);
	res = ireg.eax.w[0];
  }
  return res;
}

int main(int argc, char *argv[])
{
  char *s;
  int i, j = 1;

  for (s = argv[1]; *s && (*s < '0' || *s > '9'); s++);

  if (argc < 4 || !*s) {
    openconsole(&dev_null_r, &dev_stdcon_w);
    perror("\nUsage: ifmem.c32 size_KB boot_large_memory boot_small_memory\n");
    return 1;
  }

  // find target according to ram size
  for (i = 1; i + 2 < argc; ) { 
    j = i++; // size
    if (memory_size() >= strtoul(s, NULL, 0)) break;
    s = argv[++i];
  }

  // find and copy extra parameters to command line
  // assume the command line ends with two words (not number)
  for (s = argv[i++]; i < argc; i++) { 
	char c = *argv[i];
	if (c >= '0' && c <= '9') j = i;
	if (i - j > 2 && i < argc) {
#define SZ 512
		static char cmdline[SZ];
		char *p = cmdline, *q = s;
		int j;
		for (j = i; j <= argc; j++) {
			while (*q && p < cmdline + SZ -1) *p++ = *q++;
			if (p < cmdline + SZ -1) *p++ = ' ';
			q = argv[j];
		}
		*p++ = 0;
		s = cmdline;
	}
  }

  if (s) syslinux_run_command(s);
  else   syslinux_run_default();
  return -1;
}
