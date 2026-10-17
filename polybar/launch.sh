#!/usr/bin/env bash
# ============================================================
#  Polybar Launcher — MONOCHROME theme
#  Kills existing instances, detects monitors, launches bars.
# ============================================================

BAR_MAIN="main"

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 0.5; done

# Detect the primary network interface for the network module
if command -v ip >/dev/null 2>&1; then
    NETWORK_INTERFACE=$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}')
fi
export NETWORK_INTERFACE="${NETWORK_INTERFACE:-enp2s0}"

# Launch on every connected monitor (xrandr), else just once
if command -v xrandr >/dev/null 2>&1 && xrandr --query >/dev/null 2>&1; then
    for m in $(xrandr --query | awk '/ connected/ {print $1}'); do
        MONITOR="$m" polybar --reload "$BAR_MAIN" >/dev/null 2>&1 &
    done
else
    polybar --reload "$BAR_MAIN" >/dev/null 2>&1 &
fi

echo "Polybar launched."
