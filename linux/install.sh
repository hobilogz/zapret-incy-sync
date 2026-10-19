#!/bin/bash
# Install Zapret & INCY VPN sync systemd daemon on Linux

if [ "$EUID" -ne 0 ]; then
    echo "[!] Пожалуйста, запустите скрипт с правами root:"
    echo "    sudo bash install.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===> Установка Zapret-INCY VPN Sync на Linux..."

# 1. Копируем исполняемый скрипт
mkdir -p /usr/local/bin
cp "$SCRIPT_DIR/zapret-vpn-sync.sh" /usr/local/bin/zapret-vpn-sync.sh
chmod +x /usr/local/bin/zapret-vpn-sync.sh

# 2. Копируем systemd юнит
cp "$SCRIPT_DIR/zapret-vpn-sync.service" /etc/systemd/system/zapret-vpn-sync.service
chmod 644 /etc/systemd/system/zapret-vpn-sync.service

# 3. Перезагружаем systemd и включаем автозапуск службы
systemctl daemon-reload
systemctl enable --now zapret-vpn-sync.service

echo ""
echo "[ГОТОВО] Служба zapret-vpn-sync успешно установлена и запущена!"
echo "Статус службы:"
systemctl status zapret-vpn-sync.service --no-pager
echo ""
echo "Логи работы в реальном времени:"
echo "    journalctl -u zapret-vpn-sync -f"
