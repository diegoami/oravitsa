# Oravitsa — design

> **Stub.** Placeholder for the real design document. Only the parts that
> already constrain code are written down; everything else is deliberately
> left blank rather than invented.

## Premise

A cozy isometric 3D game. Oravitsa is a forager in a Nordic forest. She
gathers food against a hunger clock. Animals compete with her for the same
resources.

## The hard constraint

She has no attacks. Her only interactions with creatures are **non-harmful
influence spells** — scare, attract, confuse, slow.

**Nothing in this game may ever damage or kill a creature.** This is not a
difficulty setting or a pacifist route. It is the premise, and it applies to
the player, to animals, and to anything added later.

Practically, for anyone writing code here:

- No health, damage, hitpoints or death on any creature.
- No `hurt()`, `take_damage()`, `die()` — not even unused, not even "for
  later". If a method like that exists, someone will eventually call it.
- Competition for resources is the conflict. An animal that reaches a
  mushroom first has won that exchange. That is the whole of it.
- Influence spells change what a creature *wants* — where it moves, how fast,
  what it is drawn to. They never change its condition.

## Scale

**1 Godot unit = 1 metre.** Oravitsa is 150 cm, so 1.5 units. See
`character.md` for the full figure and how that number was settled.

## Not yet designed

Hunger clock, animal behaviour, the influence spells, biomes, day cycle,
progression, save format, audio. None of it is decided; none of it belongs in
iteration 1.
