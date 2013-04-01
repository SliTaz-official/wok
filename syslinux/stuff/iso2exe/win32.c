#include <windows.h>
#include <winnt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define BOOTSTRAP_SECTOR_COUNT_OFFSET	28

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

static int iswinnt(void)
{
	OSVERSIONINFOA Version;
	Version.dwOSVersionInfoSize = sizeof(Version);
	return (GetVersionEx(&Version) &&
	    Version.dwPlatformId != VER_PLATFORM_WIN32_WINDOWS); // not Win9x
}

static int ishybrid(char *isoFileName)
{
	int fdiso;
	char buffer[2048];
	unsigned long magic = 0;
	
	fdiso = open(isoFileName, O_RDONLY|O_BINARY);
	if (lseek(fdiso, 17 * 2048L, SEEK_SET) != -1 &&
	    read(fdiso, buffer, 2048) == 2048 &&
	    strncmp(buffer+23,"EL TORITO SPECIFICATION",23) == 0) {
		unsigned long lba = * (unsigned long *) (buffer + 71);
		
		if (lseek(fdiso, lba * 2048L, SEEK_SET) != -1 &&
		    read(fdiso, buffer, 2048) == 2048 &&
		    * (unsigned long *) (buffer + 0) == 1 &&
		    * (unsigned long *) (buffer + 30) == 0x88AA55) {
			lba = * (unsigned long *) (buffer + 40);
			if (lseek(fdiso, lba * 2048L, SEEK_SET) != -1 &&
			    read(fdiso, buffer, 2048) == 2048)
				magic = * (unsigned long *) (buffer + 64);
		}
	}
	close(fdiso);
	return (magic == 1886961915);
}

#define MODE_READ  0
#define MODE_WRITE 1
static int rdwrsector(int mode, int drive, unsigned long startingsector, 
		      unsigned long count, char *buffer)
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
	hDevice = CreateFile (devname, GENERIC_READ, 
		FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_EXISTING, 0, NULL);
	if (hDevice == INVALID_HANDLE_VALUE)
		return -1;
	SetFilePointer(hDevice, (startingsector*512), NULL, FILE_BEGIN);
	if (mode == MODE_READ) {
		if (!ReadFile(hDevice, buffer, 512*count, &result, NULL))
			result = -1;
	}
	else {
		if (!WriteFile(hDevice, buffer, 512*count, &result, NULL))
			result = -1;
	}
	CloseHandle(hDevice);
	return result;
}

static void rawrite(unsigned long drive, char *isoFileName)
{
	int fdiso, s, dev, isohybrid = -1;
	char buffer[2048];
	
	if (drive == 0) return;
	for (dev = 128; (drive & 1) == 0; dev++)
		drive >>= 1;
	fdiso = open(isoFileName, O_RDONLY|O_BINARY);
	for (s = 0;;) {
		int s, n = read(fdiso, buffer, sizeof(buffer));
		if (n <= 0) break;
		n = (n+511)/512;
		if (s == 0) isohybrid = buffer[69];
		rdwrsector(MODE_WRITE, dev, s, n, buffer);
		if (s == isohybrid)
			rdwrsector(MODE_WRITE, dev, 0, 1, buffer);
		s += n;
	}
	close(fdiso);
}

static unsigned long drives(void)
{
	int i, mask, result;
	char buffer[512];
	for (i = result = 0, mask = 1; i < 8; i++, mask <<= 1) {
		if (rdwrsector(MODE_READ, i+128, 0, 1, buffer) != -1)
			result |= mask;
	}
	return result;
}

static void writefloppy(char *isoFileName)
{
	char buffer[512];
	int i, n, fd;

	buffer[BOOTSTRAP_SECTOR_COUNT_OFFSET] = 0;
	fd = open(isoFileName, O_RDONLY|O_BINARY);
	if (fd != -1) {
		read(fd, buffer, sizeof(buffer));
		n = buffer[BOOTSTRAP_SECTOR_COUNT_OFFSET];
		if (n != 0 &&
	            lseek(fd, * (unsigned short *) (buffer + 66) - (512 * n),
			      SEEK_SET) != -1) {
			for (i = 0; i < n; i++) {
				read(fd, buffer, 512);
				if (i == 1) strncpy(buffer, isoFileName, 512);
				rdwrsector(MODE_WRITE, 0, i, 1, buffer);
			}
		}
		close(fd);
	}
}

//TODO #define VCPI_LINUX_LOADER The DOS/EXE loader can boot in VM86 using VCPI API
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
		usbkeymsg = "Do you want to create a boot key ?";
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
		if (MessageBox(NULL,"Step 2: plug the USB stick in.",
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
			exit(1);
		}
		rawrite(base ^ new, isoFileName);
	}
	if (header[BOOTSTRAP_SECTOR_COUNT_OFFSET] != 0 &&
	    MessageBox(NULL,"Do you want to create a bootstrap floppy ?",
			    "Create a bootstrap floppy ?",
			MB_YESNO|MB_ICONQUESTION) == IDYES &&
	    MessageBox(NULL,"Insert a floppy disk in drive now",
			    "Insert floppy",
			MB_OKCANCEL|MB_ICONEXCLAMATION) != IDCANCEL) {

		// Create a 9k bootstrap with vfat, ext2 & ntfs drivers
		// to boot the ISO image on hard disk
		writefloppy(isoFileName);
	}
}
