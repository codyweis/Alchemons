# New family (concept)

`concept_sheet.jpg` is the 17-creature concept card, three rows on a flat grey
card: Lightning, Mud, Ice, Dust, Crystal, Plant / Fire, Water, Earth, Air,
Steam, Lava / Poison, Spirit, Dark, Light, Blood.

`lightning*` is the first one, cut out and given an idle:

- `lightning.png` -- the 512x512 still
- `lightning_spritesheet.png` -- 4 frames of 512x512 in a row; in
  `alchemons_creatures.json` that is
  `"spriteData": {"frameWidth": 512, "frameHeight": 512, "totalFrames": 4, "frameDurationMs": 120}`
- `lightning_preview.gif` -- the loop on the grey card, for looking at

The idle is a breath anchored at the feet with the bolts, chest mark, tail
spikes and tail orb glowing up and back down. Rebuild it with:

    python tool/creature_idle_sheet.py art_sources/creatures/new_family/concept_sheet.jpg \
        --crop 80,20,660,660 --out art_sources/creatures/new_family/lightning

Not wired into the game yet: it needs the family's name and species id, after
which the still and sheet move to `assets/images/creatures/<rarity>/` under
the usual `XXX07_lightning<family>.png` names.
