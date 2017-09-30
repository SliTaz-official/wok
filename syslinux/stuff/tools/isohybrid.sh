#!/bin/sh

if [ "$1" == "--build" ]; then
	cat >> $0 <<EOM
$(for i in fx fx_f fx_c px px_f px_c ; do
     cat mbr/isohdp$i.bin /dev/zero | dd bs=1 count=512 2> /dev/null
  done | gzip -9 | uuencode -m -)
EOT
EOM
	sed -i '/--build/,/^fi/d' $0
	exit
fi
iso=
heads=64	# zipdrive-style geometry
sectors=32
partype=23	# "Windows hidden IFS"
entry=
id=$(( ($RANDOM <<16) + $RANDOM))
offset=0
partok=0
hd0=0
always=0

while [ -n "$1" ]; do
	case "${1/--/-}" in
	-a*)	always=1;;
	-ct*)	hd0=2;;
	-e*)	entry=$2; shift;;
	-f*)	hd0=1;;
	-h)	heads=$2; shift;;
	-i*)	id=$(($2)); shift;;
	-noh*)	hd0=0;;
	-nop*)	partok=0;;
	-o*)	offset=$(($2)); shift;;
	-p*)	partok=1;;
	-s)	sectors=$2; shift;;
	-t*)	partype=$(($2 & 255)); shift;;
	*)	iso=$1;;
	esac
	shift
done

if [ ! -f "$iso" ]; then
	cat << EOT
usage: $0 [options] isoimage
options:
	-h <X>		Number of default geometry heads
	-s <X>		Number of default geometry sectors
	-e --entry	Specify partition entry number (1-4)
	-o --offset	Specify partition offset (default 0)
	-t --type	Specify partition type (default 0x17)
	-i --id		Specify MBR ID (default random)
	--forcehd0	Assume we are loaded as disk ID 0
	--ctrlhd0	Assume disk ID 0 if the Ctrl key is pressed
	--partok	Allow booting from within a partition
	--always	Do not abort on errors
EOT
	exit 1
fi

ddq()
{
	dd "$@" 2> /dev/null
}

readiso()
{
	ddq bs=2k skip=$1 count=1 if=$iso | ddq bs=1 skip=$2 count=$3
}

# read a 32 bits data
read32()
{
	readiso $1 $2 4 | od -N 4 -t u4 -An
}

# read a 16 bits data
read16()
{
	readiso $1 $2 2 | od -N 2 -t u2 -An
}

# read a 8 bits data
read8()
{
	readiso $1 $2 1 | od -N 1 -t u1 -An
}

# write a 32 bits data
store32()
{
	n=$2; for i in 0 8 16 24; do
		printf '\\\\x%02X' $((($n >> $i) & 255))
	done | xargs echo -en | ddq bs=1 conv=notrunc of=$iso seek=$(($1))
}

store32sw()
{
	n=$2; for i in 24 16 8 0; do
		printf '\\\\x%02X' $((($n >> $i) & 255))
	done | xargs echo -en | ddq bs=1 conv=notrunc of=$iso seek=$(($1))
}

crc32()
{
	t0=00000000; t1=77073096; t2=EE0E612C; t3=990951BA;
	t4=076DC419; t5=706AF48F; t6=E963A535; t7=9E6495A3;
	t8=0EDB8832; t9=79DCB8A4; t10=E0D5E91E; t11=97D2D988;
	t12=09B64C2B; t13=7EB17CBD; t14=E7B82D07; t15=90BF1D91;
	t16=1DB71064; t17=6AB020F2; t18=F3B97148; t19=84BE41DE;
	t20=1ADAD47D; t21=6DDDE4EB; t22=F4D4B551; t23=83D385C7;
	t24=136C9856; t25=646BA8C0; t26=FD62F97A; t27=8A65C9EC;
	t28=14015C4F; t29=63066CD9; t30=FA0F3D63; t31=8D080DF5;
	t32=3B6E20C8; t33=4C69105E; t34=D56041E4; t35=A2677172;
	t36=3C03E4D1; t37=4B04D447; t38=D20D85FD; t39=A50AB56B;
	t40=35B5A8FA; t41=42B2986C; t42=DBBBC9D6; t43=ACBCF940;
	t44=32D86CE3; t45=45DF5C75; t46=DCD60DCF; t47=ABD13D59;
	t48=26D930AC; t49=51DE003A; t50=C8D75180; t51=BFD06116;
	t52=21B4F4B5; t53=56B3C423; t54=CFBA9599; t55=B8BDA50F;
	t56=2802B89E; t57=5F058808; t58=C60CD9B2; t59=B10BE924;
	t60=2F6F7C87; t61=58684C11; t62=C1611DAB; t63=B6662D3D;
	t64=76DC4190; t65=01DB7106; t66=98D220BC; t67=EFD5102A;
	t68=71B18589; t69=06B6B51F; t70=9FBFE4A5; t71=E8B8D433;
	t72=7807C9A2; t73=0F00F934; t74=9609A88E; t75=E10E9818;
	t76=7F6A0DBB; t77=086D3D2D; t78=91646C97; t79=E6635C01;
	t80=6B6B51F4; t81=1C6C6162; t82=856530D8; t83=F262004E;
	t84=6C0695ED; t85=1B01A57B; t86=8208F4C1; t87=F50FC457;
	t88=65B0D9C6; t89=12B7E950; t90=8BBEB8EA; t91=FCB9887C;
	t92=62DD1DDF; t93=15DA2D49; t94=8CD37CF3; t95=FBD44C65;
	t96=4DB26158; t97=3AB551CE; t98=A3BC0074; t99=D4BB30E2;
	t100=4ADFA541; t101=3DD895D7; t102=A4D1C46D; t103=D3D6F4FB;
	t104=4369E96A; t105=346ED9FC; t106=AD678846; t107=DA60B8D0;
	t108=44042D73; t109=33031DE5; t110=AA0A4C5F; t111=DD0D7CC9;
	t112=5005713C; t113=270241AA; t114=BE0B1010; t115=C90C2086;
	t116=5768B525; t117=206F85B3; t118=B966D409; t119=CE61E49F;
	t120=5EDEF90E; t121=29D9C998; t122=B0D09822; t123=C7D7A8B4;
	t124=59B33D17; t125=2EB40D81; t126=B7BD5C3B; t127=C0BA6CAD;
	t128=EDB88320; t129=9ABFB3B6; t130=03B6E20C; t131=74B1D29A;
	t132=EAD54739; t133=9DD277AF; t134=04DB2615; t135=73DC1683;
	t136=E3630B12; t137=94643B84; t138=0D6D6A3E; t139=7A6A5AA8;
	t140=E40ECF0B; t141=9309FF9D; t142=0A00AE27; t143=7D079EB1;
	t144=F00F9344; t145=8708A3D2; t146=1E01F268; t147=6906C2FE;
	t148=F762575D; t149=806567CB; t150=196C3671; t151=6E6B06E7;
	t152=FED41B76; t153=89D32BE0; t154=10DA7A5A; t155=67DD4ACC;
	t156=F9B9DF6F; t157=8EBEEFF9; t158=17B7BE43; t159=60B08ED5;
	t160=D6D6A3E8; t161=A1D1937E; t162=38D8C2C4; t163=4FDFF252;
	t164=D1BB67F1; t165=A6BC5767; t166=3FB506DD; t167=48B2364B;
	t168=D80D2BDA; t169=AF0A1B4C; t170=36034AF6; t171=41047A60;
	t172=DF60EFC3; t173=A867DF55; t174=316E8EEF; t175=4669BE79;
	t176=CB61B38C; t177=BC66831A; t178=256FD2A0; t179=5268E236;
	t180=CC0C7795; t181=BB0B4703; t182=220216B9; t183=5505262F;
	t184=C5BA3BBE; t185=B2BD0B28; t186=2BB45A92; t187=5CB36A04;
	t188=C2D7FFA7; t189=B5D0CF31; t190=2CD99E8B; t191=5BDEAE1D;
	t192=9B64C2B0; t193=EC63F226; t194=756AA39C; t195=026D930A;
	t196=9C0906A9; t197=EB0E363F; t198=72076785; t199=05005713;
	t200=95BF4A82; t201=E2B87A14; t202=7BB12BAE; t203=0CB61B38;
	t204=92D28E9B; t205=E5D5BE0D; t206=7CDCEFB7; t207=0BDBDF21;
	t208=86D3D2D4; t209=F1D4E242; t210=68DDB3F8; t211=1FDA836E;
	t212=81BE16CD; t213=F6B9265B; t214=6FB077E1; t215=18B74777;
	t216=88085AE6; t217=FF0F6A70; t218=66063BCA; t219=11010B5C;
	t220=8F659EFF; t221=F862AE69; t222=616BFFD3; t223=166CCF45;
	t224=A00AE278; t225=D70DD2EE; t226=4E048354; t227=3903B3C2;
	t228=A7672661; t229=D06016F7; t230=4969474D; t231=3E6E77DB;
	t232=AED16A4A; t233=D9D65ADC; t234=40DF0B66; t235=37D83BF0;
	t236=A9BCAE53; t237=DEBB9EC5; t238=47B2CF7F; t239=30B5FFE9;
	t240=BDBDF21C; t241=CABAC28A; t242=53B39330; t243=24B4A3A6;
	t244=BAD03605; t245=CDD70693; t246=54DE5729; t247=23D967BF;
	t248=B3667A2E; t249=C4614AB8; t250=5D681B02; t251=2A6F2B94;
	t252=B40BBE37; t253=C30C8EA1; t254=5A05DF1B; t255=2D02EF8D;
	crc=$((0xFFFFFFFF))
	dd if=$iso bs=1 skip=$(($1)) count=$(($2)) 2> /dev/null | \
	od -v -w1 -t u1 -An | {
		while read n; do
			local x=$((($crc ^ $n) & 255))
			eval x=0x\$t$x
			crc=$(((($crc >> 8) & 0x00FFFFFF) ^ $x))
		done
		echo $(($crc ^ 0xFFFFFFFF))
	}
}

main()
{
	uudecode | gunzip | ddq bs=512 count=1 of=$iso conv=notrunc \
	  skip=$(( (3*$partok) + $hd0))
	store32 432 $(($lba * 4))
	store32 440 $id
	store32 508 0xAA550000
	e=$(( ((${entry:-1} -1) % 4) *16 +446))
	store32 $e 0x10080
	esect=$(( ($sectors + ((($cylinders -1) & 0x300) >>2)) <<16))
	ecyl=$(( (($cylinders -1) & 0xff) <<24))
	store32 $(($e + 4)) $(($partype + (($heads - 1) <<8) +$esect +$ecyl))
	store32 $(($e + 8)) $offset
	store32 $(($e + 12)) $(($cylinders * $heads * $sectors))
	if [ -n "$efi_ofs" ]; then
		[ $(read16 0 1024) -eq 35615 -a $(read16 11 0) -ne 35615 ] &&
		ddq bs=512 conv=notrunc skip=2 seek=44 count=20 if=$iso of=$iso
		store32 $((446+16)) $((0xFFFFFE00))
		store32 $((446+16+4)) $((0xFFFFFEEF))
		store32 $((446+16+8)) $efi_ofs
		store32 $((446+16+12)) $efi_len
		uudecode <<EOT | unlzma | ddq bs=512 seek=1 of=$iso conv=notrunc
begin-base64 644 -
XQAAgAD//////////wAikYVN1N2VY3JXMnUMJn1RCdQOHN33EegtIBhrUQ7Q
JNaW37NYVuUAmqtISPiCdgAxPRlBS0xDlmAPPOCSZXmEFz9jEkXSzmsGn6+o
7SMAKMfvpMa3U1bJv/napT+/NFttJSJSx0xJA3em3KJcZsO66vaYeJC5tE+3
T0p9AJtSH6X8SMic3vU3hYWwHsYnsmeoGmsy4EJba9Wf/0liMQA=
====
EOT
		lastlba=$((($cylinders * $heads * $sectors) -1))
		usablelba=34
		store32 $((0x218)) 1
		store32 $((0x220)) $lastlba
		store32 $((0x228)) $usablelba
		store32 $((0x230)) $(($lastlba-$usablelba+1))
		store32 $((0x428)) $(($lastlba-0x800))
		store32 $((0x4A0)) $efi_ofs
		store32 $((0x4A8)) $(($efi_ofs+$efi_len-1))
		store32 $((0x258)) $(crc32 0x400 0x4000)
		store32 $((0x210)) $(crc32 0x200 $(read32 0 $((0x20C))))
		store32sw $((0x1008)) $(($efi_ofs/4))
		store32sw $((0x1054)) $(($efi_len/4))
		for i in 238 410 490 ; do
			ddq if=/dev/urandom count=16 bs=1 conv=notrunc \
			    of=$iso seek=$((0x$i))
		done
	fi
}

abort()
{
	echo "$iso: $1"
	[ $always -eq 0 ] && exit 1
}

[ "$(readiso 17 7 23)" == "EL TORITO SPECIFICATION" ] ||
	abort "no boot record found."
cat=$(read32 17 71)
[ $(read32 $cat 0) -eq 1 -a $(read32 $cat 30) -eq $(( 0x88AA55 )) ] ||
	abort "invalid boot catalog."
efi_ofs=
if [ $(read8 $cat 65) -eq 239 ]; then
	[ -n "$entry" ] && echo "$iso: efi boot ignore --entry $entry" && entry=
	partype=0
	efi_len=$(read16 $cat 102)
	efi_ofs=$((4*$(read32 $cat 104)))
fi
lba=$(read32 $cat 40)
[ $(read32 $lba 64) -eq 1886961915 ] ||
	abort "no isolinux.bin hybrid signature in bootloader."
size=$(stat -c "%s" $iso)
trksz=$(( 512 * $heads * $sectors ))
cylinders=$(( ($size + $trksz - 1) / $trksz ))
pad=$(( (($cylinders * $trksz) - $size) / 512 ))
#[ $pad -eq 0 ] || ddq bs=512 count=$pad if=/dev/zero >> $iso
if [ $cylinders -gt 1024 ]; then
	cat 1>&2 <<EOT
Warning: more than 1024 cylinders ($cylinders).
Not all BIOSes will be able to boot this device.
EOT
	cylinders=1024
fi

main <<EOT
