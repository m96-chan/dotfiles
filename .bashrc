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
[ -f /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

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

# 表示幅 (全角を 2 桁として数える) を REPLY に返す
_motd_dwidth() {
    local s=$1 w=0 i cp
    if [[ $s != *[![:ascii:]]* ]]; then
        REPLY=${#s}
        return
    fi
    for ((i = 0; i < ${#s}; i++)); do
        printf -v cp '%d' "'${s:i:1}"
        if ((cp >= 0x1100 && (cp <= 0x115f \
            || (cp >= 0x2e80 && cp <= 0x303e) \
            || (cp >= 0x3041 && cp <= 0x33ff) \
            || (cp >= 0x3400 && cp <= 0x4dbf) \
            || (cp >= 0x4e00 && cp <= 0x9fff) \
            || (cp >= 0xa000 && cp <= 0xa4cf) \
            || (cp >= 0xac00 && cp <= 0xd7a3) \
            || (cp >= 0xf900 && cp <= 0xfaff) \
            || (cp >= 0xfe30 && cp <= 0xfe6f) \
            || (cp >= 0xff00 && cp <= 0xff60) \
            || (cp >= 0xffe0 && cp <= 0xffe6) \
            || (cp >= 0x1f300 && cp <= 0x1faff) \
            || (cp >= 0x20000 && cp <= 0x3fffd)))); then
            ((w += 2))
        else
            ((w += 1))
        fi
    done
    REPLY=$w
}

# $1 を表示幅 $2 で折り返し、各行を $2 桁ちょうどに右詰めして MOTD_LINES に入れる
# タブ・改行・連続空白は潰すので fortune の整形済みテキストでも崩れない
_motd_wrap() {
    local text=$1 width=$2
    local -a words
    local word line='' lw=0 ww i c cw n

    MOTD_LINES=()
    text=${text//[[:cntrl:]]/ }
    read -r -a words <<<"$text"

    for word in "${words[@]}"; do
        _motd_dwidth "$word"
        ww=$REPLY
        if ((ww > width)); then
            # 1 単語で幅を超えるものは文字単位で分割する
            if ((lw > 0)); then
                MOTD_LINES+=("$line")
                line=''
                lw=0
            fi
            for ((i = 0; i < ${#word}; i++)); do
                c=${word:i:1}
                _motd_dwidth "$c"
                cw=$REPLY
                if ((lw + cw > width)); then
                    MOTD_LINES+=("$line")
                    line=''
                    lw=0
                fi
                line+=$c
                ((lw += cw))
            done
        elif ((lw == 0)); then
            line=$word
            lw=$ww
        elif ((lw + 1 + ww <= width)); then
            line+=" $word"
            ((lw += 1 + ww))
        else
            MOTD_LINES+=("$line")
            line=$word
            lw=$ww
        fi
    done
    if ((lw > 0 || ${#MOTD_LINES[@]} == 0)); then
        MOTD_LINES+=("$line")
    fi

    for ((n = 0; n < ${#MOTD_LINES[@]}; n++)); do
        _motd_dwidth "${MOTD_LINES[n]}"
        printf -v "MOTD_LINES[$n]" '%s%*s' "${MOTD_LINES[n]}" "$((width - REPLY))" ''
    done
}

motd() {
    local text_col=42
    local box_width=64
    local label_width=12
    local value_width=$((box_width - 17))

    # 配色は .motd_art のキャラの差し色から (緑=#70c5c4 / 赤=#ea438d)
    local border=$'\033[38;2;112;197;196m'
    local label_col=$'\033[38;2;234;67;141m'
    local reset=$'\033[0m'

    cat ~/.motd_art

    local art_lines
    art_lines=$(wc -l < ~/.motd_art)

    local quote
    quote=$(fortune -s -n 120 2>/dev/null)
    [ -z "$quote" ] && quote='Stay curious.'

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
        "QUOTE:||$quote"
    )

    local battery
    battery=$(get_battery)
    if [ -n "$battery" ]; then
        items+=("BATTERY:||$battery")
    fi

    # 吹き出しの中身を value_width で折り返して組み立てる
    local body_label=() body_value=()
    local item label value line first
    local max_body=$((art_lines - 2))
    for item in "${items[@]}"; do
        label="${item%%||*}"
        value="${item##*||}"
        [ -z "$value" ] && value="-"
        _motd_wrap "$value" "$value_width"
        first=1
        for line in "${MOTD_LINES[@]}"; do
            ((${#body_value[@]} >= max_body)) && break 2
            if [ "$first" -eq 1 ]; then
                body_label+=("$label")
                first=0
            else
                body_label+=("")
            fi
            body_value+=("$line")
        done
    done

    local body_lines=${#body_value[@]}
    local box_height=$((body_lines + 2))
    local start_row=$(((art_lines - box_height) / 2))
    [ "$start_row" -lt 0 ] && start_row=0

    # しっぽはキャラの顔の高さ (アート 10 行目付近) に合わせる
    local tail_row=$((10 - start_row - 1))
    [ "$tail_row" -lt 0 ] && tail_row=0
    [ "$tail_row" -ge "$body_lines" ] && tail_row=$((body_lines - 1))

    local hline
    hline=$(printf '─%.0s' $(seq 1 $((box_width - 2))))

    printf "\033[%dA" "$art_lines"
    [ "$start_row" -gt 0 ] && printf "\033[%dB" "$start_row"

    printf "\033[%dG%s╭%s╮%s\n" "$text_col" "$border" "$hline" "$reset"

    local i
    for ((i = 0; i < body_lines; i++)); do
        if [ "$i" -eq "$tail_row" ]; then
            printf "\033[%dG%s◥│%s" "$((text_col - 1))" "$border" "$reset"
        else
            printf "\033[%dG%s│%s" "$text_col" "$border" "$reset"
        fi
        printf " %s%-*s%s %s %s│%s\n" \
            "$label_col" "$label_width" "${body_label[i]}" "$reset" \
            "${body_value[i]}" "$border" "$reset"
    done

    printf "\033[%dG%s╰%s╯%s\n" "$text_col" "$border" "$hline" "$reset"

    local remaining=$((art_lines - start_row - box_height))
    [ "$remaining" -gt 0 ] && printf "\033[%dB" "$remaining"
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

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/29.0.14206865
export PATH=$PATH:$ANDROID_HOME/platform-tools

# starship
eval "$(starship init bash)"
# deno (未インストールの環境ではスキップ)
[ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"
