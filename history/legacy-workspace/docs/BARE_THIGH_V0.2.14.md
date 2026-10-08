# Reference skin texture and short upper-thigh exposure

The user authorized programmatic cropping/editing from `Assets/Source/reference-seating.png`. `scripts/extract_bare_thigh_v0.2.14.py` bilinearly samples only the narrow exposed skin opening inside source rows 581–677, excluding the ivory drape and dark stocking outlines. It maps that existing texture into a short region at the hip end of the existing leg atlases. This is a source texture mapping; no generated artwork or new skin colors are painted.

Outputs are `legs-bare-thigh-v0.2.14.png` and `leg-right-seated-bare-thigh-v0.2.14.png`, retained in Assets/Source, bundled character resources and the integrated candidate's character-assets directory. The original atlases remain available. The front atlas changes only x850–1035/y52–244 (about 54 canvas points of upper-thigh height, with the upper portion covered by the seated clothing). The seated back atlas changes only x759–873/y501–702, confined to the hip-end eighteen percent of the diagonal thigh. The cuff curves around each leg with a narrow transition to the original stocking RGB. Both original alpha channels are byte-identical; knee, calf and foot pixels remain unchanged.

The integrated layout changes only `file` on `leg_front`, `leg_front_thigh`, `leg_back` and `leg_back_thigh`. Existing crop, rect, anchor, contact, masks, swing gains and perspective distance are preserved. No skirt, desk, keyboard or mouse items are changed by this step.

Review artifacts in `build/previews-v0.2.14-integrated`:

- `bare-thigh-source-comparison.png`: original and mapped front/back textures beside the original visible skin and cuff.
- `bare-thigh-evidence.json`: changed pixel counts, exact bounds and unchanged alpha evidence.

The source comparison was visually inspected after narrowing the samples to remove a trace of the source skirt boundary from the first pass. Final full-character rendering, garment overlap and pose acceptance are performed by the main integration task. This texture step does not claim target-app acceptance or install a build.
