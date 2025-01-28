#!/bin/bash

set -euo pipefail

# Function to install and enable extension
install_extension() {
    local repo_url="$1"
    local ext_id="$2"

    echo "Installing $ext_id..."

    git clone "$repo_url" "$EXTENSIONS_DIR/$ext_id" 2>/dev/null || {
        echo "Extension already exists, skipping clone..."
    }

    if gnome-extensions enable "$ext_id"; then
        echo "Successfully enabled $ext_id"
        return 0
    else
        echo "Failed to enable $ext_id"
        return 1
    fi
}

setup_gnome() {
    gsettings set org.gnome.shell disable-extension-version-validation true

    # declare -A extensions=(

    # )

    # Add more as: ["extension_id"]="repo_url"
    declare -A extensions=(
        ["clipboard-indicator@tudmotu.com"]="https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git"
        ["dash-to-dock"]="https://github.com/micheleg/dash-to-dock.git"
        ["just-perfection"]=" https://gitlab.gnome.org/jrahmatzadeh/just-perfection"
        ["blur-my-shell"]="https://github.com/aunetx/blur-my-shell"
        ["gnome-ui-tune"]="https://github.com/axxapy/gnome-ui-tune"
        ["media-controls"]="https://github.com/cliffniff/media-controls"
        ["vitals"]="https://github.com/corecoding/Vitals"
        ["gnome-compact-top-bar"]="https://github.com/metehan-arslan/gnome-compact-top-bar"
        ["rounded-window-corners"]="https://github.com/flexagoon/rounded-window-corners"
    )

    # Set extensions directory
    EXTENSIONS_DIR="${HOME}/.local/share/gnome-shell/extensions"

    # Create extensions directory if it doesn't exist
    mkdir -p "$EXTENSIONS_DIR"

    for ext_id in "${!extensions[@]}"; do
        install_extension "${extensions[$ext_id]}" "$ext_id"
    done

    echo "Log out and log back in to complete installation"
}