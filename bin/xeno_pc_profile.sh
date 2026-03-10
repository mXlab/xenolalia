#!/usr/bin/env bash
# Switch XenoPC between presentation and development profiles.
#
# Usage:
#   xeno_pc_profile.sh presentation   — suppress all popups/notifications
#   xeno_pc_profile.sh development    — restore normal system notifications

set -e

usage() {
    echo "Usage: $0 {presentation|development}"
    echo ""
    echo "  presentation   Suppress popups and notifications (for visitors)"
    echo "  development    Restore normal system notifications (for maintenance)"
    exit 1
}

[ $# -eq 1 ] || usage
mode="$1"

case "$mode" in
    presentation|development) ;;
    -h|--help) usage ;;
    *) usage ;;
esac

echo "=== XenoPC profile: $mode ==="

# 1. Apport crash reporter.
echo "[1/4] Apport crash reporter..."
if [ "$mode" = "presentation" ]; then
    sudo systemctl stop apport 2>/dev/null || true
    sudo systemctl disable apport 2>/dev/null || true
    sudo sed -i 's/^enabled=1/enabled=0/' /etc/default/apport
    sudo rm -f /var/crash/*
else
    sudo sed -i 's/^enabled=0/enabled=1/' /etc/default/apport
    sudo systemctl enable apport 2>/dev/null || true
    sudo systemctl start apport 2>/dev/null || true
fi
echo "      Done."

# 2. Software update notifications.
echo "[2/4] Update notifications..."
desktop_file="/etc/xdg/autostart/update-notifier.desktop"
if [ -f "$desktop_file" ]; then
    if [ "$mode" = "presentation" ]; then
        sudo sed -i 's/^X-GNOME-Autostart-enabled=true/X-GNOME-Autostart-enabled=false/' "$desktop_file"
        sudo grep -q "^X-GNOME-Autostart-enabled" "$desktop_file" \
            || echo "X-GNOME-Autostart-enabled=false" | sudo tee -a "$desktop_file" > /dev/null
    else
        sudo sed -i 's/^X-GNOME-Autostart-enabled=false/X-GNOME-Autostart-enabled=true/' "$desktop_file"
    fi
fi
echo "      Done."

# 3. Unattended-upgrades auto-reboot.
echo "[3/4] Unattended-upgrades auto-reboot..."
upgrades_conf="/etc/apt/apt.conf.d/50unattended-upgrades"
if [ -f "$upgrades_conf" ]; then
    if [ "$mode" = "presentation" ]; then
        sudo sed -i \
            's|//Unattended-Upgrade::Automatic-Reboot "false"|Unattended-Upgrade::Automatic-Reboot "false";|' \
            "$upgrades_conf"
        sudo sed -i \
            's|Unattended-Upgrade::Automatic-Reboot "true"|Unattended-Upgrade::Automatic-Reboot "false";|' \
            "$upgrades_conf"
    else
        sudo sed -i \
            's|Unattended-Upgrade::Automatic-Reboot "false";|//Unattended-Upgrade::Automatic-Reboot "false"|' \
            "$upgrades_conf"
    fi
fi
echo "      Done."

# 4. GNOME notification banners (no sudo needed).
echo "[4/4] GNOME notification banners..."
if [ "$mode" = "presentation" ]; then
    gsettings set org.gnome.desktop.notifications show-banners false
    gsettings set org.gnome.desktop.notifications show-in-lock-screen false
else
    gsettings set org.gnome.desktop.notifications show-banners true
    gsettings set org.gnome.desktop.notifications show-in-lock-screen true
fi
echo "      Done."

echo ""
if [ "$mode" = "presentation" ]; then
    echo "Presentation mode ON. All popups suppressed."
    echo "Run '$0 development' to restore normal behaviour."
else
    echo "Development mode ON. Normal system notifications restored."
    echo "Run '$0 presentation' to suppress popups for visitors."
fi
