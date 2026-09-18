# Art pipeline

How a model gets from Blender into the game. Verified end to end, not assumed
— see "Round trip" below.

**Tools:** Blender 5.2.2 LTS, Godot 4.7.2.

---

## The scale contract

**1 Blender unit = 1 Godot unit = 1 metre. Oravitsa is 1.5 m.**

This is the one rule that cannot bend. It is set in three places and they must
agree: `resources/default_stats.tres` (`height = 1.5`), the Blender scene's
metric unit settings, and the glTF export (no export-time scaling).

Blender is Z-up, Godot is Y-up. The glTF exporter converts this for you as
long as `export_yup=True`, which `art/export_glb.py` sets. Do not "fix"
orientation by rotating objects — rotate nothing and let the exporter do it,
or you will end up with a model whose rest pose is 90° off from its transform.

---

## Layout

| Path | What | In `res://`? |
|---|---|---|
| `art/` | Blender sources and the scripts that drive them | **No** — `art/.gdignore` |
| `models/` | Exported `.glb`, the actual game assets | Yes |
| `docs/oravitsa_blockout.glb` | The in-game blockout as a modelling reference | **No** — `docs/.gdignore` |

`art/` is deliberately outside the importer. A `.blend` anywhere inside a
Godot project makes the editor try to import it through Blender, and in a
headless or CI run that fails outright with *"Blender path is invalid or not
set"*. Keeping source art gdignored avoids the whole class of problem and
keeps `.blend` files out of the asset tree.

---

## Commands

Set up (or rebuild) the modelling scene:

```
blender --background --python art/setup_blend.py
```

This writes `art/oravitsa.blend` with metric units, a 5 mm viewport near clip
(Blender's 0.1 m default clips through a figure this small), the blockout
imported into a locked `Reference` collection at true scale, and an empty
`Model` collection set active. It refuses to save if the reference did not
import at ~1.5 m, so a broken scale fails loudly instead of silently.

Export your work to `models/`:

```
blender --background art/oravitsa.blend --python art/export_glb.py -- Oravitsa
```

Selection-filtered, so the locked reference geometry can never leak into a
shipped model.

### The loop closes by itself

Model in the **`Oravitsa`** collection. The export writes
`models/<collection>.glb`, and the player loads `models/oravitsa.glb` on
`_ready()` if it exists — so **exporting is the only step needed to see your
model in the game.** Nothing to wire up, no scene to edit.

The collection name is load-bearing: export a collection called anything else
and the file lands at a path the player does not look at.

With no model on disk, the primitive blockout is used instead. The blockout is
never deleted, only hidden, so toggling `Body.visible` is a quick way to
compare a model against the measured reference.

If the model arrives more than 15 cm off the canonical 1.5 m, the player logs
a warning naming this document rather than silently rescaling it — a wrong
export scale invalidates every measurement in `character.md`, so it should be
noisy.

---

## Round trip

Verified lossless, Godot → Blender → Godot:

| Stage | Height | Up axis | Feet |
|---|---|---|---|
| Source (`oravitsa.tscn`) | 1.5220 m | +Y | 0.0000 |
| In Blender | 1.5220 m | +Z | 0.0000 |
| Back in Godot | 1.5220 m | +Y | 0.0000 |

Width 0.4235 m and depth 0.4820 m also survive unchanged. (The 1.522 rather
than 1.500 is bandana fabric above the crown — the reference sheet overshoots
its own 150 cm guide the same way.)

Re-run this check after any change to export settings.

---

## Modelling notes

**Budget.** At the game's camera she is roughly 160 px tall. That is the whole
brief: silhouette and flat colour, not detail. Somewhere under ~1,500 triangles
with flat-shaded material colours from the named palette in `character.md`.
Detail below a couple of centimetres will never be visible.

**What must survive stylisation**, in priority order (from `character.md`):
the two trailing bandana tails, the basket's hard rim above the shoulders, the
bell skirt under a narrow torso, the forward-hanging braids. Those four are
the character. Everything else is decoration.

**Rigging: skip Mixamo.** It auto-rigs to adult ~7.5-head proportions.
Oravitsa is 5.6 heads at 150 cm, so the bones land in the wrong places, and
auto-weights have nothing sensible to do with a gathered skirt. Rigify, or a
hand-built rig of roughly 15 bones, is less work than correcting it.

**Where generated 3D (Meshy, Tripo, and similar) does fit:** static props —
mushrooms, rocks, stumps, logs, berry bushes. Many are needed, none animate,
topology does not matter, and they can be decimated freely. It is a poor fit
for the character, whose thin tails and braids get fused into the body and
whose open-topped basket gets filled in, and whose topology has to deform.

**Nothing she holds may read as a weapon** — see `design.md`.
