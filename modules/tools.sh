#!/usr/bin/env bash

# Tool versions and configs
ASDF_VERSION="v0.15.0"
NEOVIM_VERSION="0.9.4"

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
GITHUB_API_URL="https://api.github.com"
ARCH="${ARCH:-x86_64}"
OS="${OS:-linux}"

install_from_github() {
    local owner="$1"
    local repo="$2"
    local binary="$3"
    local version="${4:-latest}"
    local arch="${5:-x86_64}"

    [ -z "$owner" ] || [ -z "$repo" ] || [ -z "$binary" ] && {
        echo "Usage: install_from_github OWNER REPO BINARY [VERSION]"
        return 1
    }

    command -v jq >/dev/null 2>&1 || { echo "jq is required"; return 1; }
    mkdir -p "$INSTALL_DIR"

    local api_url="$GITHUB_API_URL/repos/$owner/$repo/releases"
    [ "$version" = "latest" ] && api_url="$api_url/latest" || api_url="$api_url/tags/$version"

    local release_data=$(curl -s "$api_url")
    [ $? -ne 0 ] && { echo "Failed to fetch release data"; return 1; }

    local download_url=$(echo "$release_data" | jq -r ".assets[] | select(.browser_download_url | contains(\"$arch\") and contains(\"$OS\")) | .browser_download_url" | head -n1)
    [ -z "$download_url" ] && { echo "No matching binary found"; return 1; }

    local temp_dir=$(mktemp -d)
    local archive="$temp_dir/archive"

    echo "Downloading from $download_url..."
    curl -L "$download_url" -o "$archive" || {
        rm -rf "$temp_dir"
        echo "Download failed"
        return 1
    }

    case "$download_url" in
        *.tar.gz|*.tgz)
            tar xzf "$archive" -C "$temp_dir"
            ;;
        *.tar)
            tar xf "$archive" -C "$temp_dir"
            ;;
        *.zip)
            unzip -q "$archive" -d "$temp_dir"
            ;;
        *)
            # Direct binary download
            mv "$archive" "$temp_dir/$binary"
            ;;
    esac

    # Find and move the binary
    if [ -f "$temp_dir/$binary" ]; then
        mv "$temp_dir/$binary" "$INSTALL_DIR/$binary"
    else
        find "$temp_dir" -type f -name "$binary" -exec mv {} "$INSTALL_DIR/$binary" \;
    fi

    [ -f "$INSTALL_DIR/$binary" ] || {
        echo "Binary not found in downloaded package"
        rm -rf "$temp_dir"
        return 1
    }

    chmod +x "$INSTALL_DIR/$binary"
    rm -rf "$temp_dir"
    echo "Installed $binary to $INSTALL_DIR/$binary"
}

install_from_url() {
    local url="$1"
    local binary="$2"

    [ -z "$url" ] || [ -z "$binary" ] && {
        echo "Usage: install_from_url URL BINARY"
        return 1
    }

    mkdir -p "$INSTALL_DIR"
    local temp_file=$(mktemp)

    curl -L "$url" -o "$temp_file" || { echo "Download failed"; rm "$temp_file"; return 1; }
    chmod +x "$temp_file"
    mv "$temp_file" "$INSTALL_DIR/$binary"
    echo "Installed $binary to $INSTALL_DIR/$binary"
}

verify_checksum() {
    local file="$1"
    local expected="$2"
    local algo="${3:-sha256}"

    case "$algo" in
        sha256) echo "$expected $file" | sha256sum -c ;;
        sha512) echo "$expected $file" | sha512sum -c ;;
        md5) echo "$expected $file" | md5sum -c ;;
        *) echo "Unsupported hash algorithm"; return 1 ;;
    esac
}

# Function to install Playwright via npm
install_playwright_npm() {
    echo "Installing Playwright via npm..."
    npm install -g playwright

    echo "Installing browsers for Playwright..."
    npx playwright install --with-deps chromium
}

# Function to install aider-chat
install_aider_chat() {
    if ! command -v aider &> /dev/null; then
        pip install aider-install
        aider-install
    else
        echo "aider-chat is already installed."
    fi

    if ! command -v playwright &> /dev/null; then
        install_playwright_npm
    fi
}

# Function to install danielmiessler/fabric
install_fabric() {
    if ! command -v fabric &> /dev/null; then
        install_from_github "danielmiessler" "fabric" "fabric" "latest" "amd64"
    fi
}

setup_asdf() {
    if ! command -v asdf &> /dev/null; then
        git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch ${ASDF_VERSION}

        # Fish config
        mkdir -p ~/.config/fish/conf.d
        cat > ~/.config/fish/conf.d/asdf.fish << 'EOF'
source ~/.asdf/asdf.fish
EOF

        # Initialize asdf completions
        mkdir -p ~/.config/fish/completions
        ln -sf ~/.asdf/completions/asdf.fish ~/.config/fish/completions

        # Execute fish commands directly
        fish -c 'source ~/.config/fish/conf.d/asdf.fish'
        fish -c 'asdf plugin add python'
        fish -c 'asdf install python latest'
        fish -c 'asdf global python latest'

        fish -c 'asdf plugin add nodejs'
        fish -c 'asdf install nodejs latest'
        fish -c 'asdf global nodejs latest'

        fish -c 'asdf plugin add golang'
        fish -c 'asdf install golang 1.23.5'
        fish -c 'asdf global golang 1.23.5'
    fi
}

# Function to install VS Code extensions
install_vscode_extensions() {
    local extensions=(
        # Core extensions
        "eamodio.gitlens"
        "visualstudioexptteam.vscodeintellicode"

        # Golang
        "golang.go"

        # Python
        "ms-python.python"
        "ms-python.vscode-pylance"

        # Node.js, React, TypeScript
        "dbaeumer.vscode-eslint"
        "esbenp.prettier-vscode"
        "ms-vscode.vscode-typescript-next"
        "christian-kohler.npm-intellisense"

        # HTML/CSS
        "ecmel.vscode-html-css"
        "zignd.html-css-class-completion"
        "ritwickdey.liveserver"

        # Docker
        "ms-azuretools.vscode-docker"
    )

    echo "Installing VS Code extensions..."
    for extension in "${extensions[@]}"; do
        if ! code --list-extensions | grep -q "$extension"; then
            echo "Installing $extension..."
            code --install-extension "$extension"
        else
            echo "$extension is already installed."
        fi
    done
    echo "VS Code extensions installed successfully."
}

# Function to install VS Code
install_vscode() {
    if ! command -v code &> /dev/null; then
        echo "Installing Visual Studio Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
        sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
        rm packages.microsoft.gpg
        sudo apt update
        sudo apt install -y code
        echo "Visual Studio Code installed successfully."
    else
        echo "Visual Studio Code is already installed."
    fi
}

setup_vscode() {
    # Install VS Code
    install_vscode

    # Install VS Code extensions
    install_vscode_extensions
}

setup_neovim() {
    if ! command -v nvim &> /dev/null; then
        log "Installing Neovim..."

        sudo apt remove neovim
        sudo apt install ninja-build gettext cmake unzip curl

        # Compile and install Neovim
        git clone https://github.com/neovim/neovim /tmp/neovim
        cd /tmp/neovim
        make CMAKE_BUILD_TYPE=RelWithDebInfo
        cd build && cpack -G DEB
        sudo dpkg -i --force-overwrite nvim-linux64.deb

        # Clean up
        cd
        rm -rf /tmp/neovim
    fi
}

install_aichat() {
    # Install latest aichat CLI
    if ! command -v aichat &> /dev/null; then
        install_from_github "sigoden" "aichat" "aichat"
    fi
}

setup_ai() {
    # Install aider
    install_aider_chat

    # Install fabric
    install_fabric

    # install aichat
    install_aichat
}

setup_terminal_tools() {
    # superfile
    if ! command -v superfile &> /dev/null; then
        install_from_github "yorukot" "superfile" "spf" "latest" "amd64"
    fi

    # lsd
    if ! command -v superfile &> /dev/null; then
        install_from_github "lsd-rs" "lsd" "lsd" "latest"
    fi
}

setup_tools() {
    log "Starting common tools setup..."

    setup_asdf
    setup_vscode
    setup_neovim
    setup_ai
    setup_terminal_tools

    log "Common tools setup completed successfully!"
}