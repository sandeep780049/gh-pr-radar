#!/usr/bin/env python3
"""Build an asciinema v2 cast from the real `gh pr-radar` output captured on disk.

This does NOT invent output: it replays the exact stdout of the tool,
captured by running it. Used to render demo.gif via `agg`.
"""
import json
import sys
from pathlib import Path

FULL = Path(".tmp/out_full.txt").read_text(encoding="utf-8")
KESTRA = Path(".tmp/out_kestra.txt").read_text(encoding="utf-8")

events = []
t = 0.0


def emit(data: str, delay: float = 0.0) -> None:
    global t
    t += delay
    events.append([round(t, 3), "o", data])


def type_line(cmd: str) -> None:
    emit("$ ", 0.4)
    for ch in cmd:
        emit(ch, 0.055)
    emit("\r\n", 0.25)


def show(text: str) -> None:
    for line in text.splitlines():
        emit(line + "\r\n", 0.12)
    emit("\r\n", 0.4)


type_line("gh pr-radar --limit 5")
show(FULL)
type_line("gh pr-radar --repo kestra")
show(KESTRA)

header = {
    "version": 2,
    "width": 112,
    "height": 18,
    "timestamp": 1759600000,
    "env": {"SHELL": "/bin/bash", "TERM": "xterm-256color"},
}

out = Path(sys.argv[1] if len(sys.argv) > 1 else "demo.cast")
with out.open("w", encoding="utf-8", newline="\n") as fh:
    fh.write(json.dumps(header) + "\n")
    for ev in events:
        fh.write(json.dumps(ev) + "\n")

print(f"wrote {out} ({len(events)} events, {t:.1f}s)")
