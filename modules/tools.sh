#!/usr/bin/env bash

# Tool versions and configs
ASDF_VERSION="v0.15.0"
NEOVIM_VERSION="0.9.4"

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

# Function to configure VS Code settings
configure_vscode_settings() {
    local settings_file="$HOME/.config/Code/User/settings.json"
    local settings='
    {
        "editor.tabSize": 4,
        "editor.insertSpaces": true,
        "editor.wordWrap": "on",
        "files.autoSave": "afterDelay",
        "files.autoSaveDelay": 1000,
        "editor.fontSize": 14,
        "editor.fontLigatures": true,
        "terminal.integrated.fontSize": 14,
        "eslint.enable": true,
        "eslint.autoFixOnSave": true,
        "prettier.singleQuote": true,
        "prettier.trailingComma": "es5",
        "prettier.semi": true,
        "python.linting.enabled": true,
        "python.linting.pylintEnabled": true,
        "python.linting.flake8Enabled": true,
        "python.formatting.provider": "black",
        "go.useLanguageServer": true,
        "go.formatTool": "goimports",
        "typescript.updateImportsOnFileMove.enabled": "always",
        "javascript.updateImportsOnFileMove.enabled": "always",
        "html.format.enable": true,
        "css.validate": true,
        "docker.languageserver": {
            "enabled": true
        }
    }'

    echo "Configuring VS Code settings..."
    if [ ! -f "$settings_file" ]; then
        mkdir -p "$(dirname "$settings_file")"
    fi
    echo "$settings" > "$settings_file"
    echo "VS Code settings configured successfully."
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
    if ! command_exists code; then
        echo "Installing Visual Studio Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
        sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
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

    # Configure VS Code settings
    configure_vscode_settings
}

setup_neovim() {
    if ! command -v nvim &> /dev/null; then
        log "Installing Neovim..."
        sudo apt-get install -y neovim

        # Install vim-plug
        sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
    fi
}

setup_tools() {
    log "Starting common tools setup..."

    setup_asdf
    setup_vscode
    setup_neovim
    # setup_git

    log "Common tools setup completed successfully!"
}