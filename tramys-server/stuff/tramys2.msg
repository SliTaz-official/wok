# Sorry, no gettext here. It needs to install locale packages for used locales,
# and I don't want to install them to our Tank server.

msg() {
case $lang in
	pt_BR)
		case $1 in
			1)  echo "#Pacotes instalados: $PKGNUM"
				echo "#Pesquisando em andamento..." ;;
			2)  echo -e "#\n#Fazendo um arquivo. Por favor, aguarde..." ;;
			3)  SIZE=$(echo $SIZE | sed -e 's|.*|&B|')
				echo -e "#\n#Feito!"
				echo -e "#Agora você pode continuar a fazer\n#download e instalar as suas traduções."
				echo "#O tamanho do arquivo: $SIZE" ;;
		esac ;;
	ru*)
		case $1 in
			1)  echo "#Количество пакетов: $PKGNUM"
				echo "#Поиск переводов…" ;;
			2)  echo -e "#\n#Создание архива. Подождите…" ;;
			3)  SIZE=$(echo $SIZE | sed -e 's|\.|,|;s|[0-9,]*|& |;s|.*|&Б|')
				echo -e "#\n#Готово!"
				echo -e "#Теперь вы можете загрузить\n#и установить найденные переводы."
				echo "#Размер файла: $SIZE" ;;
		esac ;;
	*)
		case $1 in
			1)  echo "#Number of packages: $PKGNUM"
				echo "#Searching in progress..." ;;
			2)  echo -e "#\n#Preparing archive. Please wait..." ;;
			3)  SIZE=$(echo $SIZE | sed -e 's|.*|&B|')
				echo -e "#\n#Done!"
				echo -e "#Now you can proceed to downloading\n#and installing your translations."
				echo "#File size: $SIZE" ;;
		esac ;;
esac
}
