# Oravitsa

Godot 4.7.2 / GDScript, Compatibility renderer. The default opening in
`scenes/opening/` runs a disposable bot demo, then rules/controls and a fresh
player session. Gameplay is the streamed endless 2.5D Mossbank world in `scenes/endless_woods/`, extending the finite
presentation in `scenes/forest_25d/`; its simulation, controls and HUD
extend `scenes/forest_2d/forest.gd`. Read the world guide there before changing
it. The older 2D forest and `prototypes/foraging_2d/` remain usable.

This is the shared instructions file for every assistant. `CLAUDE.md` imports it.

## Work and review

- Start from a fresh `origin/main`; preserve work belonging to other sessions.
  Commit and push completed work, and open a PR. Leave it open for the owner
  unless the owner explicitly requests a merge. Never self-approve a PR.
- Explain the problem, resulting behavior, verification and limits in the PR.
  For a guard, include `Protects:` and the wrong outcomes it must reject.
- Independent reviews use a fresh session and a different model family from
  the implementer. The implementing session never reviews itself or spawns its
  own reviewer. The owner chooses and starts the reviewer.
- Optional PR reviews follow `docs/review-pr.md` and stay in the PR thread.
  Release-milestone reviews follow `docs/RELEASES.md` and
  `docs/review-release.md`. A PR or a process change alone is not a milestone.
- Reproduce findings before changing code. Fix confirmed defects on the PR
  branch and push; give evidence for disputed findings and let the owner
  decide. Do not dismiss or resolve another reviewer's findings automatically.
- For parallel work or reviews, use a distinct worktree. Never switch, reset,
  pull, reuse or remove another session's checkout. Read review instructions
  for the detached worktree and exact-SHA rules.

## Verification

Use standard **non-.NET Godot 4.7.2** and matching templates for Web exports.
Python 3.10+ runs the tools with no third-party dependencies. Set `GODOT_BIN`
or pass `--godot` when the engine is not on PATH; Windows needs a real executable.

```sh
python3 -m unittest discover -s tools -p 'test_*.py'
python3 -m unittest discover -s art -p 'test_*.py'
python3 tools/verify.py --godot /path/to/godot
python3 tools/export.py all --godot /path/to/godot
```

`verify.py` imports and runs all twenty-eight smoke scripts, including the opening bot/start flow and targeted
Shoo, endless-world travel/rebasing/ecology/food regrowth, wildlife behaviour
loops, fox foraging, hare collection, aggression, fights, save/load, audio wiring, hamlets and
cave mouths, aura/feeding/villagers/chieftain gifts, both cave levels and their
monsters, pausing, mounts, pets, queued streaming,
offscreen wildlife spawning and the retained foraging prototype. A gate must reject Godot
error output, a nonzero exit, timeout and a missing completion marker: Godot
can exit zero after an assertion or script error. CI uses this same runner.
Logged errors terminate the process immediately; timeouts retain diagnostics.
Native export startup uses `tools/verify.py --native-smoke <executable>` for
the same log-aware error handling. To run one smoke script on its own, use
`godot --headless --path . -s scenes/.../<name>_smoke_test.gd` under a
timeout and read its output for `SCRIPT ERROR`: a failed assertion there
leaves Godot running instead of exiting, so the timeout is the failure signal. Offline Python art tests use mock clients.
`Build desktop and Web` also exports Web/Linux and starts the Linux package.
Before merging, check the final PR SHA's CI, not a previous run.

For gameplay changes run the relevant scene checks; for shared simulation,
HUD or input changes run the complete runner. For changes to this workflow or
the verification runner, run its Python tests and the complete runner.
For visible changes inspect native renders in addition to headless checks.
Before a release, check packaged desktop and real-browser builds, resizing,
movement behind trees, bridges, pickups and controller prompts. An export or
headless package start does not establish Web playability or performance.
Record unavailable checks as untested, never as passed.

## Gameplay contracts

- Oravitsa never injures wildlife, and hares are the only wildlife she kills:
  unchecked, hares would multiply out of control. Sling stuns; Shoo repels. A
  hare that is currently stunned and within 75 px can be collected (walk-over,
  or A on a controller). It is removed exactly once and immediately becomes
  one raw meat; no other wildlife species can be killed or collected. The
  giant rats and spiders of cave levels and the goblins and kobolds of second
  levels are monsters, not wildlife. Oravitsa never kills one either (no
  walk-over, no A); only her pets can, and only while the monster is stunned,
  scared or slowed. A stunned or scared one does not affect her: it
  neither bites, bumps nor blocks her, and she walks through it.
  Sling, Shoo and Slow use the selected animal. Slow (E; LB) halves its
  movement for six seconds, with a snail icon, on a ten-second cooldown.
  Cure (R; RB) ends Oravitsa's stun and panic, even while she is stunned,
  and the poison and wounds of every following pet within 6 m of her, on a
  fifteen-second cooldown; its notice names what it cured, and it is not
  spent when there is nothing to cure. Shoo applies five seconds of visible
  scared status and fast escape, with a seven-second cooldown; invalid casts do
  not spend cooldown. It interrupts feeding/hunting and existing animal stun.
  Wolves and lynxes can kill hares; deer require three seconds of close pursuit.
- Wildlife must not flip between behaviours at a single limit or press forever
  against what it cannot reach: home range, fear and giving up all have
  separate start and stop values or timers.
- In the endless world about a third of the stuns she would suffer (bumps,
  charges, bites) become panic instead: for two seconds she runs by herself,
  faster, away from what hit her or, in a cave, half the time toward the way
  out, with a scared icon and time bar. While panicking she cannot be stunned
  and animals neither block nor bump her; her skills still work.
- Oravitsa walks through stunned animals with no bump. Walking into an awake
  animal stuns both for 1.2 seconds (Oravitsa less when well fed, above). Stepping out of an animal she overlaps
  (one that woke up under her) is never a bump, and such an animal can step
  away from her but never further in.
- Animal states (stunned, scared, angry, charging, fighting) are shown as
  icons above the animal, never as text. Timed states have a time-left bar,
  and stun and fear can show together.
- Aura is the endless world's points: a HUD icon with the number on top.
  Gains: a cave checkpoint (+20, once each; +30 on a second level) and food given to a hamlet's chieftain (+1 berries/mushroom, +3
  raw meat). Losses: shooing (−5) or hitting (−10) a villager or chieftain,
  and a slow decay of one point per minute of play while aura is positive
  (never below zero by itself; the fraction is saved; none while paused).
- Feeding: a fed level from 0 to 100, shown beside aura, falls 0.3 per
  second. Every 120 s Oravitsa eats one random bag item (berries +25,
  mushroom +30, raw meat +50) unless she is at 80 or more; starving (0), she
  eats as soon as she has food. Her speed runs from 60% starving through
  100% half fed to 120% full, and the stuns she suffers (bumps, charges,
  bites) shrink from full length starving to half when full. Hunger never
  harms her. Sprint (Shift held, or L3 until she stops steering) multiplies
  her speed by 1.4 and adds 0.6 fed lost per second while she moves; there is
  no sprint while starving, stunned or panicking.
- Hamlet villagers ignore Oravitsa: neither blocks or bumps the other. Each
  hamlet's chieftain keeps to his post at his store tent and takes food gifts, one
  random bag item each (not while stunned or scared). Villagers and
  chieftains are seeded per hamlet and never saved.
- Mounts (#67): each hamlet has one or two seeded mounts tethered beside its
  store tent (donkeys most common, then mules, then horses); tethered ones are
  never saved. Riding needs aura: donkey 15, mule 35, horse 70, and the ride
  prompt states the requirement when it is not met. Riding multiplies her fed
  speed (×1.3, ×1.5, ×1.8) with no sprint. While riding, a donkey halves the
  stuns she suffers, a mule changes nothing, and a stun from a horse ride
  also throws her off; panic makes her slip off first. Aura below the
  requirement dismounts her at once and the mount walks home from there.
  Mounts never enter caves: she gets off near the mouth and it waits outside.
  A ridden mount and any mount left away from its tether are saved at
  absolute positions, never duplicated at their hamlet. Mounts are not
  wildlife: no Sling/Shoo/Slow target, no bumps, never harmed.
- Pets and mounts (#103) keep their nose, half a body length ahead, out of
  trees, rocks and walls as well as their middle; riding, her moves need the
  mount's nose clear too. A pet, or a mount walking home, never steps
  further into a live creature (it may always step away); a hunting pet is
  exempt only from its prey. Creatures do not avoid pets or mounts.
  A pet or mount walking home that stops making progress plans a short
  detour around what blocks it, creatures included, and plans again while
  still stuck (#104, #116), instead of pressing on in a line. Each step is
  checked in the direction it moves, so a diagonal one keeps the nose clear
  too (#117).
- Pets (#65): about three hamlets in five keep one seeded pet near the
  clearing's edge: a cat (most common), a Shiba Inu or a husky (rare), with an
  aura threshold seeded in its band (20–40, 40–65, 65–90). The adopt prompt
  and a floating label state it; below it she cannot adopt. At most two follow
  her, a few metres behind, never blocking or bumping her, catching up by
  appearing just behind her when far or off-screen. Aura below a follower's
  threshold sends it home at once with a notice; asking right beside a
  follower does too. They go into caves, down and up levels and out with her.
  Underground only, a healthy pet runs at a monster that is stunned, scared or
  slowed (cats: rats, spiders, kobolds; dogs: goblins too) and kills it with a
  bite: removed exactly once, Death clip, dead for good on that level of that
  cave (saved), no aura. It never attacks an awake, unhindered monster. An
  awake, unscared, unstunned monster that reaches a pet bites it on its usual
  cooldown: a spider poisons it, a rat or goblin wounds it, a kobold does
  nothing. A poisoned or wounded pet shows an icon, follows at 60% pace and
  never attacks until Cure heals it; there is no health or death. Pets never
  touch wildlife or villagers. Followers are saved (hamlet, kind, threshold,
  afflictions) and never duplicated at their hamlet; the rest regenerate.
  Pets are no Sling/Shoo/Slow target.
- Hamlets and caves have Finnish, Swedish or Ukrainian-style names
  (`place_names.gd`) chosen from their absolute block or region, so a name
  never changes with streaming, rebasing or loading. Signposts at road
  crossings name and point to the nearest real hamlet and cave within
  600 m, stand off the road and have no collision.
- Each cave mouth leads to its seeded first level. The surface freezes while
  Oravitsa is underground. Saving works there: the save keeps the surface,
  her spot in the cave and the living monsters' positions and stuns. Rats
  and spiders find their way around walls and bite, which only stuns her
  (1.5 s at most); there is still no health or death. After a bite the pack
  backs off and no monster can bite until two seconds after the stun, so she
  can always get away. Collected checkpoints persist per cave and level in
  the save. Each first level has one way down, far from the way out, to a
  larger, darker seeded second level whose arrival spot is the way up back to
  it; like a mouth, neither works again until she has stepped 3 m away, and
  the way down not while she is stunned or panicking. The first level's
  monsters wait unchanged while she is below. Goblins chase and club her like
  bites (stun only, same grace). Kobolds never stun: alone they keep about
  3 m away; once three are within 6 m of her they dart in, and one that
  touches her snatches one random bag item and runs off, after which the pack
  hangs back for 3 s; she walks through them, so a kobold never bumps her. A save made there records the level, the bite grace, the hang-back and the monsters' attack and flight timers; older saves load
  on the first level.
- In the endless world wolves/lynxes are more frequent, sprint in longer and
  faster spurts, hunt both prey species and despawn after 180 hungry seconds.
  Endless foxes also hunt hares but rarely catch them. The finite scenes
  retain rare lynxes. Hares remain most frequent, with deer/foxes less and
  boars uncommon; endless food and wildlife are about a third of v0.1 density.
- Endless wolves/lynxes/boars can be provoked by lingering nearby: a visible
  warning, a bounded charge and a stun-only hit, then a disengagement
  cooldown. Shoo/stun interrupt it. A Sling hit provokes one too: when its
  stun ends (never while stunned) it warns and charges if she is within
  870 px; Shoo settles that grudge. No player damage, death or lethal combat.
  Cross-species wolf/lynx/boar fights are rare, nonlethal (loser stunned) and
  followed by a cooldown.
- Controller: left stick/D-pad moves, right-stick flicks cycle targets,
  LT casts Shoo and RT casts Sling directly, once per pull (fire at 0.6,
  re-arm below 0.3). LB casts Slow and RB casts Cure directly; there is no
  skill selection or cycling. In the endless woods Y (keyboard T, or the
  Ride button) gets on or off a mount; elsewhere it does nothing. A collects food;
  beside a chieftain it gives food, and beside a cat or dog (keyboard G, or the
  Adopt button) it adopts it or sends a following pet home.
  Map/Help start hidden (M/H; Select/Start). In the endless woods M/Select
  cycles the local map, the explored world map and none; the open world map
  zooms from 1 to 32 m per pixel (#105) with + / −, the wheel, its buttons or
  right-stick flicks (which then do not cycle targets); exploration and
  discovered hamlets and caves are absolute and saved. Pause (the HUD button, P/Esc;
  R3) freezes the whole game, surface and caves, until Resume. L3 sprints.
- Keep the approved eight-direction Oravitsa walk and movement-driven gait.
  Do not replace it with the uncorrected source model.
- Streaming must preserve pickups and animal state. Collision must work even
  outside loaded render chunks. Dress paths without making them impassable.
  Endless-world food can regrow on staggered offscreen timers; preserve their
  absolute deadlines across streaming and rebasing rather than resetting them.

## Scope and sources

Normally read `scenes/`, `tools/`, `docs/`, `art/`, `.github/` and relevant
root files. Do not search generated `.godot/`, `build/`, `export/`, `dist/`
or inspect binary art by default. Never open or echo credentials or API keys.
Paid art/API jobs require authorization for that work; use the recorded art
pipeline and preserve asset provenance. Do not regenerate approved art as a
routine code fix.

This workflow was adapted on 2026-10-26 from Geoclick2027 at
`d296ac3ef731f04776cb1877934a0bb78347e523`, with Scopetta at
`46eca26cee1a943d17b8e49f4e918846f259353a` as a second reference. The local
`harness_template` clone was unavailable; this is an explicit project adaptation,
not a claimed adoption of a tagged harness release. Model-specific routing,
paid reviewer scripts and unrelated application gates were not copied.
