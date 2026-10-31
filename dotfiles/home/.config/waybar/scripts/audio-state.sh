#!/usr/bin/env bash
# Audio module for Waybar: icon as text, volume + 10-cell bar in the tooltip.
# Runs once at startup, then on SIGRTMIN+11 (audio-watch.sh) or after each
# click/scroll (exec-on-event).
sink="@DEFAULT_AUDIO_SINK@"
out=$(wpctl get-volume "$sink" 2>/dev/null)
vol=$(awk '{ printf "%d", $2 * 100 }' <<<"$out")
[[ -z "$vol" ]] && vol=0
(( vol < 0 )) && vol=0
(( vol > 100 )) && vol=100

muted=0
grep -q MUTED <<<"$out" && muted=1

cells=24
filled=$(( (vol * cells + 50) / 100 ))
(( filled > cells )) && filled=cells

filled_bar=""
empty_bar=""
for ((i = 1; i <= cells; i++)); do
    if (( i <= filled )); then filled_bar+="█"; else empty_bar+="░"; fi
done

if (( muted )); then
    icon=$'\uf026'
    text="Muted"
    class="muted"
elif (( vol == 0 )); then
    icon=$'\uf026'
    text="Volume 0%"
    class="muted"
elif (( vol < 50 )); then
    icon=$'\uf027'
    text="Volume ${vol}%"
    class=""
else
    icon=$'\uf028'
    text="Volume ${vol}%"
    class=""
fi

printf '{"text":"%s","tooltip":"<b>%s</b>\\n<span foreground=\\"#7ad6e0\\">%s</span><span foreground=\\"#3a474c\\">%s</span>","class":"%s"}\n' \
    "$icon" "$text" "$filled_bar" "$empty_bar" "$class"
