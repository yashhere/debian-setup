setup_dotfiles() {
    # Get the directory of the current script
    SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

    # Get the parent directory
    PARENT_DIR=$(dirname "$SCRIPT_DIR")

    # Directory containing the dotfiles
    DOTFILES_DIR="${PARENT_DIR}/configs"

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