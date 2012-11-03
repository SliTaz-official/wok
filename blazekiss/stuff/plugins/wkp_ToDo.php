<?php # coding: utf-8

/** Indexe les tags {TODO ...} de pages/*.txt
 * Accès via : ?action=todo
 */
class Todo
{
   public $description = "Indexe les tags {TODO ...} de la base Wiki";
      
   function action($a)
   {
      global $CONTENT,$PAGE_TITLE,$PAGE_TITLE_link,$editable;
      
      switch ($a) {
      case "todo" :
         $PAGE_TITLE_link = FALSE; // pas de lien sur le titre
         $editable = FALSE; // non editable
         $PAGE_TITLE = "To do"; // titre de la page
         $CONTENT = '
<h2>{TODO ...} tags</h2>
';

todo_index()
{
	grep -l '{TODO' pages/*.txt | while read file; do
		page=$(basename $file .txt)
		ref="<a href=\"?page=$page#TODO\">$page</a>"
		grep '{TODO' $file | sed "s|.*{TODO\\([^}]*\\)}.*|<p>$ref\\1</p>|"
	done
}

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
	 return TRUE;
      }
      return FALSE; // action non traitée
      $CONTENT = preg_replace('#\[(.*)|(pages/.*)\]#','<a href="$1">$2</a>',$CONTENT);
   } // action

   function formatBegin()
   {
      global $CONTENT;
      $CONTENT = preg_replace('#{TODO[^}]*}#','<a name="TODO"></a>',$CONTENT);
   }
}

?>
