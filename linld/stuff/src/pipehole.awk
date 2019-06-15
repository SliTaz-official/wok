BEGIN { hold=0; is386=0; isload=0; isiso=0; istazboot=0; wascall=0 }
function isnum(n) { return match(n,/^[0-9+-]/) }
{
	sub(/segment word public/,"segment byte public")

	if (/^@.*:$/ || /	endp$/) afterjmp=0
	if (/dword ptr/) is386=1
	if (/vid_mode = vid_mode/) isload=2
	if (isload == 2) {  # LOAD.LST
		sub(/,0/,""); sub(/cmp	/,"mov	cx,")
		sub(/je/,"jcxz")
		if (/ax,word/) next
		sub(/,ax/,",cx")
		if (/version_string/) isload=0
	}
	if (/heap_top = _rm_buf/) isload=1
	if (isload == 1) {  # LOAD.LST
		if (/mov	al,byte ptr/ && is386) {
			print "	movzx	eax,byte ptr [si]"
			next
		}
		if (/ax,word ptr/) next
		if (/^	call/) isload=0
	}
	if (/x->curdirsize == 0xFFFF/) isiso=4
	if (isiso == 4) { # ISO9660.LST
		sub(/DGROUP:_isostate\+14/,"[si+14]")
		sub(/DGROUP:_isostate\+16/,"[si+16]")
		if (/goto restarted/) isiso=0
	}
	if (/c = \*s; \*s = 0;/) isiso=3
	if (isiso == 3) { # ISO9660.LST, TAZBOOT.LST
		if (/al,byte ptr/) {
			print "	mov	al,0"
			sub(/mov/,"xchg")
		}
		if (/byte ptr \[.*\],0/) {
			isiso=0
			next
		}
	}
	if (/endname = NULL/) isiso=2
	if (isiso == 2) { # ISO9660.LST
		if (/mov	bx,cx/) next
		gsub(/cx/,"bx")
		sub(/DGROUP:_isostate\+31/,"[si+31]")
	}
	if (/const char \*n = name/) isiso=1
	if (isiso == 1) { # ISO9660.LST
		if ((/mov	word ptr \[si\+32\],ax/ ) ||
		    (/mov	ax,word ptr \[si\+28\]/) ||
		    (/bx,word ptr \[si\+32\]/) || (/ax,dx/)) next
		if (/dx,/) sub(/dx/,"ax")
		if ((/sub	ax,word ptr \[si\+28\]/) ||
		    (/\[si\+12\]/) || (/ax,di/)) sub(/ax/,"bx")
		if (/add	word ptr \[si\+32\],ax/) $0="	add	bx,word ptr [si+12]"
		if (/al,/ || /,al/) sub(/al/,"cl")
		if (/cmp	byte ptr \[si\+30\],0/) $0="	or	cl,cl"
		if (/jne	@@0$/) next
		if (/jmp	@3@58$/) $0="	je	@3@58"
	}
	if (/isoopen\(s\+7\) != -1/) isotazboot=8
	if (isotazboot == 8) { # TAZBOOT.LST
		if (/ax,si/) next
		sub(/ax,ax/,"si,si")
		if (/magic/) isotazboot=0
	}
	if (/\+\+isknoppix/) isotazboot=7
	if (isotazboot == 7) { # TAZBOOT.LST
		if (/al,byte/) sub (/al,byte ptr DGROUP:/,"bx,offset ")
		if (/inc/) sub (/al/,"word ptr [bx]")
		if (/,al/) next
		if (/isokernel/) isotazboot=0
	}
	if (/if \(c\) s\+\+;/) isotazboot=6
	if (isotazboot == 6) { # TAZBOOT.LST
		if (/cmp/) {
			$0="	cmp	al,0"
			isotazboot=0
		}
	}
	if (/initrd_state.info\[m->state\]/) isotazboot=5
	if (isotazboot == 5) { # TAZBOOT.LST
		if (/cx,ax/) $0="	xchg	ax,bx"
		if (/mov	ax,word ptr \[si\]/) $0="	lodsw"
		if (/ax,word ptr \[si\+28\]/) next
		if (/bx,cx/) next
		if (/endp/) isotazboot=0
	}
	if (/0x7FF0/) isotazboot=4
	if (isotazboot == 4) { # TAZBOOT.LST
		if (/ax,word ptr/) {
			print "	mov	ax,32752"
			sub(/mov/,"sub")
		}
		if (/bx,/ || /cx,/ || /dx,/) next
		sub(/,bx/,",0")
		sub(/,cx/,",ax")
		if (/short/) isotazboot=0
	}
	if (/c = x->filename/) isotazboot=3
	if (isotazboot == 3) { # TAZBOOT.LST
		if (/ax,/) $0="	xchg	ax,bx"
		if (/\]$/) next
		if (/@strcpy\$qpxzct1/) isotazboot=0
	}
	if (/memtop/) isotazboot=2
	if (isotazboot == 2) { # TAZBOOT.LST
		if (/DGROUP:_base_himem\+2,dx/) print "	mov	bx,offset _base_himem"
		sub(/DGROUP:_base_himem,/,"[bx],")
		sub(/DGROUP:_base_himem\+2,/,"[bx+2],")
		sub(/DGROUP:_base_himem\+3,/,"[bx+3],")
		if (/ax,word ptr \[bx\+2\]/ || /\[bp-4\],ax/) sub(/ax/,"bx")
		if (/bx,ax/) next
		if (/@strcmp\$qpxzct1/) isotazboot=0
	}
	if (/static void addinitrd/) isotazboot=1
	if (isotazboot == 1 || isotazboot == 100) { # TAZBOOT.LST
		if (/m->next_chunk = next_chunk/) isotazboot=100
		if (/load_initrd/) isotazboot=1
		if (/push	si/ && isotazboot == 1) next
		if (/pop	si/) next
		sub(/\[si\]/,"[bx]")
		sub(/si,/,"bx,")
		sub(/si\+/,"bx+")
		if (/mov	cx,ax/) $0="	xchg	ax,bx"
		if (/bx,cx/) next
		sub(/cx/,"bx")
		sub(/DGROUP:_imgs\+38/,"[bx+38]")
		sub(/DGROUP:_imgs\+40/,"[bx+40]")
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
	if (/^	jmp	/) afterjmp=1
}
