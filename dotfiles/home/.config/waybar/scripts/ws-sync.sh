#!/usr/bin/env bash
# One hyprctl snapshot per Hyprland event, shared by all workspace buttons.
# Keeps 10 custom/wsN modules cheap: they read this file instead of forking hyprctl.
dir="${XDG_RUNTIME_DIR:-/tmp}/waybar-ws"
mkdir -p "$dir" || exit 0

active=$(hyprctl -j activeworkspace 2>/dev/null \
    | tr -d ' \n' | sed -n 's/.*"id":\(-\{0,1\}[0-9]\+\).*/\1/p')

{
    printf 'active=%s\n' "$active"
    hyprctl -j workspaces 2>/dev/null | tr -d ' \n' \
        | grep -o '"id":[0-9-]*[^}]*"windows":[0-9]*' \
        | sed -E 's/"id":([0-9-]+).*"windows":([0-9]+)/\1 \2/'
} > "$dir/state.$$" && mv -f "$dir/state.$$" "$dir/state"

pkill -RTMIN+8 waybar 2>/dev/null || true
