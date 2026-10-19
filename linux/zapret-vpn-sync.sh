#!/bin/bash
# Zapret & INCY VPN Synchronizer for Linux
# Monitors INCY VPN connection and automatically starts/stops zapret.

LOG_TAG="zapret-vpn-sync"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    # Also log to systemd journal / syslog if logger exists
    if command -v logger >/dev/null 2>&1; then
        logger -t "$LOG_TAG" "$1"
    fi
}

is_incy_active() {
    # 1. Check if default gateway interface is a TUN / virtual adapter (tun*, wwan*, incy*)
    local def_if
    def_if=$(ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
    if [[ "$def_if" == tun* || "$def_if" == wwan* || "$def_if" == incy* ]]; then
        return 0
    fi

    # 2. Check if an active interface has an IP in 198.18.0.0/15 (standard INCY / sing-box fake-ip range)
    if ip -4 addr show 2>/dev/null | grep -q "inet 198\.18\."; then
        return 0
    fi

    return 1
}

stop_zapret() {
    log "Stopping zapret..."

    # Check systemd service first
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet zapret 2>/dev/null; then
            systemctl stop zapret >/dev/null 2>&1
            log "[SUCCESS] Service 'zapret' stopped via systemctl."
            return
        fi
    fi

    # Official zapret init.d script
    if [ -x "/opt/zapret/init.d/sysv/zapret" ]; then
        /opt/zapret/init.d/sysv/zapret stop >/dev/null 2>&1
        log "[SUCCESS] Zapret stopped via /opt/zapret/init.d/sysv/zapret."
        return
    fi

    # Fallback to service command
    if command -v service >/dev/null 2>&1; then
        service zapret stop >/dev/null 2>&1
    fi

    # Fallback: terminate nfqws / tpws processes if still running
    pkill -f "nfqws" >/dev/null 2>&1
    pkill -f "tpws" >/dev/null 2>&1
    log "[INFO] Zapret stopped."
}

start_zapret() {
    log "Starting zapret..."

    # Check systemd service first
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl list-unit-files zapret.service 2>/dev/null | grep -q "zapret.service"; then
            systemctl start zapret >/dev/null 2>&1
            log "[SUCCESS] Service 'zapret' started via systemctl."
            return
        fi
    fi

    # Official zapret init.d script
    if [ -x "/opt/zapret/init.d/sysv/zapret" ]; then
        /opt/zapret/init.d/sysv/zapret start >/dev/null 2>&1
        log "[SUCCESS] Zapret started via /opt/zapret/init.d/sysv/zapret."
        return
    fi

    # Fallback to service command
    if command -v service >/dev/null 2>&1; then
        service zapret start >/dev/null 2>&1
    fi

    log "[INFO] Zapret started."
}

log "Zapret-INCY VPN sync daemon started."

LAST_STATE=""

while true; do
    if is_incy_active; then
        CURRENT_STATE="vpn"
    else
        CURRENT_STATE="direct"
    fi

    if [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
        if [ "$CURRENT_STATE" == "vpn" ]; then
            log "[STATUS] INCY VPN connected. Stopping zapret..."
            stop_zapret
        else
            log "[STATUS] INCY VPN disconnected. Starting zapret..."
            start_zapret
        fi
        LAST_STATE="$CURRENT_STATE"
    fi

    # Sleep consumes 0.0% CPU
    sleep 2
done
