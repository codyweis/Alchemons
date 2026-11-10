# Handoff: survival enemy look pass

For an agent picking this up cold. Repo: Alchemons (Flutter), branch master.

## Where things stand (2026-11-09)
- Seven local commits on master, 5540fd22 through 2741254a, on top of
  4582956b. **Nothing is pushed. Do not push without the user saying so.**
- Release 0.11.14+37 built from 2741254a is on the user's Galaxy Fold. The
  user has not yet said what they think of it. Ask before building on it.
- Read first: `docs/audits/survival_true_survival_2026-11-09.md` (the audit,
  what was built, cost, open list) and the frames in the folder of the same
  name. Then the memory notes `project_survival_true_survival`,
  `project_enemy_look_rework`, `project_survival_feel_audit`,
  `feedback_vfx_material_not_lines`, `feedback_flowy_not_bursty`,
  `feedback_never_flutter_install`, `feedback_cpu_parallel_tests`.

## The user's taste (hard constraints)
Dark alchemical, ink and brass, dark only. Effects are material (grains,
glass, steam, ember, ash, ink), never stroked rings, hoops, beams or
wireframe. Motion eases; nothing pops or flashes. A blast's picture matches
its real radius. Deaths dissolve where the body fell. No popups, banners or
new verbs. No `MaskFilter.blur` in per-frame paint. Solids read well only
as near-black obsidian lit by light (core fire, element rim, glints); mid-tone
coloured faces read as cheap. Not released: no compat shims, delete what
you replace.

## Tasks, in order
Do one concern per commit. Visual only unless a task says otherwise.

1. **Elites as their own tier.** Today an elite is an ordinary body at 1.3x
   on a pool of affix colour (`drawEnemy` in
   `lib/games/cosmic/cosmic_enemy_vfx.dart`, `affixColor`). Give elites a
   dark shell with the affix as the light inside it, readable in a crowd of
   several hundred. This file is shared with open space and dungeons, so
   check both still look right. Elites are declined by the swarm atlas
   (`canSimplifySurvivalSwarmEnemy`), so they draw live; keep each inside
   the per-body draw budget in `test/enemy_render_budget_test.dart`.
2. **Tell tiers apart by motion.** A wave's wisps, drones, sentinels and
   phantoms share one element colour (`spawner.waveElement`), and sentinels
   and wisps are hard to tell apart at phone scale. Differentiate by motion
   and silhouette in `lib/games/cosmic/enemy_body_art.dart`. Atlas frames
   must not change pose between frames (the user rejected 9 fps pose
   stepping).
3. **Core bursts.** Bodies bursting on the core draw as white clumps, the
   brightest thing on a late floor (`SurvivalDeaths` blast grains in
   `lib/games/cosmic_survival/survival_death_vfx.dart`, called from
   `_spawnDeath`). Bring them down to the body's own light and let them
   trail rather than pop. This is 11-03 work the user has not judged: ask
   first.
4. **Rooted bodies.** The green vine-wrap on a rooted brute reads as a lit
   lattice (Horn+Plant root wrap in `lib/games/cosmic/horn_vfx.dart`).
   Redraw as filled material.
5. **Boss health off the bar.** `drawSurvivalBoss` draws a bar and a name
   over the body. Propose reading health off the body instead (as
   `lib/games/cosmic/ready_bed_vfx.dart` does for readiness). Mock it and
   ask before removing the bar.
6. **Ask, do not change:** drone wind-up is 0.35 s
   (`lib/games/shared/enemy_action.dart`), under the half second the user
   wants. Lengthening it is a balance change.
7. **Optional, if the user wants marks to last longer near the core:** raise
   `_Tile._caps` and `_smudgeCap` in
   `lib/games/cosmic_survival/arena_wear.dart` (memory cost; tiles are baked
   to 320 px images).

## How to verify
- Frames: `LOOK_OUT=<dir> LOOK_WAVES=3,24,62 flutter test
  test/survival_field_preview_test.dart --tags preview --plain-name "look audit a"`;
  boss: `BOSS_OUT=<dir>` with `--plain-name "boss wave"`; deaths:
  `KILL_OUT=<dir>`; roster: `ENEMY_LOOK_OUT=<dir> flutter test
  test/enemy_look_preview_test.dart --tags preview`.
- Cost: `LATE_COST=1 LATE_WAVES=24,62 flutter test
  test/survival_late_wave_cost_test.dart --tags preview`. Baseline at wave
  62 (1,035 bodies, this Mac, JIT): update about 0.8 to 1.1 ms, draw-record
  about 2.1 to 2.2 ms median. Body counts must stay 344 and 1,035: if they
  move, something drew from the run's Random.
- Tests: `flutter test --exclude-tags preview -j 2 test/survival_*_test.dart
  test/cosmic_survival_*_test.dart test/enemy_*_test.dart` (about a minute).
  Never more than 2 or 3 test processes at once; never a plain
  `flutter test` (it runs hours-long preview reports).

## Traps already hit
- `cosmic_survival_game.dart`, `cosmic_survival_spawner.dart` and
  `cosmic_enemy_vfx.dart` are not `dart format` clean at HEAD. Format only
  new files; hand-format hunks in those three.
- No `git stash`, no `git rm`: the checkout is shared. Commit by path.
- A second `tester.runAsync(AbilityGrainSprite.ensureLoaded)` in one test
  process hangs; guard it with a flag.
- Headless tests do not load creature sprites; the party draws as discs.
- Phone: adb is at `~/Library/Android/sdk/platform-tools/adb`, Fold serial
  R5GL8168WSY. Build `flutter build apk --release --target-platform
  android-arm64`, install with `adb -s R5GL8168WSY install -r`. Never
  `flutter install` and never uninstall: both wipe the save.

## Done means
Before/after frames per task, late-wave cost re-measured, the test set
above passing, what was not seen on a device listed, nothing pushed.
