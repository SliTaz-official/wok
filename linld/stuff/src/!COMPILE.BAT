path ..\BC31;%PATH%
call !clean.bat
tasm /h > helptasm.log
bcc > helpbcc.log
tlink > helptlink.log
rem tasm /la /m *.asm > asm.log
tasm /la /m /dLARGE_IMAGES *.asm > asm.log
rem @pause
rem bcc @bccopt.opt -S -mt *.cpp
bcc @bccopt.opt -S -mt -DLARGE_IMAGES *.cpp
tasm /l /m load.asm
tasm /l /m himem.asm
tasm /l /m linld.asm
tasm /l /m iso9660.asm
rem bcc @bccopt.opt -c -mt *.cpp > cpp.log
bcc @bccopt.opt -c -mt -DLARGE_IMAGES *.cpp > cpp.log
rem @pause
tlink /m /s /t @link.cmd > lnk.log
rem @pause
