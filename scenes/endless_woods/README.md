# Endless Mossbank woods

The default `woods.tscn` extends the tested 2.5D presentation and the shared
forest simulation. The earlier finite scenes remain available under
`scenes/forest_25d/` and `scenes/forest_2d/`.

## World generation

There is no fixed playable border. Deterministic 16 m chunks continue north,
south, east and west. Winding east/west roads cross meandering rivers on
generated bridges; north/south roads connect them. Curving side trails lead
to forgotten homesteads, standing stones, woodcutters' camps and mossy cairns.
Seeded lakes sit away from the main roads. Meadow, birch, pine and alder-marsh
areas vary terrain colour, tree density and flowers. The familiar starting
cottage and old well stay at their original absolute coordinates.

Roads, water, tree/rock collision and landmarks come from the same seeded data
as the visible chunks. Collision works in an unrendered region. Chunks build
one per moving frame inside an 11 m margin; initial views, large teleports and
viewport changes fill immediately. Nature and bridge caches are trimmed around
the stream window. Wildlife is capped at 208 simulation slots and reuses distant
slots as the player moves into new regions.
Only nearby wildlife moves; offscreen positions are retained while status and
hunger timers continue. This is a bounded local ecology, not a full simulation
of every animal across the unvisited world.

The simulation keeps local coordinates small through a floating origin.
Beyond 456 m from the render origin it rebases by multiples of 512 food cells
(912 m), preserving the absolute chunk/cell keys. Player, camera, animals,
waypoints, projectiles, food visuals and fixed scenery shift together. This
keeps rendering precision useful during long journeys. The tests visit 4 km
in all four directions, including negative coordinates, and verify the same
terrain and harvested food on return. Coordinate types still have the normal
engine/platform limits; the world has no designed map edge.

Food is generated lazily in sparse dictionaries, with no full-world array.
Cells inside solid scenery are excluded. Picked or animal-eaten food schedules
a staggered game-time regrowth delay: **berries 3–6 minutes**, **mushrooms
5–9 minutes**. Once due, a patch recovers outside the actual camera view so it
does not visibly pop in. Visible due patches wait until the player looks away.
The check runs once per second; unloaded patches recover without creating
render nodes. Absolute cell identities and deadlines survive chunk unloading
and origin rebasing, and revisiting never restarts the timer. Depletion records
are discarded when the patch recovers; full terrain history is regenerated.
Regrowth adds no inventory, and a recovered patch must be collected again.
There is no save to disk, and quitting/reloading starts a fresh session.

## Wildlife

There are now six species. Seed weights are hare 52, deer 18, fox 10, boar 8,
wolf 7 and lynx 5. This intentionally makes predators more frequent than in
the retained finite scene. The fixed initial population is 103 animals:
62 hares, 14 deer, 12 foxes, 5 boars, 6 lynxes and 4 wolves. Replenishment targets
18/8/4/4/3/2 for hare/deer/fox/boar/wolf/lynx, with species-specific chances.
New arrivals and prey respawns stay outside the actual smoothed camera view.

Both wolves and lynxes hunt hares and deer. Hares are caught on contact; deer
require three seconds of continuous close pursuit, interrupted by losing
contact or stun. A successful catch resets the predator's hunger. After
**180 seconds without a catch**, a predator despawns, including when offscreen.
Its slot has a 45-second reuse delay and does not use the prey respawn path.
The population system may later introduce a different arriving animal.
Wolves use a rigged Quaternius CC0 model with Idle/Walk/Eating clips; there are
no attack or death animation calls. Oravitsa still cannot kill any animal:
Sling stuns and Shoo repels, with the existing keyboard/touch/controller inputs.
Shoo shares the selected target/range with Sling and scares only that animal
for five seconds. It interrupts feeding/hunting and existing animal stun,
immediately starts a fast escape away from Oravitsa, and shows an orange
`SCARED` countdown above the animal. Rigged animals gallop where available;
painted animals animate faster. The cooldown is seven seconds and is not spent
on invalid casts. Fear has priority over prey pursuit, food and home return;
ordinary AI resumes when it expires. Collision and recovery routes still apply.

Animals that make little progress for 0.8 s can request a bounded 19 × 19
local A* route around solid scenery. At most one recovery route is planned
per frame, with a two-second cooldown per animal. Normal movement still checks
collision and other animals every step; recovery does not teleport animals.
The regression test walks a stuck wolf around the cottage and through its
doorway. It does not claim every crowding or unreachable-target case is solved.

The local map follows Oravitsa and shows a 128 m neighborhood with absolute
coordinates and nearby wildlife. It starts hidden, as does Help. The approved
eight-direction heroine animation, skill controls and inventory are retained.

## Verification

Run `python3 tools/verify.py --godot /path/to/standard/godot`. In addition to the
retained scenes, the world test checks seeded diversity, curving connected
roads across rivers/chunk seams, four-direction travel/rebasing, bounded
caches/population, persistent harvests and dry-ground height. The wildlife test
checks the rigged wolf, both predator species, non-lethal Sling, feeding/hunger,
offscreen starvation and collision-safe recovery. Native captures inspect
arrival, a meadow, a generated lake, distant woods and the local map.
The regrowth test covers both food delays, visible-patch deferral, loaded and
unloaded recovery, timer persistence over rebases, re-collection and duplicate
visual prevention.

Assets and checksums: [shared attribution](../forest_25d/assets/ATTRIBUTION.md).
This development branch does not replace the independently pinned alpha draft.
