# Changes

## Unreleased

- Launch into a labelled bot-driven demo with the normal food/aura/hunger HUD
  and a small translucent floating Start button (#120). Oravitsa gathers,
  stuns and collects hares, seeks real villages and cave mouths, gives food
  to chieftains and uses Shoo/Cure. Local routes and a progress watchdog
  recover from blocked goals; a fresh demo repeats every five minutes.
- Start opens scrollable rules and keyboard/controller/touch controls.
  Separate confirmation begins a clean player-controlled world after held
  controls are released. The demo never loads or writes the manual save.

## 0.3.0-alpha.2 — visibility, movement and map fixes (candidate)

A small fix release for the known issues of 0.3.0-alpha.1. Existing controls
are unchanged (the open world map gains zoom inputs) and older saves load as
before.

- Dark creatures stay visible in caves (#102): kobolds have a faint cool
  glow and rim, and Oravitsa's pets a warm one while underground, so the
  husky and kobolds no longer vanish against the floor. On the surface pets
  look as before.
- Pets and mounts keep their whole body out of trees, rocks and walls, and
  out of creatures (#103): each checks a nose point ahead of it as well as
  its middle, a ridden mount's head stops at a trunk, and a pet or a mount
  walking home never steps further into a monster, an animal or a villager
  (it can always step away from one that walked into it). A pet still bites
  the monster it hunts.
- A mount or pet walking home no longer presses against what is in its way
  (#104): once it stops making progress it plans a short detour around
  houses, trees and walls, as wildlife does, and walks the rest of the way.
  Its detour avoids creatures standing in the way and is planned again while
  it is still stuck (#116), and diagonal steps keep the nose clear (#117).
- The world map zooms (#105) from 1 to 32 m per pixel: + / −, the mouse
  wheel, the + / − buttons on it, or right-stick flicks while it is open. The
  footer shows the scale, and place names that would overlap are left out.
- Riding, Oravitsa rises and settles in time with her mount's walk or gallop
  (#106, partly): a code-only bob, higher at a gallop, until a seated riding
  animation exists. She sits still while the mount stands.
- `SHA256SUMS.txt` and `release-manifest.json` always use LF line endings, so
  `sha256sum -c SHA256SUMS.txt` works on Linux without stripping CRs (#107).

## 0.3.0-alpha.1 — deeper caves, mounts and pets

Larger than earlier alphas: new skills and controls, places with names,
signposts and a world map, a second cave level, mounts, and dog and cat pets
that finish off stunned, scared or slowed monsters. Controls changed: LB/RB now cast Slow and Cure directly, Y no
longer casts the selected skill (Y rides a mount), and skill cycling is gone.

- Pets (#65): about three hamlets in five keep a cat, a Shiba Inu or, rarely,
  a husky, each asking for its own aura (20–40, 40–65 or 65–90, shown above
  it and on the Adopt button). Press G, controller A or the button to have up
  to two follow Oravitsa. They keep up and follow her into caves and between
  levels. There a pet kills a monster that is stunned, scared or slowed (cats
  leave goblins alone); the monster stays dead in that cave. Oravitsa herself
  still never kills. Monster bites poison (spiders) or wound (rats, goblins)
  a pet, which then follows slowly and stops hunting until her Cure heals it.
  Too little aura sends a pet home. Saves keep her pets.
- Donkeys, mules and horses (#67): each hamlet keeps one or two by the store
  tent. With enough aura (donkey 15, mule 35, horse 70) press T, controller Y
  or the Ride button to ride one: faster (×1.3, ×1.5, ×1.8) but no sprint. A
  donkey halves the stuns Oravitsa suffers; a horse throws her off when she
  is knocked down. Losing the aura makes the mount leave her and walk home.
  Mounts wait outside caves and wherever she leaves them, and saves keep them.
- Caves go deeper (#62): an amber-lit way down leads from each cave's first
  level to a larger, darker second level with its own checkpoints (+30 aura
  each). Packs of goblins hunt Oravitsa and club her, which only stuns her;
  timid kobolds keep their distance until three gather, then snatch a random
  item from her bag and run. The way up returns her to the way down. Saves
  remember which level she is on. Goblin and kobold models are CC0 by
  Quaternius.
- Caves sound like caves (#61): underground the wind and birdsong pause and a
  low drone and dripping water play instead, rats squeak and spiders hiss, and
  calls echo. Leaving the cave brings the woods back where they were. All
  sounds are synthesized by `tools/synth_audio.py` (CC0).
- A zoomed-out world map (#66): press Map (M / Select) a second time to see
  everywhere Oravitsa has been, with roads, water and the hamlets and caves she
  has found, by name. Exploration is saved. Nearby places no longer share
  names.
- Signposts at road crossings (#55) point to the nearest hamlet and cave,
  with their names and distances, such as "Koivula hamlet · 260 m". They
  stand beside the road and never block it.
- Hamlets and caves have names (#56) in Finnish, Swedish and Ukrainian styles,
  such as Koivula, Björkby, Sosnivka, Hiidenluola, Trollgrottan and Vovcha
  Pechera. The location label and the cave notice use them, and each place
  keeps its name for good.
- Aura slowly fades (#64): one point per minute of play while it is positive,
  on the surface and in caves. Decay alone never takes it below zero, saves
  keep the partial minute, and it stops while the game is paused.
- Wolves, lynxes and boars hit by the sling bear a grudge (#63): when the stun
  ends they give their usual warning and charge, unless Shoo has settled it or
  Oravitsa is far away. They never attack while stunned. They are also a
  little quicker to anger (#54): 290 px instead of 260, 2.4 s of lingering
  instead of 3, a 70% chance instead of 60, a 6 s retry, 4.5 s charges and
  a 20 s cooldown. Charges and hits still only stun.
- Slow and Cure skills (#59), cast directly with LB and RB (#60). Slow (E;
  LB) halves the selected creature's movement for six seconds, shown by a
  snail icon with a time bar, on a ten-second cooldown. Cure (R; RB) ends
  Oravitsa's own stun or panic, even while she is stunned, on a fifteen-second
  cooldown. Skill selection and cycling are gone: Y casts nothing. Saves keep
  the new cooldowns; older saves still load.
- Oravitsa can no longer kill cave monsters; hares are the only creatures
  she kills (#74). Only her pets can kill a monster, and only while it is
  stunned, scared or slowed (#65). The +5/+10 aura for rats and spiders is
  gone. A
  stunned or scared rat or spider neither bites, bumps nor blocks her, and she
  walks through it. Saves listing monsters killed earlier still load.
- Pause (#57). A Pause button beside Help, P or Esc, or the controller's
  right-stick click (R3) freezes the whole game, on the surface and in caves:
  animals, monsters, hunger, timers, animations and sound. A dimmed overlay
  shows Resume, which the same keys, a click or A also trigger.
- Sprint (#58). In the endless woods, holding Shift or clicking the left stick
  (L3, until she stops steering) makes Oravitsa 1.4 times as fast while she
  gets hungry three times as fast. The fed meter shows an orange border and
  »» chevrons meanwhile. There is no sprint while starving, stunned or
  panicking. Speed and drain are first guesses to tune by playing.

## 0.2.0-alpha.3 — livelier caves

- Animals no longer get stuck in loops (#52). They used to turn back and forth
  at the edge of their home range, wander straight back into what had just
  scared them, and press forever against food or a way home they could not
  reach. Now they walk well back inside their range, stay clear of what scared
  them, and give up on what they cannot reach.
- Shoo sends animals off at a less extreme speed, about 1.4 times Oravitsa's
  normal walking speed instead of 1.8 (#53).
- Giant rats and spiders are much more active (#50). They scurry around their
  lairs, find their way to Oravitsa around walls, notice her by walking
  distance instead of through walls, and move faster; spiders lunge when she
  is close. After a bite the pack backs off and none can bite again until two
  seconds after the stun, so she can always get away.
- About a third of the stuns Oravitsa would suffer now make her panic instead:
  she runs for two seconds, away from what hit her or toward the cave's way
  out, and cannot be stunned or blocked meanwhile. This breaks chains of stuns.
- Giant rats are smaller, with a matching smaller collision size (#51).
- Eating boars no longer get provoked (#48).

- **Aura**, the game's points: a glowing HUD icon with the number on top (#42).
- **Feeding**: a fed meter beside aura. Oravitsa eats a random bag item every
  two minutes unless full. Well fed she walks faster and recovers from stuns
  sooner; starving she walks slower (#43).
- **Villagers** stroll around each hamlet and ignore Oravitsa. Shooing or
  hitting them costs aura. Each hamlet's **chieftain** stands at his store
  tent, which replaces the hamlet well, and takes food gifts for aura (#44).
- **Cave levels**: every cave mouth leads to a seeded, lantern-lit first level
  with checkpoints worth aura (#45). Its giant rats and spiders bite (a stun
  only) and can be stunned with Sling and finished for aura (#46). Saving
  works underground.
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
