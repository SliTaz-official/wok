#include <windows.h>
#include <winnt.h>
#include <winioctl.h>
#include <commctrl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define e_grave "\xE8"
#define e_acute "\xE9"
#define e_circ  "\xEA"
#define e_trema "\xEB"
#define E_grave "\xC8"
#define E_acute "\xC9"
#define E_circ  "\xCA"
#define E_trema "\xCB"
#define a_grave "\xE0"
#define A_grave "\xC0"
#define a_circ  "\xE2"
#define A_circ  "\xC2"
#define c_cedil "\xE7"
#define C_cedil "\xC7"
#define i_circ  "\xEE"
#define I_circ  "\xCE"
#define i_trema "\xEF"
#define I_trema "\xCF"
#define o_circ  "\xF4"
#define O_circ  "\xD4"
#define o_trema "\xF6"
#define O_trema "\xD6"
#define u_grave "\xF9"
#define U_grave "\xD9"
#define u_circ  "\xFB"
#define U_circ  "\xDB"
#define u_trema "\xFC"
#define U_trema "\xDC"

static char *MsgSet[2][27] = {
	{
#define LANG_EN	0
#define MSG_BUILD_KEY	0
		"Build the SliTaz USB key...",
#define MSG_EITHER_CREATE_KEY_OR_BOOT_FLOPPY	1
		"You can either:\n\n"
		"- create a SliTaz USB boot key or a boot memory card.\n"
		"  (note that the Linux kernel will not be upgradable.\n"
		"  The Slitaz utility 'tazusb' can be used later to create\n"
		"  a true read/write USB key).\n\n"
		"- create a SliTaz bootstrap floppy for the ISO image\n"
		"  on the hard disk.\n"
		"\nDo you want to create a boot key now ?",
#define MSG_NOT_DOS_MODE	2
		"This program should run in DOS mode.\n"
		"It can create the file slitaz.pif and launch it,\n"
		"but you can reboot in DOS mode too and run it.\n"
		"\nDo you want to create the slitaz.pif file and execute it now ?",
#define MSG_CRATE_PIF_NOW	3
		"Create slitaz.pif now ?",
#define MSG_NOT_HYBRID		4
		"Not an isolinux hybrid ISO.\n"
		"This ISO image will not boot\n"
		"from the media that you create !",
#define MSG_WILL_NOT_BOOT	5
		"Will not boot !", 
#define MSG_WANT_CREATE_BOOT_KEY	6
		"You can create a SliTaz USB boot key or\n"
		"a boot memory card.\n"
		"\nDo you want to create a boot key now ?",
#define MSG_Q_CREATE_STICK	7
		"Create a boot stick ?",
#define MSG_STEP_1		8
		"Step 1: unplug the USB stick.",
#define MSG_DETECT_1		9
		"Drive detection 1/2",
#define MSG_STEP_2		10
		"Step 2: plug the USB stick in, "
		"wait for Windows to mount it",
#define MSG_DETECT_2		11
		"Drive detection 2/2",
#define MSG_NOT_FOUND		12
		"No USB stick found.",
#define MSG_SORRY		13
		"Sorry",
#define MSG_HD0_UP_TO_DATE	14
		"(hd0) is up to date.",
#define MSG_HD0_UP_TO_DATE_BUT	15
		"(hd0) is up to date but the partition table is not\n"
		"updated because I can't get the total USB stick size\n\n"
		"You can boot SliTaz with this stick and you can update\n"
		"the partition table with 'taziso' by selecting "
		"'usbbootkey' as root.",
#define MSG_NO_REPART		16
		"Finished without repartitioning",
#define MSG_KEEP_CUSTOM_CONF	17
		"Do you want to keep your custom configuration ?",
#define MSG_KEEP_CONF		18
		"keep configuration ?",
#define MSG_WANT_HOME		19
		"Do you want to create a persistent partition for /home ?",
#define MSG_DO_HOME		20
		"Create a persistent /home ?",
#define MSG_FINISHED		21
		"Finished",
#define MSG_WANT_FLOPPY		22
		"Do you want to create a bootstrap floppy ?",
#define MSG_DO_FLOPPY		23
		"Create a bootstrap floppy ?",
#define MSG_INSERT_A_FLOPPY	24
		"Insert a floppy disk in drive now",
#define MSG_INSERT_FLOPPY	25
		"Insert floppy",
#define MSG_FLOPPY_DONE		26
		"The bootstrap floppy is up to date."
	},
	{
#define LANG_FR	1
// MSG_BUILD_KEY
		"Construit la cl" e_acute " USB SliTaz...",
// MSG_EITHER_CREATE_KEY_OR BOOT_FLOPPY
		"Vous pouvez soit :\n\n"
		"- cr" e_acute "er une cl" e_acute " USB ou une carte m" e_acute "moire de d" e_acute "marrage.\n"
		"  (notez que le noyau Linux ne pourra pas " e_circ "tre mis " a_grave " jour.\n" 
		"  L'outil SliTaz 'tazusb' pourra " e_circ "tre utilis" e_acute " ensuite pour cr" e_acute "er\n"
		"  une v" e_acute "ritable cl" e_acute " USB read/write).\n\n"
		"- cr" e_acute "er une disquette de d" e_acute "marrage pour une image ISO\n"
		"  plac" e_acute " sur le disque dur.\n"
		"\nVoulez vous cr" e_acute "er une disquette de d" e_acute "marrage maintenant ?",
// MSG_NOT_DOS_MODE
		"Ce programme devrait " e_circ "tre lanc" e_acute " en mode DOS.\n"
		"Il peut cr" e_acute "er le fichier slitaz.pif et l'ex" e_acute "cuter,\n"
		"mais vous pouvez aussi red" e_acute "marrer en mode DOS et le lancer.\n"
		"\nVoulez cr" e_acute "er le fichier slitaz.pif et le lancer maintenant ?",
// MSG_CRATE_PIF_NOW
		"Cr" e_acute "er slitaz.pif maintenant ?",
// MSG_NOT_HYBRID
		"Ce n'est pas une image ISO hybride isolinux.\n"
		"Cette image ISO ne d" e_acute "marrera pas\n"
		"depuis le media o" u_grave " vous la cr" e_acute "er !",
// MSG_WILL_NOT_BOOT
		"Ne d" e_acute "marrera pas !\n",
// MSG_WANT_CREATE_BOOT_KEY
		"Vous pouvez cr" e_acute "er une cl" e_acute " USB / carte m" e_acute "moire de d" e_acute "marrage.\n"
		"\nVoulez vous cr" e_acute "er une cl" e_acute " de d" e_acute "marrage maintenant ?",
// MSG_Q_CREATE_STICK
		"Cr" e_acute "er une cl" e_acute " de d" e_acute "marrage ?",
// MSG_STEP_1
		"Etape 1 : d" e_acute "branchez la cl" e_acute " USB.",
// MSG_DETECT_1
		"D" e_acute "tection du p" e_acute "riph" e_acute "rique 1/2",
// MSG_STEP_2
		"Etape 2 : rebranchez la cl" e_acute " USB, "
		"et attendez que Windows la reconnaisse.",
// MSG_DETECT_2
		"D" e_acute "tection du p" e_acute "riph" e_acute "rique 2/2",
// MSG_NOT_FOUND
		"Aucune cl" e_acute " USB trouv" e_acute "e.",
// MSG_SORRY
		"D" e_acute " sol" e_acute,
// MSG_HD0_UP_TO_DATE
		"(hd0) a " e_acute "t" e_acute " mis " a_grave " jour.",
// MSG_HD0_UP_TO_DATE_BUT
		"(hd0) a " e_acute "t" e_acute " mis " a_grave " jour mais la table de partition n'est pas\n"
		"modifi" e_acute "e car la taille totale de la cl" e_acute " USB n'a pu " e_circ "tre d" e_acute "tect" e_acute "e\n\n"
		"Vous pouvez d" e_acute "marrer avec cette cl" e_acute " puis vous pouvez mettre " a_grave " jour\n"
		"la table de partition avec 'taziso' en choisissant "
		"'usbbootkey' (si root).",
// MSG_NO_REPART
		"Termin" e_acute " sans repartitionement",
// MSG_KEEP_CUSTOM_CONF
		"Voulez vous conserver votre configuration personnelle ?",
// MSG_KEEP_CONF
		"Garder votre configuration ?",
// MSG_WANT_HOME
		"voulez vous cr" e_acute "er une partition persistante pour /home ?",
// MSG_DO_HOME
		"Cr" e_acute "er un /home persistant ?",
// MSG_FINISHED
		"Termin" e_acute,
// MSG_WANT_FLOPPY
		"Voulez-vous cr" e_acute "er une disquette de d" e_acute "marrage ?",
// MSG_DO_FLOPPY
		"Cr" e_acute "er une disquette de boot ?",
// MSG_INSERT_A_FLOPPY
		"Veuillez ins" e_acute "rer une disquette maintenant",
// MSG_INSERT_FLOPPY
		"Ins" e_acute "rer une disquette",
// MSG_FLOPPY_DONE
		"La disquette de d" e_acute "marage est cr" e_acute e_acute "e."
	}
};
static char **Msg = MsgSet[LANG_EN];

#define BOOTSTRAP_SECTOR_COUNT_OFFSET	26
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

static void exec16bits(const char *isoFileName)
{
	int fd;
	const char pifFileName[] = "slitaz.pif";

	strcpy(PIF_content.s0.program_filename, isoFileName);
	fd = open(pifFileName, O_WRONLY|O_BINARY|O_CREAT|O_TRUNC,0555);
	write(fd,(void*)&PIF_content,sizeof(PIF_content));
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
static int ishybrid(const char *isoFileName)
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

static unsigned long crc32(void *buf, int cnt)
{
	static unsigned long t[256] = {
	0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3,
	0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988, 0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91,
	0x1DB71064, 0x6AB020F2, 0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
	0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9, 0xFA0F3D63, 0x8D080DF5,
	0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172, 0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B,
	0x35B5A8FA, 0x42B2986C, 0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
	0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423, 0xCFBA9599, 0xB8BDA50F,
	0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924, 0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D,
	0x76DC4190, 0x01DB7106, 0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
	0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D, 0x91646C97, 0xE6635C01,
	0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E, 0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457,
	0x65B0D9C6, 0x12B7E950, 0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
	0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7, 0xA4D1C46D, 0xD3D6F4FB,
	0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0, 0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9,
	0x5005713C, 0x270241AA, 0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
	0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81, 0xB7BD5C3B, 0xC0BA6CAD,
	0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A, 0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683,
	0xE3630B12, 0x94643B84, 0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
	0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB, 0x196C3671, 0x6E6B06E7,
	0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC, 0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5,
	0xD6D6A3E8, 0xA1D1937E, 0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
	0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55, 0x316E8EEF, 0x4669BE79,
	0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236, 0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F,
	0xC5BA3BBE, 0xB2BD0B28, 0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
	0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F, 0x72076785, 0x05005713,
	0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38, 0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21,
	0x86D3D2D4, 0xF1D4E242, 0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
	0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69, 0x616BFFD3, 0x166CCF45,
	0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2, 0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB,
	0xAED16A4A, 0xD9D65ADC, 0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
	0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693, 0x54DE5729, 0x23D967BF,
	0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94, 0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D };
	unsigned long crc;
	unsigned char *p = buf;
	int i;

	for (crc=0xFFFFFFFF, i=0; i < cnt; i++) {
		crc=((crc >> 8) ^ t[(crc ^ p[i]) & 255]);
	}
	return crc ^ 0xFFFFFFFF;
}

static char buffer[2048];

static int getDrive(unsigned long mask)
{
	int dev;
	if (mask == 0) {
		exit(1);
	}
	for (dev = 128; (mask & 1) == 0; dev++)
		mask >>= 1;
	return dev;
}

static unsigned long end = 0;
#define MODE_READ	0
#define MODE_WRITE	1
#define MODE_GET_SIZE	2
static int rdwrsector(int mode, int drive, unsigned long startingsector, int bufsiz)
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

	SetFilePointer(hDevice, (startingsector*bufsiz), NULL, FILE_BEGIN);
	if (mode == MODE_READ) {
		if (!ReadFile(hDevice, buffer, bufsiz, &result, NULL))
			result = -1;
	}
	else if (mode == MODE_WRITE) {
		if (!WriteFile(hDevice, buffer, bufsiz, &result, NULL))
			result = -1;
	}
	else {
		GET_LENGTH_INFORMATION li;
		DWORD rsize;

		result = -1;
		if (DeviceIoControl(hDevice, IOCTL_DISK_GET_LENGTH_INFO, NULL, 0, &li, sizeof(li), 
                 		&rsize, NULL) != 0) {
			end = li.Length.QuadPart >> 9;
			result = 0;
		}
		else {
			long i, high;
			high = -1;
			i = GetFileSize(hDevice, &high);
			if (i == INVALID_FILE_SIZE) {
				high = -1;
				i = SetFilePointer(hDevice, 0, &high, FILE_END);
			}
			if (i != INVALID_SET_FILE_POINTER) {
				end = (high << 23)|(i >> 9);
				result = 0;
			}
#if 0
			if (result == -1) {
				LARGE_INTEGER size;
				//if (GetFileSizeEx(hDevice, &size) != 0) {
				if ((*GetProcAddress(GetModuleHandle("kernel32.dll"),
						     "GetFileSizeEx"))(hDevice, &size) != 0) {
					end = (size.QuadPart >> 9);
					result = 0;
				}
			}
#endif
#if 0
			if (result == -1) {
				for (end = 0x40000000, i = (end >> 1); i != 0; i >>= 1) {
					high = (end >> 23);
					if (SetFilePointer(hDevice, end << 9, &high, FILE_BEGIN) == INVALID_SET_FILE_POINTER ||
						!ReadFile(hDevice, buffer, 512, &result, NULL) || result != 512) end -= i;
					else end += i;
				}
				high = (end >> 23);
				if (SetFilePointer(hDevice, end << 9, &high, FILE_BEGIN)
					!= INVALID_SET_FILE_POINTER) end++;
				if (end > startingsector) result = 0;
			}
#endif
		}
	
	}
	CloseHandle(hDevice);
	return result;
}

static int rawrite(int dev, char *isoFileName)
{
	int fdiso, s;
	float next;
	off_t size;
	HWND hwndPB;
	
	fdiso = open(isoFileName, O_RDONLY|O_BINARY);
	size = lseek(fdiso,0,SEEK_END);
	lseek(fdiso,0,SEEK_SET);
	if (size != -1) { // https://docs.microsoft.com/en-us/windows/win32/controls/create-progress-bar-controls
		const left=100, right=100+400, bottom=80, scroll=50;

		InitCommonControls();	// need -lcomctl32
		hwndPB = CreateWindowEx(0, PROGRESS_CLASS, Msg[MSG_BUILD_KEY],
					WS_VISIBLE | PBS_SMOOTH, left,
					bottom - scroll, right, scroll,
					NULL, (HMENU) 0, GetModuleHandle(0), NULL);
		if (hwndPB == NULL) size = -1;
		else SendMessage(hwndPB, PBM_SETRANGE, 0, MAKELPARAM(0, 0xFFFF));
	}
	for (s = 0, next = 0.0;; s++) {
		int n = read(fdiso, buffer, 2048);
		if (n <= 0) break;
		rdwrsector(MODE_WRITE, dev, s, 2048);
		if (size != -1) SendMessage(hwndPB, PBM_SETPOS, (WPARAM) floor((65536.0*2048.0*s)/size), 0 ); 
	}
	close(fdiso);
	if (size != -1) DestroyWindow(hwndPB);
	return dev;
}

static unsigned long drives(void)
{
	int i, mask, result;

	for (i = result = 0, mask = 1; i < 8; i++, mask <<= 1) {
		if (rdwrsector(MODE_READ, getDrive(i+128), 0, 512) != -1)
			result |= mask;
	}
	return result;
}

static int EndOfIso(int dev, unsigned long *endiso,  unsigned long *endcustom)
{
	if (rdwrsector(MODE_READ, dev, 16, 2048) == -1) return -1;
	*endiso = *endcustom = LONG(buffer+80);
	if (rdwrsector(MODE_GET_SIZE, dev, *endiso, 512) == -1) return -1;
	if (rdwrsector(MODE_READ, dev, *endiso, 2048) != -1 && !memcmp(buffer,"#!boot",6)) {
		char *s;
		*endcustom++;
		s = strstr(buffer, "\ninitrd:");
		if (s) {
			long n = strtol(s+8,&s,10);
			n += s - buffer;
			*endcustom += n/2048;
		}
		*endcustom += 511L; *endcustom &= ~511L;
	}
	return 0;
}

static void AddPartition(int dev, char *label, unsigned long next)
{
	int i;
	unsigned long crc;

	// https://en.wikipedia.org/wiki/GUID_Partition_Table
	if (rdwrsector(MODE_READ, dev, 2, 512) == -1) return;
	if (buffer[128+56] == 0) {
		static char id[16] = { 0xA2, 0xA0, 0xD0, 0xEB,
			0xE5, 0xB9, 0x33, 0x44, 0x87, 0xC0,
			0x68, 0xB6, 0xB7, 0x26, 0x99, 0xC7 };
		memcpy(buffer + 128, id, 16);
		for (i = 0; i < 16; i += 2)
			* (unsigned short *) (buffer + 128+16 + i) = rand();
		for (i = 56; *label; i += 2)
			buffer[128+i] = *label++;
		LONG(buffer + 128+32) = next * 2048/512;
		LONG(buffer + 128+40) = end - 3;
	}
	rdwrsector(MODE_WRITE, dev, 2, 512);
	rdwrsector(MODE_WRITE, dev, end - 2, 512);
	crc = crc32(buffer, 512L);
	if (rdwrsector(MODE_READ, dev, 1, 512) == -1) return;
	LONG(buffer+88) = crc;
	LONG(buffer+24) = 1;		// Current header
	LONG(buffer+28) = 0;
	LONG(buffer+32) = end - 1;	// Backup header
	LONG(buffer+36) = 0;
	LONG(buffer+48) = end - 3;	// Last usable sector
	LONG(buffer+52) = 0;
	LONG(buffer+16) = 0;
	crc = crc32(buffer, LONG(buffer + 0x0C));
	LONG(buffer+16) = crc;
	rdwrsector(MODE_WRITE, dev, 1, 512);
	LONG(buffer+24) = end - 1;	// Current header
	LONG(buffer+28) = 0;
	LONG(buffer+32) = 1;		// Backup header
	LONG(buffer+36) = 0;
	LONG(buffer+16) = 0;
	crc = crc32(buffer, LONG(buffer + 0x0C));
	LONG(buffer+16) = crc;
	rdwrsector(MODE_WRITE, dev, end - 1, 512);
}

static void writefloppy(char *isoFileName)
{
	int i, n, fd;

	buffer[BOOTSTRAP_SECTOR_COUNT_OFFSET] = 0;
	fd = open(isoFileName, O_RDONLY|O_BINARY);
	if (fd != -1) {
		read(fd, buffer, 512);
		n = buffer[BOOTSTRAP_SECTOR_COUNT_OFFSET];
		if (n != 0 &&
	            lseek(fd, * (unsigned short *) (buffer + 66) - (512 * n),
			      SEEK_SET) != -1) {
			for (i = 0; i <= n; i++) {
				if (i == 1) strncpy(buffer, isoFileName, 512);
				else read(fd, buffer, 512);
				rdwrsector(MODE_WRITE, 0, i, 512);
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
	char *usbkeymsg;
	
	GetModuleFileName(hInstance, isoFileName, MAX_PATH);
	if (iswinnt()) {
		LANGID lid = (*GetProcAddress(GetModuleHandle("kernel32.dll"), "GetSystemDefaultUILanguage"))();
		if ((lid & 0xff) == 0x0c) Msg = MsgSet[LANG_FR];
	}
	else {
		struct stat statbuf;
		if (stat("C:\\Mes Documents",&statbuf) != -1) Msg = MsgSet[LANG_FR];
		if (MessageBox(NULL, Msg[MSG_NOT_DOS_MODE], Msg[MSG_CRATE_PIF_NOW],
			MB_YESNO|MB_ICONQUESTION) == IDYES) {
			exec16bits(isoFileName);
		}
		exit(1);
	}
	if (!ishybrid(isoFileName)) {
		if (MessageBox(NULL, Msg[MSG_NOT_HYBRID], Msg[MSG_WILL_NOT_BOOT],
			   MB_OKCANCEL|MB_ICONWARNING) == IDCANCEL)
			exit(0);
	}
	header[BOOTSTRAP_SECTOR_COUNT_OFFSET] = 0;
	fd = open(isoFileName, O_RDONLY|O_BINARY);
	if (fd != -1) {
		read(fd, header, sizeof(header));
		close(fd);
	}
	usbkeymsg = Msg[MSG_EITHER_CREATE_KEY_OR_BOOT_FLOPPY];
	if (header[BOOTSTRAP_SECTOR_COUNT_OFFSET] == 0) { // No floppy bootstrap available
		usbkeyicon = MB_ICONQUESTION;
		usbkeymsg = Msg[MSG_WANT_CREATE_BOOT_KEY];
	}
	if (MessageBox(NULL,usbkeymsg, Msg[MSG_Q_CREATE_STICK],
			MB_YESNO|usbkeyicon) == IDYES) {
		unsigned long base, new;
		int retry;
		
		if (MessageBox(NULL, Msg[MSG_STEP_1], Msg[MSG_DETECT_1],
				MB_OKCANCEL|MB_ICONEXCLAMATION) == IDCANCEL)
			exit(0);
		base = drives();
		if (MessageBox(NULL, Msg[MSG_STEP_2], Msg[MSG_DETECT_2],
				MB_OKCANCEL|MB_ICONEXCLAMATION) == IDCANCEL)
			exit(0);
		retry = 0;
		do {
			Sleep(1000); // ms
			new = drives();
		} while (new == base && retry++ < 10);
		if (new == base) {
			MessageBox(NULL, Msg[MSG_NOT_FOUND], Msg[MSG_SORRY],
				   MB_OK|MB_ICONERROR);
		}
		else {
			unsigned long endiso, endcustom;
			char *msg = Msg[MSG_HD0_UP_TO_DATE];
			int drive = getDrive(base ^ new);
			msg[3] += rawrite(drive, isoFileName) - 128;
			if (EndOfIso(drive, &endiso, &endcustom) == -1) {
				char *msg2 = Msg[MSG_HD0_UP_TO_DATE_BUT];
				msg2[3] = msg[3];
				MessageBox(NULL,msg2, Msg[MSG_NO_REPART] ,MB_OK|MB_ICONEXCLAMATION);
			}
			else {
				static char *labels[2] = { "Basic data partition", "SliTaz persistent /home" };
				if (endiso != endcustom && MessageBox(NULL, Msg[MSG_KEEP_CUSTOM_CONF],
						Msg[MSG_KEEP_CONF], MB_YESNO|MB_ICONQUESTION) == IDYES)
					endiso = endcustom;
				AddPartition(drive, labels[MessageBox(NULL, Msg[MSG_WANT_HOME],
					Msg[MSG_DO_HOME], MB_YESNO|MB_ICONQUESTION) == IDYES], endiso); 
				MessageBox(NULL,msg, Msg[MSG_FINISHED], MB_OK);
			}
		}
	}
	else if (header[BOOTSTRAP_SECTOR_COUNT_OFFSET] != 0 &&
	    MessageBox(NULL, Msg[MSG_WANT_FLOPPY], Msg[MSG_DO_FLOPPY],
			MB_YESNO|MB_ICONQUESTION) == IDYES &&
	    MessageBox(NULL, Msg[MSG_INSERT_A_FLOPPY], Msg[MSG_INSERT_FLOPPY],
			MB_OKCANCEL|MB_ICONEXCLAMATION) != IDCANCEL) {

		// Create a 9k bootstrap with vfat, exfat, ntfs, ext2 & usb drivers
		// to boot the ISO image on hard disk
		writefloppy(isoFileName);
		MessageBox(NULL, Msg[MSG_FLOPPY_DONE],
			Msg[MSG_FINISHED], MB_OK);
	}
}
