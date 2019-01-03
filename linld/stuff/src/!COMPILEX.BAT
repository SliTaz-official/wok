path ..\BC31;..;%PATH%
call !clean.bat
bcc @bccopt.opt -S -mt -DLARGE_IMAGES *.cpp > cpp.log
ren TAZBOOT.ASM TAZBOOT.ASO
ren LOAD.ASM LOAD.ASO
ren HIMEM.ASM HIMEM.ASO
ren ISO9660.ASM ISO9660.ASO
mawk -f pipehole.awk TAZBOOT.ASO > TAZBOOT.ASM
mawk -f pipehole.awk LOAD.ASO > LOAD.ASM
mawk -f pipehole.awk HIMEM.ASO > HIMEM.ASM
mawk -f pipehole.awk ISO9660.ASO > ISO9660.ASM
tasm /la /m /dEXTRA /dNO386 /dLARGE_IMAGES /dLONG_FILENAME *.asm > asm.log
tlink /m /s /t @linkx.cmd > lnk.log
