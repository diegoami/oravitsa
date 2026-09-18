# Prototype log

Running record of what was built, what was decided, and what was deliberately
left undone. Newest entry at the top.

---

## Iteration 1a — Oravitsa blockout replaces the capsule

**Date:** 2026-09-18
**Status:** complete, verified

The capsule-with-a-cap from the brief was the right placeholder for testing
movement and the wrong one for looking at. Replaced with a **primitive
blockout** — 34 spheres, cylinders and boxes under a `Body` node. Still no
imported art and no textures: every part is a Godot primitive with a flat
colour from the named palette in `character.md`.

Built from the measured landmark table, not by eye. Shoulder at 114 cm, belt
at 91 cm, basket rim at 116 cm, skirt hem at 28 cm, and so on, so the figure
is at true scale and the capsule still matches it. `Body` is scaled by
`height / BLOCKOUT_HEIGHT`, so the canonical figure stays a single number in
`default_stats.tres`.

The parts that carry the silhouette, in the order `character.md` ranks them:
bandana with its two tails, the basket rim above the shoulders, the bell
skirt, the forward-hanging braids with amber beads.

**Tails splay sideways, not down the back.** The top-down sheet shows them
flung out to either side, and from a fixed isometric camera that is the only
placement where they read at all. This is the character's main motion cue.

**The facing marker is gone.** She now has a face, braids in front and a
basket behind, so the greybox wedge is no longer needed — which also removes
the one deliberate deviation from the brief.

**Camera pulled in from `size = 10` to `6.5`.** At 10 the figure was about
100 px tall at 720p and every bit of the above was invisible. Cozy games want
the character legible; the trade is seeing less of the field at once.

### What went wrong, twice

Both bugs were the same class: **two primitives at nearly equal radius with
different segment counts.** The flat faces of one stab through the flat faces
of the other, and it looks like a ring of spikes, not like z-fighting.

1. The tunic bottom (r 0.155, 16 segments) against the skirt top (r 0.150,
   18 segments) produced a fringe of spikes around the waist. Fixed by
   splitting the tunic into a bodice that stays inside the belt and a flare
   that drapes clearly *outside* the skirt — which is what the sheet shows
   anyway.
2. The arms at x 0.150 sat just inside the tunic flare's widest point and
   poked through. Moved out to 0.168.

The tell: the artifact was **identical with shadows disabled**, which ruled
out shadow acne immediately. Worth checking that first next time.

### Verification

18 checks against the running scene, all passing — including two new
geometric ones: the whole blockout's AABB sits on the floor (lowest point
0.000 m) and reaches the canonical height (highest 1.522 m; the extra 2 cm is
bandana fabric above the crown, which the reference sheet also shows
overshooting its own 150 cm guide).

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

Nothing outstanding.

`character-drafts/oravitsa_2.png` was briefly a zero-byte file — it was read
while the copy into the folder was still in flight. The complete 1.3 MB master
sheet is now committed, and it is the source of the named palette and the
character vitals in `character.md`.

### Next

Nothing is queued. Iteration 2 scope is not decided and should be agreed
before anything is added — the constraint that matters is in `design.md`:
nothing in this game may ever damage or kill a creature.
