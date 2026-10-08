"""Restore only the retained v0.2.8 toe textures beneath the reference ankles.

Run after integrate_reference_v0.2.16.py. This updates only leg/shoe sprites in
the latest staged manifest, so independent desk/hand edits remain intact.
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
STAGE = ROOT / "build/previews-v0.2.16-reference-full"
ASSETS = STAGE / "character-assets"
manifest_path = STAGE / "character-integrated.json"
manifest = json.loads(manifest_path.read_text())
metadata = json.loads((STAGE / "source-coordinates.json").read_text())
old_manifest = json.loads((ROOT / "build/evidence/character-before-width-refinement-v0.2.8.json").read_text())
old_sprites = {sprite["id"]: sprite for sprite in old_manifest["sprites"]}
old_atlas = Image.open(ROOT / "Sources/ViolaDesktop/Resources/Characters/Viola/legs-slender-v0.2.8.png").convert("RGBA")

plans = {
    "back": {"old_crop": [225, 920, 200, 250], "old_seam": 930, "reference_seam": 990,
             "world_scale": .32, "old_contact": [280, 1117], "old_center": 344,
             "knee": [345, 845], "hip": [400, 595], "thigh_end": 855, "calf_start": 825},
    "front": {"old_crop": [900, 940, 190, 280], "old_seam": 950, "reference_seam": 970,
              "world_scale": .38, "old_contact": [967, 1160], "old_center": 1017.5,
              "knee": [714, 650], "hip": [790, 587], "thigh_end": 670, "calf_start": 635},
}

records = {}
for side, plan in plans.items():
    sid = "leg_" + side
    source_x, source_y, source_w, source_h = metadata["parts"][sid]["sourceCrop"]
    base = Image.open(ASSETS / (sid + "-reference-v0.2.16.png")).convert("RGBA")
    base_array = np.array(base)
    row = plan["reference_seam"] - source_y
    opaque_x = np.flatnonzero(base_array[row, :, 3] > 64)
    reference_center = source_x + (float(opaque_x.min()) + float(opaque_x.max())) / 2

    # Uniform scaling preserves the retained toe/foot proportions. The calf
    # above the ankle comes from the reference at its original .64 mapping.
    ratio = plan["world_scale"] / .64
    old_x, old_y, old_w, old_h = plan["old_crop"]
    foot_crop = old_atlas.crop((old_x, old_y, old_x + old_w, old_y + old_h))
    foot_size = (round(old_w * ratio), round(old_h * ratio))
    foot = foot_crop.resize(foot_size, Image.Resampling.LANCZOS)
    ratio_x, ratio_y = foot_size[0] / old_w, foot_size[1] / old_h
    foot_x = round(reference_center + (old_x - plan["old_center"]) * ratio_x)
    foot_y = round(plan["reference_seam"] + (old_y - plan["old_seam"]) * ratio_y)

    # A narrow ankle transition blends the two retained textures in premultiplied
    # space. Complementary weights avoid a translucent horizontal split at the
    # join; all calf pixels above this transition remain exactly unchanged.
    reference = np.zeros((1280, 1312, 4), dtype=np.uint8)
    reference[source_y:source_y + source_h, source_x:source_x + source_w] = base_array
    restored = np.zeros_like(reference)
    restored[foot_y:foot_y + foot.height, foot_x:foot_x + foot.width] = np.asarray(foot)
    transition_start = plan["reference_seam"] - 5
    transition_end = plan["reference_seam"] + 12
    blend = np.clip((np.arange(1280)[:, None, None] - transition_start) /
                    (transition_end - transition_start), 0, 1)
    reference_alpha = reference[:, :, 3:4].astype(float) * (1 - blend)
    restored_alpha = restored[:, :, 3:4].astype(float) * blend
    alpha = reference_alpha + restored_alpha
    colors = (reference[:, :, :3] * reference_alpha + restored[:, :, :3] * restored_alpha) / np.maximum(1, alpha)
    merged = np.concatenate([np.rint(colors), np.rint(alpha)], axis=2).clip(0, 255).astype(np.uint8)
    preserved = reference[:transition_start, :, 3] > 0
    assert np.array_equal(merged[:transition_start][preserved], reference[:transition_start][preserved])
    canvas = Image.fromarray(merged)
    bounds = canvas.getbbox()
    left, top, right, bottom = bounds
    width, height = right - left, bottom - top
    filename = sid + "-toes-reference-v0.2.16.png"
    canvas.crop(bounds).save(ASSETS / filename)

    def normalized(point):
        return [(point[0] - left) / width, 1 - (point[1] - top) / height]

    contact = [foot_x + (plan["old_contact"][0] - old_x) * ratio_x,
               foot_y + (plan["old_contact"][1] - old_y) * ratio_y]
    for sprite in manifest["sprites"]:
        if sprite["id"] not in [sid, sid + "_thigh"]:
            continue
        sprite["file"] = filename
        sprite.pop("crop", None)
        sprite["rect"] = [40 + .64 * left, 860 - .64 * bottom, .64 * width, .64 * height]
        is_thigh = sprite["id"].endswith("_thigh")
        sprite["anchor"] = normalized(plan["hip"] if is_thigh else plan["knee"])
        if is_thigh:
            end = (plan["thigh_end"] - top) / height
            sprite["polygon"] = [[0, 0], [1, 0], [1, end], [0, end]]
        else:
            start = (plan["calf_start"] - top) / height
            sprite["polygon"] = [[0, start], [1, start], [1, 1], [0, 1]]
            sprite["contact"] = normalized(contact)

    # Retain the atlas's shoe opening and gold rim, calibrated to the restored
    # source foot's actual world size. v0.2.8 published pumps were 51.94 x 84.
    old_leg = old_sprites[sid]
    old_scale_x = old_leg["rect"][2] / old_leg["crop"][2]
    old_scale_y = old_leg["rect"][3] / old_leg["crop"][3]
    shoe_width = 51.94 * plan["world_scale"] / old_scale_x
    shoe_height = 84 * plan["world_scale"] / old_scale_y
    for sprite in manifest["sprites"]:
        if sprite["id"] in ["shoe_" + side + "_rear", "shoe_" + side + "_front"]:
            sprite["rect"] = [0, 0, shoe_width, shoe_height]

    records[side] = {"source": "legs-slender-v0.2.8.png", "oldFootCrop": plan["old_crop"],
        "oldFootContact": plan["old_contact"], "footWorldScale": plan["world_scale"],
        "referenceJoin": [reference_center, plan["reference_seam"]], "sourceCrop": [left, top, width, height],
        "sourceContact": contact, "worldContact": [40 + .64 * contact[0], 860 - .64 * contact[1]],
        "shoeSize": [shoe_width, shoe_height], "originalCalfRGBAAboveSourceY": transition_start,
        "sourceRGBAAboveTransitionPreserved": True}

manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
(STAGE / "restored-feet-coordinates.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
print(manifest_path)
