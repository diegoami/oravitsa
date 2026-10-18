# Oravitsa

Oravitsa is a cosy **2D foraging game** set in a Nordic summer forest. A young
forager gathers mushrooms against a hunger clock while a boar seeks the same
food. Deer roam the clearing. There is no combat: nothing can damage or kill a
creature. See [the design](docs/design.md) and [character reference](docs/character.md).

The current game is a one-clearing playtest. It uses painted raster art for the
forest, Oravitsa, animals, and mushrooms. Its purpose is to find out whether
moving, gathering, and competing for food make a satisfying loop before we
expand the world or polish every animation.

## Play

Open this folder in **Godot 4.7** (tested with 4.7.2) and press **F5**, or run
`godot --path .` from this folder.

- **WASD / arrows:** move Oravitsa; walk near mushrooms to gather them.
- **Space:** shoo a nearby boar briefly, without harming it. The ability has a
  cooldown.
- **R:** restart after a round.

Gather **9 mushroom patches in 90 seconds**. The boar takes patches too; the
deer is ambient wildlife. The layout is fixed so different routes can be
compared. More playtest details and known art limitations are in the
[2D game guide](prototypes/foraging_2d/README.md). The
[creation workflow](docs/2d-demo-workflow.md) records how this demo was built
and what is needed to make matching assets later.

## Project layout

- `prototypes/foraging_2d/` — **current game**: scene, gameplay script, art,
  smoke test, and guide. The folder retains its original experiment name; it
  is the project's default scene in `project.godot`.
- `docs/design.md` — current premise and loop.
- `docs/character.md` and `character-drafts/` — canonical character design and
  reference sheets. The sheets are reference material, not imported game art.
- `scenes/`, `scripts/`, `models/`, `art/`, and `resources/` — earlier 3D
  experiments, retained for history. They are not used by the 2D main scene.
- `docs/prototype_log.md`, `docs/art-pipeline.md`, and
  `docs/tripo-experiment.md` — development history and legacy 3D workflows.

The 2D art was generated from prompts and Oravitsa's reference sheets, then
checked in the running game at its actual display size. No Tripo, fal, or
OpenRouter API credits were used for these assets. The short four-frame walk
strips and mirrored sideways views are playtest art, not final animation.
