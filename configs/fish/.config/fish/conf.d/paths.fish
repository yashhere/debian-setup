# # Setting up the Path
# set -e fish_user_paths

# asdf
source ~/.asdf/asdf.fish

if command -v asdf > /dev/null
    # ASDF Golang Path Setup
    set -gx GOROOT (asdf where golang)
    set -gx GOPATH $HOME/go

    fish_add_path -p $GOROOT/bin
    fish_add_path -p $GOPATH/bin
end

# Bun
fish_add_path "$HOME/.bun"

# Local scripts
fish_add_path $HOME/.local/bin

# FZF and FD helpers for NeoVim
set -x FZF_DEFAULT_COMMAND "fd --type f"
set -x FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"

# # Docker
# set -g fish_user_paths $HOME/.docker/bin $fish_user_paths