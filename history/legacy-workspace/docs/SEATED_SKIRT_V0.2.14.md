# Seated skirt and support motion 0.2.14

The user authorized programmatic cropping of the supplied reference's thighs and skirt. Original plum/ivory folds and the stocking edge are reused rather than replacing the costume design. Atlas dimensions and leg joints remain fixed; upper-thigh color regions change independently of the calves and shoe recovery chain.

Two independent cloth sprites, `viola_skirt` and `friend_skirt`, use damped inertia with a pinned upper attachment and deforming lower hem. This is a sprite mesh approximation, not a cloth collision solver. Reduced Motion resets both meshes to static geometry.

Both desk panels have reduced depth while retaining the keyboard and mouse supports. The keyboard moves with its board toward Viola; the left hand's target is still calculated from the renderer's actual key contact.

Purple-haired support character: slow breathing and small tremble share one deformation across body and expression layers. The palm contact line stays fixed. Separate alpha mattes remove the reference's floor/cast shadow while keeping source RGB pixels.

Artwork export: `--render-gallery ... --layout ... --friend-motion-stills` produces 9 stills and 540 sampled poses, including cloth offsets. These exports are artwork review, not proof of global keyboard permissions or native desktop acceptance.
