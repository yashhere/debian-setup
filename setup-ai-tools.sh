#!/bin/sh

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Python and pip if not already installed
install_python() {
    if ! command_exists python3; then
        echo "Installing Python 3..."
        sudo apt update
        sudo apt install -y python3 python3-pip
    else
        echo "Python 3 is already installed."
    fi

    if ! command_exists pip3; then
        echo "Installing pip..."
        sudo apt install -y python3-pip
    else
        echo "pip is already installed."
    fi
}

# Function to install Playwright via npm
install_playwright_npm() {
    if ! command_exists npm; then
        echo "Installing Node.js and npm..."
        sudo apt update
        sudo apt install -y nodejs npm
    fi

    echo "Installing Playwright via npm..."
    npm install -g playwright

    echo "Installing browsers for Playwright..."
    npx playwright install --with-deps chromium
}

# Function to install aider-chat
install_aider_chat() {
    if ! command_exists aider; then
        echo "Installing aider-chat..."
        curl -LsSf https://aider.chat/install.sh | bash
    else
        echo "aider-chat is already installed."
    fi

    if command_exists npm; then
        install_playwright_npm
    else
        echo "NPM is required to install Playwright."
    fi
}

# Function to install danielmiessler/fabric
install_fabric() {
    if ! command_exists fabric; then
        echo "Installing fabric..."
        go install github.com/danielmiessler/fabric@latest
    else
        echo "fabric is already installed."
    fi
}

# Function to configure Fish shell
configure_fish_shell() {
    FISH_CONFIG="$HOME/.config/fish/config.fish"
    mkdir -p "$(dirname "$FISH_CONFIG")"

    # Add Python's user bin directory to PATH if not already present
    if ! grep -q "\$HOME/.local/bin" "$FISH_CONFIG"; then
        echo 'set -gx PATH $PATH $HOME/.local/bin' >> "$FISH_CONFIG"
    fi

    # Add fabric directory to PATH if not already present
    if ! grep -q "\$HOME/fabric" "$FISH_CONFIG"; then
        echo 'set -gx PATH $PATH $HOME/fabric' >> "$FISH_CONFIG"
    fi
}

# Main function
main() {
    # Install Python and pip
    install_python

    # Install AI tools
    install_aider_chat
    install_fabric

    # Configure Fish shell
    configure_fish_shell

    echo "AI tools setup complete!"
}

# Run the script
main