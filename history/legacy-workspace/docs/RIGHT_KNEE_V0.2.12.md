# Right knee artwork correction

The character's right knee (left in the rendered scene) inherited a pointed triangular crease and abrupt turn from the v0.2.8 leg atlas. The same shape was present before strip mesh deformation.

The built-in imagegen edit softens the kneecap and makes the thigh-to-knee-to-calf shading descend naturally. Only `leg_back` and `leg_back_thigh` use the new atlas. The other leg retains the previous atlas. Rectangles, crop bounds, anchors, contacts, leg mesh and animation code are unchanged.

- Source: `Assets/Source/legs-right-knee-v0.2.12.png`
- Runtime source: `Sources/ViolaDesktop/Resources/Characters/Viola/legs-right-knee-v0.2.12.png`
- External runtime: `~/Library/Application Support/ViolaDesktop-Preview/character-assets/legs-right-knee-v0.2.12.png`
- Preview: `build/previews-v0.2.12-right-knee/gallery/idle-legs-detail.png`

The installed v0.2.12 executable exported 16 art-only poses with the candidate external layout. Idle, forward and backward legs were visually inspected. This is artwork evidence, not input permission or global input acceptance. The application bundle was not edited or signed for this artwork change.

Native desktop reload completed through the installed app’s Quit menu followed by reopening the same app. The native screenshot visibly replaced the sharp dark knee triangle with the rounded descending transition. Code signature CDHash remained `705deecd583648ea6267aaec922ab754324ca79d`, matching the pre-edit value. Both external sprite filenames resolve to `legs-right-knee-v0.2.12.png`; source and external asset bytes match. Input Monitoring was not changed in this artwork task.

Additional laughter artwork inspection used the installed executable with the active external layout and `--laugh-stills`. Full-size `laugh-10.png` and `laugh-23.png` (plus 36/51) retain the rounded right-knee transition with no visible new thigh/shin mismatch. A complete art-only export also supplied `laugh-extremes/motion/009.png` and `020.png`, near opposite extrema of the right-leg sine (`sin(age*5.8+2.1)`). The knee shape remains attached in both. The 0.625-scale motion exports show horizontal strip artifacts on both legs; this is a separate mesh/export limitation and was not repaired in this artwork task. Full-size stills give the clearer knee evidence. No native UI, executable, code signature or input permission was changed during this additional inspection.
