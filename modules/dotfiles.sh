setup_dotfiles() {
    # Get the directory of the current script
    SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

    # Get the parent directory
    PARENT_DIR=$(dirname "$SCRIPT_DIR")

    # Directory containing the dotfiles
    DOTFILES_DIR="${PARENT_DIR}/configs"

    # Get all directories in DOTFILES_DIR
    PACKAGES=($(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))

    # Loop through each package and stow it
    for package in "${PACKAGES[@]}"; do
        echo "Stowing $package..."
        stow -v --no-folding -d "$DOTFILES_DIR" -t ~ "$package"
        # stow -v -D -d "$DOTFILES_DIR" -t ~ "$package"
    done

    echo "Dotfiles stowed successfully!"
}