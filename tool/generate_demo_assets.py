#!/usr/bin/env python3
"""Generates the offline demo catalogue's artwork and preview audio.

Wave's demo mode ships a small self-contained catalogue so the UI can be run,
screenshotted and smoke-tested without reaching a music API. This script
regenerates those assets; it has no third-party dependencies on purpose, so CI
can run it anywhere.

    python3 tool/generate_demo_assets.py
"""

import math
import struct
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "demo"
SIZE = 480

# (name, top-left rgb, bottom-right rgb, accent rgb)
COVERS = [
    ("aurora", (26, 18, 74), (12, 74, 110), (124, 92, 255)),
    ("ember", (74, 16, 36), (120, 58, 20), (255, 122, 72)),
    ("lagoon", (8, 52, 70), (16, 108, 96), (34, 211, 238)),
    ("violet", (46, 14, 78), (96, 22, 110), (196, 110, 255)),
    ("dusk", (18, 20, 48), (88, 32, 74), (244, 114, 182)),
    ("solar", (72, 52, 8), (110, 86, 16), (251, 191, 36)),
    ("mono", (16, 16, 22), (48, 48, 60), (226, 232, 240)),
    ("tide", (10, 30, 62), (30, 64, 120), (96, 165, 250)),
]


def _png(path: Path, rows: list[bytearray]) -> None:
    """Writes 8-bit RGB rows as a PNG. Avoids a Pillow dependency."""
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def _mix(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def cover(name: str, top: tuple, bottom: tuple, accent: tuple) -> None:
    rows = []
    cx, cy = SIZE * 0.68, SIZE * 0.32
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            # Diagonal base gradient.
            t = (x / SIZE * 0.55) + (y / SIZE * 0.45)
            r = _mix(top[0], bottom[0], t)
            g = _mix(top[1], bottom[1], t)
            b = _mix(top[2], bottom[2], t)

            # Soft accent glow in the upper right.
            d = math.hypot(x - cx, y - cy) / (SIZE * 0.55)
            glow = max(0.0, 1.0 - d) ** 2.2
            r = _mix(r, accent[0], glow * 0.85)
            g = _mix(g, accent[1], glow * 0.85)
            b = _mix(b, accent[2], glow * 0.85)

            # Concentric rings, fading out toward the edges.
            ring = math.sin(math.hypot(x - cx, y - cy) / SIZE * 26.0)
            fade = max(0.0, 1.0 - d * 0.8)
            lift = ring * 14.0 * fade
            row += bytes(
                (
                    max(0, min(255, int(r + lift))),
                    max(0, min(255, int(g + lift))),
                    max(0, min(255, int(b + lift))),
                )
            )
        rows.append(row)
    _png(OUT / f"{name}.png", rows)


def preview_audio(path: Path, seconds: float = 24.0, rate: int = 22050) -> None:
    """A quiet drifting chord, so demo playback is audible but unobtrusive."""
    frames = bytearray()
    total = int(seconds * rate)
    partials = [(110.0, 0.34), (164.81, 0.24), (220.0, 0.18), (329.63, 0.10)]
    for i in range(total):
        t = i / rate
        sample = 0.0
        for freq, gain in partials:
            # Slow detune keeps the chord from sounding like a test tone.
            drift = 1.0 + 0.0015 * math.sin(2 * math.pi * 0.07 * t + freq)
            sample += gain * math.sin(2 * math.pi * freq * drift * t)
        # Gentle tremolo plus fade in/out at the edges.
        sample *= 0.55 + 0.45 * math.sin(2 * math.pi * 0.25 * t)
        edge = min(1.0, t / 1.5, (seconds - t) / 1.5)
        sample *= max(0.0, edge) * 0.26
        frames += struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767))

    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(rate)
        out.writeframes(bytes(frames))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, top, bottom, accent in COVERS:
        cover(name, top, bottom, accent)
        print(f"cover  {name}.png")
    preview_audio(OUT / "preview.wav")
    print("audio  preview.wav")


if __name__ == "__main__":
    main()
