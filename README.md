# Oravitsa

Oravitsa is a cosy 2D forest game prototype. The current default scene explores a
larger world built from connecting painted tiles, with winding dirt paths, trees,
bushes, stones, ferns, fallen logs, and collectible mushrooms and berries. See the
[design](docs/design.md) and [character reference](docs/character.md).

## Play

Open this folder in **Godot 4.7** (tested with 4.7.2) and press **F5**, or run
`godot --path .` here. Use **WASD / arrows** to walk. The camera follows Oravitsa;
the minimap in the upper right shows the full forest. Grass, dirt, ferns, and
mushrooms and berries are passable. Walking over food collects it. Trees, bushes,
stones, and fallen logs block at their bases; dark green ground marks those
footprints while open diagonal gaps remain walkable. Press **Space** to shoo
nearby wildlife.

**Click an animal** to
select it, then **right-click**, press **F**, or click **Sling** to throw a stone. On phones,
tap the animal and then the **Sling** button. A gold ring marks the selected
target; the ring turns red when it is too far away. Stones stun on impact for
**3 seconds**, with a **4-second cooldown** and a **600 px** firing range.
Stunned animals stop moving and show circling stars, then recover. The sling
does not injure or remove animals. Clicking or tapping empty ground clears
the selection. Movement and Shoo remain available while using the sling.

Animals avoid each other and Oravitsa, forage, or hunt according to species. Bumping an animal briefly
stuns both of them.

Oravitsa now uses the approved eight-pose walk in all eight directions, with
separate westward views. Her gait follows actual movement and keeps its phase
through turns; blocked movement and stun return her to a grounded idle pose.

Hares are frequent, deer and foxes are less common, boars are uncommon, and
lynxes are rare. World generation and nearby wildlife replenishment both use
species-specific rates; the starting clearing introduces four hares.

The forest is **416 × 416 tiles**, 10.56 times the previous map area. It uses a
fixed seed, so paths and objects are the same on every run. Ground tiles and
nearby sprites stream around Oravitsa as she explores. The
[forest guide](scenes/forest_2d/README.md) explains the map and art sources.

The earlier timed, single-clearing foraging loop remains available at
`res://prototypes/foraging_2d/game.tscn`; open that scene and press **F6** to
play it. It includes the boar and deer and is documented in its
[playtest guide](prototypes/foraging_2d/README.md). The
[creation workflow](docs/2d-demo-workflow.md) records the original demo.

## Desktop and mobile Web builds

The project stays in **Godot 4.7.2 / GDScript**. Desktop keeps WASD, arrows,
and Space, with F to fire the sling. Touch devices show a thumb stick, Shoo,
and Sling buttons, with a HUD that
adapts to portrait and landscape. Keyboard and touch input can coexist.
The Compatibility renderer supports native desktop builds and WebGL 2 browsers.

Web export requires the **standard (non-.NET) Godot 4.7.2** editor together with
its matching **4.7.2.stable export templates** (install them in the editor via
*Editor > Manage Export Templates*). The .NET/Mono edition rejects Web export
even though this project uses only GDScript, and its templates
(`4.7.2.stable.mono`) are a different set. Select the standard executable with
`--godot` (or `GODOT_BIN`); `tools/export.py` stops early with an explanation
if the chosen engine is the .NET edition. Then:

```sh
# Website (build/site/) and native Linux executable (build/linux/)
python3 tools/export.py all

# Or export only one target; --godot selects a specific engine executable
python3 tools/export.py web --godot /path/to/standard/godot
python3 tools/export.py linux
```

Host `build/site/` on an HTTPS static host. The browser explicitly decompresses
the engine, so startup does not depend on the host applying `_headers` or
`Content-Encoding`. Content-hashed assets can be reused from browser cache.
The Web copy includes only the active forest and compresses its imported
textures at 85% quality, reducing the initial download from about 53 to 20 MiB.
Source PNGs, native desktop imports, sprite dimensions, and gameplay stay intact.
Downloads run alongside engine compilation, with byte progress and a retry
message for failures or a stalled connection. The single-threaded Web export
needs no cross-origin isolation headers. The ordinary
uncompressed `build/web/` export can also be served by a standard HTTP server.
Opening HTML directly with `file://` will not work.

Recent Android Chrome and iPhone Safari with WebGL 2 and browser gzip
decompression support (Safari 16.4 or later) are the mobile targets.
Real-device performance should be checked before a wider release. There is no
cloud game server or multiplayer service: hosting delivers the Godot game to
each browser. No game progress is persisted across reloads.

The GitHub **Build desktop and Web** workflow runs gameplay/touch smoke checks
and exports both targets. Its artifacts contain the ready-to-host website and
the native Linux executable. Other desktop targets remain available through
Godot's normal export dialog.

```sh
godot --headless --editor --import
godot --headless --script scenes/forest_2d/smoke_test.gd
godot --headless --script scenes/forest_2d/mobile_smoke_test.gd
godot --headless --script scenes/forest_2d/sling_smoke_test.gd
```

## Project layout

- `scenes/forest_2d/` — current scrolling forest scene, map script, minimap,
  painted tiles and forest objects.
- `prototypes/foraging_2d/` — earlier fixed-clearing game, retained as a
  separate playable experiment.
- `docs/character.md` and `character-drafts/` — canonical Oravitsa reference.
- `scenes/`, `scripts/`, `models/`, `art/`, and `resources/` also contain earlier
  3D experiments retained for history.

Oravitsa and all four animals display eight movement directions using five
painted views and three mirrored views. These strips are still prototype
animation. The new forest art was generated as bitmap assets and checked in
Godot at play size; no Tripo, Fal, or OpenRouter credits were used.

Diagonal movement uses the open diagonal cell when possible. Lynxes sprint in
short bursts and can catch hares quickly. Deer take three seconds of continuous
close pursuit to catch; both prey species return later away from the player.
Oravitsa cannot kill any animal,
including hares, in this iteration. The
new side and straight-back Oravitsa walk strips run four-pose loops.
Her south view is now straight-on, distinct from the southeast three-quarter
view.
