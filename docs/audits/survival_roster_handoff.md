# Handoff: survival roster redesign

For an agent picking this up cold. Repo: Alchemons (Flutter), branch master.

## Where things stand (2026-11-10)
- Survival's enemies were replaced by twelve "kinds" drawn in grains and
  stream tubes, the look of the hatch ceremony and the wild harvest. Five
  bosses are designed but not built.
- **Nothing is committed and nothing is pushed.** Do not commit or push
  without the user saying so. HEAD is 7c725189.
- Release 0.11.14+37, built from the uncommitted working tree, went on the
  user's Galaxy Fold at 09:44 on 2026-11-10 (save kept). **The user has not
  said what they think of it. Ask before building further on the look or the
  balance.**
- The tree also holds another session's uncommitted edits to
  `lib/games/cosmic/boss_forms.dart`, `enemy_body_art.dart`, `enemy_mesh.dart`
  and `test/zz_mock_brute_gunner_test.dart`. They are not part of this work.
  Leave them alone and never `git stash` (shared checkout).

## Update 2026-11-10, after the Fold build
The user's verdict: some enemies looked static with their grains too far
apart, death aftermath stayed too long and hid the essence, and enemies just
appeared. Fixed, still uncommitted and not on a device: death marks fade in
2.4 to 4.5 s (`arena_wear.dart` `_Fresh`), essence grains glow, hover and
twinkle (`surge_grains.dart`), bodies are denser and every kind moves, and a
new body gathers out of loose grains over 0.6 to 1.5 s (`enemy.age`,
`RosterBatch.arrivalSeconds`, `_gather`). Frames:
`docs/survival_roster/fix_1110_before_after.png`. The memory note has the
numbers.

## Update 2026-11-10, bosses
All five bosses are built in `boss_roster_art.dart`: the Drift (riftcaller,
with its dust sea in `dust_sea.dart`), the Harvester (conductor), the
Unhatched (standard), the Pair (duelist) and the Other Orb (trickster, with an
eclipse in `arena_wear.dart` and your party as shadows). Artillery and
siegebreaker draw their old forms in grains. Tests: `survival_boss_roster_test.dart`;
preview: `survival_boss_roster_preview_test.dart`. Artillery and siegebreaker
now draw their old archetype form in grains, and the outbreak (cores and
marks) is in grains too, so nothing in survival is drawn in the old style.
Still uncommitted and never on a device. The wave mutators' looks are next.

## Read first
- Memory notes: `project_survival_roster_redesign` (the full record),
  `project_survival_enemy_pass`, `project_survival_horde_mode`,
  `feedback_never_flutter_install`, `feedback_device_session_protocol`,
  `feedback_cpu_parallel_tests`, `feedback_dart_format_scope`,
  `feedback_vfx_material_not_lines`, `feedback_flowy_not_bursty`.
- Design frames and clips: `docs/survival_roster/` (`horde.png`, `bosses.png`,
  `arena.png`, the three `.mp4`s). In-game frames: `ingame_lineup.png`,
  `ingame_wave24.png`, `ingame_wave62.png`.

## What was built
| File | What it holds |
|---|---|
| `lib/games/cosmic_survival/survival_kind.dart` | `SurvivalKind` enum and `survivalKindOf`: a kind is read off tier + conduct + trait with no dice |
| `lib/games/cosmic_survival/roster_art.dart` | `RosterBatch`: every body appends grains and tube segments to per-colour buffers; the field goes out in a few `drawRawPoints` per colour plus two mass paths |
| `cosmic_survival_spawner.dart` | `enemy.kind` (mutable late field), `snareClosed`; every 3rd plain husk becomes a Crest from wave 10, every 4th spill a Snare from wave 12, by count |
| `cosmic_survival_game.dart` | `_holdsOffOrb`, `_inSowerWake`, `_inCrestLee`, `_snareMoves`, `_heldBySnare`; the render loop sends kind bodies to `_roster` |
| `cosmic_survival_balance.dart` | every number below |
| `lib/games/cosmic/cosmic_enemy_vfx.dart` | `drawSurvivalEnemyMarks`: tells and roots for bodies drawn in grains |
| `test/survival_wave50_potential_test.dart` | tests for Siphon, Clutch, Crest, Snare and the kind mapping |
| `test/survival_roster_art_preview_test.dart` | enlarged lineup of the in-game kinds |
| `test/survival_roster_design_preview_test.dart` | the original design frames (not game code) |

### Kinds and behaviour
| Kind | From | Behaviour |
|---|---|---|
| Mote, Strand, Husk, Spill | wisp, drone, brute, sentinel | unchanged |
| Braid | splitter trait | existing: splits on death |
| Hollow | phantom | existing |
| Lobber | siege conduct | existing: parks at 520 and shells |
| Clutch | summoner trait | settles at 440, hatches motes, never rams |
| Siphon | breaker trait | latches at 170, draws the old ram damage over 6 s for as long as it lives, never rams |
| Sower | colossus | bodies within 150 walk 1.25x |
| Crest | every 3rd husk, wave 10+ | bodies within 130 and farther from the orb take 0.5 of every hit |
| Snare | every 4th spill, wave 12+ | holds one Alchemon; lets go when killed, tires after 6 s, at most 2 held |

Outbreak (plague) cores keep their old look. Elites are a matte palette on a
black mass with the affix light behind.

## Measured
- 623 survival and enemy tests pass.
- Late-wave cost, wave 62, about 1,030 bodies, this Mac, JIT: draw 1.93 ms
  median (old bodies 2.1 to 2.2), update 0.79 ms. Phone raster not measured.
- Body counts are no longer 344 and 1,035 (now about 300 to 351 and 1,029 to
  1,037). Cause: Clutches and Siphons live on and the game's own Random is
  drawn differently. Spawning itself draws no new dice.

## Tasks, in order
1. **Get the user's verdict on the Fold build before anything else.** Ask
   what they saw for: bodies at phone size (Motes, the Crest's thin arc, Husk
   bands), late-wave frame rate, and whether Clutch, Siphon, Sower, Crest and
   Snare feel fair.
2. **Check a held Alchemon's special.** `_heldBySnare` skips the companion's
   whole update, but a special the player fires by hand may still go off.
   Find the manual special path and block it while `snaredBy != null`. Add a
   test.
3. **Known look gaps** (do what the user picks, one concern per change):
   the lit cap on heavy bodies has a hard edge; Husk bands are faint at play
   size; Motes are tiny; Hollow is a flat black disc; the closed Snare cage
   is sparse; the Crest is easy to miss in a dense wave.
4. **Balance.** Every number in the table is a guess. Run
   `test/survival_family_role_scorecard_test.dart` (`--tags preview`, about
   15 s) and the wave-50 potential tests, and report before changing numbers.
5. **Delete what was replaced**, once the user approves the look (not
   released: no shims). Survival reaches the old swarm atlas
   (`SurvivalSwarmBatch`, `ensureSurvivalSwarmAtlas`) and the tier painters
   only for plague cores now. `drawEnemy` is shared with open space and
   dungeons, so check both before removing anything. Update
   `test/enemy_render_budget_test.dart` to match.
6. **Bosses, one at a time, ask first.** Designs are in
   `docs/survival_roster/bosses.png` and the memory note: The Unhatched, The
   Harvester, The Drift, The Pair, The Other Orb. Existing bosses and their
   code (`drawSurvivalBoss`, `SurvivalBoss`, `boss_forms.dart`) have not been
   read for this work, and `boss_forms.dart` has someone else's uncommitted
   edits.
7. **Commit**, when the user says so: one concern per commit, messages in
   the repo's style (see `git log`).

## How to verify
- Lineup: `ROSTER_ART_OUT=<file.png> flutter test
  test/survival_roster_art_preview_test.dart --tags preview`
- Field frames: `LOOK_OUT=<dir> LOOK_WAVES=24,62 flutter test
  test/survival_field_preview_test.dart --tags preview --plain-name "look audit a"`
- Cost: `LATE_COST=1 LATE_WAVES=24,62 flutter test
  test/survival_late_wave_cost_test.dart --tags preview`
- Tests: `flutter test --exclude-tags preview -j 2 test/survival_*_test.dart
  test/cosmic_survival_*_test.dart test/enemy_*_test.dart` (about a minute).
  Never more than 2 or 3 test processes at once; never a plain `flutter test`.

## Traps
- `cosmic_survival_boss_discipline_test` "swarm rush joins the authored wave
  pattern pool" fails about one run in six. It builds an unseeded spawner;
  it is not caused by this work.
- Grains alone at play size (radius 20, 2-unit grains) read as loose dust.
  Heavy bodies need the dark mass, the lit cap and the heavier `big` grain,
  and no near-side grain darker than the dark tone.
- A Siphon or Clutch thrown onto the orb must not ram: the guard is in
  `_applyEnemyContactDamage`.
- Phone: never `flutter install`. Build `flutter build apk --release
  --target-platform android-arm64`, push to `/data/local/tmp`, `pm install
  -r`. adb is at `~/Library/Android/sdk/platform-tools/adb`; the Fold was at
  192.168.68.89 (port from `adb mdns services`). If the phone is unreachable,
  say so and wait.
- `dart format` only on files you wholly own (`roster_art.dart`,
  `survival_kind.dart`, the two preview tests), never on the big game files.
