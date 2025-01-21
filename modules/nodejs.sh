#!/usr/bin/env bash

setup_nodejs() {
    log "Setting up Node.js development environment..."

    # Install global npm packages
    local npm_packages=(
        typescript
        ts-node
        eslint
        prettier
        nodemon
        http-server
    )

    npm install -g "${npm_packages[@]}"

    log_success "Node.js development environment setup completed"
}