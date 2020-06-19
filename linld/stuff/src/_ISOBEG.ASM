;***************************************************************
;****** This file is distributed under GPL
;***************************************************************
                ideal
		%PAGESIZE 1000
                %crefref
                %noincl
                %nomacs
                p8086

        group   DGROUP  _TEXT,_DATA,_BSS
        assume  cs:DGROUP,ds:DGROUP

        segment _TEXT byte public use16 'CODE'
        ends    _TEXT

        segment _DATA byte public use16 'DATA'
        global  _data_start:byte
        label   _data_start byte
        ends    _DATA

        segment _BSS byte public use16 'BSS'
        global  _bss_start:byte
        label   _bss_start byte
        ends    _BSS

        segment _TEXT byte public use16 'CODE'

                org     100h
        global  _text_start:byte
        label   _text_start byte

		extrn	_isostate
		dw	_isostate

        ends    _TEXT


        end     _text_start

;###### END OF FILE ############################################
