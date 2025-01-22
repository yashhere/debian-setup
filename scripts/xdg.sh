#!/bin/bash

# Check if running as normal user (not root)
if [ "$EUID" -eq 0 ]; then
    echo "Please run as normal user, not root"
    exit 1
fi

# Function to safely check and remove directories
check_and_remove_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        # Count files (including hidden ones) but exclude . and ..
        local file_count=$(find "$dir" -mindepth 1 -maxdepth 1 | wc -l)

        if [ "$file_count" -eq 0 ]; then
            echo "Removing empty directory: $dir"
            rm -rf "$dir"
        else
            echo "Warning: $dir contains files. Please manually review and move its contents."
            echo "Directory will not be removed."
            return 1
        fi
    fi
    return 0
}

# Array of XDG directories to process
xdg_dirs=(
    "$HOME/Desktop"
    "$HOME/Documents"
    "$HOME/Downloads"
    "$HOME/Music"
    "$HOME/Pictures"
    "$HOME/Public"
    "$HOME/Templates"
    "$HOME/Videos"
)

# Flag to track if any directory has contents
has_contents=0

# First pass: Check all directories
echo "Checking XDG directories for contents..."
for dir in "${xdg_dirs[@]}"; do
    if [ -d "$dir" ]; then
        file_count=$(find "$dir" -mindepth 1 -maxdepth 1 | wc -l)
        if [ "$file_count" -ne 0 ]; then
            echo "Directory $dir contains files:"
            ls -lah "$dir"
            has_contents=1
        fi
    fi
done

# If any directory has contents, ask for confirmation
if [ "$has_contents" -eq 1 ]; then
    echo
    echo "Some XDG directories contain files. You should backup or move these files before proceeding."
    read -p "Do you want to proceed anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled. Please move or backup your files and try again."
        exit 1
    fi
fi

# Second pass: Remove directories if empty or if user confirmed
for dir in "${xdg_dirs[@]}"; do
    check_and_remove_dir "$dir"
done

# Backup existing config
if [ -f ~/.config/user-dirs.dirs ]; then
    echo "Backing up existing user-dirs.dirs configuration"
    cp ~/.config/user-dirs.dirs ~/.config/user-dirs.dirs.backup
fi

# Create new XDG config pointing everything to HOME
echo "Creating new XDG configuration"
cat > ~/.config/user-dirs.dirs << 'EOL'
XDG_DESKTOP_DIR="$HOME"
XDG_DOWNLOAD_DIR="$HOME"
XDG_TEMPLATES_DIR="$HOME"
XDG_PUBLICSHARE_DIR="$HOME"
XDG_DOCUMENTS_DIR="$HOME"
XDG_MUSIC_DIR="$HOME"
XDG_PICTURES_DIR="$HOME"
XDG_VIDEOS_DIR="$HOME"
EOL

# Disable XDG user dirs update
echo "Disabling XDG user directories updates"
echo "enabled=false" > ~/.config/user-dirs.conf

# Kill and restart xdg-user-dirs-update
echo "Updating XDG user directories"
killall xdg-user-dirs-update 2>/dev/null || true
xdg-user-dirs-update --force

# Update GTK bookmarks
if [ -f ~/.config/gtk-3.0/bookmarks ]; then
    echo "Backing up and clearing GTK bookmarks"
    mv ~/.config/gtk-3.0/bookmarks ~/.config/gtk-3.0/bookmarks.backup
    touch ~/.config/gtk-3.0/bookmarks
fi

# Prevent automatic recreation
echo "Making configuration files read-only"
chmod -w ~/.config/user-dirs.dirs
chmod -w ~/.config/user-dirs.conf

echo
echo "XDG directories configuration has been updated."
echo "* Directories that contained files were preserved"
echo "* Configuration files have been updated to point to HOME"
echo "* You may need to log out and back in for all changes to take effect"
echo
echo "To restore defaults in the future:"
echo "1. Delete ~/.config/user-dirs.{dirs,conf}"
echo "2. Run: xdg-user-dirs-update --force"