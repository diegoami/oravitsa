# Mossbank woods: a streamed 2.5D world

The default scene is `res://scenes/forest_25d/clearing.tscn`. Run
`godot --path .` or press F5. The playable world is **192 × 192 metres**, sixteen
times the area of the original 48 × 48 m clearing. The project retains the original
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
cannot kill any animal. Respawns and new arrivals are excluded from the actual
smoothed camera view, including animal height and an extra screen margin.
The entry ring and population radius adapt to wide/portrait viewports.

Oravitsa keeps the approved eight-direction walk on a camera-facing sprite in
a true 3D depth buffer, with a ground contact shadow. Foreground foliage opens a
small dithered window around her so crowns do not completely hide her. This
keeps her approved face/clothes; the camera follows at a fixed heading/elevation.
The reveal closely surrounds her silhouette, fades with foreground depth, and
anchors its stipple to world positions instead of the screen. Leaves receive
lighting with a little backlight; cool ambient fill and warm sunlight give the
canopy depth. A single orthographic shadow map avoids cascade transitions in
the fixed view. Terrain uses smooth normals shared across chunk boundaries,
with quieter grass variation and broad, slow water ripples to reduce shimmer.

## Controls

- Left stick / D-pad: walk; right-stick flicks: cycle animal targets.
- LT: Shoo; RT: Sling (once per pull). LB/RB + Y: choose and cast a skill.
- A: pick up nearby food.
- WASD/arrows: walk; left click: target; right click/F: sling; Space: scare target.
- Shoo shares Sling's range and applies five seconds of visible scared status (an icon with a time-left bar)
  and fast escape away from Oravitsa, with a seven-second cooldown.
- Keyboard/touch retain walk-over collection; touch skills are bottom left and
  movement is on the right above the inventory.
- M / Select: map; H / Start: help. Both start hidden.
- F3: optional frame-rate, draw-call and triangle counters.

## Streaming and persistence

Terrain, trees, rocks, grass, flowers and pickups stream in **16 m chunks** around
the visible camera area, including camera lag and a margin for tree overhang.
Phone and wide-window layouts derive coverage from the viewport. Native captures
load about 8–16 nearby chunks; the entire world is not instantiated at once.
During walking, a nearest-first queue builds at most one new chunk per frame
inside the 9 m margin; repeated refreshes share that frame's budget. Reversing
direction discards stale requests. Startup, teleports larger than the margin
and viewport resizing fill the new view immediately before it is drawn.
Tree meshes/materials and animal animation resources are shared. Each pickup
cluster uses a single combined mesh. Only nearby animals have model instances
and active movement simulation. All animal positions, home areas, prey respawn
state and gathered-food state remain in memory when a chunk unloads. Offscreen
status timers continue; hunting progress resets when a predator deactivates.

Collision uses deterministic world data and spatial buckets independently of
loaded render chunks. The visible terrain and collision use the same analytic
height/water definitions. Bridge approaches flatten dry banks without damming
the channel. Terrain stays beneath bridge decks and the cottage foundation;
walking height uses the tops of those structures.
Wooden bridge approaches and the stone doorstep ramp blend walking height into
the deck/floor without raising the riverbed or duplicating the deck in terrain.
Roof panels have small seams instead of overlapping coplanar faces, avoiding
depth-buffer flicker.
Gathered food does not reappear when returning to a chunk.

## Validation

Run the shared error-aware gate (it imports first):

```sh
python3 tools/verify.py --godot /path/to/standard/godot
```

The world test checks species abundance, spawn clearance, distant collision,
stream/model unloading, gathered-food persistence, fox clips, prey model removal
and offscreen respawn, status recovery, stationary resizing, edge coverage, and
flood-fill reachability of all landmarks. The scene test also checks ground
clearance beneath structures and matching terrain normals at chunk boundaries.
More than 32,000 square-metre grid
positions connect to the start. GPU captures cover both large lakes, ruins,
arrival, world map and portrait/landscape layouts.

Use F3 to inspect native frame rate, draw calls and triangle counts on the
target device. Native samples do not predict browser/mobile performance.
Web export uses the standard non-.NET Godot engine; an actual browser playtest
remains separate from successful export and package startup checks.

## Remaining scope

This is still an art/gameplay prototype. Buildings and dressing need further
art direction, and only deer/foxes have new rigged animal assets. There is no
camera orbit, swimming, building loot, quests, or save-to-disk persistence yet.
The source 2D scene retains its original large forest independently.

Asset license evidence, download sources and checksums:
[assets/ATTRIBUTION.md](assets/ATTRIBUTION.md).

## Starting-area dressing

The cottage and first bridge are the reference area for the next art pass.
The cottage has layered shingles, a gable, timber braces, chipped plaster,
foundation stones, side-window framing, firewood and a broken fence. All new
roof geometry follows the existing interior cutaway. A broken bridge rail and
worn approach stones leave the crossing clear.

A short stone path leads east to the forester's old well, with two real mushroom
patches nearby. Its ring blocks walking; its approach stays reachable and the
nearby label names the discovery. Gathered mushrooms retain the usual inventory
and streaming persistence rules. The well is a landmark, not an interaction yet.

Shallow-water colour and wet bank shading share the same waterway definitions.
Banks meet the water at the collision shoreline. A finer terrain grid smooths
shore silhouettes; reeds, seed heads and small stones stream around the starting
lake/river. Low dressing stones can be stepped over, while the well, woodpile
and fence posts use persistent collision. Cottage details are combined by
material to keep draw calls bounded. These additions use procedural geometry
and existing materials, with no new external assets.
