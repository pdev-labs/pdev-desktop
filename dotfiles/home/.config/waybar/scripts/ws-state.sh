#!/usr/bin/env bash
# Print one workspace button as Waybar JSON.
# usage: ws-state.sh <id> <label> [hide]
# With "hide", an empty workspace prints empty text so hide-empty-text can
# collapse it (used for 6-10, which appear only once they are in use).
# Reads the snapshot written by ws-sync.sh; falls back to hyprctl if missing.
id="${1:?id}"
label="${2:?label}"
mode="${3:-always}"

cache="${XDG_RUNTIME_DIR:-/tmp}/waybar-ws/state"
active=""
win=""

if [[ -r "$cache" ]]; then
    active=$(sed -n 's/^active=//p' "$cache" | head -1)
    win=$(awk -v want="$id" '$1 == want { print $2; exit }' "$cache")
fi

if [[ -z "$active" ]]; then
    active=$(hyprctl -j activeworkspace 2>/dev/null \
        | tr -d ' \n' | sed -n 's/.*"id":\(-\{0,1\}[0-9]\+\).*/\1/p')
fi

if [[ -z "$win" ]]; then
    seg=$(hyprctl -j workspaces 2>/dev/null | tr -d ' \n' \
        | grep -o "\"id\":${id},[^}]*" | head -1)
    win=$(printf '%s' "$seg" | grep -o '"windows":[0-9]*' | cut -d: -f2)
fi

if [[ "$active" == "$id" ]]; then
    class=active
elif [[ -n "$win" && "$win" -gt 0 ]] 2>/dev/null; then
    class=occupied
else
    class=empty
fi

if [[ "$mode" == "hide" && "$class" == "empty" ]]; then
    printf '{"text":""}\n'
else
    printf '{"text":"%s","class":"%s","tooltip":"Workspace %s"}\n' "$label" "$class" "$id"
fi
