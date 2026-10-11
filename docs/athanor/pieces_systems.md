# Athanor pieces: case styles, trails, fusion styles, home ambiences

The four kinds from `docs/crucible/cosmetics_concepts.md` that had no system
yet, built and wired. All four are owned through `OwnedCosmetics`
(`cosmetics_owned_v1`), which `AthanorService` already grants into; what is
*worn* is kept by `CosmeticWearService`. None is sold in the shop. Batch ids
follow `pieces_wearables.md`: `black`, `white`, `yellow`, `red`, `still`.

| Batch | Piece id | Name | Kind | Rarity | grantRef | Description |
|---|---|---|---|---|---|---|
| The Black Work | `black.obsidian_case` | Obsidian Case | `caseStyle` | common | `obsidian` | A specimen case of black glass with a faint oil-slick sheen across it. |
| The Black Work | `black.ink_fusion` | Ink Fusion | `fusionStyle` | epic | `ink` | Fusing runs the two together like ink in water, into a dark spiral that blooms. |
| The Black Work | `black.peat_mist` | Night Mist | `ambience` | epic | `peat_mist` | Low violet mist drifts along the ground of a home realm at night. |
| The White Work | `white.frost_case` | Frost Case | `caseStyle` | common | `frost` | A specimen case with frost grown in from its corners and cold light above. |
| The White Work | `white.frost_fusion` | Frost Fusion | `fusionStyle` | epic | `frost` | Fusing turns the two to frost, grows them into one crystal, and lets it fall away as snow. |
| The White Work | `white.hoarfrost_steps` | Frost Steps | `trail` | epic | `hoarfrost_steps` | Frost blooms on the ground where it walks at home, then melts. |
| The White Work | `white.moonlit_snowfall` | Snowfall | `ambience` | epic | `moonlit_snowfall` | Fine snow falls on clear nights in a home realm. |
| The Yellow Work | `yellow.gilt_case` | Gold Case | `caseStyle` | common | `gilt` | A specimen case backed with gold leaf, lit by a lamp above. |
| The Yellow Work | `yellow.gilt_fusion` | Gold Fusion | `fusionStyle` | epic | `gilt` | Fusing turns the two to gold leaf that swirls in a double helix and folds into one. |
| The Yellow Work | `yellow.gilt_steps` | Gold Steps | `trail` | epic | `gilt_steps` | Gold dust lifts where it walks at home and settles in small glints. |
| The Yellow Work | `yellow.sun_motes` | Dust Motes | `ambience` | epic | `sun_motes` | Warm dust drifts in the daylight in a home realm. |
| The Red Work | `red.garnet_case` | Garnet Case | `caseStyle` | common | `garnet` | A specimen case of deep garnet glass, lit from below. |
| The Red Work | `red.ember_fusion` | Ember Fusion | `fusionStyle` | epic | `ember` | Fusing heats the two into embers that rise as two flames and burn down to one core. |
| The Red Work | `red.ember_fall` | Rising Embers | `ambience` | epic | `ember_fall` | Embers drift up from the ground at dusk in a home realm. |
| The Still-Room | `still.brass_case` | Brass Case | `caseStyle` | common | `brass` | A specimen case with a brass instrument plate behind it and a lamp above. |
| The Still-Room | `still.distilled_fusion` | Steam Fusion | `fusionStyle` | epic | `distillation` | Fusing lifts the two as vapour that condenses and drips into one pool. |

16 pieces: 5 case styles and 5 fusion styles (common, one per batch), 2
trails and 4 ambiences (epic). The grantRefs are the ids of `CaseStyle`,
`TrailStyle`, `FusionStyle` and `HomeAmbience` in
`lib/models/cosmetic_wear.dart` (`byId` reads them back).

## The systems

| Kind | Worn | Stored (settings row) | Chosen | Drawn |
|---|---|---|---|---|
| Case style | per creature | `case_style_worn_v1` `{instanceId: id}` | creature details, the CASE square under WHAT IT WEARS (`WornLooksRow`) | `SpecimenCase` (Creatures tab and the specimen picker) draws `CaseStylePainter` in the plain light's place |
| Trail | per creature | `trail_worn_v1` `{instanceId: id}` | creature details, the TRAIL square | home field: a print every 0.55 of its size walked, alternating feet, on its row's ground under keepsakes and residents (`home_cosmetics.dart`, a part of `scene_game.dart`) |
| Fusion style | one, global | `fusion_style_v1` (bare id) | profile, DISPLAY → FUSION (`FusionStyleChoice`) | inside the shared fields, so every fusion spot plays it: `FusionParticleField` (the merge: breed tab, space ram, wild, Codex) and `FusionBurstField` (the cinematic), via `FusionStyle.worn` |
| Ambience | per home realm | `ambience_worn_v1` `{realm: id}` | home, Arrange → settings row: NO AMBIENCE + one chip per ambience owned | home field and the home screen's window: over the near row (under its front grass), mist also on the far row; only at its hour |

- Every row decodes defensively (junk, wrong types, unknown ids are left out)
  and travels with the save. A worn id that is not owned is never shown, so
  a restore that loses an item shows the plain look; the choice comes back
  if it is owned again.
- `CosmeticWearService` (provided in `app_providers.dart`, not lazy, reloads
  when the Athanor notifies and in `reloadStateAfterSaveRestore`) refuses to
  wear anything not owned.
- Hours: Night Mist 18:00–07:00 (eased), Snowfall 19:30–06:00 and only
  with no weather, Dust Motes 07:00–19:00, Rising Embers 16:30–22:00. The pinned
  hours DAWN/DAY/SUNSET/NIGHT each show at least one.
- Ambiences never announce themselves: no snack, no label on the field
  (tested).
- Previews for the Athanor (`paintCosmeticPreview` in
  `lib/widgets/fx/cosmetics/cosmetic_previews.dart`, called from
  `athanor_piece_art.dart`) are the same painters the pickers use. Trail and
  ambience tiles have their light lifted before a pour reads them into
  grains.

## Renders

`docs/athanor/content/systems/` — rerun with
`ATHANOR_SYSTEMS_OUT=docs/athanor/content/systems flutter test -j 1 <file> --tags preview`:

- `test/athanor_systems_preview_test.dart`: `cases.png` (all five on six
  species, three rows), `cases_close.png`, `trails.png` (four moments,
  two species each), `trails_close.png`, `previews.png` (every tile at grid
  and detail size), `ambience_sketch.png`.
- `test/athanor_home_cosmetics_preview_test.dart` (the real home screen):
  `home_<ambience>_<realm>_<hour>.png` for each ambience at its hour and at
  one where it does not show, and `home_trails_<realm>_12.png`.

## Cost (desktop JIT, recording only)

- A case: 15–50 µs to draw (Frost 190 µs), then replayed from a cached
  picture (~3 µs). The case is still; it repaints only on change.
- Trails: one field layer is two atlas draws; 12 creatures × 10 prints alive
  ≈ 150–175 µs a frame (the usual case, a few prints, is a few µs).
- Ambience: 20–75 µs a frame, one or two `drawRawAtlas` per row layer, at
  most a few hundred soft grains. No blur, no strokes, no text.
- Fusion styles (desktop JIT, recording only, a real pair): the merge
  370–730 µs a frame against the plain merge's 310; the cinematic 200–330
  µs against 145. Draws stay a few per color (under 110), no blur.
- Athanor tiles: 3–37 µs each per frame when animated.

## Fusion styles

They replace the sigil finishes (the author, after playing: recolouring the
octagram was not enough). Each is a whole way of fusing, built inside the
shared fields (`lib/widgets/fx/fusion_style_merge.dart`, a part of
`fusion_particles.dart`; `fusion_style_burst.dart`, a part of
`fusion_burst.dart`; materials in `fusion_style_kit.dart`). Up to the stand
(`standTime`) a styled merge is exactly the plain one, so the hold, the run
back and the knock-back work for every style; it still ends in the orb, and
the cinematic still settles into the same turning cultivation by
`settledAt`, with no sigil. Nothing chosen plays the fusion as it was.

| Style | The merge | The cinematic |
|---|---|---|
| Ink | soaked through by a front from the orb's side, each is let go like a drop into still water: a rolling mushroom cap (two lobes winding up their own sheet) pushes toward the orb with tendrils trailing back; the caps meet, spread and marble in a slow shear; all of it carried by a curling divergence-free flow (`InkFlow`, a lattice laid once a frame) — dark where thick, its own color where thin, a haze/body/fine layering against a faint light in the water | one dark marbled bloom (the two inks in regions bounded by slow waves) opens into lopsided billows with rolling edges, gathers into the cultivation as ink, and its colors come back as each grain arrives |
| Frost | feathered frost grows across each body from the side facing the other — a fan of rays, each a spine with branchlets at uneven angles, grains accreting as the growth reaches them, fresh grains bright, a slow glitter band over the crust; the two ferns reach for each other and lock into one mass | the mass, two fans meeting, turns a little; its tips sublime first into fine snow drifting on a slow flow, which settles into the cultivation |
| Gilt | each is cut into thin leaves of gold (two-toned: bright face, old-gold back, a flash as each turns full to the light) that lift off nearest-first, tumbling and spinning, onto a slow vortex with depth — a leaf-storm of both | the storm opens, the leaves are laid flat on the sphere (lit as it is lit), and a burnish sweeps across and leaves its colors behind |
| Ember | each catches from the side facing the other; every grain a parcel of flame rising on its own buoyancy through a quick curling flow, cooling white → yellow → orange → red → ash, sparks spiralling; the later it caught the more it leans into the other, so the two fires merge into one blaze that falls into a reheating coal | a white-hot coal with a red edge flickers; tongues flare off it and rise (swaying, not drifting), cooling to ash; the coal swells into the cultivation as it cools; nothing lingers |
| Distillation | each thins to steam rising on a slow flow; it beads into drops under the glass, one specimen's water to a drop; each swells, necks and lets go, falls, and its landing rings out across the pool | the last drops fall and ring the pool; the pool draws itself up, middle first, into the cultivation |

Strips (twelve moments, two pairs, beside the plain fusion):
`docs/athanor/content/fusion/<pair>_<style>.png`, plus
`<pair>_<style>_motion.png` (16 frames 1/30 s apart at the meeting, then
at the bloom), from
`FUSION_STYLES_OUT=docs/athanor/content/fusion flutter test -j 1 test/fusion_styles_preview_test.dart --tags preview`.
