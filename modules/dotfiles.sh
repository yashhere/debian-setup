setup_dotfiles() {
    # Directory containing the dotfiles
    DOTFILES_DIR="$HOME/post-install/configs"

    # List of packages to stow
    local PACKAGES=(
        fish
        git
        vim
        aider
        aichat
        ssh
        nvim
        lsd
        stow
        superfile
        vim
        vscode
        xorg
    )

    # Loop through each package and stow it
    for package in "${PACKAGES[@]}"; do
        echo "Stowing $package..."
        stow -v --no-folding -d "$DOTFILES_DIR" -t ~ "$package"
        # stow -v -D -d "$DOTFILES_DIR" -t ~ "$package"
    done

    echo "Dotfiles stowed successfully!"
}