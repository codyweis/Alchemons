# Survival, Cosmic Space, and battle-tab audit — 2026-10-02

## Finding: 500 Power does not mean 500 damage

The displayed rating is `internal stat × 100`. Combat receives the internal value, so 500 Strength is 5.0. There is no extra divide-by-100 error in the battle tab. Speed and Intelligence do not directly increase P-ATK; Strength does. Level and family also matter, depending on the mode.

At level 10, before constellation bonuses, Guardian upgrades, or temporary effects:

| Displayed Strength | Space P-ATK | Survival Pip P-ATK |
| --- | ---: | ---: |
| 250 | 4 | 26 |
| 500 | 12 | 64 |
| 900 | 15 | 81 |
| 1500 | 17 | 97 |

Space uses compact damage values against roaming enemies; Survival has its own damage, HP, defense, range, and family multipliers. Directly comparing the two attack numbers is not a comparison of effectiveness. Higher ratings continue to help, with diminishing returns above 500; integer rounding can hide small improvements to attack.

Sources: `lib/models/stat_system.dart`, `CosmicBalance` in `lib/games/cosmic/cosmic_data.dart`, and `deriveCosmicSurvivalCompanionStats` in `lib/games/cosmic_survival/cosmic_survival_companion_stats.dart`.

## Confirmed issues, ordered by impact

### High: 16 Mystic world specials have no Space implementation

`_mysticSpecial` returns no effect for every canonical element except Fire. Survival implements those effects in its own world runtime. Space's `_castCompanionSpecial` consumes the cooldown and processes the empty result without an equivalent Mystic world handler. Fire has a shared projectile payload, but this is not the same as Survival's persistent world.

This is a missing mechanic, not a low damage coefficient. Porting all 16 effects needs deliberate decisions about their targets, scope, and lifetime in an open world. The detail tab now explicitly identifies Mystic world effects as Survival abilities. Runtime implementation remains open.

Sources: `lib/games/cosmic/cosmic_data.dart` (`_mysticSpecial`), `lib/games/cosmic/cosmic_game_combat_actions.dart`, `lib/games/cosmic_survival/survival_mastery_mystic.dart` and the Survival game runtime.

### High: critical-hit chance is calculated but never used by either combat mode

Both modes assign companion crit chance, but their combat code never reads it to roll or apply a critical hit. Survival's Guardian crit upgrade therefore changes a stored/displayed number without changing attack outcomes. Its advertised benefit is currently missing.

The battle detail tab no longer advertises this inactive stat. The Survival live readout, upgrade offering, and runtime still need a coordinated fix: define critical-hit behavior and implement it, or retire the upgrade with a migration/refund policy. No new crit multiplier or economy policy was invented during this audit.

Sources: repository-wide `critChance` references under `lib/games/cosmic` and `lib/games/cosmic_survival`; `GuardianUpgrade.critChance` in `lib/models/survival_upgrades.dart`.

### Medium: cooldown rules and descriptions disagree

Space special cooldowns use Speed plus family-weighted special attack power. Survival uses the family's blended cooldown stat, then (for most families) an additional Beauty-based E-ATK factor. These are different build incentives. The old detail copy implied the Survival stat blend applied everywhere.

Both modes also make basic attacks faster as P-ATK increases, up to a factor cap of 3. Strength therefore buys damage and cadence, despite shared comments describing basic cadence as Speed-only. That is a balance decision to review, not merely wording.

The tab now distinguishes the mode rules, explains that CD is only the Speed modifier, and describes Strength's cadence contribution. Runtime coefficients are unchanged.

Sources: `CosmicCompanion.effectiveBasicCooldown` / `effectiveSpecialCooldown` and the corresponding Survival companion getters.

### Medium: battle analysis hid the relevant mode and special power

The previous tab displayed Space stats without a mode label, omitted Survival's different family modifiers, and showed Beauty-based E-ATK without the family-weighted `abilityAtk` used by specials.

Fixed in this audit:

- Added a Cosmic Space / Survival stat selector.
- Survival numbers call the actual Survival stat derivation, including family modifiers.
- Added SPECIAL with the family's contributing stats.
- Explained Power ratings versus base damage using the selected creature's numbers.
- Labeled exclusions: Guardian upgrades, run bonuses, and temporary effects are not included.
- Marked the existing family-frame boost summary as Cosmic Space.

SPECIAL is an input to authored abilities, not total damage per cast. Projectile counts, ticking fields, targeting, shields, healing, passives, and element mechanics all change the outcome.

## Survival simulation results

Ran the existing `survival_balance_audit_test.dart` harness: five level-10 creatures at Potential 80 (PIP01, HOR02, MAN04, MSK12, LET02), its predefined bonus loadout, two seeds, and up to five simulated minutes from each start wave. It uses an automated pilot and skips new draft choices. Late-wave cases start there directly rather than earning a complete run's upgrades.

| Start wave | Seed 11 result | Seed 29 result | Orb time at full HP |
| --- | --- | --- | --- |
| 1 | Reached 19, alive | Reached 18, alive | 100% / 100% |
| 15 | Reached 27, alive | Reached 26, alive | 100% / 99% |
| 30 | Died at 33 | Died at 35 | 51% / 57% |
| 50 | Died at 51 | Died at 51 | 87% / 77% |

The tested setup protects the orb very well early, then hits a sharp late-game failure region. High full-health time followed by death at wave 51 suggests burst/leak handling deserves investigation. These runs do not establish the player population's win rate or prove that wave 30 should be nerfed.

Wave 50 enemy scaling is approximately 4.06× HP, 4.00× damage, and 1.16× speed relative to wave 1. Healing counters disagree with observed HP gains in some runs; simultaneous damage/healing and overheal also limit frame-to-frame comparisons.

The harness's shared-payload screen flagged Mane Fire (4.2× its family median), Mane Lightning (3.8×), Let Earth (2×), and Kin Crystal (0.4×). These are investigation candidates, not DPS rankings: the screen omits important runtime, beam, control, healing, and persistent-world behavior. Do not nerf abilities on these totals alone.

## Validation and next priorities

The initial expanded run passed 191 checks and exposed one stale progression assertion: it expected shard rewards to rise with whirl difficulty, while `GalaxyWhirl.shardReward` explicitly documents and implements a flat 50. Updated that assertion to preserve the authored flat reward; the particle-reward growth assertion remains. No economy values changed.

Regression checks cover both displayed scales at 500 Strength, the mode switch, family-specific special power, family HP/defense, and narrow-phone layout. Existing tests cover ability parity, progression, boss curves, and Survival mastery. After correcting the stale reward assertion, all 10 battle-tab and progression checks passed on rerun. The other 182 checks passed in the expanded run. The four reporting-harness cases passed, and the analyzer reported no issues in the battle-tab changes. Passing tests do not cover the missing Mystic/crit behavior identified above.

Recommended order: resolve inactive crit/upgrades; adapt Mystic worlds to Space; agree on shared versus mode-specific cooldown contracts; then compare actual runtime damage, healing, crowd control, and survival across multiple parties, potentials, and earned-upgrade paths. Global attack inflation would not repair the missing mechanics.
