# Dungeon bosses, raids, balance, and battle behavior audit

Date: 2026-10-07. Scope: the current working tree, including pre-existing local changes. Gameplay was not changed. This is a code and headless-runtime audit, not device playtesting or a population win-rate study.

## Findings, in priority order

### P1 — Lures can cause remote damage to the creature they should protect

In `planet_dungeon_game.dart:4933`, a taunt replaces `toTarget` with the lure's position. At line 4965, the resulting steering impact still damages `combatCompanions[targetIndex]`, the original creature. No creature-distance check or non-decoy-lure branch intervenes. Decoys have a separate contact cooldown, but ordinary taunt fields do not.

**Reproduced:** a wisp diving into a stationary taunt 250 units from its creature target reduced that creature from 639 to 580 HP. This affects the shared dungeon/raid enemy loop and undermines lure-based builds.

Fix: resolve the impact against the target actually pursued. A field arrival must not become a remote creature hit; decoy arrivals should resolve against the decoy. Add regressions for fields, decoys, and ordinary creature contact.

### P1 — Raid rewards finish before the clear is persisted

`planet_dungeon_screen.dart:1426` calls `widget.onRaidCleared?.call()` without awaiting its Future inside the async `onGranted` wrapper. `RaidRewardPopup._grant` awaits that wrapper and then enables Continue, so it does not actually wait for `RaidService.markLevelCleared`.

The player can return to orbit while progression is still saving. Orbit refresh also reads and writes raid state, creating a race with tier advancement; a rejected save is detached from the reward flow. This contradicts the screen's explicit persistence contract.

Fix: await the callback and handle persistence errors before allowing dismissal. Verify with a deliberately delayed callback and a failing callback. This is confirmed by control-flow inspection; the timing race was not fault-injected in this audit.

### P1 — Raid loot and progression have no durable, idempotent victory record

`raid_rewards.dart:41–82` performs multiple independent item/currency writes. Only afterward does the popup invoke progression, which lives in SharedPreferences through `raid_service.dart:66`. There is no shared transaction or durable claim identifier. Even correcting the missing await leaves this gap.

A crash or write failure after an item is granted but before progression saves leaves loot awarded with the same tier available again. A failure midway through payout also leaves partial loot and no recovery flow. `markLevelCleared()` accepts no event identity or expected tier, so it cannot reject a duplicate/stale completion.

Fix: persist a uniquely identified victory and its rewards transactionally in the database; make progression/recovery consume that record idempotently. Do not merely move progression before loot, which reverses the failure into lost rewards. Crash recovery remains an integration test gap.

### P2 — Ordinary dungeon hits and raid adds ignore defensive stats

`planet_dungeon_game.dart:4975–4989` applies P-DEF mitigation only when both `isRaid` and `isGuardian` are true. Every other dive uses a fraction of the victim's maximum HP, independent of P-DEF and E-DEF.

**Reproduced:** identical wisp impacts dealt 59 HP with both defenses set to 0 and with both set to 999. HP investment alone also does not buy more hits survived against this percentage-based component. Shields still absorb damage, and the raid guardian's P-DEF mitigation works; the finding is specifically about the other dive paths.

This is a balance-contract problem even if percentage damage was deliberate: the shared stat model presents defenses and family durability as meaningful investments. Decide whether these hits should be mitigated or explicitly classified as defense-bypassing damage, then test that contract.

### P2 — Campaign guardian contact damage almost immediately hits its cap

Guardian base contact damage is `24 × enemyWaveDamageScale(7) × progressDmgMul`; the ordinary dive fraction caps at 20% max HP. The current wave-7 multiplier is approximately 1.2314.

- First guardian: approximately 19.28% of victim max HP per unshielded impact.
- After one other guardian: already capped at 20%.
- Seventeenth guardian: still 20%, despite a nominal damage multiplier of 2.92.

The campaign still grows harder through health, strikes, hazards, and fight duration. However, its advertised contact-damage progression effectively disappears after the first fight. Tune this together with defense handling; increasing the raw damage coefficient cannot help while capped.

### P2 — Existing combat harnesses do not always build production companions

Both `planet_dungeon_combat_test.dart` and `planet_raid_arena_test.dart` construct companions with `abilityAtk: stats.elemAtk` and omit the derived `specialCooldownReduction`. Production construction at `planet_dungeon_game.dart:3020` supplies the family-weighted ability power and special recharge.

The tests remain useful for steering, lifecycle, and layout, but must not be treated as reliable family-balance measurements. Their default two-Wing fixture also is not a legal representative five-family raid roster. Use a shared production factory or accurately reproduce every derived field before adding comparative simulations.

### P3 — The legacy boss balance report is unusable and its win rates are synthetic

`tool/boss_balance_overview.dart` reads `lib/data/boss_data.dart`, which no longer exists. Its reported win rates are a hand-authored function of estimated kill rounds, not battle outcomes, and its old four-member level-5 model does not represent current dungeon/raid combat.

Retire it or rebuild it against the live factories and runtime. Do not use its percentages to justify tuning. Several guardian comments also retain old HP/wave values; the current numbers below come from executable formulas.

## Current balance model

The shared `deriveAlchemonCombatStats` now feeds Space, Survival, dungeon companions, and the battle tab. Family frames, weighted SPECIAL, and cooldown helpers are centralized. Strength affects both basic damage and cadence until the cadence power factor caps at P-ATK 41. SPECIAL also improves recharge for most families, saturating its power factor at 150. These create nonlinear growth below the caps and require runtime comparisons rather than per-hit comparisons.

Mystics intentionally have no special outside Survival. The earlier audit's missing Space-world recommendation is superseded by the explicit design rule. The inactive critical-hit upgrade was also retired; it is not a current missing combat feature. Dark Wing's doubled basic/laser cadence is explicit design intent, not an accidental duplicate multiplier.

| Raid tier | Guardian HP, rounded | Raw guardian damage component | Add dive fraction before shields |
| --- | ---: | ---: | ---: |
| 1 | 37,142 | 47.28 | 11.89% |
| 2 | 74,283 | 67.97 | 15.58% |
| 3 | 133,710 | 94.57 | 19.28% |

Guardian hits additionally include 8% / 12% / 16% of victim max HP and then apply P-DEF mitigation. Raid health and damage scaling ignore campaign order. Adds arrive four at a time at one, two, or three tier-specific HP thresholds; the generic half-health enrage also spawns two wisps. All tiers have a ten-minute fight limit, permanent downs for the attempt, and stat-based lull strikes. The first level-3 clear schedules a twelve-hour echo cooldown and extends the event window.

Campaign guardian HP grows by 18% per other cleared guardian, reaching 3.88×. Normal lull strikes take fixed fractions, from 1/14 to 1/26 of guardian HP, with a special three-strike Light puzzle rule. These mechanics intentionally limit how much raw HP scaling alone can enforce roster quality. Raid strikes correctly use attack stats instead.

Air, Fire, and Water raid arenas carry furniture and runtime hooks for their guardian mechanics. Passing registry/furniture tests establishes configuration coverage, not equally rich mechanics or fair difficulty for every element. Other puzzle-dependent guardian hooks can be intentionally absent in raids; their encounter identity still deserves manual comparison.

## Current Survival simulation

Re-ran the existing reporting harness: five level-10 creatures at Potential 80 (PIP01, HOR02, MAN04, MSK12, LET02), predefined bonus loadout, two seeds, at most five simulated minutes per run. Higher starting waves are direct starts, not an earned run with the intervening drafts.

| Starting wave | Seed 11 | Seed 29 | Orb time at full HP |
| --- | --- | --- | --- |
| 1 | Reached 19, alive | Reached 19, alive | 100% / 100% |
| 15 | Reached 26, alive | Reached 26, alive | 100% / approximately 100% |
| 30 | Died at 34 | Died at 33 | 78% / 74% |
| 50 | Died at 52 | Died at 51 | 79% / 87% |

This roster overprotects the orb early and fails sharply later. Ship deaths still occur in early runs, so this is not evidence that the entire mode has no pressure. Investigate late-wave burst/leaks and recovery windows before changing global damage or HP. Healing-event reporting differs from frame-observed restoration, so those counters need reconciliation before tuning sustain.

The payload-only report flags Mane Fire (4.2× family median), Mane Lightning (3.8×), Let Earth (2×), and Kin Crystal (0.4×). These are investigation candidates, not total-runtime DPS rankings: beams, persistent effects, healing, targeting, and control are not captured consistently. No nerf is justified by those ratios alone.

## Validation and remaining limits

- Initial combat/raid/balance batch: 178 checks passed, including eight Survival simulation runs within the reporting tests.
- Family conformance, Mystic audit, mastery events, battle-tab stats, boss-room and raid-furniture batch: 83 checks passed.
- Two new characterization checks reproduce the lure and defense findings in `test/combat_audit_reproduction_test.dart`. They intentionally assert the observed defects; convert them to desired-behavior regressions when fixing the code.
- Dungeon completion/stat-contract batch: 145 checks passed. Total across all batches: 408 checks passed, including the two defect-characterization checks.

No gameplay coefficients or existing user edits were changed. No physical-device playtest, frame-rate comparison, exhaustive 136-build raid matchup matrix, full-project test run, or persistence fault-injection was performed. Passing checks do not establish encounter win rates. The next useful balance experiment is legal five-family raid squads at multiple training/potential bands, across all three tiers and elements, reporting clear time, downs, boss/add damage, shielding, healing, and actual special uptime.

Recommended implementation order: fix lure targeting and raid persistence; agree on the defense/contact-damage contract; repair test companion construction; then tune with encounter-level measurements.

## Resolution (2026-10-07, same day)

Fixed, each pinned by a test that fails on the audited code:

- **Lure remote damage (P1)** — a taunted impact lands only on a creature inside the enemy's reach, and never through a decoy. `test/dungeon_lure_contact_test.dart`.
- **Raid clear not awaited (P1)** — awaited; the popup retries a failed save once and never traps the player behind loot that has landed. `test/raid_reward_popup_persistence_test.dart`. The durable idempotent victory record is deferred.
- **Defence ignored (P2)** — `defenseMitigation` trims dive and plague hits by P-DEF/E-DEF, only ever downward. `test/dungeon_hit_defense_test.dart`.
- **Guardian contact capped by the 2nd dungeon (P2)** — guardian ceiling 0.20 → 0.30.
- **Harness companions (P2)** — new seam `PlanetDungeonGame.debugCreateCombatCompanion`; new tests use it. The older harnesses are unchanged.
- The characterization file `test/combat_audit_reproduction_test.dart` was retired once both of its findings were fixed.

Found beyond the audit, and fixed:

- **Dungeon guardians took every trash effect.** Survival keeps its boss out of the enemy list; the dungeon's lived in it, and the port lacked survival's per-body hit guard, so piercing shots billed a boss once a frame. 29 of 119 specials took ≥20% of a fresh guardian in one stat-3 cast; 11 deleted it. Now `_isBossBody` gives guardians and Poison plagues survival's boss rules. `test/dungeon_boss_rules_test.dart`.
- **Poison plagues** were 333 health a bar fresh (×17.5 by the end). Now 900 base on the guardian curve alone.
- **Kin calm removed** (author's call): it ended 15 of 16 guardian fights at the first lull.
- **Specials balance pass** across all 136 abilities with `test/ability_testbed_test.dart`: Horn Lava 12.8x → 1.8x, Pip Dark 6.0x → 1.5x, Kin Poison 4.7x → 0.7x, Pip Water 4.0x → 1.9x, Mane Fire 8.1x → 4.1x, Horn Steam 4.1x → 1.9x; Mane Spirit's stream and Mane Dust's trail no longer bill per frame; measured trims in `kSpecialBalanceTrim`. Max best-fight ratio 12.8x → 4.5x. `test/special_balance_pass_test.dart`.

- **Frame-rate dependence.** A fixed-target range run at 60 and at 120 fps found 55 of 255 ability/target pairs doing ≥1.25x more damage on a 120 Hz screen — every Mask auto-attack (2.6x), Kin Crystal's shards, Mane Light's ward ring, Wing Spirit and Wing Dark among them — because a piercing projectile with no per-body ceiling billed a body once per frame. Such projectiles now test contact on a fixed 60 Hz clock (`Projectile.takeContactTick`): nothing changes at 60 fps, and 120 fps matches it. The Mask dart now strikes each body once (rebased 0.9 → 1.17). Dungeon knockback and particle drag, and survival's VFX drag, decay per second instead of per frame. Down to 17 pairs, all positional (a companion standing somewhere else) or tunnelling, not billing. `test/contact_tick_frame_rate_test.dart`.
- **Raids after the boss rules**: clear times rose ~10–15% (mid squad L1/L2/L3 ≈ 74/143/250 s against the 10-minute limit; strong ≈ 32/59/107 s).
- **Harnesses**: `planet_dungeon_full_run_test`, `planet_dungeon_combat_test` and `planet_raid_arena_test` now build companions through `debugCreateCombatCompanion`.

The dead `tool/boss_balance_overview.dart` (it read a `lib/data/boss_data.dart` that no longer exists) was deleted.

Still open: Kin Blood and Horn Blood heal ~4x other healers in the testbed — both by design and inflated by the harness (Horn Blood buys back its own 18% sacrifice per kill; Kin Blood's pact scales with orb damage, which the harness refills forever) — not tuned; companion steering lands a Kin in a different place at 120 fps than at 60 (positioning, not damage — not chased); the mechanic-lull guardians cannot be timed by a generic sim.
