if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Preferred editor for local and remote sessions
if test -n "$SSH_CONNECTION"
    set -x EDITOR vim
    set -x GUIEDITOR vim
else
    set -x EDITOR vim
    set -x GUIEDITOR code
end

# Aliases
alias rmdot="rm -rf .[!.]*"
alias sudoedit="sudo $EDITOR"
alias pu="ps aux | grep -v grep | grep"
alias rs="exec $SHELL"
alias pbpaste="xclip -selection clipboard -o"

set -gx PATH $PATH $GOBIN

# Fabric
# Loop through all files in the ~/.config/fabric/patterns directory
for pattern_file in $HOME/.config/fabric/patterns/*
    # Get the base name of the file (i.e., remove the directory path)
    set pattern_name (basename "$pattern_file")

    # Create an alias in the form: alias pattern_name="fabric --pattern pattern_name"
    alias $pattern_name="fabric --pattern $pattern_name"
end

# Define the yt function
function yt
    set video_link "$argv[1]"
    fabric -y "$video_link" --transcript
end
set -gx PATH $PATH $HOME/.local/bin
set -gx PATH $PATH $HOME/fabric
