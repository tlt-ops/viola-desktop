# Implementation stages

## 0.1 — real desktop loop

- Package a native transparent app and load Viola's reference-guided layered art.
- Passive global keyboard / mouse adapter, explicit consent state and mouse-only fallback.
- Key impulses, typing cycle, visible keyboard feedback, moving/clicking mouse hand.
- Dragging, scaling, hiding/restoring, menu bar and interaction toggle.
- Inspect actual native rendering and test the real OS input path when consent is available.

## 0.2 — current smoothing and companion behaviors

### 0.2.1 visual correction

- Remove the mouse embedded in the right-arm sprite to eliminate overlapping mice.
- Keep shoulder attachment fixed while deforming the sleeve toward the hand target.
- Register hand and mouse motion, cancel breathing at the grip, and constrain travel to the desk surface.
- Increase typing lift and mouse travel; restrict blink replacement to the eyes.
- Retain the original friend/seating component and exposed keyboard.

### 0.2.2 coherent hand grip

- Draw a complete natural hand gripping a visible mouse and move it as one rigid unit.
- Extend the upper sleeve from the shoulder to the unit's wrist rather than deforming the fingers.
- Keep keyboard-side hand/cuff rigid, with the sleeve following the typing lift.
- Show the actual global keyboard connection state and received key count; retry connection after permission is granted.

### 0.2.3 forward-facing arms and physical-key finger interaction

- Redraw both arms reaching toward the viewer; retain Viola's identity and friend seating component.
- Separate palms and all ten fingers with individual pivots and finger commands.
- Share the physical-key model across keycap rendering, finger regions and hand target positions.
- Switch the right hand between keyboard and mouse in response to actual activity.
- Persist per-key press/repeat counters and expose them in a native statistics window.
- Verify all 82 visible mappings against the installed macOS SDK and run 16 core checks.

- Interpolation, small breathing, blink sprites, idle/sleep/wake.
- Persistent configuration, offscreen recovery, reduced-motion option.
- Versioned manifest, head/body/arm/seating layers, separate renderer boundary.
- Retain the requested friend/seat component and expose keyboard keys.
- Tune registration by inspecting the actual renderer gallery and native desktop window.

### 0.2.4 left hand types, right hand keeps mouse

- Assign all 82 visible keys to the five left-hand finger commands.
- Move the entire left palm to the actual pressed key, including J/K/L, Enter and navigation keys.
- Keep the right grip visible and attached to the mouse throughout typing; support keyboard and mouse response at the same time.
- Remove obsolete right-hand typing layers and mode switches.
- Check every key's actual left fingertip contact and verify right mouse grip position/visibility remain unchanged by keyboard input.

### 0.2.5 hand anatomy, keyboard orientation and idle companions

- Redraw both hands with five digits; retarget all five left finger masks and visible thumb.
- Face the complete keyboard toward Viola, with contact and depression geometry following the same transform.
- Place the legs on opposite sides of the friend's head and animate each from its own knee pivot.
- Add brief randomized effort and heart-eye expressions using registered facial feature layers.
- Keep the old installed application and ship the revision as a parallel app with a separate profile and bundle identity.

### 0.2.6 two joined desks and shorter reach

- Split the desktop into angled keyboard and mouse panels with a visible central joint.
- Compact/tilt the board and preserve all 82 actual key contacts with the left fingers.
- Share wrist travel across both sleeve segments and retain shoulder/cuff orientation.
- Keep the friend's face visible and remove the old desk strip from the retained lower source.
- Load optional profile-level layout JSON so subsequent geometry adjustments can reuse the signed executable.

## Art follow-up

- Reconstruct independently moving front/side/back hair, upper arms, forearms and fingers with consistent hidden surfaces.
- Clean the retained lower reference edges while preserving the seated pose and friend.
- Add an open-mouth sprite, more expressions and optional authored input sounds.

## 0.3 — optional future work

- Voice input/output, emotions and conversational actions.
- Local Ollama or OpenAI adapters behind an independent interaction service.
- Optional Live2D renderer consuming the existing engine's events/frame values.
- Cross-platform desktop host. Existing Foundation core can inform the contract, but AppKit/CGEvent must be replaced on Windows.

AI services and Live2D are not dependencies of the initial desktop loop.

## 0.2.7 — current leg revision

- Use fuller anatomy with visible knee, calf, shin and ankle contours in the existing anime/stocking style.
- Keep fixed upper legs on either side of the friend's head; articulate the lower legs at the knees.
- Combine larger fore/aft flexion and lateral swing at different phases, retaining idle entry/settling and reduced-motion controls.
- Export a nine-second production-rendered idle preview and install only the parallel new application.
- Preserve the central front-facing mouse desk and inward side keyboard layout.

## 0.2.8 — current footwear interaction

- Replace the fuller legs with slimmer, longer art and geometry.
- Separate two half-worn pumps into independently animated, layered shoe modules.
- Add occasional idle slips, gravity, a small landing bounce and a grounded pause.
- Support both automatic recovery and an early click on either grounded shoe.
- Add the friend's shoe-fitting variation with a matching downward amused Viola expression, while retaining self toe-hook recovery.
- Preserve the original installed app and update only the parallel application.
