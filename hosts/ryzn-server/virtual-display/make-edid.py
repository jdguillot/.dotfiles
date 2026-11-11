#!/usr/bin/env python3
"""Write a 256-byte EDID (base + CTA-861 block) for a headless 4K output.

Usage: make-edid.py OUT.bin

The HDMI and HDMI Forum vendor blocks are what get the NVIDIA driver past
its 1080p fallback on a forced-on connector; the 4:2:0 map lets 4K120 fit
600MHz TMDS (KMS capture reads the RGB framebuffer, not the link).
"""
import math
import struct
import sys

NAME = b"Virtual 4K"

# CTA-861 VICs: 97 = 2160p60, 118 = 2160p120, 16 = 1080p60, 63 = 1080p120.
VICS = [97, 118, 16, 63]
# VICs the sink also accepts as YCbCr 4:2:0 (must be listed in VICS).
Y420_VICS = [118]


def cvt_rb(w, h, hz):
    """CVT v1.2 reduced-blanking timing, as dtd() arguments."""
    h_blank, h_front, h_sync = 160, 48, 32
    v_front, min_v_blank_us = 3, 460
    v_sync = 10
    for ratio, sync in ((16 / 9, 5), (16 / 10, 6), (4 / 3, 4), (5 / 4, 7)):
        if abs(w / h - ratio) < 0.01:
            v_sync = sync
    h_period_us = (1e6 / hz - min_v_blank_us) / h
    v_blank = max(math.floor(min_v_blank_us / h_period_us) + 1, v_front + v_sync + 6)
    clock_khz = int(hz * (w + h_blank) * (h + v_blank) / 1000) // 250 * 250
    return clock_khz, w, h_blank, h_front, h_sync, h, v_blank, v_front, v_sync, False


def dtd(clock_khz, w, h_blank, h_front, h_sync, h, v_blank, v_front, v_sync, v_pos=True):
    """18-byte detailed timing descriptor (digital separate sync, +hsync)."""
    w_mm, h_mm = 600, 340
    d = bytearray(18)
    struct.pack_into("<H", d, 0, clock_khz // 10)
    d[2], d[3] = w & 0xFF, h_blank & 0xFF
    d[4] = (w >> 8) << 4 | h_blank >> 8
    d[5], d[6] = h & 0xFF, v_blank & 0xFF
    d[7] = (h >> 8) << 4 | v_blank >> 8
    d[8], d[9] = h_front & 0xFF, h_sync & 0xFF
    d[10] = (v_front & 0xF) << 4 | v_sync & 0xF
    d[11] = (h_front >> 8) << 6 | (h_sync >> 8) << 4 | (v_front >> 4) << 2 | v_sync >> 4
    d[12], d[13] = w_mm & 0xFF, h_mm & 0xFF
    d[14] = (w_mm >> 8) << 4 | h_mm >> 8
    d[17] = 0x18 | 0x02 | (0x04 if v_pos else 0)
    return d


def descriptor(tag, payload):
    d = bytearray(18)
    d[3] = tag
    d[5:18] = payload.ljust(13, b" ")
    return d


def checksummed(block):
    block[127] = -sum(block[:127]) & 0xFF
    return block


def chromaticity():
    # sRGB primaries and D65 white, 10-bit fixed point.
    xy = [(0.640, 0.330), (0.300, 0.600), (0.150, 0.060), (0.3127, 0.3290)]
    v = [round(c * 1024) for pair in xy for c in pair]
    lo_rg = (v[0] & 3) << 6 | (v[1] & 3) << 4 | (v[2] & 3) << 2 | v[3] & 3
    lo_bw = (v[4] & 3) << 6 | (v[5] & 3) << 4 | (v[6] & 3) << 2 | v[7] & 3
    return bytes([lo_rg, lo_bw] + [x >> 2 for x in v])


def base_block():
    b = bytearray(128)
    b[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"
    mfg = "VRT"
    struct.pack_into(">H", b, 8, sum((ord(c) - 64) << s for c, s in zip(mfg, (10, 5, 0))))
    b[10:12] = b"\x01\x00"  # product code
    b[16], b[17] = 1, 2026 - 1990  # week, year
    b[18], b[19] = 1, 4  # EDID 1.4
    b[20] = 0x80 | 0x30 | 0x02  # digital, 10 bpc, HDMI-a
    b[21], b[22] = 60, 34  # cm
    b[23] = 120  # gamma 2.2
    b[24] = 0x08 | 0x02 | 0x01  # RGB + YCbCr 4:4:4, native preferred, continuous
    b[25:35] = chromaticity()
    b[35:38] = b"\x21\x08\x00"  # 640x480, 800x600, 1024x768 @60
    b[38:54] = b"\x01" * 16  # no standard timings
    # Preferred: CTA 2160p60 timing.
    b[54:72] = dtd(594000, 3840, 560, 176, 88, 2160, 90, 8, 10)
    b[72:90] = dtd(*cvt_rb(2560, 1440, 120))
    # Range limits: 24-144Hz, 15-345kHz (+255 offset flag), 1200MHz.
    b[90:108] = descriptor(0xFD, bytes([24, 144, 15, 90, 120, 0x01, 0x0A]))
    b[90 + 4] = 0x08  # max H rate +255
    b[108:126] = descriptor(0xFC, NAME + b"\n")
    b[126] = 1  # one extension
    return checksummed(b)


def cta_block():
    blocks = bytearray()
    blocks += bytes([0x40 | len(VICS)]) + bytes(VICS)
    # HDMI 1.4 VSDB: phys addr 1.0.0.0, 340MHz TMDS.
    blocks += bytes([0x67, 0x03, 0x0C, 0x00, 0x10, 0x00, 0x00, 340 // 5])
    # HDMI Forum VSDB: v1, 600MHz TMDS, SCDC present, no FRL.
    blocks += bytes([0x67, 0xD8, 0x5D, 0xC4, 0x01, 600 // 5, 0x80, 0x00])
    y420_map = sum(1 << VICS.index(v) for v in Y420_VICS)
    blocks += bytes([0xE2, 0x0F, y420_map])

    c = bytearray(128)
    c[0], c[1] = 0x02, 0x03
    c[2] = 4 + len(blocks)  # first DTD offset
    c[3] = 0x80 | 0x30 | 1  # underscan, YCbCr 4:4:4 + 4:2:2, 1 native DTD
    c[4 : c[2]] = blocks
    c[c[2] : c[2] + 18] = dtd(*cvt_rb(2560, 1440, 60))
    return checksummed(c)


if __name__ == "__main__":
    edid = base_block() + cta_block()
    assert len(edid) == 256
    with open(sys.argv[1], "wb") as f:
        f.write(edid)
