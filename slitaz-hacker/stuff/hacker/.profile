# ~/.profile: Executed by Bourne-compatible login SHells.
#

# Path to personal scripts and executables (~/.local/bin).
#
if [ -d "$HOME/.local/bin" ] ; then
	PATH=$HOME/.local/bin:$PATH
	export PATH
fi

# Java JRE (paths).
#
#JAVA_HOME=$HOME/.local/lib/jre1.6.0_03
#JAVA_BINDIR=$JAVA_HOME/bin
#if [ -d "$JAVA_BINDIR" ] ; then
#	export PATH=$JAVA_BINDIR:$PATH
#fi

# Environnement variables and prompt for Ash SHell
# or Bash. Default is a classic prompt.
#
PS1='\u@\h:\w\$ '

EDITOR='nano'
PAGER='less -EM'

export PS1 EDITOR PAGER

# Alias definitions.
#
alias df='df -h'
alias du='du -h'

alias ls='ls -p'
alias ll='ls -l'
alias la='ls -la'

# Avoid errors... use -f to skip confirmation.
alias rm='rm -i'
alias mv='mv -i'

umask 022
