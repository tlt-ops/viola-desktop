# Reference seated pose 0.2.15

The user selected the final seated reference as the character visual target and explicitly kept the existing two desks, keyboard and mouse. This supersedes the earlier reconstructed stocking legs and mapped skin bands.

The new legs and exposed side of the thigh reuse original RGBA pixels from the selected reference. Each atlas retains the original 1312×1199 source positions. The shared lower-body crop is [240,560,1072,630], registered to [128.833992,60,646.166008,375]. The 20-point downward placement exposes the side opening beneath the existing desk without changing the desks to those shown in the reference.

The original visible plum/ivory skirt is extracted at [590,497,430,290], with complete compressed left folds, broad right plum panel and ivory hem. It uses the same registration as the legs and skin. Skin is a solid sprite; the skirt has its separate inertia mesh. Shoe-hook motion carries the skin with its thigh, and shoes use the new source foot contacts.

Leg anchors (original image coordinates): back hip (400,595), back knee (345,845), back foot (286,1070); front hip (790,587), front knee (714,650), front foot (775,1100). Forward swing gain is 0.65 and lateral gain 0.6. Calf strips begin at source y825 back/y635 front and overlap the static upper leg beneath the skirt.

The two desk positions/orientations and key mapping are retained. The temporary keyboard-board cutout is removed, and the mouse board depth is 110 rather than 80 points. The mouse hand remains raised to meet this surface.

Visual exports are art review; live keyboard access still depends on macOS Input Monitoring matching the current app signature.
