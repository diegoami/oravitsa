# Proposal: empty caves and villages in the endless woods

Status: **design proposal for owner review** (issue #22). Nothing here is
implemented. Caves and villages stay **uninhabited**: no NPCs, quests, shops,
enemies or settlement systems.

## How they would fit the current world

The endless world is generated from absolute coordinates. Winding east/west
road *rows* and north/south road *columns* connect everywhere, rivers are
crossed by bridges, and each 256 × 128 m landmark region (`landmark_at`)
holds one forgotten homestead, standing-stone circle, woodcutters' camp or
cairn group on a dressed side trail. Food and wildlife are now sparse (about a
third of v0.1). New landmarks should feel like rarer, larger discoveries
along the same roads, not clutter.

### Villages: abandoned hamlets

- **Identity.** Three to six empty cottages around a small overgrown green
  with a well and broken fences. Weathered grey timber, some collapsed roofs,
  cold chimneys and tall grass in former gardens. They reuse the procedural
  cottage and homestead kit (`landscape.gd` / `cottage_details.gd`), recoloured
  and varied with seeded damage; no new paid art.
- **Placement.** Only at a road crossing (a row meeting a column), with a
  seeded chance of about one in six crossings. The roads already guarantee
  reachability. Keep at least 400 m between hamlets and stay off water.
  The footprint is about 30 × 24 m, reserved so trees, rocks and food do not
  spawn inside.
- **Approach.** Each door gets a short dressed trail from the green. Doors are
  closed or show an empty dark frame; interiors are not enterable at first.
  Roof hiding (as at the starting cottage) is needed only if one cottage gets
  an open, walkable floor.
- **Label.** "Empty hamlet" via the landmark label, plus a small map icon.

### Caves: exterior mouths first

- **Identity.** A mossy rock outcrop or hillside with a dark mouth (a recessed,
  unlit opening with a black depth plane), boulders and ferns. It reads as
  something to explore without needing an interior.
- **Placement.** On higher terrain (height noise above a threshold), away
  from roads, rivers and lakes. Roughly one per two or three landmark regions,
  in a region without a homestead, so landmarks stay spread out. A dressed
  trail leads from the nearest road to the mouth.
- **Collision.** Rock masses register static blockers; the mouth itself is
  a blocker 1.5 m deep, so Oravitsa can stand in the entrance but not walk
  into geometry that does not exist.
- **Label.** "Cave mouth".

### Option B (not assumed): enterable empty interiors

A walk-in cave or cottage would need a separate small interior scene with a
transition (fade, load, return at the entrance). It would also need its own
collision and camera framing, paused or retained exterior streaming, and save
data recording which interior Oravitsa is in. That is a substantially larger
system and should be decided before building it.

## Technical requirements (when implemented)

- **Determinism.** Derive every feature from absolute region/crossing keys
  with `random_at(key, salt)`, like `landmark_at`. Never use run-time
  randomness, so revisits and saves (#17) need no extra data.
- **Collision everywhere.** Register blockers from the same seeded data as
  the meshes, so collision works in unrendered regions (an AGENTS.md
  contract).
- **Reachability.** Extend `world_smoke_test.gd` the way it walks homestead
  approaches. Walk every door/mouth trail in positive and negative regions,
  across chunk seams and after rebasing; assert `can_walk` and that the trail
  dressing stays passable.
- **Streaming.** Build meshes per chunk and keep fixed nodes rebasing with the
  origin. Keep cache sizes bounded in the four-direction 4 km travel test.
- **Ecology.** Exclude food and animal spawns inside reserved footprints. Keep
  current density targets; a hamlet's gardens could optionally hold a berry
  patch (decision below).
- **Audio (#23).** Optionally a slightly hollow wind layer near cave mouths,
  synthesized like the rest.

## Decisions for the owner

1. Caves: exterior mouths only (recommended first step) or enterable interiors?
2. Villages: frequency (about one per six crossings proposed) and size (3–6 cottages)?
3. May abandoned gardens hold food, or should hamlets be completely bare?
4. May wildlife later shelter in caves (still no enemies), or keep them empty?
5. Should any cottage be walk-in like the starting forester's cottage?
6. Names and map icons: "Empty hamlet" and "Cave mouth", or other wording?

## Suggested sequence

1. Exterior cave mouths: placement, collision, trail and tests.
2. Hamlets at crossings using the cottage kit, with reserved footprints.
3. Only if approved, interiors as a separate design and issue.
