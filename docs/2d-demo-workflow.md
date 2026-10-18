# How the 2D Oravitsa demo was made

This records the workflow used for the playable clearing on `main`, using the
project files and the surviving context of the creation session. It explains
what can be reproduced from this repository and what still depends on making
new art. The demo is a loop test, not a finished asset pipeline.

## How this experiment arrived at 2D

The project began with a 3D greybox and a Blender/Tripo experiment. The
Tripo H2.5 result was judged unsuitable, and the earlier generated 3D model
was not accepted as a game character. We then chose to test the game loop in
2D: a cosy forest with a recognisable Oravitsa, boar, deer, and mushrooms.
The request specifically called for attractive authored art rather than
code-drawn or procedural placeholder trees and characters. Krita was
installed as a possible art tool, but this first demo did not use it.

The practical sequence was: define the one-clearing rules; use the existing
character sheets to guide image generation; select a painted forest scene;
make character, animal, and mushroom PNGs; put those images into a Godot 2D
scene; build the interactions; play the scene and run the smoke test. This
sequence is recoverable. The exact text of each image-generation request is
not available in the project record.

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
assets were made through the assistant's `image_gen.imagegen` chat tool,
then checked in the running game at their display size. The tool took image
instructions and references; it did not expose an API endpoint URL or a
selectable model ID in the calls available to me. I therefore cannot name
the underlying model or reproduce the request as a direct HTTP API call.
This was a creation-time service, not a Godot feature or runtime procedural
art. We did not call Tripo, fal, or OpenRouter endpoints or use Blender or
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

The image-generation briefs can be **reconstructed** from the selected
images, reference sheets, and how the game uses them. These are descriptions
of the intended output, **not verbatim prompts**:

| Asset | Reconstructed brief |
| --- | --- |
| Forest | Warm, painterly Nordic summer clearing viewed from above, open in the middle for play, framed by birches, conifers, ferns, rocks, flowers, and soft paths; no characters or interface. |
| Oravitsa | Keep the design-sheet identity (blue patterned headscarf, pale braids, cream tunic, green skirt, boots, basket); show four aligned phases of a walk on a transparent sheet, with one toward and one away view. |
| Boar and deer | Friendly woodland animals in the forest's painted style, each as a transparent four-frame walk strip suitable for a small game sprite. |
| Mushrooms | A readable painted cluster that can be repeated as a collectible on the forest floor. |

The committed PNGs reproduce the current game. The exact generation
prompts, generation settings, and any unused candidates have no known saved
location. They might appear in earlier chat tool-call history if that history
is available, but they were not archived as project files. No layered Krita,
Photoshop, or other editable source file was created for these 2D assets.
For the next asset, save the verbatim prompt, references, service/model,
settings, accepted PNG, and any editable cleanup source together. That is a
proposed improvement, not a step completed for these images.

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
