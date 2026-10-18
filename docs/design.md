# Oravitsa — design

## Premise

Oravitsa is a cosy 2D foraging game in a Nordic summer forest. A young
forager gathers food against a hunger clock while animals compete for the same
resources. The central question is whether choosing routes and responding to
animals makes a pleasant, replayable loop.

## The hard constraint

Oravitsa has no attacks. Her interactions with creatures are non-harmful
influences such as shooing, attracting, confusing, or slowing. **Nothing in
this game may ever damage or kill a creature.** This applies to the player,
animals, and anything added later.

- No health, damage, hit points, or death on creatures.
- Competition for resources is the conflict. An animal reaching a mushroom
  first wins that exchange.
- Influence abilities change movement or attention, never a creature's
  physical condition.

## Current playtest loop

One fixed painted clearing contains 17 mushroom patches. Oravitsa must gather
9 within 90 seconds. A boar seeks the nearest available patch, with a pause
between pickups; Space briefly shoos it away when close, subject to a
cooldown. Deer roam but do not take food. The round ends when the basket is
full, time runs out, or too few patches remain. Press R to replay. The fixed
layout makes route and pacing comparisons meaningful.

This is a test of the loop, not a final difficulty target or art pipeline.
Walk strips are short, sideways movement mirrors a three-quarter view, and
the single-screen forest has no terrain obstacles or wider world.

## To decide after playtesting

The hunger clock, boar pace, and basket goal are tunable. Animal behaviour,
additional non-harmful abilities, biomes, progression, save format, audio,
and a larger world are not yet designed. Add them only if the basic loop is
worth continuing.
