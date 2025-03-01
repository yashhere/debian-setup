#!/usr/bin/env bash

# network-setup.sh
set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${1}"
}

log_error() {
    log "${RED}ERROR: $1${NC}"
}

log_success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

log_warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Validate network settings before proceeding
validate_network_settings() {
    local ip="$1"
    local gateway="$2"
    local interface="$3"

    # Check if interface exists
    if ! ip link show "$interface" &> /dev/null; then
        log_error "Interface $interface does not exist"
        return 1
    fi

    # Basic IP validation
    if ! [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        log_error "Invalid IP address format: $ip"
        return 1
    fi

    # Basic gateway validation
    if ! [[ $gateway =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "Invalid gateway address: $gateway"
        return 1
    fi

    return 0
}

# Main network configuration function
configure_network() {
    # Network configuration parameters
    local IP_ADDRESS="192.168.1.102/24"
    local GATEWAY="192.168.1.1"
    local DNS1="192.168.1.101"
    local DNS2="1.1.1.1"
    local INTERFACE="eno1"

    # Validate settings
    if ! validate_network_settings "$IP_ADDRESS" "$GATEWAY" "$INTERFACE"; then
        exit 1
    fi

    if is_ssh; then
        log_error "This script should not be run over SSH!"
        log_error "Please run this script directly on the machine console."
        exit 1
    fi

    # Detect distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        log_error "Cannot detect Linux distribution"
        return 1
    fi

    case $DISTRO in
        "ubuntu")
            configure_ubuntu_network
            ;;
        "debian")
            configure_debian_network
            ;;
        *)
            log_error "Unsupported distribution: $DISTRO"
            return 1
            ;;
    esac
}

configure_ubuntu_network() {
    log "Configuring Ubuntu network using netplan..."

    # Backup existing netplan configuration
    local NETPLAN_DIR="/etc/netplan"
    local NETPLAN_FILE="${NETPLAN_DIR}/00-installer-config.yaml"

    if [ -f "$NETPLAN_FILE" ]; then
        sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.backup"
    fi

    # Create new netplan configuration
    cat << EOF | sudo tee "$NETPLAN_FILE"
network:
  version: 2
  ethernets:
    ${INTERFACE}:
      dhcp4: no
      addresses:
        - ${IP_ADDRESS}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [${DNS1}, ${DNS2}]
EOF

    # Apply network configuration
    if sudo netplan try; then
        sudo netplan apply
        log_success "Ubuntu network configuration applied successfully"
    else
        log_error "Network configuration failed, rolling back..."
        if [ -f "${NETPLAN_FILE}.backup" ]; then
            sudo cp "${NETPLAN_FILE}.backup" "$NETPLAN_FILE"
            sudo netplan apply
        fi
        return 1
    fi
}

configure_debian_network() {
    log "Configuring Debian network using /etc/network/interfaces..."

    # Backup existing configuration
    sudo cp /etc/network/interfaces /etc/network/interfaces.backup

    # Extract IP address and prefix
    local IP_ADDR=$(echo $IP_ADDRESS | cut -d'/' -f1)
    local PREFIX=$(echo $IP_ADDRESS | cut -d'/' -f2)

    # Convert prefix to netmask
    local NETMASK=$(prefix_to_netmask $PREFIX)

    # Create new interfaces configuration
    cat << EOF | sudo tee /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto ${INTERFACE}
iface ${INTERFACE} inet static
    address ${IP_ADDR}
    netmask ${NETMASK}
    gateway ${GATEWAY}
    dns-nameservers ${DNS1} ${DNS2}
EOF

    # Restart networking service
    log "Applying network configuration..."

    # Test the configuration first
    if sudo ifup --no-act ${INTERFACE}; then
        # Create a background task to restore network if something goes wrong
        (
            sleep 30
            if ! ping -c 1 ${GATEWAY} > /dev/null 2>&1; then
                log_error "Network configuration failed, rolling back..."
                sudo cp /etc/network/interfaces.backup /etc/network/interfaces
                sudo systemctl restart networking
            fi
        ) &

        # Apply the configuration
        sudo systemctl restart networking

        # Test connectivity
        if ping -c 1 ${GATEWAY} > /dev/null 2>&1; then
            log_success "Debian network configuration applied successfully"
        else
            log_error "Network configuration failed, rolling back..."
            sudo cp /etc/network/interfaces.backup /etc/network/interfaces
            sudo systemctl restart networking
            return 1
        fi
    else
        log_error "Invalid network configuration"
        sudo cp /etc/network/interfaces.backup /etc/network/interfaces
        return 1
    fi
}

# Helper function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        return $?
    else
        return 1
    fi
}

# Display usage instructions
display_instructions() {
    cat << 'EOF'
Network Configuration Instructions:

1. BEFORE RUNNING THIS SCRIPT:
   - Connect to the machine directly (not over SSH)
   - Verify network settings in this script:
     * IP_ADDRESS
     * GATEWAY
     * INTERFACE name
     * DNS servers

2. Run this script directly on the machine:
   ./network-setup.sh

3. After successful configuration:
   - SSH into the machine using the new IP
   - Run the main setup script:
     ./setup.sh --skip-network

Note: DO NOT run this script over SSH - it will refuse to run!
EOF
}

# Main execution
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        display_instructions
        exit 0
    fi

    log_warning "This script will configure network settings."
    log_warning "Make sure you are running this directly on the machine, not over SSH."
    log_warning "Current network settings will be lost!"
    read -p "Are you sure you want to continue? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        configure_network
    else
        log "Network configuration cancelled."
        exit 1
    fi
}

main "$@"

# Helper function to convert prefix to netmask
prefix_to_netmask() {
    local prefix=$1
    local netmask=""

    # Ensure the prefix is between 0 and 32
    if [[ $prefix -lt 0 || $prefix -gt 32 ]]; then
        echo "Invalid prefix length. Must be between 0 and 32."
        return 1
    fi

    # Calculate the netmask
    for i in {1..4}; do
        if [[ $prefix -ge 8 ]]; then
            netmask+="255"
            prefix=$((prefix - 8))
        else
            netmask+=$((256 - 2**(8 - prefix)))
            prefix=0
        fi

        if [[ $i -lt 4 ]]; then
            netmask+="."
        fi
    done

    echo "$netmask"
}
