# Mossbank: fixed-camera 2.5D clearing

This branch launches `res://scenes/forest_25d/clearing.tscn` by default. Run
`godot --path .` or press F5. The original playable forest remains available at
`res://scenes/forest_2d/forest.tscn` and is unchanged on `main`.

The slice contains a lake feeding a winding stream, a plank bridge, gently
rolling terrain, textured birch and pine trees, an overgrown abandoned cottage,
two rigged animated deer, and mushroom/berry pickups. The cottage doorway is
open; entering hides its roof, and leaving restores it. Water is impassable
except at the bridge. Tree trunks, rocks, walls, and the clearing boundary block
movement. The terrain continues beyond the playable boundary to avoid a void.

Oravitsa uses the approved eight-direction sprites on an upright camera-facing
plane in a true 3D depth buffer. Her contact shadow follows the ground. This
preserves her approved face and clothes; it does not introduce another generated
character or support rotating the camera around her. The camera follows at a
fixed elevation and heading. Deer use real 3D meshes, skeletons, and source clips.

## Controls

- Left stick / D-pad: walk; right-stick flicks: cycle animal targets.
- LB/RB: choose the highlighted skill; Y: cast it; A: pick up nearby food.
- WASD/arrows: walk; left click: target; right click/F: sling; Space: shoo.
- Keyboard/touch retain walk-over collection; touch skills are bottom left and
  movement is on the right above the inventory.
- M / Select: map; H / Start: help. Both start hidden.
- F3: optional frame-rate, draw-call, and triangle counters for evaluation.

## Implementation and limits

`clearing.gd` inherits the existing forest simulation and HUD. Only world
generation, collision queries, projection, and presentation are replaced.
One metre equals 64 simulation pixels. The visible height and collision queries
share `landscape.gd`'s analytic height/water functions. Terrain, cottage, and
bridge are generated locally; instanced trees/grass reduce draw calls. Foliage
uses alpha clipping and an unshaded tint to avoid transparency sorting and
black backfaces in the Compatibility renderer. Water uses a lightweight moving
surface shader, without refraction, reflection probes, or swimming.

This is a small art/gameplay comparison, not a conversion of the full forest.
The cottage and vegetation dressing need further art direction; only deer have
new animal assets. There is no large-world streaming, expanded animal ecology,
interior loot, or persistent world saving in this slice. The source 2D scene
retains its large forest and original animal ecology.

## Validation

Import once with `godot --headless --editor --import`, then run:

```sh
godot --headless --script scenes/forest_25d/smoke_test.gd
godot --headless --script scenes/forest_2d/smoke_test.gd
godot --headless --script scenes/forest_2d/mobile_smoke_test.gd
godot --headless --script scenes/forest_2d/sling_smoke_test.gd
godot --headless --script scenes/forest_2d/controller_smoke_test.gd
```

The 2.5D check covers depth-enabled character rendering, coordinate conversion,
ground height, water/boundary/bridge/wall/door collision, roof cutaway, rigged deer
clips, projected mouse targeting, non-lethal stuns, removal of gathered 3D props,
inventory counts, and inherited controller actions. GPU captures cover arrival,
bridge, cottage interior, and portrait/landscape layouts. Web export uses the
standard non-.NET engine through `tools/export.py`; the export copies this scene
only when it is the project's main scene.

Local native sample: about 152 FPS at 1280×720 on Intel Iris Xe, with VSync
disabled, approximately 340 draw calls and 400k rendered triangles. This is a
short arrival-view sample, not a browser/mobile performance guarantee. The Web
package is about 21.5 MiB and exports successfully. Browser UI automation could
not verify Chrome's current URL and stopped, so an actual browser playtest
remains to be done. F3 exposes counters for that comparison.

Asset sources, license evidence, and checksums are in [assets/ATTRIBUTION.md](assets/ATTRIBUTION.md).
