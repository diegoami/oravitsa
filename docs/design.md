# Oravitsa — design

## Premise

Oravitsa is a cosy foraging game in a Nordic summer forest. The current default
is an endless procedural 2.5D woodland: winding connected roads, rivers, lakes,
varied tree cover and discoverable landmarks. A young forager gathers food
while animals compete for the same resources. The earlier single-clearing
prototype uses a hunger clock; the current exploration scene has no time limit.

## The hard constraint

**Oravitsa never injures a creature, and hares are the only ones she kills.**
Unchecked, hares would multiply out of control. A hare that is currently stunned
and within 75 px can be collected, which removes it once and yields one raw
meat; no other species can be killed or collected. Her other interactions with
creatures are non-lethal influences such as shooing, attracting, confusing, or
slowing. The sling temporarily stuns a selected animal;
it does not injure or kill it.
Shoo is also targeted: it interrupts the selected animal and sends it running
away from Oravitsa for five seconds, with a visible scared countdown. Other
animals are unaffected, and invalid targets do not consume cooldown.

- Animal predation is separate from player abilities: wolves and lynxes can kill hares
  and deer. Hares are caught quickly; deer require three seconds of continuous
  close pursuit. Losing contact or interrupting the predator resets that progress.
  Both prey species return away from the player; hares replenish frequently.
  Wolves/lynxes despawn after 180 seconds without a catch, including offscreen.
- No player damage, health, or hit-point combat system.
- Competition for resources is the conflict. An animal reaching a mushroom
  first wins that exchange.
- Influence abilities change movement or attention without lasting injury.

## Wildlife abundance

Hares are frequent, deer and foxes are less common, boars are less common
again. The endless world deliberately has more wolves and lynxes than the
retained finite scenes. Replenishment respects per-species chances, offscreen
entry and bounded local populations. The current tuning is documented in
`scenes/endless_woods/README.md`; finite-scene tuning remains in the older guides.

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
