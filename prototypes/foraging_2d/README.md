# Oravitsa 2D foraging experiment

Run the Oravitsa project with Godot 4.7 and press F5 on the
`prototype/2d-foraging` branch. The branch's main scene is
`prototypes/foraging_2d/game.tscn`; the earlier 3D scenes remain in `scenes/`.

WASD or arrow keys move. Walk close to mushrooms to collect them. Fill the
basket with 9 patches before the 90-second hunger clock runs out while a boar
forages for the same food. When the boar is nearby, Space shoos it away briefly
without harming it; that ability has a cooldown. Deer roam and give the player
space. Press R after a round to try another route.

This is a one-screen test, not a finished game. The clearing and every visible
world element are generated raster illustrations; there are no code-drawn
placeholder characters or procedural trees. Patch locations and animal
waypoints are fixed to make routes comparable between attempts. The two
Oravitsa strips show toward/away three-quarter views; left-facing movement
mirrors a strip. Directional and animation coverage remains limited. The
animals' frames are short generated walks and still need an artist's cleanup
pass for final production.

Art source: built-in image generation using `character-drafts/oravitsa_4.png`
and `oravitsa_1.png` as Oravitsa identity references. The approved forest
background served as style reference for the animal sprites. Art is stored in
`art/` and imported by Godot directly. No Tripo, fal, or OpenRouter call was
made for these prototype assets.
