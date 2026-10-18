# Ecology iteration art source

The 19 new PNGs (`berries.png`, two Oravitsa diagonals, and four new directions
for each animal) were generated with Codex's built-in `image_gen.imagegen` on
2026-10-18. No Tripo, Fal, or public image API was used. The original boar,
deer, fox, lynx, and Oravitsa strips were passed as references. The accepted
PNGs in `art/` are the source bitmaps; the tool supplied no editable layers.

For each boar/deer/fox/lynx directional strip, the exact prompt template was:

> Use case: stylized-concept. Asset type: transparent four-frame horizontal
> walk-cycle strip for a 2D top-down forest game. Use the supplied {name} walk
> strip as the EXACT species identity, painterly style, body proportions and
> camera height reference. Draw the same {detail} walking {orientation}. Four
> distinct sequential gait poses with alternating legs, stable body size,
> coherent anatomy, and feet/paws on a common baseline. Each complete animal
> centered in an equal-width quarter of the wide image, no touching or cropping
> at the edges. Genuine transparent PNG alpha; no background, ground, shadow,
> text, border, or other animals.

`{name}` was `boar`, `deer`, `fox`, or `lynx`. `{detail}` respectively was
“stocky brown wild boar, bristled shoulders, short legs, blunt snout and small
tusks”, “slender tawny roe deer with white rump, long delicate legs and large
ears”, “slim red fox with rusty orange coat, white chest and muzzle, black
lower legs, white-tipped bushy tail”, or “compact Eurasian lynx with tawny
spotted coat, black ear tufts, short black-tipped tail and broad paws”. The
`{orientation}` was one of “directly TOWARD the viewer, frontal face and chest
visible”, “directly AWAY from the viewer, rear and back visible”, “DIAGONALLY
UP-RIGHT, three-quarter rear view”, and “directly RIGHT, strict side profile”.

The Oravitsa diagonal requests followed the same transparent four-frame
layout, using her existing front/side/back strips as exact character and style
references, for southeast and northeast movement. The northeast prompt asked
for a three-quarter rear view with her blue kerchief, wicker basket, green
skirt, and alternating feet; the southeast prompt asked for a three-quarter
front view with the same identity and gait. These exact requests were not
captured verbatim before generation. The berry request was preserved verbatim:

> Use case: stylized-concept. A single top-down 2D game collectible prop for a
> cozy painted forest: a small low cluster of fallen wild red berries and a
> few blueberries nestled among tiny leaves, unmistakably edible and fully
> traversable, centered with generous transparent margins. Painterly soft
> detailed fantasy game asset, warm natural colors, readable at 30 pixels, no
> bush, no ground tile, no shadow, no character, no text, genuine transparent
> PNG alpha.

The fourth poses of several strips reached the sheet boundary. Edit attempts
for `lynx_walk_e.png`, `deer_walk_e.png`, and `oravitsa_walk_ne.png` did not
fix that issue and were rejected. The scene plays the first three complete
poses in a mirrored 0-1-2-1 cycle for generated strips.
