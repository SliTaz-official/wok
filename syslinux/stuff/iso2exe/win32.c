#include <windows.h>
#include <winnt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define BOOTSTRAP_SECTOR_COUNT_OFFSET	26

static int fullread(int fd, char *p, int n)
{
	int i, j;
	for (i = 0; n > 0; i += j, n -= j) {
		j = read(fd, p + i, n);
		if (j <= 0) break;
	}
	return i;
#define read fullread
}

static int fullwrite(int fd, char *p, int n)
{
	int i, j;
	for (i = 0; n > 0; i += j, n -= j) {
		j = write(fd, p + i, n);
		if (j <= 0) break;
	}
	return i;
#define write fullwrite
}

#pragma pack(push,1)
struct PIF_section_header {
	char name[16];
	short next_header_offset;
	short data_offset;
	short data_length;
};

struct PIF_basic_section {
	unsigned char unused;
	unsigned char checksum;
	char window_title[30];
	unsigned short max_mem;
	unsigned short min_mem;
	char program_filename[63];
	unsigned short bitmask;
	char working_directory[64];
	char parameters_string[64];
	unsigned char video_mode;
	unsigned char video_pages;
	unsigned char first_interrupt;
	unsigned char last_interrupt;
	unsigned char height_screen;
	unsigned char width_screen;
	unsigned char horizontal_pos;
	unsigned char vertical_pos;
	unsigned short last_text_page;
	char unused2[128];
	unsigned short bitmask2;
};

struct PIF_section_win_386_3_0 {
	unsigned short max_mem;
	unsigned short min_mem;
	unsigned short active_priority;
	unsigned short background_priority;
	unsigned short max_ems;
	unsigned short required_ems;
	unsigned short max_xms;
	unsigned short required_xms;
	unsigned long bitmask;
	unsigned short bitmask2;
	unsigned short unknown;
	unsigned short shortcut_key_code;
	unsigned short shortcut_key_modifier;
	unsigned short shortcut_key_use;
	unsigned short shortcut_key_scan;
	unsigned short unknown2;
	unsigned short unknown3;
	unsigned long unknown4;
	char parameters_string[64];
};

struct PIF_section_win_vmm_4_0 {
	char unknown[88];
	char iconfile[80];
	unsigned short icon_number;
	unsigned short bitmask;
	char unknown2[10];
	unsigned short priority;
	unsigned short bitmask2; // video
	char unknown3[8];
	unsigned short text_lines;
	unsigned short bitmask3; // Key modifiers
	unsigned short unknown4;
	unsigned short unknown5;
	unsigned short unknown6;
	unsigned short unknown7;
	unsigned short unknown8;
	unsigned short unknown9;
	unsigned short unknown10;
	unsigned short unknown11;
	unsigned short bitmask4; // Mouse
	char unknown12[6];
	unsigned short bitmask5; // Fonts
	unsigned short unknown13;
	unsigned short rasterfontHsize;
	unsigned short rasterfontVsize;
	unsigned short fontHsize;
	unsigned short fontVsize;
	char raster_name[32];
	char truetype_name[32];
	unsigned short unknown14;
	unsigned short bitmask6;
	unsigned short restore_settings;
	unsigned short Hsize;
	unsigned short Vsize;
	unsigned short HsizePixelsClient;
	unsigned short VsizePixelsClient;
	unsigned short HsizePixels;
	unsigned short VsizePixels;
	unsigned short unknown15;
	unsigned short bitmask7;
	unsigned short maximized;
	char unknown16[4];
	char window_geom[16];
	char bat_file_name[80];
	unsigned short env_size;
	unsigned short dpmi_size;
	unsigned short unknown17;
};

static struct {
	struct PIF_basic_section s0;
	struct PIF_section_header h0;
	struct PIF_section_header h1;
	struct PIF_section_win_386_3_0 s1;
	struct PIF_section_header h2;
	struct PIF_section_win_vmm_4_0 s2;
} PIF_content = {
	{ 0, 0x78, "MS-DOS Prompt                 ", 640, 0, "" /*slitaz.exe*/,
	  0x10, "", "", 0, 1, 0, 255, 25, 80, 0, 0, 7, "", 0 },
	{ "MICROSOFT PIFEX", sizeof(struct PIF_basic_section)
		+ sizeof(struct PIF_section_header), 0,
		sizeof(struct PIF_basic_section) },
	{ "WINDOWS 386 3.0", sizeof(struct PIF_basic_section)
		+ 2*sizeof(struct PIF_section_header)
		+ sizeof(struct PIF_section_win_386_3_0),
		sizeof(struct PIF_basic_section)
		+ 2*sizeof(struct PIF_section_header),
		sizeof(struct PIF_section_win_386_3_0) },
	{ 640, 0, 100, 50, 65535, 0, 65535, 0, 0x10821002, 31, 0, 0, 0, 0, 0, 0,
	  0, 0, "" },
	{ "WINDOWS VMM 4.0", 65535, sizeof(struct PIF_basic_section)
		+ 3*sizeof(struct PIF_section_header)
		+ sizeof(struct PIF_section_win_386_3_0),
		sizeof(struct PIF_section_win_vmm_4_0) },
	{ "", "PIFMGR.DLL", 0, 2, "", 50, 1, "", 0, 1, 0, 5, 25, 3, 0xC8,
	  0x3E8, 2, 10, 1, "", 28, 0, 0, 0, 7, 12, "Terminal", "Courier New",
	  0, 3, 0, 80, 25, 0x250, 0x140, 0, 0, 22, 0, 0, "", "", "", 0, 0, 1 }
};
#pragma pack(pop)

static void exec16bits(char *isoFileName)
{
	int fd;
	const char pifFileName[] = "slitaz.pif";

	strcpy(PIF_content.s0.program_filename, isoFileName);
	fd = open(pifFileName, O_WRONLY|O_BINARY|O_CREAT,0555);
	write(fd,&PIF_content,sizeof(PIF_content));
	close(fd);
	WinExec(pifFileName, SW_MINIMIZE);
	exit(0);
}

static int iswinnt(void)
{
	OSVERSIONINFOA Version;
	Version.dwOSVersionInfoSize = sizeof(Version);
	return (GetVersionEx(&Version) &&
	    Version.dwPlatformId != VER_PLATFORM_WIN32_WINDOWS); // not Win9x
}

#define LONG(x)	* (unsigned long *) (x)
static int ishybrid(char *isoFileName)
{
	int fdiso;
	char buffer[2048];
	unsigned long magic = 0;
	
	fdiso = open(isoFileName, O_RDONLY|O_BINARY);
	if (lseek(fdiso, 17 * 2048L, SEEK_SET) != -1 &&
	    read(fdiso, buffer, 2048) == 2048 &&
	    strncmp(buffer+7,"EL TORITO SPECIFICATION",23) == 0) {
		unsigned long lba = LONG(buffer + 71);
		
		if (lseek(fdiso, lba * 2048L, SEEK_SET) != -1 &&
		    read(fdiso, buffer, 2048) == 2048 &&
		    LONG(buffer + 0) == 1 && LONG(buffer + 30) == 0x88AA55) {
			lba = LONG(buffer + 40);
			if (lseek(fdiso, lba * 2048L, SEEK_SET) != -1 &&
			    read(fdiso, buffer, 2048) == 2048)
				magic = LONG(buffer + 64);
		}
	}
	close(fdiso);
	return (magic == 1886961915);
}

static char buffer[512];

#define MODE_READ  0
#define MODE_WRITE 1
static int rdwrsector(int mode, int drive, unsigned long startingsector)
{
	HANDLE hDevice;
	DWORD  result;
	char devname[sizeof("\\\\.\\PhysicalDrive0")];
		
	if (drive >= 128) {
		strcpy(devname, "\\\\.\\PhysicalDrive0");
		devname[17] += drive - 128;
	}
	else {
		strcpy(devname, "\\\\.\\A:");
		devname[4] += drive;
	}
	hDevice = CreateFile (devname, (mode == MODE_READ) ? GENERIC_READ : GENERIC_WRITE, 
		FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
	if (hDevice == INVALID_HANDLE_VALUE)
		return -1;
	SetFilePointer(hDevice, (startingsector*512), NULL, FILE_BEGIN);
	if (mode == MODE_READ) {
		if (!ReadFile(hDevice, buffer, 512, &result, NULL))
			result = -1;
	}
	else {
		if (!WriteFile(hDevice, buffer, 512, &result, NULL))
			result = -1;
	}
	CloseHandle(hDevice);
	return result;
}

static int rawrite(unsigned long drive, char *isoFileName)
{
	int fdiso, s, dev;
	
	if (drive == 0) return;
	for (dev = 128; (drive & 1) == 0; dev++)
		drive >>= 1;
	fdiso = open(isoFileName, O_RDONLY|O_BINARY);
	for (s = 0;; s++) {
		int n = read(fdiso, buffer, sizeof(buffer));
		if (n <= 0) break;
		rdwrsector(MODE_WRITE, dev, s);
	}
	close(fdiso);
	return dev;
}

static unsigned long drives(void)
{
	int i, mask, result;

	for (i = result = 0, mask = 1; i < 8; i++, mask <<= 1) {
		if (rdwrsector(MODE_READ, i+128, 0) != -1)
			result |= mask;
	}
	return result;
}

static void writefloppy(char *isoFileName)
{
	int i, n, fd;

	buffer[BOOTSTRAP_SECTOR_COUNT_OFFSET] = 0;
	fd = open(isoFileName, O_RDONLY|O_BINARY);
	if (fd != -1) {
		read(fd, buffer, sizeof(buffer));
		n = buffer[BOOTSTRAP_SECTOR_COUNT_OFFSET];
		if (n != 0 &&
	            lseek(fd, * (unsigned short *) (buffer + 66) - (512 * n),
			      SEEK_SET) != -1) {
			for (i = 0; i <= n; i++) {
				if (i == 1) strncpy(buffer, isoFileName, 512);
				else read(fd, buffer, 512);
				rdwrsector(MODE_WRITE, 0, i);
			}
		}
		close(fd);
	}
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
		   LPSTR lpCmdLine, int nCmdShow)
{
	char isoFileName[MAX_PATH];
	char header[32];
	int fd;
	int  usbkeyicon = MB_ICONASTERISK;
	char *usbkeymsg = "You can either:\n\n"
		"- create a SliTaz USB boot key or a boot memory card.\n"
		"  (note that this will be read only like a CDROM.\n"
		"  The Slitaz utility 'tazusb' can be used later to create\n"
		"  a true read/write USB key).\n\n"
		"- create a SliTaz bootstrap floppy for the ISO image\n"
		"  on the hard disk.\n"
		"\nDo you want to create a boot key now ?";
	
	GetModuleFileName(hInstance, isoFileName, MAX_PATH);
	if (!iswinnt()) {
		if (MessageBox(NULL,
			"This program must be run in DOS mode.\n"
			"I can create the file slitaz.pif to launch it,\n"
			"but you can reboot in DOS mode to run it\n",
			"Create slitaz.pif now ?",
			MB_YESNO|MB_ICONQUESTION) == IDYES) {
			exec16bits(isoFileName);
		}
		exit(1);
	}
	if (!ishybrid(isoFileName)) {
		if (MessageBox(NULL,"Not an isolinux hybrid ISO.\n"
				    "This ISO image will not boot\n"
				    "from the media that you create !",
			   "Will not boot !", 
			   MB_OKCANCEL|MB_ICONWARNING) == IDCANCEL)
			exit(0);
	}
	header[BOOTSTRAP_SECTOR_COUNT_OFFSET] = 0;
	fd = open(isoFileName, O_RDONLY|O_BINARY);
	if (fd != -1) {
		read(fd, header, sizeof(header));
		close(fd);
	}
	if (header[BOOTSTRAP_SECTOR_COUNT_OFFSET] == 0) { // No floppy bootstrap available
		usbkeyicon = MB_ICONQUESTION;
		usbkeymsg =
		"You can create a SliTaz USB boot key or\n"
		"a boot memory card.\n"
		"(note that this will be read only like\n"
		"a CDROM. The Slitaz utility 'tazusb'\n"
		"can be used later to create a true\n"
		"read/write USB key).\n"
		"\nDo you want to create a boot key now ?";
	}
	if (MessageBox(NULL,usbkeymsg, "Create a boot stick ?",
			MB_YESNO|usbkeyicon) == IDYES) {
		unsigned long base, new;
		int retry;
		
		if (MessageBox(NULL,"Step 1: unplug the USB stick.",
				"Drive detection 1/2",
				MB_OKCANCEL|MB_ICONEXCLAMATION) == IDCANCEL)
			exit(0);
		base = drives();
		if (MessageBox(NULL,"Step 2: plug the USB stick in, "
				    "wait for Windows to mount it",
				"Drive detection 2/2",
				MB_OKCANCEL|MB_ICONEXCLAMATION) == IDCANCEL)
			exit(0);
		retry = 0;
		do {
			Sleep(1000); // ms
			new = drives();
		} while (new == base && retry++ < 10);
		if (new == base) {
			MessageBox(NULL,"No USB stick found.","Sorry",
				   MB_OK|MB_ICONERROR);
		}
		else {
			char *msg = "(hd0) is up to date.";
			msg[3] += rawrite(base ^ new, isoFileName) - 128;
			MessageBox(NULL,msg,"Finished",MB_OK);
		}
	}
	else if (header[BOOTSTRAP_SECTOR_COUNT_OFFSET] != 0 &&
	    MessageBox(NULL,"Do you want to create a bootstrap floppy ?",
			    "Create a bootstrap floppy ?",
			MB_YESNO|MB_ICONQUESTION) == IDYES &&
	    MessageBox(NULL,"Insert a floppy disk in drive now",
			    "Insert floppy",
			MB_OKCANCEL|MB_ICONEXCLAMATION) != IDCANCEL) {

		// Create a 9k bootstrap with vfat, ext2 & ntfs drivers
		// to boot the ISO image on hard disk
		writefloppy(isoFileName);
		MessageBox(NULL,"The bootstrap floppy is up to date.",
				"Finished",MB_OK);
	}
}
