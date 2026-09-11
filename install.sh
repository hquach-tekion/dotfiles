#!/bin/bash
set -e

DOTFILES="$HOME/dotfiles"
BACKUP="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

echo "Checking Homebrew"
if ! command -v brew &> /dev/null; then
  echo "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "Installing packages from Brewfile"
brew bundle --file="$DOTFILES/Brewfile"

link_file () {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$BACKUP"
    echo "Backing up existing $dst"
    mv "$dst" "$BACKUP/"
  fi
  ln -s "$src" "$dst"
  echo "Linked $dst"
}

link_file "$DOTFILES/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES/tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES/starship.toml" "$HOME/.config/starship.toml"
link_file "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"

echo "Done. Backups if any are in $BACKUP"
echo "Restart terminal to apply"
