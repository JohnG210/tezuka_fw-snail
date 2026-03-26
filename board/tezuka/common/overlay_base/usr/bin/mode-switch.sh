#!/bin/sh
# mode-switch.sh — Lightweight mode manager for Pluto+ SDR
#
# Runs on the Pluto+ device. Can be used in two ways:
#   1. Direct invocation:  ./mode-switch.sh <mode>
#   2. Network listener:   ./mode-switch.sh --listen [port]
#
# Modes: ew, sigint, standby
# Mode files stored in /mnt/sd/modes/<mode>/
# Current mode tracked in /mnt/sd/mode.conf

set -e

SD="/mnt/sd"
MODE_CONF="$SD/mode.conf"
MODES_DIR="$SD/modes"
BOOT_FILES="BOOT.bin system_top.bit.bin uEnv.txt uImage devicetree.dtb uramdisk.image.gz"
LISTEN_PORT="${2:-8080}"

# ── helpers ──────────────────────────────────────────────────────────────────

get_mode() {
    if [ -f "$MODE_CONF" ]; then
        cat "$MODE_CONF" | tr -d '[:space:]'
    else
        echo "unknown"
    fi
}

list_modes() {
    local modes=""
    for d in "$MODES_DIR"/*/; do
        [ -d "$d" ] && modes="$modes $(basename "$d")"
    done
    echo "$modes" | xargs  # trim whitespace
}

validate_mode() {
    local mode="$1"
    case "$mode" in
        ew|sigint|standby) ;;
        *) echo "ERROR: unknown mode '$mode' (expected: ew, sigint, standby)"; return 1 ;;
    esac
    if [ ! -d "$MODES_DIR/$mode" ]; then
        echo "ERROR: mode directory $MODES_DIR/$mode not found"
        return 1
    fi
    # Verify all boot files exist
    for f in $BOOT_FILES; do
        if [ ! -f "$MODES_DIR/$mode/$f" ]; then
            echo "ERROR: missing $MODES_DIR/$mode/$f"
            return 1
        fi
    done
    return 0
}

switch_mode() {
    local target="$1"
    local current
    current=$(get_mode)

    if [ "$target" = "$current" ]; then
        echo "Already in $target mode"
        return 0
    fi

    # Validate target mode
    if ! validate_mode "$target"; then
        return 1
    fi

    echo "Switching from $current to $target..."

    # Copy mode files to boot location
    for f in $BOOT_FILES; do
        cp "$MODES_DIR/$target/$f" "$SD/$f"
    done

    # Update mode.conf
    echo "$target" > "$MODE_CONF"

    # Sync filesystem
    sync

    echo "OK: mode set to $target — rebooting..."
    reboot &
    return 0
}

get_health() {
    local mode uptime_s disk_free
    mode=$(get_mode)
    uptime_s=$(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
    disk_free=$(df /mnt/sd 2>/dev/null | tail -1 | awk '{print $4}')
    echo "mode=$mode uptime=${uptime_s}s disk_free=${disk_free}K modes=$(list_modes)"
}

# ── network listener mode ────────────────────────────────────────────────────

handle_request() {
    # Read one line from stdin, respond on stdout
    read -r line
    local cmd arg
    cmd=$(echo "$line" | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
    arg=$(echo "$line" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

    case "$cmd" in
        MODE?)
            echo "$(get_mode)"
            ;;
        MODE)
            if [ -z "$arg" ]; then
                echo "ERROR: usage: MODE <ew|sigint|standby>"
            else
                switch_mode "$arg"
            fi
            ;;
        MODES?)
            echo "$(list_modes)"
            ;;
        HEALTH?)
            echo "$(get_health)"
            ;;
        HELP|*)
            echo "Commands: MODE? | MODE <name> | MODES? | HEALTH? | HELP"
            ;;
    esac
}

start_listener() {
    echo "mode-switch listener on port $LISTEN_PORT"
    echo "Commands: MODE? | MODE <name> | MODES? | HEALTH?"

    # Use busybox nc (available on Pluto+) in listen mode
    # Each connection handles one command then closes
    while true; do
        handle_request | nc -l -p "$LISTEN_PORT" -w 5 2>/dev/null || true
    done
}

# ── main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
    --listen|-l)
        start_listener
        ;;
    --status|-s)
        echo "Current mode: $(get_mode)"
        echo "Available: $(list_modes)"
        ;;
    --health|-h)
        get_health
        ;;
    ew|sigint|standby)
        switch_mode "$1"
        ;;
    "")
        echo "Usage: $0 <mode>|--listen [port]|--status|--health"
        echo ""
        echo "Direct switch:"
        echo "  $0 ew              Switch to EW mode and reboot"
        echo "  $0 sigint          Switch to Sig Int mode and reboot"
        echo "  $0 standby         Switch to Standby mode and reboot"
        echo ""
        echo "Network:"
        echo "  $0 --listen [port] Start TCP listener (default port 8080)"
        echo "  echo 'MODE?' | nc <pluto-ip> 8080    Query current mode"
        echo "  echo 'MODE ew' | nc <pluto-ip> 8080  Switch mode"
        echo ""
        echo "Status:"
        echo "  $0 --status        Show current mode and available modes"
        echo "  $0 --health        Show health info"
        ;;
    *)
        echo "ERROR: unknown argument '$1'"
        exit 1
        ;;
esac
