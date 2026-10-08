> Historical v1, superseded. The user rejected its clasped hands and mechanical motion. Use [natural laugh v2](NATURAL_LAUGH_V2.md) and its current contract; v1 is not the active clip.

# Frozen belly-laugh v1 contract

This contract fixes Viola's standalone 5.6-second belly-laugh clip. Viola brings both hands to her belly with slightly narrowed eyes; the supporting friend keeps a small squint and strained expression with two subtle sweat drops. Keyboard, mouse, crawl, ordinary blinking, and layout work may continue independently, but must not retune or re-register this clip. Change it only when the user explicitly requests a laugh revision.

## Frozen implementation and artwork

- `Sources/ViolaCore/FixedLaughMotion.swift` owns revision `fixed-belly-laugh-v1`, the 5.6-second timeline, 0.42-second entry and 0.70-second exit, and all laugh weight, bounce, support, and leg-motion curves. Their current numeric values and formulas are part of v1.
- `Sources/ViolaDesktop/FixedLaughRig.swift` owns the dedicated belly pose, source crops, wrist anchors, hand artwork, cuff masks, and sleeve mesh registration. Its art comes from `frontal-arms-v0.2.5.png` crops `[210,0,440,590]` and `[870,0,420,574]`, the original left hand pieces from v0.2.29, and the clipped lap hand from `resting_lap_arm-original-v0.2.31.png`. The fixed main wrist targets are `(306,662)` and `(399,652)` canvas units; hand angles are `1.3` and `−0.45` radians. The crop rectangles, source pixel polygons, layer order, anchors, mesh mapping, and hand registrations remain fixed for v1.
- `Sources/ViolaDesktop/FixedLaughFaceIdentity.swift` owns the frozen face values: rider closure `0.40`, friend closure `0.28`, mouth half-width `14.5`, mouth depth `11.6`, beat center/amplitude/frequency `0.94/0.06/13`, brow tension `2.8`, sweat opacity `0.52`, and two drops. `Sources/ViolaDesktop/SourceReferenceFaceRig.swift` owns their registration on the source portraits. A small laugh-only crown patch clones adjacent original hair over retained fingertip pixels when the desk is hidden. Keep the source eye, brow, mouth, sweat, and crown-cover coordinates unchanged; ordinary blink changes must not override the laugh squint.
- `Sources/ViolaDesktop/LayerRenderer.swift` only connects the clip to the normal pose and renders the frozen rig. On entry it captures the current normal wrist/angle contacts, then blends into the fixed pose. On exit it blends from the held laugh contacts back to the current normal contacts; once the clip ends, existing interactive keyboard/mouse/crawl rigs own the pose again. During the main laugh, keyboard targets, mouse state, and crawl progress must not alter the fixed hand targets, angles, face, or art registration. Only the already-defined body/shoulder support and reduced-motion inputs remain allowed; changing their laugh behavior requires an explicit laugh revision.

The current source bundle version is `0.2.45` / build `46`. Keep the standard bundle identifier `local.viola.desktop`; the installed profile is managed separately.

## Review required before acceptance

Run both renderer reviews and inspect their emitted images and JSON:

```sh
swift run --package-path . ViolaDesktop --render-gallery build/fixed-laugh-review --fixed-laugh-review
swift run --package-path . ViolaDesktop --render-gallery build/source-arm-return-review --source-arm-return-review
python3 scripts/check_fixed_laugh_contract.py
```

The hash guard compares pinned source/art SHA256 values in `docs/fixed-laugh-v1-contract.json`; update that manifest only for a user-authorized laugh revision. Numerical checks alone do not establish visual acceptance. Inspect normal-to-laugh entry, the held pose, laugh release, full-face and hand/sleeve crops, desk-visible and hidden poses, and confirm there are no seams, duplicate hands, clipping, or unwanted arm geometry. Then use the native menu to trigger one complete laugh and observe entry, hold, return, and the restored normal pose. Record only checks that were actually run; this contract contains no build, render, or native acceptance result.
