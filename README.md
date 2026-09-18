# Oravitsa

A cozy isometric 3D game. Oravitsa is a forager in a Nordic forest. She
gathers food against a hunger clock, and animals compete with her for the same
resources.

She has no attacks — only non-harmful influence spells (scare, attract,
confuse, slow). **Nothing in this game may ever damage or kill a creature.**
That is the premise, not a difficulty option. See `docs/design.md`.

This repo is a **greybox prototype**. No art, no textures, no procedural
generation.

---

## World scale

**1 Godot unit = 1 metre.**

Oravitsa is **150 cm**, so 1.5 units. Every asset must be modelled to this
scale. The number is settled in `docs/character.md` (the design sheets
disagreed; 150 cm is canonical) and is stored once, in
`resources/default_stats.tres`, from which the player capsule sizes itself.

---

## Running it

Requires **Godot 4.7** (developed against 4.7.2-stable). Open the folder as a
project and press F5, or:

```
godot --path .
```

Controls: **WASD** or the **arrow keys**. Walk into a mushroom to pick it up;
the count is in the top-left. That is all there is so far.

---

## Iteration 1 scope

Exactly four things, and they are done:

1. Camera-relative character movement on a flat ground plane
2. Orthographic isometric camera that follows the player smoothly
3. Mushrooms scattered in the scene that can be picked up
4. An inventory count and a minimal on-screen label showing it

No hunger, no animals, no spells, no menus, no save system. The player is a
capsule with a coloured cap — no character model.

What was decided and why, and the shortcuts taken, are in
`docs/prototype_log.md`.

---

## Structure

```
project.godot
scenes/      world.tscn, oravitsa.tscn, mushroom.tscn
scripts/     oravitsa.gd, mushroom.gd, camera_rig.gd,
             forager_stats.gd, spawner.gd
resources/   default_stats.tres
prototypes/  (empty, for future throwaway experiments)
docs/        design.md, character.md, prototype_log.md
character-drafts/
```

---

## `character-drafts/` is reference only

The folder holds AI-generated character design sheets for the protagonist:
turnarounds, hair studies, a top-down view.

**They are never imported.** Do not use them as textures, do not build a
`res://` path that points at them, and do not generate 3D assets from them.
`character-drafts/.gdignore` keeps the Godot editor out of the folder
entirely. They are committed to git, so the `.gdignore` — not `.gitignore` —
is what excludes them from the project.

`docs/character.md` is the canonical description of the design: sampled
palette, garments, measured proportions, and which drafts are superseded. Work
from that document, not from the images.

> The original project brief that this repo was bootstrapped from is preserved
> in git history at commit `e8b6cbd`.
