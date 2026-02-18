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

source ~/.bashrc.aliases

# motd表示は関数にして起動後に呼ぶ
motd() {
    local art_width=80   # chafaの--sizeの横幅
    local text_col=50     # テキスト開始カラム（左から何文字目）
    local text_row=5      # テキスト開始行（上から何行目）
    
    cat ~/.motd_art

    # アートの先頭に戻る
    local art_lines
    art_lines=$(wc -l < ~/.motd_art)
    printf "\033[%dA" "$art_lines"  # アートの行数分カーソルを上へ

    # テキスト開始行まで下げる
    printf "\033[%dB" "$text_row"

    # 各行を指定カラムに出力
    local items=(
        "USER:||$USER"
        "HOST:||$(hostname)"
        "KERNEL:||$(uname -r)"
        "UPTIME:||$(uptime -p)"
        "MEMORY:||$(free -mh | awk '/Mem/{print $3"/"$2}')"
        "CPU:||$(awk '/cpu /{printf "%.1f%%", ($2+$4)*100/($2+$4+$5)}' /proc/stat)"
        "DISK:||$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')"
        "GPU:||$(lspci | grep -i vga | sed 's/.*: //'| tr '\n' ' '  | cut -c1-60)"
        "IP:||$(ip -4 addr show | awk '/inet.*scope global/{print $2; exit}')"
        "DATE:||$(date '+%Y-%m-%d %H:%M')"
        "TODO:||$(head -1 ~/.todo 2>/dev/null || echo 'Nothing!')"
        "QUOTE:||$(fortune -s -n 80 2>/dev/null | tr '\n' ' ' | cut -c1-60 || echo 'Stay curious.')"
    )
    # バッテリーがあれば追加
    if [ -d /sys/class/power_supply/BAT0 ]; then
        local bat_cap=$(cat /sys/class/power_supply/BAT0/capacity)
        local bat_status=$(cat /sys/class/power_supply/BAT0/status)
        items+=("BATTERY:||${bat_cap}% (${bat_status})")
    fi
    for item in "${items[@]}"; do
        local label="${item%%||*}"
        local value="${item##*||}"
        printf "\033[%dG\033[35m%-12s\033[0m %s\n" "$text_col" "$label" "$value"
    done

    # カーソルをアートの下まで戻す
    local remaining=$((art_lines - text_row - ${#items[@]}))
    if [ "$remaining" -gt 0 ]; then
        printf "\033[%dB" "$remaining"
    fi
}
motd

# ghq + fzf でリポジトリにジャンプ
ghq-fzf() {
    local dir=$(ghq list -p | fzf --query "$1")
    if [ -n "$dir" ]; then
        cd "$dir"
    fi
}
bind '"\C-]": "\C-a\C-k ghq-fzf\n"'

# starship
eval "$(starship init bash)"
