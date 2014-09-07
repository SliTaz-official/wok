/*
 * Simple example of use of vm86: launch a basic .com DOS executable
 */
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/statfs.h>
#include <signal.h>
#include <errno.h>
#include <ctype.h>
#include <termios.h>
#include <dirent.h>
#include <fnmatch.h>

#include <sys/syscall.h>
#include <asm/vm86.h>

//#define DUMP_INT21

static inline int vm86(int func, struct vm86plus_struct *v86)
{
    return syscall(__NR_vm86, func, v86);
}

#define CF_MASK 		0x00000001
#define ZF_MASK 		0x00000040
#define TF_MASK 		0x00000100
#define IF_MASK 		0x00000200
#define DF_MASK 		0x00000400
#define IOPL_MASK		0x00003000
#define NT_MASK	         	0x00004000
#define RF_MASK			0x00010000
#define VM_MASK			0x00020000
#define AC_MASK			0x00040000
#define VIF_MASK                0x00080000
#define VIP_MASK                0x00100000
#define ID_MASK                 0x00200000

void usage(void)
{
    printf("runcom version 0.2-slitaz (c) 2003-2011 Fabrice Bellard\n"
           "usage: runcom file.com [args...]\n"
           "Run simple .com DOS executables (linux vm86 test mode)\n");
    exit(1);
}

static inline void set_bit(uint8_t *a, unsigned int bit)
{
    a[bit / 8] |= (1 << (bit % 8));
}

static inline uint8_t *seg_to_linear(unsigned int seg, unsigned int reg)
{
    return (uint8_t *)((seg << 4) + (reg & 0xffff));
}

static inline void pushw(struct vm86_regs *r, int val)
{
    r->esp = (r->esp & ~0xffff) | ((r->esp - 2) & 0xffff);
    *(uint16_t *)seg_to_linear(r->ss, r->esp) = val;
}

void dump_regs(struct vm86_regs *r)
{
    int i;
    uint8_t *p8;
    uint16_t *p16;
    fprintf(stderr,
            "EAX=%08lx EBX=%08lx ECX=%08lx EDX=%08lx\n"
            "ESI=%08lx EDI=%08lx EBP=%08lx ESP=%08lx\n"
            "EIP=%08lx EFL=%08lx "
            "CS=%04x DS=%04x ES=%04x SS=%04x FS=%04x GS=%04x\n[SP]",
            r->eax, r->ebx, r->ecx, r->edx, r->esi, r->edi, r->ebp, r->esp,
            r->eip, r->eflags,
            r->cs, r->ds, r->es, r->ss, r->fs, r->gs);
    for (p16 = (uint16_t *) seg_to_linear(r->ss, r->esp), i = 0; i < 15; i++)
    	fprintf(stderr," %04x", *p16++);
    fprintf(stderr,"\n[IP]");
    for (p8 = seg_to_linear(r->cs, r->eip), i = 0; i < 25; i++)
    	fprintf(stderr," %02x", *p8++);
    fprintf(stderr,"\n");
}

static int argflags;
#define DEBUG 1

#define DOS_FD_MAX 256
typedef struct {
    int fd; /* -1 means closed */
} DOSFile;

DOSFile dos_files[DOS_FD_MAX];
uint16_t cur_psp;
uint16_t cur_dta_seg;
uint16_t cur_dta_ofs;

void dos_init(void)
{
    int i;
    for(i = 0; i < DOS_FD_MAX; i++)
        dos_files[i].fd = (i < 3) ? i : -1;
}

static inline void set_error(struct vm86_regs *r, int val)
{
    r->eflags &= ~CF_MASK;
    if (val) {
        r->eax = (r->eax & ~0xffff) | val;
        r->eflags |= CF_MASK;
    }
}
static DOSFile *get_file(int h)
{
    DOSFile *fh;

    if (h < DOS_FD_MAX) {
        fh = &dos_files[h];
        if (fh->fd != -1)
            return fh;
    }
    return NULL;
}

/* return -1 if error */
static int get_new_handle(void)
{
    DOSFile *fh;
    int i;

    for(i = 0; i < DOS_FD_MAX; i++) {
        fh = &dos_files[i];
        if (fh->fd == -1)
            return i;
    }
    return -1;
}

static char *get_filename1(struct vm86_regs *r, char *buf, int buf_size,
                           uint16_t seg, uint16_t offset)
{
    char *q;
    int c;
    q = buf;
    for(;;) {
        c = *seg_to_linear(seg, offset);
        if (c == 0)
            break;
        if (q >= buf + buf_size - 1)
            break;
        c = tolower(c);
        if (c == '\\')
            c = '/';
        *q++ = c;
        offset++;
    }
    *q = '\0';
    if (buf[1] == ':')
    	strcpy(buf, buf+2);
    return buf;
} 

static char *get_filename(struct vm86_regs *r, char *buf, int buf_size)
{
    return get_filename1(r, buf, buf_size, r->ds, r->edx & 0xffff);
}

static char *upcase(const char *s)
{
    static char buffer[80];
    int i;
    for (i = 0; i < sizeof(buffer)-1; i++, s++)
	buffer[i] = (*s >= 'a' && *s <= 'z') ? *s + 'A' - 'a' : *s;
    return buffer;
}

typedef struct __attribute__((packed)) {
    uint8_t drive_num;
    uint8_t file_name[8];
    uint8_t file_ext[3];
    uint16_t current_block;
    uint16_t logical_record_size;
    uint32_t file_size;
    uint16_t date;
    uint16_t time;
    uint8_t reserved[8];
    uint8_t record_in_block;
    uint32_t record_num;
} FCB;

typedef struct __attribute__((packed)) {
    uint16_t environ;
    uint16_t cmdtail_off;
    uint16_t cmdtail_seg;
    uint32_t fcb1;
    uint32_t fcb2;
    uint16_t sp, ss;
    uint16_t ip, cs;
} ExecParamBlock;

typedef struct __attribute__((packed)) {
    /* internals */
	uint8_t attr;		/* 00 */
	uint8_t drive_letter;	/* 01 */
	uint8_t template[11];	/* 02 */
	uint16_t entry_count;	/* 0D */
	uint32_t dta_address;	/* 0F */
	uint16_t cluster_parent_dir;	/* 13 */
    /* output */
	uint8_t attr_found;	/* 15 */
	uint16_t file_time;	/* 16 */
	uint16_t file_date;	/* 18 */
	uint32_t file_size;	/* 1A */
	uint8_t filename[13];	/* 1E */
} dirdta;

typedef struct MemBlock {
    struct MemBlock *next;
    uint16_t seg;
    uint16_t size; /* in paragraphs */
} MemBlock;

/* first allocated paragraph */
MemBlock *first_mem_block = NULL;

#define MEM_START 0x1000
#define MEM_END   0xa000

/* return -1 if error */
int mem_malloc(int size, int *pmax_size)
{
    MemBlock *m, **pm;
    int seg_free, seg;
    
    /* XXX: this is totally inefficient, but we have only 1 or 2
       blocks ! */
    seg_free = MEM_START;
    for(pm = &first_mem_block; *pm != NULL; pm = &(*pm)->next) {
        m = *pm;
        seg = m->seg + m->size;
        if (seg > seg_free)
            seg_free = seg;
    }
    if ((seg_free + size) > MEM_END)
        return -1;
    if (pmax_size)
        *pmax_size = MEM_END - seg_free;
    /* add at the end */
    m = malloc(sizeof(MemBlock));
    *pm = m;
    m->next = NULL;
    m->seg = seg_free;
    m->size = size;
#ifdef DUMP_INT21
    printf("mem_malloc size=0x%04x: 0x%04x\n", size, seg_free);
#endif
    return seg_free;
}

/* return -1 if error */
int mem_free(int seg)
{
    MemBlock *m, **pm;
    for(pm = &first_mem_block; *pm != NULL; pm = &(*pm)->next) {
        m = *pm;
        if (m->seg == seg) {
            *pm = m->next;
            free(m);
            return 0;
        }
    }
    return -1;
}

/* return -1 if error or the maxmium size */
int mem_resize(int seg, int new_size)
{
    MemBlock *m, **pm, *m1;
    int max_size;

    for(pm = &first_mem_block; *pm != NULL; pm = &(*pm)->next) {
        m = *pm;
        if (m->seg == seg) {
            m1 = m->next;
            if (!m1)
                max_size = MEM_END - m->seg;
            else
                max_size = m1->seg - m->seg;
            if (new_size > max_size)
                return -1;
            m->size = new_size;
            return max_size;
        }
    }
    return -1;
}

int load_boot(const char *filename, struct vm86_regs *r)
{
    int fd, ret;

    /* load the boot sector */
    fd = open(filename, O_RDONLY);
    if (fd >= 0) {
    	*seg_to_linear(0x0, 0x7dff) = 0;
        r->eax = 0x200;
        r->ebx = r->esp = r->eip = 0x7c00;
        r->ecx = 1;
        r->esi = r->edi = r->ebp =
        r->edx = 0; /* floppy disk */
        r->cs = r->ss = r->ds = r->es = 0;
        r->eflags = VIF_MASK;
        ret = read(fd, seg_to_linear(0x0, 0x7c00), 0x200);
        if (lseek(fd, 0, SEEK_END) > 4*1024*1024)
            r->edx = 0x80; /* hard disk */
        close(fd);
        if (ret != 0x200 ||
            *seg_to_linear(0x0, 0x7dfe) != 0x55 ||
            *seg_to_linear(0x0, 0x7dff) != 0xaa) {
            fprintf(stderr,"No boot sector.\n");
            fd = -1;
        }
    }
    return fd;
}

/* return the PSP or -1 if error */
int load_exe(ExecParamBlock *blk, const char *filename,
             int psp, uint32_t *pfile_size)
{
    int fd, size, base;
    struct {
    	uint16_t signature;		// 0x5A4D 'MZ'
    	uint16_t bytes_in_last_block;
    	uint16_t blocks_in_file;	
    	uint16_t num_relocs;	
    	uint16_t header_paragraphs;	// Size of header
    	uint16_t min_extra_paragraphs;	// BSS size
    	uint16_t max_extra_paragraphs;
    	uint16_t ss;			// Initial (relative) SS value
    	uint16_t sp;			// Initial SP value
    	uint16_t checksum;
    	uint16_t ip;			// Initial IP value
    	uint16_t cs;			// Initial (relative) CS value
    	uint16_t reloc_table_offset;
    	uint16_t overlay_number;
    } header;
    struct {
    	uint16_t offset;
    	uint16_t segment;
    } rel;

    /* load the MSDOS .exe executable */
    fd = open(filename, O_RDONLY);
    if (fd < 0) {
        return -1;
    }
    if (read(fd, &header, sizeof(header)) != sizeof(header)) {
        close(fd);
        return -1;
    }
    
    memset(seg_to_linear(psp, 0x100), 0, 65536 - 0x100);
  
    size = (header.blocks_in_file * 512) - (header.header_paragraphs * 16) + 
    	(header.bytes_in_last_block ? header.bytes_in_last_block - 512 : 0);
    header.min_extra_paragraphs += (size-1)/16;
    
    /* address of last segment allocated */
    //*(uint16_t *)seg_to_linear(psp, 2) = psp + header.min_extra_paragraphs;
    *(uint16_t *)seg_to_linear(psp, 2) = 0x9fff;
    
    if (pfile_size)
        *pfile_size = size;

    if (mem_resize(psp, header.min_extra_paragraphs) < 0 ||
    	lseek(fd, header.header_paragraphs * 16, SEEK_SET) < 0 ||
        read(fd, seg_to_linear(psp, 0x100), size) != size ||
        lseek(fd, header.reloc_table_offset, SEEK_SET) < 0) {
        close(fd);
        return -1;
    }

    base = psp + 16;
    while (header.num_relocs-- && read(fd, &rel, sizeof(rel)) == sizeof(rel))
    	if (rel.segment != 0 || rel.offset != 0)
    	    * (uint16_t *) seg_to_linear(base + rel.segment, rel.offset) += base;
    close(fd);

    blk->cs = base + header.cs;
    blk->ip = header.ip;
    blk->ss = base + header.ss;
    blk->sp = header.sp - 6;

    /* push return far address */
    *(uint16_t *)seg_to_linear(blk->ss, blk->sp + 4) = psp;

    return psp;
}

/* return the PSP or -1 if error */
int load_com(ExecParamBlock *blk, const char *filename, uint32_t *pfile_size,
             int argc, char **argv)
{
    int psp, fd, ret;

    /* load the MSDOS .com executable */
    fd = open(filename, O_RDONLY);
    if (fd < 0)
        fd = open(upcase(filename), O_RDONLY);
    if (fd < 0) {
        return -1;
    }
    psp = mem_malloc(65536 / 16, NULL);
    ret = read(fd, seg_to_linear(psp, 0x100), 65536 - 0x100);
    close(fd);
    if (ret <= 0) {
        mem_free(psp);
        return -1;
    }
    if (pfile_size)
        *pfile_size = ret;
    
    /* reset the PSP */
    memset(seg_to_linear(psp, 0), 0, 0x100);

    * (uint16_t *) seg_to_linear(psp, 0) = 0x20CD; /* int $0x20 */
    /* address of last segment allocated */
    //*(uint16_t *)seg_to_linear(psp, 2) = psp + 0xfff;
    *(uint16_t *)seg_to_linear(psp, 2) = 0x9fff;

    if (argc) {
        int i, p;
        char *s;
        /* set the command line */
        p = 0x81;
        for(i = 2; i < argc; i++) {
            if (p >= 0xff)
                break;
            *seg_to_linear(psp, p++) = ' ';
            s = argv[i];
            while (*s) {
                if (p >= 0xff)
                    break;
                *seg_to_linear(psp, p++) = *s++;
            }
        }
        *seg_to_linear(psp, p) = '\r';
        *seg_to_linear(psp, 0x80) = p - 0x81;
    }
    else {
        int len;
        /* copy the command line */
        len = *seg_to_linear(blk->cmdtail_seg, blk->cmdtail_off);
        memcpy(seg_to_linear(psp, 0x80), 
               seg_to_linear(blk->cmdtail_seg, blk->cmdtail_off), len + 2);
    }

    blk->sp = 0xfffc;
    blk->ip = 0x100;
    blk->cs = blk->ss = psp;

    if (*(uint16_t *)seg_to_linear(psp, 0x100) == 0x5A4D)
        psp = load_exe(blk, filename, psp, pfile_size);
    
    /* push ax value */
    *(uint16_t *)seg_to_linear(blk->ss, blk->sp) = 0;
    /* push return address to 0 */
    *(uint16_t *)seg_to_linear(blk->ss, blk->sp + 2) = 0;
 
    return psp;
}


void unsupported_function(struct vm86_regs *r, uint8_t num, uint8_t ah)
{
    fprintf(stderr, "int 0x%02x: unsupported function 0x%02x\n", num, ah);
    dump_regs(r);
    set_error(r, 0x01); /* function number invalid */
}

/* Open hard disk image ./hd[0-7] / floppy image ./fd[0-7] or /dev/fd[0-7] */
int open_disk(struct vm86_regs *r)
{
    int fd = -1, drive = r->edx & 0xff;
    char filename[9], n = '0' + (drive & 7);
    if (drive > 127) {
        strcpy(filename,"hd0");
        filename[2] = n;
    }
    else {
        strcpy(filename,"/dev/fd0");
        filename[7] = n;
        fd = open(filename+5, O_RDONLY);
    }
    if (fd < 0)
        fd = open(filename, O_RDONLY);
    return fd;
}


void read_sectors(int fd, struct vm86_regs *r, int first_sector, 
                  int sector_count, void *buffer) 
{
    int drive = r->edx & 0xff;
    r->eax &= ~0xff00;
    r->eax |= 0x0400; /* sector not found */
    r->eflags |= CF_MASK;
    if (fd >= 0) {
        static struct stat st;
        first_sector <<= 9;
        sector_count <<= 9;
    	if (drive < 8 && fstat(fd, &st) == 0) {
            static ino_t inodes[8];
            ino_t last = inodes[drive];
            inodes[drive] = st.st_ino;
            if (last && last != st.st_ino) {
                set_error(r, 0x0600); /* floppy disk swap */
                goto failed;
            }
    	}
        if (lseek(fd, first_sector, SEEK_SET) >= 0 &&
            read(fd, buffer, sector_count) == sector_count) {
            r->eax &= ~0xff00;
            r->eflags &= ~CF_MASK;
        }
    failed:
        close(fd);
    }
}

#define ESC "\033"
void do_int10(struct vm86_regs *r)
{
    uint8_t ah;
    char buf[20];
    static unsigned cursorlines = 0x0607;
    static unsigned activepage = 0;
    static uint8_t cursrow, curscol;
    
    ah = (r->eax >> 8);
    switch(ah) {
    case 0x02: /* set cursor position (BH == page number) */
        cursrow = r->edx >> 8;
        curscol = r->edx;
        * (uint16_t *) seg_to_linear(0x40, 0x50 + 2*((r->ebx >> 8) & 0xFF)) = r->edx;
	sprintf(buf,ESC"[%u;%uH",cursrow + 1, curscol + 1);
	write(1, buf, strlen(buf));
        break;
    case 0x03: /* get cursor position (BH == page number) */
	r->eax = 0;
	r->ecx = cursorlines;
	r->edx &= ~0xFFFF;
        r->edx |= * (uint16_t *) seg_to_linear(0x40, 0x50 + 2*((r->ebx >> 8) & 0xFF));
	sprintf(buf,ESC"[%u;%uH",cursrow + 1, curscol + 1);
	write(1, buf, strlen(buf));
        break;
    case 0x05: /* set active page */
	activepage = r->eax & 0xFF;
        break;
    case 0x06: /* scroll up */
    case 0x07: /* scroll down */
	{
	    int i = r->eax & 0xFF;
	    if (i == 0) i = 50;
    	/* FIXME assume full row, ignore colums in CL, DL */
	    sprintf(buf,ESC"[%u;%ur",1+(r->ecx >> 8) & 0xFF, 1+(r->edx >> 8) & 0xFF);
	    write(1, buf, strlen(buf));
	    buf[2] = (ah != 6) ? 'T' : 'S';
	    while (i--) write(1,buf,3);
	}
        break;
    case 0x09: /* write char and attribute at cursor position (BH == page number) */
        {
            static char color[8] = "04261537";
            char extra[5], *s = extra;
            uint8_t c = r->eax;
            uint16_t n = r->ecx;
            int i;

	    if (r->ebx & 0x8) { *s++ = '1'; *s++ = ';'; } // bold
	    if (r->ebx & 0x80) { *s++ = '5'; *s++ = ';'; } // blink
	    *s = 0;
	    sprintf(buf,ESC"[0;%s4%c;3%cm",extra,
	    	   color[(r->ebx & 0x70) >> 4],color[r->ebx & 0x7]);
	    write(1, buf, strlen(buf));
            for (i = 0; i < n; i++) 
		write(1, &c, 1);
	    write(1, ESC"[0m", 4); /* restore attributes */
        }
        break;
    case 0x0E: /* write char */
        {
            uint8_t c = r->eax;
            write(1, &c, 1);
        }
        break;
    case 0x0F: /* get current video mode */
        {
	    r->eax &= ~0xFFFF;
	    r->eax |= 0x5003; /* color or 5007 mono */
	    r->ebx &= ~0xFF00;
	    r->ebx |= activepage << 8;
        }
        break;
    case 0x11: /* get window coordonates  */
        r->ecx &= ~0xFFFF;
        r->edx &= ~0xFFFF;
        r->edx |= ~0x1950; /* 80x25 */
        break;
    case 0x12: /* get blanking attribute (for scroll) */
        r->ebx &= ~0xFF00;
        break;
    case 0x1A: /* get display combination code */
#if 0
        set_error(r, 1);
#else
        r->eax &= ~0xFF;
        r->eax |= ~0x1A;
        r->ebx &= ~0xFFFF;
        r->ebx |= ~0x0202; // CGA + color display
#endif
        break;
    default:
        unsupported_function(r, 0x10, ah);
    }
}

void do_int13(struct vm86_regs *r)
{
    uint8_t ah;
    
    ah = (r->eax >> 8);
    switch(ah) {
    case 0x00: /* reset disk */
        {
            r->eax &= ~0xff00; /* success */
            r->eflags &= ~CF_MASK;
        }
        break;
    case 0x02: /* read disk CHS */
        {
            int fd, c, h, s, heads, sectors, cylinders;
            long size;
            fd = open_disk(r);
            if (fd >= 0) {
                size = lseek(fd, 0, SEEK_END) / 512;
                if ((r->edx & 0xff) > 127) {
        	    sectors = 63;
                    if (size % sectors)
        	        sectors = 62;
                    if (size % sectors)
        	        sectors = 32;
                    if (size % sectors)
        	        sectors = 17;
                    if (size % sectors)
                        fd = -1;
                    size /= sectors;
        	    for (heads = 256; size % heads; heads--);
        	    cylinders = size / heads;
                }
                else {
                    int i;
        	    heads = 1 + (size > 256*2);
        	    cylinders = 40 * (1 + (size > 512*2));
        	    size /= heads;
        	    for (i = 0; i < 5; i++)
        	        if (size % (cylinders + i) == 0) break;
        	    if (i == 5)
        	    	fd = -1;
        	    cylinders += i;
        	    sectors = size / cylinders;
                }
            }
            c = ((r->ecx & 0xC0) << 2) | ((r->ecx >> 8) & 0xff);
            h = (r->edx >> 8) & 0xff;
            s = (r->ecx & 0x3f) -1;
            if (fd < 0 || c >= cylinders || h >= heads || s >= sectors) {
                set_error(r, 0x0400); /* sector not found */
                break;
            }
            read_sectors(fd, r, (((c * heads) + h) * sectors) + s,
                         r->eax & 0xff, seg_to_linear(r->es, r->ebx));
        }
        break;
    case 0x42: /* read disk LBA */
        {
            uint16_t *packet = (uint16_t *) seg_to_linear(r->ds, r-> esi);
            uint8_t *to = seg_to_linear(packet[3], packet[2]);
            if ((packet[3] & packet[2]) == 0xffff)
            	to = * (uint8_t **) &packet[8]; 
            if (packet[0] != 0x0010 && packet[0] != 0x0018)
                goto unsupported;
            read_sectors(open_disk(r), r, * (uint32_t *) &packet[4], packet[1], to);
        }
        break;
    default:
    unsupported:
        unsupported_function(r, 0x13, ah);
    }
}

void do_int15(struct vm86_regs *r)
{
    uint8_t ah;
    
    ah = (r->eax >> 8);
    switch(ah) {
    case 0x87: /* move memory */
    	/* XXX */
        break;
    default:
        unsupported_function(r, 0x15, ah);
    }
}

void do_int16(struct vm86_regs *r)
{
    static uint16_t last_ax, hold_char;
    struct termios termios_def, termios_raw;
    uint8_t ah;
    
    ah = (r->eax >> 8);
    tcgetattr(0, &termios_def);
    termios_raw = termios_def;
    cfmakeraw(&termios_raw);
    tcsetattr(0, TCSADRAIN, &termios_raw);
    switch(ah) {
    case 0x01: /* test keyboard */
        {
            int count;
            r->eflags &= ~ZF_MASK;
            if (hold_char) {
                r->eax &= ~0xffff;
                r->eax |= last_ax;
                break;
            }
    	    if (ioctl(0, FIONREAD, &count) < 0 || count == 0) {
                r->eflags |= ZF_MASK;
                break;
            }
            hold_char = 2;
        }
    case 0x00: /* read keyboard */
        {
            uint8_t c;
            if (hold_char)
            	hold_char--;
            read(0, &c, 1);
            if (c == 3) {
                tcsetattr(0, TCSADRAIN, &termios_def);
                exit(0);
            }
            if (c == 10)
            	c = 13;
            r->eax &= ~0xffff;
            r->eax |= last_ax = c;
            /* XXX ah = scan code */
        }
        break;
    default:
        unsupported_function(r, 0x16, ah);
    }
    tcsetattr(0, TCSADRAIN, &termios_def);
}

void do_int1a(struct vm86_regs *r)
{
    uint8_t ah;
    
    ah = (r->eax >> 8);
    switch(ah) {
    case 0x00: /* GET SYSTEM TIME */
        {
            uint16_t *timer = (uint16_t *) seg_to_linear(0, 0x46C);
            r->ecx &= ~0xffff;
            r->ecx |= *timer++;
            r->edx &= ~0xffff;
            r->edx |= *timer;
            r->eax &= ~0xff;
        }
        break;
    default:
        unsupported_function(r, 0x1a, ah);
    }
}

void do_int20(struct vm86_regs *r)
{
    /* terminate program */
    exit(0);
}

void do_int21(struct vm86_regs *r)
{
    uint8_t ah;
    DIR *dirp;
    dirdta *dta;
    
    ah = (r->eax >> 8);
    switch(ah) {
    case 0x00: /* exit */
        exit(0);
    case 0x02: /* write char */
        {
            uint8_t c = r->edx;
            write(1, &c, 1);
        }
        break;
    case 0x08: /* read stdin */
        {
            read(0,&r->eax,1);
        }
        break;
    case 0x09: /* write string */
        {
            uint8_t c;
            int offset;
            offset = r->edx;
            for(;;) {
                c = *seg_to_linear(r->ds, offset);
                if (c == '$')
                    break;
                write(1, &c, 1);
                offset++;
            }
            r->eax = (r->eax & ~0xff) | '$';
        }
        break;
    case 0x0a: /* buffered input */
        {
            int max_len, cur_len, ret;
            uint8_t ch;
            uint16_t off;

            /* XXX: should use raw mode to avoid sending the CRLF to
               the terminal */
            off = r->edx & 0xffff;
            max_len = *seg_to_linear(r->ds, off);
            cur_len = 0;
            while (cur_len < max_len) {
                ret = read(0, &ch, 1);
                if (ret < 0) {
                    if (errno != EINTR && errno != EAGAIN)
                        break;
                } else if (ret == 0) {
                    break;
                } else {
                    if (ch == '\n')
                        break;
                }
                *seg_to_linear(r->ds, off + 2 + cur_len++) = ch;
            }
            *seg_to_linear(r->ds, off + 1) = cur_len;
            *seg_to_linear(r->ds, off + 2 + cur_len) = '\r';
        }
        break;
    case 0x0b: /* get stdin status */
        {
	    r->eax &= ~0xFF; /* no character available */
        }
        break;
    case 0x0d: /* disk reset */
        {
            sync();
        }
        break;
    case 0x0e: /* select default disk */
        {
            r->eax &= ~0xFF;
            r->eax |= 3; /* A: B: & C: valid */
        }
        break;
    case 0x19: /* get current default drive */
        {
	    r->eax &= ~0xFF;
	    r->eax |= 2; /* C: */
        }
        break;
    case 0x1a: /* set DTA (disk transfert address) */
        {
	    cur_dta_seg = r->ds;
	    cur_dta_ofs = r->edx;
        }
        break;
    case 0x25: /* set interrupt vector */
        {
            uint16_t *ptr;
            ptr = (uint16_t *)seg_to_linear(0, (r->eax & 0xff) * 4);
            ptr[0] = r->edx;
            ptr[1] = r->ds;
        }
        break;
    case 0x29: /* parse filename into FCB */
#if 0
        /* not really needed */
        {
            const uint8_t *p, *p_start;
            uint8_t file[8], ext[3]; 
            FCB *fcb;
            int file_len, ext_len, has_wildchars, c, drive_num;
            
            /* XXX: not complete at all */
            fcb = (FCB *)seg_to_linear(r->es, r->edi);
            printf("ds=0x%x si=0x%lx\n", r->ds, r->esi);
            p_start = (const uint8_t *)seg_to_linear(r->ds, r->esi);

            p = p_start;
            has_wildchars = 0;

            /* drive */
            if (isalpha(p[0]) && p[1] == ':') {
                drive_num = toupper(p[0]) - 'A' + 1;
                p += 2;
            } else {
                drive_num = 0;
            }

            /* filename */
            file_len = 0;
            for(;;) {
                c = *p;
                if (!(c >= 33 && c <= 126))
                    break;
                if (c == '.')
                    break;
                if (c == '*' || c == '?')
                    has_wildchars = 1;
                if (file_len < 8)
                    file[file_len++] = c;
            }
            memset(file + file_len, ' ', 8 - file_len);

            /* extension */
            ext_len = 0;
            if (*p == '.') {
                for(;;) {
                    c = *p;
                    if (!(c >= 33 && c <= 126))
                        break;
                    if (c == '*' || c == '?')
                        has_wildchars = 1;
                    ext[ext_len++] = c;
                    if (ext_len >= 3)
                        break;
                }
            }
            memset(ext + ext_len, ' ', 3 - ext_len);

#if 0
            {
                printf("drive=%d file=%8s ext=%3s\n",
                       drive_num, file, ext);
            }
#endif
            if (drive_num == 0 && r->eax & (1 << 1)) {
                /* keep drive */
            } else {
                fcb->drive_num = drive_num; /* default drive */
            }

            if (file_len == 0 && r->eax & (1 << 2)) {
                /* keep */
            } else {
                memcpy(fcb->file_name, file, 8);
            }

            if (ext_len == 0 && r->eax & (1 << 3)) {
                /* keep */
            } else {
                memcpy(fcb->file_ext, ext, 3);
            }
            r->eax = (r->eax & ~0xff) | has_wildchars;
            r->esi = (r->esi & ~0xffff) | ((r->esi + (p - p_start)) & 0xffff);
        }
#endif
        break;
    case 0x2A: /* get system date */
        {
            time_t t = time(NULL);
            struct tm *now=localtime(&t);
            
            r->ecx = now->tm_year;
            r->edx = (now->tm_mon * 256) + now->tm_mday;
            r->eax = now->tm_wday;;
        }
        break;
    case 0x2C: /* get system time */
        {
            time_t t = time(NULL);
            struct tm *now=localtime(&t);
            struct timeval tim;
            
            gettimeofday(&tim, NULL);
            r->edx = (now->tm_hour * 256) + now->tm_min;
            r->edx = (tim.tv_sec * 256) + tim.tv_usec/10000;
        }
        break;
    case 0x2f: /* get DTA (disk transfert address */
        {
	    r->es = cur_dta_seg;
	    r->ebx = cur_dta_ofs;
        }
        break;
    case 0x30: /* get dos version */
        {
            int major, minor, serial, oem;
            /* XXX: return correct value for FreeDOS */
            major = 0x03;
            minor = 0x31;
            serial = 0x123456;
            oem = 0x66;
            r->eax = (r->eax & ~0xffff) | major | (minor << 8);
            r->ecx = (r->ecx & ~0xffff) | (serial & 0xffff);
            r->ebx = (r->ebx & ~0xffff) | (serial & 0xff) | (0x66 << 8);
        }
        break;
    case 0x33: /* extended break checking */
        {
	    r->edx &= ~0xFFFF;
        }
        break;
    case 0x35: /* get interrupt vector */
        {
            uint16_t *ptr;
            ptr = (uint16_t *)seg_to_linear(0, (r->eax & 0xff) * 4);
            r->ebx = (r->ebx & ~0xffff) | ptr[0];
            r->es = ptr[1];
        }
        break;
    case 0x36: /* get free disk space */
        {
            struct statfs buf;
            
            if (statfs(".", &buf)) {
		r->eax |= 0xFFFF;
            }
            else {
		r->eax &= ~0xFFFF;
		r->eax |= buf.f_bsize / 512; /* sectors per cluster */
		r->ebx &= ~0xFFFF;
		r->ebx |= buf.f_bavail;
		r->ecx &= ~0xFFFF;
		r->ecx |= 512; /* bytes per sector */
		r->edx &= ~0xFFFF;
		r->edx |= buf.f_blocks;
            }
        }
        break;
    case 0x37: 
        {
            switch(r->eax & 0xff) {
            case 0x00: /* get switch char */
                r->eax = (r->eax & ~0xff) | 0x00;
                r->edx = (r->edx & ~0xff) | '/';
                break;
            default:
                goto unsupported;
            }
        }
        break;
    case 0x3B: 
        {
            char filename[1024];
        
            get_filename(r, filename, sizeof(filename));
            if (chdir(filename))
                set_error(r, 0x03); /* path not found */
        }
        break;
    case 0x3c: /* create or truncate file */
        {
            char filename[1024];
            int fd, h, flags;

            h = get_new_handle();
            if (h < 0) {
                set_error(r, 0x04); /* too many open files */
            } else {
                get_filename(r, filename, sizeof(filename));
                if (r->ecx & 1)
                    flags = 0444; /* read-only */
                else
                    flags = 0777;
                fd = open(filename, O_RDWR | O_TRUNC | O_CREAT, flags);
                if (fd < 0)
                    fd = open(upcase(filename), O_RDWR | O_TRUNC | O_CREAT, flags);
#ifdef DUMP_INT21
                printf("int21: create: file='%s' cx=0x%04x ret=%d\n", 
                       filename, (int)(r->ecx & 0xffff), h);
#endif
                if (fd < 0) {
                    set_error(r, 0x03); /* path not found */
                } else {
                    dos_files[h].fd = fd;
                    set_error(r, 0);
                    r->eax = (r->eax & ~0xffff) | h;
                }
            }
        }
        break;
    case 0x3d: /* open file */
        {
            char filename[1024];
            int fd, h;

            h = get_new_handle();
            if (h < 0) {
                set_error(r, 0x04); /* too many open files */
            } else {
                get_filename(r, filename, sizeof(filename));
                fd = open(filename, r->eax & 3);
                if (fd < 1)
                    fd = open(upcase(filename), r->eax & 3);
                if (fd < 0) {
                    set_error(r, 0x02); /* file not found */
                } else {
                    dos_files[h].fd = fd;
                    set_error(r, 0);
                    r->eax = (r->eax & ~0xffff) | h;
                }
            }
        }
        break;
    case 0x3e: /* close file */
        {
            DOSFile *fh = get_file(r->ebx & 0xffff);
#ifdef DUMP_INT21
            printf("int21: close fd=%d\n", (int)(r->ebx & 0xffff));
#endif
            if (!fh) {
                set_error(r, 0x06); /* invalid handle */
            } else {
                close(fh->fd);
                fh->fd = -1;
                set_error(r, 0);
            }
        }
        break;
    case 0x3f: /* read */
        {
            DOSFile *fh = get_file(r->ebx & 0xffff);
            int n, ret;

            if (!fh) {
                set_error(r, 0x06); /* invalid handle */
            } else {
                n = r->ecx & 0xffff;
                for(;;) {
                    ret = read(fh->fd, 
                               seg_to_linear(r->ds, r->edx), n);
                    if (ret < 0) {
                        if (errno != EINTR && errno != EAGAIN)
                            break;
                    } else {
                        break;
                    }
                }
#ifdef DUMP_INT21
                printf("int21: read: fd=%d n=%d ret=%d\n", 
                       (int)(r->ebx & 0xffff), n, ret);
#endif
                if (ret < 0) {
                    set_error(r, 0x05); /* acces denied */
                } else {
                    r->eax = (r->eax & ~0xffff) | ret;
                    set_error(r, 0);
                }
            }
        }
        break;
    case 0x40: /* write */
        {
            DOSFile *fh = get_file(r->ebx & 0xffff);
            int n, ret, pos;
            
            if (!fh) {
                set_error(r, 0x06); /* invalid handle */
            } else {
                n = r->ecx & 0xffff;
                if (n == 0) {
                    /* truncate */
                    pos = lseek(fh->fd, 0, SEEK_CUR);
                    if (pos >= 0) {
                        ret = ftruncate(fh->fd, pos);
                    } else {
                        ret = -1;
                    }
                } else {
                    for(;;) {
                        ret = write(fh->fd, 
                                    seg_to_linear(r->ds, r->edx), n);
                        if (ret < 0) {
                            if (errno != EINTR && errno != EAGAIN)
                                break;
                        } else {
                            break;
                        }
                    }
                }
#ifdef DUMP_INT21
                printf("int21: write: fd=%d n=%d ret=%d\n", 
                       (int)(r->ebx & 0xffff), n, ret);
#endif
                if (ret < 0) {
                    set_error(r, 0x05); /* acces denied */
                } else {
                    r->eax = (r->eax & ~0xffff) | ret;
                    set_error(r, 0);
                }
            }
        }
        break;
    case 0x41: /* unlink */
        {
            char filename[1024];
            get_filename(r, filename, sizeof(filename));
            if (unlink(filename) < 0 && unlink(upcase(filename))) {
                set_error(r, 0x02); /* file not found */
            } else {
                set_error(r, 0);
            }
        }
        break;
    case 0x42: /* lseek */
        {
            DOSFile *fh = get_file(r->ebx & 0xffff);
            int pos, ret;
            
            if (!fh) {
                set_error(r, 0x06); /* invalid handle */
            } else {
                pos = ((r->ecx & 0xffff) << 16) | (r->edx & 0xffff);
                ret = lseek(fh->fd, pos, r->eax & 0xff);
#ifdef DUMP_INT21
                printf("int21: lseek: fd=%d pos=%d whence=%d ret=%d\n", 
                       (int)(r->ebx & 0xffff), pos, (uint8_t)r->eax, ret);
#endif
                if (ret < 0) {
                    set_error(r, 0x01); /* function number invalid */
                } else {
                    r->edx = (r->edx & ~0xffff) | ((unsigned)ret >> 16);
                    r->eax = (r->eax & ~0xffff) | (ret & 0xffff);
                    set_error(r, 0);
                }
            }
        }
        break;
    case 0x43: /* get attribute */
        {
	    struct stat statbuf;
            char filename[1024];
            get_filename(r, filename, sizeof(filename));
            if (stat(filename, &statbuf) && stat(upcase(filename), &statbuf)) {
		set_error(r, 5);
            }
            else {
            	r->ecx &= ~0xFFFF;
		if (S_ISDIR(statbuf.st_mode)) r->ecx |= 0x10;
            }
        }
        break;
    case 0x44: /* ioctl */
        switch(r->eax & 0xff) {
        case 0x00: /* get device information */
            {
                DOSFile *fh = get_file(r->ebx & 0xffff);
                int ret;
                
                if (!fh) {
                    set_error(r, 0x06); /* invalid handle */
                } else {
                    ret = 0;
                    if (isatty(fh->fd)) {
                        ret |= 0x80;
                        if (fh->fd == 0)
                            ret |= (1 << 0);
                        else
                            ret |= (1 << 1);
                    }
                    r->edx = (r->edx & ~0xffff) | ret;
                    set_error(r, 0);
                }
            }
        case 0x01: /* set device information */
            break;
        default:
            goto unsupported;
        }
        break;
    case 0x47: /* get current directory (DL drive)*/
        {
            char *s = seg_to_linear(r->ds, r->esi);
            getcwd(s,64);
            strcpy(s,s+1);
            while (*s)
        	if (*s++ == '/')
        	    s[-1] = '\\';
            r->eax = 0x100;
        }
        break;
    case 0x48: /* allocate memory */
        {
            int ret, max_size;
#ifdef DUMP_INT21
            printf("int21: allocate memory: size=0x%04x\n", (uint16_t)r->ebx);
#endif
            ret = mem_malloc(r->ebx & 0xffff, &max_size);
            if (ret < 0) {
                set_error(r, 0x08); /* insufficient memory*/
            } else {
                r->eax = (r->eax & ~0xffff) | ret;
                r->ebx = (r->ebx & ~0xffff) | max_size;
                set_error(r, 0);
            }
        }
        break;
    case 0x49: /* free memory */
        {
#ifdef DUMP_INT21
            printf("int21: free memory: block=0x%04x\n", r->es);
#endif
            if (mem_free(r->es) < 0) {
                set_error(r, 0x09); /* memory block address invalid */
            } else {
                set_error(r, 0);
            }
        }
        break;
    case 0x4a: /* resize memory block */
        {
            int ret;
#ifdef DUMP_INT21
            printf("int21: resize memory block: block=0x%04x size=0x%04x\n", 
                   r->es, (uint16_t)r->ebx);
#endif
            ret = mem_resize(r->es, r->ebx & 0xffff);
            if (ret < 0) {
                set_error(r, 0x08); /* insufficient memory*/
            } else {
                r->ebx = (r->ebx & ~0xffff) | ret;
                set_error(r, 0);
            }
        }
        break;
    case 0x4b: /* load program */
        {
            char filename[1024];
            ExecParamBlock *blk;
            int ret;

            if ((r->eax & 0xff) != 0x01) /* only load */
                goto unsupported;
            get_filename(r, filename, sizeof(filename));
            blk = (ExecParamBlock *)seg_to_linear(r->es, r->ebx);
            ret = load_com(blk, filename, NULL, 0, NULL);
            if (ret < 0)
                ret = load_com(blk, upcase(filename), NULL, 0, NULL);
            if (ret < 0) {
                set_error(r, 0x02); /* file not found */
            } else {
                cur_dta_seg = cur_psp = ret;
                cur_dta_ofs = 0x80;
                set_error(r, 0);
            }
        }
        break;
    case 0x4c: /* exit with return code */
        exit(r->eax & 0xff);
        break;
    case 0x4e: /* find first matching file */
// TODO AL input support
	dirp = opendir(".");
	if (dirp == NULL) {
		set_error(r, (errno == ENOTDIR) ? 0x03 /* path not found */
						: 0x02 /* file not found */ );
		goto pattern_found;		
	}
	else {
		struct dirent *dp;
		char *s;
		
		dta = (dirdta *) seg_to_linear(cur_dta_seg, cur_dta_ofs);
		dta->attr = r->ecx;
    		* (DIR **) &dta->entry_count = dirp;
    		s = seg_to_linear(r->ds, r->edx);
    		if (s[1] == ':') s+= 2;
    		if (s[0] == '\\') s++;
		strncpy(dta->template, s, 11);
        // NO break;
    case 0x4f: /* find next matching file */
		dta = (dirdta *) seg_to_linear(cur_dta_seg, cur_dta_ofs);
    		dirp = * (DIR **) &dta->entry_count;
		while ((dp = readdir(dirp)) != NULL) {
			if (!fnmatch(dta->template, dp->d_name, 0)) {
				struct stat statbuf;
				
				r->eflags &= ~CF_MASK;
				strncpy(dta->filename, dp->d_name, 13);
				stat(dp->d_name, &statbuf);
				dta->file_size = statbuf.st_size;
				dta->file_date = 0; //DOSDATE(statbuf.st_mtime);
				dta->file_time = 0; //DOSIME(statbuf.st_mtime);
				dta->attr_found = S_ISDIR(statbuf.st_mode) ?
					0x10 /*aDvshr*/ : 0x20 /*Advshr*/;
#if 0
				if ((dta->attr_found ^ dta->attr) & 0x16)
					continue;
#endif
				goto pattern_found;		
			}
		}
	}
	closedir(dirp);
	set_error(r, 0x12 /* no more files */);
pattern_found:
        break;
    case 0x50: /* set PSP address */
#ifdef DUMP_INT21
        printf("int21: set PSP: 0x%04x\n", (uint16_t)r->ebx);
#endif
        cur_psp = r->ebx;
        break;
    case 0x51: /* get PSP address */
#ifdef DUMP_INT21
        printf("int21: get PSP: ret=0x%04x\n", cur_psp);
#endif
        r->ebx = (r->ebx & ~0xffff) | cur_psp;
        break;
    case 0x55: /* create child PSP */
        {
            uint8_t *psp_ptr;
#ifdef DUMP_INT21
            printf("int21: create child PSP: psp=0x%04x last_seg=0x%04x\n", 
                   (uint16_t)r->edx, (uint16_t)r->esi);
#endif
            psp_ptr = seg_to_linear(r->edx & 0xffff, 0);
            memset(psp_ptr, 0, 0x80);
            psp_ptr[0] = 0xcd; /* int $0x20 */
            psp_ptr[1] = 0x20;
            *(uint16_t *)(psp_ptr + 2) = r->esi;
            r->eax = (r->eax & ~0xff);
        }
        break;
    case 0x56: /* rename file (CL attribute mask) */
        if (rename((char *) seg_to_linear(r->ds, r->edx),
	           (char *) seg_to_linear(r->es, r->edi)))
	    set_error(r, 0x5 /* access denied or 2,3,0x11 */);
        break;
    default:
    unsupported:
        unsupported_function(r, 0x21, ah);
    }
}
    
void do_int29(struct vm86_regs *r)
{
    uint8_t c = r->eax;
    write(1, &c, 1);
}

static int int8pending;

void raise_interrupt(int number)
{
    if (* (uint32_t *) seg_to_linear(0, number * 4) == 0)
        return;
    int8pending++;
}

void biosclock()
{
    //uint32_t *timer = (uint32_t *) seg_to_linear(0, 0x46C);
    //++*timer;
    raise_interrupt(8);
    //raise_interrupt(0x1C);
}

static void exec_int(struct vm86_regs *r, unsigned num)
{
    uint16_t *int_vector;
    uint32_t eflags;

    eflags = r->eflags & ~IF_MASK;
    if (r->eflags & VIF_MASK)
        eflags |= IF_MASK;
    pushw(r, eflags);
    pushw(r, r->cs);
    pushw(r, r->eip);
    int_vector = (uint16_t *)seg_to_linear(0, num * 4);
    r->eip = int_vector[0];
    r->cs = int_vector[1];
    r->eflags &= ~(VIF_MASK | TF_MASK | AC_MASK);
}

int main(int argc, char **argv)
{
    uint8_t *vm86_mem;
    const char *filename;
    int i, ret;
    uint32_t file_size;
    struct sigaction sa; 
    struct itimerval timerval;
    struct vm86plus_struct ctx;
    struct vm86_regs *r;
    ExecParamBlock blk1, *blk = &blk1;

    for (argflags = 0; *argv[1] == '-'; argv++) {
    	char *s = argv[1];

    	while (1)
    	switch (*++s) {
    	case 'd' : argflags |= DEBUG; break;
    	case 0 : goto nextargv;
    	}
nextargv:;
    }
    if (argc < 2)
        usage();
    filename = argv[1];

    vm86_mem = mmap((void *)0x00000000, 0x110000,
                    PROT_WRITE | PROT_READ | PROT_EXEC,
                    MAP_FIXED | MAP_ANON | MAP_PRIVATE, -1, 0);
    if (vm86_mem == MAP_FAILED) {
        perror("mmap");
        exit(1);
    }

    memset(&ctx, 0, sizeof(ctx));
    r = &ctx.regs;
    set_bit((uint8_t *)&ctx.int_revectored, 0x10);
    set_bit((uint8_t *)&ctx.int_revectored, 0x13);
    set_bit((uint8_t *)&ctx.int_revectored, 0x15);
    set_bit((uint8_t *)&ctx.int_revectored, 0x16);
    set_bit((uint8_t *)&ctx.int_revectored, 0x1a);
    set_bit((uint8_t *)&ctx.int_revectored, 0x20);
    set_bit((uint8_t *)&ctx.int_revectored, 0x21);
    set_bit((uint8_t *)&ctx.int_revectored, 0x29);

    dos_init();

    if (strstr(filename,".com") || strstr(filename,".exe") ||
        strstr(filename,".COM") || strstr(filename,".EXE")) {
        ret = load_com(blk, filename, &file_size, argc, argv);
        if (ret < 0) {
            perror(filename);
            exit(1);
        }
        cur_dta_seg = cur_psp = ret;
        cur_dta_ofs = 0x80;

        /* init basic registers */
        r->eip = blk->ip;
        r->esp = blk->sp + 2; /* pop ax value */
        r->cs = blk->cs;
        r->ss = blk->ss;
        r->ds = cur_psp;
        r->es = cur_psp;
        r->eflags = VIF_MASK;
    
        /* the value of these registers seem to be assumed by pi_10.com */
        r->esi = 0x100;
#if 0
        r->ebx = file_size >> 16;
        r->ecx = file_size & 0xffff;
#else
        r->ecx = 0xff;
#endif
        r->ebp = 0x0900;
        r->edi = 0xfffe;
    }
    else {
        if (load_boot(filename, r) < 0) {
            if (errno)
                perror(filename);
            exit(1);
        }
    }

    sa.sa_handler = biosclock;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGALRM, &sa, 0) == 0) {
        timerval.it_interval.tv_sec  = timerval.it_value.tv_sec  = 0;
        timerval.it_interval.tv_usec = timerval.it_value.tv_usec = 10000000 / 182;
        setitimer (ITIMER_REAL, &timerval, NULL);
    }
    *(uint8_t *)seg_to_linear(0xF000, 0) = 0xCF;
    for (i = 0; i < 16; i++) 
	*(uint32_t *)seg_to_linear(0, i * 4) = 0xF0000000;
    *(uint32_t *)seg_to_linear(0, 0x18 * 4) = 0xF0000000; /* Basic */
    *(uint32_t *)seg_to_linear(0, 0x1B * 4) = 0xF0000000; /* Keyboard Ctrl-Break */
    *(uint32_t *)seg_to_linear(0, 0x23 * 4) = 0xF0000000; /* DOS Ctrl-Break */
    *(uint32_t *)seg_to_linear(0, 0x24 * 4) = 0xF0000000; /* Critical error */

    for(;;) {
        ret = vm86(VM86_ENTER, &ctx);
        switch(VM86_TYPE(ret)) {
        case VM86_INTx:
            {
                int int_num;

                int_num = VM86_ARG(ret);
		if (argflags & 1)
			fprintf(stderr,"Int%02X: CS:IP=%04X:%04X AX=%04X\n",
				int_num, r->cs, r->eip, r->eax);
                switch(int_num) {
                case 0x10:
                    do_int10(r);
                    break;
                case 0x13:
                    do_int13(r);
                    break;
                case 0x15:
                    do_int15(r);
                    break;
                case 0x16:
                    do_int16(r);
                    break;
                case 0x1a:
                    do_int1a(r);
                    break;
                case 0x20:
                    do_int20(r);
                    break;
                case 0x21:
                    do_int21(r);
                    break;
                case 0x29:
                    do_int29(r);
                    break;
                default:
                    fprintf(stderr, "unsupported int 0x%02x\n", int_num);
                    dump_regs(&ctx.regs);
                    break;
                }
            }
            break;
        case VM86_SIGNAL:
            /* a signal came, we just ignore that */
            if (int8pending) {
		int8pending--;
		exec_int(r, 8);
            }
            break;
        case VM86_STI:
            break;
        case VM86_TRAP:
            /* just executes the interruption */
            exec_int(r, VM86_ARG(ret));
            break;
        case VM86_UNKNOWN:
            switch ( *(uint8_t *)seg_to_linear(r->cs, r->eip) ) {
            case 0xE4: /* inx portb,al */
            case 0xE5: /* in portb,ax */
            case 0xE6: /* out al,portb */
            case 0xE7: /* out ax,portb */
            	r->eip += 2;
            	continue;
            case 0xEC: /* in dx,al */
            case 0xED: /* in dx,ax */
            case 0xEE: /* out al,dx */
            case 0xEF: /* out ax,dx */
            	r->eip++;
            	continue;
            }
        default:
            fprintf(stderr, "unhandled vm86 return code (0x%x)\n", ret);
            dump_regs(&ctx.regs);
            exit(1);
        }
    }
}
