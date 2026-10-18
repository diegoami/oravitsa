# How the 2D Oravitsa demo was made

This records the workflow used for the playable clearing on `main`. It also
explains what can be reproduced from this repository and what still depends on
making new art. The demo is a loop test, not a finished asset pipeline.

## 1. Set a small playtest target

We chose one fixed, 1280 × 720 forest clearing instead of a scrolling world.
The test was whether gathering mushrooms while a boar competes for them feels
interesting. The rules are deliberately small: 17 placed patches, a goal of 9
in 90 seconds, one shoo action, a roaming deer, and restart. Keeping the map
fixed makes different routes comparable. The 2D premise and no-harm rule are
in [the design document](design.md).

## 2. Establish the visual reference and generate art

The existing Oravitsa design sheets, especially
`character-drafts/oravitsa_4.png` and `oravitsa_1.png`, supplied her identity:
headscarf, braids, clothes, basket, palette, and the view from above. The
forest clearing was selected as the style reference for the animal art. The
assets were made with built-in image generation and checked in the running
game at their display size. We did not use Tripo, fal, OpenRouter, Blender, or
Krita to produce this demo's 2D art.

The committed files in `prototypes/foraging_2d/art/` are:

| File | Use in the scene |
| --- | --- |
| `forest_clearing.png` | Painted background, fitted to 1280 × 720 |
| `oravitsa_walk_toward.png` | Four-frame walk strip for movement toward the viewer and sideways |
| `oravitsa_walk_away.png` | Four-frame walk strip for movement away |
| `boar_walk.png` | Four-frame boar walk strip |
| `deer_walk.png` | Four-frame deer walk strip |
| `mushrooms.png` | One mushroom illustration repeated at fixed positions |

The exact generation prompts, rejected candidates, and editable source files
were **not** saved in this repository. The checked-in PNGs reproduce the
current game, but they do not reproduce the image-generation process. If we
make replacement art, save its prompt, reference images, model/service,
settings, source file, and accepted export alongside it. This is a proposed
improvement for future assets, not a step completed for these PNGs.

## 3. Assemble the Godot scene

`project.godot` sets `prototypes/foraging_2d/game.tscn` as the main scene and
uses a 1280 × 720 canvas. That scene attaches `game.gd`, which loads the six
PNGs. The background fills the viewport. The script divides each walk strip
into four equal horizontal frames using `AtlasTexture`, then displays it with
`AnimatedSprite2D`. Oravitsa switches between toward and away strips based on
vertical movement; leftward movement mirrors the sprite. There are no true
left/right or diagonal animation sets yet.

The script scales and offsets sprites to place their feet on the ground,
then sets `z_index` from each sprite's Y position so nearby figures draw in
front of farther ones. It places the 17 mushrooms at explicit coordinates.
These positions and the deer waypoints are authored in `game.gd`; the forest
is not procedurally generated. The mushrooms are repeated instances of one
image, with no pickup animation.

## 4. Add the loop and verify it

`game.gd` reads WASD/arrow input, collects a mushroom when Oravitsa is close,
and moves the boar toward the nearest remaining patch. The boar pauses after
taking one. Space briefly sends it away if it is nearby, subject to a
cooldown. The deer follows fixed waypoints and gives Oravitsa space. The HUD
shows basket count, boar count, time, and shoo availability. A round ends on
success, timeout, or when too few patches remain to reach the goal.

To run the committed demo, open the repository in **Godot 4.7** (tested with
4.7.2) and press **F5**, or run:

```sh
godot --path .
```

To run the headless smoke test from the repository root:

```sh
godot --headless --path . --script res://prototypes/foraging_2d/smoke_test.gd
```

The test loads the scene and checks movement, player and boar collection,
shoo, and restart. It does not judge visual quality or game feel; those need
an in-editor playtest at the intended screen size.

## Limits to address if the loop earns further work

The short generated walk strips may change character details between frames.
Sideways movement mirrors a three-quarter view, and the boar and deer also
have limited direction coverage. Before treating the art as production-ready,
an artist could correct the sheets in Krita, give each direction a consistent
silhouette and foot position, and test the animation in Godot. That cleanup
has not been done for this demo. The older 3D scenes and Tripo trial remain
in the repository as history; neither supplies assets to this 2D scene.
