#!/usr/bin/env bash

# Function to modify SSH config safely
modify_ssh_config() {
    local param=$1
    local value=$2
    local config_file="/etc/ssh/sshd_config.new"

    # If parameter exists, replace it; otherwise, append it
    if sudo grep -q "^#*${param}" "$config_file"; then
        sudo sed -i "s/^#*${param}.*/${param} ${value}/" "$config_file"
    else
        echo "${param} ${value}" | sudo tee -a "$config_file" >/dev/null
    fi
}

setup_base() {
    log "Configuring base system settings..."

    # Update package lists and upgrade system
    sudo apt-get update
    sudo apt-get upgrade -y

    # Install essential packages
    local packages=(
        build-essential
        coreutils
        curl
        wget
        git
        htop
        tmux
        tree
        unzip
        tar
        rsync
        vim
        fish
        stow
        net-tools
        openssh-server
        gnupg
        software-properties-common
        apt-transport-https
        ca-certificates
        xclip
        fzf
        ethtool
        poppler-utils       # pdftotext
        pandoc
    )

    log "Installing base packages..."
    sudo apt-get install -y "${packages[@]}"

    # Disable needrestart
    if [ -f /etc/needrestart/needrestart.conf ]; then
        log "Disabling needrestart..."
        sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
    fi

    # Configure locale
    log "Configuring locale..."
    if ! locale -a | grep -q "^en_US.utf8$"; then
        sudo locale-gen en_US.UTF-8
    fi
    sudo update-locale LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

    # Configure lid close actions
    log "Configuring lid close actions..."

    # Update logind.conf
    local logind_conf="/etc/systemd/logind.conf"
    sudo cp "$logind_conf" "$logind_conf.backup"

    # Function to update or add parameter in logind.conf
    update_logind_param() {
        local param="$1"
        local value="$2"
        if grep -q "^#*${param}=" "$logind_conf"; then
            sudo sed -i "s/^#*${param}=.*/${param}=${value}/" "$logind_conf"
        else
            echo "${param}=${value}" | sudo tee -a "$logind_conf" > /dev/null
        fi
    }

    update_logind_param "HandleLidSwitch" "ignore"
    update_logind_param "HandleLidSwitchExternalPower" "ignore"
    update_logind_param "HandleLidSwitchDocked" "ignore"

    # Additional steps to prevent suspension
    sudo mkdir -p /etc/systemd/sleep.conf.d/
    cat << EOF | sudo tee /etc/systemd/sleep.conf.d/nosuspend.conf
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
EOF

    # Mask sleep-related targets
    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

    # disable MOTD
    sudo chmod -x /etc/update-motd.d/*
    sudo sed -i 's/^session\s\+optional\s\+pam_motd.so/#session    optional     pam_motd.so/' /etc/pam.d/sshd

    # Configure GRUB
    log "Configuring GRUB..."
    local grub_conf="/etc/default/grub"
    local grub_updated=false

    if [ -f "$grub_conf" ]; then
        # Backup GRUB config
        sudo cp "$grub_conf" "$grub_conf.backup"

        # Add pci=nomsi if not present
        if ! grep -q "pci=nomsi" "$grub_conf"; then
            if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_conf"; then
                # Add to existing parameters
                sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 pci=nomsi"/' "$grub_conf"
            else
                # Create new parameter
                echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet pci=nomsi"' | sudo tee -a "$grub_conf"
            fi
            grub_updated=true
        fi

        # Update GRUB if changes were made
        if [ "$grub_updated" = true ]; then
            sudo update-grub
        fi
    fi

    # Configure Wake-on-LAN
    log "Configuring Wake-on-LAN..."
    local interface="eno1"  # Change this if needed

    # Function to check if WoL is enabled
    check_wol() {
        sudo ethtool "$interface" | grep -q "Wake-on: g"
    }

    if ! check_wol; then
        # Enable WoL using ethtool
        sudo ethtool -s "$interface" wol g

        # Make WoL persistent across reboots
        local wol_service="/etc/systemd/system/wol.service"
        if [ ! -f "$wol_service" ]; then
            cat << EOF | sudo tee "$wol_service"
[Unit]
Description=Configure Wake-on-LAN
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s $interface wol g
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
            # Enable and start the service
            sudo systemctl enable wol.service
            sudo systemctl start wol.service
        fi
    fi

    # Set fish as default shell
    if [[ "$SHELL" != "/usr/bin/fish" ]]; then
        log "Setting fish as default shell..."
        chsh -s /usr/bin/fish
    fi

    # Configure SSH server for remote access
    log "Configuring SSH server..."

    # Create backup of SSH config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

    # Create a temporary SSH config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.new

    # Apply SSH configurations
    modify_ssh_config "PermitRootLogin" "no"
    modify_ssh_config "PasswordAuthentication" "no"
    modify_ssh_config "PubkeyAuthentication" "yes"
    modify_ssh_config "ClientAliveInterval" "300"
    modify_ssh_config "ClientAliveCountMax" "2"
    modify_ssh_config "PrintMotd" "no"
    modify_ssh_config "AllowAgentForwarding" "yes"
    modify_ssh_config "AllowTcpForwarding" "yes"
    modify_ssh_config "X11Forwarding" "yes"

    # Test the new configuration
    if sudo sshd -t -f /etc/ssh/sshd_config.new; then
        log "New SSH configuration is valid"

        # Keep the existing SSH connection alive
        sudo cp /etc/ssh/sshd_config.new /etc/ssh/sshd_config

        # Reload SSH service instead of restart
        # This keeps existing connections alive while applying new settings
        sudo systemctl reload ssh

        log_success "SSH configuration updated successfully"
    else
        log_error "Invalid SSH configuration, rolling back..."
        sudo cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
        sudo systemctl reload ssh
        return 1
    fi

    # Create .ssh directory with proper permissions if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # Setup authorized_keys file with proper permissions if it doesn't exist
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    # Disable mbox globally
    echo "unset MAILCHECK" | sudo tee /etc/profile.d/disable_mbox.sh

    # Disable mbox messages
    touch ~/.hushlogin

    log "Base system configuration completed"

    # Important notice for the user
    log_warning "IMPORTANT: Before logging out, make sure to:"
    log_warning "1. Add your SSH public key to ~/.ssh/authorized_keys"
    log_warning "2. Test SSH access in a new session before closing this one"
    log_warning "3. The system is configured to disable password authentication"
}