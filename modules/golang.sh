#!/usr/bin/env bash

setup_golang() {
    log "Setting up Go development environment..."

    # Source the configuration
    fish -c "source \"$HOME/.asdf/plugins/golang/set-env.fish\""

    # Install common Go tools
    GO_TOOLS=(
        "golang.org/x/tools/gopls@latest"                   # Go language server
        "github.com/go-delve/delve/cmd/dlv@latest"          # Delve debugger
        "golang.org/x/tools/cmd/goimports@latest"           # Goimports
        "github.com/fatih/gomodifytags@latest"              # Go struct tag modifier
        "github.com/cweill/gotests/gotests@latest"          # Generate Go tests
        "github.com/ramya-rao-a/go-outline@latest"          # Go outline for VS Code
        "github.com/stamblerre/gocode@latest"               # Autocompletion daemon
        "github.com/uudashr/gopkgs/v2/cmd/gopkgs@latest"    # List available Go packages
        "github.com/josharian/impl@latest"                  # Generate method implementations
        "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
    )

    for tool in "${GO_TOOLS[@]}"; do
        echo "Installing $tool..."
        go install "$tool"
    done

    log_success "Go development environment setup completed"
}