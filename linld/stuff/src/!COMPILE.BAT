path ..\BC31;..;%PATH%
call !clean.bat
tasm /h > helptasm.log
bcc > helpbcc.log
tlink > helptlink.log
bcc @bccopt.opt -S -mt -DISOHOOK -DMOVE_SETUP -DUSE_ARGSTR -DLARGE_IMAGES *.cpp > cpp.log
ren LINLD.ASM LINLD.ASO
ren LOAD.ASM LOAD.ASO
ren HIMEM.ASM HIMEM.ASO
ren ISO9660.ASM ISO9660.ASO
mawk -f pipehole.awk LINLD.ASO > LINLD.ASM
mawk -f pipehole.awk LOAD.ASO > LOAD.ASM
mawk -f pipehole.awk HIMEM.ASO > HIMEM.ASM
mawk -f pipehole.awk ISO9660.ASO > ISO9660.ASM
tasm /la /m /dISOHOOK /dMOVE_SETUP /dUSE_ARGSTR /dNO386 /dLARGE_IMAGES /dLONG_FILENAME *.asm > asm.log
tlink /m /s /t @link.cmd > lnk.log
tlink /m /s /t @link2.cmd > lnk2.log
tlink /m /s /t @header.cmd > header.log
