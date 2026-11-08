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
| Mud | A squishy breath; the cap's wet shine; drips from the chin and the cap |
| Ice | A slow breath; a cold glow off the cubes |
| Dust | A breath; the curl on top sways |
| Crystal | Crystals glow violet |
| Plant | A breath; the leaves on its head sway |
| Fire | Flames flicker and glow; embers rise off the head and tail |
| Water | A breath; the fins sway |
| Earth | A heavy breath; its stones float off it; the eyes smoulder |
| Air | Floats and flaps its cloud wings |
| Steam | Its cloud ring swells with the breath and churns; wisps curl up off its sides |
| Lava | The cracks and eyes glow; embers rise off the peaks |
| Poison | Spike tips and eyes glow; it drools |
| Spirit | Floats, flickering translucent; its wisps sway; the eyes glow |
| Dark | Shadow flames lick up behind it; hair and tail sway; the collar glows |
| Light | A breath; its sun crest glows |
| Blood | A lub-dub heartbeat with a red aura and gloss; a drop falls from the claw |

No sparkles and no floating decoration: the only things that leave a body
are what its element really throws off -- lightning's arcs, a flame's
embers, a drip.

Rebuild any of them (NumPy + SciPy + Pillow), from the repository root:

    python tool/creature_idle_sheet.py               # all seventeen
    python tool/creature_idle_sheet.py fire water    # just these

Where each creature stands on the card and how it idles live in that script's
`CREATURES` table and the function named for each element.

Not wired into the game yet: it needs the family's name, code and rarity,
after which each still and sheet moves to `assets/images/creatures/<rarity>/`
under the usual `XXXnn_<element><family>.png` names.
