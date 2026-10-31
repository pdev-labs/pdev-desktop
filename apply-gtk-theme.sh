#!/usr/bin/env bash
# Apply the Graphite GTK theme after installing the packages.
#   sudo pacman -S adw-gtk-theme papirus-icon-theme
#   bash ~/tools/apply-gtk-theme.sh
set -euo pipefail

if [[ ! -d /usr/share/themes/adw-gtk3-dark ]]; then
    echo "adw-gtk3-dark is not installed." >&2
    echo "Run first: sudo pacman -S adw-gtk-theme papirus-icon-theme" >&2
    exit 1
fi

gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita-Tiny'
gsettings set org.gnome.desktop.interface cursor-size 16

for v in 3.0 4.0; do
    mkdir -p "$HOME/.config/gtk-$v"
    cat > "$HOME/.config/gtk-$v/settings.ini" <<INI
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Adwaita Sans 11
gtk-cursor-theme-name=Adwaita-Tiny
gtk-cursor-theme-size=16
gtk-application-prefer-dark-theme=1
INI
done

# Qt apps: use the same icon theme once Papirus is installed.
if grep -q '^icon_theme=' "$HOME/.config/qt6ct/qt6ct.conf" 2>/dev/null; then
    sed -i 's/^icon_theme=.*/icon_theme=Papirus-Dark/' "$HOME/.config/qt6ct/qt6ct.conf"
else
    echo 'icon_theme=Papirus-Dark' >> "$HOME/.config/qt6ct/qt6ct.conf"
fi

echo "GTK theme -> adw-gtk3-dark, icons -> Papirus-Dark"
echo "Reopen running GTK apps (Nautilus, pavucontrol, blueman) to see it."
