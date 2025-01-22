#!/bin/bash

# Exit on any error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Function to check if a package is installed
is_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

# Check for GNOME
if ! is_installed "gnome-shell"; then
    echo "GNOME is not detected. This script is optimized for GNOME installations."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Installing required packages..."
apt-get update

# Check and install packages not provided by GNOME
declare -A packages_to_install

# GNOME already provides power management, but TLP can still be useful for laptops
if ! systemctl is-active --quiet "power-profiles-daemon"; then
    packages_to_install["tlp"]="1"
fi

# Check for and add necessary packages
if ! is_installed "hdparm"; then
    packages_to_install["hdparm"]="1"
fi

if ! is_installed "smartmontools"; then
    packages_to_install["smartmontools"]="1"
fi

if ! is_installed "lm-sensors"; then
    packages_to_install["lm-sensors"]="1"
fi

if ! is_installed "nvme-cli"; then
    packages_to_install["nvme-cli"]="1"
fi

if ! is_installed "sysfsutils"; then
    packages_to_install["sysfsutils"]="1"
fi

# Install packages if any are needed
if [ ${#packages_to_install[@]} -gt 0 ]; then
    apt-get install -y "${!packages_to_install[@]}"
fi

# Configure fstrim - check if not already enabled by GNOME
if ! systemctl is-enabled --quiet fstrim.timer; then
    echo "Setting up fstrim..."
    systemctl enable fstrim.timer
    systemctl start fstrim.timer
else
    echo "fstrim timer already enabled by GNOME"
fi

# Configure SMART monitoring
echo "Setting up SMART monitoring..."
cat > /etc/smartd.conf << 'EOL'
# Monitor all devices
DEVICESCAN -a -o on -S on -n standby,q -s (S/../.././02|L/../../6/03) -W 4,45,55
EOL

systemctl enable smartd
systemctl start smartd

# Configure TLP only if power-profiles-daemon is not active
if ! systemctl is-active --quiet "power-profiles-daemon"; then
    echo "Setting up TLP..."
    cat > /etc/tlp.conf << 'EOL'
# TLP configuration
TLP_ENABLE=1
TLP_DEFAULT_MODE=BAT
DISK_IDLE_SECS_ON_AC=0
DISK_IDLE_SECS_ON_BAT=2
MAX_LOST_WORK_SECS_ON_AC=15
MAX_LOST_WORK_SECS_ON_BAT=60
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
SCHED_POWERSAVE_ON_AC=0
SCHED_POWERSAVE_ON_BAT=1
NMI_WATCHDOG=0
EOL

    systemctl enable tlp
    systemctl start tlp
else
    echo "Using GNOME's power-profiles-daemon instead of TLP"
fi

# Setup sensors detection if not already configured
if [ ! -f /etc/sensors3.conf ] || [ ! -s /etc/sensors3.conf ]; then
    echo "Setting up lm-sensors..."
    yes | sensors-detect
else
    echo "Sensors already configured"
fi

# Create a weekly SMART test script
echo "Creating weekly SMART test script..."
cat > /etc/cron.weekly/smart-test << 'EOL'
#!/bin/bash
for drive in $(smartctl --scan | awk '{print $1}'); do
    smartctl -t long $drive
done
EOL

chmod +x /etc/cron.weekly/smart-test

# Create an enhanced hardware monitoring script that integrates with GNOME tools
echo "Creating hardware monitoring script..."
cat > /usr/local/bin/hw-monitor << 'EOL'
#!/bin/bash

echo "=== System Temperature ==="
sensors

echo -e "\n=== Storage Devices ==="
for drive in $(smartctl --scan | awk '{print $1}'); do
    echo "--- $drive ---"
    smartctl -H $drive
done

echo -e "\n=== Memory Status ==="
free -h

echo -e "\n=== CPU Information ==="
top -bn1 | grep "Cpu(s)"

echo -e "\n=== GNOME Power Profile ==="
if command -v powerprofilesctl &> /dev/null; then
    powerprofilesctl list
else
    echo "Power profiles daemon not available"
fi

echo -e "\n=== Power Consumption ==="
if [ -f /usr/sbin/powerstat ]; then
    powerstat -d 0
else
    echo "powerstat not installed"
fi

# Check GNOME disk utility for SMART status
echo -e "\n=== GNOME Disks SMART Status ==="
if command -v gnome-disks &> /dev/null; then
    echo "SMART status available in GNOME Disks (run 'gnome-disks' for GUI interface)"
fi
EOL

chmod +x /usr/local/bin/hw-monitor

# Create a monthly fstrim log
echo "Setting up monthly fstrim log..."
cat > /etc/cron.monthly/fstrim-log << 'EOL'
#!/bin/bash
LOG="/var/log/fstrim.log"
echo "=== FSTRIM RUN $(date) ===" >> $LOG
fstrim -av >> $LOG 2>&1
EOL

chmod +x /etc/cron.monthly/fstrim-log

echo "Setup complete! Here are some useful commands:"
echo "- Run 'hw-monitor' to check system status"
echo "- Open 'gnome-disks' for GUI disk management"
echo "- Check 'systemctl status fstrim.timer' for trim status"
echo "- View SMART status with 'smartctl -a /dev/sdX'"
if ! systemctl is-active --quiet "power-profiles-daemon"; then
    echo "- Check TLP status with 'tlp-stat'"
else
    echo "- Check power profiles with 'powerprofilesctl list'"
fi
echo "- View sensors with 'sensors'"