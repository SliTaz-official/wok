;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
                %crefref
                %noincl
                %nomacs
                p386

        segment _TEXT byte public use16 'CODE'
        global  _text_end:byte
        label   _text_end byte
        ends    _TEXT

        segment _DATA byte public use16 'DATA'
        global  _data_end:byte
        label   _data_end byte
        ends    _DATA

        segment _BSS word public use16 'BSS'
STACK_SIZE = 1024

        global  _version_string:byte
        label   _version_string byte
		db	STACK_SIZE dup(?)
        global  stktop:byte
        label   stktop byte
        global  _bss_end:byte
        label   _bss_end byte
        ends    _BSS

        end

;###### END OF FILE ############################################
