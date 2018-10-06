path ..\BC31;%PATH%
call !clean.bat
tasm /h > helptasm.log
bcc > helpbcc.log
tlink > helptlink.log
bcc @bccopt.opt -S -mt -DLARGE_IMAGES *.cpp > cpp.log
tasm /la /m /dLARGE_IMAGES *.asm > asm.log
tlink /m /s /t @link.cmd > lnk.log
