# Right seated knee geometry, 2026-10-01

User requirement: `大腿从下向上，小腿从上向下` for Viola's right leg (screen left).

The previous asset smoothed the knee shading but kept the hip above the knee. The new generated sprite `leg-right-seated-v0.2.12.png` has a lower-right hip, an upper-left knee and a hanging calf. It was generated with the built-in imagegen tool, saved without bitmap edits, and copied to Assets/Source, Resources/Characters/Viola and the Preview profile's character-assets directory.

## Runtime rig

- Shared knee pivot approximately `(205.0, 363.0)` in the y-up canvas.
- Hip attachment near `(305.1, 310.5)`, so the thigh rises from hip to knee.
- Sock foot shoe contact `(166.5, 132.0)`, within about 2 px of the previous contact; independent 62.328 px shoe rig remains in use.
- Calf sprite uses crop `[100,200,410,1330]`, frame `[148.9,115.2,90.2,279.3]`, knee anchor `[255/410,1180/1330]` and contact `[80/410,80/1330]`.
- Thigh uses crop `[100,200,800,530]`, frame `[148.9,283.2,176,111.3]` and a polygon isolating the upper/right segment. The thigh is drawn behind the seating artwork to avoid covering the supporting girl's face. The calf keeps the original rear-shoe/calf/front-shoe ordering.
- Existing swingMultiplier, perspectiveDistance and sideSwingMultiplier are preserved. No Swift renderer, animation or shoe-state code was changed.

## Validation and scope

Installed application `Viola 新版.app` exported 16 art states with `--render-gallery --layout --art-only`. Visual review covered idle, legs-forward, legs-back and the combined side/front swing states. `--laugh-stills` exported 10 selected full-size laughter frames; the rounded knee cap, descending calf and attached shoe were reviewed across early, strong and opposite swing poses. The exported images are renderer artwork evidence; no keyboard input or shoe recovery behavior assertion was run.

Final candidate preview: `build/previews-v0.2.12-seated-right-knee/final-gallery-v4/` and `final-laugh-v4/`. Applied profile preview: `build/previews-v0.2.12-seated-right-knee/applied-gallery/`.

An additional 121-frame `--laugh-art` export located right-leg positive and negative extrema near frames 20/52/63 (approximately the full 0.76-radian swing). The 0.625-scale images show the previously reported strip-mesh sampling lines, so they support extreme-pose geometry inspection only. Full-size stills remain the useful artwork reference for texture quality.

Both the source manifest and `~/Library/Application Support/ViolaDesktop-Preview/character-layout.json` were updated surgically: only the two right-leg definitions and thigh order changed. Original manifests are retained as `source-before-seated-*.json` and `profile-before-seated-*.json` in the preview directory. No application executable or signature was modified and no application process was restarted by this worker. The lead agent owns the coordinated native refresh and target-app screenshot.

Known previous artwork limitation: a small pale floor patch is exposed near the old right-foot area during some backward/upward leg poses. This patch also exists in the earlier right-knee galleries and is not an animation state failure.

Prompts and the generated image path are retained in `docs/ASSET_PROMPTS_SEATED_RIGHT_KNEE_V0.2.12.json`.

## Height restoration after user feedback

The first seated revision lowered the leg frame top from `445.055341` to `394.5`. The accepted height restoration keeps the original foot contact y exactly at `131.651625` and restores the frame top exactly to `445.055341`, using vertical scale `0.250722973` for the existing seated sprite. The knee is now `(205.0,407.446895)` and the lower hip attachment is `(305.1,344.766152)`, preserving the thigh's upward direction and the calf's downward direction. The raised knee cap is partly occluded by the desk, as shown in the accepted full-size preview.

Only `leg_back` and `leg_back_thigh` were copied from the accepted candidate into the source and Preview manifests; sprite order and all other definitions were preserved. Pre-change backups are in `build/previews-v0.2.12-seated-right-height-restored/*-before-height-restored-*.json`. The accepted full-size preview is `build/previews-v0.2.12-seated-right-height-restored/gallery/idle.png`, with the candidate configuration alongside it. No asset bytes, executable, signature or UI state were changed in this restoration.
