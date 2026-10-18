# Scrolling forest scene

Run `res://scenes/forest_2d/forest.tscn`, or press F5 because it is the default
scene. The map has 128 × 128 cells of 114 px each. The grass and dirt textures
are split into 11 × 11 tile atlases. Atlas cells are placed in sequence and
mirrored at each 11-cell edge so the painting joins continuously, rather than
choosing unrelated random tile fragments. A fixed seed shapes the winding dirt
routes and the object positions. Nearby props are streamed around the player;
collision and minimap colors come from the same `objects` array.

| Ground or object | Walkable | Interaction |
| --- | --- | --- |
| Grass, dirt, fern | Yes | None |
| Mushroom | Yes | Collect by walking close |
| Tree, bush, stone, fallen log | No | Blocks movement |

The tree line at the outer edge keeps the player inside the map. This iteration
tests scale, route choice, visibility, and collecting while exploring. The timed
boar/deer loop remains in the older clearing scene.

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
a painted backdrop. Oravitsa's walk strips and mushroom image are reused from
the earlier playtest. These PNGs are the source bitmaps. The generation tool did
not produce editable layer files.
