#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" ] && \. "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# brew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
export PATH="$HOME/.local/bin:$PATH"
. "$HOME/.cargo/env"

# Kitty
export KITTY_ENABLE_WAYLAND=1

# history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth  # ignoredups + ignorespace
HISTTIMEFORMAT="%F %T  "
shopt -s histappend

# alias
# Move to the parent folder.
alias ..='cd ..'
# Move up two parent folders.
alias ...='cd ../../'
# Move up three parent folders.
alias ~='cd ~'

alias g='git'
alias g='git'
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline -20'

alias reload='source ~/.bashrc'
alias h='history | grep'
alias cls='clear'

# motd表示は関数にして起動後に呼ぶ
motd() {
    printf "\n"
    printf " %s\n" "USER: $USER"
    printf " %s\n" "DATE: $(date)"
    printf " %s\n" "UPTIME: $(uptime -p)"
    printf " %s\n" "HOSTNAME: $(hostname -f)"
    printf " %s\n" "CPU: $(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo)"
    printf " %s\n" "KERNEL: $(uname -rms)"
    printf " %s\n" "MEMORY: $(free -mh | awk '/Mem/{print $3"/"$2}')"
    printf "\n"
}
motd

# starship
eval "$(starship init bash)"
