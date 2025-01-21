#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Skip network config over ssh
SKIP_NETWORK=true

# Root directory of the setup scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
CONFIG_DIR="${SCRIPT_DIR}/configs"
LOG_FILE="${SCRIPT_DIR}/setup.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - $1" | tee -a "${LOG_FILE}"
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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Check if running over SSH
is_ssh() {
    if [ -n "${SSH_CLIENT-}" ] || [ -n "${SSH_TTY-}" ]; then
        return 0
    else
        return 1
    fi
}

# Check for required commands
check_requirements() {
    local required_commands=("curl" "git" "sudo")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
}

# Function to source and run a module
run_module() {
    local module_name=$1
    local module_path="${MODULES_DIR}/${module_name}.sh"

    if [[ -f "$module_path" ]]; then
        log "Running module: ${module_name}"
        source "$module_path"
        if declare -F "setup_${module_name}" > /dev/null; then
            "setup_${module_name}"
            log_success "Module ${module_name} completed"
        else
            log_error "Module ${module_name} does not contain required function setup_${module_name}"
            return 1
        fi
    else
        log_error "Module not found: ${module_path}"
        return 1
    fi
}


# Main setup function
main() {
    local modules=(
        "base"          # Basic system configuration
        "network"       # Static IP and network setup
        "docker"        # Docker installation and configuration
        "tools"         # Development tools (git, vim, etc.)
        "python"        # Python development environment (pyenv, pipx)
        "nodejs"        # Node.js development environment (nvm)
        "golang"        # Go development environment
        "ai"            # terminal-based ai tools
        # "gnome"         # GNOME configuration and extensions
        # "dotfiles"      # GNU Stow dotfiles setup
    )

    # Check if running over SSH and network module is not skipped
    if is_ssh && ! $SKIP_NETWORK; then
        log_error "Network configuration cannot be run over SSH!"
        log_error "Please run network-setup.sh directly on the machine first,"
        log_error "then run this script again with --skip-network option."
        exit 1
    fi

    # Create necessary directories
    mkdir -p "${MODULES_DIR}" "${CONFIG_DIR}"

    # Initialize log file
    : > "${LOG_FILE}"

    log "Starting Debian setup script"

    # Run preliminary checks
    check_root
    check_requirements

    # Run modules
    for module in "${modules[@]}"; do
        # Skip network module if specified
        if [ "$module" = "network" ] && $SKIP_NETWORK; then
            log "Skipping network configuration as requested"
            continue
        fi

        if ! run_module "$module"; then
            log_error "Failed to run module: ${module}"
            exit 1
        fi
    done

    log_success "Setup completed successfully"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-network)
            SKIP_NETWORK=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"