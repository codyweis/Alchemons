# New family (concept)

`concept_sheet.jpg` is the 17-creature concept card, three rows on a flat grey
card: Lightning, Mud, Ice, Dust, Crystal, Plant / Fire, Water, Earth, Air,
Steam, Lava / Poison, Spirit, Dark, Light, Blood.

Each one is cut off the card and given an idle, as three files:

- `<element>.png` -- the 512x512 still
- `<element>_spritesheet.png` -- 4 frames of 512x512 in a row; in
  `alchemons_creatures.json` that is
  `"spriteData": {"frameWidth": 512, "frameHeight": 512, "totalFrames": 4, "frameDurationMs": 120}`
- `<element>_preview.gif` -- the loop on the grey card, for looking at

All seventeen use one scale, so the family keeps the sizes it has on the
card, and stand with their feet 38px off the frame's bottom like the Lets.
Every motion runs one full cycle in the four frames, so the loop has no seam.

| Element | Idle |
| --- | --- |
| Lightning | Bolts glow; arcs crackle off the bolt tips and the tail orb |
| Mud | A squishy breath; bubbles blorp on the cap; drips from the chin and the cap |
| Ice | A cold glow; glints wink on the cube corners; snow drifts down |
| Dust | The top curl sways; grains and puffs blow off the head |
| Crystal | Crystals glow violet; glints wink on their tips |
| Plant | Head leaves sway; pollen rises; a leaf falls |
| Fire | Flames flicker and glow; embers rise off the head and tail |
| Water | Light ripples through the body; the fins sway; bubbles rise |
| Earth | A heavy breath; its stones float; gravel crumbles; dust kicks at the feet |
| Air | Floats and flaps its cloud wings; wind sweeps past |
| Steam | The cloud ring sways; steam puffs drift off it |
| Lava | The cracks and eyes glow; embers rise off the peaks |
| Poison | Spike tips glow; toxic bubbles rise; it drools |
| Spirit | Floats, flickering translucent; its wisps sway; the eyes glow |
| Dark | Shadow flames lick up behind it; hair and tail sway; the collar glows |
| Light | Sun rays turn behind it; it glows; sparkles wink on the spikes |
| Blood | A lub-dub heartbeat with a red aura and gloss; a drop falls from the claw |

Rebuild any of them (NumPy + SciPy + Pillow), from the repository root:

    python tool/creature_idle_sheet.py               # all seventeen
    python tool/creature_idle_sheet.py fire water    # just these

Where each creature stands on the card and how it idles live in that script's
`CREATURES` table and the function named for each element.

Not wired into the game yet: it needs the family's name, code and rarity,
after which each still and sheet moves to `assets/images/creatures/<rarity>/`
under the usual `XXXnn_<element><family>.png` names.
