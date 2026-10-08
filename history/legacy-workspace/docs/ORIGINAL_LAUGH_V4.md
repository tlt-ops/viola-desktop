# Original rocking laugh restored in 0.2.48

The user requested the earliest energetic laugh: Viola rocks with the supporting girl's unstable sway, shakes with laughter and alternately kicks both legs; the purple-haired girl shows effort. This replaces the 8-second painted belly-laugh and tear-wipe introduced in 0.2.45–0.2.47.

The current 0.2.47 application, sources and profile were preserved in `~/Library/Caches/ViolaDesktop/original-laugh-v0.2.48/` before editing.

The original 5.6-second clip, 0.42-second entry and 0.7-second exit are restored from the surviving 0.2.44 source (which continues the 0.2.12 motion). Bounce uses sin(17t)*2.6+sin(8.5t)*1.4; supporting sway uses sin(5.1t)*0.055+sin(11.7t)*0.012; dip is -(3.5+sin(8.5t)*2.5). Opposing leg motion uses sin(5.8t)*0.82 and sin(5.8t+2.1)*0.76, with side swings 0.15 and 0.14. The supplied full-body reference retains the 0.2.44 renderer scaling of 0.45 for forward/backward projection and 0.25 for side swings.

There was no independent upper-body rotation in the surviving original implementation. The supporting girl's ground-line-fixed transform carries the seated rider sideways and down; the rider's own bounce is added. Original head, torso, skirt, thighs and source sleeves remain visible through the entire clip. The original source arm branch moves both extracted hands to the abdomen. Existing straight keyboard and mouse solvers resume at the exit. The mouse itself parks on the desk during the hand movement.

The registered face patches show Viola's open laughing mouth and partial lids. The purple-haired girl's effort brows, tightened mouth and small sweat remain; neither laugh face fully closes. The unrelated idle blink cannot override the laugh eyes. Normal independent blinking, breathing, disabled automatic sleep, input monitoring, crawling, table arrangement and user geometry are retained.

Validation: Release build; 40 core checks including motion continuity, opposing kicks, support sway, reduced-motion 35 percent, input-independent clip timing and 10 seconds of normal idle blinking; 768 renderer timeline stages with desks shown and hidden; 269 held-pose input stages; complete source-arm return/all-key/mouse-corner checks; 10 ordinary RGBA images match 0.2.47 exactly. Native installation/playback is recorded separately in the cache verification evidence.

`original-laugh-v4-contract.json` pins the saved motion, abdomen-pose helper and face constants and checks that the renderer consumes them. The previous v3 contract/art remain archived. Changes to unrelated interactions must retain this saved clip unless the user explicitly requests another laugh change.
