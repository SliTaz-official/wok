#!/bin/sh

[ -s level.htm ] && rm level.htm && patch -p0 <<EOT
--- main.htm
+++ main.htm
@@ -19,7 +19,11 @@
 width:30px;
 height:30px;
 }
-
+a{
+color:red;
+text-decoration:none;
+display:block;
+}
 @media screen and (max-width: 450px) {
 img.r{
 width:29px;
@@ -77,8 +81,11 @@
 var ie4= (navigator.appName == "Microsoft Internet Explorer")?1:0;
 var ns4= (navigator.appName=="Netscape")?1:0;
 
-Row    = 16
-Col    = 16
+Row = eval(parent.frames[0].document.forms[1].elements[0].value)
+Col = eval(parent.frames[0].document.forms[1].elements[1].value)
+CurSet = parent.frames[0].document.forms[1].elements[2].value
+maxLevel = eval(parent.frames[0].document.forms[1].elements[3].value)
+nbLevel = eval(parent.frames[0].document.forms[0].elements[(Row*Col)+1].value)
 
 function Nmajevent(evenement)
 {
@@ -124,6 +131,10 @@
 
 <script type="text/javascript">
 <!--
+if (parent.window.location.search.length > 1 && parent.frames[0].location.hash.length == 0 &&
+    parent.frames[0].location.href.indexOf(parent.window.location.search.substring(1)) < 0)
+    parent.frames[0].location = parent.window.location.search.substring(1)
+
 if (document.all) {
   top.window.resizeTo(800, 600);
 } else if (document.layers || document.getElementById) {
@@ -151,13 +162,26 @@
 manD  = new Image(30, 30); manD.src = "9.gif"; // down
 
 level = new Array()
-maxLevel = 97
 moves = 0
 saved = ""
 
+function urlself()
+{
+  var l = parent.window.location.href+"?"
+  return l.substring(0, l.search(/[#?]/))+
+         "?"+CurSet+"/level"+nbLevel+".htm#"+saved
+}
+
+function seturl()
+{
+  var e = document.getElementById("urlsave")
+  e.setAttribute("href", urlself());
+}
+
 function ReloadLevel() {
   manpos = parent.frames[0].document.forms[0].elements[Row*Col].value
   moves = 0
+  saved = ""
   window.status = ""
   nbBoxin = 0
   for (i = 0 ; i < Row * Col; i++) {
@@ -168,9 +192,18 @@
   document.images[manpos].src = eval("manD.src")
 }
 
+function Go(d,n) {
+  parent.frames[0].document.location = d + "/level" + n + ".htm#" + d
+  seturl()
+}
+
 function GoLevel(n) {
   if (n == nbLevel) ReloadLevel()
-  parent.frames[0].document.location = "level" + n + ".htm"
+  Go(CurSet, n)
+}
+
+function GoSet() {
+  Go(document.getElementById('set').value, 0)
 }
 
 function dir(d) {
@@ -214,6 +247,7 @@
       m = eval("man"+c.toUpperCase()+".src")
     } while (c == c.toLowerCase())
     document.images[manpos].src = m
+    seturl()
   }
 }
 
@@ -224,9 +258,9 @@
     var m = dir(d).toLowerCase()
     if (level[a] == boxin || level[a] == boxout)  {
       b = a + d  
-      ++moves
       m = dir(d)
       if (level[b] == floor || level[b] == dest)  {
+        ++moves
         level[a] == boxin ? (level[a] = dest,  nbBoxin++) : level[a] = floor
         level[b] == dest  ? (level[b] = boxin, nbBoxin--) : level[b] = boxout
         document.images[b].src = eval("img" + level[b] + ".src")
@@ -243,7 +277,7 @@
     if (nbBoxin == 0) {
       if (nbLevel < maxLevel) {
         alert("You have done a good job !")
-        parent.frames[0].location = "level" + (++nbLevel) + ".htm"
+        parent.frames[0].document.location = CurSet + "/level" + (++nbLevel) + ".htm"
         GoLevel(nbLevel)
       } else {
         alert("Congratulations !")
@@ -251,6 +285,7 @@
       }
     }
   }
+  seturl()
 }
   window.focus()
   window.status = ""
@@ -277,21 +312,32 @@
   }
   document.write("<\/TABLE>")
   manpos = parent.frames[0].document.forms[0].elements[Row*Col].value
-  nbLevel = parent.frames[0].document.forms[0].elements[(Row*Col)+1].value
 
   document.write("</table><TABLE cellspacing=0 cellpadding=0 style='max-width:300px'><TD>")
 
  document.write("<FORM>",
   "<INPUT TYPE=button onClick=\"Javascript:ReloadLevel();\" value=\"Restart\">",
   "<INPUT TYPE=button onClick=\"Javascript:UndoMove();\" value=\"Undo\"><p id=\"moves\" style=\"color:white\">0 moves</p></center>")
+  style="style='font-family:Courier New;font-size:14px;font-weight:bold;border:1;border-color:0;padding:0;margin:0px;background-color:#c0c0c0;color:#404040..'"
+  document.write("<select id='set' "+style+" onChange=\"Javascript:GoSet();\">")
+  document.write("<option>Change level pack</option>");
+  document.write("<option>sokojs</option>");
+  document.write("</select><br />")
+  document.write("<body style=\"margin:0\" bgcolor=\"black\">&nbsp;<b><FONT FACE=\"Comic Sans MS\" SIZE=4 COLOR=\"red\">",
+    "<a id=\"urlsave\" href=\"",urlself(),"\">",CurSet," LEVEL ",nbLevel + 1,"</a><br/>")
   for (i = 0; i <= maxLevel; i++) {
-    document.write("<INPUT style='font-family:Courier New;font-size:14px;font-weight:bold;border:1;border-color:0;padding:0;margin:0px;background-color:#c0c0c0;color:#404040ù' TYPE=\"button\" onClick=\"Javascript:GoLevel(", i, ");\" value=\"", (i<9?"&nbsp;":"")+(i+1), "\">")
+    document.write("<INPUT "+style+" TYPE=\"button\" onClick=\"Javascript:GoLevel(", i, ");\" value=\"", (i<9?"&nbsp;":"")+(i+1), "\">")
   }
   document.write("<\/FORM></table>")
 
   document.images[manpos].src = eval("manD.src")
+
+  if (parent.window.location.hash.length > 1 && parent.frames[0].location.hash.length == 0) {
+    for (i = 2; i <= parent.window.location.hash.length; i++)
+      Move(manpos-undoDir(parent.window.location.hash.substring(i-1,i)))
+  }
 //-->
 </script>
 
 </body>
-</html>
\ No newline at end of file
+</html>
--- sokojs.htm
+++ sokojs.htm
@@ -22,14 +22,13 @@ Foundation, Inc., 59 Temple Place - Suit
 <html>
 <head>
 <TITLE>Sokoban (C) Michel Buze</TITLE>
-<META HTTP-EQUIV="Keywords" CONTENT="boxworld,javascript,sokoban,jeu,jeux,game,buze,web">
+<META HTTP-EQUIV="Content Type" CONTENT="text/html;charset=utf-8">
 <META NAME="Keywords" CONTENT="boxworld,javascript,sokoban,jeu,jeux,game,buze,web">
 <meta name="viewport" content="width=device-width, initial-scale=1">
 </head>
 
-<frameset border="0" rows="0,700,*">
-<frame src="level0.htm">
-<frame src="0.gif">
+<frameset border="0" rows="0,*">
+<frame src="sokojs/level0.htm">
 <frame src="0.gif">
 <noframes>
 <body>
EOT
[ -s level0.htm ] && mkdir sokojs && for l in level*.htm ; do
	col=$(sed '/^Col/!d;s|Col=||' $l)
	pos=$(sed '/write/!d;/value=\\"[0-9]/!d;s|.*value=."||;s|.".*||' $l)
	awk -vx=$(($pos%$col+2)) -vy=$(($pos/$col+10)) '{ c="@"
  if (substr($0,x,1) == ".") c="+"
  if(l++==y) $0=substr($0,1,x-1) c substr($0,x+1)
  print }' < $l | sed -e "s|1)|&.replace('+','.').replace('@','_')|" \
	-e '/level.htm/d;s|location = "|&../|;/.*main.htm/i document.write("<FORM ACTION=\\"\\">")\
document.write("<INPUT TYPE=\\"button\\" value=\\""+Row+"\\">",\
               "<INPUT TYPE=\\"button\\" value=\\""+Col+"\\">",\
               "<INPUT TYPE=\\"button\\" value=\\"sokojs\\">",\
               "<INPUT TYPE=\\"button\\" value=\\"97\\"><\\/FORM>")' > sokojs/$l
	rm -f $l
done
[ -s sokojs/description.txt ] || cat > sokojs/description.txt <<EOT
SokoJS
Sokoban Game for Javascript
michel.buze@gmail.com
http://buze.michel.chez.com
copyright Michel BUZE
EOT
