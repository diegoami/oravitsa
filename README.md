# Oravitsa

Contribution and verification rules: [AGENTS.md](AGENTS.md). Independent
[PR reviews](docs/review-pr.md) use a separate session; formal
[milestone reviews](docs/RELEASES.md) happen before a release tag.

Oravitsa is a cosy forest game prototype. The default scene is the **endless
Mossbank woods**: a procedural 2.5D world with meandering roads and waterways,
generated bridges, lakes, ruins, standing stones and abandoned camps. Walk in
any direction through meadows, birch, pine and alder-marsh areas. Gather food
and watch six wildlife species. See the [endless-world guide](scenes/endless_woods/README.md),
[design](docs/design.md) and [character reference](docs/character.md).

## Play

Open this folder in **Godot 4.7.2** and press **F5**, or run
`godot --path .` here. Use **WASD / arrows** to walk. The camera follows Oravitsa;
map and help start hidden, toggled with **M/H** or their buttons. Walking over
food collects it with keyboard/touch; on controller press **A/Cross** nearby.
Water, trunks, large rocks, walls and the well block movement; use bridges to
cross the waterways. Low path and shore stones can be stepped over. The cottage
roof cuts away inside. Select an animal, then press **Space** to Shoo it.

**Click an animal** to
select it, then **right-click**, press **F**, or click **Sling** to throw a stone. On phones,
tap the animal and then the **Sling** button. A gold ring marks the selected
target; the ring turns red when it is too far away. Stones stun on impact for
**4.5 seconds**, with a **4-second cooldown** and a **600 px** firing range.
A hit on an animal that is already stunned does not extend the stun, so an
animal always gets to recover. Stunned animals stop moving and show a
`STUNNED` countdown, then recover. The sling
does not injure or remove animals. **A stunned hare can be collected for raw
meat**: walk up to it (or press A on a controller) while it is still stunned.
It is removed once and adds one raw meat to the inventory's third slot, with a
`+1 raw meat` notice. Alert hares, other species and a stunned Oravitsa cannot
collect. In the endless woods a collected hare does not respawn; the sparse
population brings a new hare later. In the finite scenes it returns like a caught
hare. Clicking or tapping empty ground clears
the selection. Movement and Shoo remain available while using the sling.

**Shoo uses the same selected animal and range as Sling** (600 simulation px,
about 9.4 m in 2.5D). Space, the Shoo button, controller LT, or Y with Shoo selected
gives that animal **five seconds of SCARED status**, shown above its head with
a countdown. It immediately abandons feeding/hunting and runs away from
Oravitsa faster than she can walk. Existing animal stun is cleared so it can
flee immediately. No target, a dead/out-of-range target, player stun or cooldown
prevents the cast without wasting its seven-second cooldown. Other animals
are unaffected; normal behavior returns after fear expires. Both skills remain
non-lethal.

Animals avoid each other and Oravitsa, forage, or hunt according to species.
In the endless woods, lingering close to a wolf, lynx or boar for a few seconds
may make it angry: after a red `!! ANGRY` warning it charges, and if it reaches
Oravitsa she is stunned for two seconds. Back away or Shoo it to avoid the
charge. Afterwards it loses interest. Wolves, lynxes and boars of different
species occasionally fight each other; the loser is stunned, never hurt. Bumping an animal
stuns both of them for **1.2 seconds**; the skill bar shows Oravitsa's
recovery countdown.

Oravitsa now uses the approved eight-pose walk in all eight directions, with
separate westward views. Her gait follows actual movement and keeps its phase
through turns; blocked movement and stun return her to a grounded idle pose.

Hares are frequent, deer and foxes are less common, boars are uncommon, and
wolves and lynxes are more frequent than in the retained finite scene. The
woods are deliberately sparse: the fixed seed starts with **34 animals: 17
hares, 8 deer, 3 foxes, 2 boars, 2 lynxes and 2 wolves**, with two hares near
arrival, and food patches are about a third as dense as in v0.1. Replenishment
keeps species-specific chances. New arrivals and respawns
wait outside the actual camera view, including its smoothing lag.

Terrain, trees, food and nearby animal models stream around the camera. Gathered
food and wildlife state survive leaving and returning to an area during the
session. **The endless woods can be saved and resumed**: press **K** to save
and **L** to load, use the Save/Load buttons under Help, or press **X**/**B** on
a controller while Help is open. There is one manual save slot and no autosave.
The save restores Oravitsa's absolute location, inventory, cooldowns, depleted
food with its regrowth deadlines, and wildlife state. Game time is paused while
the game is closed. Finite scenes are not saved.
Berries can regrow after **3–6 minutes** and mushrooms after **5–9 minutes**,
with staggered timers. Due patches wait until offscreen before reappearing;
leaving/revisiting a region does not reset their countdown.
Rendering rebases its local origin during long walks; generated world data has
no fixed playable border. Only nearby terrain and animal visuals stay loaded.

The endless woods have a quiet looping forest ambience, and nearby animals
occasionally call (wolves howl, boars grunt, foxes yip…). Distant ones stay
silent. Press **9**/**0** or use the Help panel buttons to cycle forest and
animal volume (100/60/30%/Off). In a browser, sound starts after your first
click, key or touch. The sounds are original synthesized CC0 audio.

The earlier **192 × 192 m clearing** remains playable at
`res://scenes/forest_25d/clearing.tscn`, with its three lakes, four bridges and
five abandoned sites. Its [guide](scenes/forest_25d/README.md) describes that
finite version. The independently pinned alpha draft remains unchanged by
this development branch.

The original painted **416 × 416 tile 2D forest** remains playable at
`res://scenes/forest_2d/forest.tscn`; open it and press **F6**. Its dark blocked
ground and tile/sprite streaming are described in the
[2D forest guide](scenes/forest_2d/README.md).

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

Controllers use the **left stick or D-pad** to move and **right-stick flicks**
to cycle nearby living animal targets. **LT/L2 casts Shoo and RT/R2 casts
Sling** directly at the selected animal. A trigger fires once when pulled past
60% and re-arms after it is released below 30%, so holding it never repeats
the cast. The earlier path still works: **LB/RB (L1/R1)** select a skill and
**Y/Triangle** casts it; a trigger cast does not change that selection.
**A/Cross** picks up food within reach. Return the stick to center between
targets. The active skill has a gold outline; each slot shows its trigger, `· Y`
on the selected one, and its cooldown.
Stick movement is analog with a deadzone, so gentle input walks more slowly.
On Web, enter the forest and press a controller button to let the browser detect it.

Shoo and Sling appear in the bottom-left skill bar with icons, cooldown timers,
and prompts that follow keyboard/mouse, controller, or touch input. Berries and
mushrooms appear as icons and counts in the bottom-right inventory. On phones,
the movement stick sits above the inventory. Map and Help start hidden; open
or collapse them with their buttons, **M/H**, or controller **Select/Start**.

Web export requires the **standard (non-.NET) Godot 4.7.2** editor together with
its matching **4.7.2.stable export templates** (install them in the editor via
*Editor > Manage Export Templates*). The .NET/Mono edition rejects Web export
even though this project uses only GDScript, and its templates
(`4.7.2.stable.mono`) are a different set. Select the standard executable with
`--godot` (or `GODOT_BIN`); `tools/export.py` stops early with an explanation
if the chosen engine is the .NET edition. Then:

```sh
# Website and native Linux/Windows executables
python3 tools/export.py all

# Or export only one target; --godot selects a specific engine executable
python3 tools/export.py web --godot /path/to/standard/godot
python3 tools/export.py linux
python3 tools/export.py windows
```

The Windows build is `build/windows/oravitsa.exe`; the Linux build is
`build/linux/oravitsa.x86_64`. From a clean candidate checkout,
`python3 tools/package_release.py` creates three downloadable ZIPs plus source
metadata and SHA-256 checksums under `build/releases/<version>/`. Packaging
does not create a tag or publish a release. See [release policy](docs/RELEASES.md).

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

The GitHub **Build desktop and Web** workflow runs the offline Python suites
and gameplay/input/streaming smoke checks, then exports **Web, Linux and
Windows**. Its three artifacts contain the ready-to-host website and native
Linux/Windows builds. Linux package startup is checked through the log-aware
runner; Windows package startup is also checked locally during release
preparation.

```sh
python3 -m unittest discover -s tools -p 'test_*.py'
python3 -m unittest discover -s art -p 'test_*.py'
python3 tools/verify.py --godot /path/to/standard/godot
```

The runner imports and checks both forests, queued streaming and the retained
foraging prototype (twenty smoke scripts). It rejects logged errors immediately
and preserves output on timeouts. Native package startup uses the same log
checks via `python3 tools/verify.py --native-smoke /path/to/export`.
The offline art tests mock paid APIs; they make no uploads or paid requests.
`node art/test_walk_layout.mjs` is a local artifact-dependent check: it requires
the ignored Blender render manifest and is not a clean-checkout CI gate.

## Project layout

- `scenes/endless_woods/` — current default, procedural terrain/roads/ecology,
  sparse forage state, floating origin, local map and recovery pathfinding.
- `scenes/forest_25d/` — shared 3D presentation and retained finite clearing,
  terrain/water/foliage, cottage/bridge/well dressing and world map.
- `scenes/forest_2d/` — shared simulation, input, HUD and approved heroine walk,
  plus the retained painted forest scene and its map/tiles/props.
- `prototypes/foraging_2d/` — earlier fixed-clearing game, retained as a
  separate playable experiment.
- `docs/character.md` and `character-drafts/` — canonical Oravitsa reference.
- `art/` — asset generation/import/repair scripts and offline paid-job guards.
  `scenes/`, `scripts/`, `models/` and `resources/` also retain earlier 3D
  experiments.

Oravitsa uses **eight distinct directional atlases**, each with an eight-pose
walk loop. The shipped walk comes from a paid Tripo reconstruction and Meshy
animation through fal.ai, followed by local mesh/rig repairs and Blender
renders. See [the experiment record](docs/tripo-experiment.md) and
[approved-walk provenance](scenes/forest_2d/art/oravitsa/provenance.json).

The 2.5D deer, foxes and wolves use rigged Quaternius models; hares, boars and lynxes use
painted animated billboards. Their sources and the tree assets are recorded in
[asset attribution](scenes/forest_25d/assets/ATTRIBUTION.md). The retained 2D
tile/prop bitmap generation used no Tripo, fal.ai or OpenRouter credits; that
statement does not apply to the heroine's paid 3D-to-sprite pipeline.

Wolves and lynxes sprint in long bursts and catch hares quickly; foxes also
chase hares but usually miss and then rest, and they eat berries between hunts. Deer take
three seconds of continuous close pursuit to catch; both prey species return
later away from the player. A catch resets the predator's hunger; after 180 s
without a catch it despawns, including offscreen. Stuck animals can plan a local
collision-safe recovery route. The finite scenes retain their original ecology.
Oravitsa cannot kill any animal, including hares. There are no quests, swimming,
building loot or camera orbit yet; this is an early playable alpha.
