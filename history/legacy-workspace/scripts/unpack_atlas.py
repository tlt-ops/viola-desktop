#!/usr/bin/env python3
"""Mechanically unpack generated sprite atlases; never repaint or remove backgrounds.
Coordinates use pixels from the atlas's top-left. Original source files are retained.
"""
from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Assets' / 'Source'
TARGET = ROOT / 'Sources' / 'ViolaDesktop' / 'Resources' / 'Characters' / 'Viola'
SOURCE.mkdir(parents=True, exist_ok=True)
TARGET.mkdir(parents=True, exist_ok=True)
atlas = SOURCE / 'viola-atlas-open.png'
closed = SOURCE / 'viola-atlas-closed.png'
im = Image.open(atlas)
blink = Image.open(closed)
if im.mode != 'RGBA' or im.size != (1536, 1024) or blink.size != im.size:
    raise SystemExit('Expected the inspected 1536 x 1024 RGBA sprite atlases')
regions = {
    'head.png': (30, 10, 675, 362),
    'body.png': (30, 360, 675, 710),
    'left_arm.png': (680, 310, 1100, 715),
    'right_arm.png': (1200, 310, 1536, 715),
    'keyboard.png': (0, 805, 640, 976),
    'mouse.png': (650, 805, 855, 973),
    'desk.png': (860, 805, 1536, 977),
}
for name, bounds in regions.items():
    im.crop(bounds).save(TARGET / name)
if (SOURCE / 'right-arm-no-mouse.png').exists():
    # Preserve the registered mouse-free edit; CALayer fits it into the same sprite slot.
    shutil.copyfile(SOURCE / 'right-arm-no-mouse.png', TARGET / 'right_arm.png')
if (SOURCE / 'mouse-hand-rigid.png').exists():
    shutil.copyfile(SOURCE / 'mouse-hand-rigid.png', TARGET / 'mouse_hand.png')
if (SOURCE / 'frontal-arms.png').exists():
    shutil.copyfile(SOURCE / 'frontal-arms.png', TARGET / 'frontal-arms.png')
blink.crop(regions['head.png']).save(TARGET / 'head_close.png')
shutil.copyfile(SOURCE / 'reference-seating.png', TARGET / 'reference-seating.png')
print(f'Unpacked {len(regions) + 2} assets into {TARGET}')
