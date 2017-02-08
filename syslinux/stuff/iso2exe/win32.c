#include <windows.h>
#include <winnt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define VCPI_LINUX_LOADER The DOS/EXE loader can boot in VM86 using VCPI API
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

#ifdef VCPI_LINUX_LOADER
static void exec16bits(char *isoFileName)
{
	int fdiso, fdtmp, i;
	long buffer[512/4];
	char tmpFileName[MAX_PATH], *p;

	strcpy(tmpFileName, isoFileName);
	p = strrchr(tmpFileName, '\\');
	if (!p++) p = tmpFileName;
	strcpy(p, "tazboot.exe");
	fdiso = open(isoFileName, O_RDONLY|O_BINARY);
	fdtmp = open(tmpFileName, O_WRONLY|O_BINARY|O_CREAT,0555);
	for (i = 0; i < 0x8000; i += sizeof(buffer)) {
		read(fdiso, (char *) buffer, sizeof(buffer));
		if (i == 0) buffer[15] = 0;	// kill PE header
		write(fdtmp, (char *) buffer, sizeof(buffer));
	}
	close(fdiso);
	close(fdtmp);
	execl(tmpFileName, isoFileName);
}
#endif

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
#ifdef VCPI_LINUX_LOADER
		exec16bits(isoFileName);
#else
		MessageBox(NULL,"No support for Win9x yet.\n"
				"Retry in DOS mode without emm386.\n",
			   "Sorry", MB_OK|MB_ICONERROR);
		exit(1);
#endif
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
