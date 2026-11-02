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
Without loading a save, quitting/reloading starts a fresh session.

## Sound

A quiet forest ambience plays two looping layers of different lengths: 23 s of
wind and leaves and 19 s of birdsong. Their combined pattern only repeats
every 437 s. Animals within 14 m of Oravitsa occasionally call: wolves howl,
lynxes growl, boars grunt, deer bark, foxes yip and hares thump. Each animal waits
12–60 s (by species) between calls, at most two calls play at once, and calls
start at least 1.2 s apart, so crowds stay comfortable. Distant and offscreen
animals are silent. Calls are 3D sounds heard from Oravitsa's position (not the
camera's), attenuated with distance and panned to match the fixed view. An
animal that turns angry calls immediately, and so does an animal starting a
fight. A call stops if its animal despawns or leaves the active area. The
ambience is never restarted by streaming or origin rebasing.

Underground (#61) both surface layers pause where they are, and a 21 s low
cave drone and 17 s of dripping water loop instead. Giant rats squeak and
spiders hiss through the same call system (9–28 s apart), and a reverb on the
Animals bus makes calls echo. Entering or leaving a cave ends any call in
progress, and leaving resumes the surface layers and turns the echo off.

Volume levels cycle 100% → 60% → 30% → Off separately for the forest and the
animals: press **9**/**0**, or use the *Forest*/*Animals* buttons under Help.
The levels persist in `user://settings.cfg`. Browsers only start audio after
the first click, key or touch on the page; the woods are silent until then.
Headless runs use Godot's silent driver, where the same scheduling runs without
playback. Every sound is synthesized by `tools/synth_audio.py` (CC0, no
recordings or services; see [audio provenance](audio/PROVENANCE.md)).
Listening quality, and browser and native playback, have not yet been checked
by ear.

## Saving

One manual slot, `user://oravitsa_save.json`, with no autosave. **K** or the
Help panel's *Save game* button saves; **L** or *Load game* loads; with Help
open a controller uses **X**/**B**. (F5 would reload a browser tab, so it is not
used.) A notice reports every success or failure.

The save is versioned JSON holding only bounded state: the world identity,
Oravitsa's absolute ground position, stun, both cooldowns, the selected skill,
inventory (berries, mushrooms, raw meat), aura, the fed level and meal timer,
cave progress (collected checkpoints per cave, plus killed monsters from older saves), the food
clock, depleted food records
(absolute cell and deadline) and at most 208 animal records (absolute
position/home/target plus status, hunger and cooldown timers). Terrain, trees and
undepleted food are regenerated from the seeds, never stored. On loading, the
floating origin is rebased near the saved position. Timers continue from their saved values,
so game time is paused while the game is closed. Stones in flight, the target
selection, route plans and in-progress warnings, charges, fights and hunts
restart from calm, while their cooldowns persist. A save made before a world
feature existed (such as a hamlet house built over the saved spot) still
loads in the same world. Oravitsa and every animal are moved to the nearest
open ground, and animal homes leave hamlet clearings. Positions that are
already valid stay exactly as saved, and moved actors land clear of every
other actor, so nobody starts stuck in contact.

A save is written to a temporary file and read back and validated. Only then
does it replace the slot, using renames that replace their destination in one
step. A readable replaced save is kept as `.bak`; a corrupt slot is never
rotated over a valid backup. If the final replacement fails, the previous save
is moved back into the slot, so a failed save always leaves the last readable
save recoverable (the save test injects real rename failures). Loading validates
every field before anything changes. A missing, unreadable, incompatible
(other version) or foreign-world save is reported and left untouched. If the
slot is missing or unreadable but the backup is intact, the backup is loaded
and the notice says so. Desktop builds store the file in Godot's per-user data folder.
The Web build uses the browser's persistent storage (IndexedDB), which private
browsing or clearing site data can discard. The browser save path is untested.

## Hamlets and cave mouths

Both are uninhabited: no people, quests, shops or enemies. They come from the
same seeded absolute data as roads and landmarks, so revisits and saves need
no extra state. Collision works without rendered chunks, and each house or
rock is built in the chunk that holds its centre.

- **Hamlets.** Each 512 × 384 m block (two road columns by three road rows)
  has one hamlet, at a seeded crossing in its middle row, so exactly one
  crossing in six. Hamlets are at least 256 m apart. Each has 3–6 closed,
  weathered cottages from six seeded slots set back from both roads, and an
  the chieftain's canvas store tent near the crossing, its entrance facing
  south, solid exactly to its square base. Cottages are grey timber with a shut door facing
  the east/west road, dark shuttered windows, a seeded collapsed roof section
  over a dark interior, and usually a cold chimney. A short dressed trail
  joins each door to the road. The 30 m clearing around the crossing grows no
  trees, rocks or food ("bare gardens"), and no animal spawns or has its home
  there; wandering animals may pass through. The label reads "Hamlet",
  and the map shows a small house icon. Villagers live there (see below).
- **Names (#56).** `place_names.gd` names each hamlet from a pool of 24
  Finnish (-la/-lä), Swedish (-by, -vik, -dal…) and Ukrainian (-ivka…) village
  names, and each cave from 24 Finnish (-luola, -kolo), Swedish (-grottan) and
  Ukrainian (*pechera*) cave names, by hashing its absolute hamlet block or
  landmark region. Nothing is stored: the same place always gets the same name.
  Names step through the pool on an x + 5y lattice, so neighbours differ: two
  caves sharing a name are at least about 690 m apart, two hamlets 1.9 km.
  The location label shows "Koivula · hamlet", "Hiidenluola · cave mouth" and,
  underground, "Hiidenluola · first level" or "· second level"; entering a
  cave or its second level names it.
- **World map (#66).** Walking marks the absolute 32 m cells within two cells
  of Oravitsa as explored, and coming within 60 m of a hamlet's centre or a
  cave mouth discovers it. M / Select cycles the local map, the world map and
  neither. The world map (`world_map.gd`) covers the screen at 4 m per pixel,
  centred on her (underground, on her cave's mouth). It draws explored cells
  in their ground colour, with roads and water, leaves the rest dark, and
  marks discovered hamlets and caves by name. The skill bar, bag and labels
  hide while it is open. Explored cells and discoveries are saved as flat
  absolute coordinate lists (`explored`, `discovered`); saves from before have
  none.
- **Signposts (#55).** At a road crossing with a hamlet or cave mouth between
  40 and 600 m away, `landscape.signpost_at` places a post on the first free
  off-road corner (3.6 m diagonally from the crossing, over 2.4 m from any
  road and clear of water). It has one board to the nearest hamlet (light
  wood) and one to the nearest cave (grey stone), each turned toward its
  destination, with a billboard label such as "Koivula hamlet · 260 m".
  Signs come from absolute coordinates and are cached per crossing like the
  other features, so streaming and rebasing rebuild them identically. They
  have no collision.
- **Cave mouths.** Each leads to a seeded first level (see below). A landmark
  region without a homestead gets a cave with an 80% chance, on the highest of
  14 seeded candidate spots at least 0.55 m above the base terrain. Candidates
  avoid roads, water, the region's landmark and hamlets. The mouth always
  opens south, toward the fixed camera: a dark recessed opening under a stone
  lintel in a mossy outcrop, flanked by two boulders. Its trail runs 6 m south
  and then to the nearest road. The trail must stay inside the region, keep
  clear of water and the landmark, and never pass back through the outcrop,
  or the spot gets no cave. One list of rock parts drives both collision and
  meshes, so Oravitsa can stand in the entrance while the rock behind it is
  solid. About one region in three has a cave. The label reads "Cave mouth",
  and the map shows a dark triangle.

`landmarks_smoke_test.gd` surveys 49 blocks and 117 regions, including
negative ones. Its checks:

- Solid houses, store tents and rock, and open entrances and crossings.
- Rock and tent collision ending at the drawn surface, sampled just inside
  and just outside each part and side.
- Every visited house, store tent, rock part and cave opening drawn once, at
  exactly its collision size, both before and after a 3 km rebased round trip
  that unloads and rebuilds them.
- Walkable door and cave trails that match their dressing.
- Bare clearings with no spawns inside, and identical regeneration.
- Bounded caches and the labels.
- Old saves positioned inside a house or homed in a clearing being moved
  to open ground on load, clear of a validly saved boar right beside it.

## Aura, feeding, villagers and the chieftain

- **Aura** is the game's points: a glowing HUD badge at the top centre with
  the number drawn on top (`aura_badge.gd`, `hud_icons/`). Every change
  shows a "+N aura · reason" notice and flashes the badge. Aura can go below
  zero. Positive aura fades by one point per minute of play (#64), on the
  surface and underground, silently and without a flash; decay stops at zero,
  the partial minute is kept in the save (`aura_decay`), and pausing stops it.
- **Feeding.** A fed level from 0 (starving) to 100 (full), drawn beside the
  aura badge as a bowl and a meter. It starts at 60 and falls 0.3 per second.
  Every 120 s Oravitsa eats one random bag item (each item equally likely):
  berries +25, a mushroom +30, raw meat +50. At 80 or more she skips the
  meal; a meal due with an empty bag waits for food, and once she is
  starving she eats whatever she finds at once. Speed: 60% starving, 100%
  half fed, 120% full (linear between). The stuns she suffers (bumps,
  charges, bites) are scaled from full length starving down to half when
  full. Starving shows a crossed-out bowl. Hunger never harms her.
- **Sprint.** Holding Shift, or clicking the left stick (L3) until she stops
  steering, multiplies her fed speed by 1.4 and drains 0.6 more fed per second
  while she actually moves (0.9 in all, three times as fast). The fed meter
  then gets an orange border and »» chevrons. There is no sprint while she is
  starving, stunned or panicking (panic keeps its own speed).
- **Villagers.** Two to four per hamlet, seeded from the hamlet, drawn with
  CC0 Quaternius farmer, man and woman models
  (`creatures/ATTRIBUTION.md`). They stroll around the clearing with pauses
  and ignore Oravitsa: neither blocks or bumps the other. Shoo sends one
  running and costs 5 aura; a Sling hit stuns one and costs 10. They appear
  within 150 m of their hamlet, leave beyond 230 m, regenerate identically
  and are never saved.
- **The chieftain.** One per hamlet, drawn with the CC0 Quaternius King, at
  his post 0.9 m in front of his store tent's entrance. He keeps to it
  (returning after a shoo), turns to Oravitsa when she is within 7 m, and
  the label then reads "Hamlet · the chieftain’s store". Within 2.4 m of him, O,
  controller A or the *Give food to the chieftain* button gives one random
  bag item: raw meat +3, a mushroom or berries +1. He waves his thanks. He
  takes nothing while stunned or scared, and the villager penalties apply to
  him too.

`village_smoke_test.gd` covers aura changes and the badge, feeding decay,
random meals, skipped meals when full, starving, the speed and stun scaling,
villager spawning, wandering, pass-through, shoo/sling penalties, the
chieftain's post and gifts by key and controller, leave/return regeneration,
and saving (version 2, with version-1 saves still loading).

## Cave levels

Walking into a cave mouth (within 0.9 m) enters that cave's first level
(`cave_level.gd`). It is a 26 × 20 grid of 2 m cells, generated from the
cave's region: an entry room under the mouth, five to seven rooms joined to
the nearest reachable room by tunnels (some two cells wide), all connected.
It extends north of the mouth, so Oravitsa walks straight in. Collision comes
from the grid, independent of the low drawn walls (low enough for the fixed
camera to see over). The cave is dark: the surface sun is off, the ambient
light is dim, a warm lantern follows Oravitsa, daylight marks the way out,
and checkpoint crystals glow blue.

- **Checkpoints.** Two or three, in the rooms farthest from the entrance.
  Reaching one gives +20 aura once; its crystal then dims to gold.
- **Giant rats and spiders.** Four to six rats and two or three spiders, at
  least 10 m from the entrance, drawn with CC0 Quaternius models. They scurry
  cell by cell around their lair (rats up to five cells, spiders three). They
  notice Oravitsa by walking distance, never through walls (rats 14 m, spiders
  10 m), chase her around corners using a map of walking steps to her, and
  keep at it until she is half as far again. They settle where a chase ends.
  Within 4 m a spider lunges at 1.8× speed for 0.7 s, every 4 s. A bite stuns
  her for 1.5 s, less when she is well fed (no health or injury), and plays
  the Attack clip, with a 3.5 s cooldown. The biter then scuttles back, the
  pack keeps 2.5 m away, and no monster can bite until two seconds after the
  stun, so she can always get away. Rats are faster (185 px/s) than spiders
  (140 px/s), but a half-fed Oravitsa outruns both. Shoo drives one off along
  the tunnels and Sling stuns one. A scared or stunned monster neither bites,
  bumps nor blocks her, and she walks through it. Monsters are never killed:
  only hares are (#74).
- **Panic.** Anywhere in the endless world, about a third of the stuns she
  would suffer (bumps, charges, bites) become panic instead, which breaks
  chains of stuns. For two seconds she runs by herself at 1.25× speed, away
  from what hit her or, in a cave, half the time toward the way out, turning
  along walls. A scared icon with a time bar floats above her. She cannot be
  stunned meanwhile, animals neither block nor bump her, and her skills still
  work. A cave mouth does not take her in while she panics, and panic is not
  saved. An animal she bumps is still stunned.
- **Freezing and saving.** While Oravitsa is underground, the surface
  landscape, food and wildlife are hidden and kept exactly as they were. The
  map shows "Underground". The sunlit way out returns her just outside the
  mouth. Collected checkpoints are kept per cave and saved. Saves from
  before #74 may also list killed monsters, which stay absent. Saving works underground: the save holds the waiting surface with
  her at the cave mouth, plus an `underground` section with the cave, her
  offset from the way out and each living monster's index, offset and stun.
  Loading re-enters that cave and puts them back; loading any save while
  underground first leaves the cave.

### Second level (#62)

Each first level has one **way down**: a dark shaft ringed with stones and lit
amber, on the floor cell farthest on foot from the way out that lies inside a
room and at least 4 m from every checkpoint. Walking onto it (within 1 m, not
while stunned or panicking) enters the cave's second level: the same
generator with a different salt, a 30 × 24 grid, six to eight rooms, slate
floor and walls and a darker ground. Its arrival spot, a pale stone ring under
a cold light, is the **way up**, which returns her to the way down. Like a
cave mouth, the spot she arrives on works only after she has stepped 3 m
away. The first level's monsters are kept exactly as they were while she is
below; the second level starts from its seed on every descent, as the first
does on every entry. The surface stays frozen throughout. The label reads
"Way down", "Way up" and "Hiidenluola · second level".

- **Checkpoints.** Two or three, +30 aura once each, saved per cave in its
  `deep` list.
- **Goblins** (Quaternius Goblin, CC0, 0.95 m): two or three packs of two or
  three. They hunt by walking distance like rats, slower (165 px/s) but from
  farther (20 m), and club her with the bite rules: a stun of at most 1.5 s,
  less when well fed, the Attack clip, then they back off and nobody can club
  or bite until two seconds after the stun.
- **Kobolds** (Quaternius Blue Demon, CC0, 0.75 m): two packs of two or three,
  fast (200 px/s) and timid. Within 16 m on foot, a kobold alone backs off
  when she is closer than 2.6 m, creeps up when she is farther than 4 m and
  waits in between. When three awake, calm kobolds are within 6 m of her they
  dart in, each for at most 2.5 s. One that touches her snatches one random
  bag item (the chieftain's random pick; no stun), shows a notice, plays its
  Punch clip and runs off for 4 s; for 3 s after a theft the others hang back.
  With an empty bag it just runs off.
- Sling, Shoo and Slow work on both; a stunned or scared one neither clubs,
  steals, bumps nor blocks her. Neither can be killed and neither has a call.
- **Saving.** The `underground` section also stores `level` (1 or 2); offsets
  and monster indices are relative to that level's arrival spot. Saves without
  it load on the first level. Saving below does not store the first level's
  waiting monsters: after loading there they start from their lairs.

`cave_level2_smoke_test.gd` covers the way down on many caves, identical and
connected second levels, both ways without bouncing, the waiting first level,
goblin chases, clubs and back-off, kobold distance-keeping, pack theft of
exactly one item, no theft while stunned or scared, deep checkpoints, and
saving, loading and older saves.

`cave_smoke_test.gd` covers seeding and variety, connectivity, entry and
exit, the frozen surface, lighting, bites, monsters that cannot be killed and leave
her alone while stunned or scared, once-only checkpoints, persistence across visits and saves,
and saving and loading underground.

## Wildlife

There are now six species. Seed weights are hare 52, deer 18, fox 10, boar 8,
wolf 7 and lynx 5. This intentionally makes predators more frequent than in
the retained finite scene. The ecology is intentionally sparse, at roughly a
third of v0.1's abundance (endless world only; finite scenes are unchanged).
The fixed initial population is 34 animals: 17 hares, 8 deer, 3 foxes, 2 boars,
2 lynxes and 2 wolves. Replenishment targets 6/3/1/1/1/1 for
hare/deer/fox/boar/wolf/lynx, with species-specific chances; a 1.5 km walk
averages about 10 animals in the local population radius (27 before). Food
patch chances are 4.3% of cells in birch woods and 2.7% elsewhere, giving about
400 patches per 200 m square around arrival (1115 before).
New arrivals and prey respawns stay outside the actual smoothed camera view.

Both wolves and lynxes hunt hares and deer. Hares are caught on contact; deer
require three seconds of continuous close pursuit, interrupted by losing
contact or stun. Endless wolves and lynxes chase in longer, faster spurts than
the finite scenes: 240 px/s for 2.2 s, restarting 3.4 s after each spurt
begins (finite scenes: 220 px/s for 1.5 s). Foxes hunt hares too, with weak
195 px/s, 1.4 s spurts. They avoid only boars, wolves and lynxes, and hares
now flee foxes. Seven of ten fox lunges miss, after which the fox rests for
nine seconds before hunting again. In isolated 20-second chases from 6 m
(`ecology_sample.gd`, 24 trials each), catches rose from wolf→hare 4 to 15,
lynx→hare 3 to 11, wolf→deer 0 to 4 and lynx→deer 1 to 7; foxes catch 2 hares
(previously they never hunted). Foxes also eat berries (never mushrooms) when no
hare is within reach or while resting after a missed lunge; hunting a nearby
hare takes priority. They use the shared foraging path: 0.7 s of eating
consumes a patch once, starts its normal 3–6 minute berry regrowth deadline and
grants no inventory. Fear or a stun resets eating progress, and a fox abandons
a patch that someone else emptied. A successful catch resets the predator's hunger. After
**180 seconds without a catch**, a predator despawns once outside the camera
view. Hunger keeps counting while visible; offscreen predators leave immediately
when the limit is reached.
Its slot has a 45-second reuse delay and does not use the prey respawn path.
The population system may later introduce a different arriving animal.
Wolves use a rigged Quaternius CC0 model with Idle/Walk/Eating/Gallop clips; there are
no attack or death animation calls. Oravitsa injures no animal and kills only
hares, which would otherwise multiply out of control: Sling stuns and Shoo
repels, with the existing keyboard/touch/controller inputs. Stunned animals
can be walked through without a bump. A hare that is currently stunned and within 75 px can be collected by walking
to it or pressing A. It is removed once and becomes one raw meat. Its slot is
marked gone with the 45-second reuse delay, so it never takes the prey respawn
path; ordinary replenishment restores the hare population.
Shoo shares the selected target/range with Sling and scares only that animal
for five seconds. It interrupts feeding/hunting and existing animal stun,
immediately starts a fast escape away from Oravitsa, and shows a sweat-drops
icon with a time-left bar above the animal. Rigged animals gallop where available;
painted animals animate faster. The cooldown is seven seconds and is not spent
on invalid casts. Fear has priority over prey pursuit, food and home return;
ordinary AI resumes when it expires. Sling can stun a scared animal; both
status icons appear side by side while it is frozen, and the fear bar keeps
emptying.
Collision and recovery routes still apply.

**Aggression toward Oravitsa.** Lingering within 290 px (about 4.5 m) of a wolf,
lynx or boar builds provocation; backing away drains it twice as fast. After
2.4 seconds there is a 70% chance the animal turns angry; otherwise it ignores
her for six seconds before another roll. An angry animal stands still for
1.2 s under a red anger-mark icon, with a HUD notice, and then charges for at most
4.5 seconds (wolf 232, lynx 228, boar 196 px/s; Oravitsa walks at 210).
Reaching her stuns her for two seconds; an already stunned Oravitsa is not
stunned again. Hit or miss, the animal then loses interest for 20 seconds.
These values were raised slightly in #54 (from 260 px, 3 s, 60%, 8 s, 4 s and
25 s). A Sling hit leaves a grudge (#63): the moment its stun ends, the animal
gives the same 1.2 s warning and charges, regardless of dwell, chance or
cooldown, if she is within 870 px. It never attacks while stunned, even when hit
again, and Shoo or her being farther away settles the grudge.
Shoo, any stun, feeding (after a catch or at a food patch) or leaving the active
area ends the encounter at once.
A charge overrides hunting and uses ordinary collision-checked movement. There
is no damage or death. Retained finite scenes have no aggression.

**Fights.** Calm wolves, lynxes and boars of *different* species within 140 px
are checked once per second, with a 12% chance to fight; same-species pairs do
not fight. Both square off in place for 2.5 s under one scuffle-cloud icon
centred over the pair. Wolves win slightly more often (strength 1.2 against 1.0). The loser
is stunned for four seconds (with the normal dizzy-stars icon and bar); nobody is
hurt or removed. Both then avoid fights for 45 s. An animal that is stunned,
scared, feeding (including a forager in the middle of eating a patch), hunting
or provoked by Oravitsa never starts a fight. Shoo, a
stun or leaving the active area ends a fight for both with no winner and a
20 s cooldown. A fighting animal ignores prey and Oravitsa.

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
