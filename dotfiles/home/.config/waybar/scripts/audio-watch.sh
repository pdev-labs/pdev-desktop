#!/usr/bin/env bash
# Ping the Waybar audio module whenever PipeWire/PulseAudio reports a change,
# so the icon and tooltip stay correct even when volume changes come from
# media keys, pavucontrol or another app.
lock="${XDG_RUNTIME_DIR:-/tmp}/waybar-audio-watch.lock"
exec 9>"$lock"
flock -n 9 || exit 0

pactl subscribe 2>/dev/null | while read -r line; do
    case "$line" in
        *"on sink"*|*"on server"*) pkill -RTMIN+11 waybar 2>/dev/null || true ;;
    esac
done
