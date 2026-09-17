#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

case "$OSTYPE" in
    darwin*) alias ls='ls -G' ;;
    *)       alias ls='ls --color=auto' ;;
esac
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

case "$OSTYPE" in
    linux*)
        # Remove inherited Homebrew search paths after migration to pacman.
        for _path_var in PATH MANPATH INFOPATH XDG_DATA_DIRS PKG_CONFIG_PATH; do
            declare -p "$_path_var" >/dev/null 2>&1 || continue
            IFS=: read -r -a _path_parts <<< "${!_path_var}"
            _path_clean=()
            for _path_part in "${_path_parts[@]}"; do
                case "$_path_part" in /home/linuxbrew/.linuxbrew|/home/linuxbrew/.linuxbrew/*) continue ;; esac
                _path_clean+=("$_path_part")
            done
            printf -v "$_path_var" '%s' "$(IFS=:; printf '%s' "${_path_clean[*]}")"
            export "${_path_var?}"
        done
        unset _path_var _path_parts _path_part _path_clean
        unset HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY
        ;;
esac

# PATH を reload のたびに重複させない。
_path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) export PATH="$1${PATH:+:$PATH}" ;;
    esac
}

# Homebrew は macOS 用。Linux では pacman への移行設定を維持する。
_bashrc_brew() {
    case "$OSTYPE" in linux*) return 0 ;; esac
    local brew_bin
    if [[ -n ${HOMEBREW_PREFIX:-} && -n ${HOMEBREW_CELLAR:-} \
        && :$PATH: == *":$HOMEBREW_PREFIX/bin:"* \
        && :$PATH: == *":$HOMEBREW_PREFIX/sbin:"* ]]; then
        return 0
    fi
    brew_bin=$(command -v brew 2>/dev/null) || brew_bin=''
    if [ -z "$brew_bin" ]; then
        case "$OSTYPE" in
            darwin*)
                for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
                    [ -x "$brew_bin" ] && break
                done
                ;;
            linux*) brew_bin=/home/linuxbrew/.linuxbrew/bin/brew ;;
        esac
    fi
    [ -x "$brew_bin" ] && eval "$("$brew_bin" shellenv bash)"
    return 0
}
_bashrc_brew
unset -f _bashrc_brew
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
_path_prepend "${CARGO_HOME:-$HOME/.cargo}/bin"
_path_prepend "$HOME/.local/bin"

# nvm: ユーザーのインストールを優先し、Homebrew はフォールバックにする。
# reload 時も読み込み済みなら再実行しない。
_bashrc_load_nvm() {
    if [[ $OSTYPE == linux* ]]; then
        NVM_DIR="$HOME/.nvm"
    elif [ -z "${NVM_DIR:-}" ]; then
        NVM_DIR="$HOME/.nvm"
        [ -n "${XDG_CONFIG_HOME:-}" ] && NVM_DIR="$XDG_CONFIG_HOME/nvm"
    fi
    export NVM_DIR
    declare -F nvm >/dev/null && return

    local dir script
    local dirs=("$NVM_DIR")
    case "$OSTYPE" in
        linux*) dirs=(/usr/share/nvm "$NVM_DIR") ;;
        darwin*) dirs+=("${HOMEBREW_PREFIX:-/opt/homebrew}/opt/nvm" /usr/local/opt/nvm) ;;
    esac
    for dir in "${dirs[@]}"; do
        # Arch の nvm パッケージは初期化と補完をこのスクリプトで行う。
        if [ -s "$dir/init-nvm.sh" ]; then
            source "$dir/init-nvm.sh"
            return
        fi
        if [ -s "$dir/nvm.sh" ]; then
            source "$dir/nvm.sh"
            break
        fi
    done
    declare -F nvm >/dev/null || return 0
    for dir in "${dirs[@]}"; do
        for script in "$dir/bash_completion" "$dir/etc/bash_completion.d/nvm"; do
            if [ -s "$script" ]; then
                source "$script"
                return
            fi
        done
    done
}
_bashrc_load_nvm
unset -f _bashrc_load_nvm

# Activate the retained Python 3.14 ML environment when needed.
ml-python() { source "$HOME/.local/share/venvs/ml-py314/bin/activate"; }

# MOTD の TODO 欄が読む ~/.todo を操作する。
# 引数なしで一覧、引数ありで1行追加、-d で先頭行（MOTD に出る行）を削除。
todo() {
    local file="$HOME/.todo"
    case ${1-} in
        '')
            [ -s "$file" ] && cat -- "$file" || echo 'Nothing!'
            ;;
        -d)
            [ -s "$file" ] && sed -i.bak '1d' -- "$file" && rm -f -- "$file.bak"
            ;;
        *)
            printf '%s\n' "$*" >> "$file"
            ;;
    esac
}

# history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth  # ignoredups + ignorespace
HISTTIMEFORMAT="%F %T  "
shopt -s histappend checkwinsize

[ -r "$HOME/.bashrc.aliases" ] && source "$HOME/.bashrc.aliases"

# Arch と Homebrew の bash-completion。fzf より先に読み込む。
if ! declare -F _completion_loader >/dev/null; then
    if ((BASH_VERSINFO[0] >= 4)); then
        _completion_files=("${HOMEBREW_PREFIX:-/nonexistent}/etc/profile.d/bash_completion.sh"
            /usr/share/bash-completion/bash_completion)
    else
        _completion_files=("${HOMEBREW_PREFIX:-/nonexistent}/etc/bash_completion")
    fi
    for _completion in "${_completion_files[@]}"; do
        if [ -r "$_completion" ]; then
            source "$_completion"
            break
        fi
    done
    unset _completion _completion_files
fi

# --- MOTD: OS 別ヘルパー関数 ---

get_uptime() {
    case "$OSTYPE" in
        linux*)  uptime -p ;;
        darwin*) LC_ALL=C uptime | sed -E 's/^.* up[[:space:]]+//; s/,[[:space:]]*[0-9]+ users?.*$//' ;;
    esac
}

get_memory() {
    case "$OSTYPE" in
        linux*)  LC_ALL=C free -h | awk '/^Mem:/{print $3"/"$2}' ;;
        darwin*)
            local total used
            total=$(sysctl -n hw.memsize) || return
            # Apple Silicon は16KiBページ。vm_stat のヘッダから実際のサイズを読む。
            used=$(LC_ALL=C vm_stat | awk '
                NR == 1 && match($0, /[0-9]+ bytes/) {size=substr($0, RSTART, RLENGTH)+0}
                /^Pages active:|^Pages wired down:/ {sum+=$NF}
                END {if (size > 0) printf "%.0f", sum*size; else exit 1}
            ') || return
            printf "%dMi/%dMi" $((used/1024/1024)) $((total/1024/1024))
            ;;
    esac
}

get_cpu() {
    case "$OSTYPE" in
        linux*)
            # 起動以来の平均ではなく、短い区間の差分を使う。
            local before
            IFS= read -r before < /proc/stat || return
            sleep 0.1
            LC_ALL=C awk -v before="$before" '
                BEGIN {split(before, prev)}
                /^cpu / {
                    # guest / guest_nice は user / nice に含まれるため二重加算しない。
                    for (i=2; i<=9; i++) {
                        delta=$i-prev[i]
                        if (delta < 0) delta=0
                        total+=delta
                        if (i != 5 && i != 6) busy+=delta
                    }
                    if (total > 0) printf "%.1f%%\n", busy*100/total
                    else print "N/A"
                    exit
                }
            ' /proc/stat
            ;;
        darwin*)
            # top の全プロセス走査を避け、1秒間の CPU 統計だけを取得する。
            # 1回目は起動以来の平均なので捨て、2回目の idle から使用率を求める。
            LC_ALL=C iostat -d -C -n 0 -c 2 -w 1 2>/dev/null |
                awk 'NF == 3 && $1 ~ /^[0-9]+$/ {idle=$3; samples++}
                     END {if (samples >= 2) printf "%.0f%%\n", 100-idle
                          else print "N/A"}'
            ;;
    esac
}

get_gpu() {
    local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/motd-gpu-$OSTYPE"
    local gpu=''
    if [ "${1:-}" = --cached ]; then
        [ -r "$cache_file" ] && IFS= read -r gpu < "$cache_file"
    else
        gpu=$(case "$OSTYPE" in
            (linux*)
                command -v lspci >/dev/null 2>&1 && LC_ALL=C lspci |
                    awk -F': ' '/VGA compatible controller|3D controller|Display controller/ {printf "%s%s", sep, $2; sep=" / "}'
                ;;
            (darwin*) LC_ALL=C system_profiler SPDisplaysDataType | awk -F': ' '/Chipset Model|Chip/ {print $2; exit}' ;;
        esac)
        if [ -n "$gpu" ]; then
            # 保存できない環境でも表示は続ける。キャッシュは実行せず文字列として読む。
            (umask 077; mkdir -p -- "${cache_file%/*}" && printf '%s\n' "$gpu" > "$cache_file") 2>/dev/null
        fi
    fi
    printf '%s\n' "${gpu:--}"
}

get_ip() {
    case "$OSTYPE" in
        linux*)
            command -v ip >/dev/null 2>&1 || { printf 'N/A\n'; return; }
            ip -4 addr show | awk '/inet.*scope global/{print $2; exit}'
            ;;
        darwin*) ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "N/A" ;;
    esac
}

get_battery() {
    case "$OSTYPE" in
        linux*)
            local battery cap status type
            for battery in /sys/class/power_supply/*; do
                [ -r "$battery/type" ] && IFS= read -r type < "$battery/type" || continue
                [ "$type" = Battery ] || continue
                [ -r "$battery/capacity" ] && IFS= read -r cap < "$battery/capacity" || continue
                status=Unknown
                [ -r "$battery/status" ] && IFS= read -r status < "$battery/status"
                printf '%s%% (%s)\n' "$cap" "$status"
                return
            done
            ;;
        darwin*)
            pmset -g batt 2>/dev/null | awk -F'\t' 'NR==2 {print $2}' | sed 's/;.*//'
            ;;
    esac
}

# --- MOTD 表示 ---

# 表示幅 (全角を 2 桁として数える) を REPLY に返す
_motd_dwidth() {
    local s=$1 w=0 i cp byte count j
    # Bash 3.2 の printf は Unicode のコードポイントではなく先頭バイトを返す。
    # UTF-8 をバイト単位で読むことで Bash のバージョンによる差をなくす。
    local LC_ALL=C
    # [:ascii:] は macOS 標準 Bash では使えないため文字範囲で判定する。
    if [[ $s != *[!$'\001'-$'\177']* ]]; then
        REPLY=${#s}
        return
    fi
    for ((i = 0; i < ${#s}; i++)); do
        printf -v cp '%d' "'${s:i:1}"
        ((cp &= 255))
        count=0
        if ((cp >= 0xc2 && cp <= 0xdf)); then
            count=1; ((cp &= 0x1f))
        elif ((cp >= 0xe0 && cp <= 0xef)); then
            count=2; ((cp &= 0x0f))
        elif ((cp >= 0xf0 && cp <= 0xf4)); then
            count=3; ((cp &= 0x07))
        fi
        for ((j = 0; j < count && i + 1 < ${#s}; j++)); do
            ((i += 1))
            printf -v byte '%d' "'${s:i:1}"
            ((cp = (cp << 6) | (byte & 0x3f)))
        done
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

# $1 を表示幅 $2 で折り返し、行末を空白で埋めて MOTD_LINES に入れる
# タブ・改行・連続空白は潰すので fortune の整形済みテキストでも崩れない
_motd_wrap() {
    local text=$1 width=$2
    local -a words
    local word line='' lw=0 ww i c cw n padded

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
        # macOS 標準の Bash 3.2 は printf -v で配列要素へ代入できない。
        printf -v padded '%s%*s' "${MOTD_LINES[n]}" "$((width - REPLY))" ''
        MOTD_LINES[n]=$padded
    done
}

motd() {
    # 起動時も使用量を表示する。--brief は GPU の再検出だけを省く。
    local brief=0
    case "${1:-}" in
        --brief) brief=1 ;;
        '') ;;
        *) printf 'usage: motd [--brief]\n' >&2; return 2 ;;
    esac

    # 左のアートに40列、右の情報欄に40列を使う。
    local text_col=41
    local box_width=40
    local label_width=8
    local value_width=$((box_width - label_width - 5))

    # 配色は .motd_art のキャラの差し色から (緑=#70c5c4 / 赤=#ea438d)
    local border=$'\033[38;2;112;197;196m'
    local label_col=$'\033[38;2;234;67;141m'
    local reset=$'\033[0m'

    local cols=${COLUMNS:-80} art_lines=0 compact=1
    local _tty_rows tty_cols art_line
    local art=()
    # SSH の起動直後も、環境変数より PTY の実際の幅を優先する。
    if [[ -t 1 ]]; then
        read -r _tty_rows tty_cols < <(stty size 2>/dev/null)
        [[ $tty_cols =~ ^[1-9][0-9]*$ ]] && cols=$tty_cols
    fi
    [[ $cols =~ ^[0-9]+$ ]] || cols=80
    [ "$cols" -ge 2 ] || return 0
    if [[ -t 1 && ${TERM:-dumb} != dumb && $cols -ge 80 && -r "$HOME/.motd_art" ]]; then
        while IFS= read -r art_line || [[ -n $art_line ]]; do
            art+=("$art_line")
        done < "$HOME/.motd_art"
        art_lines=${#art[@]}
        if ((art_lines >= 3)); then
            compact=0
        fi
    fi

    local quote
    quote=$(fortune -s -n 120 2>/dev/null)
    [ -z "$quote" ] && quote='Stay curious.'

    local items=(
        "USER:||$USER"
        "HOST:||${HOSTNAME:-$(hostname)}"
        "KERNEL:||$(uname -r)"
        "UPTIME:||$(get_uptime)"
        "MEMORY:||$(get_memory)"
        "CPU:||$(get_cpu)"
        "DISK:||$(LC_ALL=C df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')"
        "IP:||$(get_ip)"
    )
    if ((brief)); then
        items+=("GPU:||$(get_gpu --cached)")
    else
        items+=("GPU:||$(get_gpu)")
    fi

    local battery
    battery=$(get_battery)
    [ -n "$battery" ] && items+=("BATTERY:||$battery")

    items+=(
        "DATE:||$(date '+%Y-%m-%d %H:%M')"
        "TODO:||$(head -1 ~/.todo 2>/dev/null || echo 'Nothing!')"
        "QUOTE:||$quote"
    )

    # 吹き出しの中身を value_width で折り返して組み立てる
    local body_label=() body_value=()
    local item label value line first

    # 横幅が足りないペイン、アートなし、リダイレクト時はテキスト表示。
    if ((compact)); then
        for item in "${items[@]}"; do
            label="${item%%||*}"
            value="${item#*||}"
            _motd_wrap "$label ${value:--}" "$cols"
            printf '%s\n' "${MOTD_LINES[@]}"
        done
        return 0
    fi

    local max_body=$((art_lines - 2))
    for item in "${items[@]}"; do
        label="${item%%||*}"
        value="${item#*||}"
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
    # 吹き出しを中央配置から5行上にずらす。
    local start_row=$(((art_lines - box_height) / 2 - 5))
    [ "$start_row" -lt 0 ] && start_row=0

    # しっぽはキャラの顔の高さ (アート 10 行目付近) に合わせる
    local tail_row=$((10 - start_row - 1))
    [ "$tail_row" -lt 0 ] && tail_row=0
    [ "$tail_row" -ge "$body_lines" ] && tail_row=$((body_lines - 1))

    local hline
    hline=$(printf '─%.0s' $(seq 1 $((box_width - 2))))

    # アートと情報欄を1行ずつ出力する。画面を上に戻さないので、
    # SSH の24行端末などでも上端に重ね描きせずスクロールできる。
    local row i
    for ((row = 0; row < art_lines; row++)); do
        printf '%s%s' "${art[row]}" "$reset"
        i=$((row - start_row - 1))
        if ((row == start_row)); then
            printf "\033[%dG%s╭%s╮%s" "$text_col" "$border" "$hline" "$reset"
        elif ((i >= 0 && i < body_lines)); then
            if ((i == tail_row)); then
                printf "\033[%dG%s◥│%s" "$((text_col - 1))" "$border" "$reset"
            else
                printf "\033[%dG%s│%s" "$text_col" "$border" "$reset"
            fi
            printf " %s%-*s%s %s %s│%s" \
                "$label_col" "$label_width" "${body_label[i]}" "$reset" \
                "${body_value[i]}" "$border" "$reset"
        elif ((i == body_lines)); then
            printf "\033[%dG%s╰%s╯%s" "$text_col" "$border" "$hline" "$reset"
        fi
        printf '\n'
    done
    return 0
}
# パイプやコマンド置換には起動メッセージを混ぜない。
[[ -t 1 ]] && motd --brief

# fzf: Ctrl+T でパス挿入、Alt+C で移動、Ctrl+R で履歴検索。
if command -v fzf >/dev/null 2>&1; then
    export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS---height=40% --layout=reverse --border}"
    if _fzf_init=$(fzf --bash 2>/dev/null); then
        eval "$_fzf_init"
    else
        # --bash がない旧版もディストリ同梱の連携スクリプトで使える。
        for _fzf_dir in /usr/share/fzf "${HOMEBREW_PREFIX:-/nonexistent}/opt/fzf/shell" "$HOME/.fzf/shell"; do
            if [ -r "$_fzf_dir/key-bindings.bash" ]; then
                source "$_fzf_dir/key-bindings.bash"
                [ -r "$_fzf_dir/completion.bash" ] && source "$_fzf_dir/completion.bash"
                break
            fi
        done
    fi
    unset _fzf_init _fzf_dir
fi

# ghq + fzf でリポジトリにジャンプ
ghq-fzf() {
    local dir
    command -v ghq >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1 || {
        printf 'ghq と fzf をインストールしてください。\n' >&2
        return 127
    }
    dir=$(ghq list -p | fzf --query "${1:-}") || return
    if [ -n "$dir" ]; then
        cd -- "$dir" || return
    fi
}
bind '"\C-]": "\C-a\C-k ghq-fzf\n"'

# Java / Android: 明示した設定を優先し、インストール済みのものだけ自動検出する。
_bashrc_dev_env() {
    local java_home sdk ndk ndk_version
    if [ -z "${JAVA_HOME:-}" ]; then
        case "$OSTYPE" in
            linux*)
                for java_home in /usr/lib/jvm/java-17-openjdk /usr/lib/jvm/default; do
                    [ -x "$java_home/bin/java" ] && export JAVA_HOME="$java_home" && break
                done
                ;;
            darwin*)
                if java_home=$(/usr/libexec/java_home -v 17 2>/dev/null) || java_home=$(/usr/libexec/java_home 2>/dev/null); then
                    export JAVA_HOME="$java_home"
                fi
                ;;
        esac
    fi
    if [ -z "${ANDROID_HOME:-}" ]; then
        for sdk in "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk" /opt/android-sdk; do
            [ -d "$sdk" ] && export ANDROID_HOME="$sdk" && break
        done
    fi
    if [ -n "${ANDROID_HOME:-}" ]; then
        [ -d "$ANDROID_HOME/platform-tools" ] && _path_prepend "$ANDROID_HOME/platform-tools"
        if [ -z "${ANDROID_NDK_HOME:-}" ]; then
            ndk_version=$(
                for ndk in "$ANDROID_HOME"/ndk/[0-9]*; do
                    [ -d "$ndk" ] && printf '%s\n' "${ndk##*/}"
                done | LC_ALL=C sort -t. -k1,1n -k2,2n -k3,3n | tail -1
            )
            if [ -n "$ndk_version" ]; then
                export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/$ndk_version"
            elif [ -d "$ANDROID_HOME/ndk-bundle" ]; then
                export ANDROID_NDK_HOME="$ANDROID_HOME/ndk-bundle"
            fi
        fi
    fi
    return 0
}
_bashrc_dev_env
unset -f _bashrc_dev_env

# starship
if command -v starship >/dev/null 2>&1; then
    export STARSHIP_CONFIG="${STARSHIP_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml}"
    eval "$(starship init bash)"
fi
# deno (未インストールの環境ではスキップ)
[ -f "$HOME/.deno/env" ] && . "$HOME/.deno/env"

# >>> grok installer >>>
_path_prepend "$HOME/.grok/bin"
[[ -r "$HOME/.grok/completions/bash/grok.bash" ]] && source "$HOME/.grok/completions/bash/grok.bash"
# <<< grok installer <<<

# opencode
_path_prepend "$HOME/.opencode/bin"

# --- AUR ビルド用の環境分離 ---------------------------------------
# pyenv の shim が makepkg 内の `python` を 3.11 に乗っ取ってしまい、
# python 系 AUR パッケージ (python-einops など) のビルドが失敗するため、
# AUR ビルド時だけ PATH から pyenv を外してシステム Python を使わせる。
# uv も同様に、管理版 Python をダウンロードせずシステム Python を使う。
_aur_build_env() {
    local p
    p=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vF "${PYENV_ROOT:-$HOME/.pyenv}" | paste -sd: -)
    env -u PYENV_VERSION -u PYENV_ROOT -u PKG_CONFIG_PATH \
        PATH="$p" \
        UV_PYTHON_PREFERENCE=only-system \
        UV_PYTHON_DOWNLOADS=never \
        "$@"
}
yay()     { _aur_build_env yay "$@"; }
makepkg() { _aur_build_env makepkg "$@"; }

# --- goose マルチモデル worker -------------------------------------
# ACP プロバイダ (claude-acp / codex-acp) 配下では goose 側の
# GOOSE_SUBAGENT_* が効かず、内蔵の委譲ではサブエージェントのモデルを
# リードと別にできない。そのため worker の分担は goose に任せず、
# レシピを CLI から直接叩いてモデルを明示的に切り替える。
GOOSE_RECIPES="${XDG_CONFIG_HOME:-$HOME/.config}/goose/recipes/plan-implement-review"

# 計画やレビュー指摘は複数行になるので、素の文字列に加えて
# '-' で stdin、'@path' でファイルからも渡せるようにする。
_goose_arg() {
    case "$1" in
        -)  cat ;;
        @*) cat -- "${1#@}" ;;
        *)  printf '%s' "$1" ;;
    esac
}

_goose_recipe() {
    local recipe=$1; shift
    goose run --no-session --max-turns "${GOOSE_WORKER_MAX_TURNS:-50}" \
        --recipe "$GOOSE_RECIPES/$recipe" "$@"
}

# 計画立案 (Fable): goose-plan <task|-|@file>
goose-plan() {
    [ $# -ge 1 ] || { echo "usage: goose-plan <task|-|@file>" >&2; return 2; }
    _goose_recipe planner_fable.yaml --params task="$(_goose_arg "$1")"
}

# 実装 (Sol / Opus): goose-impl <sol|opus> <plan|-|@file> [feedback|@file]
goose-impl() {
    local recipe
    case "$1" in
        sol)  recipe=implementer_sol.yaml ;;
        opus) recipe=implementer_opus.yaml ;;
        *)    echo "usage: goose-impl <sol|opus> <plan|-|@file> [feedback|@file]" >&2; return 2 ;;
    esac
    [ $# -ge 2 ] || { echo "usage: goose-impl <sol|opus> <plan|-|@file> [feedback|@file]" >&2; return 2; }
    _goose_recipe "$recipe" \
        --params plan="$(_goose_arg "$2")" \
        --params feedback="$(_goose_arg "${3:-なし}")"
}

# レビュー (Astra): goose-review <plan|-|@file> <report|-|@file>
goose-review() {
    [ $# -ge 2 ] || { echo "usage: goose-review <plan|-|@file> <report|-|@file>" >&2; return 2; }
    _goose_recipe reviewer.yaml \
        --params plan="$(_goose_arg "$1")" \
        --params implementation_report="$(_goose_arg "$2")"
}

# --- Go ------------------------------------------------------------
# go install の出力先。GOBIN と、複数指定された GOPATH の先頭にも対応する。
_bashrc_go_paths=''
if command -v go >/dev/null 2>&1; then
    _bashrc_go_paths=$(go env GOBIN GOPATH 2>/dev/null) || _bashrc_go_paths=''
fi
_bashrc_go_bin=${_bashrc_go_paths%%$'\n'*}
_bashrc_go_path=${_bashrc_go_paths#*$'\n'}
_bashrc_go_path=${_bashrc_go_path:-${GOPATH:-$HOME/go}}
_path_prepend "${_bashrc_go_bin:-${GOBIN:-${_bashrc_go_path%%:*}/bin}}"
unset _bashrc_go_paths _bashrc_go_bin _bashrc_go_path

# cgo で libmagic を使う Go 製ツール (pistol など) のビルド用。
# Homebrew の libmagic は keg-only で ${HOMEBREW_PREFIX}/include に
# リンクされないため、ヘッダとライブラリの場所を明示する必要がある。
# Arch は file パッケージがヘッダも標準パスに置くので不要。
case "$OSTYPE" in
    darwin*)
        _libmagic="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/libmagic"
        if [ -d "$_libmagic" ]; then
            case " ${CGO_CFLAGS:-} " in
                *" -I$_libmagic/include "*) ;;
                *) export CGO_CFLAGS="-I$_libmagic/include${CGO_CFLAGS:+ $CGO_CFLAGS}" ;;
            esac
            case " ${CGO_LDFLAGS:-} " in
                *" -L$_libmagic/lib "*) ;;
                *) export CGO_LDFLAGS="-L$_libmagic/lib${CGO_LDFLAGS:+ $CGO_LDFLAGS}" ;;
            esac
        fi
        unset _libmagic
        ;;
esac
