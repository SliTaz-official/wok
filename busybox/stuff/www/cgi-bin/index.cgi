#!/bin/sh

[ ! -d ..$QUERY_STRING ] && echo "HTTP/1.1 404 Not Found" || cat <<EOT  
Content-type: text/html

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head> <title>Index of $QUERY_STRING</title> </head>
<body>
	<h1>Index of $QUERY_STRING</h1>
	<ul>
$({ [ "$QUERY_STRING" != "/" ] && echo "../"; ls -p ..$QUERY_STRING; } | \
  sed 's|.*|		<li><a href="&">&</a></li>|')
	</ul>
</body>
</html>
EOT
