# Survival stat walls

Survival is a grind: the better a team is bred and enhanced, the further it goes. This page records where each stat band meets its wall, why the curves are shaped the way they are, and how to measure them again.

## Targets (user decision, 2026-10-09)

A perfect team should reach about twice as far as a decent one.

| Team (benchmark party, level 10) | Target wall |
| --- | --- |
| P70 (decent) | ~40 |
| P90 | ~60 |
| P100 | ~70 |
| P100 + Enhancement 10 (perfect) | ~80 |

Waves 50–100 are the grinder's endgame. Masteries ([Family XP](../lib/models/survival_family_mastery.dart)), Guardian upgrades and in-run picks add to these walls. They are a second progression track on top of stats, not a replacement for it.

## Method

`test/survival_stat_wall_report_test.dart` (tag `preview`) runs the wave-50 benchmark party. The party is PIP01 Fire, HOR02 Water, MAN04 Air, MSK12 Plant and LET02 Water, at level 10 with the same Potential in every stat. Each run takes the benchmark's twenty fixed picks and no Guardian upgrades or masteries. It jumps straight to the wave and is flown by the same simple pilot as the wave-50 tests, with 3 seeds per wave.

Only ordinary horde waves are sampled. Boss waves (multiples of 5) cap the field at 24 bodies, so they are easier than the waves around them. The older "P80 clears wave 50" and "P95 clears wave 75" tests land on boss waves, so they overstate how far a team really gets.

The wall is the first wave where most seeds die. Deaths are a cliff when the front reaches the orb: 30–50 s into the wave until 2026-10-20, 40–80 s since then, when waves past 33 began to send more bodies (see below). Removing siege artillery and broodmothers barely moved it: the plain horde front is what kills.

Run bands in parallel, one process each, a few seconds apart, because parallel `flutter test` runs can collide copying into `build/`:

```bash
WALL_BANDS=P100E10 WALL_WAVES=71,76,81,86,91,96,101 flutter test test/survival_stat_wall_report_test.dart --tags preview
```

## History

| Team | Before (10-09) | After |
| --- | --- | --- |
| P50 | ~31 | ~34 |
| P70 | ~37 | ~40 |
| P80 | ~40 | ~44 |
| P90 | ~41 | ~55 |
| P100 | ~43 | ~64 |
| P100 + E10 | ~47 | ~80+ |

**After the full ability pass (2026-10-10).** All four phases of `docs/ability_pass/` were in: hooks on the full curve, the stacking cap, Mask and Mystic family rules, reach/count/rate trims, and the restyle.

| Team | Wall |
| --- | --- |
| P50 | ~32 |
| P70 | ~37 |
| P80 | ~40 |
| P90 | ~55 |
| P100 | ~68 |
| P100 + E10 | ~88 |

That's within noise of the targets at P70 and P100. P90 sits a few waves short, and perfect a few waves long, so the spread is about 2.4× rather than 2×. It was left as is: grinding pays slightly more than planned.

At 3 seeds a wall is good to a few waves either way.

**Before.** `survivalStatPower` had a knee at internal stat 5, which is about P70 on an average species. Past it, only an overcap term worth ×0.30 kept growing. From P70 to P100 + E10, the stat on screen went from 504 to 1056, but damage rose only about 35%. Total horde health per wave was growing about 6% a wave near wave 40, so the whole top of the grind bought about 10 waves.

**What changed (2026-10-09):**

1. **Stat power keeps climbing past the knee.** `CosmicSurvivalBalance.statPowerPastKnee` went from 0.30 to 1.17. Between 5 and 9 that keeps the slope power had below the knee, about +0.42 per internal point. Past 9 it tapers on the log tail. This is the shared power model, so every mode sees it. Creatures at or below internal 5, and the 1–5 arena/wild band, are unchanged.
2. **Late pressure.** Past wave 40, enemy health, damage and speed, the spawn rate and the field ceiling all read `latePressure(wave)`, which climbs at half pace. Wave 80 presses like wave 60 used to. The field holds at 1,000 bodies through wave 60, holds 1,800 at wave 100, and reaches 3,000 at wave 160. Waves 1–40 are untouched.
3. **Stat surges are a share of the creature's own stat:** +10% a stack for companion surges and +5% for banners, with keystones on the same footing. Before, they added flat points: about 4% of an average stat and 2% of a perfect one. That's why three War Banners measured as +0% kills.
4. **Elemental Fury** splashes for 25/40/55% of the killer's E-ATK, once per kill. Before, it was a flat 18/26/34, and every body the splash finished erupted again. That let one kill chain through an entire front until enemy health outgrew the flat number.

**Orb shield copy removed, early fire tuned (2026-10-10).** Every Horn and Kin shield used to be copied onto the orb (70%, up to 45% of its health) and refilled on each cast. That carried every team that had a shield caster. Companion shields now stay on the companion, and the orb's only shield is the boss-wave grant (4%). To keep the walls, the orb hardens past wave 10 (`CosmicSurvivalBalance.orbWaveDamageShare`: 0.59 of each hit at wave 20, 0.42 at 30, 0.22 at 80).

Without the copy, a real run's waves 6–12 were lost to enemy fire on the orb from out of reach: siege artillery was 50–85% of the orb's damage there. A level-10 team fell where a level-1 team did. The world changes that make level decide instead:

- **Artillery** parks at 520 (`artilleryHoldRange`, was 820), in the ring the Manes and Masks patrol. It has 2.55× its sentinel body's health (was 0.85), and its shells do 1.14× its damage (was 1.9).
- **Brute siege beams** do 0.57× damage until wave 24, then build back to 1.9× by wave 31 (`bruteBeamDamage`).
- **Fronts** open to the full rim by wave 40 (was 11).
- **Shooters** join mixed waves from wave 20 (was 12). Breaker, summoner and splitter traits start at waves 14, 18 and 20 (were 8, 12, 14).
- **Opening bodies** have double health through wave 8, back to normal by wave 11 (`openingBodyHp`).
- **Rest:** past wave 10, each cleared wave gives back 5% more of the orb's and the fielded team's health, up to 60% from wave 22 (`waveRestShare`). Boss waves still give at least 7% and a 4% shield.

Real runs from wave 1 (`test/survival_fresh_team_wall_report_test.dart`: benchmark species, P50, no upgrades, drafts taken in the benchmark's order, the stat-wall pilot, 16 seeds):

| Level | Falls at |
| --- | --- |
| 1 | 9.9 (8–11) |
| 5 | 17.9 (12–23, most 17–19) |
| 10 | 24.3 (20–27) |

Before any of this, with the old draft order and 4 seeds, they were 12.0, 17.8 and 22.5. With only the copy removed, they were 9.5, 12.0 and 13.3.

Stat walls, measured as the mean first wave each of 8 seeds dies on (seeds 7, 19, 29, 41, 53, 67, 83, 97; every non-boss wave):

| Team | Before | After |
| --- | --- | --- |
| P50 | 33.1 | 33.5 |
| P70 | 35.6 | 39.6 (38.5 on seeds 101–808) |
| P100 + E10 | 73.3 | 74.1 |

In the 3-seed report above, P70 still walls at about 41 and P100 + E10 at about 93. P50's first majority death moved from 31 to 38, but on those three seeds that is a one-seed swing at each sampled wave.

## Family rebuild answered in the world (2026-10-20)

The survival family rebuild of 2026-10-20 (bug sweeps, Let strong early, Pip's carry-over, Wing focus beams, Mask traps on the orb's approach, Mane's longer catapults, bosses reachable by Horn, Mane, Kin and zones) made survival much easier. Every band walled 15–25 waves later. The rebuild's family balance stays as tuned, so the walls were brought back on the world's side only. No creature, family or ability number moved.

Stat walls, 3-seed report (seeds 7, 19, 29):

| Team | Before the rebuild | After the rebuild | After the world change |
| --- | --- | --- | --- |
| P50 | ~32 | ~46 | 36 |
| P70 | ~37–41 | ~61 | 41 |
| P80 | ~40–44 | ~71 | 41 |
| P90 | ~51–55 | ~76 | 61 |
| P100 | ~68 | past 91 | 71 |
| P100 + E10 | ~88–93 | ~116 | 96 |

"Before the rebuild" is the 10-10 table, with P70 and P90 measured again on the committed build the same day (41 and 51). P100 + E10 after the rebuild lost a seed at 111 and two at 116, and then held all three at 121.

On three more seeds (41, 53, 67), P70 loses two at 36 and all at 46, P90 two at 46 and all at 61, and P100 + E10 all three at 81. On the six seeds together that puts P70 at about 41, P90 between 51 and 61, and a perfect team between 81 and 96. A wall is still good only to a few waves either way. The shape holds: a perfect team goes about 2.3× as far as a decent one, the same spread the 10-10 pass left.

**Why it took more than a steeper curve.** The rebuild did not make teams ten waves stronger. It roughly doubled the horde a team gets through before its front breaks. Measured as a wave's total horde health (bodies × health per body), a P70 team at its wall now held about 2.4× what it held before, P90 about 1.7–2×, and a perfect team about 1.9×. The pressure curves are a weak lever for that, because health grows only about 2% per wave of pressure near wave 50. Putting the curves eleven waves ahead on their own moved P90 from 76 to only 71.

**What changed (`CosmicSurvivalBalance`):**

1. **Density.** `hordeDensity` is ×1.0 through wave 25 and ramps to ×1.8 by wave 33. `hordeCountForWave` multiplies by it, so a wave past 33 sends 1.8× the bodies. Each body is the same as before, so every family meets the bodies it was balanced against. The meter's capacity follows the count, so the draft still opens about once a wave. The field ceiling is unchanged, so a wall wave runs longer rather than fuller.
2. **Pressure lead.** `latePressure` is the real wave through 25, then pulls ahead until it is 11 waves ahead at wave 40. Past 40 it climbs at half pace, as before: wave 40 presses like 51, 60 like 61, and 80 like 71. Health, damage, speed, the spawn rate and the orb's hardening all read it, so health and damage still climb together (×1.25 each at wave 40, ×1.18 at 80). A hit at a given wave costs the orb what it did before. Boss health, the ship's hull and outbreak bodies read the same curves and rise with them.
3. **The field ceiling keeps its old climb.** It reads the pressure without the lead (`_fieldCeilingPressure`): 1,000 through wave 60, 1,800 at 100. It is a frame budget measured on the Fold, not a difficulty knob.
4. **Wave total ceiling: 9,000 → 16,000.** At 9,000 it would have capped waves from about 85, right where the perfect team's wall is measured. At 16,000 it is first reached around wave 122, where 9,000 used to be.

Waves 1–25 are untouched, and so are the dungeons, which read waves 3–7.

**The cliff comes later.** Deaths are still a cliff. The orb sits at or near full until the front breaks, then falls in seconds. But the cliff now comes 40–80 s into a wall wave instead of 30–50 s, because a wave there has more bodies. P70 dies at 42–60 s. P90, P100 and the perfect team die at 50–79 s, and they take 50–85 s to clear the waves they hold. On the committed build the same day, P70 and P90 died at 36–49 s and held waves in 36–49 s.

A trial with tougher bodies instead of most of the density (×1.5 bodies, ×1.45 health and damage, no lead) brought deaths back to 34–61 s. P70 stayed at 41, but P90 fell back to 51: once the front leaks, damage is what decides a strong team. Density was kept, because P90 belongs at 60.

**Family shares hold.** `test/family_balance_survival_test.dart` ran 21 P70 parties just under each wall: wave 56 before the world change and wave 36 after. Kill shares moved two points at most: Let 36%, Mane 24→25%, Pip 23→24%, Mask 20→21%, Wing 20→18%, Horn 11→9%, Kin 6%. Damage shares moved more, Mane 29→36% and Let 27→22%, because bodies with a little more health leave less overkill on Mane's lines, and damage share counts only the health a hit removes.

**Fresh teams** (`test/survival_fresh_team_wall_report_test.dart`, 16 seeds) are unchanged by the world change, which starts at wave 26:

| Level | Committed build (before the rebuild) | After the rebuild | After the world change |
| --- | --- | --- | --- |
| 1 | 9.6 | 9.0 | 9.0 |
| 5 | 14.8 | 15.3 | 15.3 |
| 10 | 23.8 | 18.2 | 18.1 |

Level 10 fails its check (23 or later) since the rebuild, not since the world change. On 7 of 16 seeds it falls at waves 5–15. The report's pilot never flies out for surge grains, so a level-10 team, which kills far from the orb, gets its first draft late. It plays waves 1–8 with only its Pip. Since the rebuild, that lone Pip cannot finish the wave-5 or wave-10 boss: on seed 808 the boss still had 155 of its 2,878 health after 320 s of grinding the orb down. Level 1 kills near the orb, where the core drinks the grains, so it has its Horn by wave 5. That is a question for Pip against an early boss, and for whether the report's pilot should gather, not for the world curves.

**Meter pacing** (`test/survival_meter_pacing_test.dart`) still passes. From wave 30 it now clears two waves in its two minutes (60 s a wave, was 40) for one surge, 0.5 a wave, the bottom of its band. That is the first wave of a jump-started run, which never pays a surge, out of only two.
