#!/usr/bin/env python3
# Drags with the VM's mouse (QEMU's USB tablet), as a user would: presses at
# (x0, y0) and moves back and forth to (x1, y1) and back, for testing what
# window moves do. Screen coordinates; DRAG_SCREEN=WxH gives the VM's screen
# size if it isn't 1920x1080.
#   vm/drag.py x0 y0 x1 y1 [steps] [rounds]
import json
import os
import subprocess
import sys

kWidth, kHeight = [int(v) for v in
    os.environ.get("DRAG_SCREEN", "1920x1080").split("x")]


def send(*events):
    command = {"execute": "input-send-event", "arguments": {"events": list(events)}}
    subprocess.run(["virsh", "-c", "qemu:///system", "qemu-monitor-command",
        "haiku-navi", json.dumps(command)], check=True,
        stdout=subprocess.DEVNULL)


def move(x, y):
    send({"type": "abs", "data": {"axis": "x", "value": int(x * 32767 / (kWidth - 1))}},
        {"type": "abs", "data": {"axis": "y", "value": int(y * 32767 / (kHeight - 1))}})


def button(down):
    send({"type": "btn", "data": {"down": down, "button": "left"}})


x0, y0, x1, y1 = [float(a) for a in sys.argv[1:5]]
steps = int(sys.argv[5]) if len(sys.argv) > 5 else 40
rounds = int(sys.argv[6]) if len(sys.argv) > 6 else 3

move(x0, y0)
button(True)
for _ in range(rounds):
    for i in list(range(1, steps + 1)) + list(range(steps - 1, -1, -1)):
        move(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)
button(False)
