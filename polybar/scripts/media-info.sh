#!/usr/bin/env bash
# ---------------------------------------------
#  Now-playing label for the polybar media bar
#  Prints:   <artist> — <title>   (or nothing)
#  Safe when playerctl is not installed.
# ---------------------------------------------

if ! command -v playerctl >/dev/null 2>&1; then
    exit 0
fi

status=$(playerctl status 2>/dev/null)
[ "$status" = "Playing" ] || [ "$status" = "Paused" ] || exit 0

artist=$(playerctl metadata artist 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)

case "$status" in
    Playing) icon="󰏤" ;;   # pause glyph (player is playing)
    Paused)  icon="󰐊" ;;   # play glyph  (player is paused)
    *)       icon="󰓛" ;;
esac

if [ -n "$artist" ] && [ -n "$title" ]; then
    printf '%s  %s — %s' "$icon" "$artist" "$title"
elif [ -n "$title" ]; then
    printf '%s  %s' "$icon" "$title"
fi

