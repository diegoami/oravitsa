# Oravitsa — design

## Premise

Oravitsa is a cosy 2D foraging game in a Nordic summer forest. A young
forager gathers food against a hunger clock while animals compete for the same
resources. The central question is whether choosing routes and responding to
animals makes a pleasant, replayable loop.

## The hard constraint

**Oravitsa cannot kill any creature in this iteration, including hares.**
Her interactions with creatures are non-lethal influences such as shooing,
attracting, confusing, or slowing. The sling temporarily stuns a selected animal;
it does not injure or kill it.

- Animal predation is separate from player abilities: lynxes can kill hares
  and deer. Hares are caught quickly; deer require three seconds of continuous
  close pursuit. Losing contact or interrupting the lynx resets that progress.
  Both prey species return away from the player; hares replenish frequently.
- No player damage, health, or hit-point combat system.
- Competition for resources is the conflict. An animal reaching a mushroom
  first wins that exchange.
- Influence abilities change movement or attention without lasting injury.

## Wildlife abundance

Hares are frequent, deer and foxes are less common, boars are less common
again, and lynxes are rare. Both initial world generation and replenishment
must respect this order; do not guarantee every species near the player.
The current tuning is documented in `scenes/forest_2d/README.md`.

## Earlier single-clearing playtest loop

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

The hunger clock, boar pace, and basket goal in the earlier prototype remain
tunable. The current forest adds a larger world and species-specific animal
behaviour. Additional player abilities, biomes, progression, save format,
and audio remain undecided.
