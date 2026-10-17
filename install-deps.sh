#!/usr/bin/env bash
# ============================================================
#  install-deps.sh — check & install the packages the configs need
#
#  Scans the configs for required programs/fonts, reports which
#  are missing, and installs the missing ones with pacman.
#  The AUR is only used when you pass --aur and yay/paru exists.
#
#  Usage:
#      ./install-deps.sh                # report, then install missing
#      ./install-deps.sh --dry-run      # report only, install nothing
#      ./install-deps.sh --yes          # no confirmation prompt
#      ./install-deps.sh --aur          # also allow AUR packages
#      ./install-deps.sh --help
# ============================================================
set -euo pipefail

DRY_RUN=0
ASSUME_YES=0
ALLOW_AUR=0
AUR_HELPER=""

usage() {
    sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run|-n) DRY_RUN=1 ;;
        --yes|-y)     ASSUME_YES=1 ;;
        --aur)        ALLOW_AUR=1 ;;
        -h|--help)    usage 0 ;;
        *) echo "unknown option: $1" >&2; usage 1 ;;
    esac
    shift
done

# ---- colours (only when attached to a terminal) -------------
if [ -t 1 ]; then
    R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; N=$'\e[0m'
else
    R=""; G=""; Y=""; B=""; N=""
fi

# ---- what the configs require -------------------------------
#  package|binary|what it is for
REQUIRED=(
    "i3-wm|i3|i3 window manager"
    "i3status|i3status|i3 bar status generator"
    "polybar|polybar|status bar"
    "picom|picom|compositor (shadows, blur, transparency)"
    "rofi|rofi|app launcher / dmenu replacement"
    "feh|feh|sets the wallpaper from i3/config"
    "dex|dex|runs XDG autostart .desktop files"
    "xss-lock|xss-lock|locks the screen on suspend"
    "i3lock|i3lock|screen locker used by xss-lock"
    "network-manager-applet|nm-applet|tray network icon"
    "libpulse|pactl|volume keys (XF86Audio*)"
    "xorg-setxkbmap|setxkbmap|us/ir keyboard layout toggle"
    "playerctl|playerctl|media-info.sh now-playing label"
    "xorg-xrandr|xrandr|per-monitor polybar launch"
    "dmenu|dmenu_run|fallback launcher bound in i3"
    "iproute2|ip|default-network detection in launch.sh"
    "fastfetch|fastfetch|system info fetch (fastfetch config)"
)

#  file to look for|package|what it is for
FONTS=(
    "/usr/share/fonts/noto/NotoColorEmoji.ttf|noto-fonts-emoji|emoji glyphs in the polybar"
)

# Nerd Font may be installed system-wide or per-user.
NERD_FONT_PATHS=(
    "/usr/share/fonts/TTF/SymbolsNerdFontMono-Regular.ttf"
    "$HOME/.local/share/fonts/SymbolsNerdFontMono-Regular.ttf"
)
NERD_FONT_PKG="ttf-nerd-fonts-symbols"

MISSING_PKGS=()
WARNINGS=()

have_bin() { command -v "$1" >/dev/null 2>&1; }
have_font() {
    local name="$1"
    command -v fc-list >/dev/null 2>&1 && fc-list 2>/dev/null | grep -qi "$name"
}

echo "${B}Checking dependencies for the i3 / polybar / picom / rofi configs${N}"
echo

# ---- programs -----------------------------------------------
printf '%s\n' "${B}Programs${N}"
for entry in "${REQUIRED[@]}"; do
    IFS='|' read -r pkg bin what <<<"$entry"
    if have_bin "$bin"; then
        printf '  %s✓%s %-14s %s\n' "$G" "$N" "$bin" "$what"
    else
        printf '  %s✗%s %-14s %s  %s(needs %s)%s\n' "$R" "$N" "$bin" "$what" "$Y" "$pkg" "$N"
        MISSING_PKGS+=("$pkg")
    fi
done

# ---- fonts --------------------------------------------------
echo
printf '%s\n' "${B}Fonts${N}"
for entry in "${FONTS[@]}"; do
    IFS='|' read -r path pkg what <<<"$entry"
    if [ -e "$path" ] || have_font "$(basename "$path" .ttf | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')"; then
        printf '  %s✓%s %-14s %s\n' "$G" "$N" "$pkg" "$what"
    else
        printf '  %s✗%s %-14s %s  %s(needs %s)%s\n' "$R" "$N" "$pkg" "$what" "$Y" "$pkg" "$N"
        MISSING_PKGS+=("$pkg")
    fi
done

nerd_found=0
for p in "${NERD_FONT_PATHS[@]}"; do
    [ -e "$p" ] && nerd_found=1
done
if [ "$nerd_found" = 1 ] || have_font "Nerd Font"; then
    printf '  %s✓%s %-14s icon glyphs in the polybar\n' "$G" "$N" "$NERD_FONT_PKG"
else
    printf '  %s✗%s %-14s icon glyphs in the polybar  %s(needs %s)%s\n' \
        "$R" "$N" "$NERD_FONT_PKG" "$Y" "$NERD_FONT_PKG" "$N"
    MISSING_PKGS+=("$NERD_FONT_PKG")
fi

# Adwaita Mono is part of adwaita-fonts on Arch.
if [ -e /usr/share/fonts/Adwaita/AdwaitaMono-Regular.ttf ] || have_font "Adwaita Mono"; then
    printf '  %s✓%s %-14s bar text font\n' "$G" "$N" "adwaita-fonts"
else
    printf '  %s✗%s %-14s bar text font  %s(needs %s)%s\n' \
        "$R" "$N" "adwaita-fonts" "$Y" "adwaita-fonts" "$N"
    MISSING_PKGS+=("adwaita-fonts")
fi

# ---- picom blur capability ----------------------------------
echo
printf '%s\n' "${B}Compositor features${N}"
if have_bin picom; then
    if picom --help 2>&1 | grep -q dual_kawase; then
        printf '  %s✓%s dual_kawase blur available (picom.conf uses it)\n' "$G" "$N"
    else
        printf '  %s✗%s this picom has no dual_kawase blur\n' "$R" "$N"
        printf '      picom.conf sets blur-method = "dual_kawase";\n'
        printf '      install the AUR fork:  %spicom-pijulius-next-git%s\n' "$Y" "$N"
        printf '      or set blur-background = false in picom/picom.conf.\n'
        WARNINGS+=("picom-pijulius-next-git")
    fi
fi

# ---- summary -------------------------------------------------
echo
if [ ${#MISSING_PKGS[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "${G}All dependencies are installed.${N}"
    exit 0
fi

if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
    echo "${G}All required dependencies are installed.${N}"
    echo "Only the optional AUR item(s) below are missing."
fi

# de-duplicate while keeping order
UNIQUE_PKGS=()
for p in "${MISSING_PKGS[@]}"; do
    skip=0
    for u in "${UNIQUE_PKGS[@]:-}"; do [ "$u" = "$p" ] && skip=1; done
    [ "$skip" = 1 ] || UNIQUE_PKGS+=("$p")
done

if [ ${#UNIQUE_PKGS[@]} -gt 0 ]; then
    echo "${B}Missing packages (${#UNIQUE_PKGS[@]}):${N} ${UNIQUE_PKGS[*]}"
fi

if [ "$DRY_RUN" = 1 ]; then
    echo
    echo "--dry-run: nothing installed. Re-run without --dry-run to install."
    exit 0
fi

# ---- pick a package manager ---------------------------------
if ! command -v pacman >/dev/null 2>&1; then
    echo "${R}error:${N} pacman not found — this installer only supports Arch Linux." >&2
    exit 1
fi

if [ "$ALLOW_AUR" = 1 ]; then
    for h in yay paru; do
        command -v "$h" >/dev/null 2>&1 && AUR_HELPER="$h" && break
    done
fi

if [ ${#UNIQUE_PKGS[@]} -gt 0 ] && [ "$ASSUME_YES" != 1 ]; then
    printf 'Install these with pacman? [y/N] '
    read -r reply
    case "$reply" in [yY]|[yY][eE][sS]) ;; *) echo "Aborted."; exit 0 ;; esac
fi

if [ ${#UNIQUE_PKGS[@]} -gt 0 ]; then
    echo
    echo "${B}==>${N} sudo pacman -S --needed ${UNIQUE_PKGS[*]}"
    sudo pacman -S --needed "${UNIQUE_PKGS[@]}"
fi

if [ ${#WARNINGS[@]} -gt 0 ] && [ -n "$AUR_HELPER" ]; then
    echo
    echo "${B}==>${N} $AUR_HELPER -S --needed ${WARNINGS[*]}"
    "$AUR_HELPER" -S --needed "${WARNINGS[@]}"
elif [ ${#WARNINGS[@]} -gt 0 ]; then
    echo
    echo "${Y}Not installing ${WARNINGS[*]} (AUR, pass --aur to allow it).${N}"
fi

echo
echo "${G}Done.${N} Log out and back in (or press \$mod+Shift+r in i3)."
