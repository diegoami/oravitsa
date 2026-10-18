# Oravitsa

Oravitsa is a cosy 2D forest game prototype. The current default scene explores a
larger world built from connecting painted tiles, with winding dirt paths, trees,
bushes, stones, ferns, fallen logs, and collectible mushrooms. See the
[design](docs/design.md) and [character reference](docs/character.md).

## Play

Open this folder in **Godot 4.7** (tested with 4.7.2) and press **F5**, or run
`godot --path .` here. Use **WASD / arrows** to walk. The camera follows Oravitsa;
the minimap in the upper right shows the full forest. Grass, dirt, ferns, and
mushrooms are passable. Walking over a mushroom collects it. Trees, bushes,
stones, and fallen logs block movement.

The forest is 128 × 128 tiles, or roughly 11 visible screens across and 20 down
at the default window size. It uses a fixed seed, so paths and objects are the
same on every run. Ground is a Godot `TileMapLayer`; nearby object sprites are
loaded as Oravitsa explores. The [forest guide](scenes/forest_2d/README.md)
explains the map and art sources.

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

The short four-frame Oravitsa walk strips remain prototype animation. The new
forest art was generated as bitmap assets and checked in Godot at play size;
no Tripo, fal, or OpenRouter credits were used.
