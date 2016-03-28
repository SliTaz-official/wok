#!/bin/sh

[ -z "$1" ] && echo "Usage: $0 <newpassword>" && exit 1

/etc/init.d/mysql stop
/usr/bin/mysqld_safe --skip-grant-tables &
mysql <<EOT
UPDATE `mysql`.`user` SET `Password` = password('$1') WHERE `User` = "root" AND Host = "localhost";
quit
EOT
mysqladmin shutdown
/etc/init.d/mysql start
