BEGIN { hold=0; is386=0; isload=0; isiso=0; istazboot=0; wascall=0; ishimem=0; label="none"; xlabel=""; file="" }
function isnum(n) { return match(n,/^[0-9+-]/) }
{
	sub(/segment word public/,"segment byte public")

	if (/^   ;	$/) next
	if (/^@.*:$/ || /	endp$/) afterjmp=0
	if (/^	\.386p$/) is386=1
	if (file == "" && /debug	S/) { file=$3; gsub(/\"/,"",file) }
	if (/debug	S/) print "	%PAGESIZE 1000"
	 if (file == "tazboot.cpp") {
	if (/add	si,2/) $0="	lodsw	; " $0
	if (/add	si,4/) { print "	lodsw"; $0="	lodsw	; " $0 }
	if (/add	di,2/) $0="	scasw	; " $0
	if (/int argc/) istazboot=1
	if (istazboot == 1) {
		if (/push.*i$/) $0="; " $0
		if (/word ptr/) { istazboot=0; $0="; " $0 }
	}
	 } # file == "tazboot.cpp"
	 if (file == "linld.cpp") {
	if (/add	si,2/) $0="	lodsw	; " $0
	if (/add	di,2/) $0="	scasw	; " $0
	if (/bx,offset DGROUP:s@\+26/) sub(/mov/,";mov")
	if (islinld==1) {
		print "; " $0
		if (!/word ptr/) next
		islinld=0
		sub(/,word.*/,",di	; argv")
		if (/di,di/) { print "; " $0; next }
	}
	if (/^_main	proc/) islinld=1
	if (/== 0x662F/) islinld=2
	if (islinld==2) {
		if (/cpuhaslm/) islinld=0
		if (/bx,word/) { print "; " $0; next }
	}
	if (/image\|initrd/) islinld=3
	if (islinld==3) {
		if (/bx,word ptr/) { print "; " $0; next }
	}
	if (/fileexist\$qpxzc/) islinld=4
	if (islinld==4) {
		if (/ax,-1/) {
			print "	inc	ax"
			print "	mov	ax,word ptr [si]"
			next
		}
		if (/ax,word ptr/) next
		if (/\[si\]$/) { islinld=0; print "; " $0; next }
	}
	if (/buf_cmdline\+1/) {
		islinld=5
		print "	mov	bx,offset DGROUP:buf_cmdline+1"
		sub(/offset DGROUP:buf_cmdline\+1/,"bx")
	}
	if (islinld==5) {
		if (/bx,offset DGROUP:buf_cmdline/) $0="	dec	bx"
		if (/ax,word ptr/) next
		if (/call/) islinld=0
	}
	 } # file == "linld.cpp"
	 if (file == "himem.cpp") {
	if (/sp,bp/ || /pop	bp/) next
	if (/void load_image/) ishimem=1
	if (ishimem == 1 && is386 == 0) {
		if (/si\+8\]$/ || /si\+4\]$/ || /si\+16\]$/) next
		if (/si\+6\]$/ || /si\+2\]$/ || /si\+14\]$/) sub(/mov	dx,/,"les	dx,d")
		if (/si\+12\],ax/ || /si\+16\],ax/ || /DGROUP:buf\+2,ax/) sub(/,ax/,",es")
		if (/dx,dword ptr \[si\+14\]/ || /DGROUP:buf,dx/) sub(/dx/,"ax")
	}
	if (ishimem == 1) {
		if (/do \{/) ishimem=2
		if (/bx,si/ || /push	bp/ || /bp,sp/ || /push	di/ || /push	si/) next
		if (/sp,2/) next
		if (/bp\+4/) {
			$0="	xchg	ax,si"
		}
	}
	if (ishimem == 2) {
		if (/movzx/) print "	cwde"
		if (/bp-2/ || /di,ax/ || /bx,di/) next
		if (/storepage.bufv/) {
			print "	inc	ax"
			print "	push	ax"
		}
		if (/buf \+= size;/) {
			print "	pop	ax"
		}
		if (/endp/) ishimem=0
	}
	if (/@memcpy_image\$qp11image_himem/) next
	if (/far last_ditch/) {
		print "	extrn	memcpy_image_kernel:near"
		print "	extrn	memcpy_image_initrd:near"
		ishimem=3
		cpy_initrd=0
	}
	if (ishimem == 3) {
		if (/bx,di/ || /di,ax/ || /bx,32/) next
		if (/mov	bx,si/) {
			if (cpy_initrd==0) sub(/mov	bx,si/, "call	memcpy_image_kernel")
			else sub(/mov	bx,si/, "call	memcpy_image_initrd")
			cpy_initrd=1-cpy_initrd
		}
		sub(/lea	bx,\[si\+32\]/, "call	memcpy_image_initrd")
	}
	if (/m = pm2initrd/) ishimem=4
	if (ishimem == 4) {
		if (/si,32/ || /bx,di/ || /di,ax/) next
		sub(/\[si/,"[si+32")
		sub(/mov	bx,si/, "call	memcpy_image_initrd")
	}
	 } # file == "himem.cpp"
	 if (file == "load.cpp") {
	if (/readrm\(m, 0x200/) isload=15
	if (isload == 15) {  # LOAD.LST
		if (/bx,di/) next
		if (/call/) isload=0
	}
	if (/load_image\(/) {
		if (isload == 3) isload=13
		else isload=14
	}
	if (isload == 14) {  # LOAD.LST
		if (/call/) {
			print	"	xchg	ax,di"
			$0="	jmp	short load_imagez"
		}
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
	if (/m, _rm_size/) isload=10
	if (isload == 10) {  # LOAD.LST
		if (/^	je	/ || /bx,di/) next
		if (/ptr @die\$qpxzc/) {
			$0="	jne	@die@"
			isload=0
		}
	}
	if (/setup_sects == 0/) isload=9
	if (isload == 9) {  # LOAD.LST
		sub(/,0/,",al")
		if (/jne/) isload=0
	}
	if (/fallback\)\[1\] == 0/) isload=8
	if (isload == 8) {  # LOAD.LST
		if (/load_image/) isload=0
		else next
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
		print "	mov	ax,si"
		print "	push	di"
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
			print "load_imagez:"
			next
		}
	}
	if (isload == 5) {  # LOAD.LST
		sub(/ax,/,"bx,")
		if (/strcatb/) isload=0
		if (/mov	bx,ax/) next
		sub(/,word ptr \[si\+29\]/,",cx")
	}
	if (/_base_himem\+2/ && is386 == 0) isload=4
	if (isload == 4) {  # LOAD.LST
		if (/_base_himem\+2/) next
		if (/_base_himem$/) {
			sub(/mov	dx,/,"les	dx,d")
		}
		sub(/,ax/,",es")
		if (/add	ax,word ptr/) $0="	add	ax,cx"
		if (/i\+29\],0/) {
			sub(/,0$/,"")
			sub(/cmp	/,"mov	cx,")
		}
		sub(/je/,"jcxz")
		if (/\+0x200/) isload=5
	}
	if (/void load_initrd\(\)/) isload=3
	if (isload == 3) {  # LOAD.LST
		if (/short @2@198/) sub(/@2@198/,"load_initrd_ret")
		if (/mov	ax,word ptr \[si\]/) $0="	lodsw"
		if( /jmp/) {
			print "load_initrd_ret:"
			print "	pop	si"
			print "	ret"
			next
		}
		sub(/\[di/,"[bx")
		sub(/di,/,"bx,")
	}
	if (/vid_mode = vid_mode/) isload=2
	if (isload == 2) {  # LOAD.LST
		sub(/,0/,""); sub(/cmp	/,"mov	cx,")
		sub(/je/,"jcxz")
		if (/ax,word/) next
		sub(/,ax/,",cx")
		if (/starting linux 1\.3\.73/) isload=0
	}
	if (/die\(not_kernel/ || /_rm_size=0x200/ || /heap_top = _rm_buf/) isload=1
	if (isload == 1) {  # LOAD.LST
		if (/ptr .die\$qpxzc/) $0="@die@:\n" $0
		if (/mov	al,byte ptr/ && is386) {
			sub(/mov	al/,"movzx	eax")
		}
		if (is386 == 0) {
			if (/m->size -= _rm_size/) print "	cwd"
			sub(/,0$/,",dx")
		}
		if (/ax,word ptr/) next
		if (/^	call/) isload=0
	}
	 } # file == "load.cpp"
	 if (file == "iso9660.cpp") {
	if (/x->curpos \+= x->entrysize/) isiso=14
	if (isiso == 14) { # ISO9660.LST
		if (/ax,ax/) {
			print "return0:"
			isiso=0
		}
	}
	if (/p = x->buffer \+ 34/) isiso=13
	if (isiso == 13) { # ISO9660.LST
		if (/di,si/) $0="	xchg	ax,bx"
		if (/di,ax/) $0="	lea	di,[si+bx+70]"
		if (/di,70/) {
			isiso=0
			next
		}
	}
	if (/register len/) isiso=12
	if (isiso == 12) { # ISO9660.LST
		sub(/mov	dx,ax/,"xchg	ax,bx")
		if (/bx,dx/) next
		sub(/i,dx/,"i,bx")
		if (/while/) isiso=0
	}
	if (/while \(\*\+\+s/) isiso=11
	if (isiso == 11) { # ISO9660.LST
		if (/cmp/ || /filename2open/) isiso=0
		if (/cmp/) next
		if (/mov/) {
			sub(/mov	bx,/,"cmp	byte ptr [")
			sub(/i$/,"i],0")
		}
	}
	if (/curpos >= SECT/) isiso=10
	if (isiso == 10) { # ISO9660.LST
		if (/cmp/) {
			sub(/cmp	/,"mov	bx,")
			sub(/i.*/,"i]")
			print
			$0="	cmp	bh,2048/256"
		}
		if (/mov/) {
			isiso=0
			next
		}
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
		if (/ax,/) next
		sub(/mov	dx,/,"les	dx,d")
		sub(/,ax/,",es")
		if (/filemod/) isiso=0
	}
	if (/CD001/) isiso=7
	if (isiso == 7) { # ISO9660.LST
		sub(/mov	ax,-1/,"dec	ax")
		if (/jmp/) isiso=0
	}
	if (/int len =/) isiso=6
	if (isiso == 6) { # ISO9660.LST
		if (/dx,ax/) next
		sub(/ax/,"dx")
		sub(/cx,di/,"bx,di")
		sub(/cx,dx/,"bx,ax")
		sub(/di,dx/,"di,ax")
		if (/while/) isiso=2
	}
	if (/entrysize =/) isiso=5
	if (isiso == 5) { # ISO9660.LST
		if (/ax,ax/) next
		sub(/ax/,"cx")
		sub(/je/,"jcxz")
		if (/return/) isiso=0
	}
	if (/x->curdirsize == 0xFFFF/) isiso=4
	if (isiso == 4) { # ISO9660.LST
		sub(/DGROUP:_isostate\+18/,"[si+18]")
		sub(/DGROUP:_isostate\+20/,"[si+20]")
		if (/goto restarted/) isiso=0
	}
	 } # file == "iso9660.cpp"
	 if (file == "iso9660.cpp" || file == "tazboot.cpp") {
	if (/do s\+\+; while/) isiso=3
	if (/for \(p = s; \*s && \*s \!=/) isiso=3	# tazboot/main
	if (isiso == 3) { # ISO9660.LST, TAZBOOT.LST
		sub(/cmp	byte ptr \[.i\]/,"sub	al")
		if (/mov	byte ptr \[bp-5\],al/) $0="	push	ax"
		if (/mov	al,byte ptr \[bp-5\]/) $0="	pop	ax"
		if (/inc	/) { r=$2; print; next }
		if (/al,0/) print "	mov	al,[" r "]"
		if (/al,byte ptr/) sub(/mov/,"xchg")
		if (/byte ptr \[.*\],0/) next
		if (/jmp/) {
			print "	mov	bx,si"
			$0="	db	0A8h	; test al,xx instead of " $0
		}
		if (/word ptr \[bp-4\]/) next
		if (/\) s\+\+;/ || /\],-1/) isiso=0
	}
	 } # file == "iso9660.cpp" || file == "tazboot.cpp"
	 if (file == "iso9660.cpp") {
	if (/endname = NULL/) isiso=2
	if (isiso == 2) { # ISO9660.LST
		if (/mov	bx,cx/) next
		gsub(/cx/,"bx")
		sub(/DGROUP:_isostate\+35/,"[si+35]")
	}
	if (/const char \*n = name/) isiso=1
	if (isiso == 1) { # ISO9660.LST
		if ((/mov	word ptr \[si\+32\],ax/ ) ||
		    (/mov	ax,word ptr \[si\+2\]/) ||
		    (/bx,word ptr \[si\+32\]/) || (/ax,dx/)) next
		if (/dx,/) sub(/dx/,"ax")
		if ((/sub	ax,word ptr \[si\+2\]/) ||
		    (/\[si\+16\]/) || (/ax,di/)) sub(/ax/,"bx")
		if (/add	word ptr \[si\+32\],ax/) $0="	add	bx,word ptr [si+16]"
		if (/al,/ || /,al/) sub(/al/,"cl")
		if (/cmp	byte ptr \[si\+34\],0/) $0="	or	cl,cl"
		if (/ax,ax/) next
		if (/short @.@506/)  $0="	jmp	return0"
		if (/jne	@@0$/) next
		if (/jmp	@.@58$/) sub(/jmp/,"je")
		sub(/mov	ax,-1/,"dec	ax")
	}
	 } # file == "iso9660.cpp"
	if (/endp/) { xlabel = ""; goto2=0 }
	if (/isoopen\(s\+7\)/ && xlabel == "") goto2=1		# tazboot/bootiso
	if (/_vid_mode,ax/ && xlabel == "") goto2=1		# tazboot/main
	if (/_initrd_name,si/ && xlabel == "") goto2=1		# tazboot/main
	if (/_base_himem\+2,/ && xlabel == "@") goto2=1		# tazboot/bootiso tazboot/main
	if (/DGROUP:_skip_alloc/ && xlabel == "@") goto2=1	# tazboot/bootiso tazboot/main
	if (/puts\(cmdline\)/ && xlabel == "@@") goto2=1
	if (goto2 == 1 && /jmp/) { # TAZBOOT.LST && LINLD.LST
		print $NF xlabel "@:"
		label=$NF
	}
	if (goto2 > 0 && label == $NF) {
		$0=$0 xlabel
		if (goto2++ == 1) xlabel=xlabel "@"
	}
	if (file == "tazboot.cpp" && /close\(x/) isotazboot=16
	if (isotazboot == 160) { # TAZBOOT.LST
		$0="; " $0
		if (/ret/) isotazboot=0
	}
	if (isotazboot == 16) { # TAZBOOT.LST
		if (/@.@/) {
			isotazboot=160
			next
		}
	}
	if (file == "tazboot.cpp" && /jne	@@2/) isotazboot=15
	if (isotazboot == 15) { # TAZBOOT.LST
		if (/@.@/) {
			print	"	pop	di"
			print	"	pop	si"
			print	"	mov	sp,bp"
			print	"	pop	bp"
			print	"	ret"
			next
		}
		if (/skip_alloc/) isotazboot=0
	}
	if (/if\(\*s>=/) isotazboot=14
	if (isotazboot == 14) { # LINLD.LST
		if (/jmp/) {
			$0="	db	0A9h	; test ax,xxxx instead of " $0
			isotazboot=0
		}
	}
	if (file == "tazboot.cpp" && /;					s \+= 4/) isotazboot=13	# tazboot/main
	if (isotazboot == 13) { # TAZBOOT.LST
		if (/si,4/) $0="	lea	bx,[si+4]"
		if (/bx,si/) next
		if (/DGROUP:_topmem/ || /set_iso/) isotazboot=0
	}
	if (file == "tazboot.cpp" && /case 0x652F:/) isotazboot=12	# tazboot/main
	if (isotazboot == 12) { # TAZBOOT.LST
		sub(/si,word/,"bx,word")
		if (/short/) isotazboot=0
	}
	if (/return load_kernel/) isotazboot=11	# tazboot/isokernel
	if (isotazboot == 11) { # TAZBOOT.LST
		sub(/call/,"jmp")
		if (/ret/ || /pop/) next
		if (/endp/) isotazboot=0
	}
	if (/cmdline=s\+=3/ || /magic \!= 0/ || /&root_dev =/) { isotazboot=10; j="" }	# ,tazboot/bootiso,tazboot/main
	if (isotazboot == 10) { # TAZBOOT.LST && LINLD.LST
		if (/je/ || /jne/) { j=$1; next }
		if (/jmp/) {
			if (j=="jne") sub(/jmp/,"je")
			else if (j=="je") sub(/jmp/,"jne")
			isotazboot=0
		}
	}
	if (/static const unsigned long initrddesc = 18L/) isotazboot=9	# tazboot/bootiso
	if (isotazboot == 9) { # TAZBOOT.LST
		if (/,0/) {
			split($4,y,",")
			print "	mov	bx,offset " y[1]
			sub(/DGROUP:.*,/,"[bx],")
		}
		if (/mov/ && $3 == y[1]) next
		if (/je/) next
		if (/jmp/) sub(/jmp/,"jne")
		sub(/ax,offset/,"bx,offset")
		if (/bx,ax/) { isotazboot=0; next }
	}
	if (/isoopen\(s\+7\) != -1/) isotazboot=8	# tazboot/bootiso
	if (isotazboot == 8) { # TAZBOOT.LST
		sub(/\[bx/,"[si")
		if (/bx,si/) next
		if (/magic/) isotazboot=0
	}
	if (/isoopen\(\"bzImage\"\)/) isotazboot=7		# tazboot/bootiso
	if (isotazboot == 7) { # TAZBOOT.LST
		if (/inc/ || /,al/) next
		if (/al,byte/) sub (/mov	al,/,"inc	")
		if (/isokernel/) isotazboot=0
	}
	if (/if \(c\) s\+\+;/) isotazboot=6		# tazboot/main
	if (isotazboot == 6) { # TAZBOOT.LST
		if (/cmp/) {
			$0="	cmp	al,0"
			isotazboot=0
		}
	}
	if (/static void next_chunk/) isotazboot=5	# tazboot/next_chunk
	if (isotazboot == 501) {
		if (/ret/) {
			print "@1@86:"
			isotazboot=0
		}
	}
	if (isotazboot == 5 || isotazboot == 500) { # TAZBOOT.LST
		if (/cx,ax/) $0="	xchg	ax,bx"
		if (/ax,word ptr \[si\+28\]/ && isotazboot == 500) next
		if (/bx,cx/) next
		if (/push/ || /pop/ || /bp,sp/ || /si,/) next
		sub(/\[si/,"[di")
		if (/initrd_info/) isotazboot=500
		if (/bx\+6\]/) next
		if (/bx\+4\]/) sub(/mov	dx,/,"les	dx,d")
		sub(/di\+24\],ax/,"di+24],es")
		sub(/call/,"jmp")
		if (/ret/ || /pop/ || /^@1@86:/) next
		if (/_isostate\+14/) next
		if (/_isostate\+12/) {
			sub(/mov	ax,/,"les	ax,d")
			print
			print "	mov	dx,es"
			next
		}
		if (/ax,-4/) isotazboot++
	}
	if (/0x7FF0/) isotazboot=4		# tazboot/bootiso
	if (isotazboot == 4) { # TAZBOOT.LST
		if (/ax,word ptr/) {
			print "	mov	ax,32752"
			print "	cwd"
			sub(/mov/,"sub")
		}
		if (/bx,/ || /cx,/ || /dx,/) next
		sub(/,0/,",dx")
		sub(/,bx/,",dx")
		sub(/,cx/,",ax")
		if (/@addinitrd\$qv/) isotazboot=0
	}
	if (/c = x->filename/) isotazboot=3	# tazboot/bootiso
	if (isotazboot == 3) { # TAZBOOT.LST
		if (/ax,/) $0="	xchg	ax,bx"
		if (/\]$/) next
		if (/@strcpy\$qpxzct1/) isotazboot=0
	}
	if (/base_himem = memtop/) isotazboot=2	# tazboot/bootiso
	if (isotazboot == 2) { # TAZBOOT.LST
		if (/word ptr \[si\+2\],0/) {
			print s; hold=0
			print "	mov	bx,word ptr [si+2]"
			$0="	or	bx,bx"
		}
		if (/\[bp-4\],ax/) sub(/ax/,"bx")
		if (/ax,word ptr \[si\+2\]/ || /bx,ax/) next
		if (/_base_himem\+2,dx/) {
			print "	mov	bx,offset DGROUP:_base_himem+2"
		}
		sub(/DGROUP:_base_himem,/,"[bx-2],")
		sub(/DGROUP:_base_himem\+2,/,"[bx],")
		sub(/DGROUP:_base_himem\+3,/,"[bx+1],")
		if (/@strcmp\$qpxzct1/) isotazboot=0
	}
	if (/static void addinitrd/) isotazboot=100	# tazboot/addinitrd
	if (isotazboot == 100) { # TAZBOOT.LST
		if (/cx,ax/) {
			print "	mov	si,offset _isostate+8"
			print "	push	ds"
			print "	pop	es"
			print "	xchg	ax,di"
			print "	movsw"
			print "	movsw"
			print "	movsw"
			print "	movsw"
			$0="	xchg	ax,di"
		}
		if (/mov/ && !/si/ && !/cl/) next
		if (/void load_initrds/) isotazboot=101
	}
	if (isotazboot == 101 || isotazboot == 102) { # TAZBOOT.LST
		sub(/\[si/,"[di"); sub(/si,/,"di,"); sub(/si$/,"di")
		sub(/DGROUP:_imgs\+38$/,"[di+38-32]")
		sub(/DGROUP:_imgs\+40$/,"[di+40-32]")
		if (/isofd/) isotazboot=102
		if (/push/ && isotazboot == 102) next
		if (/pop/ && isotazboot == 102) next
		if (/load_initrd/) isotazboot=101
		if (/isokernel/) isotazboot=103
	}
	if (isotazboot > 102) { # TAZBOOT.LST
		if (/push/ || /pop/) next
		sub(/\[si/,"[bx")
		sub(/si,/,"bx,")
		if (/static void bootiso/) isotazboot=0
	}
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
	if (/^	jmp	/ || /^	call	near ptr _boot_kernel/ ||
	    /^	call	near ptr @die\$qpxzc/ ||
	    /^	call	near ptr @exit\$qv/) afterjmp=1
}
