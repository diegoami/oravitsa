# Oravitsa walk cleanup trial — 2026-10-18

This is a rejected, non-destructive art experiment. The game still uses
`prototypes/foraging_2d/art/oravitsa_walk_toward.png`. These images are kept
with the verbatim prompts so the result can be reviewed and the experiment
does not become another undocumented generation step.

Tool: the assistant's `image_gen.imagegen` tool. Its underlying model ID and
HTTP endpoint were not exposed. Edit target: the existing four-frame
`oravitsa_walk_toward.png` sprite strip. Krita was not used in this trial.

## Trial 1

[Generated image](oravitsa-walk-toward-trial-1.png)

Prompt (verbatim):

```text
Use case: precise-object-edit. Edit target: the supplied four-frame transparent sprite sheet for the 2D Godot game Oravitsa. Keep the exact horizontal four-panel sheet structure, frame spacing, transparent background, painterly illustration style, three-quarter camera, figure size, dark blue gold-patterned headscarf, pale braids with amber beads, cream tunic, green skirt, boots, and wicker basket. Improve only the walking animation: give the four frames distinct, coherent alternating leg and arm positions, keep the head/face/scarf/basket identical in design and scale, keep the feet aligned to a consistent ground line in every panel, and clean stray colored pixels around each silhouette. The sprite must remain full-body and uncropped, four equally wide frames, one Oravitsa per frame. No labels, text, borders, scenery, shadows, extra figures, or new accessories.
```

The step positions vary more clearly than in the current sheet, but colored
fringes remain around the silhouettes and the character details still vary
between frames. This is not a finished cleanup.

## Trial 2

[Generated image](oravitsa-walk-toward-trial-2.png)

Prompt (verbatim):

```text
Edit the supplied Oravitsa four-frame transparent walk sprite strip. Preserve the four equal horizontal cells, identical character identity and painterly style, transparent background, full body and aligned feet. Improve the walk cycle so legs and arms alternate clearly while scarf, braids, face, outfit and basket remain consistent. No text or scenery.
```

This version also varies the steps but does not solve the fringe or
consistency issues. Neither trial was imported into the game or used to
replace the committed sprite. The next useful test is a manual, frame-by-frame
pass in Krita on a copy of the original strip, followed by an in-game preview
at the actual sprite size. That pass has not been done.
