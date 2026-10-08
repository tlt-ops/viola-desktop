# Image generation record

Built-in image_gen was used. Inputs are retained locally; atlas unpacking is deterministic.

## Open-eye sprite atlas

Use case: character-illustration. Create a production anime sprite atlas for a desktop keyboard/mouse companion, closely matching the GREEN-HAIRED seated Viola in reference image 1 (top character only). Keep olive-dark-green long hair, blunt bangs, viewer-right side bun and loose long sidelock, dark X clip viewer-left and white triangle+bar clip viewer-right, olive-gray eyes, serene smile, ivory/gold high collar and chest panel, plum-brown sleeves and cream cuffs, flower badge. Normal human anime proportions, refined hand-drawn Japanese game art, soft cel shading. Reference image 1 provides identity and the slightly turned seated typing pose. Reference image 2 supports face and costume detail. Deliver ONE transparent PNG SPRITE ATLAS, landscape 3 columns x 2 rows of six SEPARATE ISOLATED parts in equal cells, with clear wide transparent gutters and absolutely no text or borders. Row 1 col 1: Viola upper-body core from head to waist in the seated 3/4 pose, WITHOUT arms or hands; shoulders lead to smooth sleeveless seam concealed when separate arms are placed. Her face is complete with open eyes. Row 1 col 2: the COMPLETE keyboard-side arm including plum sleeve from shoulder joint to cream cuff and bare slender hand, elbow bent and forearm reaching viewer-left downward, fingers poised for typing; isolate just this arm on transparent. Row 1 col 3: the COMPLETE mouse-side arm including sleeve from shoulder joint to cream cuff and bare hand in a mouse-holding pose, elbow bent down and hand reaching viewer-right; isolate just arm, no mouse. Row 2 col 1: a compact dark-plum keyboard with pale ivory keycaps, keys clearly visible from above at matching front three-quarter seated desk angle, wide horizontal, no labels. Row 2 col 2: a matching pale mouse with subtle plum outline at same view, no hand. Row 2 col 3: a low slim dark-plum horizontal desk surface, top surface visible, no legs, no objects. Each isolated component fully inside its cell, centered, no overlaps between cells, genuine transparent background, natural human proportions. No chibi, no photorealism, no 3D, no extra person, no text or graphic marks. Aim for six individually usable animation parts, keep the core highly faithful to the references.

## Closed-eye edit

Edit target: the attached Viola sprite atlas. Preserve the EXACT canvas dimensions, exact locations, scale, linework, colors, clothing, all six objects and transparency. Change ONLY the green-haired character's two eyes from open to gently closed in a natural anime blink: relaxed thin curved dark lash lines on the same face; preserve the eyebrows, skin and bangs exactly. Keep every other part as close to pixel-identical as possible for animation registration. No new background, effects, text, borders or objects. Actual transparent PNG.

## Lower seating generation (rejected by tool)

Use image 1 as the definitive reference. Create ONE isolated transparent lower seating component for an anime desktop companion. Preserve the original lower scene: green-haired Viola's waist, flowing dark-plum/ivory skirt and long legs with dark stockings, seated in exactly the same pose on the back of her purple-haired female friend. The purple-haired friend is kneeling on hands and knees, facing slightly viewer-left, elbows straight, palms on the floor, wearing exactly the reference's long plum-purple dress, dark ruffles, hair and violet eyes. Preserve their anatomy, normal anime proportions, clothing, pose and relative placement very closely. Frame ONLY Viola from waist down and the complete purple-haired friend. Cut off Viola's upper torso cleanly at waist; it will be hidden behind a separately layered desk. No desk, desk legs, monitor, keyboard, mouse, text, speech bubbles, annotations, extra limbs or background. Refined clean Japanese anime illustration, not chibi, not photoreal or 3D. Real transparent PNG, full connected seated silhouette in frame with generous transparent margin.

The tool rejected this output at its safety check; no generated seating image was returned. The original reference is used at runtime for that component.

## Mouse grip and frontal arm revisions

Subsequent image-tool edits removed the accidentally embedded mouse from the original arm and produced a single coherent hand gripping a mouse. Those source files remain as `right-arm-no-mouse.png` and `mouse-hand-rigid.png`; the current rig uses the later frontal atlas.

`frontal-arms.png` is a 1536 × 1024 transparent atlas of two isolated, normal-proportion anime arms. The generation requested sleeves matching Viola's plum/ivory/gold clothing, shoulders above wrists on a forward-facing centerline, a keyboard hand with clearly separated fingers, and a second hand visibly gripping a white/plum mouse. It requested preservation of the reference illustration style and excluded chibi, photographic and 3D rendering.

Runtime crops and polygon masks divide this atlas into sleeves, palms and fingers. The historical 0.2.3 right typing hand mirrored that source; 0.2.4 onward uses only the left hand for typing. Keyboard keycaps are native vector layers drawn from the physical-key map; their exact labels/positions are not generated image text. The keyboard/mouse arrangement can be changed in `character.json` without redrawing the character or changing physical key assignments.

## 0.2.5 final source assets (built-in image_gen)

Selected outputs were copied into `Assets/Source/` and the bundled character directory:

- `frontal-arms-v0.2.5.png`: edit of the frontal arm atlas. Exactly four long typing fingers plus a clearly visible short thumb; natural curled knuckles; mouse grip has one thumb, two button fingers and two side fingers. Preserve cuffs, sleeves, position, palette, forward direction and transparency. The earlier six-finger candidate was discarded.
- `friend-effort-v0.2.5.png`: original purple-haired friend's head, same head tilt and anime design, gently closed effort eyes, mild strain and small open mouth, isolated transparent head.
- `friend-hearts-v0.2.5.png`: same identity/head angle, violet eyes with pink heart pupils and a small warm smile, transparent head. Only registered eyes/mouth are used in the app.
- `seating-repair-v0.2.5.png`: background repair of the original illustration, replacing its two stockinged leg silhouettes with existing plum costume/cushion textures. Only small background regions are rendered behind moving legs.
- `seating-sides-v0.2.5.png`: user-requested revision with one fully stockinged leg hanging on each side of the friend's head/shoulders; preserve costume and seated relationship, keep face visible, balanced relaxed pose. Upper scene is unused; original upper Viola art remains in the app.

The image tool rejected a subsequent background-only repair request for the revised pose at its output safety check. It was not retried. The runtime uses the already available repair pixels and transparent sprite masking. No rejected output is included.

The existing 0.2.4 app keeps its own original embedded assets. The 0.2.5 app uses a separate bundle identity and profile, and includes the new source assets locally.

## 0.2.6 two assembled desk panels

Built-in image_gen edit of the retained `desk.png`, generating a transparent 1942 × 809 two-panel desktop. Selected source: `Assets/Source/modular-desk-v0.2.6.png`; also bundled locally. Runtime polygon masks separate the two panels; no character assets were regenerated for this desk change. Exact prompt is also recorded in `ASSET_PROMPTS_V0.2.6.json`.

Use case: precise-object-edit. Redesign only this isolated dark-plum anime desktop surface into TWO small joined desktop panels for a keyboard/mouse desktop pet. Transparent background, no legs, no objects, no keyboard, no mouse, no hands or people. Keep the same muted plum material, subtle painted texture and clean Japanese anime linework. Wide canvas about 1536x640. The LEFT keyboard panel is a compact rectangular board angled diagonally from the lower-left foreground toward the upper-middle rear, so its long axis slopes upward to the right by about 18 degrees in the image. The RIGHT mouse panel is a compact rectangular board extending from the center toward viewer-right with the gentle original desk perspective. The two boards connect at their inner edges with a narrow visible joint, like a modular desk assembled from two pieces. Both top surfaces lie flat in the same horizontal plane, viewed from slightly above; never depict a vertically standing board or a hinged upright panel. Generous usable left top surface for a keyboard, usable right top surface for the mouse, coherent simple perspective, slim front lips and a tiny connector below the central seam. Keep silhouette balanced, slight shallow V arrangement, no supports below, clear empty transparency around component. Do not add glowing halos or cast shadows into transparent background.

User correction after the first desk preview: the boards should angle inward toward Viola. The same desk image was retained, and the two masked panels were reoriented in the renderer (-36° left, +18° right). Keyboard placement and lower-seat alignment follow this final inward layout. No second image-generation request was needed.

## 0.2.7 fuller leg source (built-in image_gen)

Selected transparent output: `Assets/Source/legs-anatomy-v0.2.7.png` (1254 × 1254 RGBA), also bundled in the character directory. Reference: retained `seating-sides-v0.2.5.png`. The request isolates two clothed anime legs with fuller knee/calf anatomy and clearer shin/ankle contours, retaining opaque dark plum stockings and the reference style. Exact prompt, reference paths, output path and generation mode are in `ASSET_PROMPTS_V0.2.7.json`. Runtime crop masks, overlaps and projection are application geometry, not additional image-generation passes.

## 0.2.8 independent heels and friend assistance

Built-in image_gen was used for slender leg edits, a separate matching pair of plum/gold pumps, two violet-sleeved cupped helper arms, Viola's downward amused expression, and repair of the background behind the friend's original forearms. All five selected final PNGs are stored in `Assets/Source/` and bundled. Exact prompts, final dimensions and earlier refinement prompts are in `ASSET_PROMPTS_V0.2.8.json`. Runtime polygons separate toe/rim from shoe backs, sleeves from palms, and eye/mouth patches from the source head. Original references and previous versions remain local.

## Right knee correction — 2026-10-01

Built-in imagegen edit of `legs-slender-v0.2.8.png`; retained only for `leg_back` and `leg_back_thigh`. New local source/runtime asset: `legs-right-knee-v0.2.12.png`.

Use case: precise-object-edit. Edit target original two black-stocking leg sprites on transparent 1280x1280 canvas. Correct ONLY LEFT sprite's knee, approximately x310..470 y240..470. Make a clearly visible anatomical correction: currently the kneecap is an angular bump at the far LEFT of the upper calf, with a deep right-side hollow, giving a reverse zigzag. Replace this with a smoother, forward-facing knee whose cap center is approximately x398 y327; align hip, knee and shin on a gentle descending diagonal from upper right to lower left. Thigh smoothly narrows as it descends into knee, then shin descends down and slightly left. Reduce the deep inward right-side knee notch and the leftward sideways kneecap bump. Knee surface is a soft rounded oval and stocking shading sweeps diagonally from HIGH upper-right toward LOWER bottom-left. Do not create a sharp inverted triangular fold. Preserve all pixels outside that knee/transition area as closely as possible, exact 1280x1280 atlas dimensions, sprite positions, all stocking shading elsewhere, and exact ankle and foot, no shoes. The RIGHT sprite must be unchanged. Preserve genuinely transparent background. No added objects or text.
