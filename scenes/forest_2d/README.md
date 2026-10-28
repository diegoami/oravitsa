# Scrolling forest scene

Run `res://scenes/forest_2d/forest.tscn`, or press F5 because it is the default
scene. The map has **416 × 416 cells of 114 px** each, 10.56 times the previous
128 × 128 map area. Grass and dirt textures are split into 11 × 11 tile atlases.
Atlas cells are placed in sequence and mirrored at each 11-cell edge so the
painting joins continuously. A shader blends dirt softly into grass. A fixed
seed shapes the winding dirt routes and object positions. Only the nearby
ground tiles, props, and animals are instantiated as the player explores;
collision and minimap colors come from the full map arrays.

Open the project in the editor once (or run `godot --headless --editor --import`)
to import its textures. The desktop and Web exports use Godot's imported art.

| Ground or object | Walkable | Interaction |
| --- | --- | --- |
| Grass, dirt, fern | Yes | None |
| Mushroom | Yes | Collect by walking close |
| Fallen berries | Yes | Collect by walking close; boars, deer, and hares eat them |
| Tree, bush, stone, fallen log | No | Blocks movement |

The tree line at the outer edge keeps the player inside the map. Dark green
ground beneath trees and bushes marks blocked vegetation; bright grass and dirt
remain passable. Tree, bush, stone, and log collision follows their small base
footprints instead of filling their whole tile, so a visible diagonal gap
between two props can be crossed. Animals and Oravitsa have solid circular
footprints. Walking into an awake animal
stuns both for 1.2 seconds; Oravitsa walks through stunned animals, and
stepping out of one that woke up under her is not a bump. Select an animal, then Space scares that target
within 600 px for five seconds, with a seven-second cooldown. A sweat-drops icon
with a time-left bar marks its fast escape away from Oravitsa. Invalid casts spend no
cooldown. Boars move slowly, forage for mushrooms and berries,
and sometimes hold their ground near Oravitsa. Deer seek berries and flee
lynxes; lynxes pursue nearby deer and hares in 1.5-second bursts at 220 px/s,
then recover before sprinting again. Hares are caught immediately on contact;
deer require three seconds of continuous close pursuit. The lynx keeps pace
while attempting a deer catch; losing contact, switching prey, being shooed,
or being stunned resets the attempt. A lynx that catches prey pauses to feed;
the prey returns at its home area after 25 seconds, once that area is clear
and away from Oravitsa. Hares seek berries and flee lynxes. Oravitsa cannot
kill any animal, including hares. Foxes flee every nearby animal. All species avoid Oravitsa only
when she comes close, except for some boars that hold their ground. Their
roaming targets persist for several seconds and stay near their home area.
World generation chooses species with relative weights of **60% hare, 17% deer,
17% fox, 5% boar, and 1% lynx**. These are selection probabilities; actual
counts vary with the fixed seed and available clear ground. Four hares start
near the clearing; rare animals are not placed there as guaranteed encounters.
Every seven seconds, the forest checks for wildlife within about 1,150 px of
Oravitsa. When a species is scarce, it may move an offscreen animal of that
species into a clear location 730–1,150 px away, or add one if needed.
The chance per check is 100% for hares, 35% each for deer and foxes, 12% for
boars, and 2% for lynxes. Local refill targets are four hares, two deer, two
foxes, one boar, and one lynx. These are refill targets, not hard population
caps or guaranteed encounters; rare species can remain absent for many checks.
The minimap shows colored markers for all living animals, with a species key
beneath it; Oravitsa is the bright outlined marker.

Click or tap an animal to select it, then right-click, press F, or use Sling to fire. The range
is 600 px, the cooldown is four seconds, and a hit stuns for 4.5 seconds
without injury or removal. A hit never extends an existing stun, which
prevents stun-locking with the shorter cooldown. Oravitsa can walk through a
stunned animal without bumping it, so its longer stun is never replaced. A dizzy-stars icon with a time-left bar is shown above the animal. States use
the hand-drawn SVG icons in `status_icons/` (CC0, see `PROVENANCE.md`); no
state is shown as text.
The selection ring, flying stone, and circling stun stars are drawn effects;
Oravitsa currently keeps her walking or idle pose rather than a sling animation.
Controllers use the left stick or D-pad to walk and right-stick flicks to cycle
in-range living targets, nearest first. LT/L2 casts Shoo and RT/R2 casts Sling
directly (once per pull past 60%, re-armed below 30%). LB/RB (L1/R1) still switch
the highlighted active skill and Y/Triangle casts it; trigger casts leave that
selection unchanged. A/Cross picks up food within 40 px; controller
walking does not collect automatically. Keyboard and touch retain walk-over pickup.
Stick targeting requires returning to center between targets; shoulder buttons switch once per press.
The bottom-left skill slots show icons, cooldowns, and the active input prompts.
Berries and mushrooms have icons and counts in the bottom-right inventory; the
touch movement stick sits above it. Map and Help start hidden and toggle
independently with their buttons, M/H, or Select/Start.

Oravitsa uses the approved Tripo/Meshy walk with local shoe, skirt, and arm
repairs: eight distinct poses in each of eight directions, including separate
westward views. `art/oravitsa/walk.tres` stores the shared SpriteFrames, measured
foot pivot, display scale, and cycle timing. Gait advances from distance actually
travelled, retaining phase through turns and pauses. Blocking and stun stop the
walk; idle displays the first grounded pose. Partial touch input slows the gait.
`art/oravitsa/provenance.json` records the installed atlas hashes and repairs.
To regenerate the approved assets, render, package, and validate the local
`build/fal-walk` export, then run `python art/install_approved_walk.py`.

Animals retain their existing source strips and mirror the three westward views.
Diagonal input first tests the direct diagonal destination;
if blocked, movement can still slide along a clear horizontal or vertical edge.

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

The later directional strips and berry art are documented in
[ART_ECOLOGY.md](ART_ECOLOGY.md).
The revised Oravitsa walking art is documented in [ART_WALK_V2.md](ART_WALK_V2.md).
