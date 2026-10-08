# Natural belly laugh v2 — 0.2.46 / build 47

The latest user request replaces the rejected .45 laugh and adds tears followed by an eye wipe. This is one independently authored eight-second action. Both relaxed palms rest against the abdomen during six chuckles with breathing gaps. Viola gently folds forward, eyes remain partially open, and the painted mouth opens in rhythm. Tears appear after 3.2 seconds; from 5.0 seconds one hand rises into a painted wiping pose, makes two small rigid strokes, then lowers. The friend has a slight squint, mild strain, and two small sweat drops. The crown repair fills pre-existing hand-shaped holes only during this action.

The desk, keyboard and mouse fade during the laugh to expose the abdomen, then return to the same layout. The normal character pose remains owned by its original keyboard, mouse and crawl rigs at zero laugh. Ordinary inactivity now preserves breath and transient blinks: automatic closed-eye sleep is disabled by default and can be explicitly enabled in Settings. Existing size, location, layout, key statistics and input permissions are retained.

## Ownership and stability

`FixedLaughMotion.swift` owns the timeline, laugh pulses, forward bow, tear/wipe weights and wipe strokes. `FixedLaughRig.swift` owns the pinned upper-body art, painted mouth, wiping palm/forearm/cuff and registrations. Hands move as rigid painted pieces; there is no sleeve-triangle morph or fast symmetric vibration in this action. `FixedLaughFaceIdentity.swift` owns the friend's laugh expression constants. The normal keyboard/mouse layout never enters the main laugh geometry.

Preserve this saved clip when working on keyboard, mouse, crawling, ordinary blinks or desk layout. Revise it only when the user explicitly asks to change the laugh. The current contract records its implementation and artwork SHA256 values in `natural-laugh-v2-contract.json`; run `scripts/check_fixed_laugh_contract.py` after adjacent changes. Visual acceptance is still the user's decision; numerical checks establish defined behavior only.

## Validation commands

```sh
swift build -c release
.build/release/ViolaChecks
.build/release/ViolaDesktop --render-gallery build/natural-laugh-review --fixed-laugh-review
.build/release/ViolaDesktop --render-gallery build/source-arm-return-review --source-arm-return-review
python3 scripts/check_fixed_laugh_contract.py
```

Review entering and returning poses, main belly laugh, tears before the wipe, the two wiping strokes, complete return, and both desk modes. Compare normal pre/post, representative keys and mouse corners to the previous installed version. Then trigger the full native menu action, observe recovery and verify the settings checkbox and existing global keyboard connection. Local renders and core tests do not establish actual physical-key delivery in a newly installed build.

Validated and installed on this Mac as 0.2.46 build 47. 39 core checks passed, including ten-minute idle blinking/breath and tear-before-wipe timing. Both desk modes passed 1058 rendered timeline stages; 445 deliberately moved-desk/noisy-input stages retained the clip. The arm review passed 2912 stages across all 82 physical keys and four mouse corners. Twelve representative normal full-RGBA renders exactly match .45. Native menu-triggered belly laugh and eye wipe were observed; the final Idle capture has laugh=0, both blink values=0, original keyboard/mouse arms restored, inputPermission=true and globalKeyboardConnected=true. Settings shows automatic closed-eye sleep off and its slider disabled. New-build physical key events remain zero, so this records connection only, not a fresh physical-key acceptance. User visual acceptance remains pending feedback. Old .45 app and profile-at-quit are retained under the cache evidence directory.
