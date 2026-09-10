# Breeding-driven combat baseline

All progression benchmarks use level 10, with no Enhancement or Nature bonus.
Real creature levels still affect combat. Breeding potential is applied per stat;
species bases, Nature, and Enhancement remain multiplicative inputs.

| Potential | Stat multiplier |
| --- | --- |
| 1 | 0.85 |
| 20 | 1.00 |
| 50 | 1.25 |
| 70 | 1.55 |
| 80 | 1.80 |
| 90 | 2.10 |
| 95 | 2.30 |
| 100 | 2.50 |

Values interpolate linearly between anchors. There are no threshold jumps.
P95 produces 84% more effective stat than P50 for identical other inputs.
Existing saves recalculate cached stats at GameDataService initialization from
their original genetics; repeat initialization does not compound the bonus.

## Cosmic Space

Guardian victories continue to determine encounter tiers; the equipped party
does not cause enemy scaling. Levels 1–2 target P20–50, level 3 P60–80,
level 4 optimized P80–90, and level 5 P90–95+ across the party.
Boss template health multipliers are 7 / 11 / 24 / 42 / 60. Ship damage
and boss shield tuning remain unchanged. A median template has 35 base HP.
A level-10 P70 trio with neutral base-60 stats has approximately a 27-second
basic-only damage budget against a median level-3 boss, excluding movement,
specials, family attack patterns, crits, and ship weapons.

The five-species catalog benchmark (PIP01, HOR02, MAN04, MSK12, LET02) measures
single-hit basic cadence, not actual encounter DPS:

| Potential | Space cadence | Survival cadence | Survival team HP |
| --- | ---: | ---: | ---: |
| 35 | 29.7 | 407.2 | 3610 |
| 50 | 36.2 | 502.5 | 4004 |
| 70 | 53.3 | 672.4 | 4732 |
| 80 | 66.7 | 802.8 | 5297 |
| 95 | 78.5 | 916.5 | 5745 |

These confirm increasing gains survive the existing combat conversions. Their
diminishing returns remain in place; raw stat gains are not damage multipliers.

## Survival

Waves 1–10 retain their existing enemy HP curve. After wave 10, enemy HP
receives an additional `1 + (wave - 10) × 0.008` factor. Boss HP also receives
`1 + (wave - 10) × 0.018`. Damage and orb contact caps remain unchanged.

Controlled checkpoint simulations use a five-member level-10 party, twenty
fixed run upgrades, no permanent upgrades or Enhancement, and an automated
pilot. They start directly at a wave with full resources; they are not full-run
survival or difficulty guarantees. Early checkpoints are deliberately generous
because the same upgrades are supplied to every case.

After tuning, the P80 wave-50 checkpoint cleared in 32–33 seconds across seeds
11, 29, and 47 (previously 19–20 seconds with the new potential curve alone).
P95 cleared the wave-75 checkpoint in 42 seconds at seed 11.
P35/wave 10 and P70/wave 30 checkpoints also cleared.

## Remaining playtest coverage

Planet guardian encounter coefficients were reviewed and retained; their
companions inherit the new stat curve through the shared survival conversion.
Dungeon combat, scaling, and raid regressions are checked, but this pass does
not establish new win-rate targets for every planet guardian or every team.
Manual full-run testing should focus on guardian vulnerability cycles,
special-heavy teams, Enhancement stacking, and resource attrition in survival.
