setup_dotfiles() {
    # Get the directory of the current script
    SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

    # Get the parent directory
    PARENT_DIR=$(dirname "$SCRIPT_DIR")

    # Directory containing the dotfiles
    DOTFILES_DIR="${PARENT_DIR}/configs"

    # Environment file paths
    SOURCE_ENV="${PARENT_DIR}/secrets/.env"
    TARGET_ENV="${HOME}/.env"

    # Handle .env file
    if [ -f "$SOURCE_ENV" ]; then
        cp "$SOURCE_ENV" "$TARGET_ENV" || {
            echo "Error copying .env file"
            return 1
        }
    else
        touch "$SOURCE_ENV" || {
            echo "Error creating .env file"
            return 1
        }
        echo "Created empty .env file at $SOURCE_ENV"
        cp "$SOURCE_ENV" "$TARGET_ENV"
    fi
    chmod 600 "$TARGET_ENV"

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
