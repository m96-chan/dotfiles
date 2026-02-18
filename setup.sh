DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

ln -sf "$DOTFILES_DIR/.bashrc" ~/.bashrc
ln -sf "$DOTFILES_DIR/.bashrc.aliases" ~/.bashrc.aliases
ln -sf "$DOTFILES_DIR/.gitconfig.aliases" ~/.gitconfig.aliases
ln -sf "$DOTFILES_DIR/.motd_art" ~/.motd_art

mkdir -p ~/.config
ln -sf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml

mkdir -p ~/.config/kitty
ln -sf "$DOTFILES_DIR/.config/kitty/kitty.conf" ~/.config/kitty/kitty.conf

mkdir -p ~/.config/wtf
ln -sf "$DOTFILES_DIR/.config/wtf/config.yml" ~/.config/wtf/config.yml
