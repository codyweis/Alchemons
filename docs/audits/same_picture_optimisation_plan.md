# Plan: same-picture optimisation

For an agent picking this up cold. Repo: Alchemons (Flutter), branch master.

## The rule
**The picture must not change.** The user's words: "I don't want to cut
costs if it makes a worse game." So every change here makes the game work
out the same grains less often. No thinning grains, no shorter effects, no
lower quality, no LOD the player can see. If a change cannot be proved
identical, drop it.

## Where things stand (2026-11-11, after round two)
- HEAD is c3c79f89. Rounds one and two are **uncommitted**, in five files:
  `lib/games/cosmic/element_ground_art.dart`,
  `lib/games/cosmic/mane_grain_vfx.dart`,
  `lib/games/cosmic_survival/roster_art.dart`,
  `lib/games/cosmic_survival/components/mystic_world_ambience.dart`,
  `lib/games/shared/enemy_facing.dart`. Do not commit or push without the
  user saying so.
- Every change is proved identical against the committed code (below).
- Round two stopped by the plan's rule: what is left at the top is either
  under about 5% of the frame or bound by recording the grains themselves
  (see "What is left").
- Phone frame time is unmeasured. All numbers here are draw-record time on
  this Mac, in JIT, under load 6 to 10: use them to compare, not as frame
  rates.

## Before and after (wave 62, about 1,035 bodies)
A/B against a worktree of HEAD, both run side by side three times, median
of the three draw medians:

| Party | Draw median, HEAD | Now | Draw p95, HEAD | Now |
|---|---|---|---|---|
| A (wave 62) | 3.68 ms | 2.74 ms (26% less) | 5.09 ms | 3.71 ms |
| B (wave 62, Fire world) | 2.81 ms | 2.59 ms (8% less) | 3.71 ms | 3.39 ms |
| C (wave 62, Poison world) | 3.30 ms | 2.83 ms (14% less) | 4.67 ms | 3.91 ms |
| A (wave 24) | 2.26 ms | 1.88 ms | | |
| B (wave 24) | 1.88 ms | 1.78 ms | | |
| C (wave 24) | 1.84 ms | 1.68 ms | | |

Both trees ran at once, so the machine was busier than in a single run and
the numbers are higher than single-run ones; compare across the row only.
"HEAD" has neither round. Party A gains most because round one and the
start of round two were aimed at its effects; B's effects were already
light (its top items are each under 5% of the frame).

Party A: Lava Mane, Plant Kin, Dark Wing, Poison Mask, Fire Horn (the
test's own). Party B: Lightning Pip, Earth Let, Water Horn, Spirit Kin, Fire
Mystic (Simurgh, a world up). Party C: Water Mane, Plant Wing, Ice Mask,
Steam Horn, Poison Mystic (Blightfang, a world up).

## What each painter costs now
Compute alone (a canvas that records nothing), this Mac, against the
committed code. "Recorded" adds a real `PictureRecorder`.

| Painter | Committed | Now | Recorded now |
|---|---|---|---|
| Fire ground, r 54 (Horn's Fire leftover) | 16.7 us | 7.4 us | 11.9 us |
| Steam ground, r 54 (Horn's Steam geyser) | 16.1 us | 6.8 us | 10.3 us |
| Steam ground, r 90 | 21.6 us | 8.2 us | 13.2 us |
| Plant ground, r 60 (Kin's field) | 24.1 us | 9.4 us | 13.8 us |
| Poison ground, r 60 (Mask's trap) | 12.7 us | 6.3 us | 10.1 us |
| Mane Lava pool, r 60, steady | 137 us | 7 us | 13 to 15 us |
| Mane Lava pool, spreading (laid afresh each frame) | 54 us | 27 to 30 us | |
| Mane Lava shot, r 34 | 56 us | 28 to 30 us | 40 to 43 us |
| Mane Water shot, hh 93 at speed 174 (as in play) | 98 us | 69 us | 79 us |
| Mystic weather, Fire / Water / Ice / Poison | 76 / 92 / 72 / 48 us | 35 / 43 / 31 / 20 us | |
| Enemy bodies, per body: husk / hollow / spill / crest / core / clutch | 8.6 / 6.5 / 5.8 / 6.6 / 9.9 / 6.6 us | 6.8 / 4.2 / 3.5 / 3.6 / 7.6 / 5.0 us | |
| Enemy bodies, per body: mote | 0.83 us | 0.71 us | |

## What was done
Round one:
- `paintManeLavaPool`: a `_PoolLayout` per pool, keyed by where it lies:
  each grain's place, nearest cell and distance to the seam, rebuilt only if
  the pool's place, radius or grain count change; the map cleared at 160.
- `_plant` and `_poison` (`element_ground_art.dart`): each grain's place in
  its leaf or bank from a table built once.

Round two:
- **`x % 1.0` is a runtime call in Dart** (and half of Fire's cost was it).
  `x - x.floorToDouble()` gives the same bits for every finite x (both are
  the one rounding of the same exact value, and +0 for a whole number).
  Swapped in the ground painter, the Mane painter, the enemy bodies and the
  weather (`_fract`; `_mod2` for `% 2.0` in the Lava shot).
- **Grains written straight in** (`_room` then `_put`) where nothing
  dissolves, instead of `_g`'s per-grain checks: Fire, Steam, the shared
  bed, the Lava shot.
- **Fixed per-grain values in tables** (Float64 where the frame compares
  them): Fire's loop bounds; Steam's lip, mouth and plume hashes; the Lava
  shot's shadow, heat, rim thinning, seam row and tone (one lookup in place
  of a branch chain); the Water shot's wall front and depth, crest clumps
  and spray; every enemy kind's index hashes and `pow`s (hollow, spill,
  lobber, sower, crest, core roots, the seed hashes of motes and siphons).
- **Lava pool, steady:** a grain further from a seam than the white-hot seam
  ever reaches keeps its tone, so while the heat holds and nothing
  dissolves, the tones only such grains take are kept as points per pool
  (`_PoolLayout.fix`) and only the rest are worked out. A pool still
  spreading is laid afresh each frame and keeps nothing.
- **Water shot's lace:** its hash depends on the path's stretch and the
  grain only, so a row per stretch is kept (`_laceHash`, 16 rows). The
  `pow(1 - age, 1.4)` test is skipped when the hash is past `1 - age`
  (for `1 - age` up to 0.999999 the power is at least a two-millionth below
  it, far more than pow's error).
- **Mystic weather:** a cell's eight hashes depend on its id alone, so they
  are kept by slot (4,096, tagged with the id); the per-grain
  `viewport.contains(Offset(...))` became the four comparisons it is.
- **Enemy bodies, shared:** the arrival cube is worked out only for a body
  still arriving; the last colour's palette is remembered; the shell and
  ball loops read their statics from locals; a body's facing remembers the
  last few `exp` results (every body follows on the same frame step).

## What is left
- **Recording.** In play most painters now spend more on recording than on
  maths (Fire 7 us of maths against 17 to 19 us in the game). Fewer draws
  would mean batching pieces together, which changes what is drawn over
  what. Not identical.
- **Lava pools spreading** (their first 0.35 s): laid afresh every frame,
  about a third of the pool's cost. Inherent to a growing pool.
- **Horn's Steam geysers** (Party C's top item, about 18% of its frame, 25
  at once): the maths left is a `pow` and a `sin` per plume grain, both
  moving with time.
- **Mystic ambience** (Poison's about 140 us in play, Fire's about 70): path
  building, 26 native `lineTo` calls a crescent. Cheaper path calls would
  rest on engine internals, not provable here.
- **Enemy flush** (about 185 us) and motes (240 a frame at about 0.6 us):
  recording, and per-body work that is already small.
- **Mane Water shot in play:** its first use in a session builds the lace
  (about 270,000 sines, a few ms) and each new stretch fills a row (2,400
  sines). A short timing sample counts these; a long run does not notice.

## Tasks
1. **Commit both rounds** when the user says so (one commit, five files).
2. **Phone check**, when the user asks: a profile build on the Fold with a
   full party past wave 50. If it holds its frame rate there, nothing more
   is needed.
3. Only if the phone says so: the items under "What is left", starting with
   the spreading Lava pool and the Steam geyser.

## How to measure
- Whole frame: `LATE_COST=1 LATE_WAVES=24,62 flutter test
  test/survival_late_wave_cost_test.dart --tags preview`. Run it three
  times and compare medians; single runs swing by 10% with the Mac's load.
- Other parties: copy that test to a temporary file whose `_party` reads
  `LATE_PARTY` (`id:name:family:element,...`). A Mystic with a world
  element casts its world in the test (see `_mysticWorldElements`).
- Before and after: `git worktree add --detach <scratchpad>/base HEAD`,
  `flutter pub get` there, copy the temporary test in, and run both trees
  side by side so they share the machine's load. Remove the worktree after.
- By family: wrap the `_renderCompanionProjectile(canvas, proj);` call in
  `cosmic_survival_game.dart` in a Stopwatch keyed by
  `abilityFamily/element/stationary/visualStyle.name`, and count frames,
  so each kind reads as us a frame. Mark every timing line with one tag
  and delete those lines by hand when done: **never `git checkout` or
  `git stash`** here (other sessions keep work in this checkout).
- Inside a painter: a Stopwatch round its call. Build any key string
  outside the outer timer (a string built per call inflated it by about
  6 us), and keep one Stopwatch per method: a global one started in one
  method and read in another ran across the frame boundary.
- Painters alone: a temporary test calling the painter with a canvas whose
  `noSuchMethod` does nothing (compute) and with a real `PictureRecorder`
  (recorded), best of five batches.

## How to prove the picture is the same
The audit sheets are **not** repeatable run to run (seeds come from
`identityHashCode`), so comparing images proves nothing. Instead:

1. A temporary test calls the painter directly with fixed inputs over many
   frames, covering every state it has (growing, cooling, dissolving,
   reduced quality, several sizes, several at once, a time past 3,000 s).
2. It passes a `Canvas` whose `noSuchMethod` hashes every draw bit for bit:
   the method name, each `Float32List`'s raw 32-bit words, each double's 64
   bits, each Paint's colour (a, r, g, b as doubles), stroke width, style,
   cap and blend, and a Path's bounds, contour lengths and nine points
   along each contour.
3. The committed code is the reference: `git show HEAD:<file> >
   test/zz_tmp_<name>_orig.dart` (make relative imports package imports)
   and import it `as orig`, so both fingerprints come from one run.
4. Run it twice first to see it is stable; it must match exactly after.
   Delete the temporary files after.

Round two matched against HEAD on all 17 grounds (40,320 calls each), the
Lava shot and pool, the Water shot, the weather and ambience of every
Mystic world (camera drifting, jumping and pulled back), all 13 enemy kinds
(hit flash, arriving, hurt, dense, closed snares) and the facing.

## Traps
- **Precision.** A cached value that is compared with a threshold must be
  kept as a double (`Float64List`). Kept as a float it can flip a grain's
  tone at the boundary. Positions that end up in a `Float32List` anyway can
  be cached as floats. A value the frame reads from a float table must be
  read back from that table when a cache is built from it.
- **Keep the order.** Grains must be added in the same order with the same
  skips, or the buffers differ even when the picture looks the same.
  Reordering *tests* that each drop a grain is fine; reordering grains is
  not.
- **Left-to-right maths.** Hoisting a term out of a loop is safe only if
  the expression still evaluates in the same order (`(k * F) - u * (k * D)`
  from a table of `F` and `D` is the same as `front(s) - u * depth(s)`;
  `k * (F - u * D)` is not).
- **`%` on doubles** is a runtime call; `x - x.floorToDouble()` is the same
  bits for `% 1.0`. Only `1.0` (and powers of two) are exact this way.
- **Bounds instead of a call** (the lace's `pow`) are only safe with a wide
  margin: prove the true value is far from the bound compared with the
  function's error, and keep the call where it is not.
- **Caches must be bounded and must notice change.** Key by what is truly
  fixed, check every field that feeds the result, and cap the size.
- A table index can run past the end on a very large effect: keep a
  fallback to the direct maths.
- **Measure before keeping.** Two identical changes here gained nothing
  (the pool's hoisted thresholds, the lace's lower bound) and were taken
  out: keep only what the benchmark shows.
- In a temporary test that calls through `dynamic`, write `0.0` and `1.0`:
  an int literal is not turned into a double there.
- `dart format` only on files whose committed version is already formatted
  (check with `dart format -o show` against `git show HEAD:<file>`):
  `element_ground_art.dart`, `mane_grain_vfx.dart` and `roster_art.dart`
  are; `mystic_world_ambience.dart` and the big game files are not.
- Never more than 2 or 3 test processes at once; never a plain
  `flutter test`. Two `flutter test` runs in the same checkout at once can
  race on `build/`.
- Tests to run after each change: `flutter test --exclude-tags preview -j 2
  test/survival_*_test.dart test/cosmic_survival_*_test.dart
  test/ability_*_test.dart test/mask_*_test.dart test/let_*_test.dart
  test/horn_*_test.dart test/kin_*_test.dart test/mystic_*_test.dart
  test/mane_*_test.dart test/enemy_*_test.dart
  test/dead_ability_wakeup_test.dart` (990 pass, about 80 s).
