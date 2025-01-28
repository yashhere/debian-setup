#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Skip network config over ssh
SKIP_NETWORK=false

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

log_error() { log "${RED}ERROR: $1${NC}"; }
log_success() { log "${GREEN}SUCCESS: $1${NC}"; }
log_warning() { log "${YELLOW}WARNING: $1${NC}"; }

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
}

# Check if running over SSH
is_ssh() {
    [ -n "${SSH_CLIENT-}" ] || [ -n "${SSH_TTY-}" ]
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

    if [[ ! -f "$module_path" ]]; then
        log_error "Module not found: ${module_path}"
        return 1
    fi

    log "Running module: ${module_name}"
    source "$module_path"

    if ! declare -F "setup_${module_name}" > /dev/null; then
        log_error "Module ${module_name} does not contain required function setup_${module_name}"
        return 1
    fi

    "setup_${module_name}"
    log_success "Module ${module_name} completed"
}

# List available modules
list_modules() {
    echo "Available modules:"
    for module in "${MODULES_DIR}"/*.sh; do
        [[ -f "$module" ]] || continue
        basename "$module" .sh
    done
}

# Main setup function
main() {
    local modules=(
        "base"          # Basic system configuration
        "network"       # Static IP and network setup
        "docker"        # Docker installation and configuration
        "tools"         # Development tools
        "python"        # Python development environment
        "nodejs"        # Node.js development environment
        "golang"        # Go development environment
        "gnome"         # GNOME configuration and extensions
        "dotfiles"      # GNU Stow dotfiles setup
    )

    # Create necessary directories
    mkdir -p "${MODULES_DIR}" "${CONFIG_DIR}"
    : > "${LOG_FILE}"

    log "Starting Debian setup script"
    check_root
    check_requirements

    # Run single module if specified
    if [[ -n "${SINGLE_MODULE:-}" ]]; then
        run_module "$SINGLE_MODULE"
        exit $?
    fi

    # Check SSH conditions
    if is_ssh && ! $SKIP_NETWORK; then
        log_error "Network configuration cannot be run over SSH! Use --skip-network option."
        exit 1
    fi

    # Run all modules
    for module in "${modules[@]}"; do
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
        --module)
            SINGLE_MODULE="$2"
            shift 2
            ;;
        --list-modules)
            list_modules
            exit 0
            ;;
        --help)
            echo "Usage: $0 [--skip-network] [--module <module_name>] [--list-modules] [--help]"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

main "$@"