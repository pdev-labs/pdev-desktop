#!/usr/bin/env python3
"""Return a safe terminal geometry for a possible Hyprland split.

If the active window belongs to this shell and is tiled, reserve enough space
for the next tiling step so already-printed fastfetch output does not reflow:

* one tiled window: prepare for a 2x2 split (quarter width, half height)
* two or three tiled windows: prepare for the next split (half width/height)
* four or more: use the actual size

The output is "columns lines" on one line.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys


def ancestors(pid: int) -> set[int]:
    seen: set[int] = set()
    while pid > 0 and pid not in seen:
        seen.add(pid)
        try:
            with open(f"/proc/{pid}/stat", "r", encoding="utf-8") as fh:
                fields = fh.read().split()
            pid = int(fields[3])
        except (OSError, ValueError, IndexError):
            break
    return seen


def emit(cols: int, lines: int) -> None:
    print(max(1, cols), max(1, lines))


def main() -> None:
    try:
        cols, lines, shell_pid = (int(x) for x in sys.argv[1:4])
    except (ValueError, TypeError):
        emit(80, 24)
        return

    if (
        os.environ.get("FF_SAFE", "1") == "0"
        or os.environ.get("TMUX")
        or os.environ.get("STY")
        or not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    ):
        emit(cols, lines)
        return

    try:
        win = json.loads(
            subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True)
        )
        if win.get("floating") or not win.get("mapped"):
            emit(cols, lines)
            return
        if win.get("pid") not in ancestors(shell_pid):
            emit(cols, lines)
            return

        monitors = json.loads(
            subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
        )
        monitor = next(
            (m for m in monitors if m.get("id") == win.get("monitor")), None
        )
        if not monitor:
            emit(cols, lines)
            return

        clients = json.loads(
            subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        )
        ws = (win.get("workspace") or {}).get("id")
        tiled = sum(
            1
            for c in clients
            if c.get("mapped")
            and not c.get("hidden")
            and not c.get("floating")
            and (c.get("workspace") or {}).get("id") == ws
        )

        width = (win.get("size") or [0])[0]
        near_full = width >= monitor.get("width", 0) * 0.75

        if tiled == 1 and near_full and cols >= 95:
            emit(cols // 4 - 2, lines // 2 - 1)
        elif tiled in (2, 3):
            emit(cols // 2 - 2, lines // 2 - 1)
        else:
            emit(cols, lines)
    except Exception:
        emit(cols, lines)


if __name__ == "__main__":
    main()
