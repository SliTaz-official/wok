<?php # coding: utf-8

/** Transfert un fichier (images ...) dans pages/data
 * Accès via : ?action=upload
 */
class Upload
{
   public $description = "Télécharge un fichier dans la base Wiki";
      
   function template()
   {
   	global $html;
   	
	$upload = "Chargement";
   	switch ($_GET["action"]) {
   	case "edit" :
   		$html = preg_replace("/HISTORY/",
  	 		"<a href=\"$urlbase?action=upload\">$upload</a> / HISTORY",
  	 		$html);
  	 	break;
   	case "upload" :
   	case "uploadfile" :
   		$html = preg_replace('/ \/ <a href.*recent.*<\/a>/', '', $html);
   		$html = preg_replace('/.*name="query".*/', '', $html);
  	 	break;
  	default:
  		return 1;
   	}
	return 0;
   }
   
   function action($a)
   {
      global $plugins,$CONTENT,$HELP_BUTTON,$EDIT_BUTTON,$PAGE_TITLE,
      		$PAGE_TITLE_link,$editable;
      
      $upload = "Chargement";
      switch ($a) {
      case "upload" :
         $PAGE_TITLE_link = FALSE; // pas de lien sur le titre
         $editable = FALSE; // non editable
         $PAGE_TITLE = "$upload"; // titre de la page
         $CONTENT = '
<form method="post" enctype="multipart/form-data" action="?action=uploadfile">
<input type="file" name="file" value="file"/>
<input type="submit"/>
<table>
';
	 if ($handle = @opendir("pages/data")) {
		while(($item = readdir($handle)) !== false) {
			 if ($item == '..' || $item == '.') continue;
		         $CONTENT .= '<tr><td><input type=checkbox ';
		         exec('grep -qs "pages/data/'.$item.'" pages/*.txt', $tmp, $ret);
		         if ($ret == 0) $CONTENT .= 'checked=checked ';
		         $CONTENT .= 'disabled=disabled /><a href="pages/data/'.
		         	$item.'">'.$item.'</a></td></tr>';
		}
	 }
         $CONTENT .= '
</table>
</form>
';
         break;
      case "uploadfile" :
	 @mkdir("pages/data");
	 $name = $_FILES["file"]["name"]; $n="";
	 if (is_file("pages/data/".$name)) $n=1;
	 while (is_file("pages/data/".$n.$name)) $n++;
	 move_uploaded_file($_FILES["file"]["tmp_name"], "pages/data/".$n.$name);
	 $url = "pages/data/".$n.$name;
         $PAGE_TITLE_link = FALSE; // pas de lien sur le titre
         $editable = FALSE; // non editable
         $PAGE_TITLE = "$upload"; // titre de la page
         $CONTENT = '<h1><a href="javascript:history.go(-2)">'.
         	$EDIT_BUTTON.'</a></h1>
<p>
Le fichier '.$_FILES["file"]["name"].' ('.$_FILES["file"]["size"].' octets, '.
		$_FILES["file"]["type"].' est plac&eacute; en <a href="'.$url.'">'.
		$url.'</a>.
</p>';
	 switch (substr($_FILES["file"]["type"],0,4)) {
	 case "imag":
	 	$CONTENT .= '
<p>
Vous pouvez inc&eacute;rer cette image avec <b>['.$url.']</b> voir
<a href="?page='.$HELP_BUTTON.'">'.$HELP_BUTTON.'</a> pour plus de d&eacute;tails.
</p>
<img src="'.$url.'" alt="'.$url.'" />';
	 	break;
	 }
         break;
      default:
	return FALSE; // action non traitée
      }
      return TRUE;
   } // action

   function formatEnd()
   {
      global $CONTENT;
      $CONTENT = preg_replace('#\[(.*)|(pages/.*)\]#','<a href="$1">$2</a>',$CONTENT);
      $CONTENT = preg_replace('#\[(pages/.*)\]#','<a href="$1">$1</a>',$CONTENT);
   }
}

?>
