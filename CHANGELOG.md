# Changes

## Unreleased — endless woods

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
