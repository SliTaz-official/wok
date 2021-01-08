
;typedef unsigned dirsizetype;
struc		isostate		; struct isostate {
curpos		dw	?		; 0	unsigned curpos;
filename2open	dw	?		; 2	char *filename2open;
fd		dw	?		; 4	int fd;
filemod		dw	?		; 6	unsigned short filemod;
fileofs		dd	?		; 8	unsigned long fileofs;
filesize	dd	?		;12	unsigned long filesize;
filepos		dd	?		;16	unsigned long filepos;
filename	dw	?		;20	char *filename;
curdirsize	dw	?		;22	dirsizetype curdirsize;
dirsize		dw	?		;24	dirsizetype dirsize;
dirpape		dw	?		;26	unsigned short dirpage;
curdirofs	dd	?		;28	unsigned long curdirofs;
;overlap
entrysize	dw	?		;32	int entrysize;
tmp		dw	?		;34	const char *tmp;
c		db	?		;36	char c;
_64bits		db	?		;37	char _64bits;
buffer		db	?		;38	char buffer[2048+512];
ends		isostate		; } isostate;
