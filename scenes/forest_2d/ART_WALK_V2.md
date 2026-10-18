# Oravitsa walk revision

`art/oravitsa_walk_side_v2.png` and `art/oravitsa_walk_back_v2.png` were
generated with Codex's built-in `image_gen.imagegen` on 2026-10-18, using the
existing Oravitsa strips as visual references. No public image API, Tripo, Fal,
or editable layered source was involved. The accepted PNGs are the source
bitmaps. The earlier strips remain checked in for comparison.

The accepted side-strip prompt was:

> Use case: stylized-concept. Create a production-ready transparent 2D game
> sprite sheet of Oravitsa's COMPLETE CYCLIC WALK, four equal-width panels in
> one horizontal image. Preserve precisely the young blonde girl with
> navy-blue gold-floral kerchief, cream blouse, brown vest, moss-green skirt,
> brown boots, and wicker flower basket from reference. Camera/view: strict
> 90-degree right-facing side profile, her face fully in profile, basket on
> her back. Four CLEARLY DIFFERENT consecutive locomotion poses: frame 1 left
> boot forward with right arm forward; frame 2 left leg passing under her body
> and arms crossing neutral; frame 3 right boot forward with left arm forward;
> frame 4 right leg passing under her body and arms crossing neutral. This is
> one seamless full gait loop, with opposite contact poses and alternating
> passing poses; arms swing opposite legs, skirt and kerchief lag naturally.
> Keep fixed body scale, fixed head position, feet on same baseline. Every
> entire figure must fit in its own quarter panel with 10% transparent margin
> on BOTH LEFT AND RIGHT, especially panel 4; no clipping, no cross-panel
> overlap. Fully transparent alpha, no ground, no shadow, no glow, no text or
> panel separators. Painterly cozy forest game style identical to references.

The accepted straight-back strip prompt was:

> Generate a NEW transparent PNG game sprite sheet, NOT an illustration on a
> background. Four separate full-body poses of Oravitsa seen from EXACTLY
> STRAIGHT BEHIND, walking north away from the viewer. The existing rear strip
> shows her side and is WRONG; rotate the character to pure 180-degree REAR
> VIEW, both shoulders symmetric, wicker basket exactly centered on her back,
> back of navy blue gold-floral headscarf exactly centered with two tails, no
> face, no profile, no eyes, no nose. Cream blouse, moss green skirt, brown
> boots. Four equal-width panels, four sequential keyframes of one looping
> walk cycle: left boot backward contact, passing, right boot backward contact,
> passing. Opposite arm swing and soft skirt sway. Painterly style and scale
> match the supplied Oravitsa art. Complete silhouette centered inside EACH
> panel with transparent margins. BACKGROUND MUST HAVE ZERO ALPHA EVERYWHERE
> OUTSIDE FIGURES; no gradient, no ground, no lighting halo, no shadow, no text.

Three rear-view attempts were rejected: one was still a side/rear profile, and
two had an opaque gradient behind an otherwise good straight-back silhouette.
The accepted strip has a transparent background and a clear rear view. The
scene plays all four poses in each revised strip, without the prior repeated
middle-frame workaround. The view and alpha were checked visually and sheet
boundary pixels were inspected for clipping.
