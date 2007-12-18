# /etc/bashrc: Bash system wide config file.
#

if [ "`id -u`" -eq 0 ]; then
	PS1='\u@\h:\w\# '
else
	PS1="\[\e[34;1m\]\u@\[\e[32;1m\]\h:\w\[\e[0m\] $ "
fi

export PS1
