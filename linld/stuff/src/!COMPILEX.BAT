path ..\BC31;%PATH%
call !clean.bat
rem tasm /la /m /dEXTRA /dNO386 *.asm > asm.log
tasm /la /m /dEXTRA /dNO386 /dLARGE_IMAGES *.asm > asm.log
rem @pause
rem bcc @bccopt.opt -S -mt *.cpp
bcc @bccopt.opt -S -mt -DLARGE_IMAGES *.cpp
tasm /l /m load.asm
tasm /l /m himem.asm
tasm /l /m tazboot.asm
tasm /l /m iso9660.asm
rem bcc @bccopt.opt -c -mt *.cpp > cpp.log
bcc @bccopt.opt -c -mt -DLARGE_IMAGES *.cpp > cpp.log
rem @pause
tlink /m /s /t @linkx.cmd > lnk.log
rem @pause
