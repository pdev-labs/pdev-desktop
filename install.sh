#!/usr/bin/env bash
# Install the pdev-labs desktop configuration.
#
#   bash install.sh                 # configs + theme + services
#   bash install.sh --packages      # also install curated packages
#   sudo -v; bash install.sh --packages --yes
#   bash install.sh --from-backup ~/backups/dotfiles-....tar.zst
#
# Options:
#   --packages       install dotfiles/packages/desktop.txt with pacman --needed
#   --all-packages   install every explicitly installed repo package (careful)
#   --aur            install dotfiles/packages/aur-desktop.txt with yay (clipse)
#   --from-backup F  restore from a dotfiles-*.tar.zst archive
#   --dry-run        print actions, change nothing
#   --yes            do not prompt
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES="${DOTFILES:-$SCRIPT_DIR/dotfiles}"
STAMP="$(date +%Y-%m-%d-%H%M%S)"
BACKUP_DIR="$HOME/backups/pre-apply-$STAMP"
DRY=0
INSTALL=0
ALL_PACKAGES=0
AUR=0
ASSUME_YES=0
FROM_BACKUP=""
TMP=""

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while (($#)); do
    case "$1" in
        --packages) INSTALL=1 ;;
        --all-packages) INSTALL=1; ALL_PACKAGES=1 ;;
        --aur) AUR=1 ;;
        --from-backup) FROM_BACKUP="${2:?--from-backup needs a file}"; shift ;;
        --dry-run) DRY=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        -h|--help) usage 0 ;;
        *) echo "unknown option: $1" >&2; usage 2 ;;
    esac
    shift
done

if ((EUID == 0)); then
    echo "Run this as your user, not with sudo. It calls sudo only for packages." >&2
    exit 1
fi

run() {
    if ((DRY)); then
        printf '  + %s\n' "$*"
    else
        "$@"
    fi
}

confirm() {
    ((ASSUME_YES)) && return 0
    [[ -t 0 ]] || { echo "non-interactive shell; pass --yes" >&2; return 1; }
    local answer
    read -r -p "$1 [y/N] " answer
    [[ "$answer" == [yY]* ]]
}

if [[ -n "$FROM_BACKUP" ]]; then
    [[ -f "$FROM_BACKUP" ]] || { echo "no such archive: $FROM_BACKUP" >&2; exit 1; }
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    echo "Extracting $FROM_BACKUP"
    tar -I zstd -xf "$FROM_BACKUP" -C "$TMP"
    DOTFILES="$TMP/dotfiles"
fi

SRC="$DOTFILES/home"
[[ -d "$SRC" ]] || { echo "missing $SRC — run ~/tools/backup-configs.sh first" >&2; exit 1; }

PATHS=(
    .config/hypr
    .config/waybar
    .config/wofi
    .config/kitty
    .config/ghostty
    .config/swaync
    .config/qt6ct
    .config/gtk-3.0
    .config/gtk-4.0
    .config/starship.toml
    .config/omniroute/env
    .config/fastfetch
    .config/bat
    .config/htop
    .config/lsd
    .config/nvim
    .config/dolphinrc
    .config/pavucontrol.ini
    .config/autostart
    .config/systemd
    .config/yay
    .bashrc
    .bash_profile
    .profile
    .tmux.conf
    .icons/Adwaita-Tiny
    wallpaper
)

# ── Packages ──────────────────────────────────────────────────────────────
if ((INSTALL)); then
    if ((ALL_PACKAGES)); then
        LIST="$DOTFILES/packages/native-explicit.txt"
        echo "WARNING: --all-packages installs every explicit repo package."
    else
        LIST="$DOTFILES/packages/desktop.txt"
    fi
    [[ -f "$LIST" ]] || { echo "missing package list: $LIST" >&2; exit 1; }
    mapfile -t PKGS < <(grep -vE '^\s*(#|$)' "$LIST")
    echo "Packages: ${#PKGS[@]} from ${LIST##*/}"
    if confirm "Install with pacman --needed?"; then
        SUDO=""
        ((EUID != 0)) && SUDO="sudo"
        run $SUDO pacman -S --needed --noconfirm "${PKGS[@]}"
        run $SUDO systemctl enable --now NetworkManager
        run $SUDO systemctl enable --now bluetooth
    fi
    if ((AUR)); then
        if command -v yay >/dev/null 2>&1; then
            AUR_LIST="$DOTFILES/packages/aur-desktop.txt"
            ((ALL_PACKAGES)) && AUR_LIST="$DOTFILES/packages/aur-explicit.txt"
            mapfile -t AUR_PKGS < <(grep -vE '^\s*(#|$)' "$AUR_LIST")
            echo "AUR packages: ${#AUR_PKGS[@]} from ${AUR_LIST##*/}"
            run yay -S --needed --noconfirm "${AUR_PKGS[@]}"
        else
            echo "yay not found; install AUR packages manually:"
            cat "$DOTFILES/packages/aur-explicit.txt"
        fi
    fi
fi

# ── Back up what is about to be replaced ──────────────────────────────────
echo "Backing up current files to $BACKUP_DIR"
if ((!DRY)); then
    mkdir -p "$BACKUP_DIR"
fi
for rel in "${PATHS[@]}"; do
    [[ -e "$HOME/$rel" ]] || continue
    run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    run cp -a "$HOME/$rel" "$BACKUP_DIR/$(dirname "$rel")/"
done
if [[ -d "$HOME/tools" ]]; then
    run mkdir -p "$BACKUP_DIR/tools"
    run bash -c 'cp -a "$HOME"/tools/*.sh "$1"/ 2>/dev/null || true' _ "$BACKUP_DIR/tools"
fi

# ── Restore ───────────────────────────────────────────────────────────────
echo "Applying $SRC -> $HOME"
run rsync -a "$SRC/" "$HOME/"

if ((!DRY)); then
    [[ -d "$HOME/.config/omniroute" ]] && chmod 600 "$HOME/.config/omniroute/env" 2>/dev/null || true
    find "$HOME/tools" "$HOME/.config/hypr/scripts" "$HOME/.config/waybar/scripts" \
        -maxdepth 1 -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

    # Make absolute paths portable if this is restored under another $HOME.
    mapfile -d '' TEXT_FILES < <(
        grep -RIlZ '/home/pdev' \
            --include='*.lua' --include='*.conf' --include='*.json' \
            --include='*.jsonc' --include='*.css' --include='*.sh' \
            --include='*.toml' --include='*.ini' \
            "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/wofi" \
            "$HOME/.config/kitty" "$HOME/.config/swaync" "$HOME/.config/qt6ct" \
            "$HOME/.config/ghostty" "$HOME/.config/starship.toml" \
            "$HOME/.bashrc" "$HOME/.tmux.conf" "$HOME/tools" 2>/dev/null || true
    )
    for f in "${TEXT_FILES[@]}"; do
        [[ -f "$f" ]] || continue
        sed -i "s#/home/pdev#$HOME#g" "$f"
    done
fi

# ── Services and theme ────────────────────────────────────────────────────
if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]] \
   && systemctl --user show-environment >/dev/null 2>&1; then
    run systemctl --user daemon-reload
    if systemctl --user list-unit-files swaync.service >/dev/null 2>&1; then
        run systemctl --user enable --now swaync
    fi
fi

if [[ -d /usr/share/themes/adw-gtk3-dark ]]; then
    run bash "$SCRIPT_DIR/apply-gtk-theme.sh"
else
    echo
    echo "GTK theme still missing. Run:"
    echo "  sudo pacman -S adw-gtk-theme papirus-icon-theme"
    echo "  bash apply-gtk-theme.sh"
fi

if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    run hyprctl reload
    if pgrep -x waybar >/dev/null; then
        run pkill -SIGUSR2 waybar
    fi
    run systemctl --user restart swaync 2>/dev/null || true
fi

# ── Validation ────────────────────────────────────────────────────────────
if ((!DRY)); then
    echo
    echo "Validation:"
    ok=1

    if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        err="$(hyprctl configerrors 2>/dev/null || true)"
        if [[ -n "${err//[[:space:]]/}" ]]; then
            echo "  hyprland: ERRORS"
            echo "$err" | sed 's/^/    /'
            ok=0
        else
            echo "  hyprland: ok"
        fi
    fi

    if python3 - "$HOME/.config/waybar/config.jsonc" "$HOME/.config/swaync/config.json" <<'PY'
import json, sys
for path in sys.argv[1:]:
    json.load(open(path))
PY
    then
        echo "  json: ok"
    else
        echo "  json: INVALID"
        ok=0
    fi

    for f in "$HOME"/tools/*.sh "$HOME"/.config/hypr/scripts/*.sh "$HOME"/.config/waybar/scripts/*.sh; do
        [[ -f "$f" ]] || continue
        bash -n "$f" || { echo "  bash: $f"; ok=0; }
    done
    echo "  scripts: checked"

    if command -v kitty >/dev/null 2>&1; then
        if kitty +runpy "from kitty.config import load_config; load_config('$HOME/.config/kitty/kitty.conf')" >/dev/null 2>&1; then
            echo "  kitty: ok"
        else
            echo "  kitty: parse failed"
            ok=0
        fi
    fi

    ((ok)) || echo "  -> see errors above"
fi

echo
echo "Done."
echo "  replaced files: $BACKUP_DIR"
echo "  dotfiles:       $DOTFILES"
echo "  next: reopen GTK/Qt apps; log out and back in for env vars."
echo "  source repo: $SCRIPT_DIR"
