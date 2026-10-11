# Ability VFX: final eye-check (2026-10-10)

The visual QA pass after the rebuild. I read every sheet at 1:1 (`AUDIT_SCALE=1`,
new in this pass), family by family, at all three stat bands and all three moments,
against the `_hitarea` sheets, and fixed whatever didn't read or broke the art rules.
Gameplay radii, damage and logic were not touched. The art reads the radii.

## Files

| File | What it is |
|---|---|
| `<family>_specials.png`, `<family>_hitarea.png`, `basics.png`, `data.json` | The full audit (`test/ability_vfx_audit_preview_test.dart`), at default player quality (`balanced`), 0.64 scale |
| `mystic_cast_overlay.png` | All 17 Mystic cast overlays, 5 moments (0.05 / 0.14 / 0.29 / 0.48 / 0.77 s), grain sprite awaited |
| `let_aftermath_preview.png` | Let craters, aftermath beats and zones (Lightning chain on `vfxArcInto`) |

The PNGs are palette-quantized to 256 colours, like earlier phases. Regenerate:

```
AUDIT_OUT=<dir> [AUDIT_SCALE=1] [AUDIT_FAMILIES=horn,…] \
  flutter test test/ability_vfx_audit_preview_test.dart --tags preview
MYSTIC_OVERLAY_OUT=<dir> flutter test test/mystic_graphx_overlay_test.dart
LET_AFTER_OUT=<dir> flutter test test/let_aftermath_preview_test.dart --tags preview
```

## Per-family verdict (one line per special)

**Horn**: bulky tank. Slam front is now billows plus a frayed line of flaring grains, not a crescent sickle.
- Fire: burning lane with flame tongues; taunt patches along it.
- Lava: slow ram, heat build-up, molten kill-blast seekers.
- Lightning: dash, then a brewing storm cloud on the body with crawling arcs; chain discharge.
- Water: circular sweep, whirlpool at the centre (sized to its pull).
- Ice: sideways wall of ice blocks segment by segment.
- Steam: geyser at impact (vapour plume).
- Earth: decoy cairn with quake pulses.
- Mud: passive sludge trail.
- Dust: cyclone pulling inward.
- Crystal: wind-up stones are now lit crystal (they were dark holes on black).
- Air: passive outward wind grains.
- Plant: root wrap on hit bodies is two vines climbing in over the body, thorns lying back. It was a dashed green hoop of 18 fills; now 4.
- Poison: miasma banks over the aura radius.
- Spirit: phantom wind-up, wisps released.
- Dark: NEW 5 s wind-up: the void gathers out to the real pull radius (darkened ground, grains drawn in, black heart, accretion arms). Before, the whole 5 s showed nothing.
- Light: lit glass bubble at the real reflect radius. Its three rotating rim dashes became one drifting sheen.
- Blood: sacrifice and siphon.

**Wing**: beams, all in material at default quality.
- Plant: the vine has a body and a lit side; it was a dark wire across the beam.
- Air: pressure fronts are soft deep swells, not thin bright ticks.
- Fire/Poison: flame field and fog bank fill the hit disc.
- Lightning: charge, then one blast.
- Crystal/Light/Water: lit lances (Light refracts).
- The others (Earth, Mud, Dust, Dark, Blood, Ice, Steam, Spirit) read as their material.

**Let**: a skyfall, then a crater, then a zone.
- Bowl: gained a lit inner wall, so it reads as dug.
- Ejecta: goes out before it thins to a hairline.
- Throws and rims: every even-wheel throw, crown, lip-frost and crystal rim moved to golden-angle bearings with uneven reach (no starbursts).
- Lava: ground is a crazed crust of short molten cracks (it was 8 radial forked seams, a spider of hairlines).
- Earth: rubble cracks the same way (they were 6 radial fissures).
- Lightning: crater has charge arcs crawling inside the bowl (they were radiating forks re-rolled at 9 Hz).
- Dark: halo is a wide band of bent light, not a ring.
- Plant: vine rises as a plant, not an X of 4 arms.
- Air: gust is golden-angle puffs and grains (it was 13 evenly spaced drops).
- Fire: second blast throws flame on uneven bearings with grain embers (it was a 12 + 8-point star).
- Lightning chain: wider.

**Pip**: darts with bounce notches.
- Lightning: trail is one material arc (two bright arcs per dart read as a fan of white hairlines across the volley).
- Steam: NEW shared `drawPipSteamCloud` (survival and open space). Puffs roll up off the flanks and grow with the attack-speed ramp; it was invisible.
- The others: darts and kill/hit pieces as before (Fire pools, Dust clouds, Crystal beacon, Poison line, Mud trails).

**Mane**: piercing pieces sized from the hit.
- Lightning: slash arcs run along travel (they crossed into an X). The field is two edge-to-edge discharges, not an asterisk.
- Water: wave crests are broad foam, not ruled hairlines.
- Dark: void now shows its pull: faint bent light out to the snare, flecks drawn in from that rim (art stopped at ~0.45 of the pull).
- The rest (Lava, Ice, Steam, Earth, Dust, Crystal, Poison, Blood, Plant, Spirit, Light, Air, Mud, Fire) read as before.

**Mask**: scattered traps.
- Plant: tendrils are filled tapering ribbons in 3 shared paths. They were 3 stroked polylines each plus 2 hard flash discs; the flash is now a soft pool.
- Plant rootstock: 5 bent roots, not a 9-spoke star.
- Steam: vents have a dark mouth with a lit lip (it was a pale chevron).
- Air: hollows have deep soft lips (they were thin arcs, ×21 traps).
- Fire, Lava, Water, Poison, Earth, Mud, Crystal, Ice, Lightning, Dark, Blood: unchanged and good.

**Kin**: rare support.
- Crystal: refract counter-shot is now a fuller beam in Crystal's tone with glint grains running down it (it was a thin cream wire at cast start). Escorts are lit crystal, not dark holes.
- Kin laser: slim but never a wire (min body ~4 px).
- Ice: charge is frost condensing (curving grains and a growing ice crust). It was a wheel of 7 inward shards turning round the body.
- Steam: boiler puffs rise; they were thrown out at the four quarters, a cross.
- Air: updraft fills its effect radius with a winding swirl (it covered ~0.6 of it).
- The others (Water cloud, Earth wall, Mud, Dust banks, Plant garden, Poison darts, Spirit wisp, Light lanterns, Dark veil, Blood threads, Lava plate, Lightning coil, Fire phoenix) are as built.

**Mystic** (world art):
- Lightning: bolt is three filled Lightning-material ribbons through curved bends. It was 3 stroked raw-blue polylines with a white wire core; the white flash cores are now Lightning's glint.
- Grove vine (Plant): swing is a soft crescent, not a 2 px stroked arc.
- The rest of the world art is unchanged.

**Mystic cast overlay** (`mystic_cast_overlay.png`): all 17 read as their idea in grains and filled material, with no lines.
- Crystal: a rooted geode cluster of upright two-faced prisms, a glint running along them, then chips falling. It was a pinwheel of loose facets round the caster.
- Ice: crown is upright needles on a frost plate (it had fanned blades).
- Light: motes rising through the morning light past a small gold sun (they had gathered into radial rays).
- Lightning: two leaders fork toward the strike (it had a wheel of 3 arcs).

**Basics**: unchanged and good. Each family's basic is its own material (`basic_vfx.dart`); none stroked.

## Draw census

Mean extra draws per cast frame (middle moment, mean over 17 elements × 3 bands):

| Family | phase4_final | final |
|---|---|---|
| Horn | 27.3 | 21.7 |
| Wing | 30.6 | 30.8 |
| Let | 45.5 | 44.6 |
| Pip | 10.0 | 10.1 |
| Mane | 9.4 | 10.2 |
| Mask | 21.9 | 22.8 |
| Kin | 11.4 | 10.4 |
| Mystic | 31.7 | 32.6 |

Blur 0 and saveLayer 0 everywhere. The census "+stroked" column is a `drawRawPoints` grain batch (one per cast in most families), not a line. Several fixes also batch paths:
- Horn Plant wrap: 18 → 4 fills per rooted body.
- Mask Plant tendrils: 3 stroked draws per tendril → 3 fills total.
- Let cracks: per-seam fills → 2.

## Left on purpose, or not mine

- **Mystic world ambience** (`mystic_world_ambience.dart`): screen-edge flicks (Lava seams, Ice veins, Air streaks, Plant creepers) are already filled tapered ribbons at low alpha. At the audit's 0.5 zoom they look thin. I left them.
- **Kin Lightning coil**: three short writhing arcs round the kin. It reads as a charged coil, not busy orbiting. Left.
- **Horn Steam/Earth taunt reach** (orange on the hit sheet) is bigger than their art. That's a taunt radius, not an area to paint. Left.
- **Off-frame or no-trigger in the audit scene**: Mask Light void and Mask Spirit wisps land outside the frame. Pip Fire pools and Wing/Let kill effects need a kill, and the practice bodies never die. Judged from the pieces and preview sheets instead.
- **`drawLightningCrackle`** (`cosmic_projectile_vfx.dart`) is a stroked zig-zag with no callers, so it's dead code. `drawLightningBolt` (also stroked) is used only by the dungeon Lightning puzzle (`planet_dungeon_game_lightning.dart`), which isn't ability art.
- **Dungeon Pip Steam**: the dungeon counts `pipSteamWindowTimer` down rather than up. I didn't wire the shared cloud there, to avoid guessing at the semantics.
- **Gameplay-side, for the balance owner**: the dungeon Horn Dark wind-up drags from a hard-coded 200. Survival and open space use `hornDarkAuraRadius(beauty)` (221–338). The art follows each mode's real number.
