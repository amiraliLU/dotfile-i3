#!/usr/bin/env bash
# ============================================================
#  install.sh — install the config folders into ~/.config
#
#  Every top-level folder in this repo is treated as an
#  application config directory and is installed to
#  ~/.config/<folder-name>:
#
#      dotfiles/i3       ->  ~/.config/i3
#      dotfiles/polybar  ->  ~/.config/polybar
#      ...
#
#  Usage:
#      ./install.sh                  # symlink folders (default)
#      ./install.sh --copy           # copy folders instead of linking
#      ./install.sh --unlink         # remove installed links/copies
#      ./install.sh i3 polybar       # only these apps
#      ./install.sh --copy rofi      # copy only rofi
#      ./install.sh --deps           # only check/install dependencies
#      ./install.sh --no-deps        # skip the dependency check
#
#  Existing files at the target are moved to
#  <name>.bak.<timestamp> before being replaced.
# ============================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

MODE="link"
DEPS="ask"
DEPS_ARGS=()
APPS=()

usage() {
    sed -n '2,23p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

# ---- parse arguments ----------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --copy|-c)   MODE="copy" ;;
        --link|-l)   MODE="link" ;;
        --unlink|-u) MODE="unlink" ;;
        --deps)      DEPS="only" ;;
        --no-deps)   DEPS="skip" ;;
        --yes|-y)    DEPS_ARGS+=(--yes) ;;
        --aur)       DEPS_ARGS+=(--aur) ;;
        -h|--help)   usage 0 ;;
        -*)          echo "unknown option: $1" >&2; usage 1 ;;
        *)           APPS+=("$1") ;;
    esac
    shift
done

# ---- dependencies -------------------------------------------
#  The deps script lives next to this one. It reports what is
#  missing and can install it. Never runs for --unlink.
check_deps() {
    local script="$DOTFILES_DIR/install-deps.sh"
    [ -x "$script" ] || [ -f "$script" ] || return 0

    echo "==> dependency check"
    bash "$script" "$@" || true
    echo
}

if [ "$DEPS" = "only" ]; then
    check_deps "${DEPS_ARGS[@]}"
    exit 0
fi

if [ "$DEPS" = "ask" ] && [ "$MODE" != "unlink" ]; then
    if [ "$(id -u)" = 0 ] || command -v sudo >/dev/null 2>&1; then
        printf 'Check and install missing dependencies first? [Y/n] '
        read -r _reply || _reply=""
        case "$_reply" in
            [nN]|[nN][oO]) check_deps --dry-run ;;
            *)             check_deps "${DEPS_ARGS[@]}" ;;
        esac
    else
        # no sudo available, so only report
        check_deps --dry-run
    fi
fi

# ---- discover app folders -----------------------------------
discover() {
    local d
    for d in "$DOTFILES_DIR"/*/; do
        [ -d "$d" ] || continue
        basename "$d"
    done
}

if [ ${#APPS[@]} -eq 0 ]; then
    mapfile -t APPS < <(discover)
fi

backup() {
    local dst="$1"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local b="${dst}.bak.$(date +%s)"
        mv "$dst" "$b"
        echo "  backup: $dst -> $b"
    fi
}

install_one() {
    local app="$1" src="$DOTFILES_DIR/$1" dst="$CONFIG_DIR/$1"

    if [ ! -d "$src" ]; then
        echo "  skip:   $app (no such folder in $DOTFILES_DIR)" >&2
        return
    fi

    mkdir -p "$CONFIG_DIR"

    if [ "$MODE" = "link" ]; then
        if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$src" ]; then
            echo "  ok:     $dst -> $src (already linked)"
            return
        fi
        backup "$dst"
        ln -s "$src" "$dst"
        echo "  linked: $dst -> $src"
    else
        backup "$dst"
        cp -a "$src" "$dst"
        echo "  copied: $src -> $dst"
    fi
}

uninstall_one() {
    local app="$1" dst="$CONFIG_DIR/$1"

    if [ -L "$dst" ]; then
        rm -f "$dst"
        echo "  unlinked: $dst"
    elif [ -d "$dst" ]; then
        local b="${dst}.bak.$(date +%s)"
        mv "$dst" "$b"
        echo "  moved:    $dst -> $b"
    else
        echo "  skip:     $dst (not installed)"
    fi
}

# ---- run ----------------------------------------------------
echo "dotfiles : $DOTFILES_DIR"
echo "target   : $CONFIG_DIR"
echo "mode     : $MODE"
echo

for app in "${APPS[@]}"; do
    case "$MODE" in
        unlink) uninstall_one "$app" ;;
        *)      install_one "$app" ;;
    esac
done

echo
if [ "$MODE" = "unlink" ]; then
    echo "Done. Removed ${#APPS[@]} entr(y|ies)."
else
    echo "Done. Reload with \$mod+Shift+r in i3, or log out and back in."
fi
