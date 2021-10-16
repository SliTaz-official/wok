#!/bin/sh

grep -q 'text/html' level.htm || patch -p0 <<EOT
--- level.htm
+++ level.htm
@@ -22,12 +22,14 @@
 <html>
 <head>
 <title></title>
+<META HTTP-EQUIV="Content Type" CONTENT="text/html;charset=utf-8">
 <script type="text/javascript">
 <!--
 if (parent.frames[0] == null) { document.location = "sokojs.htm"  }
-Row=16
-Col=16
-document.write("<body style=\"margin:0\" bgcolor=\"black\">&nbsp;<b><FONT FACE=\"Comic Sans MS\" SIZE=4 COLOR=\"red\">LEVEL ",
+Row = eval(parent.frames[0].document.forms[1].elements[0].value)
+Col = eval(parent.frames[0].document.forms[1].elements[1].value)
+document.write("<body style=\"margin:0\" bgcolor=\"black\">&nbsp;<b><FONT FACE=\"Comic Sans MS\" SIZE=4 COLOR=\"red\">",
+  parent.frames[0].document.forms[1].elements[2].value," LEVEL ",
   eval(parent.frames[0].document.forms[0].elements[(Row*Col)+1].value) + 1);
 
 
--- main.htm
+++ main.htm
@@ -11,8 +11,9 @@
 -->
 <html>
 <head>
+<META HTTP-EQUIV="Content Type" CONTENT="text/html;charset=utf-8">
 <meta name="viewport" content="width=device-width, initial-scale=1">
-<style>
+<style type="text/css">
 <!--
 img.r{
 width:30px;
@@ -76,19 +77,19 @@
 var ie4= (navigator.appName == "Microsoft Internet Explorer")?1:0;
 var ns4= (navigator.appName=="Netscape")?1:0;
 
-Row    = 16
-Col    = 16
+Row = eval(parent.frames[0].document.forms[1].elements[0].value)
+Col = eval(parent.frames[0].document.forms[1].elements[1].value)
 
 function Nmajevent(evenement)
 {
            if (evenement.which == 52 || evenement.which == 37) {
         Move(eval(manpos) - 1)
     } else if (evenement.which == 56 || evenement.which == 38) {
-        Move(eval(manpos) - Row)
+        Move(eval(manpos) - Col)
     } else if (evenement.which == 54 || evenement.which == 39) {
         Move(eval(manpos) + 1)
     } else if (evenement.which == 50 || evenement.which == 40) {
-        Move(eval(manpos) + Row)
+        Move(eval(manpos) + Col)
     }
 }
 
@@ -108,7 +109,7 @@
          if (window.event.keyCode == 37) {
      Move(eval(manpos) - 1)
   } else if (window.event.keyCode == 38) {
-     Move(eval(manpos) - Row)
+     Move(eval(manpos) - Col)
   } else if (window.event.keyCode == 39) {
      Move(eval(manpos) + 1)
   } else if (window.event.keyCode == 40) {
@@ -150,7 +151,7 @@
 manD  = new Image(30, 30); manD.src = "9.gif"; // down
 
 level = new Array()
-maxLevel = 97
+maxLevel = eval(parent.frames[0].document.forms[1].elements[3].value)
 moves = 0
 
 function ReloadLevel() {
@@ -168,14 +169,18 @@
 
 function GoLevel(n) {
   if (n == nbLevel) ReloadLevel()
-  parent.frames[0].document.location = "level" + n + ".htm"
+  parent.frames[0].document.location = parent.frames[0].document.forms[1].elements[2].value + "/level" + n + ".htm"
+}
+
+function GoSet() {
+  parent.frames[0].document.location = document.getElementById('set').value + "/level0.htm"
 }
 
 function dir(d) {
   if (d ==   -1) return "L";
   if (d ==    1) return "R";  
-  if (d ==  Row) return "D";    
-  if (d == -Row) return "U";      
+  if (d ==  Col) return "D";    
+  if (d == -Col) return "U";      
 }
 
 function print_moves(m) {
@@ -226,7 +231,7 @@
     if (nbBoxin == 0) {
       if (nbLevel < maxLevel) {
         alert("You have done a good job !")
-        parent.frames[0].location = "level" + (++nbLevel) + ".htm"
+        parent.frames[0].document.location = parent.frames[0].document.forms[1].elements[2].value + "/level" + (++nbLevel) + ".htm"
         GoLevel(nbLevel)
       } else {
         alert("Congratulations !")
@@ -246,14 +251,14 @@
   for (y = 0 ; y < Row; y++) {
     document.write ("<TR>")
     for (x = 0; x < Col; x++) {
-      level[x + Row * y] = parent.frames[0].document.forms[0].elements[x + Row * y].value
-      if (level[x + Row * y] == dest) nbBoxin++
-      if (level[x + Row * y] == land || level[x + Row * y] == wall)
+      level[x + Col * y] = parent.frames[0].document.forms[0].elements[x + Col * y].value
+      if (level[x + Col * y] == dest) nbBoxin++
+      if (level[x + Col * y] == land || level[x + Col * y] == wall)
         document.write("<TD VALIGN=TOP>",
-          "<IMG align=middle class=r border=0 src=\"", level[x + Row * y], ".gif\"<\/TD>")
+          "<IMG align=middle class=r border=0 src=\"", level[x + Col * y], ".gif\"<\/TD>")
       else
-        document.write("<TD VALIGN=TOP><A HREF=\"JavaScript:Move(", x + Row * y, ")\">",
-          "<IMG align=middle class=r border=0 src=\"", level[x + Row * y], ".gif\"</A><\/TD>")      
+        document.write("<TD VALIGN=TOP><A HREF=\"JavaScript:Move(", x + Col * y, ")\">",
+          "<IMG align=middle class=r border=0 src=\"", level[x + Col * y], ".gif\"</A><\/TD>")      
     }
     document.write("<\/TR>")
   }
@@ -266,8 +271,12 @@
  document.write("<FORM>",
   "<INPUT TYPE=button onClick=\"Javascript:ReloadLevel();\" value=\"Restart\">",
   "<INPUT TYPE=button onClick=\"Javascript:UndoMove();\" value=\"Undo\"><p id=\"moves\" style=\"color:white\">0 moves</p></center>")
+  style="style='font-family:Courier New;font-size:14px;font-weight:bold;border:1;border-color:0;padding:0;margin:0px;background-color:#c0c0c0;color:#404040..'"
+  document.write("<select id='set' "+style+" onChange=\"Javascript:GoSet();\">")
+  document.write("<option>sokojs</option>");
+    document.write("</select><br />")
   for (i = 0; i <= maxLevel; i++) {
-    document.write("<INPUT style='font-family:Courier New;font-size:14px;font-weight:bold;border:1;border-color:0;padding:0;margin:0px;background-color:#c0c0c0;color:#404040ù' TYPE=\"button\" onClick=\"Javascript:GoLevel(", i, ");\" value=\"", (i<9?"&nbsp;":"")+(i+1), "\">")
+    document.write("<INPUT "+style+" TYPE=\"button\" onClick=\"Javascript:GoLevel(", i, ");\" value=\"", (i<9?"&nbsp;":"")+(i+1), "\">")
   }
   document.write("<\/FORM></table>")
 
--- sokojs.htm
+++ sokojs.htm
@@ -22,13 +22,13 @@
 <html>
 <head>
 <TITLE>Sokoban (C) Michel Buze</TITLE>
-<META HTTP-EQUIV="Keywords" CONTENT="boxworld,javascript,sokoban,jeu,jeux,game,buze,web">
+<META HTTP-EQUIV="Content Type" CONTENT="text/html;charset=utf-8">
 <META NAME="Keywords" CONTENT="boxworld,javascript,sokoban,jeu,jeux,game,buze,web">
 <meta name="viewport" content="width=device-width, initial-scale=1">
 </head>
 
 <frameset border="0" rows="0,700,*">
-<frame src="level0.htm">
+<frame src="sokojs/level0.htm">
 <frame src="0.gif">
 <frame src="0.gif">
 <noframes>
EOT
[ -s level0.htm ] && mkdir sokojs && mv level?*.htm sokojs &&
sed -i 's|location = "|&../|;/.*main.htm/i document.write("<FORM ACTION=\\"\\">")\
document.write("<INPUT TYPE=\\"button\\" value=\\""+Row+"\\">",\
               "<INPUT TYPE=\\"button\\" value=\\""+Col+"\\">",\
               "<INPUT TYPE=\\"button\\" value=\\"sokojs\\">",\
               "<INPUT TYPE=\\"button\\" value=\\"97\\"><\\/FORM>")' sokojs/level*.htm
