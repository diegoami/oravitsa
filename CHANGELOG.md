# Changes

## Unreleased

- **Karma**, the game's points: a lotus HUD icon with the number on top (#42).
- **Hunger**: Oravitsa eats from her bag every two minutes. With an empty bag
  she is hungry and walks slower (#43).
- **Villagers** stroll around each hamlet and ignore Oravitsa. Shooing or
  hitting them costs karma. Food offered at a village well earns karma (#44).
- **Cave levels**: every cave mouth leads to a seeded, lantern-lit first level
  with checkpoints worth karma (#45). Its giant rats and spiders bite (a stun
  only) and can be stunned with Sling and finished for karma (#46).
- Saves are version 2; version-1 saves still load.

## 0.2.0-alpha.2 — hamlets and caves (candidate)

This release supersedes the unreleased 0.2.0-alpha.1 candidate and includes
all of its changes, listed in the next section.

- Oravitsa walks through stunned animals with no bump. Stepping out of an
  animal that woke up under her is never a bump either, and it can step away.
- Animal states are icons instead of text, on dark round badges, in all
  scenes: dizzy stars (stunned), sweat drops (scared), an anger mark (angry
  warning), a red burst (charging) and a scuffle cloud (fighting). Timed
  states have a bar that empties as they run out. Stun and fear show side by
  side.
- The hare exception is now stated with its reason: hares are the only
  animals Oravitsa kills, because unchecked they would multiply out of control.
- Empty hamlets at one road crossing in six: 3–6 closed, weathered cottages, a
  well and a bare clearing. Exterior cave mouths on high ground in about one
  landmark region in three. Both are seeded and solid, with walkable trails,
  map icons and labels (#22). Saves from before hamlets load with Oravitsa
  and animals moved off any new house to the nearest open ground.

## 0.2.0-alpha.1 — living woods (never released; included in 0.2.0-alpha.2)

- Sparser endless woods: food and wildlife at about a third of v0.1 density
  (#21); finite scenes unchanged.
- Longer stuns with visible countdowns: Sling 4.5 s, bumps 1.2 s; a hit never
  extends an existing stun, so animals cannot be stun-locked (#26).
- Endless wolves and lynxes chase in longer, faster spurts and catch more
  often; foxes hunt hares but rarely catch them (#16) and eat berries between
  hunts (#24).
- Controller LT casts Shoo and RT casts Sling once per pull; LB/RB + Y remain
  (#18).
- A stunned hare can be collected once as raw meat, a new inventory slot; the
  only exception to the no-killing rule (#19).
- Lingering near a wolf, lynx or boar can provoke a warned, bounded charge that
  stuns Oravitsa, followed by a cooldown (#20). Occasional nonlethal
  cross-species fights leave the loser stunned (#25).
- One manual, versioned save slot for the endless woods with verified safe
  replacement, a backup and rejection of bad saves without data loss (#17).
- Synthesized CC0 forest ambience and nearby animal calls with forest/animal
  volume controls (#23).
- Design proposal for empty caves and villages, not implemented (#22).
- Six new smoke scripts (nineteen in total) and an ecology sampling tool.

Untested in this candidate: listening quality, browser and native audio
playback, browser save persistence, physical controller triggers and
touch-device play.

## Endless woods (merged after 0.1.0-alpha.1)

- Targeted, stronger Shoo: select an animal, then scare it into a five-second
  fast escape with a visible SCARED countdown; no cooldown spent on invalid casts.

- Infinite-direction procedural terrain with winding connected roads, generated
  river crossings, lakes, four landscape types and four landmark styles.
- Sparse forage state and floating-origin rendering; harvested food remains
  consumed until its regrowth timer expires, even when revisiting distant regions.
- Occasional offscreen food regrowth: berries after 3–6 minutes, mushrooms after
  5–9 minutes, with staggered timers for player- and animal-consumed patches.
- More predators, with a rigged CC0 wolf joining lynxes. Both hunt hares/deer,
  reset hunger after eating and despawn after three hungry minutes.
- Bounded local pathfinding recovery for stuck wildlife, an endless local map,
  and regressions for long-distance travel, ecology and navigation.
- The finite 2D/2.5D scenes and pinned alpha draft remain available separately.

## 0.1.0-alpha.1 — first playable alpha

- Explore the 192 × 192 m Mossbank woods: three lakes, a river and tributary,
  four bridges, five abandoned sites and the forester's old well.
- Oravitsa's approved eight-direction walk; rigged deer and foxes, with hares,
  boars and a rare lynx. Sling stuns and Shoo repels; Oravitsa cannot kill.
- Keyboard/mouse, touch and controller controls; selectable skills and cooldowns,
  food inventory, and hidden-by-default map/help panels.
- Streamed terrain, vegetation, food and wildlife; local state survives leaving
  an area. Queued chunk creation reduces synchronous streaming bursts.
- Lit foliage with a character reveal, calmer water, dressed starting shores,
  weathered cottage details and smooth bridge/doorstep approaches.
- Windows and Linux desktop exports and a static-hostable Web build.
- Wildlife arrivals and respawns stay outside the smoothed camera view.
- Export cleanup and per-file provenance reject stray or changed archive
  contents; Windows version resources identify this alpha as 0.1.0.1.

This is an early prototype. Progress does not survive quitting/reloading; there
are no quests, swimming or building loot. Animal/building styles remain mixed.
Browser, physical controller/touch-device and moving-camera flicker checks are
not established by headless tests. Independent baseline audit #3 found no
MUST-FIX issue in its stated coverage; its follow-up fixes and this release
preparation require exact-candidate review before publication under the release
policy. No full-project or release approval beyond that coverage is claimed.
