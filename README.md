# Project: Oravitsa — prototype repo bootstrap

Set up a new Godot 4.7 project in this folder. Greybox prototype only —
no art, no textures, no procedural generation yet.

## Existing content in this repo
There is a folder `character-drafts/` containing AI-generated character
design sheets for the protagonist (turnarounds, expression sheets, a
top-down view, hair studies, prop details).

These are REFERENCE ONLY. Do not import them into the Godot project, do
not use them as textures, do not build a res:// path that points at
them, and do not try to generate 3D assets from them. Godot must not
import that folder — add it to .gitignore's import exclusions or place
a `.gdignore` file inside it so the editor skips it.

Read the images and write `docs/character.md` summarising the canonical
design in text: palette hex values sampled from the sheets, garment
list, proportions, height, distinguishing silhouette features. Note
explicitly which drafts are superseded — earlier sheets show a red hood
which has been DROPPED; the current canonical design is the summer
version with a blue-and-yellow patterned bandana, oatmeal linen tunic,
moss green skirt, back-worn basket, amber braid beads. Also flag that
the sheets disagree on height (145 cm vs 150 cm) and that one value
must be chosen, since it sets world scale.

Pick 150 cm and record it in docs/character.md as the canonical figure.
Size the player capsule to match, and state the world scale (1 unit =
1 metre) in the README so future assets are modelled to it.

## What the game is (context, not to be built yet)
A cozy isometric 3D game. Oravitsa is a forager in a Nordic forest. She
gathers food against a hunger clock. Animals compete for the same
resources. She has no attacks — only non-harmful influence spells
(scare, attract, confuse, slow). Nothing in this game may ever damage
or kill a creature.

## Iteration 1 scope — build exactly this
1. Camera-relative character movement on a flat ground plane.
2. Orthographic isometric camera that follows the player smoothly.
3. Mushrooms scattered in the scene that can be picked up.
4. An inventory count and a minimal on-screen label showing it.

Nothing else. No hunger, no animals, no spells, no menus, no save system.
The player is a capsule with a coloured cap — no character model.

## Structure
res://
  scenes/            world.tscn, oravitsa.tscn, mushroom.tscn
  scripts/           oravitsa.gd, mushroom.gd, camera_rig.gd,
                     forager_stats.gd, spawner.gd
  resources/         default_stats.tres
  prototypes/        (empty, for future throwaway experiments)
  docs/              design.md (stub), character.md, prototype_log.md
  character-drafts/