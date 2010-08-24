for i in ../puzzles-*/_pkg/usr/local/games/*
do 
	name=$(basename $i)
	cp games.desktop.mk $name.desktop
	sed -i -e  "s/%%NAME%%/$name/" \
		-e  "s/%%EXEC%%/$name/" \
		-e  "s/%%ICONS%%/$name.png/" $name.desktop
	
done
