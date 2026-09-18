# Survival horde stress arena

A separate profiling entry point for 250, 500, 1,000 and 2,000 live enemies. It uses the actual Survival game, enemy updates, targeting, projectiles, damage, deaths and renderer. It does not alter the normal wave schedule or save a run.

## Run on a device

```sh
flutter devices
flutter run --profile -t tool/survival_horde_arena.dart -d <device-id>
```

Select a population and a party. **Solo mane** is one Lavamane; **Party A** (Mane, Kin, Mystic, Wing, Mask) and **Party B** (Pip, Let, Horn, Kin, Mystic) put five Alchemons out at once via Pack Leader. **Sustain** (on by default) respawns the dead at the rim so the crowd holds its size while bodies keep dying. **All specials** zeroes every companion's special cooldown on the same frame. “Mixed” substitutes ranged sentinels for 5% of the crowd. “Kill half” exercises damage, rewards and death effects instead of deleting entities.

To see *where* the time goes, sample the Dart CPU profile while the arena runs (profile builds only):

```sh
dart run tool/cpu_profile.dart <VM service URL printed by flutter run> 6 45
``` Enemy contact damage is zero and player health is replenished for profiling; upgrade menus are disabled. This is not a balance simulation.

The HUD shows rolling p95 game-update, Flutter build and raster times. Update time is part of build time: **do not add them together**. At 60 Hz each stage has a 16.7 ms budget. Profile the weakest supported real device, test sustained mixed threats, repeated specials and repeated large kills, and watch memory/thermal behavior before raising production wave caps.

## Reproduce the headless report

```sh
HORDE_REPORT_OUT=/tmp/horde flutter test test/survival_horde_stress_test.dart
flutter test test/survival_horde_render_test.dart
```

The opt-in harness seeds slow real enemies, warms up 15 updates/renders, samples 60 updates and 30 drawing-command recordings with Water, Dark, Lava and Plant active, then kills half the crowd through the damage path. Durable bodies keep the steady-state population stable. The screenshot/raster sample is taken **after** the deaths. The test renderer is not a phone GPU benchmark; snapshot raster time is an asynchronous export measurement, not frame time. Deaths have no source-slot attribution, so this burst does not cover every mastery/proc chain. The interactive arena supports attributed specials for that follow-up work.

## Initial local results (2026-09-18)

One warmed debug-mode run before and after, 900×700 viewport. Full JSON reports are included. These are directional engineering measurements, not guaranteed frame rates.

| Starting enemies | Update median before → after | Drawing-command median before → after |
| --- | --- | --- |
| 250 | 0.726 → 0.325 ms | 1.081 → 1.361 ms |
| 500 | 0.292 → 0.319 ms | 1.001 → 0.789 ms |
| 1,000 | 0.352 → 0.340 ms | 2.035 → 1.054 ms |
| 2,000 | 0.630 → 0.573 ms | 3.030 → 1.718 ms |

At 2,000 enemies, recording drawing commands improved by about 43%. The mixed/noisy smaller results show why device profiling is still necessary. The 1,000-death burst took 0.633 ms after changes; post-burst particles were capped at 150.

## Device results — Galaxy Fold (SM-F971U1), profile, cover screen (2026-09-18)

Rolling p95 over ~120 frames. Build includes update; raster is the GPU thread. Both must stay under 16.7 ms for 60 fps.

| Scenario | Alive | Update | Build | Raster |
| --- | --- | --- | --- | --- |
| 250, spread | 204 | 0.6 ms | 6.1 ms | 5.8 ms |
| 500, spread | 400 | 0.9 ms | 7.1 ms | 7.3 ms |
| 1,000, 3 s in | 990 | 2.3 ms | 14.1 ms | 15.0 ms |
| 1,000, 6 s in (converging) | 803 | 4.7 ms | 16.6 ms | 16.7 ms |
| 2,000, 3 s in | 1,969 | 5.6 ms | 20.8 ms | 16.2 ms |
| 2,000, 6 s in (converging) | 1,623 | 13.6 ms | 35.2 ms | 27.1 ms |
| 2,000 + Kill half | 1,715 | 8.2 ms | 25.6 ms | 26.4 ms |
| 2,000 mixed threats, 4 s in | 1,967 | 2.1 ms | 13.7 ms | 15.8 ms |

Four simultaneous Mane specials (Water/Dark/Lava/Plant) cleared all 2,000 arena bodies (150 HP) within 3 s; the sample after that is 11.3 ms build / 12.4 ms raster.

Readings: ~500 is comfortable, ~1,000 sits right at the frame budget, 2,000 does not hold 60 fps. Cost rises sharply as the crowd **converges** on the orb and dies in bulk. That points at dense-cell collision/separation work and the death burst, not raw entity count. Raster tracks body count, so batched swarm drawing is the other lever. The arena has no party projectiles or companion VFX beyond one Lavamane, so real runs will be heavier than these numbers.

## Round 2 — device CPU profile and fixes (2026-09-18)

Sustained 1,000 bodies, device CPU profile (UI thread, inclusive). Full solo listing in `device_profile_solo_1000.txt`.

| Hot path | Solo Lavamane | Party A | Party B |
| --- | --- | --- | --- |
| Swarm body drawing (`_drawSurvivalSwarmEnemy`) | 31.6% | 30.8% | 39.2% |
| Projectile contact queries (`_visitEnemiesNear` from `_updateCompanionProjectiles`) | 21.5% | 10.7% | — |
| Mane Lava pool painting (`_Painter.lavaPool`) | 16.7% | 12.9% | — |
| Companion target scan (`_pickCompanionTargetChoice`) | — | — | 10.6% |

HUD at 1,000 sustained: Solo 20.0 build / 21.8 raster ms; Party A 13.2 / 12.9; Party B 14.8 / 12.7.

Fixes, all visual-equivalent or result-equivalent:

- **Batched swarm bodies.** Plain wisps/drones are baked into one atlas (per element × wisp/drone × normal/hit-flash) and drawn with a single `drawRawAtlas`; damaged-body health bars go out as one `drawRawPoints` per element. Headless recording at 2,000: 1.72 → 0.57 ms.
- **Tighter contact queries.** Projectile hit tests pad by the largest live enemy radius (+12 slack) instead of a fixed 110, and grid cells shrank 180 → 96 units.
- **Lighter Lava pools in crowds.** Above 24 Mane Lava pools each draws heat fill + one glow + one crust raft, no clip. Gameplay untouched.
- **Grid-backed companion targeting.** Same scoring, but candidates come from the spatial grid within scan range, and spread-fire penalties are gathered once per pick.
- **Field ceiling.** 400 during round 2, raised to 1,000 after the device sweep below.

Wave shape check: `test/survival_horde_wave_preview_test.dart` renders overhead maps of real waves; `wave_21_fronts.png` shows the three advancing arcs at 5 s / 12 s / 20 s with the field held at 400 of a 737-body wave.

### Device results after round 2 (Galaxy Fold cover screen, profile, sustained churn)

p95 ms, build / raster. "+ specials" is 2.5–3 s after every companion was forced to cast at once. Before round 2, solo Lavamane at 1,000 read 20.0 / 21.8.

| Party | 1,000 | 1,000 + specials | 2,000 | 2,000 + specials |
| --- | --- | --- | --- | --- |
| Solo Lavamane | 8.1 / 7.0 | 7.3 / 9.2 | 14.8 / 12.3 | 11.5 / 11.9 |
| Party A (Mane, Kin, Mystic, Wing, Mask) | 8.6 / 7.6 | 9.8 / 8.4 | 14.7 / 13.0 | 14.9 / 13.1 |
| Party B (Pip, Let, Horn, Kin, Mystic) | 7.6 / 4.0 | 9.5 / 5.2 | 14.3 / 6.7 | 12.4 / 8.0 |

Every cell is inside 16.7 ms. `hordeActiveCeiling` is now **1,000**, leaving margin for bosses, companion sprites and the real HUD. What remains at 2,000 (`device_profile_partyA_2000_round2.txt`): companion target scans (14–19%), drones mid-telegraph drawn in full detail on purpose (9–18%), and the grid rebuild (~9%).

Installing: a 295 MB profile APK over wireless adb drops mid-install under `flutter run`; `adb install -r` succeeds. Launch with `am start -n com.luck3yapps.alchemons/.MainActivity --ez enable-dart-profiling true`, read the VM service URL from logcat, `adb forward` its port, then run `tool/cpu_profile.dart`.

## Implemented improvements (round 1)

- At 250+ active list entries, ordinary idle wisps/drones reuse normalized cached materials and a shared silhouette. Elites, traits, plague roots, larger tiers, active attack cues, root effects and hard freezes retain detailed rendering. Hit feedback and damaged-enemy health reads remain.
- Spatial-grid bucket lists are cleared and reused between the two frame rebuilds; query/collision semantics are unchanged.
- Hit and alchemy pickup bursts respect the remaining slots in their existing 150-particle ceiling.

Normal Survival wave caps and alchemical-meter balance remain the next gameplay pass, after real-device profiling. No enemy simulation has been throttled or attacks skipped in this change.

## Round 3 — 3,000 bodies and spawning outside the rim (2026-09-18)

**Spawning.** Walking bodies (every wave spawn and boss escort) now appear `hordeSpawnBeyondRim` = 70 units *outside* the arena rim and cross it; before, they materialised ~770 units from the orb, inside a ≥1,140-unit arena. Only enemies that portal by design appear inside: phantom blinks, summoner adds, splitter children, boss adds, outbreak cores and boss entrances. Horde body speed 0.45 → 0.6 of tier speed, so a wisp crosses rim-to-orb in ~20 s. `wave_21_fronts.png` shows the three fronts outside the rim at 3 s, crossing at 12 s and closing on the orb at 24 s.

**Caps.** `hordeActiveCeilingForWave`: 1,000 through wave 50, then linear to 3,000 at wave 100 (2,000 at wave 75). Wave totals may reach `hordeWaveTotalCeiling` = 9,000.

**Fixes.**
- **Flat enemy grid.** The Map-of-buckets grid became a column-major counting-sort window around the orb (arena + 700), with an overflow list for anything further out. Same cells, same per-cell order.
- **Skip discarded target picks.** While a companion's target lock holds, the stabiliser returns the current target and ignores the fresh pick, so the pick is no longer computed. No behaviour change.
- **Dense-field atlas (≥1,200 bodies).** Sentinels and phantoms are baked into the atlas from the detailed renderer; bodies mid-attack stay in the batch with only their telegraph drawn live. Elites, traits, roots, hard freezes and custom colours keep the full renderer.

**Device, 3,000 sustained** (p95 build / raster ms; "mixed" = 5% ranged sentinels):

| Party | Plain | + specials | Mixed | Mixed + specials |
| --- | --- | --- | --- | --- |
| Solo Lavamane | 9.8 / 8.9 | 12.5 / 11.3 | 14.0 / 11.5 | 9.3 / 9.2 |
| Party A | 9.3 / 7.8 | 11.1 / 4.7 | 14.8 / 14.2 | 11.2 / 10.3 |
| Party B | 9.9 / 3.6 | 10.0 / 5.7 | 10.5 / 5.4 | 10.8 / 6.6 |

Before the dense atlas, the same mixed runs read up to 22.7 ms build. Profile in `device_profile_partyA_3000_round3.txt`.

## Round 4 — archetypes and family roles (2026-09-18)

A horde of identical chaff asks one question, so every family answered it the
same way. The scorecard (`role_scorecard.md`, regenerate with
`ROLE_OUT=docs/horde_stress flutter test test/survival_family_role_scorecard_test.dart --tags preview`)
measures one companion at a time, every family and element, against five
scripted wave-20 problems, each also run with no companion as a baseline.

**Two archetypes joined the fronts** (both a minority of any wave):

- **Siege artillery** — `EnemyConduct.siege`, from wave 6, `artilleryCountForWave`. Walks in, parks at `kSiegeHoldRange` (820) — past a ship-anchored companion's reach — and shells the orb: 2.6x cadence, 1.9x damage, 0.62x speed, fat 7.5-radius rounds. Fragile (0.85x HP) once something reaches it.
- **Broodmothers** — the `summoner` trait promoted into an archetype, from wave 8, `broodCountForWave`. Brute-bodied, 2.2x HP, half speed, bursting `broodBurst` (4) bodies every `broodInterval` (3.4s) until cut out. Their old flat 220-body ceiling silenced them on any horde wave; the field's own limit now bounds them.

**Tuning (numbers only — no ability contract changed).** Survival's own cadence
table: Mane 0.88 → 0.70 (the family that clears waves gets its line back
sooner), Pip 1.18 → 0.95, Let 1.18 → 1.05, Wing 1.00 → 1.22. Special reach:
Let 1.10 → 2.05, Wing 1.50 → 1.95 of base. Outgoing damage: Mane 1.00 → 1.12,
Wing 1.00 → 0.88 outside boss fights.

**Where that leaves the roles** (lower orb damage is better; "target kills" is
the scenario's own threat):

| Scenario | Leader | Notes |
| --- | --- | --- |
| tide (480 chaff) | Horn 495 orb dmg | Wing 544, Let 669, Mane 889 (was 1001). Horn leads by tanking, not clearing. |
| artillery (30 siege guns) | Wing 7.1/30 | Let 0.9/30; **every other family scores 0** — reach is now a real axis. |
| brood (6 broodmothers) | Wing 5.9/6 | Mane 5.7, Let 5.4, Pip 4.6. |
| siege (6 brutes + 2 colossi) | Wing 89% | Let 83% (was 69%), Mask 79%. |
| flank (24 phantoms inside) | Horn 67 orb dmg | Wing 144, Mane 217. Horn's defensive theme reads clearly. |
| support | Kin | Highest healing everywhere (77.5 flank, 47.2 brood) and the lowest damage — its role is visible now that the harness stops topping companions up. |

**Still open:** Mane places 5th in tide despite being the wave-clearing family;
Wing still leads three of five; Pip leads nothing. Those are the next tuning
targets, and Pip probably wants a scenario built around the thing it is best at
(a packed cluster for ricochets) before its numbers are judged.

## Round 5 — run-to-run variety (2026-09-18)

Simulating three runs side by side showed the fill varied but the skeleton did
not. Identical in every run that has ever been played: the **mutator schedule**
(wave 7 Orb Siege, 9 Hunter Swarm, 11 Arc Storm, 22 Fortified...), the
**pattern** of any wave matching a modulo rule (7 and 21 Wisp Horde, 9 and 18
Siege Push, 11 Swarm Rush, 12 and 24 Shooter Screen), the **wave size** (737
bodies at wave 21, every time), the **artillery count**, and the **direction of
the escape gap**, which was `wave * 0.73`.

Now rolled per wave, from `_rng` (time-seeded in a real run):

- **Mutators** roll from `mutatorPoolForWave` — everything the wave has
  unlocked (`kMutatorUnlockWave`: Orb Siege 7, Hunter Swarm 8, Arc Storm 10,
  Mana Flux and Fortified 14, Shattered Space 18). Never the same modifier two
  waves running, and a 45% chance of none before wave 12 (22% after), so a run
  has quiet waves as well as loud ones. The old `previewMutatorForWave` is gone;
  nothing displayed it.
- **Patterns**: the modulo rules became 65% leanings instead of locks. Wave 9
  is usually a siege push; not always.
- **Wave size** carries a per-wave jitter of 0.90-1.15.
- **Fronts**: 2 (25%), 3 (53%) or 4 (22%) of them, centred on a `frontBearing`
  rolled per wave, so the gap faces somewhere new each time.

Three simulated runs afterwards, wave 7: `wispHorde/orbSiege`, `wispHorde/-`,
`hunterPack/orbSiege`. Wave 21: `mixed/arcStorm` 592 bodies,
`wispHorde/manaFlux` 666, `wispHorde/shatteredSpace` 674. Pinned by
`test/survival_wave_variety_test.dart`: two seeds must differ across at least a
third of 24 waves, the same seed must still replay exactly, and what is
authored (boss waves on fives, unlock waves, 2-4 fronts) must hold.

Late-run gate: reshuffling the seeded draws turned the single-seed wave-75
check into a different encounter, so it became a rate like wave 50's. Measured:
**wave 50 clears 12/12** at 80 Potential, **wave 75 clears 8/12** at 95 — the
far end is reachable, not guaranteed.

## Round 6 — void holes, orb health, meter pacing (2026-09-18)

**Void holes move bodies; they do not hurt them.** Mask+Dark's board says
"enemies that enter are sent out of the area (yeeted)" and the Mystic+Dark
maw's own code comment says "displacement, not execution". Both were damaging
anyway: the Mask hole ran the shared `blackHole` tick (chip + execute under 10%
HP) and the maw dealt `maw.damage` before ejecting. Now:

- `Projectile.voidEjectOnly` marks a hole that only moves things. Mask+Dark
  sets it, with `effectPower` 0 and no contact damage.
- One shared `_ejectBodyFromField` puts a body on the ring walking bodies
  arrive on — `_arenaRadius + hordeSpawnBeyondRim`, i.e. outside the rim — so
  the player gets the whole march back. It replaced the maw's own copy, whose
  ring still used the pre-rim spawn formula and would now drop bodies *inside*
  the arena.
- Mane+Dark (bolt that eats low-health bodies), Horn+Dark (void-suck then
  crush) and Pip+Dark (holes from auto-kills) still damage — their boards say
  so. Pip's is the loose one: its board says only "suck in".

**Orb health 400 → 800.** Waves went from dozens of bodies to hundreds. Note
what this does *not* do: `orbContactDamage` caps a single hit at a share of max
HP (10%, 22% heavy), so heavy bodies still need the same number of impacts. It
buys room against chaff, whose raw damage is flat.

**Orb-contact kills pay nothing** (`_killEnemy(grantAlchemyReward: false)`),
which is deliberate: a body you let through costs orb HP *and* the meter it
would have paid.

**Meter pacing, measured** (five companions, two minutes, orb kept alive):

| From wave | Upgrades | Kills | Orb damage |
| --- | --- | --- | --- |
| 6 | 8 | 980 | 32 |
| 12 | 13 | 1,850 | 882 |
| 20 | 15 | 3,087 | 1,772 |

Halving the reward did not slow upgrades down, because kills rose roughly
tenfold: the draft still opens every 8-15s. If that is too often, the lever is
`alchemicalMeterCapacity` scaling with wave size rather than another cut to the
reward.
