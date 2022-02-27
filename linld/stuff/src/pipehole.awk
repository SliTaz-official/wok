BEGIN { hold=0; is386=0; isload=0; isiso=0; istazboot=0; wascall=0; ishimem=0; label="none"; xlabel=""; file="" }
function isnum(n) { return match(n,/^[0-9+-]/) }
{
	sub(/segment word public/,"segment byte public")

	if (/^   ;	$/) next
	if (/^@.*:$/ || /	endp$/) afterjmp=0
	if (/^	\.386p$/) is386=1
	if (file == "" && /debug	S/) { file=$3; gsub(/\"/,"",file) }
	if (/debug	S/) {
		print "	%PAGESIZE 255"
		print "	include	common.inc"
	}
	 if (file == "linld.cpp") {
	if (/\[si/ || /si,/ || /,si/) sub(/si/,"di")
	else if (/\[di/ || /di,/ || /,di/) sub(/di/,"si")
	if (/add	di,2/) $0="	scasw	; " $0
	if (/bx,di/ || /\[bp-2\]/) next
	sub(/\[bx\],0/,"[di],0")
	if (/ptr @exit\$qv/) {
		if (gotexit) next
		print "call_exit:"
		gotexit=1
	}
	if (islinld==1) {
		if (/,word.*/) islinld=0
		print "; " $0
		next
	}
	if (/^_main	proc/) islinld=1
	if (/image\|initrd/) islinld=3
	if (islinld==3 && /bx,word ptr/) { print "; " $0; next }
	if (/fileexist\$qpxzc/) islinld=4
	if (islinld==4) {
		if (/DGROUP:_heap_top/) next
		if (/ax,-1/) {
			print "	inc	ax"
			print "	mov	ax,word ptr [di]"
			next
		}
		if (/ax,word ptr \[/) next
	}
	if (/buf_cmdline\+1/) {
		islinld=5
		print "	mov	bx,offset DGROUP:_buf_cmdline+1"
		sub(/offset DGROUP:_buf_cmdline\+1/,"bx")
	}
	if (islinld==5) {
		if (/bx,offset DGROUP:_buf_cmdline/) $0="	dec	bx"
		if (/ax,word ptr/) next
		if (/call/) islinld=0
	}
	if (/bx,word ptr DGROUP:_cmdstr\+6/) next
	if (/_cmdstr\+6,0/) {
		print "	mov	bx,word ptr [si+6]"
		$0="	or	bx,bx"
	}
	if (/heap_top \+1;/) islinld=6
	if (islinld==6) {
		sub(/ax/,"bx")
		if (/strcatb/) {
			print "	dec	bx"
			islinld=4
		}
	}
	if (/minram>>16/) islinld=7
	if (islinld==7) {
		if (/endif/) islinld=0
		if (/mov/) sub(/ax/,"cx");
		if (/;/ || /_memtop/) print
		if (/cmdnum/) {
			print
			print "	ja	call_exit"
		}
		next
	}
	if (/mincpu > cputype/) islinld=8
	if (islinld==8) {
		if (/endif/) islinld=0
		if (/jbe/) $0="	ja	call_exit"
	}
	 } # file == "linld.cpp"
	 if (file == "himem.cpp") {
	if (/sp,bp/ || /pop	bp/ || /enter/ || /leave/) next
	if (/void load_image/) ishimem=1
	if (ishimem == 1 && is386 == 0) {
		if (/si\+8\]$/ || /si\+4\]$/ || /si\+16\]$/) next
		if (/si\+6\]$/ || /si\+2\]$/ || /si\+14\]$/) sub(/mov	dx,/,"les	dx,d")
		if (/si\+12\],ax/ || /si\+16\],ax/ || /di\+2\],ax/ || /DGROUP:_himem_buf\+2,ax/) sub(/,ax/,",es")
		if (/dx,dword ptr \[si\+14\]/ || /DGROUP:_himem_buf,dx/) sub(/dx/,"ax")
	}
	if (ishimem == 1) {
		if (/do \{/) ishimem=2
		if (/bx,si/ || /di,ax/ || /push	bp/ || /bp,sp/ || /push	di/ || /push	si/) next
		if (/sp,2/ || /bp\+4/) next
	}
	if (ishimem == 2) {
		if (/movzx/) print "	cwde"
		if (/bp-2/ || /di,ax/ || /bx,di/ || /bx,si/) next
		if (/storepage.bufv/) {
			print "	inc	ax"
			print "	push	ax"
		}
		if (/buf \+= size;/) {
			print "	pop	ax"
		}
		if (/i\+12/) ishimem=20
	}
	if (ishimem == 20) {
		if (/loadfail/) next
		if (/je/) {
			print "	extrn	jmploadfailure"
			$0="	jne	short jmploadfailure"
		}
		if (/endp/) ishimem=0
	}
	if (/@memcpy_image\$qp11image_himem/) next
	if (/far last_ditch/) ishimem=3
	if (ishimem == 3) {
		sub(/DGROUP:_imgs\+4,/,"[si+4],")
		if (/bx,di/ || /di,ax/) next
	}
	 } # file == "himem.cpp"
	 if (file == "load.cpp") {
	if (isload != 3 && isload != 6) {  # LOAD.LST
		if (/,si/ || /si,/ || /\[si/) sub(/si/,"di")
		else if (/,di/ || /di,/ || /\[di/) sub(/di/,"si")
	}
	if (/moverm\(/) isload=16
	if (isload != 16 && /bx,si/) next
	if (/@moverm/) isload=0
	if (/readrm\(m, 0x200/) isload=15
	if (isload == 15) {  # LOAD.LST
		if (/bx,si/) next
		if (/call/) isload=0
	}
	if (/load_image\(/) {
		if (isload == 3) isload=13
		else isload=14
	}
	if (isload == 14) {  # LOAD.LST
		if (/call/) $0="	jmp	short load_imagez"
		if (/ret/) isload=0
		if (/pop/ || /ret/ || /push/) next
	}
	if (isload == 13) {  # LOAD.LST
		if (/pop/) isload=3
		if (/push/ || /call/ || /pop/) next 
	}
	if (/i\+21\],513$/) isload=11
	if (isload == 12) {  # LOAD.LST
		if (/cmp/) next
		if (/jb/) isload=0
		sub(/jb/,"jcxz")
	}
	if (isload == 11) {  # LOAD.LST
		if (/cmp/) {
			print "	mov	cx,513"
			sub(/cmp	/,"sub	cx,")
			sub(/,513/,"")
		}
		if (/jb/) isload=12
		sub(/jb/,"ja")
	}
	sub(/_imgs\+65534/,"_imgs-2")
	if (/setup_sects == 0/) isload=9
	if (isload == 9) {  # LOAD.LST
		sub(/,0/,",al	; worst case 2k boundary (iso)")
		if (/jne/) isload=0
	}
	if (/cmd_line_ptr =/ && is386 == 0) isload=7
	if (isload == 7) {  # LOAD.LST
		if (/add/ || /xor/ || /extrn/ || /N_LXLSH@/ || /cl,4/ || /,ax/) next
		if (/enable A20 if needed/) { print nextinst; isload=0 }
		if (/i-463/) $0="	mov	bx,-463"
		if (/i-465/) {
			sub(/465/,"2"); sub(/\[/,"[bx+")
			nextinst=$0; sub(/-2\],-23745/,"],8000h",nextinst) 
		}
		if (/,dx/) {
			print "	mov	cl,12"
			print "	shr	ax,cl"
			print "	mov	bx,55"
			sub(/dx/,"ax")
		}
	}
	if (/pm_low == 0/) {
		print "	push	di"
		print "	push	si"
		isload=6
	}
	if (isload == 6) {  # LOAD.LST
		if (/si\+2/) {
			print "	cmpsw"
			next
		}
		if (/les/) sub(/bx,/,"di,")
		if (/bx\+4/ || /es:/ || /call/ || /pop/ || /ret/) next
		if (/si\+6/) {
			print "	movsw"
			print "	movsw"
			print "	movsw"
			print "	movsw"
			print "	pop	si"
			print "load_imagez:"
			next
		}
	}
	if (isload == 5) {  # LOAD.LST
		sub(/ax,/,"bx,")
		if (/@puts\$qpxzc/) isload=0
		if (/mov	bx,ax/) next
		sub(/,word ptr \[di\+29\]/,",cx")
	}
	if (/_cmdnum\+14/ && is386 == 0) isload=4
	if (isload == 4) {  # LOAD.LST
		if (/_cmdnum\+14/) next
		if (/_cmdnum\+12$/) {
			$0="	les	dx,dword ptr [bx+12]"
		}
		sub(/,ax/,",es")
		if (/add	ax,word ptr/) $0="	add	ax,cx"
		if (/i\+29\],0/) {
			sub(/,0$/,"")
			sub(/cmp	/,"mov	cx,")
		}
		sub(/je/,"jcxz")
		if (/@strcpy/) isload=0
		if (/\+0x200/) isload=5
	}
	if (/void load_initrd\(\)/) { isload=3; isload2=0 }
	if (isload == 3) {  # LOAD.LST
		if (/bx,offset DGROUP:_imgs\+28/ || /push	si/) next
		if (/si,offset DGROUP:_imgs\+28/) print "	push	si"
		if (/cmdstr\+4,0/) {
			isload2++
			print	"	mov	ax,word ptr DGROUP:_cmdstr+4"
			$0="	or	ax,ax"
		}
		if (isload2 && /DGROUP:_cmdstr\+4/) $0=";" $0
		if (/je	short @2@.*/) sub(/@2@.*/,"load_initrd_ret")
		if (/mov	ax,word ptr \[si\]/) $0="	lodsw"
		if( /jmp/) {
			print "load_initrd_ret:"
			print "	ret"
			next
		}
		if (/@loadfailure/) {
			print "	global	jmploadfailure:near"
			print "jmploadfailure:"
		}
		sub(/\[di/,"[bx")
		sub(/di,/,"bx,")
	}
	if (/mode = vid_mode/) { isload=2; print	"	mov	bx,offset _cmdnum" }
	if (isload == 2) {  # LOAD.LST
		if (/DGROUP:_cmdnum/) { sub(/DGROUP:_cmdnum/,"[bx"); $0=$0 "]"}
		sub(/,0/,""); sub(/cmp	/,"mov	cx,")
		sub(/je/,"jcxz")
		if (/ax,word/) next
		sub(/,ax/,",cx")
		if (/starting linux 1\.3\.73/) isload=0
	}
	if (/_rm_size=0x200/ || /heap_top = _rm_buf/) isload=1
	if (isload == 1) {  # LOAD.LST
		if (/ptr .die\$qpxzc/) $0="@die@:\n" $0
		if (/mov	al,byte ptr/ && is386) {
			sub(/mov	al/,"movzx	eax")
		}
		if (is386 == 0) {
			if (/m->size -= _rm_size/) print "	cwd	; do not trust rewind result (iso case)"
			sub(/,0$/,",dx")
		}
		if (/ax,word ptr/) next
		if (/^	call/) isload=0
	}
	 } # file == "load.cpp"
	 if (file == "iso9660.cpp") {
	if (swapsidi == 1) {
		if (/\[si/) sub(/\[si/,"[di")
		else (/\[di/) sub(/\[di/,"[si")
		if (/\+si/) sub(/\+si/,"+di")
		else (/\+di/) sub(/\+di/,"+si")
		if (/,si/) sub(/,si/,",di")
		else if (/,di/) sub(/,di/,",si")
		if (/si,/) sub(/si,/,"di,")
		else if (/di,/) sub(/di,/,"si,")
	}
	if (/di,offset DGROUP:_buf2k/) { si="si"; di="di" }
	if (/si,offset DGROUP:_buf2k/) { si="di"; di="si" }
	if (/leave/ || /enter/ || /bp/ || /sub	sp,/) next
	if (/ptr \[.i\+8\],dx/) next
	if (/ptr \[.i\+6\],ax/) next
	if (/ptr \[.i\+6\],eax/) next
	if (/x,word ptr \[.i\+32\]/) next
	if (/add	word ptr \[.i\],ax/) sub(/ax/,"cx")
	if (/ax,word ptr \[si\+18\]/) sub(/mov	ax,/,"les	ax,d")
	if (/ax,word ptr \[si\+20\]/) next
	if (/word ptr \[si\+25\],ax/) sub(/ax/,"es")
	sub(/di,word ptr DGROUP:_isostate\+2/,"di,word ptr [si+2]")
	if (/-257/) isiso=22
	if (isiso == 22) {
		sub(/-257/,"-257	; clear C")
		if (/je/) {
			print "	cbw"
			print "	xchg	ax,bx"
			print "	xchg	ax,dx		; .. or ."
			$0="	je	returnC"
		}
	}
	if (/p = buf2k \+ 32 \+ x->curpos/) isiso=21
	if (isiso == 21) { # ISO9660.LST
		if (/ax,/) next
		if (/.i,ax/) sub(/mov/,"xchg")
		if (/# else/) isiso=0
	}
	if (/cx,.i/) {
		if (isiso == 0) {
			print "	ifndef	CLEAN_ISO9660"
			print "	inc	" di
			print "	mov	cx," di
		}
		isiso=20
	}
	if (isiso == 20) { # ISO9660.LST
		if (/bx,dx/) {
			isiso=12
			next
		}
		if (/add	.i,ax/ || /cbw/) next
		if (/cmp/) sub(/\[/,"[bx+")
		if (/inc	cx/) next
		if (/sub/) sub(/.i/,"bx")
		sub(/inc	.i/,"inc	bx")
		if (/al,byte ptr/) {
			next
		}
		sub(/i-1\],12603/,"i],12603")
		if (/bx\+.i\],46/) {
			print "	inc	" di
			print "	mov	cx," di
		}
		if (/i],0/) {
			print "	ifndef	CLEAN_ISO9660"
			print "	inc	" di
			print "	mov	cx," di
			print "	endif"
			print "seteos:"
			sub(/,0/,",bh	; clear C")
			sub(/mov	byte ptr \[/,"and	byte ptr [bx+")
		}
		if (/cx,.i/) next
		if (/\}/) {
			print "	xchg	ax,cx"
		}
		if (/cx,5/) $0="	lea	dx,[" di "+5]" 
		if (/filename = s;/) {
			isiso=0
		}
	}
	if (isiso == 19) { # ISO9660.LST
		if (/short @2@310/) $0="	jc	restoreC"
		if (/si\+32/ || /ax,dx/ || /ax,di/ || /cmp	ax,-1/ || /sub	ax,/) next
		if (/ax,word ptr \[si\+28\]/) next
		if (/bx,offset/) sub(/bx/,"ax")
		sub(/dx,/,"bx,")
		if (/short @2@282/) sub(/je/,"jnc")
		if (/\[si\+30\],0/) $0="	;or	cl,cl"
		if (/short @2@478/) sub(/je/,"jcxz")
		if (/@strcmp\$qpxzct1/) {
			print
			print "restoreC:"
			$0="	mov	byte ptr [di],dl	; c"
			isiso=1
		}
	}
	if (isiso == 18) { # ISO9660.LST
		if (/endif/) isiso=1
	}
	if (isiso == 17) { # ISO9660.LST
		if (/si\+18/) {
			print "next:"
			print "	mov	word ptr [si+20],bx"
			print
			isiso=0
		}	
		if (/_buf2k\+167/) {
			print
			$0=""
		}
		else sub(/ax/,"bx")
		if (/,bx/) next
		if (/isoreadrootsector/) {
			print
			print "	mov	ax,word ptr [_buf2k+1]"
			print "	xor	ax,17475	; clear C, CD"
			print	"jne_returnNotC:"
			print	"	cmc"
			$0="	jne	returnC"
		}
	}
	if (/if \(c\)/) isiso=16
	if (isiso == 16) { # ISO9660.LST
		if (/cmp/) {
			print "	mov	bx,word ptr [si+7]"
			print "	mov	ax,word ptr [si+11]"
			print "	dec	dx"
			print "	jns	next"
		}
		if (/isolseek/) isiso=1
		else if (! /;/) next
	}
	if (/found:/) isiso=15
	if (isiso != 15 && /si,offset DGROUP:_isostate/) $0=";" $0
	if (isiso == 15) { # ISO9660.LST
		if (/xor/) {
			print	"returnC:"
			print	"	sbb	dx,dx"
			print	"return:"
			next
		}
		if (/i\+28\],cx/) {
			print	"	ifndef BASIC_ISO9660"
			print	"	xchg	ax,dx"
			print	"	endif"
			next
		}
		if (/@1@422:/) next
		if (/\[di\],47/) isiso=17
	}
	if (isiso == 14) { # ISO9660.LST
		if (/ax,/ || /jge/) next
		sub(/mov/,"sub")
		sub(/,ax/,",8")
		if (/jmp/) {
			print	"	;JUMPS"
			print	"	jb	returnCXZC"
			$0="	;NOJUMPS"
			isiso=0
		}
	}
	if (/p = buf2k \+ 34/) isiso=13
	if (isiso == 13) { # ISO9660.LST
		#if (/cbw/) $0="	;cbw"
		if (/i,.i/) $0="	xchg	ax,bx"
		if (/i,ax/) $0="	xchg	ax," di 
		if (/i,70/ || /ptr \[.i\+32\]/) next
		if (/register len/) {
			isiso=12
		}
	}
	if (isiso == 12) { # ISO9660.LST
		if (/.i\+2/) sub(/al/,"bl")
		if (/cbw/) next
		if (/dx,ax/) next
		if (/bx,dx/) next
		sub(/i,dx/,"i,bx")
		sub(/cx,/,"dx,")
		if (/bx\+.i\],0/) {
			sub(/,0/,",bh")
		}
		if (/jmp/) {
			print
			$0="	endif"
		}
		if (/jne/) {
			print "	ifdef	BASIC_ISO9660"
			print "	lea	cx,[" di "+5]" 
			print "	je	seteos"
			print "	else"
		}
		if (/while/) isiso=120
	}
	if (isiso == 120) { # ISO9660.LST
		sub(/ax/,"cx")
		if (/cmp	cx,/) $0="	cmp	" di ",cx"
		sub(/jae/,"jb")
		if (/endif/) isiso=0
	}
	if (/curpos >= SECT/) isiso=10
	if (isiso == 10) { # ISO9660.LST
		if (/,2048/) {
			print "	xor	cx,cx"
			sub(/cmp	/,"mov	bx,")
			sub(/i.*/,"i]")
			print
			$0="	cmp	bh,2048/256"
		}
		if (/DGROUP:_buf2k\[bx\],0/) $0="	cmp	word ptr [bx+" di "],cx"
		sub(/,0/,",cx")
		if (/\[.i\],cx/) isiso=14
		else if (/mov/) next
	}
	if (/<< SECTORBITS/) isiso=9
	if (isiso == 9) { # ISO9660.LST
		if (/dx,/) next
		sub(/mov	ax,/,"les	ax,d")
		if (/^	call/) {
			print "	extrn	N_LXLSH@ES:near"
			sub(/N_LXLSH@/,"N_LXLSH@ES")
			isiso=0
		}
	}
	if (/filesize =/) isiso=8
	if (isiso == 8) { # ISO9660.LST
		if (/ax,/ || /cbw/) next
		sub(/mov	dx,/,"les	dx,d")
		sub(/\],ax/,"],es")
		sub(/cx,/,"dx,")
		if (/DGROUP:s@\+/) {
			print
			next
		}
		if (/i\+33]/) {
			print "	ifdef	ROCKRIDGE"
			print "	 ifdef	BASIC_ISO9660"
			print "	add	" di ",32"
			print "	mov	ax,[" di "]"
			print "	 else"
			print "	mov	ax,[" di "+32]"
			print "	 endif"
			print "	mov	bl,ah"
			print "	mov	bh,0"
			print "	else"
			print "	mov	al,[" di "+33]"
			print "	cbw"
			$0="	endif"
		}
		if (/sub/) {
			print "	ifdef	ROCKRIDGE"
			print "	sub	dx,bx"
			print "	else"
			print 
			$0="	endif"
			isiso=0
		}
	}
	if (/entrysize =/) isiso=5
	if (isiso == 5) { # ISO9660.LST
		if (/ax,ax/) next
		if (/word ptr \[.i\+3.\],ax/) next
		sub(/ax/,"cx")
		sub(/je/,"jcxz")
		if (/jcxz/) {
			hold=0
			print	s
			print "	stc"
			print "returnCXZC:"
			sub(/@1@1../,"returnC")
			print
			if (is386) $0="	mov	dword ptr [" si "+6],eax"
			else {
				print "	mov	word ptr [" si "+8],dx"
				$0="	mov	word ptr [" si "+6],ax"
			}
		}
		if (/return/) isiso=0
	}
	if (/do s\+\+; while/) isiso=3
	if (isiso == 3) { # ISO9660.LST
		if (/do \{/) print "while1:"
		sub(/cmp	byte ptr \[.i\]/,"sub	al")
		if (/inc	/) { r=$2; print; next }
		if (/al,0/) print "	mov	al,[" r "]"
		if (/word ptr \[si\],-1/) $0="	not	word ptr [si]	; zero'd in BSS"
		sub(/al,32/,"ax,32")
		if (/byte ptr \[si\+30\],al/) $0="	xchg	ax,cx"
		if (/al,byte ptr \[/) next
		if (/byte ptr \[.*\],0/) next
		if (/byte ptr \[si\+31\],al/) next
	}
	if (/ptr .isoreaddir/) {
		print "	ifdef	ISOHOOK"
		print "	push	cx"
		print
		print "	pop	cx"
		print "	else"
		print
		$0="	endif"
		isiso=1
	}
	if (isiso == 1) { # ISO9660.LST
		if (/xor/) {
			$0="	xor	cl,32"
			isiso=18
		}
		if (/n = name;/) {
			isiso=19
			print "	xchg	dl,byte ptr [di]	; c"
		}
		sub(/jne/,"jnc")
		if (/short @2@450/) $0="	jc	returnC"
		if (/je/) $0="	jc	while1"
		if (/short @2@562/) sub(/@2@562/,"jne_returnNotC")
		if (/jmp/) $0="	jmp	jne_returnNotC"
		if (/ax,word ptr \[si\+4\]/) $0="	xchg	ax,bx	; " $0
		if (/\[di\],al/ || /al,byte ptr/) next
		if (/@2@338/) next
		if (/ax,-1/) next
		if (/inc	di/ || /@@0/) next
		if (/@2@142$/) print "	inc	di"
	}
	if (/i\+34\]/) next
	if (/di,offset DGROUP:_isostate/) {
		sub(/mov/,";mov")
		sub(/di,/,"si,")
		swapsidi=1
	}
	if (/^	ret/) swapsidi=0
	 } # file == "iso9660.cpp"
	if (wascall) {
		if (rcall != "") {
			if (/,ax$/) 	print "	mov	" rcall ",ax"
			else		print "	xchg	ax," rcall
			wascall=0
		}
		else if (/^	mov	.i,ax$/) {
			split($2,y,",")
			rcall=y[1]
			next
		}
		else wascall=0
	}
	if (/^	call	/) { wascall=1; rcall="" }
	if (hold == 0) {
		s=$0
		if (/^	mov	.[ix],bx$/ || /^	mov	.[ix],.i$/) {
			r=$2; kept=0
			hold=1; split($2,regs,","); next
		}
		if (/^	inc	e?.[ixhl]/ || /^	dec	e?.[ixhl]/) {
			hold=2; r=$2; next
		}
		if (/^	mov	[abcds][ix],/ && ! /,.s/) {
			hold=3; split($2,regs,","); next
		}
		if (/^	movzx	eax,ax$/) { hold=4; next }
		if (/^	cmp	word ptr/ || /^  cmp     [bcd]x,/) {
			split($0,regs,",")
			if (isnum(regs[2]) && regs[2] != 0 &&
				 (regs[2] % 256) == 0) {
				hold=5; next
			}
		}
		if (/^	mov	ax,cs$/)  { hold=6; kept=0; next }
		if (/^	mov	cl,4$/)   { hold=7; next }
		if (/^	cmp	word ptr DGROUP:.*,0$/)  {
			hold=8; split($2,regs,","); next
		}
		if (/^	cbw/)		  { hold=11; kept=0; next }
		if (/^	add	[abcds][ix],2$/) {
			split($2,regs,","); hold=12; next
		}
		if (/^	sub	[abcds][ix],2$/) {
			split($2,regs,","); hold=13; next
		}
		if (/^	push	dx$/) {
			hold=14; next;
		}
	}
	else if (hold == 1) {
		if (/^   ;/) { line[kept++]=$0; next }
		hold=0; split($2,args,","); op=""
		if ($1 == "add") op="+"
		if ($1 == "sub") op="-"
		if ($1 == "inc") { op="+"; args[2]="1"; }
		if ($1 == "dec") { op="-"; args[2]="1"; }
		if (op != "" && regs[1] == args[1]) {
			if (isnum(args[2])) {
				for (i = kept++; i > 0; i--) line[i] = line[i-1]
				line[0] = "\tlea\t" regs[1] ",[" regs[2] op args[2] "]"
				sub(/\+-/,"-",line[0])
				hold=10; next
			}
			line[kept++]=$0
			hold=1
			next
		}
		if (/^	pop	[ds]i/ && regs[2] ~ /^[ds]i$/) {
			print "	xchg	" r
		}
		else print s
		for (i = 0; i < kept; i++) print line[i]; kept=0
	}
	else if (hold == 2) {
		split($0,args,",")
		if (/^	mov	/ && r == args[2]) { print s; s=$0; next }
		split($2,args,",")
		hold=0; print s
		if ($1 == "or" && r == args[1] && r == args[2]) next	# don't clear C ...
	}
	else if (hold == 3) {
		hold=0
		if (/^	call	/ && regs[2] == "ax") s="	xchg	ax," regs[1]
		if (/^	add	[abcds][ix],/) {
			split($2,regs2,",")
			if (regs[1] == regs2[1] && (regs2[2] == "offset" || isnum(regs2[2]))) {
				t=$0; sub(/mov/,$1,s); sub(/add/,"mov",t)
				print t; print s; next
			}
		}
		print s
	}
	else if (hold == 4) {
		hold=0
		if (/^	push	eax$/) {
			print "	push	0"; print "	push	ax"; next
		} else { print s }
	}
	else if (hold == 5) {
		hold=0
		if ($1 == "jae" || $1 == "jb") {
			sub(/word ptr/,"byte ptr",s); sub(/x,/,"h,",s) ||
			sub(/\],/,"+1],",s) || sub(/,/,"+1,",s)
			s = s "/256"
		}
		print s
	}
	else if (hold == 6) {
		if (($1 == "and" || $1 == "add") && $2 ~ /^ax,/) {
			line[kept++]=$0
			next
		}
		p=$0
		if (/^	movzx	eax,ax$/) {
			s="	mov	eax,cs"; p=""
		}
		print s
		for (i = 0; i < kept; i++) print line[i]; kept=0
		if (p != "") print p
		hold=0; next
	}
	else if (hold == 7) {
		hold=0
		if (/^	call	near ptr N_LXURSH@$/) {
			print "	extrn	N_LXURSH@4:near"
			print "	call	near ptr N_LXURSH@4"
			next
		}
		if (/^	call	near ptr N_LXLSH@$/) {
			print "	extrn	N_LXLSH@4:near"
			print "	call	near ptr N_LXLSH@4"
			next
		}
		print s
	}
	else if (hold == 8) {
		if ($1 == "je" || $1 == "jne") { p=$0; hold=9; next }
		hold=0
		print s
	}
	else if (hold == 9) {
		hold=0; split($2,args,",")
		if (/^	mov	ax,/ && args[2] == regs[1]) {
			print; print "	or	ax,ax"; print p; next
		}
		print s; print p;
	}
	else if (hold == 10) {
		split($2,args,","); op=""
		if ($1 == "add") op="+"
		if ($1 == "sub") op="-"
		if ($1 == "inc") { op="+"; args[2]="1"; }
		if ($1 == "dec") { op="-"; args[2]="1"; }
		if (op != "" && isnum(args[2])) {
			split(line[0],reg,",")
			if (substr(reg[1],length(reg[1])-1,2) == args[1]) {
				line[0] = substr(line[0],1,length(line[0])-1) op args[2] "]"
				next
			}
		}
		hold=0
		if (/^	mov	[sd]i,ax$/) {
			split($2,args,",")
			for (i = 0; i < kept; i++) {
				sub(/ax/,args[1],line[i]); print line[i]
			}
			next
		}
		for (i = 0; i < kept; i++) print line[i]
	}
	else if (hold == 11) {
		if (/^	inc	ax$/ || /^	dec	ax$/) {
			line[kept++]=$0; next
		}
		split($2,args,",")
		if (/^	mov	cl,/) {
			split($2,args,",")
			if (args[2] >= 8) {
				line[kept++]=$0; next
			}
		}
		if (!/^	shl	ax,/ || (args[2] != "cl" && args[2] < 8)) {
			print "	cbw	"
		}
		for (i = 0; i < kept; i++) print line[i]
		hold=kept=0
	}
	else if (hold == 12) {
		hold=0
		if ($1 != "adc" && $1 != "sbb" && ! /^	jn?[abc]/) {
			print "	inc	" regs[1]
			print "	inc	" regs[1]
		}
		else	print "	add	" regs[1] ",2"
	}
	else if (hold == 13) {
		hold=0
		if ($1 != "adc" && $1 != "sbb" && ! /^	jn?[abc]/) {
			print "	dec	" regs[1]
			print "	dec	" regs[1]
		}
		else	print "	sub	" regs[1] ",2"
	}
	else if (hold == 14) {
		if (/^	push	ax$/) { hold++; next; }
		print	"	push	dx";
		hold=0;
	}
	else if (hold == 15) {
		if (/^	pop	eax$/) { hold++; next; }
		print	"	push	dx";
		print	"	push	ax";
		hold=0;
	}
	else if (hold == 16) {
		hold=0;
		if (/^	shr	eax,16$/) { print "	xchg	ax,dx"; next; }
		print	"	push	dx";
		print	"	push	ax";
		print	"	pop	eax";
	}
	else if (hold == 17) {
		hold=0;
		if (/^	cmp	ax,-1$/) { print "	inc	ax"; next; }
	}
	if (/^	call	near ptr @fileexist\$/ || 	# return boolean :
	    /^	call	near ptr @isoreaddir\$/ ||	#  0=true, -1=false
	    /^	call	near ptr @isoreset\$/ ||
	    /^	call	near ptr @isoopen\$/ ||
	    /^	call	near ptr @isoreadsector\$/ ||
	    /^	call	near ptr @strhead\$/ ||
	    /^	call	near ptr @strcmp\$/ ||
	    /^	call	near ptr @argstr\$/ ||
	    /^	call	near ptr @argnum\$/) { print; hold=17; next; }
	s=$0
	# These optimisation may break ZF or CF
	if (/^	sub	sp,2$/) { print "	push	ax"; next }
	if (/^	sub	sp,4$/) { print "	push	ax"; print "	push	ax"; next }
	if (/^	add	sp,4$/) { print "	pop	cx"; print "	pop	cx"; next }
	if (/^	mov	d*word ptr .*,0$/ || /^	mov	dword ptr .*,large 0$/) {
		sub(/mov/,"and",s); print s; next	# slower
	}
	if (/^	mov	d*word ptr .*,-1$/ || /^	mov	dword ptr .*,large -1$/) {
		sub(/mov/,"or",s); print s; next	# slower
	}
	if (/^	or	.*,0$/ || /^	and	.*,-1$/) next
	if (/^	or	[abcd]x,/) {
		split($2,args,",")
		if (isnum(args[2]) && args[2] >= 0 && args[2] < 256) {
			print "	or	" substr(args[1],1,1) "l," args[2]; next
		}
	}
	if (/^	and	[abcd]x,/) {
		split($2,args,",")
		if (isnum(args[2]) && args[2] >= -256 && args[2] < 0) {
			print "	and	" substr(args[1],1,1) "l," args[2]; next
		}
	}
	if (/^	or	e[abcd]x,/) {
		split($2,args,",")
		if (args[2] == "large") { args[2] = $3 }
		if (isnum(args[2]) && args[2] >= 0 && args[2] < 256) {
			print "	or	" substr(args[1],2,1) "l," args[2]; next
		}
	}
	if (/^	and	e[abcd]x,/) {
		split($2,args,",")
		if (args[2] == "large") { args[2] = $3 }
		if (isnum(args[2]) && args[2] >= -256 && args[2] < 0) {
			print "	and	" substr(args[1],2,1) "l," args[2]; next
		}
	}
	if (/^	or	e[abcds][ix],/) {
		split($2,args,",")
		if (args[2] == "large") { args[2] = $3 }
		if (isnum(args[2]) && args[2] >= 0 && args[2] < 65536) {
			print "	or	" substr(args[1],2) "," args[2]; next
		}
	}
	if (/^	and	e[abcds][ix],/) {
		split($2,args,",")
		if (args[2] == "large") { args[2] = $3 }
		if (isnum(args[2]) && args[2] >= -65536 && args[2] < 0) {
			print "	and	" substr(args[1],2) "," args[2]; next
		}
	}
	if (/^	add	word ptr/ || /^	sub	word ptr/ ||
	    /^	add	[bcd]x,/ || /^	sub	[bcd]x,/) {
		split($0,args,",")
		if (isnum(args[2]) && (args[2] % 256 == 0)) {
			sub(/word ptr/,"byte ptr",s); sub(/x,/,"h,",s) ||
			sub(/\],/,"+1],",s) || sub(/,/,"+1,",s)
			print s "/256"; next
		}
	}
	if (/^	add	dword ptr/ || /^	sub	dword ptr/) {
		split($0,args,",")
		if (args[2] == "large") { args[2] = $3 }
		if (isnum(args[2])) {
			if (args[2] % 16777216 == 0) {
				sub(/dword/,"byte",s)
				sub(/\],/,"+3],",s) || sub(/,/,"+3,",s)
				print s "/16777216"; next
			}
			if (args[2] % 65536 == 0) {
				sub(/dword/,"word",s)
				sub(/\],/,"+2],",s) || sub(/,/,"+2,",s)
				print s "/65536"; next
			}
		}
	}
	if (/^	mov	e.x,/) {
		split($2,args,",")
		r=args[1]
		if (args[2] == "large") { args[2] = $3 }
		if (isnum(args[2]) && args[2] % 65536 == args[2]) {
			if (args[2] % 256 == args[2] || args[2] % 256 == 0) {
				print "	xor	" r "," r
				if (args[2] == 0) next 
				x="	mov	" substr(r,2,1)
				if (args[2] % 256 == 0) {
					print x "h," args[2] "/256"
				}
				else { print x "l," args[2] }
				next
			}
		}
	}
	if (afterjmp) print ";" $0
	else print
	if (/^	jmp	/ || /boot_kernel\(\);/ ||
	    /^	call	near ptr @die\$qpxzc/ ||
	    /^	call	near ptr @exit\$qv/) afterjmp=1
}
