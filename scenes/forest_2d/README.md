# Scrolling forest scene

Run `res://scenes/forest_2d/forest.tscn`, or press F5 because it is the default
scene. The map has **416 × 416 cells of 114 px** each, 10.56 times the previous
128 × 128 map area. Grass and dirt textures are split into 11 × 11 tile atlases.
Atlas cells are placed in sequence and mirrored at each 11-cell edge so the
painting joins continuously. A shader blends dirt softly into grass. A fixed
seed shapes the winding dirt routes and object positions. Only the nearby
ground tiles, props, and animals are instantiated as the player explores;
collision and minimap colors come from the full map arrays.

The scene decodes its checked-in PNG files at runtime. A fresh checkout can
therefore launch directly without waiting for Godot to build `.godot/imported`.
An exported build would need to include those source PNGs in its export preset;
export packaging has not been tested yet.

| Ground or object | Walkable | Interaction |
| --- | --- | --- |
| Grass, dirt, fern | Yes | None |
| Mushroom | Yes | Collect by walking close |
| Tree, bush, stone, fallen log | No | Blocks movement |

The tree line at the outer edge keeps the player inside the map. Boars, deer,
foxes, and lynxes roam in short, obstacle-aware walks. They are ambient and can
be walked through; there is no combat or animal-foraging behavior here. Oravitsa
uses a new side-facing walk for horizontal travel and the existing front/back
strips for vertical travel. The timed boar/deer loop remains in the older
clearing scene.

## Art source

The seven new PNGs in `art/` were generated with Codex's built-in
`image_gen.imagegen` tool on 2026-10-18. The tool did not expose an underlying
model name or public API endpoint. The old painted forest clearing was supplied
as a style reference. The first three prompts below were preserved verbatim;
the remaining four are reconstructed from the generation requests because the
tool does not save a prompt manifest. Rejected attempts and every accepted PNG
are accounted for here.

- `grass.png`: “Generate a brand-new square tileable GAME TEXTURE, not a scene:
  seamless repeatable Nordic summer FOREST GRASS viewed straight down, matching
  the painterly colors and brushwork of the supplied forest-clearing style
  reference. Warm olive and yellow-green grass with small sparse clover and tiny
  flower flecks. Even visual density, no paths, no tree, no rocks, no large
  objects, no horizon, no shadows, no text, no border or vignette. The left/right
  and top/bottom edges must join seamlessly when repeated in a large 2D Godot
  tilemap. Opaque full-canvas texture.”
- `dirt.png`: “Generate a brand-new square tileable GAME TEXTURE, not a scene:
  seamless repeatable compacted earth and light DIRT for winding paths in the
  Nordic summer forest style of the supplied reference. Warm ochre soil with a
  few tiny pebbles, leaf fragments, sparse grass specks, painterly overhead
  lighting. Even visual density, no path shape or hard edge, no trees, no large
  objects, no horizon, no shadow, no text, no border or vignette. The left/right
  and top/bottom edges must join seamlessly when repeated in a large 2D Godot
  tilemap. Opaque full-canvas texture.”
- `tree.png`: “Single isolated Nordic forest TREE sprite for a cozy 2D Godot
  game, steep three-quarter overhead view: birch trunk and leafy golden-green
  canopy mixed with a dark spruce bough, visible roots, painterly detailed style
  matching the supplied forest reference. ONE object centered, full silhouette
  uncropped, genuine transparent PNG alpha background with absolutely no ground
  plane, gradient, glow, checkerboard, border, text or other objects.”
- `bush.png`, `stone.png`, `log.png`, `fern.png`: Each requested a single isolated
  named Nordic forest object in the same painterly, steep three-quarter overhead
  style, centered and uncropped on genuine transparent alpha without ground
  plane, gradient, text, or other objects. The log was specified as a mossy
  fallen birch log, the stone as mossy, and the bush as rounded and leafy.

Rejected attempts were an object sheet and an edit of that sheet; both retained
a painted backdrop. The following three accepted PNGs were generated in the
next iteration with the same built-in tool, using the existing walk strips as
visual references. Their prompts were preserved verbatim:

- `oravitsa_walk_side.png`: “Use case: stylized-concept. Asset type: transparent
  2D game walk-cycle sprite sheet. Use the supplied Oravitsa walk strip as exact
  character identity and painterly rendering reference. Create a NEW four-frame
  horizontal sprite sheet of the SAME young blonde girl with blue
  flower-patterned kerchief, cream blouse, brown vest and belt, green skirt,
  boots and wicker mushroom basket. Show her in convincing 90-degree SIDE
  PROFILE facing RIGHT, walking right in four DISTINCT sequential poses: left
  foot forward/contact, passing pose, right foot forward/contact, passing pose.
  Her head/body scale and identity stay consistent across frames, feet align to
  a common baseline, arms and legs visibly swing while the basket bobs subtly.
  Each complete character centered within an equal-width quarter of the wide
  image; no overlap or crop. Transparent PNG alpha; no shadow, no ground, no
  text, no borders. Match the painterly game art exactly.”
- `fox_walk.png`: “Use case: stylized-concept. Asset type: transparent 2D game
  walk-cycle sprite sheet. Using the supplied deer and boar strips as style,
  camera angle, scale, and four-frame layout references, depict ONE red fox
  from a steep three-quarter overhead view, facing RIGHT, in four clearly
  DIFFERENT sequential walking poses. Accurate red fox anatomy: slim rusty
  orange body, white chest and muzzle, dark lower legs, long bushy white-tipped
  tail. Legs alternate visibly and tail sways slightly while head/body
  proportions stay identical. Each full animal centered in its own equal-width
  quarter of a wide horizontal sheet; all paws share one ground baseline.
  Genuine transparent PNG alpha, no background/ground/shadow/text/borders, no
  other animals.”
- `lynx_walk.png`: “Use case: stylized-concept. Asset type: transparent 2D game
  walk-cycle sprite sheet. Using the supplied deer and boar strips as style,
  camera angle, scale, and four-frame layout references, depict ONE Eurasian
  lynx from a steep three-quarter overhead view, facing RIGHT, in four clearly
  DIFFERENT sequential walking poses. Accurate lynx anatomy: tawny spotted
  coat, prominent black ear tufts, short black-tipped bobtail, broad padded
  paws, compact muscular cat shape. Legs alternate visibly while head/body
  proportions stay identical. Each full animal centered in its own equal-width
  quarter of a wide horizontal sheet; all paws share one ground baseline.
  Genuine transparent PNG alpha, no background/ground/shadow/text/borders, no
  other animals.”

The boar/deer strips, front/back Oravitsa strips, and mushroom image are reused
from the earlier playtest. The PNGs are the source bitmaps. The generation tool
did not produce editable layer files.
