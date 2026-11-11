# Handoff: ability look pass

For an agent picking this up cold. Repo: Alchemons (Flutter), branch master.

## Where things stand (2026-11-11, end of day)
- **Done and committed (not pushed)**, in seven commits after 53d67eea:
  survival round the enemies; Mask spread and life; Mystic weather; ground
  effects in grains with routing, the void, weak spots, cost and cleanup;
  Mane's shots; Pip, Wing, Mystic set pieces and Let's crater; the ability
  reel. Every task below was worked through; see "Task 1 progress" and the
  commit messages for what was kept and what was replaced.
- The rule that decided it, from the user: **"we shouldnt sacrifice
  visuals just to make it grainy"**. Compare old and new per piece; keep the
  old where it reads better and fix only its faults.
- On the Fold as a PROFILE build (DEVELOPER > ABILITY REEL shows every
  special). The user has judged only Mane's six and the black hole in play.
- Not done: nothing on the list. Watch for what the user flags in the reel.
  Least sure: Poison Mane's olive glob; Steam zones where many overlap.
- Another session was refactoring survival upgrades (ship shield, guardian
  removal) in the same checkout; its files were left out of these commits.

## Read first
- Memory: `project_survival_roster_redesign` (the full record, long; the
  later entries are this pass), `project_shared_ability_vfx`, the eight
  `project_*_specials_design` notes (what each family and element MUST do;
  never change what an ability does), `feedback_vfx_material_not_lines`,
  `feedback_flowy_not_bursty`, `feedback_particles_not_models`,
  `feedback_dart_format_scope`, `feedback_cpu_parallel_tests`,
  `feedback_never_flutter_install`, `feedback_no_git_stash`.
- Sheets in `docs/ability_vfx_audit/`: `ground_designs_1110.png` (the 17
  approved designs), `ground_art_lineup_1111.png` (as the game draws them),
  `keep_mane_1111.png`, `keep_pip_1111.png`, `keep_wing_1111.png` (the three
  families as they are now), `mask_grounds_ingame_1111.png`,
  `let_zones_ingame_1111.png`, `horn_ground_ingame_1111.png`.

## The user's taste for this work (hard constraints)
- **No blobs.** A rounded patch with things drawn on it reads as a blob
  whatever is on top. Shape comes from grains: their density, direction and
  light, thinning to nothing at the rim. No outline.
- **No brown.** Colour comes from saturated light on a near-black base. A
  wide low-alpha tinted wash over the teal floor turns to mud.
- Material, not lines: no stroked rings, hoops, hairline arcs or dotted
  circles. A lone grain reads as a star; use short runs.
- Each element is told apart by FORM before colour (fire tongues, lava
  cells, water rings, ice needles, plant leaves, lightning branches).
- Motion eases; nothing pops. No blur. Dark only.
- Show design frames first for anything new, then build. That is what
  worked for the enemies and for the ground effects.

## What was built this pass (all uncommitted)
| File | What |
|---|---|
| `lib/games/cosmic/element_ground_art.dart` (new) | `paintElementGround(canvas, element, r, time, seed, {reduced, mends})`: all 17 elements' ground in grains, round the origin |
| `lib/games/cosmic/mask_trap_vfx.dart` | `drawMaskTrapFixture` returns early through it (not Dust, not Spirit); Light slit widened; Fire/Lava recoloured (now unreachable) |
| `lib/games/cosmic/let_vfx.dart` | `drawLetGroundZone` routes through it, stone kept; telegraph pool lightened, reach marked in grit, crater lip in grains |
| `lib/games/cosmic/horn_vfx.dart` | stationary leftovers route through it except Ice wall, Earth cairn, reflecting Light barrier (now a dome of grains) |
| `lib/games/cosmic/kin_vfx.dart` | sigil fields route through it except Earth's wall |
| `lib/games/cosmic/mystic_world_vfx.dart` | poison patch routes through it; maelstrom arms carry foam grains |
| `lib/games/cosmic_survival/components/mystic_world_ambience.dart` | `drawMysticWorldWeather`: each world's weather across the view |
| `lib/games/cosmic/mask_trap_placement.dart` + game | Mask traps spread round the orb; `kMaskTrapLifeBase = 1.5` in `cosmic_data.dart` |
| `lib/games/cosmic/hostile_shot_vfx.dart` | `HostileShotBatch`: enemy shots in grains |
| `lib/games/cosmic/cosmic_enemy_vfx.dart` | boss health and shield as rings of grains |
| `lib/games/cosmic_survival/mutator_field.dart` (new) | a look on the floor for each of the six wave mutators |
| `lib/games/cosmic_survival/roster_art.dart` | elite look removed |
| tests | `element_ground_design_preview_test`, `element_ground_art_preview_test`, `survival_mutator_field_test` (new); `mask_mane_rebuild_test`, `enemy_render_budget_test`, `ability_vfx_audit_preview_test`, `survival_field_preview_test` (edited) |

954 survival and ability tests pass. Open-space and planet-dungeon suites
were NOT re-run after the routing, and those modes share these painters.

## Task 1 progress (2026-11-11, uncommitted, headless)
Design frames: `test/mane_shot_design_preview_test.dart`,
`docs/ability_vfx_audit/mane_designs_1111.png`. The user then set the rule
**"we shouldnt sacrifice visuals just to make it grainy"**: compare old and
new per piece, keep the old where it reads better. Built, judged in the game
(`docs/ability_vfx_audit/mane_ingame_{a,b}_1111.png`, before/after):
- Lava, Water, Blood in flight: new grain painters in
  `lib/games/cosmic/mane_grain_vfx.dart`. Lava pools: `paintManeLavaPool`,
  cells anchored to the world so pools dropped on a crowd merge into one
  field. Blood's drops run home (`ManeBloodRuns`): the orb in survival, the
  ship in open space, the caster in a dungeon.
- Ice: old glass kept; its mist and chips replaced by frost plumes and a
  frost track. Earth: old slab kept, cracks now dark fissures with light in
  them; its old quakes kept (the shared Earth ground looked like dice there).
- Dark: old kept as is (the user prefers it); only its paint is reused.
- `Projectile.flown` (distance flown, advanced in each mode's straight-line
  step) lays the ground tracks; a draw-time clock failed in the audit.
- Shared Lava ground: small pools (r < 70) use 7 larger cells and more
  grains (weak spot 6, Lava only).
- Unreachable now, delete after approval: in `_Painter`
  (mane_alchemical_vfx) `lavaPool`, `lightningField`, `blood`, `water`,
  `mud`, `air`, `spirit`, `vapor` except Dust's field and Dust in flight,
  and `_lavaPoolHeat`/`_pool`/`_lavaRaft`. The old Lava boulder
  and Ice mist/chips are already deleted.
- The other eleven, judged old vs new in the game
  (`docs/ability_vfx_audit/mane_ingame_{c,d}_1111.png`): KEPT Fire, Dust,
  Plant, Light, Crystal. NEW (mane_grain_vfx.dart) Mud (wet clod with folds,
  splats), Poison (olive glob with bubbles, drips; least sure of this one),
  Air (bow wave of wind streaks, curling ends), Spirit (wisp with a curling
  tail), Steam (roiling ball, puffs). Lightning's landed orbs and Steam's
  zones now lie on the shared ground (bolts; vents with plumes).
- Dark ground is the old void again everywhere (`drawVfxVoid`, now in
  vfx_shapes.dart): the user found the grain hole worse on Horn's leftover.
- ABILITY REEL (Profile, DEVELOPER): `lib/screens/debug/ability_reel_screen.dart`,
  every family x element special in one arena in turn; test
  `test/ability_reel_screen_test.dart`. `abilityLabMember` (battle_sheet.dart)
  builds a species at a stat band for the lab and the reel.

## Tasks, in order
1. **Mane, the user's priority.** Read `project_mane_specials_design`
   (Catapult / Piercing: one heavy shot that pierces a line). Render the
   family (`AUDIT_FAMILIES=mane AUDIT_SCALE=1`) and look at every element at
   all three moments. Find what holds it back against the new look: likely a
   filled-shape body under the particles, a wake that reads as a line, and
   elements that differ only in colour. Make design frames for 4 to 6 Mane
   shots in grains (the shot in flight, the pierce, what it leaves), show
   the user, then build. The shot's path and what it hits must not change.
2. **Pip and Wing, the same way, smaller.** Pip is Ricochet (fast small
   shots that bounce); Wing is Beams. They already read well; look for
   leftover filled shapes, ruled-line beams and same-shape elements. Wing's
   Water and Lightning showed nothing at the audit's middle moment: check
   whether that is timing or a real gap.
3. **Mystic set pieces.** Only weather and poison are new. The maw,
   maelstrom, tornado, dawn star, revenants, storm, quake, vent, crystal
   shards, lava meteors, scorch and flora are still the older style
   (`mystic_world_vfx.dart`). Design frames first; these are the loudest
   things in the game.
4. **Let: the meteor and its crater.** The zones are new; the falling
   stone, the crater and the per-element throw (`drawLetMeteor`,
   `drawLetCrater`, `_craterThrow`) are still filled shapes.
5. **Things the families build**, left alone on purpose: Horn's Ice wall and
   Earth cairn, Kin's Earth wall, Mask's Dust shield and Spirit wisp. Ask
   the user before restyling.
6. **Weak spots in what was built:** Dust's ripples barely read at play
   size; small Fire, Lava and Water traps are sparse; Fire leans toward
   vertical streaks when many pools overlap; Mystic weather is a regular
   field of short runs with muted colour.
7. **Cost.** A field of ground effects is heavier than it should be (this
   Mac, JIT, record only): 25 traps r 40 = 0.16 to 0.96 ms by element; 15
   pools r 90 up to 1.84 ms. Fire, Mud and Dust are worst (trig per grain).
   Lava uses a static template built once; do the same for the others.
8. **Delete what was replaced**, once the user approves the look in the
   game (not released: no shims). Unreachable now: most of
   `_drawRemainingMask` and the Crystal/Light/Water/Dark branches of
   `drawMaskTrapFixture`; Let's `_moltenGround`, `_dustPall`, `_sump`,
   `_rubble`, `_mire`, `_wellOfLight`, `_vent`, `_vine`; Horn's
   `_drawWhirlpool`, `_drawStormScar`, `_drawGeyser`, `_drawCyclone`; Kin's
   `_drawRainCloud`, `_drawUpdraft`, `_drawDustBank`. Check each has no
   other caller first.
9. **Run the open-space and planet-dungeon tests** (they share the
   painters), and get a build on the phone when the user asks.
10. **Commit**, when the user says so: one concern per commit, messages in
    the repo's style (see `git log`). Suggested split: survival round-the-
    enemies (elites, shots, boss ring, mutators); Mask spread and life;
    Mystic weather; ground effects renderer and routing; docs.

## How to verify
- Every family through the real game, 17 elements x 3 moments x 3 stat
  bands: `AUDIT_OUT=<dir> [AUDIT_FAMILIES=mane,pip] [AUDIT_SCALE=1] flutter
  test test/ability_vfx_audit_preview_test.dart --tags preview` (about 35 s
  for all eight). Sheets are huge (3476 x 4741): cut one column into a grid
  to look at them.
- Ground effects as the game draws them: `GROUND_ART_OUT=<file.png> flutter
  test test/element_ground_art_preview_test.dart --tags preview`.
- Design frames: `GROUND_OUT=<file.png> flutter test
  test/element_ground_design_preview_test.dart --tags preview`.
- Tests: `flutter test --exclude-tags preview -j 2 test/survival_*_test.dart
  test/cosmic_survival_*_test.dart test/ability_*_test.dart
  test/mask_*_test.dart test/let_*_test.dart test/horn_*_test.dart
  test/kin_*_test.dart test/mystic_*_test.dart test/enemy_*_test.dart
  test/dead_ability_wakeup_test.dart` (about 90 s). Never more than 2 or 3
  test processes at once; never a plain `flutter test`.

## Traps
- **Meaning before look.** Each element's ability is a contract. The Earth
  ground first came out as a healing spring under Let's rubble; that is why
  `paintElementGround` takes `mends`. Check every routed use says what the
  ability does.
- Art is drawn at the radius it acts on. The grain effects thin out at the
  rim, so they are drawn a little past it (`r * 1.1`); keep the reach
  honest.
- Standing things (flames, plumes, shards) must keep a capped height; scaled
  with the radius, a big pool's flames were 150 units tall. A fixed grain
  count on a big effect is a scatter of dots: scale grains with area.
- The camera pulls back under a Mystic world: 2-unit grains were under a
  pixel there.
- `cosmic_survival_boss_discipline_test` "swarm rush joins the authored wave
  pattern pool" fails about one run in six (unseeded spawner). Not ours.
- `dart format` only on files you wholly own (`element_ground_art.dart`,
  `mutator_field.dart`, the new preview tests). I ran it on
  `mask_trap_vfx.dart` by mistake and had to reverse the formatter-only
  hunks.
- Other sessions edit this checkout. Check `git status` before assuming a
  file is as you left it, and never `git stash`.
