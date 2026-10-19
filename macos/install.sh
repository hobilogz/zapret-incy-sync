#!/bin/bash
# Install Zapret & INCY VPN sync daemon on macOS

if [ "$EUID" -ne 0 ]; then
    echo "[!] Пожалуйста, запустите скрипт с sudo:"
    echo "    sudo bash install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===> Установка Zapret-INCY VPN Sync на macOS..."

# 1. Копируем исполняемый скрипт
mkdir -p /usr/local/bin
cp "$SCRIPT_DIR/zapret-vpn-sync.sh" /usr/local/bin/zapret-vpn-sync.sh
chmod +x /usr/local/bin/zapret-vpn-sync.sh

# 2. Копируем файл службы launchd
cp "$SCRIPT_DIR/com.zapret.vpn-sync.plist" /Library/LaunchDaemons/com.zapret.vpn-sync.plist
chmod 644 /Library/LaunchDaemons/com.zapret.vpn-sync.plist
chown root:wheel /Library/LaunchDaemons/com.zapret.vpn-sync.plist

# 3. Выгружаем старую службу (если была) и регистрируем новую
launchctl unload /Library/LaunchDaemons/com.zapret.vpn-sync.plist 2>/dev/null
launchctl load -w /Library/LaunchDaemons/com.zapret.vpn-sync.plist

echo ""
echo "[ГОТОВО] Служба com.zapret.vpn-sync успешно установлена и запущена в фоне!"
echo "Логи работы можно посмотреть командой:"
echo "    tail -f /var/log/zapret-vpn-sync.log"
