# Prototype log

Running record of what was built, what was decided, and what was deliberately
left undone. Newest entry at the top.

---

## Iteration 1 — camera, movement, mushrooms, count

**Date:** 2026-09-18
**Godot:** 4.7.2.stable.mono
**Status:** complete, verified

### Scope

Exactly the four items from `README.md`:

1. Camera-relative character movement on a flat ground plane
2. Orthographic isometric camera with smooth follow
3. Pickable mushrooms scattered in the scene
4. An inventory count and an on-screen label

No hunger, no animals, no spells, no menus, no save system. The player is a
capsule with a coloured cap.

### Decisions

**World scale: 1 unit = 1 metre.** Oravitsa is 150 cm (see `character.md` for
how that was settled), so the capsule is 1.5 units tall and 0.28 radius. The
capsule and its greybox meshes are sized from `ForagerStats.height` at
`_ready()`, so changing the canonical figure in one `.tres` re-sizes the body
rather than requiring a scene edit.

**Camera angle: true isometric, not 2:1 dimetric.** Pitch is
−35.264° (`atan(1/√2)`), yaw 45°, which puts the camera on the (1,1,1)
diagonal and makes the three world axes project at exactly 120° apart.
Orthographic, `size = 10`, so the view covers 10 m vertically. The rig
follows; the `Camera3D` child holds a fixed offset and rotation, so the angle
cannot drift.

**Follow smoothing uses `1 - exp(-k·dt)`,** not `lerp(a, b, k·dt)`. The naive
form changes its easing with framerate; this one does not.

**Mushrooms detect the player, not the other way round.** Each mushroom is an
`Area3D` on the player's collision layer. This keeps the pickup rule inside
the thing being picked up and avoids a per-frame proximity scan that would
have to be rewritten once there are hundreds of them.

**Physics layers:** 1 = world, 2 = player. Named in `project.godot` so the
masks are readable in the inspector.

**Spawner uses a fixed seed** (`random_seed = 20260918`). The greybox layout is
identical between runs, so when movement or the camera changes, that change is
the only variable. Set the seed to 0 for a fresh scatter.

**Scatter is uniform by area** (`sqrt(randf()) * radius`), with a 3 m clear
radius around the player start and 1.2 m minimum spacing, placed by rejection
sampling with a bounded retry count. It gives up and warns rather than looping
forever or stacking mushrooms on each other. This is **not** procedural
generation and should not grow into it.

**Greybox colours come from the model sheet's named palette.** The capsule,
cap and facing marker use Oatmeal Linen, Bandana Blue and Golden Yellow at
their exact swatch values (`character.md`), not colours sampled off the
rendered figure. The prototype therefore reads as the right character even
with no model.

**Lighting.** The sun was initially placed at the camera's own azimuth, which
meant every shadow fell directly behind its caster and was invisible. It is
now off-axis (yaw −58°, pitch −52°) so shadows fall to screen-right. On a flat
untextured plane the contact shadow is the only depth cue there is — without
it, nothing looks like it is standing on the ground.

### Known shortcuts

- **The player writes to the HUD label directly.** `oravitsa.gd` holds an
  exported `Label` and sets its text. The player should not know about the UI.
  The reason it does is that the iteration-1 file list in `README.md` has no
  `hud.gd`, and a signal cannot format a string without a script on the
  listening side. `inventory_changed` is already emitted, so the fix is to add
  `hud.gd`, connect it to that signal, and drop the export. Do this as soon as
  there is a second number on screen.
- **The facing marker is not in the spec.** The brief says "a capsule with a
  coloured cap". A bare cap gives no way to see which way she is facing, which
  makes camera-relative movement impossible to verify by eye, so there is a
  small yellow wedge on the front edge of the cap. It is three lines of scene
  and dies with the greybox.
- **No input remapping, no gamepad.** WASD and arrow keys only, bound by
  physical keycode so the layout works on non-QWERTY.
- **Gravity is applied but the ground is flat,** so it only ever settles the
  capsule onto the floor. It is there so that iteration 2 does not start with a
  hovering character the moment the terrain stops being a plane.

### Verification

Checked by script against the running scene, not by eye
(21 checks, all passing):

- all four input actions exist with both bindings
- capsule is 1.5 m × 0.28 m and the stats resource loads
- camera is orthographic and pitched at 35.26°
- 24 mushrooms spawn, none inside the clear radius, none outside the area
- forward input maps to world `(−0.707, −0.707)` — i.e. it is genuinely
  camera-relative, not world-aligned
- right input is perpendicular to forward
- the facing marker points the way she walks
- walking onto a mushroom increments the count, updates the label, and frees
  the mushroom
- the rig converges on the player (13.01 m → 0.04 m over 60 physics frames)
  without changing height

Two real bugs were caught this way and fixed:

1. **Node-reference exports were silently null.** A hand-written `.tscn` needs
   `node_paths=PackedStringArray("...")` on the `[node]` header for exported
   `Node` properties; without it Godot assigns the `NodePath` to an object
   property and it becomes `null` with no error. The player's camera reference,
   its label reference, and the rig's target were all null — movement had
   silently fallen back to world-aligned, and the camera never followed. **If
   you hand-edit a `.tscn` and add a node reference, add it to `node_paths`.**
2. **The capsule's dome poked through the cap** and the facing marker was
   buried inside the cap disc. Both were invisible until the scene was actually
   rendered.

### Outstanding — needs a human

**`character-drafts/oravitsa_2.png` is committed as a zero-byte file.** The
working copy is the complete 1.3 MB master model sheet — the richest of the
four, and the source of the named palette and the character vitals now written
into `character.md`. The blob in git history is empty, so that image exists in
exactly one place and is not backed up. It was a 0-byte file on disk at the
start of this session and had content by the end of it, which is worth
understanding before trusting the folder. **Commit it.**

### Next

Nothing is queued. Iteration 2 scope is not decided and should be agreed
before anything is added — the constraint that matters is in `design.md`:
nothing in this game may ever damage or kill a creature.
