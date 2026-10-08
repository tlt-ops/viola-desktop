# Character asset specification

## Heart-eye mouth and drool (0.2.11)

`friend-hearts-drool-v0.2.11.png` is a 1312 × 1199 RGBA edit of the existing heart-eye head. The runtime reuses the original eye sprites and replaces only `friend_hearts_mouth`, with crop `[580,832,137,110]`. Its rect preserves the previous mouth's source-to-canvas scale and anchor while extending down to include the small droplet. The existing `expression: hearts` binding controls the whole mouth/drool patch, including opacity and friend breathing. Neutral and effort states use their existing mouth sprites. Source image and exact built-in-tool prompt are retained in `Assets/Source/` and `ASSET_PROMPTS_V0.2.11.json`.

External layouts now optionally load images from a sibling `character-assets/` directory before falling back to the signed app's bundled images. The current drool PNG is also installed at `~/Library/Application Support/ViolaDesktop-Preview/character-assets/`. Future art-only revisions can replace that external image and layout, then restart the app without modifying its signed bundle. Sprite filenames remain restricted to local basenames.

## Current typing hand revision (0.2.10)

`typing-hand-v0.2.10.png` is a 1536 × 1024 RGBA atlas edited with the built-in image tool. The current rig uses its left cuff/palm and exactly five individually masked digits; sleeves and the entire right mouse grip still use `frontal-arms-v0.2.5.png`. Updated finger masks, knuckle anchors and tip contacts follow the new shorter, relaxed curved fingers. Original PNGs are retained; the exact prompt is in `ASSET_PROMPTS_V0.2.10.json`.

The left sleeve now uses a shared curved surface between fixed shoulder and moving wrist. Adjacent 8-source-pixel bands are rendered as pairs of affine triangles with overlapping borders. Cross-sections turn by 40% of the centerline angle to retain the forward-facing sleeve and avoid self-folding. Both original sleeve parts follow the same source coordinates and curve; the cuff ends upright at the rigid palm. The right sleeve rig is unchanged. Finger pressure slightly foreshortens the projected digit (maximum 6.5%, thumb 3.5%); it never elongates the finger. Key aiming uses the same transformed contact point.

Production artwork: `build/previews-v0.2.10-hand/`. `--hand-art` exports the resting hand and 11 representative keys at three pressure levels without behavioral checks.

The reference defines Viola's dark green long hair, blunt bangs, side bun, X and triangular clips, olive-gray eyes, ivory-and-gold collar/chest panel, plum sleeves and flower badge. Normal human anime proportions and recognizability take precedence over realism. The referenced typing pose and the purple-haired friend beneath Viola are part of the requested composition.

## Runtime format

`Sources/ViolaDesktop/Resources/Characters/Viola/character.json` is the authoritative layout. Canvas: **800 × 960** logical points. Sprite rectangles use bottom-left coordinates. Atlas crop rectangles use top-left pixel coordinates. Array order is back-to-front z-order; anchors are normalized bottom-left coordinates.

| File / layer | Purpose | Current subdivision |
|---|---|---|
| `seating-sides-v0.2.5.png` / seating | Friend and retained seated clothing | Original leg silhouettes removed by cutout masks |
| `legs-anatomy-v0.2.7.png` / leg_back, leg_front and thigh layers | Fuller stockinged legs on either side of friend | Each leg has a fixed upper section and independently projected calf/foot |
| `body.png` | Lower torso, costume, back hair | Same core illustration cut at the neck region |
| `head.png` | Face, bangs, side bun, upper hair | Combined head sprite, pivot near neckline |
| `head_close.png` | Blink and sleep | Only masked eyelid regions overlay the open head; hair and neck remain unchanged |
| `frontal-arms-v0.2.5.png` / left_arm | Forward-facing keyboard sleeve | Shoulder fixed; upper sleeve connects to a separate forward-facing forearm |
| `frontal-arms-v0.2.5.png` / left_palm | Left cuff and palm | Rigid palm moving toward target keys |
| `frontal-arms-v0.2.5.png` / left_* finger | Five left fingers | Independent masks, knuckle pivots and fingertip contact points |
| `frontal-arms-v0.2.5.png` / right_arm, mouse_hand | Forward-facing mouse arm | Coherent hand/mouse remains rigid; sleeve follows wrist |
| `KeyboardRenderer` | 82 visible physical keys | Ivory keycaps and plum case; geometry, labels and feedback share the key map |
| Legacy arm/keyboard/mouse PNGs | Prior source assets | Retained but not rendered by the current rig |
| `modular-desk-v0.2.6.png` / desk_keyboard, desk_mouse | Two joined plum desk panels | Shared source, separate crop masks and placement |

PNG files carry alpha. Cropping the generated atlas is mechanical asset unpacking; no background removal, recoloring or redrawing is performed by the extraction script. Original generated atlases and reference remain in `Assets/Source/`.

Version 0.2.5 uses `Assets/Source/frontal-arms-v0.2.5.png`, generated for the user's requested forward-facing pose. The left keyboard arm and right mouse arm are cropped and masked at render time; cuff/palm/finger overlap avoids gaps at their joints. The eight obsolete right-hand typing layers have been removed from the active manifest. Prior edits remain in `Assets/Source/`. Sprite image dimensions can differ from logical rectangles; CALayer fits each PNG into its manifest rectangle.

The upper-arm `anchor` is the shoulder attachment and `contact` marks its elbow seam in normalized bottom-left coordinates. Each `_forearm` layer is anchored at the wrist. The upper sleeve remains attached to the shoulder. The elbow follows 58% of the wrist lateral displacement, with the forearm taking the remainder; horizontal cross-sections retain shoulder/cuff orientation. Both segments adjust their projected depth. The palm/grip remains attached to that wrist as the hand moves. Each left typing finger has its own `finger`, knuckle `anchor` and fingertip `contact`. Only the assigned finger flexes. The left palm travels across the full keyboard toward a contact point inside the actual pressed keycap, using the shared physical-key map. The right mouse hand and mouse remain one visible rigid sprite during all keyboard input; travel is bounded to x ±32 and y −22…+12 points, in addition to the grip's static right/front placement. The keyboard wrapper uses `rotationDegrees: -18`; the complete inner board rotates 180 degrees toward Viola. Space is nearest her, F keys nearest the viewer. Keycap depression and contact use the same local offset.

The rig provides independent head/body/upper sleeves/forearms/left palm/five left fingers/keyboard/right mouse-grip/seating transforms. It has no independent front/side/back hair or full anatomical skeleton. Open-mouth expression and voice-driven lip sync belong to a later art revision.

## Fidelity and known artwork limits

Upper assets were generated with the built-in image tool using the supplied reference. Their pose and costume are reference-guided, but generated details can differ. The lower pose now uses the user-requested leg placement revision. The friend remains recognizable, but this generated revision moves her face slightly; expression features have been registered to the revised face. Original and earlier assets remain in Assets/Source.

The original lower component includes some desk structure and soft/rough edge pixels. Its mask excludes nearby annotations where practical. Head/body share breathing translation without independent rotation; only eyelid regions change on blinking. Finger flex uses masked 2D sprites rather than a complete hand anatomy solver. Same-hand chords orient the palm toward the latest key while maintaining independent finger and keycap states. These boundaries are explicit so future rig art can replace the rendering without replacing input/statistics.

## Adding assets

Add an RGBA PNG to the character folder and a sprite record with `id`, local `file` name, `[x,y,width,height]` and optional normalized `anchor`. Optional `crop` and normalized top-left `polygon` support atlas/reference assets. Keep filenames local and unique IDs. Run the render gallery after layout changes and inspect idle, typing, mouse, click, blink and sleep.

## 0.2.5 moving legs and expressions

`polygon` defines a sprite outline; optional `cutouts` removes the original fixed leg silhouettes from the base using an even-odd mask. The two leg layers rotate by at most 0.014/0.010 radians around knee anchors after two seconds idle, then ease to rest on input. Existing generated skirt/cushion repair pixels appear only inside the exposed leg regions. A second repair generation was blocked by the image tool; it is not a shipped asset.

`friend-effort-v0.2.5.png` and `friend-hearts-v0.2.5.png` supply only eyes and mouth. Each feature has its own registered crop and soft mask; the original hair, face outline and body remain in the base scene. A seeded random scheduler selects a temporary expression, holds 2.5–3.5 seconds, and returns to neutral. No global input is simulated for idle behaviors.

The hand atlas visibly contains four long keyboard fingers and one short thumb. Left masks partition the new source along each finger gap; old masks are not reused. The right mouse grip is one five-digit drawing, so sleeve deformation cannot duplicate a finger.

## 0.2.6 modular desk

The transparent 1942 × 809 PNG was generated with built-in image_gen from the existing desk surface. It contains two connected plum panels with a visible central seam. The runtime takes two complementary polygon masks from crop `[30,190,1900,510]` and places the left/right panels separately. The left board is shallow enough to keep the friend's eyes visible; the right provides the full mouse travel area. The old desk strip in the lower seating source is masked out. Original desk art remains available locally.

The compact keyboard is 250 × 80 logical points with a -18-degree inward outer angle. Left hand layers use the original shoulder position with a 112 × 244 rectangle; the existing five-finger masks and contacts are retained. The mouse grip is placed at rect y=409 to meet its inward-facing desk surface. The entire seating/leg/feature group moves up 60 points to maintain the waist connection exposed by the new desk angle.

A profile-level `character-layout.json` may override the bundled layout, using only images already in the bundle. It is loaded at launch, and invalid layouts fall back to the bundled manifest. `diagnostics.json` reports the active `layoutPath`.

The final inward layout rotates the left panel -36 degrees and the right panel +18 degrees around their shared inner/front connection. The keyboard follows the left panel to -18 degrees. These are sprite placement transforms using the retained generated source. Static layer rotations are applied during construction as well as animated pose updates.

## Superseding center-mouse layout

The final user correction keeps `desk_mouse` at 0 degrees with rect `[-13,195,640,270]`. The keyboard panel alone remains at -36 degrees and moves 65 points toward viewer-left; its keyboard is 235 × 80 at -18 degrees. The grip uses `[401,379,106,247]`. This profile-only revision uses the same bundled images and signed executable. The bilateral inward candidate is retained for history.

## 0.2.7 fuller legs and compound idle motion

The built-in image tool produced `legs-anatomy-v0.2.7.png`, a 1254 × 1254 RGBA source with two isolated legs. It retains opaque charcoal/plum stockings and anime linework while adding fuller knee/calf volume, shin planes and tapered ankles. Source and bundled PNG are both retained; exact prompt is in `ASSET_PROMPTS_V0.2.7.json`.

Each leg is split into a fixed `_thigh` layer and a moving calf/foot layer, with overlapping artwork around the knee. The prior hips retain their canvas positions. The viewer-left original cutout expands 1.4 logical points to remove the old silhouette's antialiased fringe.

Fore/aft amplitudes are 0.36/0.32 radians, combined with lateral amplitudes 0.065/0.055 radians. Frequencies and phases differ between legs. The renderer uses 48 overlapping horizontal texture strips per lower leg to approximate perspective depth while keeping native and PNG rendering consistent. Two source pixels of overlap prevent seams. The knee is the fixed pivot; projected foot contact includes both motions. Optional manifest values `swingMultiplier`, `sideSwingMultiplier` and `perspectiveDistance` tune gains and perspective without recompilation. Current gains are 1 and distance is 760 points. Sleep and reduced-motion settings lower the amplitudes.

## 0.2.8 slender legs, independent heels and assistance

The user superseded the fuller 0.2.7 anatomy with slimmer, longer proportions. New leg art is `legs-slender-v0.2.8.png`; frames are 342 points high and 114.48/83.74 wide after the user requested a final 6% width increase, retaining the hip attachment positions and compound projection. Calf silhouettes and feet were redrawn with the built-in image tool.

`heels-pair-v0.2.8.png` is a separate two-shoe atlas. Each heel has a full rear sprite behind its foot and a front leather/toe/rim mask above it. The opening stays visible with the stockinged heel outside. Both layers share one rigid `ShoeRig` transform. Shoes do not deform with the leg mesh. Shoe anchors sit inside the toe box; `floorY` sets each sprite's landing floor. Falling/grounded transforms stop following the foot.

`friend-help-arms-v0.2.8.png` supplies two independent sleeves and rigid cupped palms. Original resting forearms are retained as masks of the earlier seating image. `friend-arms-background-v0.2.8.png` provides the arm-free base and continuous floor. During assistance the corresponding resting forearm fades out, its helper sleeve stretches from the fixed elbow to the palm, and original shoulder ruffles cover the attachment. Only one helping arm is selected at a time.

`viola-amused-v0.2.8.png` supplies registered eye and smile patches. Soft masks confine them to the face; original head, hair and clips remain. During help, the assisted leg settles, Viola looks downward and smiles, then returns to her normal expression. Blink overlays remain active.

All five final transparent source PNGs are retained in `Assets/Source/` and bundled locally. Exact prompts and sizes are in `ASSET_PROMPTS_V0.2.8.json`. This is still a 2D layered animation: the hand uses a cupped pose, sleeve interpolation and aligned contact, not a complete anatomical skeleton or finger grasp simulation.
