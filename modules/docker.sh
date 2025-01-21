#!/usr/bin/env bash

# Helper function to check if docker is properly installed and running
check_docker_installation() {
    # Check if docker command exists and is executable
    if command -v docker &> /dev/null; then
        # Check if docker daemon is running
        if sudo systemctl is-active --quiet docker; then
            # Check if we can run docker commands
            if docker info &> /dev/null; then
                return 0
            fi
        fi
    fi
    return 1
}

# Helper function to check if docker compose is installed
check_docker_compose() {
    if docker compose version &> /dev/null; then
        return 0
    fi
    return 1
}

# Helper function to check if user is in docker group
check_docker_group() {
    if groups "$USER" | grep -q "\bdocker\b"; then
        return 0
    fi
    return 1
}

setup_docker() {
    log "Checking Docker environment..."

    # Check if Docker is already properly installed and running
    if check_docker_installation; then
        log "Docker is already installed and running"
        DOCKER_INSTALLED=true
    else
        DOCKER_INSTALLED=false

        # Remove old versions only if they exist
        local old_packages=(
            "docker"
            "docker-engine"
            "docker.io"
            "containerd"
            "runc"
        )

        for pkg in "${old_packages[@]}"; do
            if dpkg -l | grep -q "^ii  $pkg "; then
                log "Removing old package: $pkg"
                sudo apt-get remove -y "$pkg"
            fi
        done

        # Install prerequisites if not already installed
        local prerequisites=(
            "ca-certificates"
            "curl"
            "gnupg"
        )

        for pkg in "${prerequisites[@]}"; do
            if ! dpkg -l | grep -q "^ii  $pkg "; then
                sudo apt-get update
                sudo apt-get install -y "${prerequisites[@]}"
                break
            fi
        done

        # Add Docker's GPG key if not already added
        if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
            log "Adding Docker's GPG key..."
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg
        fi

        # Add repository if not already added
        if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
            log "Setting up Docker repository..."
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        fi

        # Install Docker Engine if not already installed
        log "Installing Docker packages..."
        sudo apt-get update
        local docker_packages=(
            "docker-ce"
            "docker-ce-cli"
            "containerd.io"
            "docker-buildx-plugin"
            "docker-compose-plugin"
        )

        sudo apt-get install -y "${docker_packages[@]}"

        # Enable and start Docker service
        log "Enabling Docker service..."
        sudo systemctl enable docker
        sudo systemctl start docker
    fi

    # Add user to docker group if not already added
    if ! check_docker_group; then
        log "Adding user to docker group..."
        sudo usermod -aG docker "$USER"
        log_warning "You will need to log out and back in for the docker group membership to take effect"
    fi

    # Create docker config directory if it doesn't exist
    mkdir -p ~/.docker

    # Configure Docker daemon if not already configured
    if [ ! -f /etc/docker/daemon.json ]; then
        log "Configuring Docker daemon..."
        cat << EOF | sudo tee /etc/docker/daemon.json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "default-address-pools": [
        {
            "base": "172.17.0.0/16",
            "size": 24
        }
    ]
}
EOF
        # Restart Docker only if we modified the configuration
        sudo systemctl restart docker
    fi

    # Check Docker installation
    if ! check_docker_installation; then
        log_error "Docker installation failed"
        return 1
    fi

    # Install Docker Compose if not already installed
    if ! check_docker_compose; then
        log "Installing Docker Compose..."
        DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
        mkdir -p $DOCKER_CONFIG/cli-plugins
        COMPOSE_LATEST=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep "tag_name" | cut -d '"' -f 4)
        curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_LATEST}/docker-compose-linux-$(uname -m)" -o $DOCKER_CONFIG/cli-plugins/docker-compose
        chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

        if ! check_docker_compose; then
            log_error "Docker Compose installation failed"
            return 1
        fi
    fi

    # Create common Docker networks if they don't exist
    if ! docker network ls | grep -q "front-proxy"; then
        log "Creating front-proxy network..."
        docker network create --driver bridge front-proxy
    fi

    if ! docker network ls | grep -q "backend"; then
        log "Creating backend network..."
        docker network create --driver bridge backend
    fi

    # Create docker directory structure if it doesn't exist
    mkdir -p ~/docker/{compose,volumes,configs}

    # Create README only if it doesn't exist
    if [ ! -f ~/docker/README.md ]; then
        cat << 'EOF' > ~/docker/README.md
Docker Environment Structure

./docker
├── compose/    # Docker compose files
├── volumes/    # Docker volumes
└── configs/    # Configuration files

Usage:
1. Place your docker-compose.yml files in the compose directory
2. Store persistent data in the volumes directory
3. Keep configuration files in the configs directory

Remember to:
1. Log out and back in to use Docker without sudo
2. Use docker compose from any directory
3. Check docker logs with: docker logs [container_name]
4. Monitor containers with: docker stats
EOF
    fi

    log_success "Docker setup completed"

    if [ "$DOCKER_INSTALLED" = false ] || ! check_docker_group; then
        log_warning "IMPORTANT: You need to log out and back in for all changes to take effect"
    fi
}