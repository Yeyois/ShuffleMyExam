#!/usr/bin/env python3
"""Generates the JCT MixExam launcher icon for Android and iOS.

The mark: a white exam sheet (RTL — answer bullets on the right, the first
one marked in the app's seed blue) sitting on the seed-blue field, with the
two crossing shuffle arrows in amber below it.

Everything is drawn from the normalised 100x100 layout in `draw_mark()`, so
the same artwork produces the legacy square icons, the Android adaptive
foreground, the themed-icon monochrome layer and the iOS icon set.

Run from the repo root:  python3 tool/generate_app_icon.py
Requires Pillow (`pip install Pillow`). Only needs re-running when the icon
design changes — the generated PNGs are committed.
"""

from __future__ import annotations

import json
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_RES = os.path.join(ROOT, "android/app/src/main/res")
IOS_ICONSET = os.path.join(
    ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")

# Palette — anchored on the app's Material seed colour (#00639B).
BLUE_TOP = (0x1B, 0x8A, 0xCC)
BLUE_BOTTOM = (0x00, 0x3D, 0x63)
SEED = (0x00, 0x63, 0x9B)
SHEET = (0xFF, 0xFF, 0xFF)
INK = (0xB4, 0xC7, 0xD4)
INK_STRONG = (0x7C, 0x99, 0xAD)
AMBER = (0xFF, 0xB3, 0x00)
WHITE = (0xFF, 0xFF, 0xFF)

# Everything is rendered at this resolution and downsampled, which is what
# keeps the diagonals and the sheet corners clean at 48px.
RENDER = 2048

# Legacy square icons: dp -> res directory suffix.
ANDROID_LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                  "xxhdpi": 144, "xxxhdpi": 192}
# Adaptive layers are 108dp canvases.
ANDROID_ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216,
                    "xxhdpi": 324, "xxxhdpi": 432}


def _px(box, x, y):
    """Maps a point on the normalised 100x100 grid into the content box."""
    left, top, size = box
    return (left + x * size / 100.0, top + y * size / 100.0)


def _len(box, v):
    return v * box[2] / 100.0


def draw_mark(draw, box, *, mono=False):
    """Draws the sheet-and-shuffle-arrows mark inside `box` = (left, top, size)."""
    p = lambda x, y: _px(box, x, y)  # noqa: E731 — local shorthand
    u = lambda v: _len(box, v)       # noqa: E731

    sheet_fill = WHITE if mono else SHEET
    line_soft = None if mono else INK
    line_hard = WHITE if mono else INK_STRONG
    bullet_on = WHITE if mono else SEED
    arrow = WHITE if mono else AMBER

    # --- the exam sheet -------------------------------------------------
    if mono:
        # Tinted themed icons turn a filled sheet into a featureless blob,
        # so the monochrome layer outlines it instead.
        draw.rounded_rectangle([p(12, 2), p(88, 60)], radius=u(7),
                               outline=sheet_fill, width=int(u(4.5)))
    else:
        draw.rounded_rectangle([p(12, 2), p(88, 60)], radius=u(7),
                               fill=sheet_fill)

    # Title line, then three answer rows. RTL: bullets on the right, the
    # lines running leftwards at uneven lengths like real answer text.
    draw.rounded_rectangle([p(46, 11), p(80, 16)], radius=u(2.5),
                           fill=line_hard)

    for i, (cy, left_x) in enumerate([(28, 30), (39.5, 40), (51, 24)]):
        r = u(4.2)
        cx, cyy = p(75.5, cy)
        fill = bullet_on if i == 0 else (sheet_fill if mono else INK)
        if mono and i != 0:
            draw.ellipse([cx - r, cyy - r, cx + r, cyy + r],
                         outline=fill, width=int(u(2.2)))
        else:
            draw.ellipse([cx - r, cyy - r, cx + r, cyy + r], fill=fill)
        bar = line_hard if (mono or i == 0) else line_soft
        draw.rounded_rectangle([p(left_x, cy - 2.4), p(68, cy + 2.4)],
                               radius=u(2.4), fill=bar)

    # --- the shuffle arrows ---------------------------------------------
    y_hi, y_lo, w = 72.0, 92.0, int(u(7.5))
    for a, b in ((y_hi, y_lo), (y_lo, y_hi)):
        draw.line([p(8, a), p(30, a), p(64, b), p(78, b)],
                  fill=arrow, width=w, joint="curve")
        # Round off the open left end so the stroke doesn't read as chopped.
        r = w / 2.0
        x0, y0 = p(8, a)
        draw.ellipse([x0 - r, y0 - r, x0 + r, y0 + r], fill=arrow)
        # Arrowhead.
        tip_x, tip_y = p(92, b)
        draw.polygon([(tip_x, tip_y), p(76, b - 8.5), p(76, b + 8.5)],
                     fill=arrow)


def render_square(size, *, rounded, corner=0.225):
    """Full-bleed icon: gradient field, optional rounded corners, mark on top."""
    grad = Image.new("RGB", (1, RENDER))
    for y in range(RENDER):
        t = y / (RENDER - 1)
        grad.putpixel((0, y), tuple(
            round(BLUE_TOP[c] + (BLUE_BOTTOM[c] - BLUE_TOP[c]) * t)
            for c in range(3)))
    img = grad.resize((RENDER, RENDER)).convert("RGBA")

    if rounded:
        mask = Image.new("L", (RENDER, RENDER), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, RENDER - 1, RENDER - 1], radius=RENDER * corner, fill=255)
        img.putalpha(mask)

    inset = RENDER * 0.13
    draw_mark(ImageDraw.Draw(img), (inset, inset, RENDER - 2 * inset))
    return img.resize((size, size), Image.LANCZOS)


def render_layer(size, *, mono):
    """Adaptive foreground / monochrome: transparent, mark inside the safe zone.

    Android crops adaptive layers to the central 72dp of the 108dp canvas in
    most launcher masks, so the mark is sized to that.
    """
    img = Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 0))
    content = RENDER * 72 / 108.0
    inset = (RENDER - content) / 2.0
    draw_mark(ImageDraw.Draw(img), (inset, inset, content), mono=mono)
    return img.resize((size, size), Image.LANCZOS)


def write(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    for bucket, px in ANDROID_LEGACY.items():
        write(render_square(px, rounded=True),
              f"{ANDROID_RES}/mipmap-{bucket}/ic_launcher.png")

    for bucket, px in ANDROID_ADAPTIVE.items():
        write(render_layer(px, mono=False),
              f"{ANDROID_RES}/mipmap-{bucket}/ic_launcher_foreground.png")
        write(render_layer(px, mono=True),
              f"{ANDROID_RES}/mipmap-{bucket}/ic_launcher_monochrome.png")

    # iOS masks its own corners and rejects alpha, so: square and opaque.
    with open(f"{IOS_ICONSET}/Contents.json") as f:
        entries = json.load(f)["images"]
    sizes = {}
    for e in entries:
        if "filename" not in e:
            continue
        px = round(float(e["size"].split("x")[0]) * float(e["scale"][0]))
        sizes[e["filename"]] = px
    for name, px in sorted(sizes.items()):
        write(render_square(px, rounded=False).convert("RGB"),
              f"{IOS_ICONSET}/{name}")


if __name__ == "__main__":
    main()
