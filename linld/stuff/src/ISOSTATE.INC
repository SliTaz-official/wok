
;typedef unsigned dirsizetype;
struc		isostate		; struct isostate {
curpos		dw	?		; 0L	unsigned curpos;		// assume zero'd in bss
filename2open	dw	?		; 2I	char *filename2open;
fd		dw	?		; 4X	int fd;				// assume zero'd in bss
fileofs		dd	?		; 6O	unsigned long fileofs;
filesize	dd	?		;10O	unsigned long filesize;
filepos		dd	?		;14O	unsigned long filepos;
dirsize		dw	?		;18S	dirsizetype dirsize;		//\
dirpage		dw	?		;20S	unsigned short dirpage;		///
curdirsize	dw	?		;22L	dirsizetype curdirsize;
curdirofs	dd	?		;24L	unsigned long curdirofs;	// assume zero'd in bss
;overlap
filename	dw	?		;28U	char *filename;
_64bits		db	?		;30U	char _64bits;
c		db	?		;31U	char c;
entrysize	dw	?		;32U	int entrysize;
tmp		dw	?		;34U	const char *tmp;
ends		isostate		; } isostate;

ISOSTATE_OVERLAP	=	8
