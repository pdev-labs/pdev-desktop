#!/usr/bin/env bash
# Power menu for Waybar (wofi dmenu).
set -u

choice=$(printf '  Lock\n  Suspend\n  Logout\n  Reboot\n  Shutdown' \
    | wofi --dmenu --prompt 'Power' --width 240 --height 280) || exit 0
[[ -z "$choice" ]] && exit 0

case "$choice" in
    *Lock)     exec hyprlock 2>>/home/pdev/.cache/hyprlock.log ;;
    *Suspend)  exec systemctl suspend ;;
    *Logout)   exec hyprctl dispatch 'hl.dsp.exit()' ;;
    *Reboot)   exec systemctl reboot ;;
    *Shutdown) exec systemctl poweroff ;;
esac
