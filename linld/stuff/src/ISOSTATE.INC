
;typedef unsigned dirsizetype;
struc		isostate		; struct isostate {
curpos		dw	?		; 0	unsigned curpos;
filename2open	dw	?		; 2	char *filename2open;
fd		dw	?		; 4	int fd;
fileofs		dd	?		; 6	unsigned long fileofs;
filesize	dd	?		;10	unsigned long filesize;
filepos		dd	?		;14	unsigned long filepos;
filename	dw	?		;18	char *filename;
curdirsize	dw	?		;20	dirsizetype curdirsize;
dirsize		dw	?		;22	dirsizetype dirsize;
dirpape		dw	?		;24	unsigned short dirpage;
curdirofs	dd	?		;26	unsigned long curdirofs;
_64bits		db	?		;30	char _64bits;
;overlap
c		db	?		;31	char c;
entrysize	dw	?		;32	int entrysize;
tmp		dw	?		;34	const char *tmp;
ends		isostate		; } isostate;

ISOSTATE_OVERLAP	=	5
