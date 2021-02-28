path ..\BC31;..;%PATH%
call !clean.bat
tasm /h > helptasm.log
bcc > helpbcc.log
tlink > helptlink.log
bcc @bccopt.opt -S -mt *.cpp > cpp.log
ren LINLD.ASM LINLD.ASO
ren LOAD.ASM LOAD.ASO
ren HIMEM.ASM HIMEM.ASO
ren ISO9660.ASM ISO9660.ASO
mawk -f pipehole.awk LINLD.ASO > LINLD.ASM
mawk -f pipehole.awk LOAD.ASO > LOAD.ASM
mawk -f pipehole.awk HIMEM.ASO > HIMEM.ASM
mawk -f pipehole.awk ISO9660.ASO > ISO9660.ASM
mawk "{ if (/ptional/) hide=1; if (!hide) { sub(\"//\",\";\");sub(\"#define \",\"\");print $1 \"\t=\t1\t\t;\" $0} }" COMMON.H > COMMON.INC
tasm /la /m *.asm > asm.log
tlink /m /s /t @link.cmd > lnk.log
