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

The wall is the first wave where most seeds die. Deaths are a cliff about 30–50 s into the wave, when the front reaches the orb. Removing siege artillery and broodmothers barely moved it: the plain horde front is what kills.

Run bands in parallel, one process each, a few seconds apart, because parallel `flutter test` runs can collide copying into `build/`:

```bash
WALL_BANDS=P100E10 WALL_WAVES=61,66,71,76,81,86,91 flutter test test/survival_stat_wall_report_test.dart --tags preview
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
