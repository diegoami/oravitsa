# Oravitsa

Godot 4.7.2 / GDScript, Compatibility renderer. The default is the streamed
endless 2.5D Mossbank world in `scenes/endless_woods/`, extending the finite
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

`verify.py` imports and runs all thirteen smoke scripts, including targeted
Shoo, endless-world travel/rebasing/ecology/food regrowth, queued streaming, offscreen wildlife spawning and the
retained foraging prototype. A gate must reject Godot
error output, a nonzero exit, timeout and a missing completion marker: Godot
can exit zero after an assertion or script error. CI uses this same runner.
Logged errors terminate the process immediately; timeouts retain diagnostics.
Native export startup uses `tools/verify.py --native-smoke <executable>` for
the same log-aware error handling. Offline Python art tests use mock clients.
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

- Oravitsa cannot kill animals, including hares. Sling stuns; Shoo repels.
  Both use the selected animal. Shoo applies five seconds of visible scared
  status and fast escape, with a seven-second cooldown; invalid casts do not
  spend cooldown. It interrupts feeding/hunting and existing animal stun.
  Wolves and lynxes can kill hares; deer require three seconds of close pursuit.
- In the endless world wolves/lynxes are more frequent, sprint in longer and
  faster spurts, hunt both prey species and despawn after 180 hungry seconds.
  Endless foxes also hunt hares but rarely catch them. The finite scenes
  retain rare lynxes. Hares remain most frequent, with deer/foxes less and
  boars uncommon; endless food and wildlife are about a third of v0.1 density.
- Controller: left stick/D-pad moves, right-stick flicks cycle targets,
  LB/RB select the active skill, Y always casts it, A collects food.
  LT/RT do not select skills. Map/Help start hidden (M/H; Select/Start).
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
