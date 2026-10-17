# Oravitsa: one-credit-conscious Tripo trial

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
