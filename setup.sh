#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# -n は GNU/BSD の両方で、ディレクトリへのリンクを辿らず置き換える。
# 通常ファイル・ディレクトリは一度だけ退避し、既存のバックアップは上書きしない。
link_dotfile() {
    local source=$1 target=$2
    mkdir -p -- "$(dirname "$target")"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        if [ -e "$target.dotfiles-backup" ] || [ -L "$target.dotfiles-backup" ]; then
            printf 'バックアップが既にあります: %s.dotfiles-backup\n' "$target" >&2
            return 1
        fi
        mv -- "$target" "$target.dotfiles-backup"
    fi
    ln -sfn -- "$source" "$target"
}

link_dotfile "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
link_dotfile "$DOTFILES_DIR/.bashrc.aliases" "$HOME/.bashrc.aliases"
link_dotfile "$DOTFILES_DIR/.gitconfig.aliases" "$HOME/.gitconfig.aliases"

# Git エイリアスを自動で読み込む。同じ include は重複登録しない。
if ! git config --global --path --get-all include.path |
    grep -Fxq "$HOME/.gitconfig.aliases"; then
    # Git 自身に ~ を展開させる。
    # shellcheck disable=SC2088
    git config --global --add include.path '~/.gitconfig.aliases'
fi

link_dotfile "$DOTFILES_DIR/.motd_art" "$HOME/.motd_art"

link_dotfile "$DOTFILES_DIR/.config/starship.toml" "$DOTFILES_CONFIG_DIR/starship.toml"

link_dotfile "$DOTFILES_DIR/.config/kitty/kitty.conf" "$DOTFILES_CONFIG_DIR/kitty/kitty.conf"

link_dotfile "$DOTFILES_DIR/.config/wtf/config.yml" "$DOTFILES_CONFIG_DIR/wtf/config.yml"

link_dotfile "$DOTFILES_DIR/.config/goose/config.yaml" "$DOTFILES_CONFIG_DIR/goose/config.yaml"
link_dotfile "$DOTFILES_DIR/.config/goose/recipes" "$DOTFILES_CONFIG_DIR/goose/recipes"

link_dotfile "$DOTFILES_DIR/.config/pistol/pistol.conf" "$DOTFILES_CONFIG_DIR/pistol/pistol.conf"
