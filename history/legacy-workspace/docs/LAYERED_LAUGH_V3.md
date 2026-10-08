# Layered belly laugh v3 — 0.2.47 / build 48

The user rejected the stiffness of the v2 flat upper-body animation and explicitly authorized a layered replacement on 2026-10-04. Preserve this clip during unrelated keyboard, mouse and crawl edits.

## Authored motion

The eight-second sequence retains partial eye closure, mouth movement, abdominal laughter, two tear wipes, and the supporting friend’s squint, effort and small sweat drops. Chest contraction, shoulder lift, head nod and delayed hair rotation now have distinct curves. The waist shares the retained thighs’ translation. Each sleeve has separate shoulder/elbow sections; palms and cuffs remain rigid. Wrist targets travel continuously from the normal pose to the abdomen, up to the eye, back to the abdomen and finally to the current normal contacts. During the lift a single opaque hand sprite changes from a relaxed palm to the wiping gesture. No full-person wipe-pose dissolve remains. At full wipe the finger direction follows the nodding head.

## Art and rollback

The builtin imagegen edited the preserved .46 painting only to remove its arms and reconstruct the covered dress/apron and hair. Separate head, chest, long-hair, upper-arm, forearm and hand alpha sprites were derived from that plate and the preserved .46 art. Source, exact prompt and segmentation masks are saved. The supplied full-body image, normal keyboard/mouse assets and layout are retained.

Rollback app and latest profile at quit: cache/layered-laugh-v0.2.47/Viola-0.2.46-before.app and profile-at-quit.

## Validation

40 core checks passed, including independent chest/head/hair curves, timing boundaries, tear-before-wipe, keyboard/mouse independence and idle blinks. The final gallery passed 1058 timeline stages, 445 moved-desk/noisy-input stages and a full-blink collision. The complete arm review covers the existing physical key map and mouse corners. Twelve normal RGBA images exactly match .46. Final laugh wrist error is zero, minimum sleeve determinant is 0.736985, and one opaque laugh hand per side is checked. These results establish geometry and restoration; user assessment of naturalness is still pending.

The installed .47 app has been menu-triggered in a native window. Native captures show the belly pose, the hand touching the eye during wiping, and both eyes open with normal keyboard/mouse hands restored. The temporary automatic-crawl pause used for inspection has been reversed; idleCrawlEnabled is true. Existing input-monitoring authorization was refreshed for the same app; inputPermission and globalKeyboardConnected are true. No new physical keyboard acceptance is claimed.

## Saved action guard

Run python3 scripts/check_fixed_laugh_contract.py. The new docs/layered-laugh-v3-contract.json pins the motion, rig, face identity and all .47 layers. Archived v1/v2 contracts remain historical. Change this clip only after a new explicit request to revise the laugh.
