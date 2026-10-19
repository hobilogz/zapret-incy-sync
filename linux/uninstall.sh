#!/bin/bash
# Uninstall Zapret & INCY VPN sync daemon on Linux

if [ "$EUID" -ne 0 ]; then
    echo "[!] Пожалуйста, запустите скрипт с правами root:"
    echo "    sudo bash uninstall.sh"
    exit 1
fi

echo "===> Удаление Zapret-INCY VPN Sync..."

systemctl disable --now zapret-vpn-sync.service 2>/dev/null
rm -f /etc/systemd/system/zapret-vpn-sync.service
rm -f /usr/local/bin/zapret-vpn-sync.sh
systemctl daemon-reload

echo "[ГОТОВО] Служба zapret-vpn-sync успешно удалена."
