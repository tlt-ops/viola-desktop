# Test and acceptance instructions

## 0.2.11 expression artwork

Use `--render-gallery <folder> --art-only --layout <active profile JSON>` to render without behavioral checks. Compare `friend-hearts-face-detail.png`, `friend-effort-face-detail.png` and `idle-face-detail.png`: the small mouth droplet should appear only in the heart-eye state, with eye positions unchanged. Current exports are in `build/previews-v0.2.11-drool/`. A later manual native check can observe the random expression fading in and out while the friend breathes.

## 0.2.10 hand artwork and manual follow-up

`--render-gallery <folder> --hand-art` exports rest and A/S/D/F/J/K/L/Enter/Space/Esc/Backspace poses at 0%, 50% and 100% pressure without running behavioral checks. An optional `--layout <absolute JSON path>` selects the active external layout. Inspect the five-digit silhouette, cuff connection, knuckle seams, lack of finger elongation, and curved sleeve at the keyboard extremes. Current exports are in `build/previews-v0.2.10-hand/`.

For later native acceptance, type these keys physically in another app; compare visible selected keycaps with actual presses, look for smooth palm travel and release, and confirm the right hand remains on the mouse. This physical-key sequence was not performed during the visual repair.

## Automated core checks

```sh
swift run ViolaChecks
./scripts/build_app.sh --parallel
"Viola 新版.app/Contents/MacOS/ViolaDesktop" --render-gallery build/previews-v0.2.6-inward
```

The 18-case core suite checks typing start/stop, repeat, rolling frequency, stationary mouse handling, key impulse/recovery, both click buttons, smoothed mouse direction/return, sleep/wake, transient blinks, reduced motion, configuration persistence/corruption and pause reset. Keyboard checks cover every visible physical key's assigned left finger and left palm target, simultaneous keyboard/mouse response, independent chords, pressure release, per-key press/repeat counters and statistics serialization. These tests prove clock-driven core behavior, not system permission or end-to-end desktop input.

The gallery uses the production CALayer renderer with actual bundled art. Inspect `idle.png`, `typing.png`, `typing-and-mouse.png`, `mouse-move.png`, `mouse-left.png`, `click.png`, `blink.png`, `sleep.png`, `breathing.png` and `preview.png`, plus all five left `finger-*.png` states. Verify identity, friend component, forward-facing arms, shoulder/cuff registration, finger flex and keycap contact. `key-38.png`, `key-40.png`, `key-37.png`, `key-36.png` and `key-49.png` show the left hand reaching J/K/L/Enter/Space. The right grip must remain visible on the mouse. `motion/` contains 180 engine-driven frames; `motion-geometry.json` records shoulder/contact geometry and `key-bindings.json` records all 82 mappings. These previews demonstrate animation geometry/timing; they do not prove OS reception.

For the arm fix, inspect the shoulder while moving in all four directions. It must follow the torso without sliding sideways. Confirm the hand and mouse are one stable grip, the fingers retain their shape throughout travel, and the mouse never moves beyond the rear desk edge. Inspect typing from rest through lift and return: fingers retain their shape and lift above the key plane rather than pass through it. Sleeves should extend toward both wrists without an exposed gap.

## Actual macOS acceptance

1. Open `Viola 新版.app`. Confirm one transparent desktop scene plus menu-bar ✨. It should remain above ordinary windows without taking text focus.
2. In settings enable input monitoring, grant Viola in macOS privacy settings, then reconnect/restart as required. Confirm the app reports **全局键盘已接入**, then type in a separate app and confirm the displayed received-key count increases.
   If the system switch is already on but fresh app diagnostics report `inputPermission=false`, check for a stale code identity after a local rebuild. The 2026-09-30 audit confirmed this exact failure through `tccd`'s `Failed to match existing code requirement` message. Remove the old Viola entry with the minus button, add the current `~/Applications/Viola 新版.app` with the plus button, enable it and follow any quit/reopen prompt. The user performs this permission change. Do not assume that a visible on switch or a restart proves permission for the current executable.
3. Type a short phrase in a separate editor. Watch the typing hand and keyboard. Release keys and confirm it settles. Hold a key and confirm repeat animates without blocking the editor.
   Open the statistics window before/after a controlled sequence such as A S D F J K L Enter Space. Each key's `presses` must increase independently; hold A and confirm its `repeats` increases without counting every repeat as a new physical press. Every visible keyboard press must move/use the left hand, including J/K/L/Enter/Space. The right hand must stay gripping the mouse, and mouse movement/clicks must still work during typing. Chords should show multiple corresponding keycaps and finger states. Demo must leave statistics unchanged. Use physical keyboard input for this native check: the CUA-generated TextEdit sequence inserted text but did not increment the passive global tap on this machine.
4. Move the pointer right/left/up/down in another app. In 0.2.9, confirm the mouse hand moves on screen left/right/down/up respectively, stays within the mouse desk and returns smoothly. Click left and right; confirm the pressing motion. This mapping reverses both axes to match Viola facing the viewer.
5. Stop using input. Observe breathing and at least one blink. Set sleep to 15 seconds, wait without moving the mouse, confirm eyes close, then move or type to wake.
6. Drag the companion. Scale via settings and Option + wheel. Relaunch and confirm the position and width return; test on available screens.
7. Hide via menu and restore through menu-bar ✨. Turn interaction off and confirm input is ignored; enable it again. Turn mouse-through on and confirm underlying apps receive clicks; use menu bar to switch it off.
8. Close settings, then type in another app. Confirm the companion never steals focus. Quit from menu and confirm the companion/menu icon disappear.

`~/Library/Application Support/ViolaDesktop-Preview/diagnostics.json` includes the actual permission status, tap connection, real input event counters, demo flag, visibility and window dimensions. Demo events are fed directly to the engine and **do not** increment real-listener counters.

## Evidence rules

The 10-second demo is useful for inspecting all motion before authorization. It does not prove global keyboard reception. Rendered PNGs, core tests, build/signature checks, a running process and live OS input each prove different things. Record which native acceptance steps were actually exercised; leave unexercised steps unverified.

## Rotated keyboard geometry (0.2.6)

The gallery checks settled left fingertip contact for every one of the 82 visible keys after the keyboard's -18 degree outer rotation and 180-degree inner facing, including depressed-key coordinates. It exports key-contact-geometry.json and fails for any error over 0.1 logical point. It also verifies all keys use left fingers, and that the right mouse grip stays visible with unchanged position during keyboard-only input. Inspect mouse-left-front.png as well as mouse-left.png and mouse-move.png for separation at movement extremes.

## 0.2.5 parallel revision

Build with `./scripts/build_app.sh --parallel`. This installs `~/Applications/Viola 新版.app` and leaves the previous `Viola.app` intact. The new profile is `~/Library/Application Support/ViolaDesktop-Preview/`; its Input Monitoring grant is separate. If the new app is missing from System Settings, use Input Monitoring → `+` to select that exact new app, then complete the OS authorization and restart prompt.

1. Observe the idle hands: left has four long fingers and one short thumb; right retains a five-digit mouse grip.
2. Type A/S/D/F/Space and J/K/L/Enter: left palm moves to the key, its assigned finger presses, and the right hand stays on the mouse. Space is the row nearest Viola; F keys are nearest the viewer.
3. Stop all input for at least two seconds: the two legs on either side of the friend's head sway gently. Resume input and observe them ease back to rest.
4. Watch for roughly 30 seconds: the friend briefly shows an effort or heart-eye expression and then returns to neutral. Both expressions occur over randomized intervals, so one interval need not show both.
5. Check current-version diagnostics for `inputPermission=true`, `globalKeyboardConnected=true`, `demoActive=false`, and increasing `KEY_DOWN`/`KEY_UP` while typing in another app. A rendered gallery or built-in demonstration does not establish this.
6. Open the old version independently if desired; its original appearance/settings remain available. Close one overlay for normal use.

The core checks now include idle entry/settling, reduced leg motion, temporary expression timing and both random expression choices (18 checks total). The actual renderer checks all 82 key contacts and right-grip visibility/position. `--stills-only` skips animation-frame export while preserving all key contact checks.

## 0.2.6 assembled desks

Inspect the central joint, full visibility of the friend's eyes, keyboard support at both ends and mouse containment at all movement extremes. Compare `key-0.png` and `key-115.png` for shoulder/cuff continuity. The left hand must still reach both edges; the right grip must not move during keyboard-only input. Check the active profile layout in diagnostics. After a geometry-only edit and restart, the executable signature should remain unchanged. Native keyboard connection must be checked after executable updates. Never remove/reset the old preserved app's permission while updating the new app.

The final inward-facing layout is in `build/previews-v0.2.6-inward/`. Earlier outward-facing previews are retained as historical candidates. Inspect the inward version for acceptance. Generated per-frame PNGs may be removed after encoding the final GIF; `--render-gallery` reproduces them.

Current accepted direction: `build/previews-v0.2.6-center-mouse/`. Check that the mouse panel is forward-facing and only the side keyboard panel folds inward. Inspect `mouse-move.png`, `mouse-left.png` and `mouse-left-front.png` for support at movement extremes. The native app uses the external profile layout; the executable signature remains unchanged from build 8.

## 0.2.7 compound leg motion

For an art-only export without running behavior/key-contact checks:

```sh
"Viola 新版.app/Contents/MacOS/ViolaDesktop" --render-gallery build/previews-v0.2.7 --idle-only
```

This exports 16 static states and 180 idle frames at 20 fps, plus `idle-leg-positions.json`. `--art-only` exports only the still states. Neither flag executes behavioral checks. The existing behavior-check bounds were adjusted for the larger fore/aft amplitudes; no checks were added or executed for this visual revision.

Manual visual steps: stop mouse/keyboard input for more than two seconds; observe both feet moving fore/aft through perspective size/length change, together with lateral arcs at different phases. Knees should remain attached and the friend's face visible. Compare `legs-combined.png` and `legs-opposite.png` for motion extremes. Resume mouse activity to observe settling, then check reduced-motion/sleep settings if desired. These are instructions; only explicitly recorded observations count as completed acceptance.

## 0.2.8 footwear and assistance — manual instructions

This revision does not add or execute behavior tests. Art export uses the production engine/renderer without assertions or simulated key events:

```sh
"Viola 新版.app/Contents/MacOS/ViolaDesktop" --render-gallery build/previews-v0.2.8 --shoe-art
```

`--shoe-art` advances 38 seconds at 15 fps and exports the natural seeded drop/recovery story, per-shoe positions and key poses; `--shoe-stills` exports the same key poses without individual video frames. Both return before key-contact checks.

Manual acceptance steps for the user:

1. Stop input for around 15–30 seconds. Observe a shoe loosen, detach from the foot, fall and settle. The bare stockinged foot must stay complete, with no attached duplicate shoe.
2. Leave the shoe alone: after 6–9 seconds, observe either toe-hook recovery or the friend's hand collecting and fitting it. The first left-shoe recovery uses friend assistance; later choices vary.
3. During assistance, the relevant old resting hand disappears, a single helper hand supports the shoe, the foot steadies and Viola's downcast amused eyes/smile appear. The helper hand then returns to rest.
4. On another drop, click the grounded shoe before auto recovery. That shoe should start recovery immediately; the desktop window should stay in place. Drag the character outside a fallen-shoe region to move it normally.
5. Restore normal half-worn contact after either recovery. Original two-axis leg sway continues.
6. Reduced motion suppresses new drops; an in-progress recovery completes. With mouse-through enabled, use the menu to disable it before direct shoe clicks.

These are acceptance instructions, not claims that native clicks or all cases were exercised. Native global keyboard permission and physical input remain a separate acceptance item.
