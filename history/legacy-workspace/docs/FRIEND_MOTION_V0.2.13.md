# Supporting girl breathing and tremor

The supporting girl has a slow 3.8-second breathing cycle with a small second harmonic. `friendBreath` moves between approximately -1.47 and +1.58 canvas pixels over the arranged preview. Two independent frequency pairs generate a continuous, subdued muscle tremor: approximately 0.50 pixels horizontally and 0.34 pixels vertically at the rig's reference height. The animation has no per-frame random jumps.

`LayerRenderer` builds one world-space affine transform from the line joining the two resting-palm contact points. Points on that line stay fixed. The seating artwork, resting sleeves, shoulder covers and expression patches share that transform, so breathing does not lift the palms or detach facial details. The seated character's body and leg chain receive the same support displacement at the hip; attached shoes continue to follow the projected feet. The typing and mouse sleeves follow the displaced shoulders while their wrist targets stay on the controls.

During shoe assistance, the helper sleeve's shoulder follows the support transform. Its wrist stretches to the existing shoe target, and the helper palm stays at that target. The transform is not applied a second time to that hand. Existing laughter drives `supportSway`, `supportDip` and its large leg motions; normal breathing and tremor fade out with the laughter envelope. Reduced motion uses 20 percent of the supporting girl's breath and disables its tremor.

Optional `alphaMaskFile` values load a generated transparency matte next to an external layout, falling back to bundled resources. The mask receives the sprite's existing crop and is composited in memory through a native Core Graphics alpha clip. The original sprite supplies all color pixels, and existing polygon/cutout masks still apply. No source bitmap is rewritten by the renderer.

## Artwork evidence

The release executable was built from `~/Library/Caches/ViolaDesktop/source`. `--render-gallery <folder> --layout <active layout> --friend-motion-stills --art-only` exports nine selected PNGs across normal, reduced-motion and shoe-assistance poses, plus `friend-motion-poses.json` with 540 geometry samples. `--friend-motion-art` also exports frame sequences when explicitly requested. Heart and effort overlays in these arranged previews are selected to inspect expression registration.

The first export is in `build/previews-v0.2.13-friend-motion/`. Normal and assistance stills were visually inspected. Both resting-palm contact points stayed at their defined positions to floating-point precision (largest recorded movement below 0.000000001 pixels). Reduced-motion samples contained no tremor. This is artwork/geometry evidence. No behavior checks, input injection, native application interaction, installation or code signing were performed for this subtask. Final matte and layout revisions are integrated separately before the final application handoff.
