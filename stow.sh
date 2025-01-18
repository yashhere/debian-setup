#!/bin/sh

# Directory containing the dotfiles
DOTFILES_DIR="$HOME/dotfiles"

# List of packages to stow
PACKAGES="fish git vim aider ssh"

# Loop through each package and stow it
for package in $PACKAGES; do
    echo "Stowing $package..."
    stow -v -t ~ "$package"
done

echo "Dotfiles stowed successfully!"
