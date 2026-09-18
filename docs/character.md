# Oravitsa — canonical character reference

Text summary of the design sheets in `character-drafts/`. **This document is
the canonical source, not the images.** Where a sheet and this file disagree,
this file wins.

The sheets are reference only. They are never imported into the project:
`character-drafts/.gdignore` keeps the Godot editor out of that folder, and
nothing under `res://` points at it.

---

## Vitals

From the model sheet's own header block (`oravitsa_2.png`):

| | |
|---|---|
| Age | 12 |
| Build | Small / light |
| Role | Forager |
| Region | Nordic (summer) |
| Height | **150 cm** (canonical — see below) |

## Canonical figure: 150 cm

**Oravitsa is 150 cm tall.** This is the number every asset is modelled to.

The sheets disagreed — the brief records an earlier draft carrying a 145 cm
guide — and only one value can be canonical, because it sets world scale for
the entire project. 150 cm is chosen.

Of the sheets actually present in this repo, **only 150 cm appears**, on the
turnaround's guide line. No surviving sheet shows 145 cm, so nothing here
contradicts the choice.

Consequences, already applied:

- `resources/default_stats.tres` sets `height = 1.5`
- The player capsule in `scenes/oravitsa.tscn` is 1.5 m tall, 0.28 m radius
- World scale is **1 Godot unit = 1 metre** (stated in `README.md`)

Changing this number later means re-scaling every asset made against it, so
treat it as frozen.

---

## Draft status

| Sheet | Contents | Status |
|---|---|---|
| `oravitsa_1.png` | Turnaround: front, three-quarter, side, back. 150 cm guide line. | **Canonical** |
| `oravitsa_2.png` | **Master model sheet.** Four-view turnaround, vitals block, the named palette, bandana pattern detail, four facial expressions, eye and braid-bead details, bandana rear view, accessory studies (basket, belt, boot), example foraged plants, three pose references. | **Canonical — the primary sheet** |
| `oravitsa_3.png` | Hair studies: loose and braided, four angles each, head-shape guide, hairline and braid detail. | **Canonical** (hair only) |
| `oravitsa_4.png` | Top-down view — the angle the game is actually played at. Bandana pattern, basket contents. | **Canonical** |

`oravitsa_2.png` is the richest of the four and is where the named palette and
the vitals come from. When two sheets disagree on a detail, prefer it.

### Superseded: the red hood

Earlier drafts showed Oravitsa in a **red hood. That design is DROPPED.** It is
not canonical, it should not be referenced, and it should not reappear in any
later asset. The current design is the **summer version** described below.

**No sheet in this repo shows the red hood.** All four are the summer version,
and the model sheet states "Region: Nordic (Summer)" outright. The drop is
recorded here because the project brief records it, not because there is a
draft still lying around to be mistaken for current — those drafts are simply
not in this folder.

### Note on `oravitsa_2.png`

For a while this file was zero bytes, both on disk and in git — it was read
while the copy into the folder was still in flight. The complete 1.3 MB image
is now committed, and everything above was read from it.

Noted only so that an early-session reference to an "empty `oravitsa_2.png`"
is not mistaken for a missing sheet.

---

## Palette

### The named palette (canonical)

The model sheet carries its own labelled swatch strip. **These six are the
canonical palette** — the designer's stated colours, not an interpretation.
Values sampled from the swatches themselves. Hex is sRGB.

| Name | Hex | Godot `Color` | Used for |
|---|---|---|---|
| Bandana Blue | `#374660` | `0.216, 0.275, 0.376` | Bandana ground and tails |
| Golden Yellow | `#D1A54B` | `0.820, 0.647, 0.294` | Bandana motif |
| Oatmeal Linen | `#CDC4B8` | `0.804, 0.769, 0.722` | Tunic |
| Birch Grey | `#998E83` | `0.600, 0.557, 0.514` | Wool socks, neutral accents |
| Moss Green | `#565948` | `0.337, 0.349, 0.282` | Skirt |
| Dark Leather | `#463A3A` | `0.275, 0.227, 0.227` | Belt, pouch, boots, basket straps |

The greybox in `scenes/` uses Bandana Blue, Golden Yellow and Oatmeal Linen
directly, so the prototype reads as the right character at the right scale
even with no model.

### As actually drawn

The figure is rendered lighter and warmer than the flat swatches, because it
is lit. These are dominant-colour samples off the rendered figure — useful for
matching a shader or a stylised material, not a substitute for the six above.

| Element | Lit | Shadow |
|---|---|---|
| Tunic | `#DECFBF` | `#B4A08D` |
| Skirt | `#5E5C47` | `#43402F` |
| Leather | `#4B3A2D` | — |
| Boots | `#624939` | `#392A1E` |
| Bandana | `#334762` | — |
| Bandana motif | `#E0A32D` | — |

### Not in the named palette

Sampled only; the sheet does not name them.

| Element | Hex | Godot `Color` | Notes |
|---|---|---|---|
| Hair (ash blonde) | `#C4AC97` | `0.769, 0.675, 0.592` | Shadow `#7F6856`. |
| Skin | `#ECCCB4` | `0.925, 0.800, 0.706` | |
| Eyes | `#6C7C8C` | `0.424, 0.486, 0.549` | Muted steel blue, darker limbal ring. From the sheet's large eye-detail panel. |
| Braid beads (amber) | `#B56821` | `0.710, 0.408, 0.129` | Shadow `#894A16`. Two beads, one per braid. |
| Basket wicker | `#7A5E46` | `0.478, 0.369, 0.275` | Shadow `#593F29`. |

### Reading from above

The game is played from a fixed isometric camera, so **the top-down sheet
(`oravitsa_4.png`) is the important one.** From that angle the visible
silhouette is, by area: the blue bandana, the wicker basket rim behind the
head, the oatmeal shoulders, the moss skirt.

The blue-on-yellow bandana is effectively the character's icon — it is what a
player tracks across a forest floor. No other prop should use that colour
pair.

---

## Garments and props

Top to bottom:

- **Bandana** — deep blue, tied at the back of the head, two long tails falling
  past the shoulders. A band of yellow eight-point stars and lozenges runs
  along the front hem and repeats down the tails. Covers the crown; hair shows
  at the temples and fully below.
- **Hair** — ash blonde, wavy, past shoulder length. Two braids, one at each
  temple, drawn forward over the shoulders, each finished with a single amber
  bead. `oravitsa_3.png` also documents a loose, unbraided variant; the
  turnaround and the top-down both show braids, so **braided is canonical.**
- **Tunic** — oatmeal linen, hip length, loose. Sleeves rolled to just below the
  elbow. Small laced keyhole neckline. Falls in a soft flare over the skirt.
- **Belt** — wide dark leather at the natural waist, square brass buckle, long
  tongue hanging on the left. A small rectangular pouch on the right hip, and a
  second strap hanging down the front-left.
- **Skirt** — moss green, gathered, mid-calf, heavy enough to hold a bell shape
  rather than cling.
- **Socks** — thick Birch Grey wool, turned down over the boot tops.
- **Boots** — brown leather, ankle height, front-laced, flat soled.
- **Basket** — wicker, worn on the back on two dark leather shoulder straps.
  Open-topped; the top-down sheet shows it holding greens and small white
  flowers. This is the container the foraging loop fills.

No weapon, no tool, no blade appears anywhere, in any sheet. That is
deliberate, and it matches the design constraint: Oravitsa has no attacks, and
nothing in this game may damage or kill a creature. **She should never be
drawn, modelled or rigged holding anything that reads as a weapon.**

### Also documented on the master sheet

Not needed for iteration 1, but recorded so nobody re-derives it later:

- **Four facial expressions** — soft smile (neutral/default), open laugh,
  worried, eyes-closed grin. No angry or pained expression exists on any sheet,
  which is consistent with the design constraint.
- **Bandana pattern detail** — an enlarged swatch of the band: eight-point
  stars alternating with stacked lozenges, Golden Yellow on Bandana Blue.
- **Bandana rear view** — how the knot and the two tails sit at the back.
- **Accessory studies** — the basket, the belt with its pouch and hanging
  strap, and a single boot, each drawn in isolation at larger scale. Use these
  for modelling rather than cropping the turnaround.
- **Example foraged plants** — small white umbel flowers, ferns, and
  blueberries on the branch. This is the visual vocabulary for gatherables,
  and it is where the mushroom greybox should eventually lead.
- **Three pose references** — standing with a bundle of greens, walking with
  the basket loaded, and crouching to gather. The crouch is the foraging pose.

---

## Proportions

Measured off the front turnaround, calibrated against its own 150 cm guide
line (4.767 px/cm at the sheet's native 1344×896).

| Landmark | Height |
|---|---|
| Top of bandana | 150 cm |
| Eye line | 133 cm |
| Chin | 123 cm |
| Basket rim | ~116 cm |
| Shoulder line | 114 cm |
| Belt / natural waist | 91 cm |
| Basket base | ~81 cm |
| Fingertip, arms at rest | 68 cm |
| Skirt hem | 28 cm |
| Boot top | 19 cm |

| Dimension | Size |
|---|---|
| Shoulder width | 34 cm |
| Head width (incl. hair) | 27 cm |
| Head height (chin to crown) | 27 cm |
| Skirt hem width | 37 cm |
| Basket height | ~34 cm |

**≈5.6 heads tall** — a stylised young-teen build, not a realistic adult's 7.5.
Slight frame, narrow shoulders, no exaggeration at hip or bust.

The basket figures are marked approximate: in the back view the bandana tails
hang across the basket and occlude its upper edge, so its extents were read
off the side-view silhouette instead.

---

## Silhouette

What identifies her at gameplay distance, in priority order:

1. **The two trailing bandana tails** — the only long, loose, moving element on
   the character, and so the best motion cue at any distance.
2. **The basket's hard rim above the shoulders** — a straight horizontal edge
   above a soft body. Nothing else on her reads as straight.
3. **A bell-shaped skirt under a narrow torso** — a clear triangle, widest at
   the hem, that stays legible from directly overhead.
4. **Two forward-hanging braids** breaking the chest line symmetrically.
5. **Blue-and-yellow against oatmeal and moss** — the only saturated colour
   pair on the character.

A greybox capsule keeps only (3). When the real model arrives, the tails, the
basket rim and the braids are what must survive stylisation — they are the
silhouette, not decoration.
