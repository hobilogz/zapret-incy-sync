#!/bin/bash
# Uninstall Zapret & INCY VPN sync daemon on macOS

if [ "$EUID" -ne 0 ]; then
    echo "[!] Пожалуйста, запустите скрипт с sudo:"
    echo "    sudo bash uninstall.sh"
    exit 1
fi

echo "===> Удаление Zapret-INCY VPN Sync..."

launchctl unload /Library/LaunchDaemons/com.zapret.vpn-sync.plist 2>/dev/null
rm -f /Library/LaunchDaemons/com.zapret.vpn-sync.plist
rm -f /usr/local/bin/zapret-vpn-sync.sh

echo "[ГОТОВО] Служба удалена из системы."
