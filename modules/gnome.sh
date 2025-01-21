#!/bin/bash

set -euo pipefail

sudo apt install -y gnome-shell-extensions gnome-shell-extension-prefs

declare -A extensions=(
    ["dash-to-dock"]="307"
    ["user-theme"]="19"
    ["workspace-indicator"]="21"
    ["system-monitor"]="120"
    ["clipboard-indicator"]="779"
)

gsettings set org.gnome.shell disable-extension-version-validation true

for ext_name in "${!extensions[@]}"; do
    ext_id="${extensions[$ext_name]}"
    if ! gnome-extensions list | grep -q "$ext_name"; then
        version=$(gnome-shell --version | cut -d' ' -f3)
        dbus-send --session --type=method_call \
            --dest=org.gnome.Shell.Extensions \
            /org/gnome/Shell/Extensions \
            org.gnome.Shell.Extensions.InstallRemoteExtension \
            "string:$ext_id"
        sleep 2
    fi
done

echo "Log out and log back in to complete installation"