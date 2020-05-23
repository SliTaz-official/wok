
;typedef unsigned dirsizetype;
struc		isostate		; struct isostate {
curpos		dw	?		; 0	unsigned curpos;
filename2open	dw	?		; 2	char *filename2open;
fd		dw	?		; 4	int fd;
filemod		dw	?		; 6	unsigned short filemod;
fileofs		dd	?		; 8	unsigned long fileofs;
filesize	dd	?		;12	unsigned long filesize;
filename	dw	?		;16	char *filename;
curdirsize	dw	?		;18	dirsizetype curdirsize;
dirsize		dw	?		;20	dirsizetype dirsize;
curdirofs	dd	?		;22	unsigned long curdirofs;
dirofs		dd	?		;26	unsigned long dirofs;
;overlap
entrysize	dw	?		;30	int entrysize;
tmp		dw	?		;32	const char *tmp;
c		db	?		;34	char c;
_64bits		db	?		;35	char _64bits;
buffer		db	?		;36	char buffer[2048+512];
ends		isostate		; } isostate;
