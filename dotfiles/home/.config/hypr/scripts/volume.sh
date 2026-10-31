#!/usr/bin/env bash
# Volume control with an OSD through the running notification daemon (swaync).
# usage: volume.sh up|down|mute|status [--quiet]
#   --quiet  change the volume without showing the notification
#            (used by Waybar scrolling, where the tooltip is the feedback)
set -u

sink="@DEFAULT_AUDIO_SINK@"
step="${VOLUME_STEP:-5%}"
quiet=0
action=""

for arg in "$@"; do
    case "$arg" in
        --quiet|-q) quiet=1 ;;
        *)          action="$arg" ;;
    esac
done

case "$action" in
    up)     wpctl set-volume -l 1.0 "$sink" "$step"+ ;;
    down)   wpctl set-volume "$sink" "$step"- ;;
    mute)   wpctl set-mute "$sink" toggle ;;
    status) ;;
    *)      echo "usage: ${0##*/} up|down|mute|status [--quiet]" >&2; exit 2 ;;
esac

(( quiet )) && exit 0

out=$(wpctl get-volume "$sink" 2>/dev/null)
vol=$(awk '{ printf "%d", $2 * 100 }' <<<"$out")
muted=0
grep -q MUTED <<<"$out" && muted=1

if (( muted )); then
    notify-send -a Volume \
        -h string:x-canonical-private-synchronous:volume \
        -h int:value:0 \
        -i audio-volume-muted \
        "Muted"
else
    notify-send -a Volume \
        -h string:x-canonical-private-synchronous:volume \
        -h int:value:"$vol" \
        -i audio-volume-medium \
        "Volume ${vol}%"
fi
