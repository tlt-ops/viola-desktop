#!/usr/bin/env python3
"""Pack the native renderer export into reproducible Windows RGBA atlases.

Requires Pillow. First run ViolaDesktop --export-windows-frames build/windows-frames,
then python3 scripts/pack_windows_sprites.py build/windows-frames windows/Assets/sprites.
The generated media retain the separate terms in ASSET_LICENSE.md.
"""
import argparse
import json
import math
from pathlib import Path
import shutil

from PIL import Image


def pack(source: Path, destination: Path) -> None:
    manifest = json.loads((source / "frames.json").read_text(encoding="utf-8"))
    width, height = manifest["width"], manifest["height"]
    destination.mkdir(parents=True, exist_ok=True)
    for name, clip in sorted(manifest["clips"].items()):
        count = clip["frameCount"]
        columns = min(16, count)
        atlas = Image.new("RGBA", (width * columns, height * math.ceil(count / columns)))
        for index in range(count):
            with Image.open(source / name / f"{index:04}.png") as raw:
                frame = raw.convert("RGBA")
                if frame.size != (width, height):
                    raise ValueError(f"Wrong dimensions: {name}/{index:04}")
                atlas.paste(frame, ((index % columns) * width, (index // columns) * height))
        filename = f"{name}.png"
        atlas.save(destination / filename, compress_level=9)
        # Verify every tile is byte-identical, including partially transparent edges.
        with Image.open(destination / filename) as saved:
            for index in range(count):
                x, y = index % columns * width, index // columns * height
                tile = saved.crop((x, y, x + width, y + height)).convert("RGBA")
                with Image.open(source / name / f"{index:04}.png") as original:
                    if tile.tobytes() != original.convert("RGBA").tobytes():
                        raise ValueError(f"Atlas round-trip failed: {name}/{index}")
        clip.update(sheet=filename, columns=columns)
        print(f"{name}: {count} frames, {atlas.width}x{atlas.height}, verified", flush=True)
    for key, filename in manifest["poses"].items():
        with Image.open(source / filename) as pose:
            if pose.size != (width, height) or pose.mode != "RGBA":
                raise ValueError(f"Invalid pose: {key}")
        shutil.copyfile(source / filename, destination / filename)
    manifest["poses"].update({"mouse-left": "desk-mouse-0.png", "mouse-right": "desk-mouse-2.png"})
    manifest["applicationVersion"] = "0.2.51"
    (destination / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(f"Packed {len(manifest['clips'])} clips and {len(manifest['poses'])} poses", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    pack(args.source, args.destination)
