# Mossbank woods: a streamed 2.5D world

This branch launches `res://scenes/forest_25d/clearing.tscn` by default. Run
`godot --path .` or press F5. The playable world is **192 × 192 metres**, sixteen
times the area of the original 48 × 48 m clearing. Main retains the original
2D forest at `res://scenes/forest_2d/forest.tscn`.

Three lakes connect through a winding river and tributary, with four working
bridges. Forest paths lead to the forester’s cottage, old watchhouse, Alderwater
mill ruins, an overgrown orchard and a southern shelter. All five sites are
reachable with the real player collision radius. The cottage roof cuts away
when entered. Water, trunks, rocks, walls and the outer boundary block movement.

The fixed seed starts with **127 animals: 83 hares, 23 deer, 11 foxes, 9 boars,
and one lynx**. General placement uses the existing 60/17/17/5/1 species weights;
if those rolls produce no lynx, one distant territory is populated. Rare species
are not guaranteed near the start. Local replenishment retains species-specific
chances: hares frequent, deer/foxes less common, boars uncommon, lynxes rare.

Deer and foxes use rigged 3D models and source animation clips. Hares, boars and
lynxes use their existing painted animation strips on depth-tested upright
sprites. All five species retain their original roaming, avoidance, foraging,
pursuit and stun rules. Lynxes catch hares quickly and require three seconds of
continuous close contact with deer. Prey respawn away from the player. Oravitsa
cannot kill any animal.

Oravitsa keeps the approved eight-direction walk on a camera-facing sprite in
a true 3D depth buffer, with a ground contact shadow. Foreground foliage opens a
small dithered window around her so crowns do not completely hide her. This
keeps her approved face/clothes; the camera follows at a fixed heading/elevation.

## Controls

- Left stick / D-pad: walk; right-stick flicks: cycle animal targets.
- LB/RB: choose the highlighted skill; Y: cast it; A: pick up nearby food.
- WASD/arrows: walk; left click: target; right click/F: sling; Space: shoo.
- Keyboard/touch retain walk-over collection; touch skills are bottom left and
  movement is on the right above the inventory.
- M / Select: map; H / Start: help. Both start hidden.
- F3: optional frame-rate, draw-call and triangle counters.

## Streaming and persistence

Terrain, trees, rocks, grass, flowers and pickups stream in **16 m chunks** around
the visible camera area, including camera lag and a margin for tree overhang.
Phone and wide-window layouts derive coverage from the viewport. Native captures
load about 8–16 nearby chunks; the entire world is not instantiated at once.
Tree meshes/materials and animal animation resources are shared. Each pickup
cluster uses a single combined mesh. Only nearby animals have model instances
and active movement simulation. All animal positions, home areas, prey respawn
state and gathered-food state remain in memory when a chunk unloads. Offscreen
status timers continue; hunting progress resets when a predator deactivates.

Collision uses deterministic world data and spatial buckets independently of
loaded render chunks. The visible terrain and collision use the same analytic
height/water definitions. Bridge approaches flatten dry banks without damming
the channel. Terrain stays beneath bridge decks and the cottage foundation;
walking height uses the tops of those structures. Roof panels have small seams
instead of overlapping coplanar faces, avoiding depth-buffer flicker.
Gathered food does not reappear when returning to a chunk.

## Validation

Import once with `godot --headless --editor --import`, then run:

```sh
godot --headless --script scenes/forest_25d/smoke_test.gd
godot --headless --script scenes/forest_25d/world_smoke_test.gd
godot --headless --script scenes/forest_2d/smoke_test.gd
godot --headless --script scenes/forest_2d/mobile_smoke_test.gd
godot --headless --script scenes/forest_2d/sling_smoke_test.gd
godot --headless --script scenes/forest_2d/controller_smoke_test.gd
```

The world test checks species abundance, spawn clearance, distant collision,
stream/model unloading, gathered-food persistence, fox clips, prey model removal
and offscreen respawn, status recovery, stationary resizing, edge coverage, and
flood-fill reachability of all landmarks. More than 32,000 square-metre grid
positions connect to the start. GPU captures cover both large lakes, ruins,
arrival, world map and portrait/landscape layouts.

Short native samples at 1280×720 on Intel Iris Xe, with VSync disabled: about
139–163 FPS across three locations, with 362–490 draw calls and 142–160k rendered
triangles. These are native samples, not browser/mobile performance guarantees.
Web export uses the standard non-.NET Godot engine; an actual browser playtest
remains separate from successful export and package startup checks.

## Remaining scope

This is still an art/gameplay prototype. Buildings and dressing need further
art direction, and only deer/foxes have new rigged animal assets. There is no
camera orbit, swimming, building loot, quests, or save-to-disk persistence yet.
The source 2D scene retains its original large forest independently.

Asset license evidence, download sources and checksums:
[assets/ATTRIBUTION.md](assets/ATTRIBUTION.md).
