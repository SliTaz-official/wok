BEGIN { hold=0 }
function isnum(n) { return match(n,/^[0-9+-]/) }
{
	if (hold == 0) {
		s=$0
		if (/^	mov	.x,bx$/ || /^	mov	.x,.i$/) {
			hold=1; split($2,regs,","); next
		}
		if (/^	inc	e?.[ix]/ || /^	dec	e?.[ix]/) {
			hold=2; r=$2; next
		}
		if (/^	mov	[abcds][ix],/ && ! /,.s/) {
			hold=3; split($2,regs,","); next
		}
		if (/^	movzx	eax,ax$/) { hold=4; next }
if (0) {
		if (/^	cmp	dx,-1$/) { hold=10; next }
}
	}
	else if (hold == 1) {
		hold=0; split($2,args,","); op=""
		if ($1 == "add") op="+"
		if ($1 == "sub") op="-"
		if (op != "" && regs[1] == args[1] && isnum(args[2])) {
			print "\tlea\t" regs[1] ",[" regs[2] op args[2] "]"
			next
		}
		print "\tmov\t" regs[1] "," regs[2]
	}
	else if (hold == 2) {
		hold=0; split($2,args,","); print s
		if ($1 == "or" && r == args[1] && r == args[2]) next	# don't clear C ...
	}
	else if (hold == 3) {
		hold=0
		if (/^	add	[abcds][ix],/ || /^	sub	[abcds][ix],/) {
			split($2,regs2,",")
			if (regs[1] == regs2[1] && (regs2[2] == "offset" || isnum(regs2[2]))) {
				t=$0; sub(/mov/,$1,s)
				if ($1 == "add") sub(/add/,"mov",t); else sub(/sub/,"mov",t)
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
	else if (hold == 10) {
		if ($1 == "je" || $1 == "jne") { s2=$0; cmp=$1; hold++; next }
		hold=0; print s
	}
	else if (hold == 11) {
		if (/^	cmp	ax,-1$/) { s3=$0; hold++; next }
		hold=0; print s; print s2
	}
	else if (hold == 12) {
		if (($1 == "je" || $1 == "jne") && $1 != cmp) {
			print "	and	ax,dx"; print "	inc	ax"
		} else { print s; print s2; print s3 }
		hold=0
	}
	s=$0
	# These optimisation may break ZF or CF
	if (/^	add	sp,4/) { print "	pop	cx"; print "	pop	cx"; next }
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
		if (isnum(args[2]) && args[2] >= -255 && args[2] < 0) {
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
		if (isnum(args[2]) && args[2] >= -255 && args[2] < 0) {
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
		if (isnum(args[2]) && args[2] >= -65535 && args[2] < 0) {
			print "	and	" substr(args[1],2) "," args[2]; next
		}
	}
	if (/^	add	word ptr/ || /^	sub	word ptr/) {
		split($0,args,",")
		if (isnum(args[2]) && (args[2] % 256 == 0)) {
			sub(/word/,"byte",s); sub(/\]/,"+1]",s)
			print s "/256"; next
		}
	}
	if (/^	add	dword ptr/ || /^	sub	dword ptr/) {
		split($0,args,",")
		if (args[2] == "large") { split(args[2],args," ") }
		if (isnum(args[2])) {
			if (args[2] % 16777216 == 0) {
				sub(/dword/,"byte",s); sub(/\]/,"+3]",s)
				print s "/16777216"; next
			}
			if (args[2] % 65536 == 0) {
				sub(/dword/,"word",s); sub(/\]/,"+2]",s)
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
	print
}
