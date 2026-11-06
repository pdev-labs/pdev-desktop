#!/usr/bin/env bash
# stdin: the new clipboard text. Show a generic toast and never print the text.
set -u

# Consume stdin so wl-paste never blocks on a full pipe.
chars=$(wc -m)
(( chars == 0 )) && exit 0

notify-send \
    -a "Clipboard" \
    -i edit-copy \
    -u normal \
    -t 1400 \
    -h string:x-canonical-private-synchronous:clipboard-toast \
    "Copied to clipboard"
