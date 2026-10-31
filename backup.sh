#!/usr/bin/env bash
# Refresh ./dotfiles from the current machine and write a timestamped archive
# to ~/backups. No credentials or browser profiles are captured.
#
#   bash backup.sh
#   sudo bash backup.sh --system   # also selected /etc files
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_ROOT="${DEST_ROOT:-$HOME/backups}"
DOTFILES="${DOTFILES:-$SCRIPT_DIR/dotfiles}"
STAMP="$(date +%Y-%m-%d-%H%M%S)"
ARCHIVE="$DEST_ROOT/dotfiles-$STAMP.tar.zst"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
umask 077

WITH_SYSTEM=0
for arg in "$@"; do
    case "$arg" in
        --system) WITH_SYSTEM=1 ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "unknown option: $arg" >&2
            exit 2
            ;;
    esac
done

SRC="$TMP/dotfiles"
mkdir -p "$SRC/home" "$SRC/packages"

# Only real configuration. Browser profiles, clipboard history and package
# caches are deliberately excluded.
PATHS=(
    .config/hypr
    .config/waybar
    .config/wofi
    .config/kitty
    .config/ghostty
    .config/swaync
    .config/qt6ct
    .config/starship.toml
    .config/fastfetch
    .config/bat
    .config/htop
    .config/lsd
    .config/nvim
    .bashrc
    .bash_profile
    .profile
    .tmux.conf
    .icons/Adwaita-Tiny
    wallpaper
)

for rel in "${PATHS[@]}"; do
    [[ -e "$HOME/$rel" ]] || continue
    mkdir -p "$SRC/home/$(dirname "$rel")"
    rsync -a --exclude='*.bak-*' --exclude='*.log' \
        --exclude='__pycache__' --exclude='*.disabled' \
        "$HOME/$rel" "$SRC/home/$(dirname "$rel")/"
done

# ── Manifests ─────────────────────────────────────────────────────────────
mkdir -p "$SRC/packages/optional"
pacman -Qqen > "$SRC/packages/optional/native-explicit.txt"
pacman -Qqem > "$SRC/packages/optional/aur-explicit.txt"

cat > "$SRC/packages/desktop.txt" <<'EOF'
# Curated packages needed by this desktop. `install.sh --packages`
# installs them with pacman --needed. AUR-only packages are listed in
# aur-explicit.txt (install those with yay).
hyprland
hyprlock
hypridle
hyprpolkitagent
waybar
wofi
kitty
ghostty
swaync
swaybg
xdg-desktop-portal-hyprland
xdg-desktop-portal-gtk
polkit
qt6ct
adw-gtk-theme
papirus-icon-theme
ttf-jetbrains-mono-nerd
noto-fonts
noto-fonts-emoji
pipewire
pipewire-pulse
wireplumber
pavucontrol
playerctl
brightnessctl
blueman
bluez
bluez-utils
networkmanager
libnotify
grim
slurp
wl-clipboard
starship
tmux
zoxide
eza
bat
fd
ripgrep
fzf
btop
fastfetch
less
git
python
jq
rsync
zstd
firefox
nautilus
EOF

cat > "$SRC/packages/aur-desktop.txt" <<'EOF'
# AUR-only packages the desktop actually needs. `--aur` installs these;
# `--all-packages --aur` installs every foreign package instead.
clipse
EOF

{
    echo "date=$STAMP"
    echo "host=$(uname -n)"
    echo "user=${USER:-$(id -un)}"
    echo "home=$HOME"
    echo "kernel=$(uname -r)"
    echo "hyprland=$(pacman -Q hyprland 2>/dev/null || echo unknown)"
    echo "waybar=$(pacman -Q waybar 2>/dev/null || echo unknown)"
    echo "hyprlock=$(pacman -Q hyprlock 2>/dev/null || echo unknown)"
    echo "swaync=$(pacman -Q swaync 2>/dev/null || echo unknown)"
    echo "kitty=$(pacman -Q kitty 2>/dev/null || echo unknown)"
} > "$SRC/manifest.txt"

systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null \
    > "$SRC/manifest-user-services.txt" || true
gsettings list-recursively org.gnome.desktop.interface 2>/dev/null \
    > "$SRC/manifest-gsettings.txt" || true

# ── Optional /etc core files ──────────────────────────────────────────────
if (( WITH_SYSTEM )); then
    SYS_PATHS=(
        etc/fstab
        etc/default/grub
        etc/mkinitcpio.conf
        etc/pacman.conf
        etc/ssh/sshd_config
        etc/hosts
        etc/hostname
        etc/locale.conf
        etc/vconsole.conf
        etc/sudoers
        etc/sudoers.d
        etc/systemd/system
        etc/udev/rules.d
        etc/modprobe.d
        etc/X11/xorg.conf.d
    )
    existing=()
    for p in "${SYS_PATHS[@]}"; do
        [[ -e "/$p" ]] && existing+=("$p")
    done
    if ((${#existing[@]})); then
        echo "Copying ${#existing[@]} system paths from /etc (sudo required)..."
        (cd / && sudo rsync -aR "${existing[@]}" "$SRC/system/")
    fi
fi

# ── Publish ───────────────────────────────────────────────────────────────
mkdir -p "$DEST_ROOT" "$DOTFILES"
rsync -a --delete "$SRC/" "$DOTFILES/"

tar -I 'zstd -19 -T0' -cf "$ARCHIVE" -C "$TMP" dotfiles
chmod 600 "$ARCHIVE"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
chmod 600 "$ARCHIVE.sha256"

# Keep the last 10 archives (KEEP=0 disables pruning).
KEEP="${KEEP:-10}"
if ((KEEP > 0)); then
    mapfile -t old < <(ls -1t "$DEST_ROOT"/dotfiles-*.tar.zst 2>/dev/null | tail -n +$((KEEP + 1)))
    for archive in "${old[@]}"; do
        rm -f -- "$archive" "$archive.sha256"
    done
fi

echo
echo "Dotfiles tree: $DOTFILES"
echo "Archive:       $ARCHIVE ($(du -h "$ARCHIVE" | cut -f1))"
echo "Checksum:      $ARCHIVE.sha256"
echo "Contents:      $(find "$SRC" -type f | wc -l) files, $(du -sh "$SRC" | cut -f1)"
(( WITH_SYSTEM )) && echo "System files:  included (etc/...)"
echo
echo "Restore on this machine:"
echo "  bash install.sh --from-backup '$ARCHIVE'"
