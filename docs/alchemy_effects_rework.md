# Alchemy effects rework — handoff plan

Written 2026-10-01. The plan is approved.

**Status (2026-10-01): Steps 1, 2 and part of 3 built. 14 effects are on the shared painter in every host, and the old widget, Flame and canvas copies are deleted. Not device-played.**
- **Step 3, the two the user picked:**
  - **Will-o'-Wisps** (`will_o_wisps`, `alchemy.will_o_wisps`, offer `effects.will_o_wisps`, 20g). Four soft marsh lights on slow unrepeating paths. Each is a pale heart in a wide glow, with a short trail and a light pool on the ground beneath it. Each one is in front of the creature or behind it depending on its own depth.
  - **Elemental Dust Ring** (`dust_ring`, `alchemy.dust_ring`, offer `effects.dust_ring`, 35g). Cindrath's `_ParticleRing` recipe at creature scale, in the element's colours (`auraElement`, as the Elemental Aura uses): soft lanes and about 450 fine grains with Keplerian shear and twinkle, far half behind and near half in front. The shop card shows it in Dust.
  - Both have front layers.
  - Renders: `docs/alchemy_effects_step3_*.png`.
  - Evaporating edge was not picked.
- **Step 2:**
  - All 10 remaining effects were rebuilt per §4, one part file each, mostly on `_Atlas` soft grains, with `_ripple` for Blood and a one-path sigil for Golden Rite.
  - Speed's comets and Intelligence's disk have front layers, as Prismatic's ring does.
  - Every host routes every key through `AlchemyEffectPaint`. `InstanceSprite.showAlchemyEffect` is gone, so every list shows effects.
  - `InvKeys.alchemyEffectFor` is the single item-to-effect map, used by the shop preview, the inventory screen and the inventory HUD.
  - Census: at most 14 draws a frame (Wavebreaker); 0 blurs.
  - Renders: `docs/alchemy_effects_step2.png`, `docs/alchemy_effects_step2_in_context.png`, `docs/alchemy_effects_step1_elements.png`.
- **Rounds 1–3 (Step 1), what the user ruled:**
  - Prismatic is bold and colourful.
  - Four-point stars are cheesy, so no star shapes anywhere.
  - The aura shows the creature's own element (or its pigment faction's).
  - Buying an effect only toasts.
  - Effects belong in the grids.
- `lib/widgets/fx/alchemy_effects/`:
  - `alchemy_effect_paint.dart`: the dispatcher plus the shared kit — one `GrainBatch`, the unit-gradient `_pool` and `_ripple`, the unit-path `_shape`, `_hsv`/`_mix`, and `_Atlas` (soft grains and petals in one `drawRawAtlas` call, each its own colour, size and turn, additive on the dark plate).
  - One part file per effect; `elemental_aura.dart` has the 17 element motions on `essenceRamp`/`essencePool`.
  - `alchemy_effect_view.dart`: wraps the sprite as its `child`, painter behind and `foregroundPainter` in front, on `GlyphClock`, in its own `RepaintBoundary`.
- **Prismatic, redirected by the user:** "barely noticeable … should be an awesome prismatic one with awesome colors; the old one was close, just not performant and up to date." It is now bold and colourful:
  - three hues drifting through each other as a glow behind it;
  - 7 soft coloured shafts turning slowly;
  - a tipped ring of 190 rainbow grains (the planet dust-ring recipe) passing behind and then in front of the creature;
  - a spectral pool at its feet.
  - Hues cycle every 12 s. The §4 "restraint" brief for Prismatic is superseded.
- **The `front:` layer exists:** `AlchemyEffectPaint.hasFront(key)` and `paint(front: true)`.
  - Widget: the `foregroundPainter`. Flame: a twin `AlchemyEffectComponent` at priority 1 on the same seed. Space: a second `_drawAlchemyEffectCanvas(front: true)` after each sprite.
  - The orbital-chamber site used to draw its effect at the world origin; it is now translated to the chamber.
- **Element:** the user said "all elements belong in a faction".
  - `SpriteVisuals.elementType` is the creature's first type. `auraElement` is `variantFaction ?? elementType`: a pigment's faction when it has one, else its own element.
  - `CreatureSprite(elementType:)` is passed at every site that shows an effect.
  - The resolver maps a faction to its lead element (Verdant to Plant, Arcane to Spirit) and also knows the legacy 'Pyro'/'Aqua'.
- **Shop:** buying an effect now toasts "<name> added to inventory". It no longer pushes the specimen picker; effects are applied from the inventory. `ShopService.applyEffectToInstance` is deleted.
- Census: `test/alchemy_effects_census_test.dart` covers every key, element, plate, size and both layers (0 blurs; ceiling 16 draws).

**Goal:** bring the 12 shop "alchemy effects" (cosmetic auras applied to an Alchemon) up to the game's new particle and grain style, and make them cheap to render.

**Before:** `docs/alchemy_effects_before.png` shows them in two rows.
- Top row: Glow, Elemental, Volcanic, Void, Prismatic, Golden Rite.
- Bottom row: Blood, Wavebreaker, Beauty, Speed, Strength, Intelligence.

Regenerate the sheet with:

```bash
FX_OUT=/tmp/alchemy_fx.png flutter test test/alchemy_effects_preview_test.dart --tags preview
```

That writes `/tmp/alchemy_fx_0.png` and `/tmp/alchemy_fx_1.png` (every effect as the app shows it), `/tmp/alchemy_fx_painters.png` (each shared-painter key: hero at 4 moments dark, 2 light, then HUD size) and `/tmp/alchemy_fx_elements.png` (Elemental Aura per element on its own Horn), and prints µs per frame. Add `FX_ROWS=1` for 2.5× crops of every row.

---

## 1. What exists today

**12 effects.** The key stored on the creature is in brackets; it must not change (see §3).

| Shop name | key | price | widget file |
|---|---|---|---|
| Alchemical Resonance | `alchemy_glow` | 10g | `alchemy_glow.dart` |
| Elemental Aura | `elemental_aura` | 10g | `orbiting_particles.dart` (class `ElementalAura`) |
| Volcanic Aura | `volcanic_aura` | 10g | `volcanic_aura.dart` |
| Void Rift | `void_rift` | 15g | `void_rift.dart` |
| Prismatic Cascade | `prismatic_cascade` | 100g | `prismatic_cascade.dart` |
| Golden Rite | `ritual_gold` | 5g (unlock: Pureblood Rite) | `ritual_gold.dart` |
| Blood Aura | `blood_aura` | 50g | `blood_aura.dart` |
| Wavebreaker Crown | `wavebreaker_crown` | 50g (unlock: survival wave 50) | `wavebreaker_crown.dart` |
| Beauty Radiance | `beauty_radiance` | 40g (contest unlock) | `beauty_radiance.dart` |
| Speed Flux | `speed_flux` | 40g (contest unlock) | `speed_flux.dart` |
| Strength Forge | `strength_forge` | 40g (contest unlock) | `strength_forge.dart` |
| Intelligence Halo | `intelligence_halo` | 40g (contest unlock) | `intelligence_halo.dart` |

The widget files live in `lib/widgets/animations/sprite_effects/`.

**Three copies of every effect (36 in all), and they have drifted apart:**

1. **Flutter widgets:** `lib/widgets/animations/sprite_effects/*.dart`, each with its own AnimationControllers. Some rebuild 10+ Containers with `BoxShadow` every frame.
2. **Flame components (wilderness):** `lib/games/sprite_effects/sprite_*_component.dart` (and `sprite_glow_component.dart`, `sprite_volcanic_aura.dart`).
3. **Space companion canvas painters:** private `_draw*Canvas` functions in `lib/games/cosmic/cosmic_game_helpers.dart`, lines ~5–830, dispatched by `_drawAlchemyEffectCanvas` (~L827). It is called from 4 sites in `lib/games/cosmic/cosmic_game.dart` (~L6429, 6538, 7345, 7528).

**Hosts and switch statements to rewire:**

- **Shop and inventory previews:**
  - `lib/services/shop_service.dart` `getAlchemyEffectPreview` (~L183) builds the preview widgets.
  - `lib/screens/shop/shop_widgets.dart` wraps them in `StaticEffectSnapshot` (~L686–851). This is a frozen t=0 bake; keep it.
- **`lib/widgets/creature_sprite.dart`:**
  - `CreatureSprite._buildEffectLayer` (~L296) serves details, party and HUD screens.
  - `InstanceSprite._buildEffectLayer` (~L524) serves small slots. Grids already pass `showAlchemyEffect: false`.
- **Flame:** `lib/widgets/wilderness/creature_sprite_component.dart` `_buildEffectComponent` (~L188).
- **Space:** `cosmic_game_helpers.dart` `_drawAlchemyEffectCanvas`.
- **Sizing helpers:** `lib/utils/effect_size.dart`. Prismatic has its own sizing functions.

**Problems:**

- **Look.** Almost everything is built from rings, dial ticks, spokes and flat discs.
  - Volcanic, Void, Blood and Strength each sit a coloured coin behind the creature, so they read as stickers.
  - Golden Rite and Beauty read as clock faces, and Speed reads as a loading spinner.
  - Prismatic, the most expensive at 100g, is the worst: its blurred glow washes far past the creature.
  - Elemental is 5 tiny dots that barely register.
- **Performance.** Blur passes per creature per frame:
  - widget versions: Golden Rite ~36, Wavebreaker ~26, Prismatic ~20, Intelligence ~18, Beauty ~15, Speed ~12;
  - Flame and space versions: similar.

  `MaskFilter.blur` (and `BoxShadow`/`blurRadius`) is this game's #1 jank source. The 11 blur sites left in `cosmic_game_helpers.dart` after the 2026-09-29 space blur purge are these effects.

---

## 2. Target architecture

**One plain-Dart painter per effect, shared by all three hosts.** Follow the pattern of `PowerOrbPaint.paint` (`lib/widgets/fx/power_orb.dart`) and `EssenceField` (`lib/widgets/fx/elemental_essence.dart`).

- **New folder:** `lib/widgets/fx/alchemy_effects/`.
  - One file per effect, plus `alchemy_effect_paint.dart`. That file holds a single dispatcher:

    ```dart
    abstract final class AlchemyEffectPaint {
      /// center = creature centre; r = effect radius (today's "size");
      /// t = seconds; element = variant faction (Elemental Aura only);
      /// opacity = host fade.
      static void paint(Canvas c, String key, Offset center, double r, double t,
          {String? element, double opacity = 1});
      static bool has(String key);
    }
    ```

  - If an effect needs layers both behind and in front of the sprite, add a `front:` flag. Keep this rare; behind-only is the default.
- **Host adapters:**
  - **Widget:** an `AlchemyEffectView(effectKey, size, element)` CustomPainter. It runs on the shared `GlyphClock` (`lib/widgets/fx/glyph_clock.dart`) and respects `TickerMode`; the power orb does exactly this. Replace both `_buildEffectLayer` switches and `getAlchemyEffectPreview` with it.
  - **Flame:** one `AlchemyEffectComponent` that calls the painter in `render`, replacing the 12 `sprite_*_component.dart` files.
  - **Space:** `_drawAlchemyEffectCanvas` becomes a call to `AlchemyEffectPaint.paint`.
- **Deletions:** remove the 12 old widget files, the 12 Flame components and the `_draw*Canvas` helpers once nothing references them. Check with grep for the class names.
- **Hard rules for every painter:**
  - **Zero `MaskFilter.blur`, zero `BoxShadow`, zero `Shadow(blurRadius:)`.** Instead:
    - use `paintSoftCircle` / `paintSoftRing` / `GlowDots` from `lib/games/cosmic/planets/planet_art.dart` (~L1207–1248);
    - or use layered translucent fills: wide and faint underneath, narrow and bright on top.
  - **Batch the grains.** Draw them with `drawRawPoints` / `drawAtlas` / `GlowDots`, not a `drawCircle` loop. Aim for ≤ ~15 draw calls per effect per frame.
  - **No allocation in paint.** Precompute grain seeds once per effect type in static lists; derive everything else from `t`.
- **Pin it with a test:** add a draw census test that paints every key into a counting canvas and asserts 0 blurred paints and a draw-call ceiling. See `test/constellation_render_budget_test.dart` for the counting-canvas pattern.

---

## 3. Constraints (from the user, learned on earlier reworks)

- **Keep every key string exactly as it is.** Effects players already own must upgrade in place. Do not touch the DB, inventory keys or shop offer IDs.
- **Material, not lines.** Avoid stroked hoops, full circles, dial ticks, radial spokes and hairlines; they read as cheesy UI. Use filled tapered shapes, grains, and light as radial-gradient pools. Helpers are in `lib/games/cosmic/vfx_shapes.dart`: `vfxBlob`, `vfxCrescent`, `vfxRibbon`, `vfxSpiralArm`, `vfxDrop`, `vfxLeaf`, `vfxShard`.
- **Nothing busy around the creature.** On the Enhance infusion the user called orbiting stuff around the mon cheesy, three times. So:
  - keep effects close to the body, lopsided, drifting rather than orbiting in perfect circles;
  - weight them behind the creature and at its feet: ground pools, things rising from below;
  - symmetric rings of anything read as a badge.
- **Style:** dark, alchemical, soft and mystical rather than crisp or cartoony. The particle dust ring and the grain black hole (`lib/widgets/fx/rift_vortex.dart`) were loved. Reuse those recipes.
- **No flat disc behind the sprite, ever.**
- **Must read at small sizes too:** party HUD (~40–56 px slots) as well as the details hero (~110–190 px). Render both sizes in the preview sheet.
- **Light theme:** pale effects wash out on the parchment plate. Render a light-plate variant like `ESSENCE_LIGHT=1` in `test/elemental_essence_preview_test.dart`.

---

## 4. Per-effect spec

The user approved this direction. Build in this order:

**Step 1 — shared painter plus the two worst offenders.** Render a preview and show the user before doing anything else.

1. **Prismatic Cascade** (rebuild; highest price, worst look, most expensive). Clear glass prism motes drift slowly upward and around the body. Each one occasionally splits into a short spectral smear: red→violet in 3–4 grains, a dispersion. Add a faint pale-white light pool at the feet. Hue appears only in the split grains, never as a giant wash. This should feel like the rarest effect because of restraint and sparkle quality, not size.
2. **Elemental Aura** (rebuild as particles). Element-coloured grains whose motion is that element's essence form, at aura scale and low density. Take the colours from the per-element `_Look` ramps in `lib/widgets/fx/elemental_essence.dart`. Motion per element:
   - **Fire:** embers rise.
   - **Water:** droplets roll and bob.
   - **Earth:** grit settles at the feet.
   - **Air:** wisps curl.
   - **Steam:** puffs billow up.
   - **Lava:** drips with glowing crust specks.
   - **Lightning:** grains that jump position every ~75 ms.
   - **Mud:** slow drops.
   - **Ice:** frost flecks drifting down.
   - **Dust:** blows downwind.
   - **Crystal:** a few small faceted glints standing off.
   - **Plant:** tiny leaves/spores rising.
   - **Poison:** bubbles that rise and pop.
   - **Spirit:** faint wisps rising.
   - **Dark:** grains sinking into a small void pool at the feet.
   - **Light:** uneven soft rays.
   - **Blood:** droplets on a lub-dub pulse.

   `element` comes from `instance.variantFaction`, falling back to Arcane/neutral. Hosts already pass it.

**Step 2 — the rest.**

3. **Volcanic Aura** (rebuild). Embers and ash rise off the creature's shoulders, and a molten glow pools at the feet, with a little heat shimmer suggested by wavering grain columns. No disc.
4. **Void Rift** (rebuild). A small grain black hole behind the creature (the `rift_vortex.dart` recipe): dark violet grains spiral into a point, with a faint bright accretion lip. It sits behind and slightly below centre, not as a halo.
5. **Golden Rite** (rebuild; the biggest perf win). A gold alchemical sigil lying flat on the ground under the feet: a foreshortened ellipse, drawn as filled glyph shapes, not stroked rings. Gold dust motes rise slowly from it.
6. **Blood Aura** (rebuild). Matches Blood's essence: a deep red light pool that beats lub-dub, with occasional droplets falling from the body. Dark, not a red coin.
7. **Wavebreaker Crown** (small changes; the trophy identity is good). Keep the 3-point crown above the head and the 5 shards, which stand for the five 10-wave gauntlets. Delete both broken rings. Make the shards filled amber/cyan glass with a catchlight, drifting lopsidedly near the head, and keep the crown filled rather than stroked.
8. **Contest four**: match the stat signatures of the new power orbs in `lib/widgets/fx/power_orb.dart`, so a contest reward looks like its stat:
   - **Beauty Radiance:** rare soft glints and a few petal-shaped light motes drifting; warm rose/gold light pool.
   - **Speed Flux:** two or three grain comets that whip past the creature on lopsided paths and fade; no spokes, no arcs.
   - **Strength Forge:** embers plus a heartbeat throb of warm light at the core and feet; no hexagons.
   - **Intelligence Halo:** a small tilted disk of fine grains orbiting above or behind the head (a planetary-ring look); no segmented rings or hexagram lines.
9. **Alchemical Resonance** (glow; small changes only). Keep the soft radial light. Slow the 1 s, 0.4→1.2 pulse, which reads as strobing, to ~3 s with a much smaller scale range. Shift it into the game's palette.

**Step 3 — new particle effects.** Optional; ask the user which ones they want first. Each new one needs a shop offer and inventory key; follow the existing `effects.*` offer pattern in `shop_service.dart` ~L736.

- **Will-o'-wisps:** 3–4 soft lights wandering lazily near the creature. Cheap and lovely.
- **Dust Ring:** a tilted ring of orbiting dust, the planet dust-ring recipe the user loved.
- **Evaporating edge:** the creature's own silhouette sheds grains like smoke. This needs the sprite's grains: `SpecimenGrains` in `lib/widgets/fx/fusion_particles.dart`, captured as `ElementalEssence` does it. It is a heavier host integration, so do it last.

---

## 5. Verification

1. **Preview sheet.** Extend `test/alchemy_effects_preview_test.dart` to paint each key through `AlchemyEffectPaint`:
   - several time steps;
   - details size (~110) and HUD size (~48);
   - dark and light plates;
   - plus a µs-per-frame timing print, as in `test/power_orb_preview_test.dart`.

   **Look at the PNG before calling anything done.** Show the user the Step 1 render before moving on.
2. **Census test:** 0 blurred paints and a draw-call ceiling per key (§2).
3. **Run it:** `flutter analyze` plus the existing tests that touch `creature_sprite`, the shop and cosmic.
4. **Device:**
   - **NEVER use `flutter install`.** It uninstalls first and wipes the save.
   - Back up the save first with `run-as`, then build and install with `adb install -r`.
   - If the phone or hot-reload session is down, say so and wait for the user to say "ready".
5. **Where to check on device:**
   - a creature's details screen;
   - the party HUD in the wilderness, with an effect on a party member;
   - a space companion wearing an effect;
   - the shop effect cards (frozen snapshot).
