path ..\BC31;%PATH%
call !clean.bat
tasm /l /m /dNO386 *.asm > asm.log
rem @pause
bcc @bccopt.opt -S -mt *.cpp
tasm /l /m load.asm
tasm /l /m himem.asm
tasm /l /m tazboot.asm
tasm /l /m iso9660.asm
bcc @bccopt.opt -c -mt *.cpp > cpp.log
rem @pause
tlink /m /s /t @linkx.cmd > lnk.log
rem @pause
