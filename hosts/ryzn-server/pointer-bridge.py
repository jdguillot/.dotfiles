"""Make absolute-pointer streaming clients usable on Plasma Wayland.

Two gaps, one virtual pointer pair (absolute + relative uinput devices):

Steam desktop streaming moves the pointer with XWarpPointer, which Xwayland
applies only to its own idea of the pointer, never to KWin's cursor; its
clicks (XTest) do reach KWin, so they land wherever the real cursor sits.
While Steam's log says a desktop stream is up, every change of the X11
pointer position is replayed on the absolute device. Only during streams:
Wine games warp the pointer to the window centre for mouse look, and
mirroring those at other times would fight them.

Absolute pointers (Moonlight's laser/touch via Sunshine, and the warps
above) never produce relative motion, so Wine gets no raw input deltas and
drag-to-adjust UIs such as Star Citizen's face editor ignore them. While a
button is held, the same movement is also sent on the relative device, then
the cursor is put back on the absolute target.
"""

import os
import threading
import time

from evdev import AbsInfo, InputDevice, UInput, ecodes, list_devices
from Xlib import X, display

LOG = os.path.expanduser("~/.local/share/Steam/logs/streaming_log.txt")
START = ">>> Starting desktop stream"
STOP = ">>> Stopped desktop stream"
SUNSHINE_ABS = "libvirtualhid Mouse (Absolute)"
POLL = 1 / 240
BUTTONS = (ecodes.BTN_LEFT, ecodes.BTN_RIGHT, ecodes.BTN_MIDDLE)


class Pointer:
    """An absolute and a relative uinput pointer sharing one screen size."""

    def __init__(self, width, height):
        self.lock = threading.Lock()
        # Each needs a button for libinput to classify it as a pointer.
        self.abs = UInput(
            {
                ecodes.EV_KEY: [ecodes.BTN_LEFT],
                ecodes.EV_ABS: [
                    (ecodes.ABS_X, AbsInfo(0, 0, width - 1, 0, 0, 0)),
                    (ecodes.ABS_Y, AbsInfo(0, 0, height - 1, 0, 0, 0)),
                ],
            },
            name="pointer-bridge absolute",
        )
        self.rel = UInput(
            {ecodes.EV_KEY: [ecodes.BTN_LEFT], ecodes.EV_REL: [ecodes.REL_X, ecodes.REL_Y]},
            name="pointer-bridge relative",
        )

    def move(self, x, y, dx=0, dy=0):
        """Put the cursor on (x, y); with a delta, emit it as relative motion first."""
        with self.lock:
            if dx or dy:
                self.rel.write(ecodes.EV_REL, ecodes.REL_X, dx)
                self.rel.write(ecodes.EV_REL, ecodes.REL_Y, dy)
                self.rel.syn()
            self.abs.write(ecodes.EV_ABS, ecodes.ABS_X, x)
            self.abs.write(ecodes.EV_ABS, ecodes.ABS_Y, y)
            self.abs.syn()


def follow(path):
    """Yield appended lines (None when idle), reopening when Steam rotates
    the log. History before the first open is skipped; a rotated-in file is
    read from its start."""
    f, ino = None, None
    while True:
        try:
            st = os.stat(path)
        except FileNotFoundError:
            yield None
            continue
        if f is None or st.st_ino != ino or st.st_size < f.tell():
            first = f is None
            if f:
                f.close()
            f, ino = open(path, errors="replace"), st.st_ino
            if first:
                f.seek(0, os.SEEK_END)
        yield f.readline() or None


def steam_warps(pointer, root, size):
    held_mask = X.Button1Mask | X.Button2Mask | X.Button3Mask
    lines = follow(LOG)
    streaming, last = False, None
    while True:
        line = next(lines)
        while line is not None:
            if START in line and not streaming:
                streaming, last = True, None
                print("steam: desktop stream started", flush=True)
            elif STOP in line and streaming:
                streaming = False
                print("steam: desktop stream stopped", flush=True)
            line = next(lines)
        if not streaming:
            geo = root.get_geometry()
            if (geo.width, geo.height) != size:
                # The devices' ranges are fixed; systemd restarts us at the new size.
                raise SystemExit(f"screen changed to {geo.width}x{geo.height}")
            time.sleep(0.5)
            continue
        p = root.query_pointer()
        cur = (p.root_x, p.root_y)
        if last is not None and cur != last:
            if p.mask & held_mask:
                pointer.move(*cur, cur[0] - last[0], cur[1] - last[1])
            else:
                pointer.move(*cur)
        last = cur
        time.sleep(POLL)


def sunshine_drags(pointer, width, height):
    while True:
        src = next((d for d in map(InputDevice, list_devices()) if d.name == SUNSHINE_ABS), None)
        if src is None:
            time.sleep(5)
            continue
        print(f"sunshine: watching {src.path}", flush=True)
        sx = width / src.absinfo(ecodes.ABS_X).max
        sy = height / src.absinfo(ecodes.ABS_Y).max
        held, pos, last = set(), [None, None], None
        try:
            for ev in src.read_loop():
                if ev.type == ecodes.EV_KEY and ev.code in BUTTONS:
                    (held.add if ev.value else held.discard)(ev.code)
                    last = None
                elif ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_X:
                    pos[0] = round(ev.value * sx)
                elif ev.type == ecodes.EV_ABS and ev.code == ecodes.ABS_Y:
                    pos[1] = round(ev.value * sy)
                elif ev.type == ecodes.EV_SYN and held and None not in pos:
                    if last is not None and tuple(pos) != last:
                        pointer.move(*pos, pos[0] - last[0], pos[1] - last[1])
                    last = tuple(pos)
        except OSError:
            print("sunshine: device gone", flush=True)
            time.sleep(1)


def main():
    root = display.Display().screen().root
    geo = root.get_geometry()
    pointer = Pointer(geo.width, geo.height)
    print(f"screen {geo.width}x{geo.height}", flush=True)
    threading.Thread(target=sunshine_drags, args=(pointer, geo.width, geo.height), daemon=True).start()
    steam_warps(pointer, root, (geo.width, geo.height))


if __name__ == "__main__":
    main()
