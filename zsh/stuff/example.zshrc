# history
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=1000
setopt appendhistory autocd extendedglob
setopt EXTENDED_HISTORY		# puts timestamps in the history

# default apps
  (( ${+BROWSER} )) || export BROWSER="w3m"
  (( ${+PAGER} ))   || export PAGER="less"

BLACK="%{"$'\033[01;30m'"%}"
GREEN="%{"$'\033[01;32m'"%}"
RED="%{"$'\033[01;31m'"%}"
YELLOW="%{"$'\033[01;33m'"%}"
BLUE="%{"$'\033[01;34m'"%}"
BOLD="%{"$'\033[01;39m'"%}"
NORM="%{"$'\033[00m'"%}"


# prompt (if running screen, show window #)
if [ x$WINDOW != x ]; then
    export PS1="$WINDOW:%~%# "
else
    export PS1="[${RED}%n${YELLOW}@${BLUE}%U%m%u$:${GREEN}%2c${NORM}]%(!.#.$) "
    #right prompt - time/date stamp
    export RPS1="${GREEN}(%D{%m-%d %H:%M})${NORM}"
fi

# format titles for screen and rxvt
function title() {
  # escape '%' chars in $1, make nonprintables visible
  a=${(V)1//\%/\%\%}

  # Truncate command, and join lines.
  a=$(print -Pn "%40>...>$a" | tr -d "\n")

  case $TERM in
  screen)
    print -Pn "\ek$a:$3\e\\"      # screen title (in ^A")
    ;;
  xterm*|rxvt)
    print -Pn "\e]2;$2 | $a:$3\a" # plain xterm title
    ;;
  esac
}

# precmd is called just before the prompt is printed
function precmd() {
  title "zsh" "$USER@%m" "%55<...<%~"
}

# preexec is called just before any command line is executed
function preexec() {
  title "$1" "$USER@%m" "%35<...<%~"
}

# vi editing
bindkey -v

# colorful listings
zmodload -i zsh/complist
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

autoload -U compinit
compinit

# aliases
alias mv='nocorrect mv'       # no spelling correction on mv
alias cp='nocorrect cp'
alias mkdir='nocorrect mkdir'
alias j=jobs
if ls -F --color=auto >&/dev/null; then
  alias ls="ls --color=auto -F"
else
  alias ls="ls -F"
fi
alias ll="ls -l"
alias ..='cd ..'
alias .='pwd'

# functions
setenv() { export $1=$2 }  # csh compatibility

#bash style ctrl-a (beginning of line) and ctrl-e (end of line)
bindkey '^a' beginning-of-line
bindkey '^e' end-of-line

# Emulate tcsh's backward-delete-word
tcsh-backward-delete-word () {
    #local WORDCHARS="${WORDCHARS:s#/#}"
    local WORDCHARS='*?_[]~\!#$%^<>|`@#$%^*()+?'
    zle backward-delete-word
}

zle -N tcsh-backward-delete-word

bindkey '\e^H' tcsh-backward-delete-word

#if this is uncommented, it will ignore the stop-at-special-chars
#bindkey '\e^H' backward-delete-word

#uncomment this to have a nice update script that will cause ur zshrc to update from a central location

#selfupdate(){
#        URL="http://stuff.mit.edu/~jdong/misc/zshrc"
#        echo "Updating zshrc from $URL..."
#        echo "Press Ctrl+C within 5 seconds to abort..."
#        sleep 5
#        cp ~/.zshrc ~/.zshrc.old
#        wget $URL -O ~/.zshrc
#        echo "Done; existing .zshrc saved as .zshrc.old"
#}
