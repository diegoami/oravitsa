# Oravitsa: one-credit-conscious Tripo trial

## Current API trial — 24 October 2026

The current provider is **fal.ai**, using prepaid fal credits and endpoint
`tripo3d/h3.1/image-to-3d`. The first stage is one H3.1 reconstruction with
standard texture, listed at $0.30. Rigging and animation are later decisions. Do not
repeat the rejected procedural 3D model or the old H2.5 Studio attempt.

The reference for this trial is **the current painted in-game character**,
not the historical reference crop described below. Prepare a single unchanged
southeast figure on a neutral background with:

```powershell
godot --headless --path . --script art/prepare_tripo_reference.gd
python art/fal_tripo_trial.py
```

The default runner only writes an offline plan in `build/fal-tripo-trial/plan.json`.
Configure the API key locally with `art/Set-FalApiKey.ps1`; input is masked and
stored in the Windows user environment. The Python runner reads it without
printing it or requiring a Codex restart. Never paste the key into chat.

`--submit` sends the reference, submits one reconstruction, saves the fal request
ID, then polls and downloads the GLB. It does not retry generation automatically.
`--resume` only resumes polling and downloading the saved request. An ambiguous
submission response blocks a new paid request until task history is reconciled.
Inspect the likeness in static renders before rigging or replacing game assets.

On Windows, CDN downloads use the native HTTPS client with certificate
verification enabled. `art/review_3d_candidate.py` imports the downloaded GLB,
normalizes its height, and renders eight static angles with the generated
base-color textures. It does not modify the game model or rig the candidate.

The separate `art/tripo_trial.py` runner targets Tripo's direct API and requires
`TRIPO_API_KEY` and a separate Tripo API balance. It is not used for the fal trial.

Pricing: <https://fal.ai/models/tripo3d/h3.1/image-to-3d>.

### Animation trial

The user approved the reconstruction and a Meshy rigging call through the same
fal account. `art/prepare_rig_input.py` preserves the generated texture, reduces
the mesh from 1,420,280 to 199,999 triangles, normalizes height to 1.5 m and aligns
its front to glTF +Z. The original reconstruction remains unchanged.

`art/fal_walk_job.py --submit` uses `fal-ai/meshy/rigging` with
`enable_animation=false`: the documented $0.20 rigging operation includes a basic
walking clip, so no extra animation preset is purchased. The result has 24 bones
and a roughly 1.033-second walk. First/end joint positions match within about one
micrometer after root travel; its motion is already essentially in place.

`art/render_imported_walk.py` samples eight poses per direction at consistent
phase, retaining the generated base-color texture and the provider's original
skin weights. `art/package_imported_walk.gd` creates eight PNG atlases and checks
all 64 frames for alpha, uniqueness within each direction and clipped borders.
`art/preview_imported_walk.gd` checks Godot playback and phase-preserving turns.

The result is a **review export**, not an approved replacement for the game art:
automatic weights visibly deform the skirt and boots in some poses. Local
garment/IK corrections were rejected and are not part of the active export.
Do not confuse successful loop/export tests with visual approval. The review
viewer is `art/imported_walk_review.html`; artifacts live in `build/fal-walk/`.

Rigging source and pricing: <https://fal.ai/models/fal-ai/meshy/rigging/api> and
<https://fal.ai/models/fal-ai/meshy/rigging>.

### Footwear repair

The user's Windows screenshot exposed a boot that flattened during animation,
plus the 2x viewer layout could cut off the silhouette below its fixed origin.
The current export uses `--foot-skinning matched` by default. It extracts the
intact right boot with its original UVs, creates an anatomically mirrored pair,
and bakes rigid transforms following the deformed sock collars. The face and
upper costume are unchanged. Original Tripo/Meshy downloads remain untouched.

The second exported pose exposed a separate orientation error: a toe-down
ankle-to-toe vector crosses vertical, reversing its horizontal projection.
Reading that projection as yaw turned the rear shoe backward after pitch was
limited. The correction keeps yaw in the forward hemisphere, limits it to
15 degrees, and fades yaw near vertical. Both half-cycles use this correction.

`art/validate_matched_boots.py` checks both real shoe meshes through 65 poses:
their shape stays constant, the mirrored shapes match and the loop closes.
It also checks forward headings, successive heading changes and heading closure.

`art/test_walk_layout.mjs` executes the actual review draw function against
measured opaque bounds at both zoom sizes, checking all 64 new frames plus the
painted reference frames. Layout reserves a margin around the full silhouette
and grows the inspection canvas rather than clipping the feet.

### Skirt coverage repair

Poses 4 and 5 exposed the upper right thigh because the automatic garment
weights lifted the skirt with the leg. A pelvis-weight-only test stretched
seams and was rejected. `art/skirt_drape.py` instead adds a fitted continuous
surface over the original skirt. It samples the original olive fabric texture,
tucks its upper edge beneath the tunic, and expands cloth rings around the
moving thighs. The source body, face, rig, walk, and repaired boots are retained.
The original downloads and a copy of the accepted shoe-only export are kept.

This is a local fitted garment correction, not a cloth simulation or a new AI
generation. It is enabled by default; `--no-skirt-repair` exports the previous
garment. The corrected Blender scene includes baked drape shape keys and
transforms. `art/validate_skirt_drape.py` checks all 65 poses for side holes,
height loss, abrupt vertex motion, stretched edges, and loop mismatch. The
64-frame Godot export and preview framing checks still apply. No additional
provider calls or credits are needed. The result remains a review export.

### Left-hand clearance

In southwest, west, and northwest views, poses 1 and 2 hid part of the left
hand inside the skirt. `art/arm_clearance.py` adds 8 degrees of outward rotation
at the left upper arm throughout the walk, preserving the source elbow and
wrist motion. The corrected arm rotation is baked into a copied action; the
source action remains available. `--no-arm-clearance` disables this adjustment.
The previously accepted skirt export is saved under
`build/fal-walk/accepted-skirt-before-arm`.

`art/validate_arm_clearance.py` checks segment lengths and loop closure through
65 poses, and casts rays against the actual baked skirt to check the weighted
left-hand vertices for penetration in poses 1 and 2. The shoe, skirt, Godot
export, and viewer layout checks are also run. This is a local rig correction
with no provider calls, and remains a review export.

### Game integration (25 October 2026)

The accepted shoe, skirt, and arm revision is installed in the default forest
scene as eight atlases and `scenes/forest_2d/art/oravitsa/walk.tres`. The reusable
SpriteFrames resource contains all 64 frames plus the measured foot pivot,
scale, and source cycle duration. Runtime gait follows actual travelled distance,
preserves phase through direction changes and pauses, and uses a grounded idle
pose when stopped, stunned, or blocked. Westward directions are distinct views.
The previous painted strips remain for the earlier prototype and comparison.
`art/install_approved_walk.py` installs a validated local render and records its
hashes and repairs in the adjacent provenance file. The raw provider GLB is not
the corrected game character; local Blender corrections remain in the baked
scene used to render the approved sprites.

## Historical trial

> Historical 3D experiment. No Tripo-generated model is used by the current 2D game on main.


This is an experiment, not a replacement for the canonical design or the current game model. The source of truth remains `docs/character.md`. No Tripo GLB has been imported into this project. The image upload API has been tested successfully.

**Studio outcome (reported by the user):** An H2.5 character result was generated in Tripo Studio and judged unsatisfactory. Studio also presented an upgrade requirement at export. Do not spend more credits retrying H2.5 merely to export it.

## Reference to upload

Use **`character-drafts/tripo_oravitsa_input.png`**, an exact 320×745 crop (x=370–690, y=55–800) of the second, full-body three-quarter figure in `character-drafts/oravitsa_1.png`. It preserves the headscarf, both hands, both boots, and back basket. Do not upload the entire four-character sheet or the collage in `oravitsa_2.png`: Tripo may merge the figures and accessory studies. Do not use `oravitsa_4.png` as the model input; its steep overhead angle is for evaluating the output in the game camera.

The original sheets stay unchanged and remain outside Godot imports. The crop is in the already `.gdignore`d `character-drafts/` directory. At 234 KB it needs no file-size compression; isolating one figure is the useful preparation.

## Compact prompt

> Single full-body stylized 3D game character, relaxed A-pose: Oravitsa, a slight 12-year-old Nordic summer forager, about 5.6 heads tall. Ash-blonde hair in two forward braids with amber beads. Deep blue headscarf with gold star border, tied behind the head with two long separate tails. Loose oatmeal tunic, moss-green bell skirt, dark leather belt and pouch, grey socks, brown ankle boots. Open wicker back basket with visible rim and greens. Gentle expression, clean silhouette, separate limbs. No red hood, weapon, or extra props.

This is **533 characters**. Tripo's `image_to_model` API request does **not** have a text prompt field, so the API uses the cropped image alone. If Studio offers a text box alongside image input, paste this there. Otherwise use it as the acceptance checklist. Do not spend credits generating another image just to include this text.

## Tested API route

The existing Blender add-on key also works with the API while Blender is closed. From the neighboring `test_tripo` repository, run `python oravitsa_trial.py` to inspect the request and wallet; `python oravitsa_trial.py --upload-only` uploads the crop without creating a model task. Both were tested on 17 October 2026: wallet `0`, image upload accepted, no model generated. The script can read the add-on's locally stored key without printing or committing it.

One `v3.1-20260211` image-to-model task with standard texture is listed at **30 API credits**. The script checks for at least 30 available credits before upload or task creation. After adding API credits, run `python oravitsa_trial.py --submit` once. This is an alternative to Studio; its credits are separate from Studio's free monthly credits. The API run is intended as a single candidate, not an automatic variation loop.

## Credit-conscious run

1. For **existing free credits**, use Tripo Studio. For a scripted generation, add at least 30 credits to the separate API wallet and use the tested API route above.
2. Choose **Image to 3D → HD Model/H2.5** if that option is available on the free plan. Upload the one cropped figure. Check the credit charge shown in Studio before generating. Run **one** base model.
3. Do not spend credits on Tripo image generation, multi-view generation, Smart Mesh, rigging, refining, extra texture quality, or variations yet. The free plan's published export allowance is limited to H2.5; multi-view and the one-click DCC Bridge are listed under paid plans.
4. Inspect the front, side, back, and a steep overhead angle. Judge the geometry without texture as well as with it. Stop if the two scarf tails, forward braids, open basket rim, and bell skirt are fused or missing. Record the result and decide on a **single targeted** second attempt only if there is a plausible correction.
5. If the model passes, export a GLB and bring it into Blender. Compare it at **1.5 m** height against `docs/oravitsa_blockout.glb`; keep 1 Blender/Godot unit = 1 m and let glTF handle the axis conversion. Test it in the game's fixed isometric camera at about 160 px height before considering rigging or replacing `models/oravitsa.glb`.

The existing procedural model remains the game asset until a Tripo candidate passes that visual and scale check. Tripo output may be best used as a sculpting or texture reference if its topology cannot deform cleanly around the skirt, braids, and scarf tails.

## Sources

- Project: `docs/character.md`, `docs/art-pipeline.md`, and `character-drafts/oravitsa_1.png` through `_4.png`.
- [Tripo Studio pricing and free-plan limits](https://www.tripo3d.ai/pricing)
- [Tripo on single and multi-view inputs](https://www.tripo3d.ai/help/features/how-to-use-multi-view-input-effectively)
- [Tripo API and Studio credits are separate](https://platform.tripo3d.ai/docs/faq)
- [Tripo API prompt schema](https://platform.tripo3d.ai/docs/schema)
- [Tripo API upload](https://platform.tripo3d.ai/docs/upload)
- [Tripo API pricing](https://platform.tripo3d.ai/docs/billing)
