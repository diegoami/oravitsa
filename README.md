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
stones, and fallen logs block movement; dark green ground marks blocked trees
and bushes. Press **Space** to shoo nearby wildlife. Animals avoid each other
and Oravitsa, forage, or hunt according to species. Bumping an animal briefly
stuns both of them.

The forest is **416 × 416 tiles**, 10.56 times the previous map area. It uses a
fixed seed, so paths and objects are the same on every run. Ground tiles and
nearby sprites stream around Oravitsa as she explores. The
[forest guide](scenes/forest_2d/README.md) explains the map and art sources.

The earlier timed, single-clearing foraging loop remains available at
`res://prototypes/foraging_2d/game.tscn`; open that scene and press **F6** to
play it. It includes the boar and deer and is documented in its
[playtest guide](prototypes/foraging_2d/README.md). The
[creation workflow](docs/2d-demo-workflow.md) records the original demo.

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
short bursts and can catch deer; deer return later away from the player. The
new side and straight-back Oravitsa walk strips run four-pose loops.
