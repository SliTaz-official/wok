path ..\BC31;%PATH%
call !clean.bat
tasm /h > helptasm.log
bcc > helpbcc.log
tlink > helptlink.log
tasm /la /m *.asm > asm.log
rem @pause
bcc @bccopt.opt -S -mt *.cpp
tasm /l /m load.asm
tasm /l /m himem.asm
tasm /l /m linld.asm
tasm /l /m iso9660.asm
bcc @bccopt.opt -c -mt *.cpp > cpp.log
rem @pause
tlink /m /s /t @link.cmd > lnk.log
rem @pause
