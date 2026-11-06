#!/usr/bin/env bash
# Show a short toast whenever the Wayland text clipboard changes.
# Started at login from hyprland.lua; flock keeps a single watcher.
set -u

lock="${XDG_RUNTIME_DIR:-/tmp}/hypr-clipboard-toast.lock"
exec 9>"$lock"
flock -n 9 || exit 0

exec wl-paste -n --type text/plain --watch \
    /home/pdev/.config/hypr/scripts/clipboard-toast-once.sh
