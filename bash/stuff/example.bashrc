# /etc/bashrc: Bash system wide config file.
#

if [ "`id -u`" -eq 0 ]; then
	# Simple prompt
	#PS1='\u@\h:\w # '
	
	# Colored prompt
	PS1="\[\e[31;1m\]\u@\[\e[32;1m\]\h:\w\[\e[0m\] # "
else
	# Simple prompt
	#PS1='\u@\h:\w $ '
	
	# Colored prompt
	PS1="\[\e[34;1m\]\u@\[\e[32;1m\]\h:\w\[\e[0m\] $ "
fi

export PS1
