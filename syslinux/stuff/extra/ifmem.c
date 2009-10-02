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

struct e820_data {
  uint64_t base;
  uint64_t len;
  uint32_t type;
  uint32_t extattr;
} __attribute__((packed));

// Get memory size in Kb
static unsigned long memory_size(void)
{
  uint64_t bytes = 0;
  com32sys_t ireg, oreg;
  struct e820_data ed;

  memset(&ireg, 0, sizeof ireg);

  ireg.eax.w[0] = 0xe820;
  ireg.edx.l    = 0x534d4150;
  ireg.ecx.l    = sizeof(struct e820_data);
  ireg.edi.w[0] = OFFS(__com32.cs_bounce);
  ireg.es       = SEG(__com32.cs_bounce);

  memset(&ed, 0, sizeof ed);
  ed.extattr = 1;

  do {
    memcpy(__com32.cs_bounce, &ed, sizeof ed);

    __intcall(0x15, &ireg, &oreg);
    if (oreg.eflags.l & EFLAGS_CF ||
	oreg.eax.l != 0x534d4150 ||
	oreg.ecx.l < 20)
      break;

    memcpy(&ed, __com32.cs_bounce, sizeof ed);

    if (ed.type == 1)
       bytes += ed.len;

    ireg.ebx.l = oreg.ebx.l;
  } while (ireg.ebx.l);

  if (!bytes) {
     memset(&ireg, 0, sizeof ireg);
     ireg.eax.w[0] = 0x8800;
     __intcall(0x15, &ireg, &oreg);
     return ireg.eax.w[0];
  }
  return bytes / 1024;
}

int main(int argc, char *argv[])
{
  char *s;
  int i, j = 1;
  unsigned long ram_size;

  for (s = argv[1]; *s && (*s < '0' || *s > '9'); s++);

  openconsole(&dev_null_r, &dev_stdcon_w);
  if (argc < 4 || !*s) {
    perror("\nUsage: ifmem.c32 size_KB boot_large_memory boot_small_memory\n");
    return 1;
  }

  // find target according to ram size
  ram_size = memory_size();
  printf("Total memory found %luK.\n",ram_size);
  for (i = 1; i + 2 < argc; ) { 
    char *p = s;
    unsigned long scale = 1;
    
    if (*p) while (p[1]) p++;
    switch (*p | 0x20) {
    case 'g': scale = 1024*1024; *p = 0; break;
    case 'm': scale = 1024;
    case 'k': *p = 0; break;
    }
    j = i++; // size
    if (ram_size >= scale * strtoul(s, NULL, 0)) break;
    s = argv[++i];
  }

  // find and copy extra parameters to command line
  // assume the command line ends with two words (not number)
  for (s = argv[i++]; i < argc; i++) { 
	char c = *argv[i];
	if (c >= '0' && c <= '9') j = i;
	if (i - j > 2 && i < argc) {
#define SZ 4096
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
		break;
	}
  }

  if (s) syslinux_run_command(s);
  else   syslinux_run_default();
  return -1;
}
