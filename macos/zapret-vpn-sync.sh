#!/bin/bash
# Zapret & INCY VPN Synchronizer for macOS
# Monitors INCY VPN connection and automatically starts/stops zapret.

LOG_FILE="/var/log/zapret-vpn-sync.log"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE" 2>/dev/null
}

is_incy_active() {
    # 1. Check if default gateway interface is a utun tunnel
    local def_if
    def_if=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    if [[ "$def_if" == utun* ]]; then
        return 0
    fi

    # 2. Check if an active utun interface exists with INCY's 198.18.x.x subnet
    if ifconfig 2>/dev/null | grep -B 2 -E "inet 198\.18\." | grep -q "utun"; then
        return 0
    fi

    return 1
}

stop_zapret() {
    log "Stopping zapret..."
    local stopped=0

    # Official zapret init script for macOS (flushes pf anchor rules and terminates daemon)
    if [ -x "/opt/zapret/init.d/macos/zapret" ]; then
        /opt/zapret/init.d/macos/zapret stop >/dev/null 2>&1
        stopped=1
    fi

    # Check launchd daemon
    if [ -f "/Library/LaunchDaemons/zapret.plist" ]; then
        launchctl unload /Library/LaunchDaemons/zapret.plist >/dev/null 2>&1
        stopped=1
    fi

    # Fallback: kill tpws or nfqws if still running
    pkill -f "tpws" >/dev/null 2>&1
    pkill -f "nfqws" >/dev/null 2>&1

    log "[SUCCESS] Zapret stopped."
}

start_zapret() {
    log "Starting zapret..."
    local started=0

    # Official zapret init script for macOS (configures pf rules and starts tpws)
    if [ -x "/opt/zapret/init.d/macos/zapret" ]; then
        /opt/zapret/init.d/macos/zapret start >/dev/null 2>&1
        started=1
    fi

    # Check launchd daemon
    if [ -f "/Library/LaunchDaemons/zapret.plist" ]; then
        launchctl load /Library/LaunchDaemons/zapret.plist >/dev/null 2>&1
        started=1
    fi

    log "[SUCCESS] Zapret started."
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
