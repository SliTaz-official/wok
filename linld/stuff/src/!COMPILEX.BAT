path ..\BC31;%PATH%
call !clean.bat
bcc @bccopt.opt -S -mt -DLARGE_IMAGES *.cpp > cpp.log
tasm /la /m /dEXTRA /dNO386 /dLARGE_IMAGES *.asm > asm.log
tlink /m /s /t @linkx.cmd > lnk.log
