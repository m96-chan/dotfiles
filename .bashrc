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

# --- MOTD: OS 別ヘルパー関数 ---

get_uptime() {
    case "$OSTYPE" in
        linux*)  uptime -p ;;
        darwin*) uptime | sed 's/.*up //' | sed 's/,\s*[0-9]* user.*//' | xargs ;;
    esac
}

get_memory() {
    case "$OSTYPE" in
        linux*)  free -mh | awk '/Mem/{print $3"/"$2}' ;;
        darwin*)
            local total=$(sysctl -n hw.memsize)
            local used=$(vm_stat | awk '/Pages active|Pages wired/ {sum+=$NF} END {printf "%d", sum*4096}')
            printf "%dMi/%dMi" $((used/1024/1024)) $((total/1024/1024))
            ;;
    esac
}

get_cpu() {
    case "$OSTYPE" in
        linux*)  awk '/cpu /{printf "%.1f%%", ($2+$4)*100/($2+$4+$5)}' /proc/stat ;;
        darwin*) top -l 1 -n 0 | awk '/CPU usage/ {print $3}' ;;
    esac
}

get_gpu() {
    case "$OSTYPE" in
        linux*)  lspci | grep -i vga | sed 's/.*: //' | tr '\n' ' ' | cut -c1-60 ;;
        darwin*) system_profiler SPDisplaysDataType | awk -F': ' '/Chipset Model|Chip/ {print $2; exit}' ;;
    esac
}

get_ip() {
    case "$OSTYPE" in
        linux*)  ip -4 addr show | awk '/inet.*scope global/{print $2; exit}' ;;
        darwin*) ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "N/A" ;;
    esac
}

get_battery() {
    case "$OSTYPE" in
        linux*)
            if [ -d /sys/class/power_supply/BAT0 ]; then
                local cap=$(cat /sys/class/power_supply/BAT0/capacity)
                local status=$(cat /sys/class/power_supply/BAT0/status)
                echo "${cap}% (${status})"
            fi
            ;;
        darwin*)
            pmset -g batt 2>/dev/null | awk -F'\t' 'NR==2 {print $2}' | sed 's/;.*//'
            ;;
    esac
}

# --- MOTD 表示 ---

motd() {
    local text_col=50
    local text_row=5

    cat ~/.motd_art

    local art_lines
    art_lines=$(wc -l < ~/.motd_art)
    printf "\033[%dA" "$art_lines"
    printf "\033[%dB" "$text_row"

    local items=(
        "USER:||$USER"
        "HOST:||$(hostname)"
        "KERNEL:||$(uname -r)"
        "UPTIME:||$(get_uptime)"
        "MEMORY:||$(get_memory)"
        "CPU:||$(get_cpu)"
        "DISK:||$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')"
        "GPU:||$(get_gpu)"
        "IP:||$(get_ip)"
        "DATE:||$(date '+%Y-%m-%d %H:%M')"
        "TODO:||$(head -1 ~/.todo 2>/dev/null || echo 'Nothing!')"
        "QUOTE:||$(fortune -s -n 80 2>/dev/null | tr '\n' ' ' | cut -c1-60 || echo 'Stay curious.')"
    )

    local battery
    battery=$(get_battery)
    if [ -n "$battery" ]; then
        items+=("BATTERY:||$battery")
    fi

    for item in "${items[@]}"; do
        local label="${item%%||*}"
        local value="${item##*||}"
        printf "\033[%dG\033[35m%-12s\033[0m %s\n" "$text_col" "$label" "$value"
    done

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
