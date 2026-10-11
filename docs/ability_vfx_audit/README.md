# Ability VFX audit — 2026-10-09

Audit only: no game code was changed. Every Alchemon special (8 families × 17
elements) and every family's basic attack, rendered by the **real Survival
renderer** at three stat bands, judged against the art rules (material not
lines, alchemy is grains, no stars/blades/orbiting, flowy not bursty, no
per-frame blur, dark palette, low draws) and against the hit areas the game
actually uses.

## The sheets

| File | What it shows |
|---|---|
| `<family>_specials.png` (8) | 17 rows × 3 moments after the cast; inside each moment **low \| decent \| perfect** side by side. Left column: the numbers the cast carries at low/decent/perfect, the extra draws the cast adds to the frame, and blur count. |
| `<family>_hitarea.png` (8) | The middle moment again with the gameplay hit areas drawn over it: cyan contact (3 × radiusMultiplier), yellow effectRadius, green snare, orange taunt, blue intercept, red Let skyfall blast / crater, white Horn charge sweep. |
| `basics.png` | Each family's auto attack, two elements per family, 3 bands, two moments. |
| `wing_specials_cinematic.png` | Wing again at `SurvivalVisualQuality.cinematic`, for comparison: players on the default setting get `balanced`, which strips the beam material (see W1). |
| `data.json`, `basics.json` | Every number in this README, per ability and band: the cast's own numbers (`pure`), the live projectiles on the middle frame (`live`), the draw census of the middle frame and of the same scene before the cast (`census`, `baseline`), and the drawn extent of the cast's biggest piece rendered alone (`pure.main.drawnR80/drawnRMax`). |

Regenerate (≈25 s for everything):

```
AUDIT_OUT=docs/ability_vfx_audit \
  flutter test test/ability_vfx_audit_preview_test.dart --tags preview
# optional: AUDIT_FAMILIES=horn,wing,basics   AUDIT_QUALITY=cinematic
```

The committed PNGs were palette-quantized to 256 colours afterwards to keep
the repo small; a fresh run writes full-colour PNGs.

### The scene

- `CosmicSurvivalGame` itself (a test subclass modelled on
  `AbilityPreviewGame`), at **`balanced` quality — what players get by
  default** (`CinematicQuality.cinematic` maps to `SurvivalVisualQuality.balanced`,
  cosmic_survival_screen.dart:486; `SurvivalVisualQuality.cinematic` is not
  reachable from settings).
- One **level-10** creature of the real species (real sprite sheet), all four
  stats set to the band: **low 3.0 (Potential 35), decent 4.65 (Potential 55),
  perfect 11.0 (Potential 100)**.
- Seven practice bodies in a cluster ~300 units off the core: 5e6 HP, speed 0,
  sprung to their posts, back 0.8 s after a fall. Waves are held back, the
  ship is parked on the core and hidden (shown for the Kin elements whose
  special works through it).
- The caster is placed in reach of the cluster before the cast (fast flyers
  otherwise wander out of special range), the special forced with
  `specialCooldown = 0`, and basic attacks are held so the special reads alone.
  Kin's charged laser is not cooldown-gated and still fires.
- Camera zoom 1.0 (560 × 420 world units per cell, drawn at 0.64); Mystic at
  zoom 0.5 because its world spreads over the arena; Kin framed on core,
  ship and cluster.

### What the sheets can't show

- The **Mystic cast overlay** (`MysticGraphxOverlay`, a Flutter layer over the
  game: cosmic_survival_screen.dart:2418) is not drawn by `game.render`, so it
  is not on the sheets. It has the worst art in the audit — see M-Mystic 1.
- **Flat white creature silhouettes** in many cells are the companion's
  contact hit-flash (it is touching the practice bodies), not ability art.
  That flash is itself a hard white `srcATop` fill of the whole sprite
  (cosmic_survival_game.dart:20685-20690), rule 4.
- The census counts **one** caster in a quiet scene. A five-creature party in
  a horde multiplies it.

Line numbers below are against HEAD `ef4d4751` plus the uncommitted survival
balance change. The main checkout has other uncommitted edits to
`cosmic_survival_game.dart`, so survival line numbers there may be off by a
few. File keys used below:
**SG** `lib/games/cosmic_survival/cosmic_survival_game.dart`,
**P** `lib/games/cosmic/cosmic_projectile_vfx.dart`,
**D** `lib/games/cosmic/cosmic_data.dart`,
**H** `horn_vfx.dart`, **HR** `horn_runtime.dart`, **M** `mask_trap_vfx.dart`,
**MP** `mask_trap_placement.dart`, **WV** `wing_vfx.dart`, **LV** `let_vfx.dart`,
**PV** `pip_vfx.dart`, **MAV** `mane_alchemical_vfx.dart`, **MR** `mane_runtime.dart`,
**KV** `kin_vfx.dart`, **KR** `kin_support_runtime.dart`, **MW** `mystic_world_vfx.dart`,
**AR** `cosmic_ability_runtime.dart`, **V** `vfx_shapes.dart` (all under
`lib/games/cosmic/`), **GX** `lib/games/cosmic_survival/components/mystic_graphx_overlay.dart`,
**AMB** `lib/games/cosmic_survival/components/mystic_world_ambience.dart`.

---

## Headlines

1. **No grains anywhere.** Not one ability frame in 408 uses `drawRawAtlas`
   (census `atlas +0` for every cast). Rule 2 is unmet family-wide; V has no
   grain primitive. Every spark, ember, mote and wisp is a `drawCircle`.
2. **No blur.** 0 blurred paints and 0 `saveLayer` in every ability frame
   (rule 5 clean). The only blurs left near abilities are two text shadows
   (SG:20628-20633 Wing+Plant counter, KV:880 Kin Steam badge).
3. **Claim-order bugs put old art on screen.** Let's stationary catch-all
   (P:3563-3574) claims Horn's Fire, Water, Steam, Dust and Dark zones, so
   they are drawn by the legacy flat-disc zone painters, never by horn_vfx —
   in survival, open space and dungeons. `test/horn_vfx_preview_test.dart`
   calls the horn painter directly, so it never saw this.
4. **The default quality strips Wing's beam material.** `balanced` passes
   `particles: false` to `drawAdvancedAbilityBeam` (SG:19351), which turns off
   `_drawMaterial` (WV:146). Every default player sees all 13 line beams as
   the same coloured laser (compare `wing_specials.png` with
   `wing_specials_cinematic.png`).
5. **The generic fallback is the only art for the most numerous shots.**
   Wing, Horn and Mystic basics, Pip and Mask basics, all Wing special discs
   and trail drops, Mane Lightning orbs, Mane Dust trail, Kin Poison darts and
   Horn Lava seekers are flat saturated `drawCircle` pairs (P:5984-6018,
   6146-6160). In `basics.png` no basic is distinguishable by element and none
   changes with stats.
6. **A hexagram.** The Mystic cast seal draws two opposed triangles
   (GX:417-432) — the sigil rule says ringed octagram {8/3}, never a hexagram.
7. **Scaling is uneven.** Contact radii all scale (about ×1.9 low→perfect),
   but many *areas* are flat constants, several painters clamp the art while
   the hitbox keeps growing, and a few areas blow up at perfect (Let blast
   ×1.84, Earth Let 181→348 px; Mask trap fields ×2.5 count).

---

## Outdated abilities, by family (worst first)

Scores are 1–10, 10 = most outdated. "Seen" = visible on the sheet.

### Horn (`horn_specials.png`)

1. **Fire / Water / Steam / Dust / Dark zones — 7.** Drawn by Let's legacy
   fallout (P:3563-3574 → `_drawLetFallout` P:4476) instead of horn_vfx's
   burning ground / whirlpool / geyser / cyclone / void (H:605-620, never
   reached). Seen: Dust is three flat concentric discs (P:3086-3100), Steam a
   flat grey disc (P:2784-2809), Water a polygon pool with stroked ripple
   hoops (P:2392-2400), Dark stroked spirals (P:2873-2876), Fire a lane of flat
   discs with a white-hot pip (P:2439-2452). Plus 8 rotating taunt spokes
   each (P:4349-4366). Rules 1, 3, 6.
2. **Crystal — 8.** Wind-up draws 6 white tangent dashes orbiting the horn
   through the element-less beam path (H:1382-1388 → P:166-219, 150–190
   draws); each orbiting shard gets 3 spinning stroked arcs (P:4391-4408).
   Seen at 2.2 s: thin arcs round the cluster. Rules 1, 3.
3. **Spirit — 8.** A straight horizontal bar through the horn every frame
   (H:1422-1428), 8-spoke rings round every phantom, white particle flood
   (H:1470-1482). Rules 1, 3, 6.
4. **Lightning — 5.** Brew chords are element-less stroked beams (H:1255-1261);
   discharge is a radial burst of 40–70 dots (H:1278-1295). Seen: a hairline
   arc and zig-zag at the cluster. Rules 1, 4.
5. **Light — 5.** Barrier rim is a thin bright band (H:1008-1014) and near-
   diameter white chords cross it 45% of frames (H:1650-1661). Seen: the
   hairline across the bubble. Rule 1.
6. **Ice — 6.** ~88 rotating taunt spoke dashes along the wall (role overlay),
   pure-white motes (H:1585). Rule 1, 3.
7. **Lava — 4.** Kill explosion = 12 evenly spaced rays (H:1305); seekers are
   generic discs (HR:470-488, `drawHornMote` H:633 never reached).
8. Earth 4, Air 6 (passive: dots only, H:1454), Blood 3, Mud 3, Poison 3,
   Plant 3 — fine material apart from the role-overlay spokes on Earth.

### Wing (`wing_specials.png`, `wing_specials_cinematic.png`)

1. **All line beams (13 elements) — 6–7.** W1: default quality draws no beam
   material (above). W2: every live beam is re-pushed as a 0.08 s segment each
   frame (WV:745, WV:778-815, SG:18524-18545) and every live segment is drawn
   (SG:19325-19353), so ~5 overlapping copies per beam: glow stacks toward
   opaque, a moving beam ghosts, and the 24-segment cap evicts copies.
   W3: tint is 70% Material accent colour (WV:90). Seen: identical bright
   lines in different colours. Rules 1, 6, 7.
2. **Lightning — 9.** Straight white micro-arc lines (P:168-217), hairline
   zig-zags re-rolled at 20 Hz (WV:172-181), a 3.4w white flash (WV:755-757).
   Rules 1, 4.
3. **Fire / Poison rings — 6.** Seen: a dashed ring of drops / dotted olive
   hoop. Closed ink soft-ring (WV:587), radar-sweep crescents (WV:662-677),
   Material-purple particles on olive Poison. The ring art is a perimeter
   band, the hit is a filled disc (SG:15932-15934).
4. **Crystal — 7.** Two-triangle prism clip-art (WV:441-452); shard
   secondaries get spinning stroked guard arcs (P:4391-4409).
5. **Plant — 6.** Daisy pickups: 5 round petals + white centre (WV:988-1017);
   per-frame TextPainter counter with a blurred shadow (SG:20622-20641).
6. **Special discs and trail drops (all 17) — 7.** Generic `standard` dots
   (P:6146-6160). Trail drops tick at 66 / 85 / 132 px but draw a 3.6 px dot.
7. **Light heal core — 6.** The legacy 3-line ruled beam (P:167-217).
8. Earth, Mud, Dust, Air, Dark, Blood, Water, Ice, Steam: material is
   reasonable when it is shown at all (see W1).

### Let (`let_specials.png`)

1. **Telegraph (all 17) — 7.** Flat tinted disc + stroked 1–2.2 px hoop
   (P:6851-6854) + 3 rotating tick spokes (P:6864-6872) + hard shadow disc.
   Seen: at perfect the disc covers most of the frame including the core.
   Rules 1, 3.
2. **Meteor (all 17 + every Let basic) — 7.** Four-point star glints
   (`drawSparkleGlints` P:6470-6508, used at 3799/3835/3888/4067/4111), white
   pip, outline stroke (P:3775-3781), Earth `drawRect` squares (P:4202-4209),
   Lava `drawLine` fissures (P:3862), Lightning white zig-zag down the wake,
   Poison violet / Spirit lilac off-palette accents, Dark orbiting motes;
   ~20 `Paint()` allocations per meteor per frame. Rules 1, 3, 6, 7.
3. **Lightning crater — 8.** Radiating hairline `vfxBolt` strokes (LV:255-277).
   Seen: white hairline zig-zag cracks.
4. **Light crater — 7.** 7 radial lens rays (LV:279-303). Seen: a 4-blade
   cross. Rule 3.
5. **Crystal / Ice / Air craters — 6–7.** Symmetric spike rings of shards
   (LV:459-546). Seen.
6. **Earth — 7.** Squares on the rock; hairline cracks left behind (seen at
   1.6 s); its 150 px sweep (SG:14505) is never drawn.
7. Poison 7, Spirit 7, Dark 7 (off-palette accents, orbiting motes, 5
   follow-up telegraphs up to ~600 px); Water, Mud, Steam, Plant, Blood 5–6.

### Pip (`pip_specials.png`)

Pip specials barely read at all: at t + 0.05 s they are a few small dart
streaks, at 0.15 s grey hit puffs, and they look like the basic. Hit puffs are
the shared 6-dot spark.

1. **Ice — 8.** A frost asterisk of 6 rotating white spokes on every dart
   (P:4374-4388); cyan needle.
2. **Light — 8.** 3 spinning stroked arcs per dart (P:4391-4409).
3. **Lightning — 7.** Zig-zag stroked trail snapping at 18 Hz (PV:268-287);
   up to 35 bounce sparks.
4. **Basic (all 17, unmastered) — 8.** It has no tempo signal so Pip's own
   `drawPipDart(special:false)` refuses it (P:374-379) and it falls to the
   generic dot (P:5984-5998): a 1.6 px core against a 3 px hitbox.
5. Steam 6 (4 discs orbiting the pip, SG:20563-20586), Poison 5 (purple head
   on olive web), Crystal 5 (contracting ring pulse PV:481-488), Dust 4
   (orbiting dots PV:457-466). Shared: bounce-counter chevrons read as HUD
   (PV:104-119); 75% Material tint (PV:47).

### Mane (`mane_specials.png`)

1. **Lightning — 8.** Orbs in flight are generic white-core dots
   (P:6000-6018); fields are stroked zig-zags re-rolled at 9 Hz
   (MAV:138-147, 349-362); field count is `5 + rng.nextInt(6)` (MR:81) —
   random, ignoring the Beauty-scaled count.
2. **Dust — 7.** Two trail systems: ~50 generic dots (seen as a dotted line,
   P:6146-6160) plus fog puffs; +115 draws.
3. **Light — 7.** Rotating hairline curls (MAV:422-435), rings orbiting the
   creature, evenly spaced radial burst on feed (KR:616-628).
4. **Plant — 6.** Stroked cords (MAV:378-393). Seen: the vines fill the whole
   frame at every band (glow ~360 px, root ~405 px at the caps).
5. **Earth quake zone — 8.** Only two expanding strokes (MAV:539-546).
6. **Fire — 5.** Launch is an evenly spaced fan of flame blades (seen at
   0.3 s, 5 → 16 of them); near-white glow core (MAV:447).
7. Ice 5 (hairline veins + engraved seal + `drawLine` glint, P:596-635),
   Water 5 (stroked crest arcs), Mud 5, Steam 5, Lava 4, Crystal 4, Poison 4,
   Spirit 4, Air 4, Blood 3, Dark 3. Shared: `_Painter.line` (MAV:183-196) is
   the stroke behind nearly all of them.

### Mask (`mask_specials.png`)

1. **Spirit — 7.** The clear effect: 80→800 px flat disc, a white disc and a
   full-viewport wash (M:1385-1401), plus 32 radial motes. Seen at decent and
   perfect: the whole cell washes blue. Rule 4.
2. **Fire / Lava — 6.** Four stacked stroke passes per crack/ember in
   saturated orange (M:471-474, M:485-488), `fleck` drawLines (M:425-434).
   The heaviest Mask frames: +354 / +279 draws at perfect
   (225 / 180 of them stroked); 884 / 729 total at cinematic.
3. **Dust — 7.** Grit, stones and crescents orbiting every ally (M:790-822).
4. **Air — 4.** Pinwheel spirals of hairline arcs with orbiting leaves
   (M:878-927), up to 20 at once (+221 draws at perfect).
5. **Lightning — 5.** 6 bolts radiating from the centre (M:928-946). Seen:
   thin wavy wires.
6. **Water — 5.** Stroked rim arcs + hairline reflections (M:288-321). Seen:
   the pools are near-black and barely read.
7. **Ice — 3–5.** Seen: a large flat grey monolith polygon; frost hairlines.
8. Crystal 4 (hairline fractures M:228-234), Steam 5 (hairline curls and
   chevrons M:866-876), Dark 4 (stroked wisps M:355-366), Plant 6 (three-pass
   stroked tendrils P:5862-5871; enemy search and sort inside render
   SG:18476-18493), Earth 3, Light 3, Mud 2, Poison 2, Blood 2.

### Kin (`kin_specials.png`)

Kin specials are mostly invisible on the sheets: Fire, Ice, Steam, Spirit,
Blood and Light show nothing or a few small marks, and nothing visibly changes
between bands.

1. **Blood — 9.** Ruled 1.2 px lines between every pair of allies, saturated,
   a Paint per line (KV:827-846).
2. **Lightning — 8.** Zig-zag coils re-randomised at 16 Hz (KV:501-527);
   random radial spokes on the ship every frame (KV:814-821). Seen: the
   stroked ring at the ship.
3. **Plant garden — 7.** Falls to the old mask ground-zone path: flat glow
   disc (P:3521-3524), hairline stroked stalks (P:2584-2597), clip-art daisy.
4. **Poison — 7.** Darts fall to the generic sigil dot with a white core
   (P:6000-6018).
5. **Ice — 7.** A 220 / 365 / 544 px release is shown as a 38–67 px burst
   (particle drag, SG:519-528).
6. **Dark — 6.** The core veil is a stroked saturated purple hoop
   (SG:19911-19929). Seen: same ring at every band.
7. **Light — 4.** Kite/diamond lanterns read as four-point gems (KV:254-286).
8. Steam 5 (HUD text badge KV:857-889), Lava 6, Fire 6 (3 flames orbiting
   fast KV:532), Spirit 5, Water 3, Earth 3, Mud 3, Dust 4, Crystal 3, Air 4.
9. **Basic laser — 4.** Good lens art (KV:656-699) in raw Material colour
   (SG:13849, 13858, 20556); drawn half-height ≤0.28 of the hit band.

### Mystic (`mystic_specials.png`)

1. **Cast overlay, all 17 — 10.** Hexagram seal (GX:417-432), stroked rings
   and hexagon, rune ticks, radial spike lines, white flash discs
   (GX:805-850, 1731-1757), saturated palette (GX:244-355), fixed screen-pixel
   sizes; `SceneConfig.autoRender` keeps a full-screen layer repainting every
   frame for the whole run (GX:64). Not on the sheets.
2. **Fire — 8.** ~35 / 44 / 51 embers as flat discs, no viewport cull, Paint
   per circle (SG:19805-19834) — +456 draws at perfect; plus the leftover
   "Sacred Pyre" salvo (D:10830-10896) as comet dots (P:93-137) over a 90 px
   burn.
3. **Lightning — 8.** Stroked 12-point zig-zag with a white core
   (P:7261-7318), white snap spill (MW:441-447), full-screen flash
   (SG:13675-13684).
4. **Light — 8.** Corona is an 11-point sunburst (MW:296-313); full-screen
   flash in lightning blue (SG:13675-13684, triggered at SG:12685).
5. **Ambience (10 elements)** — stroked flicks, ruled rain, hairline curves,
   zig-zag glyphs, oval rings, hairline cracks via AMB `stroke()/oval()/line()`
   (AMB:95-120, 350-359). Seen: Lava hairline cracks, Air stroked tornado
   ellipses, Plant stick-figure stems.
6. Mud 7, Ice 6, Dust 5, Plant 5, Earth 4, Lava 4, Crystal 4, Air 4, Poison 4
   (but up to ~600 draws worst case), Blood 4, Water 3, Steam 3, Spirit 3,
   Dark 2 (the maw is the best-looking Mystic).
7. Most worlds read as a viewport colour wash with sparse props; beyond Fire's
   ember count, Dark's maw and Air's funnel, nothing changes between bands.

### Basic attacks (`basics.png`)

No basic changes with stats in any family, and most can't be told apart by
element. Horn, Wing, Mystic: generic `standard` disc pair (P:6146-6160).
Pip, Mask: generic `dart` dot (P:5984-5998). Let: the full meteor painter
(star glints, white pip; ~25 draws per shot). Mane: material blade with a
stroked hairline edge (MAV:697) — fine. Kin: the charge/laser is good material
in raw colour. Basics carry `abilityFamily ''` (D:11323-11494), so no family
painter can claim its own basic.

---

## Scaling

The left column of every sheet carries the cast's numbers at
low / decent / perfect; the hit-area sheets draw them. Full tables are in the
appendix.

### Scales correctly (art follows the hit)

- **Wing beams**: width 7.6 / 9.8 / 15.3, drawn full width 18 / 24 / 38 —
  ≈ 0.85 of the capsule the beam hits with (half-width max(10, 1.45w), AR:547)
  at every band. Beam duration also grows (2.1 → 2.5 s).
- **Horn Fire lane, Horn Light dome** (155 / 178 / 233 = protect radius),
  **Horn charge sweeps** (drawn slam = final sweep until 170 px).
- **Mask traps**: art radius grows ×1.36–1.45 with effectRadius; trap count
  grows 6 → 15 (Fire/Lava), 8 → 21 (Air), 5 → 12 (Poison), 4 → 10 (Water).
- **Pip darts** (visualScale and radiusMultiplier share one curve).
- **Kin Water / Plant / Air / Dust / Crystal** zones (r80 68 → 113 for Water).
- **Mystic Water maelstrom, Dark maw, Air funnel, Poison pools** (drawn
  0.86–1.15 r).
- **Let telegraph and crater** match `letSkyfallBlastRadius` exactly.

### Doesn't scale at all

- **Every basic attack** (all families).
- **Let meteor body**: `visualScale.clamp(1.2, 4.8)` (P:3692) bites at Beauty
  ≈ 2.6; measured r80 65 / 64 / 61 while contact grows ×1.92 — it even shrinks.
- **Horn Water, Steam, Dust, Dark, Lightning zones and Earth's damage pulse**:
  `scaleHornProjectile` never scales `effectRadius` (D:5807-5885) and
  `clampHornChargeBurst` caps it at 110 (HR:131-148). Gameplay *and* art are
  flat (measured r80 Dust 111 / 111 / 111, Steam 102 / 101 / 100, Dark
  126 / 127 / 128).
- **Let zones**: fixed 115–145 px (AR:114-170).
- **Pip snare / intercept radii** (not scaled by `scalePipProjectile`
  D:7840-7868, and never drawn); Pip Poison web radius 32.
- **Kin**: Dark veil ring, Earth wall stones (count grows 9 → 13, stones fixed),
  Lightning, Steam, Lava plate (fixed 21/30 px), Spirit wisp (kill-driven).
- **Mane Light ward** ring sizes (fixed ladder D:7527-7528; only count grows).
- **Mane Lightning field count** is random (MR:81).
- **Most Mystic worlds** (Lava fissure count saturates at stat 3, SG:12114;
  Lightning splash fixed 78; Light star fixed).

### Drawn size ≠ hit area

| Ability | Gameplay | Drawn | Ratio |
|---|---|---|---|
| Horn Poison aura | 140 × hornPoisonAuraScale(Int) = 140 / 163 / 182 (SG:16648-16649) | hard-coded `radius: 140` (SG:20648) | 0.90 / 0.77 / 0.69 |
| Mane (Water, Lava, Ice, Earth, Crystal, Dust, Steam, Poison, Blood, Dark, Air, Mud) | contact grows ×2.2–2.3 | draw clamps 4.4 (MAV:606-615) / 3.4 (P:527, 718, 876) freeze the art from Beauty ≈ 3.6–6.4; measured r80 Lava 51 / 59 / 59, Water 84 / 98 / 98, Ice 46 / 56 / 56 | art 3.6× hit at low, 1.9× at perfect |
| Mane snare fields | 1.5–2.5× the body | never drawn | 0 |
| Mask contact traps (Air, Crystal, Fire ball, Water, Light, Blood) | trigger 3 × radiusMultiplier (Beauty, D:9520) | art from effectRadius (Intelligence, M:40-41) | art ≈ 12–21× trigger |
| Mask ground traps | circle `max(24, effectRadius)` (SG:15327) | ellipse squashed 0.55–0.65 | under-drawn 35–45% vertically |
| Wing trail drops | tick 66 / 85 / 132 | 3.6 px generic dot | 0.03–0.05 |
| Wing rings | filled disc | perimeter band 0.79–1.19 r | interior unpainted |
| Wing Spirit tether | straight wing → target | dog-leg wing → ship → target (WV:792-800) | path mismatch |
| Let impact art | blast 132 / 161 / 243 | crater disc ≈ effectRadius 85 / 108 / 163 | ≈ 0.65 |
| Let Earth sweep, Crystal splash, Lightning chain | 150 / 140 / 135 px hops | not drawn (sparks only) | — |
| Kin Ice release | 220 / 365 / 544 | 38–67 px burst | 0.07–0.30 |
| Kin Fire phoenix | burn 60 / 72 / 99 | outer art ≈ 0.6 r | 0.58–0.66 |
| Kin Light | heal 60 / 72 / 99 | spill ≈ 0.44 r | 0.44 |
| Kin laser (basic) | band enemy r + 14 per side | ≤ 3.9 px half-height | ≤ 0.28 |
| Horn Dark wind-up pull | 260 / 303 / 338 | particles reach ≤ 99 | 0.38 / 0.33 / 0.29 |
| Horn Crystal / Spirit | intercept 42 / 54 / 81, taunt 146–180 | arcs 17 / 21 / 32, spoke ring 33–71 | 0.23–0.39 |
| Pip Water final-bounce splash, Mane Plant root explosion, Mane Crystal boss blast | 160 / 165 / 240 px | a 6-dot hit spark | — |
| Mystic Fire salvo | burn 90 | 4–6 px comet dots | ≈ 0.05 |
| Mystic Dark maw | pull 430 / 501 / 589 | spiral arms 0.58 r | 0.58 |
| Hit sparks (every ability) | — | drag 0.92 per 60 Hz frame (SG:519-528) → a burst travels ≈ v/5 px | reach 6–23 px |

### Blows up at perfect

- **Let blast**: 132 → 243 px (area ×3.4); **Earth Let** 181 → 348 px; **Dark
  Let follow-ups** 253 → 487 px, ×4–5 of them, each with its own telegraph.
  At perfect the telegraph covers the core.
- **Mask trap fields**: counts ×2.5 and art ×1.4 → the field covers the frame
  including the core; draws +142 → +354 (Fire), +79 → +221 (Air),
  +84 → +209 (Poison), +26 → +80 (Water).
- **Mane Lava**: +323 → +514 draws per cast (pools).
- **Mystic Fire**: +324 → +456 draws (un-culled embers).
- **Mane Plant vines**: fill the whole frame at every band (glow / root art
  caps at 360 / 405 px) — already oversized at low.
- **Horn Light dome**: 155 → 233 px and keeps growing on the log tail
  (≈ 294 px at stat 30) — covers core and creature.
- **Mask Spirit clear**: only fires at decent / perfect in this scene, and
  washes the screen.

### Shared scaling plumbing

- **`hornStatScale`** (HR:27) is used at 57 call sites (horn, kin, pip zones,
  mystic worlds, AR). Above internal 5 it reads `legacyGameplayRating` (11.0
  rates 6.69) and every call clamps to a small `max` (1.22–1.55 typically), so
  those numbers stop growing around internal 6–9 — before perfect, and well
  before what the new balance pays for.
- **`scaledAbilityValue`** keeps a log tail past 12; art clamps (Mane 4.4/3.4,
  Let 4.8, Horn slam 170, Mask 260, Pip 2.3) do not, so past the clamp the
  hitbox grows and the art does not.
- **Culling uses the hit radius** (`3·rm·2.6 + 28`, SG:19259-19268), so art
  drawn at 100–260 px (Mask Steam/Dark/Lightning, Lava glow, Horn Light dome,
  Let wakes, Mane blades) pops in and out at screen edges.

---

## Performance

Census = draw calls recorded by a `Canvas` that counts calls
(as in `survival_orb_budget_test.dart`) on the middle frame, minus the same
scene before the cast. The scene alone is ≈ 78–125 draws. Repeat runs
vary by a few draws (particle timing).

| Cast (perfect) | +draws L / D / P | What it is |
|---|---|---|
| Mane Lava | 323 / 361 / 514 | pools: +219 circles, +293 paths |
| Mystic Fire | 324 / 415 / 456 | +432 `drawCircle` (embers, no cull, Paint each) |
| Mask Fire | 142 / 209 / 354 | +247 paths, **+225 stroked** (4-pass cracks), +45 lines |
| Mask Lava | 136 / 189 / 279 | +190 paths, **+180 stroked** |
| Horn Ice | 228 / 209 / 154 | wall blocks + 88 taunt spokes + pool particles |
| Mask Air | 79 / 122 / 221 | +184 paths (pinwheels) |
| Mask Poison | 84 / 121 / 209 | traps + particle pool at 127 |
| Horn Fire | 198 / 197 / 195 | 5 legacy zones × (9 + 8 spokes) + 143 pool particles |
| Wing Steam / Lava / Poison / Earth / Mud | 120–180 | 5 overlapping beam copies + pool at 130–150 |
| Mask Crystal | 91 / 143 / 176 | +171 paths, +88 stroked |
| Horn Plant | 132 / 131 / 127 | root wraps, 18 paths per rooted enemy, no cap |
| Kin Earth | 86 / 106 / 126 | 10 paths per wall stone × 9–13 |
| Pip Poison | 48 / 81 / 125 | web + pool at its 150 cap |

At `cinematic` (not reachable from settings) Mask Fire reaches 884 total
draws and Mask Lava 729; Wing beams roughly double.

Draw cost grows with stats (×1.5–3) for Mask Fire/Lava/Air/Poison/Water/
Earth/Mud/Crystal, Mane Lava and every Pip special — a creature-count effect,
fine as gameplay, but it's linear in draws because nothing is batched.

**The particle pool** (`_vfx`, SG:19853-19863): one `drawCircle` and one new
`Paint()` per particle, cap 150. It sits at **140–150** on the middle frame
for Horn Fire/Steam/Earth/Dust, Wing Lava/Ice/Steam/Mud/Plant/Poison, Pip
Lightning/Dust/Poison, Mane Dust/Light and Kin Dust — up to 150 draws and 150
allocations by itself. On `balanced` it skips `i.isOdd`, and because
`removeWhere` compacts the list, particles change parity as others die and
**blink frame to frame**. `AbilityVfxPool.render` (P:5718-5729, open space and
dungeons) has the same flicker, no cap, and drag not scaled by dt.

**Allocations**: ~20 Paints per Let meteor per frame; a Paint per call in
mask_trap_vfx (M:113-124, 140, 386, 1064, 1190); a new Gradient per
`vfxSpill` / `vfxSoftRing` / `vfxCrossLit` call (V:309-406); TextPainter
built per frame for the Wing+Plant counter.

**Blur**: none in ability paint (two text-shadow blurs, above).
**Mystic overlay**: full-screen graphx layer repainting every frame (GX:64).
**Enemy atlas**: bodies with `maneRootTimer > 0` or hard freeze leave the
swarm atlas (cosmic_enemy_vfx.dart:259-260, 406-407) but draw nothing
different — a free win to remove.

---

## Prioritised fix list

Cost notes are per frame, per affected caster.

| # | Fix | Covers | Per-frame cost |
|---|---|---|---|
| 1 | **Scope Let's stationary catch-all to Let** (`abilityFamily == 'let'`, or exclude `hornImpact`) at P:3566-3574 | Horn Fire, Water, Steam, Dust, Dark zones + Steam kill geysers get their authored horn_vfx art, in survival, open space and dungeons | neutral (horn zone art ≈ the 9–17 fills it replaces, minus 8 spokes) |
| 2 | **Empty `drawProjectileRoleOverlay`** (P:4328-4474) — or one `vfxSpill` under the piece for taunt; delete turret and heal (dead) | Pip Ice asterisk, Pip Light arcs, Horn/Wing Crystal guard arcs, taunt spokes on Horn Fire/Steam/Earth/Dust/Dark/Spirit/Ice wall/geysers | −3 to −8 line/arc draws + Paints per projectile (Horn Ice wall −88) |
| 3 | **Remove the hexagram**: replace `_castAlchemySeal` (GX:395-488) with a grain octagram or drop the overlay; stop the always-on ticker | all 17 Mystic casts | saves a full-screen repaint every frame |
| 4 | **Wing beams: paint each live beam once per frame** from `_activeWingBeams` (as `_renderWingRings` does) and drop the 0.08 s `_BeamFx` copies (WV:745, 778-815; SG:18524-18545, 19325-19353); then decide W1 — give `balanced` the beam material (it is ~+90–170 draws today *because* of the 5× copies; after this fix it is ~1/5 of that) | all 13 line beams + blast + split children | −80% of beam draws (140–350 → 30–70) |
| 5 | **Particle pool → one `drawRawAtlas` grain batch** (SG:19853-19863; same for `AbilityVfxPool` P:5681-5729, also dt-scale its drag and cap it); colour from `vfxMaterial` glint → white instead of raw `elementColor`/white (SG:18506-18523, P:5145-5432, H:1184-1664, WV:829-899); thin at spawn instead of skipping `i.isOdd`; emit at the gameplay radius (or relax the drag SG:519-528) so bursts show their area. Pattern exists: lib/widgets/fx/alchemy_effects/alchemy_effect_paint.dart:339-400, cosmic_enemy_vfx.dart:262-500 | every hit spark (67 call sites + every projectile hit), zone wisps, detonation bursts, emitters of every family; makes Kin Ice / Pip Water / Mane Plant / Crystal AoEs visible | −149 draws and −150 Paint allocs at cap; fixes the flicker; first grains in ability art |
| 6 | **Tag basics with their family** (`createFamilyBasicAttack` D:11323) and let each painter claim its own: Pip → `drawPipDart(special:false)`, Horn → `drawHornMote`, small material drops for Wing/Mask/Mystic; make the generic fallback material (`vfxDrop` in `vfxMaterial`, radius from 3·rm, per-projectile phase) for what is left (Wing special discs/trail drops, Mane Lightning orbs and Dust trail, Kin Poison darts, Horn Lava seekers) | every basic in the game; all 17 Wing specials | ≈ +1 fill per projectile |
| 7 | **Kill the full-screen flashes**: `_renderMysticSkyFlash` (SG:13675-13684), Mask Spirit clear (M:1385-1401), Wing Lightning 3.4w flash (WV:755-757), white flash discs in the legacy zone painters (P:1876-2110) → short local grain blooms | Mystic Lightning/Light, Mask Spirit, Wing Lightning | −1 full-screen fill each |
| 8 | **Let telegraph** (P:6812-6884) → a soft closing `vfxSoftRing` band + spill shadow, no hoop or ticks; **Let meteor** (P:3674-4326) → drop `drawSparkleGlints` (P:6470-6508) for white-flaring grains, drop the white pip/outline/squares/fissure lines, cache Paints, lift the 4.8 clamp | all 17 Let specials, every Let basic, Deadfall, Dark follow-ups, Mane legacy Fire/Ice glints | −4 draws per telegraph; −5–10 draws and ≈ −20 allocations per meteor |
| 9 | **Strokes → filled ribbons** in the four stroke helpers: `_Painter.line` (MAV:183-196), mask_trap_vfx `line()/stroke()` (M:157-165, 395-402), AMB `stroke()/oval()/line()` (AMB:95-120, 350-359), the element-less beam (P:166-219, `HornBeamEmit` H:1175) → `vfxRibbon`/`vfxLens`/`vfxBolt` | every Mane stroke; Mask Fire/Lava/Steam/Crystal/Water/Ice/Dark; 10 Mystic ambiences; Horn Crystal/Spirit/Lightning/Dark/Light emitters, turrets, orb reflect | Mask Fire/Lava 4 passes → 1 fill: about −200 draws at perfect |
| 10 | **Palette pass**: start from `vfxMaterial`, tint toward `elementColor` (≈30%, glowing elements only): Wing beam tint WV:90, Pip tint PV:47, companion aura disc SG:20499-20505, Kin laser SG:13849/13858/20556, generic painter, hit sparks | 15 Wing beams, 16 Pip heads, every creature's aura, Kin basic | free |
| 11 | **Size plumbing**: scale Horn `effectRadius` by g (D:5807-5885) and revisit the 110 cap (HR:131-148); draw Horn Poison aura at its real radius (SG:20648); Mane clamps (MAV:606-615, P:527/718/876) — either art follows radiusMultiplier or radiusMultiplier gets the same cap; Mask contact traps — art and trigger from the same stat (M:40-41 vs SG:17422); Let rock clamp (P:3692); draw Mane snare fields; cull by drawn radius (SG:19259-19268); review `hornStatScale` caps (HR:27, 57 sites) against the new past-5 balance | the scaling table above | free to small |
| 12 | **Cap the blow-ups**: Let blast (D:7563) and Dark follow-ups (SG:15074-15130), Mane Plant art caps, Mask trap counts vs draw cost, Mystic Fire embers (cull + batch) | Let, Mane Plant, Mask Fire/Lava/Air/Poison, Mystic Fire | Mystic Fire −400 draws once batched |
| 13 | **Replace the legacy zone painters** (P:2121-3126: 11-gon polygons, flat concentric disc stacks, stroked ripples/spirals/stalks, orbiting Spirit orbs) once #1 has moved Horn off them; they still draw Kin Plant (P:2558-2608) and the Mane stationary fallback | Kin Plant, Mane fallbacks | ≈ same |
| 14 | **Small stuff**: Pip+Steam orbiting puffs (SG:20565-20586), Wing+Plant counter (cache it, drop the blur), Kin Steam badge blur (KV:880), Kin Blood ruled lines (KV:827-846), Kin Lightning spokes (KV:792-823), Kin Dark veil hoop (SG:19911-19929), enemy atlas gates (cosmic_enemy_vfx.dart:259-260, 406-407), companion white hit-flash (SG:20685-20690) | — | small savings |
| 15 | **Dead code**: legacy Mane slash renderer P:968-1766 (+ `drawManeTrailWisps` P:6601-6655), `_drawLetElementOverlay` P:4750 and the second switch in `_drawLetFallout` P:4595-4747, inline Kin Spirit wisp SG:20253-20298, `drawMysticSigil` P:6679, Lightning/Earth Mystic flora P:7559-7575 / 7663-7681, reduced-branch slash and decoy rings SG:20364-20393 / 20473-20482, ~76 `maskFilter = null` no-ops | — | none; stops old vocabulary coming back |

### Where one fix covers many abilities

- **`_renderCompanionProjectile` claim order** (SG:20231-20483, mirrored in
  cosmic_game_ability_render.dart:10-110 and the dungeon) and the Let
  catch-all (P:3563-3574) — fix #1.
- **`drawProjectileRoleOverlay`** (P:4328-4474) — fix #2.
- **`_vfx` particle loop + `_spawnHitSpark`** (SG:19853-19863, 18506-18523) and
  `AbilityVfxPool` — fix #5; the single biggest lever for both rule 2 and
  draw count.
- **`drawGenericProjectileVisual`** (P:5906-6162) and `createFamilyBasicAttack`
  (D:11323) — fix #6.
- **`drawAdvancedAbilityBeam` element-less path** (P:140-218) and the Wing
  beam pipeline (WV:745-815, SG:19325-19353) — fixes #4, #9.
- **The four stroke helpers** (MAV:183-196, M:157-165/395-402,
  AMB:95-120/350-359, P:166-219) — fix #9.
- **`drawLetSkyfallTelegraph` + `_drawSkyfallMeteor` + `drawSparkleGlints`**
  (P:6812-6884, 3674-4326, 6470-6508) — fix #8.
- **`vfxSpill` / `vfxSoftRing` / `vfxCrossLit`** (V:309-406) — cache a unit
  shader and `canvas.scale`, as `_Material.glow` does; removes most
  per-frame Gradient allocations in Let craters, Wing beams, Mask traps.
- **`hornStatScale`** (HR:27) — one curve decision changes 57 scaling sites.

---

## Appendix: numbers per ability

`+draws` = draws added by the cast on the middle frame (L/D/P).
`pool` = live particles in the shared `_vfx` pool (cap 150) at perfect.
`lines+strokes` = `drawLine` + stroked-paint draws added at perfect.
`drawn r80` = radius holding 80% of the drawn alpha of the cast's biggest
piece, rendered alone through the same painter chain survival uses
(`pure.main` in data.json; for Let it is the meteor, for Wing the special
disc, not the beam). Growth columns are perfect ÷ low.

### Horn: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | 198/197/195 | 143 | 41 | 5/5/5 | 3.7/4.7/7 | effect 60/60/60 · sweep 57/72.3/109.6 | 46/58/88 | 1.89 / 1.00 / 1.91 |
| Lava | 39/37/34 | 35 | 1 | 0/0/0 | 0/0/0 | sweep 71.7/91/137.8 | – | – / 1.92 / – |
| Lightning | 22/26/27 | 27 | 14 | 1/1/1 | 4.9/6.2/9.4 | effect 140/140/140 · sweep 45.6/57.9/87.7 | 47/50/52 | 1.92 / 1.00 / 1.11 |
| Water | 19/19/20 | 9 | 4 | 1/1/1 | 6.1/7.8/11.7 | effect 140/140/140 · sweep 45.6/57.9/87.7 · snare 114/144.7/219.3 | 116/116/174 | 1.92 / 1.00 / 1.50 |
| Ice | 227/210/151 | 124 | 49 | 0/0/0 | 0/0/0 | sweep 40.7/51.7/78.3 | – | – / 1.92 / – |
| Steam | 98/100/99 | 149 | 9 | 1/1/1 | 5.4/6.8/10.3 | effect 120/120/120 · sweep 52.1/66.1/100.2 | 102/101/100 | 1.91 / 1.00 / 0.98 |
| Earth | 90/120/116 | 150 | 9 | 1/1/1 | 7.8/9.9/15 | effect 120/120/120 · sweep 71.7/91/137.8 | 41/49/59 | 1.92 / 1.00 / 1.44 |
| Mud | PASSIVE -6/3/8 | 40 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Dust | 109/105/105 | 147 | 9 | 1/1/1 | 5.4/6.8/10.3 | effect 130/130/130 · sweep 45.6/57.9/87.7 | 111/111/111 | 1.91 / 1.00 / 1.00 |
| Crystal | 53/51/52 | 0 | 55 | 5/7/7 | 3.9/5/7.5 | sweep 50.5/64.1/97.1 | 16/20/32 | 1.92 / 1.92 / 2.00 |
| Air | PASSIVE -6/-9/-5 | 26 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Plant | 129/132/129 | 0 | 1 | 0/0/0 | 0/0/0 | sweep 57/72.3/109.6 | – | – / 1.92 / – |
| Poison | 2/22/29 | 47 | 1 | 0/0/0 | 0/0/0 | sweep 48.9/62/94 | – | – / 1.92 / – |
| Spirit | 38/40/41 | 65 | 10 | 5/7/7 | 4.9/6.2/9.4 | sweep 40.7/51.7/78.3 | 27/46/98 | 1.92 / 1.92 / 3.63 |
| Dark | 12/14/13 | 29 | 1 | 1/1/1 | 5.9/7.4/11.3 | effect 180/180/180 · sweep 48.9/62/94 | 126/127/128 | 1.92 / 1.00 / 1.02 |
| Light | 66/66/67 | 125 | 4 | 1/1/1 | 12.7/16.1/24.4 | – | 149/171/224 | 1.92 / – / 1.50 |
| Blood | 13/11/14 | 0 | 1 | 0/0/0 | 0/0/0 | sweep 57/72.3/109.6 | – | – / 1.92 / – |

### Wing: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | 126/118/134 | 129 | 1 | 5/6/7 | 4.3/5.6/8.7 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.02 / 2.01 / 2.00 |
| Lava | 140/157/158 | 149 | 1 | 4/5/6 | 6.7/8.7/13.5 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.01 / 2.01 / 2.00 |
| Lightning | 17/22/19 | 29 | 7 | 6/8/8 | 2.9/3.7/5.8 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.00 / 2.01 / 2.00 |
| Water | 63/60/61 | 75 | 1 | 8/10/11 | 4.8/6.2/9.7 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.02 / 2.01 / 2.00 |
| Ice | 107/102/112 | 148 | 1 | 9/11/12 | 5.3/6.8/10.6 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.00 / 2.01 / 2.00 |
| Steam | 163/153/182 | 147 | 1 | 9/12/13 | 6/7.8/12.1 | beam w 7.6/9.8/15.3 (drawn 18/24/41) | 7/10/14 | 2.02 / 2.01 / 2.00 |
| Earth | 127/125/125 | 132 | 1 | 5/5/5 | 7.2/9.3/14.5 | beam w 7.6/9.8/15.3 (drawn 18/24/38) · snare 88/88/88 | 7/10/14 | 2.01 / 2.01 / 2.00 |
| Mud | 116/117/122 | 147 | 1 | 7/8/10 | 6/7.8/12.1 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.02 / 2.01 / 2.00 |
| Dust | 61/59/60 | 71 | 1 | 9/11/12 | 2.6/3.4/5.3 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.04 / 2.01 / 2.00 |
| Crystal | 63/65/65 | 74 | 1 | 7/9/10 | 3.8/5/7.7 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.03 / 2.01 / 2.00 |
| Air | 59/65/63 | 75 | 1 | 4/5/6 | 2.9/3.7/5.8 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.00 / 2.01 / 2.00 |
| Plant | 95/95/106 | 144 | 1 | 5/6/7 | 5.3/6.8/10.6 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.00 / 2.01 / 2.00 |
| Poison | 153/144/123 | 147 | 1 | 8/9/11 | 4.8/6.2/9.7 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.02 / 2.01 / 2.00 |
| Spirit | 137/125/124 | 47 | 1 | 4/4/5 | 4.3/5.6/8.7 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.02 / 2.01 / 2.00 |
| Dark | 64/60/62 | 73 | 1 | 8/10/12 | 4.3/5.6/8.7 | beam w 7.6/9.8/15.3 (drawn 20/26/40) | 7/10/14 | 2.02 / 2.01 / 2.00 |
| Light | 73/74/74 | 75 | 13 | 6/8/8 | 3.6/4.7/7.2 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.00 / 2.01 / 2.00 |
| Blood | 57/61/60 | 72 | 1 | 4/4/5 | 4.8/6.2/9.7 | beam w 7.6/9.8/15.3 (drawn 18/24/38) | 7/10/14 | 2.02 / 2.01 / 2.00 |

### Let: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | 49/50/48 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 65/64/61 | 1.92 / 1.84 / 0.94 |
| Lava | 69/69/72 | 2 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 39/36/34 | 1.92 / 1.84 / 0.87 |
| Lightning | 49/46/49 | 18 | 7 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 116/113/112 | 1.92 / 1.84 / 0.97 |
| Water | 76/75/77 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 60/58/54 | 1.92 / 1.84 / 0.90 |
| Ice | 56/55/55 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 61/59/55 | 1.92 / 1.84 / 0.90 |
| Steam | 43/40/41 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 43/42/42 | 1.92 / 1.84 / 0.98 |
| Earth | 23/20/21 | 0 | 3 | 1/1/1 | 24.4/31/47 | blast 180.8/229.4/347.7 | 27/26/26 | 1.93 / 1.92 / 0.96 |
| Mud | 36/36/39 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 32/32/31 | 1.92 / 1.84 / 0.97 |
| Dust | 65/66/69 | 2 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 50/49/47 | 1.92 / 1.84 / 0.94 |
| Crystal | 52/52/54 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 54/51/48 | 1.92 / 1.84 / 0.89 |
| Air | 40/40/-2 | 0 | 0 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 70/68/68 | 1.92 / 1.84 / 0.97 |
| Plant | 41/39/41 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 45/43/40 | 1.92 / 1.84 / 0.89 |
| Poison | 64/66/64 | 2 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 43/40/37 | 1.92 / 1.84 / 0.86 |
| Spirit | 23/22/22 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 59/58/55 | 1.92 / 1.84 / 0.93 |
| Dark | 44/42/45 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 44/42/40 | 1.92 / 1.84 / 0.91 |
| Light | 28/27/29 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 59/59/60 | 1.92 / 1.84 / 1.02 |
| Blood | 49/48/50 | 0 | 1 | 1/1/1 | 17.1/21.7/32.9 | blast 132/160.6/243.4 | 52/49/46 | 1.92 / 1.84 / 0.88 |

### Pip: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | 19/21/42 | 78 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 | 12/14/18 | 1.37 / 1.38 / 1.50 |
| Lava | 33/16/15 | 30 | 0 | 2/2/2 | 4.7/5.3/6.5 | effect 64.8/73/89.6 | 16/18/22 | 1.38 / 1.38 / 1.38 |
| Lightning | 77/79/84 | 150 | 4 | 5/7/7 | 2.4/2.7/3.4 | effect 64.8/73/89.6 | 20/22/27 | 1.42 / 1.38 / 1.35 |
| Water | 36/38/58 | 6 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 | 10/13/17 | 1.37 / 1.38 / 1.70 |
| Ice | 21/31/67 | 126 | 0 | 3/3/4 | 3.1/3.5/4.3 | effect 64.8/73/89.6 · snare 64/64/64 | 12/16/20 | 1.39 / 1.38 / 1.67 |
| Steam | 24/22/41 | 78 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 | 14/16/20 | 1.37 / 1.38 / 1.43 |
| Earth | 11/11/16 | 30 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 | 14/14/16 | 1.37 / 1.38 / 1.14 |
| Mud | 35/22/38 | 78 | 0 | 3/3/4 | 3.6/4.1/5 | effect 64.8/73/89.6 · snare 72/72/72 | 14/16/19 | 1.39 / 1.38 / 1.36 |
| Dust | 28/59/75 | 150 | 0 | 4/6/6 | 2.7/3/3.7 | effect 64.8/73/89.6 | 10/10/14 | 1.37 / 1.38 / 1.40 |
| Crystal | 20/29/64 | 126 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 | 12/14/18 | 1.37 / 1.38 / 1.50 |
| Air | 32/37/64 | 36 | 0 | 3/4/5 | 2.7/3/3.7 | effect 64.8/73/89.6 | 10/12/16 | 1.37 / 1.38 / 1.60 |
| Plant | 22/21/42 | 78 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 · snare 58/58/58 | 12/12/16 | 1.37 / 1.38 / 1.33 |
| Poison | 48/80/124 | 150 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 · snare 50/50/50 | 12/14/17 | 1.37 / 1.38 / 1.42 |
| Spirit | 21/30/71 | 120 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 | 16/18/22 | 1.37 / 1.38 / 1.38 |
| Dark | PASSIVE 0/-1/-1 | 0 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Light | 26/45/60 | 60 | 6 | 3/4/5 | 2.7/3/3.7 | effect 64.8/73/89.6 | 12/14/18 | 1.37 / 1.38 / 1.50 |
| Blood | 45/22/28 | 54 | 0 | 3/3/4 | 2.7/3/3.7 | effect 64.8/73/89.6 | 14/16/19 | 1.37 / 1.38 / 1.36 |

### Mane: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | -9/-9/-8 | 0 | 1 | 5/8/16 | 3.6/4/4.8 | effect 84.1/93.2/112 | 22/24/28 | 1.33 / 1.33 / 1.27 |
| Lava | 321/360/514 | 136 | 4 | 1/1/1 | 14/20.4/31.8 | effect 84.1/93.2/112 · snare 84.1/93.2/112 | 51/59/59 | 2.27 / 1.33 / 1.16 |
| Lightning | 12/11/12 | 28 | 5 | 6/7/12 | 3.6/4/4.8 | effect 84.1/93.2/112 | 15/16/20 | 1.33 / 1.33 / 1.33 |
| Water | 35/48/51 | 82 | 4 | 1/1/1 | 16.7/24.4/38 | effect 100.6/111.4/134 · snare 118.9/131.7/158.3 | 84/98/98 | 2.28 / 1.33 / 1.17 |
| Ice | 31/33/34 | 46 | 6 | 1/1/1 | 13.4/19.5/30.4 | effect 84.1/93.2/112 · snare 95.1/105.3/126.6 | 46/56/56 | 2.27 / 1.33 / 1.22 |
| Steam | 40/40/58 | 85 | 1 | 1/1/1 | 12.2/17.7/27.6 | effect 82.3/91.2/109.6 | 61/88/97 | 2.26 / 1.33 / 1.59 |
| Earth | 78/46/45 | 57 | 6 | 1/1/1 | 14.9/21.7/33.8 | effect 126.2/139.8/168 · snare 107.9/119.5/143.7 | 56/72/72 | 2.27 / 1.33 / 1.29 |
| Mud | 4/-1/-8 | 0 | 1 | 1/1/1 | 11.6/16.8/26.2 | effect 84.1/93.2/112 · snare 113.4/125.6/151 | 33/48/56 | 2.26 / 1.33 / 1.70 |
| Dust | 115/114/114 | 145 | 1 | 1/1/1 | 14.6/21.3/33.1 | effect 84.1/93.2/112 | 71/104/107 | 2.27 / 1.33 / 1.51 |
| Crystal | 31/31/32 | 42 | 2 | 1/1/1 | 14/20.4/31.8 | effect 84.1/93.2/112 | 38/56/58 | 2.27 / 1.33 / 1.53 |
| Air | -9/-10/-7 | 0 | 1 | 1/1/1 | 12.2/17.7/27.6 | effect 84.1/93.2/112 | 70/101/118 | 2.26 / 1.33 / 1.69 |
| Plant | 66/61/56 | 100 | 7 | 1/1/1 | 6.7/9.8/15.2 | effect 84.1/93.2/112 · snare 100.6/111.4/134 | 29/42/66 | 2.27 / 1.33 / 2.28 |
| Poison | 41/38/39 | 72 | 1 | 1/1/1 | 13.4/19.5/30.4 | effect 84.1/93.2/112 · snare 117/129.7/155.9 | 53/77/85 | 2.27 / 1.33 / 1.60 |
| Spirit | 23/18/22 | 38 | 1 | 1/1/1 | 7.9/11.5/17.9 | effect 84.1/93.2/112 | 31/45/70 | 2.27 / 1.33 / 2.26 |
| Dark | 21/21/20 | 18 | 1 | 1/1/1 | 7.9/11.5/17.9 | effect 164.6/182.3/219.2 · snare 164.6/182.3/219.2 | 46/68/77 | 2.27 / 1.33 / 1.67 |
| Light | -2/52/69 | 143 | 3 | 1/1/1 | 4.5/5/6 | effect 69.5/77/92.5 | 11/12/15 | 1.33 / 1.33 / 1.36 |
| Blood | 37/40/39 | 72 | 1 | 1/1/1 | 13.4/19.5/30.4 | effect 84.1/93.2/112 · snare 87.8/97.2/116.9 | 36/53/58 | 2.27 / 1.33 / 1.61 |

### Mask: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | 140/209/359 | 75 | 270 | 6/9/15 | 4/4.9/7 | effect 85.5/101.2/118.8 | 28/33/38 | 1.75 / 1.39 / 1.36 |
| Lava | 135/189/278 | 130 | 180 | 6/9/15 | 4.8/5.9/8.3 | effect 82.8/98/115 | 59/70/82 | 1.73 / 1.39 / 1.39 |
| Lightning | 3/2/6 | 13 | 6 | 1/1/1 | 6.6/8/11.3 | effect 99/117.2/137.5 | 56/66/77 | 1.71 / 1.39 / 1.38 |
| Water | 24/42/80 | 0 | 70 | 4/6/10 | 4.6/5.5/7.8 | effect 99/117.2/137.5 | 62/74/86 | 1.70 / 1.39 / 1.39 |
| Ice | -4/-3/-5 | 3 | 3 | 1/1/1 | 6.1/7.4/10.5 | effect 162/191.7/225 | 89/106/124 | 1.72 / 1.39 / 1.39 |
| Steam | 98/109/141 | 128 | 8 | 4/5/8 | 4.6/5.5/7.8 | effect 216/255.6/300 | 117/138/141 | 1.70 / 1.39 / 1.21 |
| Earth | 43/64/117 | 47 | 0 | 2/3/5 | 6.1/7.4/10.5 | effect 99/117.2/137.5 | 57/68/80 | 1.72 / 1.39 / 1.40 |
| Mud | 17/27/54 | 44 | 0 | 2/3/5 | 6.6/8/11.3 | effect 108/127.8/150 · snare 120/120/120 | 72/77/90 | 1.71 / 1.39 / 1.25 |
| Dust | 34/36/12 | 8 | 0 | 1/1/1 | 3.5/4.3/6.1 | effect 63/74.6/87.5 | 44/52/61 | 1.74 / 1.39 / 1.39 |
| Crystal | 90/142/175 | 0 | 88 | 4/5/7 | 6.1/7.4/10.5 | effect 99/117.2/137.5 | 48/58/67 | 1.72 / 1.39 / 1.40 |
| Air | 78/120/221 | 0 | 0 | 8/12/21 | 3.8/4.6/6.5 | effect 77.4/91.6/107.5 | 44/52/62 | 1.71 / 1.39 / 1.41 |
| Plant | 9/11/13 | 16 | 0 | 1/1/1 | 6.1/7.4/10.5 | effect 81/95.9/112.5 · snare 90/90/90 | 40/42/50 | 1.72 / 1.39 / 1.25 |
| Poison | 83/121/208 | 127 | 0 | 5/7/12 | 5.6/6.8/9.6 | effect 99/117.2/137.5 | 51/61/71 | 1.71 / 1.39 / 1.39 |
| Spirit | -10/-18/19 | 51 | 0 | 5/8/14 | 3/3.7/5.2 | effect 63/74.6/87.5 | 36/42/50 | 1.73 / 1.39 / 1.39 |
| Dark | 38/38/40 | 64 | 14 | 1/1/1 | 6.6/8/11.3 | effect 216/255.6/300 | 115/136/138 | 1.71 / 1.39 / 1.20 |
| Light | -12/-11/-10 | 0 | 0 | 1/1/1 | 5.1/6.2/8.7 | effect 63/74.6/87.5 | 44/52/61 | 1.71 / 1.39 / 1.39 |
| Blood | 0/3/3 | 1 | 0 | 1/1/1 | 5.8/7.1/10 | effect 86.4/102.2/120 | 40/47/55 | 1.72 / 1.39 / 1.38 |

### Kin: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | PASSIVE -6/-6/-8 | 0 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Lava | 12/14/12 | 0 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Lightning | 13/12/13 | 0 | 11 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Water | 37/37/37 | 30 | 1 | 1/1/1 | 2.6/3.1/4.3 | effect 85.7/102.5/141.8 | 68/82/113 | 1.65 / 1.65 / 1.66 |
| Ice | 6/9/7 | 0 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Steam | 2/3/2 | 0 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Earth | 88/105/124 | 0 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Mud | 29/28/30 | 34 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Dust | 93/93/93 | 147 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Crystal | 6/10/8 | 0 | 1 | 3/4/4 | 4.1/4.9/6.8 | – | 16/18/26 | 1.66 / – / 1.62 |
| Air | 24/23/23 | 21 | 1 | 1/1/1 | 2.6/3.1/4.3 | effect 94.3/112.7/156 | 44/52/72 | 1.65 / 1.65 / 1.64 |
| Plant | 19/17/19 | 11 | 8 | 1/1/1 | 2.6/3.1/4.3 | effect 85.7/102.5/141.8 | 74/84/125 | 1.65 / 1.65 / 1.69 |
| Poison | 17/24/28 | 40 | 1 | 12/15/19 | 3.6/4.3/6 | effect 0.9/1/1.4 | 2/4/5 | 1.67 / 1.56 / 2.50 |
| Spirit | 4/5/5 | 0 | 1 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Dark | 8/5/9 | 0 | 2 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Light | 10/4/3 | 0 | 1 | 3/4/5 | 4.9/5.8/8.1 | effect 60/71.7/99.3 | 15/18/25 | 1.65 / 1.66 / 1.67 |
| Blood | 1/0/-1 | 0 | 2 | 0/0/0 | 0/0/0 | – | – | – / – / – |

### Mystic: numbers

| Element | +draws L/D/P | pool particles (P) | lines+strokes (P) | projectiles | contact r | area r (effect/blast/beam/sweep) | drawn r80 (main piece) | growth L→P: contact × / area × / drawn × |
|---|---|---|---|---|---|---|---|---|
| Fire | 326/415/460 | 125 | 8 | 11/15/19 | 8.1/10.8/18 | effect 90/90/90 · snare 62.9/83.5/139.2 | 8/12/14 | 2.22 / 1.00 / 1.75 |
| Lava | 84/82/85 | 19 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Lightning | 15/12/12 | 4 | 18 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Water | 35/34/33 | 13 | 13 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Ice | 89/88/90 | 70 | 38 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Steam | 17/15/14 | 25 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Earth | 26/25/24 | 14 | 10 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Mud | 40/40/40 | 40 | 18 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Dust | 43/41/41 | 56 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Crystal | 35/33/34 | 8 | 10 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Air | 44/48/46 | 9 | 18 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Plant | 108/111/111 | 26 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Poison | 34/36/37 | 14 | 18 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Spirit | 24/24/26 | 20 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Dark | 34/32/34 | 18 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Light | 40/41/41 | 11 | 6 | 0/0/0 | 0/0/0 | – | – | – / – / – |
| Blood | 19/19/19 | 17 | 0 | 0/0/0 | 0/0/0 | – | – | – / – / – |
