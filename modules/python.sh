#!/usr/bin/env bash

setup_python() {
    log "Setting up Python development environment..."

    # Install pipx
    pip install --user pipx
    pipx ensurepath

    # Install common Python tools with pipx
    local python_tools=(
        black
        flake8
        mypy
        poetry
        pre-commit
        pytest
        jupyterlab
    )

    for tool in "${python_tools[@]}"; do
        pipx install "$tool"
    done

    log_success "Python development environment setup completed"
}