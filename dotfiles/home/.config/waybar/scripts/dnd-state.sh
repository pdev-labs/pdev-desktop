#!/usr/bin/env bash
# Do-Not-Disturb indicator for Waybar (swaync backend).
if swaync-client -D 2>/dev/null | grep -q true; then
    printf '{"text":"\uf1f6","class":"on","tooltip":"Do Not Disturb: on"}\n'
else
    printf '{"text":"\uf0f3","class":"off","tooltip":"Do Not Disturb: off"}\n'
fi
