path ..\BC31;..;%PATH%
call !clean.bat
tasm /h > helptasm.log
bcc > helpbcc.log
tlink > helptlink.log
bcc @bccopt.opt -S -mt -DUSE_ARGSTR -DLARGE_IMAGES *.cpp > cpp.log
ren LINLD.ASM LINLD.ASO
ren LOAD.ASM LOAD.ASO
ren HIMEM.ASM HIMEM.ASO
mawk -f pipehole.awk LINLD.ASO > LINLD.ASM
mawk -f pipehole.awk LOAD.ASO > LOAD.ASM
mawk -f pipehole.awk HIMEM.ASO > HIMEM.ASM
tasm /la /m /dUSE_ARGSTR /dNO386 /dLARGE_IMAGES /dLONG_FILENAME *.asm > asm.log
tlink /m /s /t @link.cmd > lnk.log
