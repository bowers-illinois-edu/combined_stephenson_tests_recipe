export PS1=" \h \#* \w/>"
umask 022
set nobeep

set history=2000          # History remembered is 2000
set savehist='(2000 merge)' # Save and merge with existing saved

alias ls='ls -vaFhG'
alias ll='ls -hl'

# General common aliases
#unalias rm
alias q=exit
alias ll='ls -l'
alias lf='ls -F'
alias la='ls -a'
alias l='ls -F'

alias kk='kill -9'
alias h=history
alias psf='ps -ef | grep $USER'
alias df='df -h'
alias du='du -h'
