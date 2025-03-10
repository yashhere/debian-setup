#!/usr/bin/env bash

# Tool versions and configs
ASDF_VERSION="v0.15.0"
NEOVIM_VERSION="0.9.4"

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
GITHUB_API_URL="https://api.github.com"
ARCH="${ARCH:-x86_64}"
OS="${OS:-linux}"
INFLUXDB_HOST="${INFLUXDB_HOST:-localhost}"

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

    local download_url=$(echo "$release_data" | jq -r ".assets[] | select(.browser_download_url | ascii_downcase | contains(\"$arch\") and contains(\"$OS\") and (endswith(\".tar.gz\") or endswith(\".zip\"))) | .browser_download_url" | head -n1)
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
        # Python build dependencies
        sudo apt install -y build-essential python3-dev libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev curl git libffi-dev \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev liblzma-dev

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
        fish -c 'asdf plugin add bun'
        fish -c 'asdf install bun latest'
        fish -c 'asdf global bun latest'

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
        sudo apt install -y ninja-build gettext cmake unzip curl

        # Compile and install Neovim
        git clone https://github.com/neovim/neovim /tmp/neovim
        cd /tmp/neovim
        make CMAKE_BUILD_TYPE=RelWithDebInfo
        cd build && cpack -G DEB
        sudo dpkg -i --force-overwrite nvim-linux*.deb

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
    if ! command -v spf &> /dev/null; then
        install_from_github "yorukot" "superfile" "spf" "latest" "amd64"
    fi

    # lsd
    if ! command -v lsd &> /dev/null; then
        install_from_github "lsd-rs" "lsd" "lsd" "latest"
    fi

    # bat
    if ! command -v bat &> /dev/null; then
        install_from_github "sharkdp" "bat" "bat" "latest"
    fi

    # glow
    if ! command -v glow &> /dev/null; then
        install_from_github "charmbracelet" "glow" "glow" "latest"
    fi

    # docx2md
    if ! command -v docx2md &> /dev/null; then
        install_from_github "mattn" "docx2md" "docx2md" "latest" "amd64"
    fi

    # cheat
    if ! command -v cheat &> /dev/null; then
        go install github.com/cheat/cheat/cmd/cheat@latest
    fi

    # tealdeer
    if ! command -v tealdeer &> /dev/null; then
        install_from_github "tealdeer-rs" "tealdeer" "tealdeer" "latest"
    fi

    # doggo
    if ! command -v doggo &> /dev/null; then
        install_from_github "mr-karan" "doggo" "doggo" "latest"
    fi

    # dust
    if ! command -v dust &> /dev/null; then
        install_from_github "bootandy" "dust" "dust" "latest"
    fi

    # duf
    if ! command -v duf &> /dev/null; then
        install_from_github "muesli" "duf" "duf" "latest"
    fi

    # bottom
    if ! command -v btm &> /dev/null; then
        install_from_github "ClementTsang" "bottom" "btm" "latest"
    fi

    # gron
    if ! command -v gron &> /dev/null; then
        install_from_github "tomnomnom" "gron" "gron" "latest" "amd64"
    fi

    # gh-cli
    if ! command -v gh &> /dev/null; then
        install_from_github "cli" "cli" "gh" "latest" "amd64"
    fi
}

setup_gh_commit() {
    if ! command -v gh > /dev/null 2>&1
    then
        log "GitHub CLI could not be found. Can't install gh-commit!"
        return 0
    fi

    # Check if the extension is already installed
    if gh extension list | grep -q "gh-commit"; then
        log "gh-commit extension is already installed.\n"
        return 1
    fi

    # Install GitHub CLI extension
    gh extension install ghcli/gh-commit

    # Create Git alias (POSIX compliant)
    git config --global alias.auto-commit '!f() { git commit -m "$(gh commit)" || git commit -a -m "$(gh commit)" && git log HEAD...HEAD~1; }; f'

    log "Commit GitHub CLI extension installed successfully!"
}

setup_telegraf() {
    # Verify required environment variables
    if [ -z "$INFLUXDB_HOST" ] || [ -z "$INFLUXDB_TOKEN" ]; then
        echo "Error: Required environment variables not set"
        echo "Please set: INFLUXDB_HOST, INFLUXDB_TOKEN"
        return 1
    fi

    # Add InfluxDB repository
    if [ ! -f "/etc/apt/sources.list.d/influxdata.list" ]; then
        curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
        echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main" | sudo tee /etc/apt/sources.list.d/influxdata.list
    fi

    # Update and install
    sudo apt-get update
    sudo apt-get install -y telegraf acpi

    # Create battery monitoring script
    if [ ! -f "/etc/telegraf/battery_monitor.sh" ]; then
        cat << 'BATTERYSCRIPT' | sudo tee /etc/telegraf/battery_monitor.sh
#!/bin/bash

# Get battery info using acpi
battery_info=$(acpi -b)

# Extract percentage
percentage=$(echo "$battery_info" | grep -oP '\d+(?=%)' || echo "0")

# Extract charging status
if echo "$battery_info" | grep -q "Charging"; then
    status="charging"
elif echo "$battery_info" | grep -q "Discharging"; then
    status="discharging"
elif echo "$battery_info" | grep -q "Full"; then
    status="full"
else
    status="unknown"
fi

# Extract time remaining if available
time_remaining=$(echo "$battery_info" | grep -oP '\d+:\d+:\d+' || echo "00:00:00")

# Output in InfluxDB line protocol format
echo "laptop_battery,host=$(hostname) percentage=$percentage,status=\"$status\",time_remaining=\"$time_remaining\""
BATTERYSCRIPT

        sudo chmod +x /etc/telegraf/battery_monitor.sh
    fi

    # required by ping plugin
    sudo setcap cap_net_raw=eip /usr/bin/telegraf
    # required by docker plugin
    sudo usermod -aG docker telegraf

    # Backup original config
    sudo cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.bak

    # Create new configuration
    cat << EOF | sudo tee /etc/telegraf/telegraf.conf
[global_tags]

[agent]
interval = "10s"
round_interval = true
metric_batch_size = 1000
metric_buffer_limit = 10000
collection_jitter = "0s"
flush_interval = "10s"
flush_jitter = "0s"
precision = ""
hostname = ""
omit_hostname = false

[[outputs.influxdb_v2]]
urls = ["http://${INFLUXDB_HOST}:8086"]
token = "${INFLUXDB_TOKEN}"
organization = "homelab"
bucket = "homelab"
user_agent = "telegraf"
insecure_skip_verify = true

[[inputs.cpu]]
percpu = true
totalcpu = true
collect_cpu_time = false
report_active = false

[[inputs.disk]]
ignore_fs = ["tmpfs", "devtmpfs", "devfs", "iso9660", "overlay", "aufs", "squashfs"]
mount_points = ["/", "/home", "/data"]

[[inputs.diskio]]

[[inputs.mem]]

[[inputs.system]]

[[inputs.processes]]

# # Collect statistics about itself
[[inputs.internal]]

# # This plugin gathers interrupts data from /proc/interrupts and /proc/softirqs.
[[inputs.interrupts]]

# Linux Sysctl (for advanced metrics, be cautious)
[[inputs.kernel]]

# # Provides Linux sysctl fs metrics
[[inputs.linux_sysctl_fs]]

# Kernel vmstat metrics
[[inputs.kernel_vmstat]]

# # Get kernel statistics from /proc/mdstat
# # This plugin ONLY supports Linux
[[inputs.mdstat]]

# Sensors (if you have lm-sensors installed and configured)
[[inputs.sensors]]
  # No configuration needed for basic sensor data.

[[inputs.net]]
interfaces = ["eno1", "wlo1"]

# # Read TCP metrics such as established, time wait and sockets counts.
[[inputs.netstat]]

# # Collect kernel snmp counters and network interface statistics
[[inputs.nstat]]

[[inputs.ping]]
  urls = ["8.8.8.8", "1.1.1.1", "192.168.1.1"]
  method = "native"
  interface = "eno1"
  ping_interval = 1.0
  timeout = 1.0
  interval = "30s"
  count = 3
  percentiles = [50, 95, 99]

[[inputs.http_response]]
urls = ["https://google.com", "https://yashagarwal.in"]
response_timeout = "10s"
follow_redirects = true

[[inputs.dns_query]]
servers = ["8.8.8.8", "1.1.1.1", "9.9.9.9"]

[[inputs.docker]]
endpoint = "unix:///var/run/docker.sock"
source_tag = true
timeout = "5s"
total = false
perdevice = false
gather_services = false
docker_label_include = [
    "com.docker.compose.config-hash",
    "com.docker.compose.container-number",
    "com.docker.compose.oneoff",
    "com.docker.compose.project",
    "com.docker.compose.service",
]

[[inputs.exec]]
  commands = ["/etc/telegraf/battery_monitor.sh"]
  timeout = "5s"
  data_format = "influx"
  interval = "30s"

EOF

    # Start and enable service
    sudo systemctl enable telegraf
    sudo systemctl stop telegraf
    sudo systemctl start telegraf
}

setup_tools() {
    log "Starting common tools setup..."

    setup_asdf
    setup_vscode
    setup_neovim
    setup_ai
    setup_terminal_tools
    setup_telegraf
    setup_gh_commit

    log "Common tools setup completed successfully!"
}
