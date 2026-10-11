# Ability pass: power and scaling

Date: 2026-10-09. This is the first half of the full pass over all 136 specials (8 families × 17 elements). It covers power and scaling only; visuals are audited separately. It is a report: no game code was changed.

Files:

- `profiles.csv`: one row per ability. It holds the draft intent (role, intended profile), what was measured at four stat bands, a verdict, the mechanism behind any problem, and notes.
- `test/ability_scaling_report_test.dart`: the instrument (tag `preview`). It has three tests: `measure` runs the fights, `payload` is a static per-cast scan, and `aggregate` writes `profiles.csv`.

The user's brief: "we need a full pass at every alchemon special ability … some as support, some scale, some are strong early, faster progressed etc."

## The short version

1. **The family's cadence rule sets most curves, not the element design.** Most specials recharge on SPECIAL. They come back about 3× faster from P50 to P100E10 and hit about 3.5× harder per cast, so the median special's added damage grows **×10.8** across the bands. The families that ride this rule keep up or pull ahead: **Let** (median share 1.6 → 1.8) and **Mane** (2.7 → 2.8). The rest slip:
   - **Wing** (2.3 → 1.6) is the first to reach the ×6 cadence cap.
   - **Horn** (1.0 → 0.85) has charge time that the cooldown never covers.
   - **Mystic** (damage worlds 3.7 → 1.0) makes one cast per deployment.
   - **Mask** (0.16 → 0.29) recharges in 23–77 s and ignores SPECIAL.
   - **Kin** supports scale only by piling up persistent pieces.
2. **Five abilities are broken or nearly so:**
   - **Kin Ice** never fires above about P95. Every recast restarts its charge.
   - **Kin Steam** never builds stacks. Every recast zeroes them.
   - **Kin Spirit** does nothing measurable.
   - **Horn Poison**'s cast adds almost nothing on top of its passive aura.
   - **Mask Light** places one execute trap per minute.
3. **Four abilities heal as much as, or more than, all incoming damage:**
   - **Mane Blood** heals 1.4× → 8× of everything the orb takes.
   - **Wing Plant** heals 0.7× → 3.7×. Its flower effect heals the orb on every resolve; the board says flowers should power up the wing instead.
   - **Wing Water** and **Wing Crystal** reach about 1.0–1.1× at P100E10.
4. **Too strong at every band:**
   - Mane Fire: 5.0–7.1×, highest at P100E10.
   - Let Fire: 5.4–6.7×.
   - Mane Dark: 4.3–6.0×.
   - Mane Plant: 4.9–6.1×.

   **Too strong at most bands:** Let Dark (up to 4.9×, at three of four bands).

   **Too strong early:**
   - Mystic Plant: 7.3× at P50.
   - Mystic Earth: 6.7× at P50.
   - Wing Spirit: 4.0–5.1× through P90.
   - Wing Dark: 4.5–5.3× through P90.

   The ceiling is 3.3× the median of all 136, which is the testbed's established ceiling.
5. **The whole Mask family is 3–10× too weak at every band.** Its family median is 0.16–0.29× the median, and six elements read about 0 (Light, Ice, Earth, Blood, Dark, Dust).
6. **Stacking is real and widespread.** In 24 abilities, persistent pieces (zones, walls, clouds, pools, orbitals) live a fixed time while casts come 3× faster. Live pieces per caster grow ×2.6–7 from P50 to P100E10. Examples: Pip Fire pools ×7, Pip Dust clouds ×6.6, Kin Earth wall segments ×4.7 (to 64 live), and Kin Water/Plant/Air ×3.7–4. This is the only reason most Kin supports scale at all.
7. **Hook stats barely move.** The stat hooks inside abilities (durations, radii, heal %, slow strength) read a compressed stat curve. Their median growth from P50 to P100E10 is **×1.20**, against ×3 for SPECIAL. Three Mystic hooks are already maxed at stat 3:
   - the Ice blizzard, which prevents about 73% of incoming at every band;
   - the Spirit revenant cap;
   - the Lava fissure count.
8. **In-run ramps hardly exist.** Mane Light reaches its 10-feeding cap in 10 casts (11 s at P100E10). Mane Spirit's 1→10 stream becomes an 11 s sawtooth. Pip Spirit's kill stacks peak at 4–6. Mask Lightning's growing field is the only clear in-run ramp.
9. **Horn specials cost Horn its boss damage.** With the boss held, every casting Horn deals 15–30% less boss damage than the same Horn with its special held. Horn Light and Horn Dark deal about 90% less.

Profile spread (intended draft → measured):

| Family | Intended SCALER / STEADY / EARLY / RAMP / SUPPORT | Measured SCALER / STEADY / EARLY / none (+ in-run ramp) |
| --- | --- | --- |
| Horn | 2 / 3 / 3 / 0 / 9 | 2 / 11 / 4 / 0 (+2) |
| Wing | 4 / 4 / 3 / 1 / 5 | 4 / 9 / 4 / 0 |
| Let | 3 / 5 / 3 / 0 / 6 | 6 / 10 / 1 / 0 (+1) |
| Pip | 3 / 5 / 2 / 2 / 5 | 6 / 6 / 4 / 1 |
| Mane | 5 / 4 / 2 / 2 / 4 | 1 / 15 / 1 / 0 (+1) |
| Mask | 4 / 3 / 2 / 3 / 5 | 8 / 2 / 7 / 0 (+3) |
| Kin | 2 / 1 / 2 / 2 / 10 | 6 / 4 / 6 / 1 |
| Mystic | 3 / 6 / 3 / 1 / 4 | 6 / 2 / 8 / 1 |
| **All 136** | 26 / 31 / 20 / 11 / 48 | 39 / 59 / 35 / 3 (+7) |

A measured profile describes the ability's own judged axis. SUPPORT is an intent, not a measurement: a support's axis is measured as SCALER, STEADY or EARLY.

Verdicts: 46 OK and 90 flagged. Of the flagged:

- 64 have a curve that differs from the draft intent. Many of these say more about the draft than about the ability; see the open questions.
- 37 are too weak at some band.
- 22 are too strong at some band.
- 3 over-heal.
- 2 collapse: Kin Ice, plus Pip Mud, whose control reading is noise around zero.
- 1 does nothing.

An ability can carry several flags.

## Method

### The fight

Each ability is measured alone, in real survival fights, by the same `CosmicSurvivalGame` that ships. The harness mirrors `test/ability_testbed_test.dart` with these changes:

- **Subject.** One alchemon of the family and element, at level 10. Its species stats are the roster median (speed 63, intelligence 68, strength 64, beauty 69), so the comparison is between abilities, not species.
- **Four stat bands, each fought near its own wall** ([`docs/survival_stat_walls.md`](../survival_stat_walls.md)):

| Band | Potential / Enhancement | Internal stat | SPECIAL (Fire, by family) | Normal wave | Boss wave (discipline) |
| --- | --- | --- | --- | --- | --- |
| P50 | 50 / 0 | ≈4.3 | 43–81 | 28 | 30 (Siegebreaker) |
| P70 | 70 / 0 | ≈5.3 | 55–106 | 34 | 35 (Riftcaller) |
| P90 | 90 / 0 | ≈7.2 | 80–153 | 46 | 45 (Trickster) |
| P100E10 | 100 / 10 | ≈11.1 | 127–240 | 68 | 70 (Riftcaller) |

- **Four fights per band**, the testbed's set: `horde` (wisp horde), `siege` (siege push) and `shooters` (shooter screen), each with the wave's pattern held and no mutator, plus `boss`. Four seeds each (4242, 7, 19, 31). The window is 45 s at 60 Hz.
- **Special ready at the start.** A companion is deployed for the whole run, so the steady state is what matters. Without this, a 23–77 s Mask or a 60 s Mystic spends most of the window waiting for its first cast.
- **The orb and the ship are held at 60%** after every frame. Heals have room to land and nothing dies. A frame that takes more than 60% has its game-over undone, so the clock keeps running. The companion is revived if it falls.
- **A simple pilot** flies the ship at whatever is nearest the orb, the same pilot as the stat-wall report. This lets flowers, wisps and shards be collected and lets ship-borne effects run.
- **Waves restart.** If a strong ability clears the wave, the same wave is restarted, so it is measured on power and not on how many bodies the wave held.
- **The boss is held** (a separate pass, `BOSS_HOLD=1`). Below 60% it is topped back up, so the boss fight measures boss damage per second over the whole window rather than a noisy kill time. One exception: Mane Crystal still kills the held boss outright, because its boss explosion deals the boss's whole health in one hit.

### What the special adds

Every fight is run twice on the same seed:

- `full` is the alchemon as it plays.
- `auto` is the same alchemon with its special held on cooldown.

**Special-added = full − auto.** This captures everything the special adds, including what it adds through the auto attacks (Pip Steam's haste, Mask Ice's amp, Kin Steam's boiler). The four pure passives (Horn Air, Horn Mud, Pip Dark, Kin Fire) never cast, so they are compared against their family's median auto-only fight instead.

The outcome axes are the testbed's:

| Axis | What it measures |
| --- | --- |
| damage | special-added damage |
| heal | special-added healing (run-wide, by recipient) ÷ what the orb and ship lose in the nothing-deployed control fight |
| protect | (auto − full) orb and ship loss ÷ the same control loss |
| control | special-added body-seconds under slow, root, freeze, disorient or shove. Uptime as a share of all bodies is useless when a deep wave holds a thousand of them, most nowhere near one alchemon. |
| boss | special-added boss damage per second (held boss) |

**Share** is an ability's special-added damage ÷ the median of all 136 in the same band and fight, averaged over the three non-boss fights. The median special's added damage grows ×8.4 (horde), ×16.3 (siege) and ×10.1 (shooters) from P50 to P100E10. On the boss it grows ×18.2.

The median of all 136 includes about 50 abilities that do little or no damage, so it sits low. The median *damage-judged* ability reads 1.5–1.8× it.

### Profiles and verdicts

Each ability is judged on one axis (`axis` column):

- **damage** for damage specials. This includes damage specials that carry a control rider: their kills drown their control in the body-count metric.
- **heal**, **protect** or **control** (`cc` in the CSV) for supports.

The **trend** is the judged value at P100E10 ÷ at P50:

| Trend | Measured profile |
| --- | --- |
| ≥ 1.5 | SCALER |
| ≤ 0.67 | EARLY |
| between | STEADY |
| axis near zero at both ends | none |

For damage this is share against the band median, so STEADY means "tracks the median curve". For supports it is the share of the band's incoming damage, so STEADY means "keeps pace with the wall". "+RAMP" means the long pass (below) saw the special's added damage rise inside the window: last third ÷ first third ≥ 1.3× the median ability's same ratio, on bands where it does real damage.

Verdict flags:

- **too strong**: share > 3.3 at a band (the testbed's ceiling).
- **over-heals**: heal > 1.0, i.e. more than everything incoming.
- **too weak**: share < 0.3 (damage), heal < 0.05, protect < 0.03, or control < 50 body-seconds.
- **collapses**: the judged value falls below 10% of its best band.
- **wrong curve**: the measured profile does not match the intended one:

| Intended | Matches when measured is |
| --- | --- |
| SCALER | SCALER |
| STEADY | STEADY |
| EARLY | EARLY, or STEADY with a trend below 1 |
| RAMP | an in-run ramp (+RAMP) |
| SUPPORT | SCALER or STEADY |

A reviewer column (`review`) corrects the verdict where the harness misreads an ability, for example the team buffs a solo fight cannot see.

### Supporting passes

- **Long pass.** 120 s, horde and boss, two seeds, every ability. It reads in-run ramps (damage by thirds) and steady-state stacking.
- **Payload scan.** A static scan of what one cast returns at each band: counts, damage, lifetimes and radii. It shows which authored numbers move with stats.
- **Hook census.** All 98 `hornStatScale` / `_specialStatScaleFromBaseline` call sites, evaluated at the four bands.

### Run size and harness limits

The main pass ran 17,408 fights, the held-boss pass 4,352 and the long pass 4,352. That is about 26,000 fights, which took about 75 minutes of wall time on 8–14 parallel processes.

Things this harness cannot see:

- Team effects:
  - Kin Lightning chains the party's autos.
  - Kin Steam turns damage into team haste.
  - Mask Ice amps its allies.
  - Mystic Blood tithes the party's autos.
- Alchemy-meter payouts (Pip Plant, Mystic Crystal).
- Orb death (Kin Fire's phoenix).
- A pilot who flies a decoy on purpose (Kin Dark).
- Mystic Lava: only a boss crossing a fissure triggers it, and the boss fight is a single body.

The boss column also mixes boss disciplines across bands; each band is still normalised against its own boss.

## How to rerun

From the repo root, after `flutter pub get`. Each process appends JSON lines; split the families across processes and start them about 8 s apart, because parallel `flutter test` runs can collide copying into `build/`.

```bash
OUT=/tmp/scale && mkdir -p $OUT/main $OUT/boss $OUT/long
T=test/ability_scaling_report_test.dart

# 1. Main pass: 4 bands x 4 fights x 4 seeds, full and special-held (≈2,176 fights a family).
for f in horn wing let pip mane mask kin mystic; do
  FAMS=$f MODE=both SEEDS=4242,7,19,31 SECONDS=45 OUT=$OUT/main/$f.jsonl \
    flutter test $T --tags preview --plain-name measure > $OUT/main/$f.log 2>&1 &
  sleep 8
done
CONTROL=1 SEEDS=4242,7,19,31 SECONDS=45 OUT=$OUT/main/control.jsonl \
  flutter test $T --tags preview --plain-name measure
wait

# 2. Held-boss pass (replaces the main pass's boss fights in the aggregate).
FAMS=horn,wing,let,pip,mane,mask,kin,mystic SCENS=boss BOSS_HOLD=1 MODE=both \
  SEEDS=4242,7,19,31 OUT=$OUT/boss/all.jsonl flutter test $T --tags preview --plain-name measure

# 3. Long pass: in-run ramps and steady-state stacking.
FAMS=horn,wing,let,pip,mane,mask,kin,mystic SCENS=horde,boss SECONDS=120 MODE=both \
  SEEDS=4242,7 OUT=$OUT/long/all.jsonl flutter test $T --tags preview --plain-name measure

# 4. Aggregate. Reads the authored columns back from docs/ability_pass/profiles.csv
#    (line, role, intended, why, axis, review, mechanism, notes) and rewrites every
#    measured column, so an edited intent survives a rerun.
AGG_IN=$OUT/main AGG_BOSS=$OUT/boss AGG_LONG=$OUT/long AGG_OUT=docs/ability_pass \
  flutter test $T --tags preview --plain-name aggregate

# Optional: the static per-cast payload scan.
PAYLOAD_OUT=$OUT/payload.jsonl flutter test $T --tags preview --plain-name payload
```

Other filters: `ELEMS=Fire,Ice` and `BANDS=P50,P100E10`. Steps 2 and 3 can be split by family the same way as step 1.

To change an intent, edit the `intended` (or `axis`) cell in `profiles.csv` and rerun step 4 alone. The verdicts update; no fights need to be rerun.

## The family picture

Family median **share** of the median special's added damage, by band (all 17 elements). The **interval** columns give seconds between specials: the formula value (`alchemonSpecialInterval`) / what was measured in the fights.

| Family | Share P50 | P70 | P90 | P100E10 | Interval P50 | P100E10 | Cadence gain | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mane | 2.66 | 2.48 | 2.63 | 2.82 | 2.8 / 2.8 | 0.9 / 0.9 | ×3.0 | shortest cadence in the game; strongest family at every band |
| Wing | 2.34 | 2.08 | 1.73 | 1.64 | 5.6 / 5.6 | 2.2 / 2.2 | ×2.5 | SPECIAL 137 at P90: the ×6 cadence cap binds first |
| Let | 1.58 | 1.41 | 1.69 | 1.83 | 6.0 / 6.0 | 2.1 / 2.1 | ×2.8 | the only family that gains on the median |
| Horn | 1.04 | 0.93 | 1.10 | 0.85 | 4.2 / 4.9 | 1.4 / 2.2 | ×2.2 measured | cooldown frozen through every charge, wind-up and brew |
| Pip | 0.42 | 0.40 | 0.40 | 0.46 | 5.1 / 5.1 | 1.6 / 1.7 | ×3.0 | single-target darts: strong on bosses, faint on hordes |
| Mystic | 0.27 (dmg worlds 3.69) | 0.07 (2.03) | 0.18 (1.29) | 0.10 (0.97) | 60 | 60 | ×1.0 | one world per deployment |
| Mask | 0.16 | 0.18 | 0.13 | 0.29 | 40.6 / 33.1 | 28.9 / 26.7 | ×1.4 | ignores SPECIAL; 23–77 s |
| Kin | 0.10 | 0.07 | 0.05 | 0.04 | 7.1 / 7.1 | 2.3 / 2.3 | ×3.1 | support; judged on heal / protect / control |

SPECIAL itself grows ×2.9–3.0 in every family (e.g. Mane 53 → 158, Wing 72 → 215, Mystic 81 → 240). Per-cast payloads grow ×3.5–5 for most families and ×6 for Mask (counts ×1.7 × damage). The median special therefore gains ×10.8, while enemy health at the band waves grows only ×1.8 (2.45× → 4.39× wave-1 health).

On bosses (held boss), family medians are:

| Family | P50 | P100E10 | Note |
| --- | --- | --- | --- |
| Let | 6.1 | 3.6 | the boss family |
| Wing | 2.2 | 4.1 | |
| Mane | 1.3 | 3.6 | |
| Pip | 2.5 | 1.2 | |
| Mask | 0.2 | 0.4 | |
| Mystic | 0.5 | 0.2 | |
| Kin | 0 | 0 | |
| Horn | −1.4 | −0.4 | casting costs Horn boss damage (finding 9) |

## Mechanisms and recommended fixes (shared fixes first)

Each fix is ranked by how many abilities one change covers. The file:line references are against HEAD + today's balance changes.

### M7: persistent pieces stack (24 abilities)

**What.** Zones, walls, clouds, pools, orbitals and traps live a fixed time, while the caster recasts up to 3× faster. Kin, Let and Mystic trap-like pieces go through `_specialTrapPersistenceScale` (`cosmic_data.dart:5662`). It is meant to scale persistence from 3.0 to 5.0, but its stat term (rating − 4) × 0.26 + 1 never clears the 3.0 floor at any real stat. So every trap-like piece lives exactly 3× its authored life at every band.

**Evidence.** Live pieces per caster, mean over the 45 s fights, P50 → P100E10:

| Ability | Live pieces | Growth |
| --- | --- | --- |
| Pip Fire pools | 3.8 → 26.7 | ×7.0 |
| Pip Dust clouds | 8.7 → 57.5 | ×6.6 |
| Pip Crystal taunts | 0.6 → 3.9 | ×6.5 |
| Kin Earth wall segments | 13.6 → 63.8 | ×4.7 |
| Mask Lava | 1.6 → 6.7 | ×4.2 |
| Kin Plant | 1.6 → 6.6 | ×4.1 |
| Mask Poison | 1.5 → 6.1 | ×4.1 |
| Wing Fire | 3.9 → 15.8 | ×4.1 |
| Kin Water | 1.7 → 6.8 | ×4.0 |
| Wing Poison | 16 → 64 | ×3.9 |
| Wing Mud | 13 → 49 | ×3.9 |
| Mane Earth | 9.5 → 36 | ×3.8 |
| Wing Lava | 11 → 43 | ×3.8 |
| Kin Air | 1.9 → 7.0 | ×3.7 |
| Kin Crystal | 1.6 → 5.7 | ×3.6 |
| Mane Steam | 15 → 51 | ×3.4 |
| Mane Lightning | 7 → 22 | ×3.1 |
| Horn Steam | 18 → 51 | ×2.9 |
| Kin Dust | 2.3 → 6.1 | stopped by its cap of 10 |

This confirms finding (a) from the brief and generalises it beyond Kin Crystal. For Kin it is the whole scaling story:

- Kin Water heal: 0.38 → 0.83 of incoming.
- Kin Plant heal: 0.33 → 0.77.
- Kin Air protect: 0.17 → 0.45.
- Kin Earth protect: 0.33 → 0.59.

These rise because pieces pile up, not because any one piece gets better.

**Fix.** Give every persistent piece a per-caster ceiling. Options:

- the cast refreshes or replaces the caster's oldest piece once it holds N (Kin Dust already does this with a cap of 10, `kin_support_runtime.dart:295`);
- or tie a piece's life to the caster's own interval (life = k × interval), so overlap stays constant.

**Expected effect.** Live pieces flat across bands; zone damage abilities lose their extra ×3; the Kin supports above drop from SCALER to roughly flat. So this fix must ship with M5, which moves their per-piece numbers so they still grow.

### M5: the stat hooks inside abilities read a compressed curve (27 abilities dominated, 98 hook sites)

**What.** `hornStatScale` (`horn_runtime.dart:27`) and `_specialStatScaleFromBaseline` (`cosmic_data.dart:5307`) read stats above 5 through `legacyGameplayRating`. Its overcap term is still ×0.30 (`stat_system.dart:161`). So internal stats 4.25 / 5.27 / 7.14 / 11.05 read as 4.25 / 5.08 / 5.64 / 6.70, and most hooks then clamp at 1.2–1.5.

**Evidence.** Census of all 98 hook calls: the median growth from P50 to P100E10 is ×1.20 (range ×0.72–1.65). SPECIAL grows ×3.0 over the same span. Today's `statPowerPastKnee = 1.17` change did not reach these hooks. They set the durations of every timed Kin support, the Kin heal and blessing scale (capped at ×1.20), the Let impact and radius scales, the Wing power scale, Horn Light's barrier, Horn Mud's interval, and almost every Mystic world quantity (vent force, Maw and Maelstrom size, Haze/Crystal chances, tithe share, Grove/Tornado scale).

The 27 abilities whose result these hooks set are every casting Kin (14), nine Mystic worlds and four Horns (Light, Mud, Air, Water). Examples: Kin Light (heal flat at 0.29 of incoming), Kin Lava, Kin Mud, the Mystic control worlds (Steam, Dark, Water, Dust), Horn Light, Horn Mud and Horn Air.

**Fix.** Do not raise the legacy rating itself: range (`alchemonBaseRange`) and other systems read it too. Instead, move the hooks that are an ability's identity onto the anchored curve, `scaledAbilityValue` (`cosmic_data.dart:11238`), which already spans the real 2.5 → 12 band and keeps a log tail. Candidates:

- heal %, slow strength and support durations;
- Mystic world intensity;
- Horn Light barrier time.

**Expected effect.** These numbers grow ×1.5–2 across the bands instead of ×1.2. Ship it after M7, or longer durations will pile up even more pieces.

### M1: Mask cadence ignores SPECIAL (all 17 Mask)

**What.** `alchemonSpecialInterval` (`alchemon_combat_stats.dart:393`) returns 22.5 s × element multiplier (1.40–3.60) ÷ recharge stats. Unlike every other family, it never divides by `alchemonSpecialPowerFactor`.

**Evidence.**

- Cadence gains ×1.4 from P50 to P100E10 (Fire: 35.2 → 25.1 s), against ×2.5–3.1 for the other casting families.
- The real intervals run 23–77 s, so a 45 s window sees one or two casts even with the special primed.
- Per-cast payload does grow ×6 (counts ×1.7 × damage), so Mask shares mostly *rise* (Crystal, Lava, Poison and Spirit are measured SCALER).
- But the level is 3–10× too low at every band:
  - family median share 0.16 / 0.18 / 0.13 / 0.29;
  - Light, Ice, Earth, Blood, Dark and Dust read about 0;
  - only Lightning (0.4–1.2) and Spirit (0.5–1.6) get near the median.
- Brief finding (b) is confirmed for Mask's curve, but the bigger problem is the level, not the curve.

**Fix**, two levers:

1. Level: lower the element multipliers (`elementalSpecialCooldownMultiplierSurvival`, `cosmic_data.dart:5530`; currently 1.40–3.60) by about 2×. That roughly doubles casts at every band.
2. Curve: divide by the power factor relative to its value at the P50 band, e.g. × `factor(P50 SPECIAL) / factor(SPECIAL)`. Casts then grow ×3 like everyone else's without changing P50.

Both levers multiply live traps (M7), so cap traps per caster first.

**Expected effect.** About a ×2 lift at P50 and ×4 at P100E10. This puts most Mask elements at 0.5–1.5× the median.

### M2: a Mystic is one world per deployment (all 17 Mystic)

**What.** A Mystic world is lit once and holds while the caster is deployed. Its 60 s cadence (`alchemon_combat_stats.dart:398`) is flat from P50 up (Mystic SPECIAL is already 81 at P50, past the 36 that saturates it). Inside the world, the numbers ride SPECIAL ×3 (damage), the compressed hooks ×1.2 (M5), or fixed clocks:

- strike every 10 s (`kMysticStrikeInterval`, `cosmic_survival_game.dart:11424`);
- quake every 15 s (`:11425`);
- vent every 8 s (`:12283`).

Every other family also gets ×3 more casts.

**Evidence.** Every damage world is EARLY:

| World | Share P50 → P100E10 |
| --- | --- |
| Plant | 7.3 → 2.6 |
| Earth | 6.7 → 2.5 |
| Air | 4.4 → 2.0 |
| Poison | 4.4 → 1.8 |
| Spirit | 3.7 → 0.8 |
| Fire | 2.1 → 1.0 |
| Lightning | 0.4 → 0.15 |

The Mystic damage-world median is 3.7 → 1.0. They start too strong at P50 and end at or below the median.

Brief finding (b) is confirmed. The cadence itself matters little, because a world is lit once. What matters is that nothing inside the world multiplies with stats the way a recast does.

**Fix.** Scale world intensity with SPECIAL. Either:

- multiply world damage, and the shoves and holds, by `alchemonSpecialPowerFactor(SPECIAL) / factor(P50)` (the cadence gain the other families get), keeping the clocks fixed as designed ("a player has to be able to count on the rhythm");
- or let the clocks shorten with SPECIAL.

Then bring P50 down: Plant and Earth by about ÷2.

**Expected effect.** Damage worlds become STEADY (trend ≈1) at about 2–3× the median. That is a showpiece, fitting a family that fields only one.

### M3: the Horn cooldown freezes through every charge (15 casting Horns)

**What.** A Horn's cooldown does not tick while it charges, winds up or brews: the movement code returns early, and Light's barrier is gated explicitly (`cosmic_survival_game.dart:3171-3183`). Light's gate stops its autos too. This execution time is a fixed floor on top of the formula.

**Evidence.** Measured vs formula interval at P100E10:

| Horn | Measured | Formula |
| --- | --- | --- |
| most | 1.9–2.4 s | 1.4 s |
| Crystal | 3.2 s | 1.4 s |
| Spirit | 4.0 s | 1.4 s |
| Lightning | 5.0 s | 1.4 s |
| Light | 7.2 s | 1.4 s |
| Dark | 7.5 s | 1.4 s |

Measured cadence gains only ×2.2 (Dark ×1.35). The intended SCALERs measure EARLY: Horn Lava 3.65 → 2.19 and Horn Steam 3.08 → 1.91. Horn Lightning is intended STEADY and measures 1.77 → 0.85.

The same floor makes every casting Horn *lose* boss damage against its own special-held self (all negative boss shares), because the dash and wind-up replace its autos.

**Fix.** Let the cooldown tick during the dash and the post-dash windows (keep it frozen for Light's barrier, which is a channel). Or shorten the wind-ups and brews with the power factor, e.g. Dark's 5 s and Lightning's 3 s × `sqrt(factor(P50)/factor)`.

**Expected effect.** Most Horns gain ×1.4–1.6 casts at P100E10. Lava, Steam and Lightning move from EARLY to about STEADY; Dark and Lightning gain the most.

### M4: the SPECIAL cadence cap (all 17 Wing first, then every casting family at P100E10)

**What.** `alchemonSpecialPowerFactor` clamps at ×6 at SPECIAL 150 (`alchemon_combat_stats.dart:326`). Wing has the largest SPECIAL frame (elemAtk 1.30), so it reaches 137 at P90 and 215 at P100E10. Its cadence gains only ×1.29 from P90 to P100E10, against ×1.5–1.7 for the others. At P100E10, Let (176), Pip (153) and Mane (158) are capped too.

**Evidence.** Wing family share 2.34 → 1.64. The intended SCALERs (Fire, Lightning, Light, Dark) measure STEADY or EARLY. Wing Dark is too strong at P50–P90 (4.7–5.3×, from its doubled cadence at `alchemon_combat_stats.dart:427`), then 3.0× once the cap binds.

**Fix.** Keep the cap; it is what stops cadence running away. If Wing should be a scaler, move the cap for Wing alone (or lower Wing's SPECIAL frame so it reaches 150 later) and trim its P50 level. Otherwise accept STEADY and relabel Wing's intents.

### M10: heals with no ceiling on need (4 abilities)

**What.**

- Mane Blood heals 10% of shot damage per body pierced (`mane_runtime.dart:368`) through the leech path (`cosmic_survival_game.dart:15569`).
- Wing Plant's `flower` beam effect heals the orb 0.30 × effect power on every resolve (`cosmic_survival_game.dart:15641`, `cosmic_ability_runtime.dart:71`).
- Wing Water and Wing Crystal leech.

Healing scales with bodies touched × casts.

**Evidence.**

| Ability | Heal as a share of all incoming, P50 → P100E10 |
| --- | --- |
| Mane Blood | 1.4× → 8.0× |
| Wing Plant | 0.7× → 3.7× |
| Wing Water | 0.32 → 1.12 |
| Wing Crystal | 0.31 → 1.00 |

Above 1.0 the orb is effectively unkillable while the ability is up.

**Fix.** Cap heal per cast at a share of the orb's max (e.g. ≤5% per cast for Mane Blood) or make the per-body heal diminish. Wing Plant also drifts from its board ("collect flowers to power up the plant wing"): restore the power-up and drop the per-resolve heal.

### M11: per-cast executes ignore stats (7 abilities)

Mane Crystal kills a boss outright with any cast that reaches it, at every band: the held boss is removed in 3–5 s, and the boss share falls 50.9 → 4.7 only because everyone else catches up. The user's ruling keeps it.

Wing Steam (first-touch kill), Wing Blood, Let Spirit, Mane Dark and Mask Light are also per-cast executes. Their kill count per cast is fixed, so they scale only through cadence. Let Spirit even measures SCALER because its chance and its cadence both rise.

Execute credit books the body's whole remaining health. This inflates Mane Dark (4.3–6.0×) and Let Dark.

No shared fix is proposed; these are the natural EARLY or STEADY abilities.

### M12: count × payload × cadence compound (6 abilities)

Counts that grow with stats multiply the payload and the cadence:

- Mane Fire: fireballs 4 → 8, payload ×5.0, cadence ×3. Measured 5.0 → 7.1×, the strongest special in the game at P100E10.
- Mane Lightning: orbs ×1.7, payload ×6.1.
- Mask Fire, Lava and Crystal: ×1.7 counts.
- Pip Lightning: bounces ×1.9.

**Fix** for Mane Fire: hold its fireball count once SPECIAL passes the P70 band, or trim it 0.55 in `kSpecialBalanceTrim`. Mane Fire is already folded to 3.6·√(n/8) (2026-10-07); the count still doubles.

### M8: a Kin recast restarts its own running timer (2 abilities, both broken at high stats)

**Kin Ice.** Every cast sets `kinIceChargeTimer = chargeTime` (`cosmic_survival_game.dart:10625-10631`). The charge is 3.1–3.7 s; the Kin interval falls 7.1 → 2.3 s. Once the interval is shorter than the charge (about P95), the charge restarts before it releases. The Kin then stands frozen and never fires: control 4.6k → 15k → 25k body-seconds, then **0 at P100E10**.

**Kin Steam.** Every cast sets `kinSteamBoilerStacks = 0` (`:10636`). At a 2.3 s recast the boiler never builds: share 0.20 → 0.02.

**Fix.** Do not recast while an Ice charge is running (or let a recast extend the release, not restart it). Keep Steam stacks across recasts and refresh only the window.

### M6: hooks already maxed at stat 3 (3 Mystic worlds)

`hornStatScale(..., min: 0 or 0.5, max: 1.0)` is used as a 0 → 1 progress. But that curve is 1.0 at stat 3, so it is maxed for every fielded creature:

- Mystic Ice blizzard (`cosmic_survival_game.dart:12340`): "30% slower at the bottom … 55% at the top" is always 55%. It prevents about 73% of incoming at every band, the strongest single protect in the game, and flat.
- Mystic Spirit revenant cap (`:11461`): always 16 before surge.
- Mystic Lava fissure count (`:12115`): always 9.

**Fix.** Use `scaledAbilityValue(stat, atLow: 0, atAverage: 0.25, atPerfect: 1)` or similar, so the 0 → 1 actually spans the band.

### M9: the shared projectile pool (2 abilities)

Mane Lava's blob chain holds 102 → 161 of the 220-slot `companionProjectiles` (`CappedProjectileList`, `cosmic_ability_runtime.dart:781`), with peaks of 217–218 at *every* band. Its measured output is a floor set by the pool. In a party it starves everyone else's placements. This was already open in project-space-specials-drift.

Mane Dust's trail holds about 106 at every band.

**Fix.** Make a lava blob unable to spawn blobs (or cap blobs per cast), and budget Dust's trail like `kPipMudTrailBudget`.

### Smaller ones

- **M14: the cast adds little.**
  - Horn Poison's cast adds 0–0.24× the median; its passive aura, on in both modes, does the work.
  - Most Pip specials are 2–4 single-target darts whose riders are kill-gated. On hordes they read 0.1–0.5×: Lava, Blood, Spirit, Steam, Plant, Light, Crystal, Ice, Mud and Air. Most of them read 1–8× on the boss.
  - Pip is the boss family's backup, not a horde family. Lift the rider effects, or accept and relabel.
- **M15: the ramp is too short.**
  - Mane Light reaches its 10-feeding cap in 10 casts: 34 s at P50, 11 s at P100E10.
  - Mane Spirit's 1 → 10 stream resets every 10 casts.
  - Pip Spirit's kill stacks peak at 4–6.
  - Mask Plant feeds once per 31–44 s cast.

  Faster casting makes these ramps *disappear*. If RAMP is the intent, key the ramp to time or kills in the run, not to cast count.
- **M16: broken piece.** Kin Spirit's wisp shows no damage at any band. It is known to die on first contact (project-space-specials-drift).
- **Number excess**, with no structural cause found. Proposed `kSpecialBalanceTrim` entries to bring the worst under 3.3×:

| Ability | Measured | Proposed trim |
| --- | --- | --- |
| Let Fire | 5.4–6.7×; its kill blast is 0.72× the meteor to everything in reach, `cosmic_survival_game.dart:14707` | ≈0.55 |
| Mane Plant | 4.9–6.1×; already 0.71 | ≈0.6 more |
| Let Dark | up to 4.9× | ≈0.7 |
| Mane Dark | 4.3–6.0× | ≈0.6, or count execute credit at a cap |
| Wing Spirit | 5.1× at P50 | ≈0.7 |

  These trims move a level, not a curve.

## Top 10 most out of profile

1. **Kin Ice** (intended SCALER): collapses to nothing at P100E10. Its charge never releases. M8.
2. **Kin Steam** (SUPPORT): 0.20 → 0.02. Its stacks are zeroed by every recast. M8.
3. **Mane Blood** (SUPPORT, heal): heals 1.4× → 8× of all incoming orb damage. M10.
4. **Wing Plant** (RAMP): over-heals 1.4–3.7× and shows no ramp. The flower effect heals the orb instead of powering up the wing. M10 + design drift.
5. **Mask Light / Ice / Earth / Dark / Dust** (EARLY, SCALER and SUPPORT intents): about 0 at every band. M1 (one cast per 23–77 s) + M11 (Light) + harness-blind (Ice).
6. **Mystic Plant and Earth** (STEADY / SCALER): 7.3× and 6.7× at P50, falling to 2.6× and 2.5×. Spirit (RAMP) 3.7 → 0.8. M2.
7. **Mane Fire** (SCALER): 5.0–7.1×, too strong at every band and highest at P100E10. M12.
8. **Let Fire** (SCALER): 5.4–6.7× at every band. Number excess.
9. **Mystic Ice** (SUPPORT): full strength from stat 3, prevents about 73% of incoming at every band. M6.
10. **Horn Lava and Horn Steam** (SCALER): measured EARLY, 3.65 → 2.19 and 3.08 → 1.91. Horn Lightning (STEADY) 1.77 → 0.85. M3.

Close behind:

- Mane Dark, 4.3–6.0× at every band (M11 credit).
- Wing Dark, 4.7–5.3× through P90 (M4).
- Mane Lava, pool-capped (M9).
- Kin Spirit, does nothing (M16).

## Fixes ranked by how many abilities one change covers

| # | Change | Abilities covered | Expected effect |
| --- | --- | --- | --- |
| 1 | M5: move identity hooks (heal %, slow, support durations, world intensity) to the anchored `scaledAbilityValue` curve | 27 dominated (98 hook sites) | supports' own numbers grow ×1.5–2 instead of ×1.2 |
| 2 | M7: cap persistent pieces per caster (refresh oldest), or life ∝ own interval | 24 | live pieces flat across bands; zone damage loses its hidden ×3 |
| 3 | M1: Mask element multipliers ÷2, and Mask cadence relative to its P50 power factor | 17 | Mask ×2 at P50, ×4 at P100E10 |
| 4 | M2: Mystic world intensity × SPECIAL power factor (clocks stay fixed); P50 Plant/Earth ÷2 | 17 | damage worlds STEADY at 2–3× |
| 5 | M3: Horn cooldown ticks through dashes; wind-ups/brews shorten with the power factor | 15 | Horn cadence ×1.4–1.6 at P100E10; Lava/Steam/Lightning ≈ STEADY; less boss-damage loss |
| 6 | M4: decide Wing (cap per family or relabel) | 17 | relabel or Wing ≈ STEADY → SCALER |
| 7 | M11/M12 + number excess: `kSpecialBalanceTrim` for Let Fire, Mane Fire/Plant/Dark, Let Dark, Wing Spirit; hold Mane Fire's count | 7 | all under 3.3× |
| 8 | M10: per-cast heal ceilings; restore Wing Plant's power-up | 4 | heal ≤ incoming |
| 9 | M6: real 0 → 1 curve for the three Mystic hooks | 3 | Mystic Ice grows instead of starting maxed (and should drop at P50) |
| 10 | M8: Kin Ice no recast mid-charge; Kin Steam keeps stacks | 2 | both work at high stats |
| 11 | M9: Mane Lava blobs cannot spawn blobs; budget Mane Dust's trail | 2 | frees 100–200 pool slots |

M7 and M5 must ship together. Removing stacking alone flattens the Kin supports, and lengthening durations alone deepens the stacking.

## In-run ramps (the RAMP reading)

The long pass (120 s) compares special-added damage in the last third with the first, normalised by the median ability's own ratio (≈1.37, because the field fills up). Results:

- **Clear ramp:** Mask Lightning. The field grows per body; the last third is 2.5–6× the first.
- **Ramp that collapses with stats:**
  - Mane Spirit and Mane Light reach their cap in 10 casts.
  - Horn Steam ramps at P50 only.
- **No visible ramp:**
  - Pip Spirit: stacks 4–6, then reset.
  - Pip Steam: its 9 s window is a cycle.
  - Mask Plant: one feeding per 31–44 s.
  - Kin Dust: clouds reach the cap of 10.
  - Kin Spirit: does nothing.
  - Mystic Spirit: the revenant cap is maxed (M6).
  - Wing Plant: flowers were rarely collected, 0–18 a run.

## Open questions for the author

1. **What does "faster progressed" mean?** We read it as RAMP: an ability that grows *within a run* as it is used. That is an assumption. Another reading is "front-loaded": reaches its full power at moderate breeding (around P70–P90), then flattens. Several abilities already behave that way through count caps that finish at P95 (`kAbilityFinalStepPotential`) and hooks that saturate. If that is the meaning, RAMP should be redefined as a curve shape, and the in-run ramps above should be judged as STEADY.
2. **Every SCALER / STEADY / EARLY label is a proposal.** The boards say *what* each special does, never how it should scale. The `intended_is_proposed = no (board)` rows are only those where the board names a stat range or a ramp ("3–25 by stats", "1 → 10 per cast"). Please edit `intended` in `profiles.csv` and rerun the aggregate step.
3. **Should Mask ride SPECIAL at all?** The design says "the placement is the rare action". If so, only the level lever (element multipliers) applies.
4. **Is EARLY acceptable for Mystic?** Worlds are lit once and keep fixed clocks by design. If the showpiece should stay a showpiece at P100E10, world intensity has to read SPECIAL (M2).
5. **Wing:** make it a scaler (move the cap) or relabel it STEADY?
6. **Horn on bosses:** is losing boss damage by casting acceptable for the tank family, or should the cooldown tick through dashes (M3)?
7. **Over-heal:** should Mane Blood / Wing Plant / Wing Water be capped per cast, and should Wing Plant go back to its board (flowers power up the wing)?
8. **The 3.3× ceiling** is against the median of all 136, which includes about 50 non-damage abilities. The median damage special reads 1.5–1.8×. Keep 3.3×, or judge damage specials against the damage median?
9. **Kin Ice / Kin Steam:** fix as bugs (M8)?

## All 136 (draft profile table)

**Share** is the special-added damage ÷ the band median at P50 / P70 / P90 / P100E10. For supports, the judged axis is appended at P50 / P100E10:

- **heal** and **protect**: share of incoming;
- **control**: body-seconds.

"(board)" marks an intent the board implies; everything else is proposed. The full numbers, mechanism and notes are in `profiles.csv`.

### Horn (bulky defence tank)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | Thornguard Charge | Charge roots every survivor it hits for 3 s | control | damage | SUPPORT | STEADY+RAMP | 1.00 / 0.93 / 1.17 / 1.34 | OK |
| Air | Gale Crash | PASSIVE: shoves nearby bodies out toward the rim | control | cc | EARLY | STEADY | -0.09 / -0.19 / -0.13 / -0.12 · control 122 / 143 | curve (EARLY, measured STEADY) |
| Dust | Sandstorm Ram | Impact cyclone pulls bodies in and turns shooters on each other | control | cc | SUPPORT | STEADY | 1.08 / 0.86 / 0.84 / 0.74 · control 889 / 1043 | OK |
| Lava | Magma Ram | Slow heavy slam; bodies the slam kills burst into homing flames | damage | damage | SCALER | EARLY | 3.65 / 2.96 / 2.74 / 2.19 | strong P50 (3.6x); curve (SCALER, measured EARLY) |
| Poison | Toxic Ram | Charge poisons everything it sweeps, plus a passive toxic aura | damage | damage | STEADY | SCALER | -0.04 / 0.13 / 0.20 / 0.24 | weak P50/P70/P90/P100E10; curve (STEADY, measured SCALER) — the cast adds almost nothing on top of its passive aura |
| Blood | Crimson Fortress | Sacrifices 18% HP for a harder ram; kills in the window heal 5% max HP | damage | damage | EARLY | STEADY | 1.04 / 1.00 / 1.15 / 1.42 | curve (EARLY, measured STEADY) |
| Earth | Cataclysmic Fortress | Impact leaves a high-HP decoy clone that taunts and quakes | support-protect | protect | SUPPORT | STEADY | 2.75 / 1.97 / 1.75 / 1.63 · protect 0.43 / 0.52 | OK |
| Light | Radiant Guard | Stationary barrier: reflects shots, bounces bodies, allies inside take 30% | support-protect | protect | SUPPORT (board) | STEADY | -0.26 / -0.06 / -0.11 / -0.15 · protect 0.43 / 0.44 | OK |
| Spirit | Spirit Bastion | Wind-up with damage reduction, then six taunting phantom wisps | support-protect | protect | SUPPORT | STEADY | 0.41 / 0.42 / 0.46 / 0.52 · protect 0.18 / 0.22 | OK |
| Crystal | Crystal Bulwark | Six orbiting shards each block two shots, then shatter into shrapnel | support-protect | protect | SUPPORT | STEADY | 0.76 / 0.59 / 0.61 / 0.81 · protect 0.25 / 0.32 | OK |
| Fire | Blazing Charge | Rams a line, leaving burning patches that taunt and burn | control | protect | STEADY | STEADY | 2.82 / 2.17 / 1.94 / 1.51 · protect 0.48 / 0.55 | OK |
| Lightning | Thunder Crash | Dash, brew a 3 s storm, discharge a chain blast boosted by damage absorbed | damage | damage | STEADY | EARLY+RAMP | 1.77 / 1.42 / 1.10 / 0.85 | curve (STEADY, measured EARLY) |
| Steam | Pressure Crash | Slam drops a geyser; a slam kill resets the cooldown and adds a geyser | damage | damage | SCALER | EARLY | 3.08 / 2.31 / 2.30 / 1.91 | curve (SCALER, measured EARLY) |
| Dark | Shadow Crash | 5 s void suck, then a dash that carries the captured bodies and hits them | control | protect | EARLY | STEADY | 1.53 / 1.27 / 1.18 / 0.93 · protect 0.27 / 0.21 | OK |
| Ice | Glacier Slam | Sideways dash painting an ice wall that taunts, slows and reflects shots | support-protect | protect | SUPPORT | STEADY | 0.70 / 0.63 / 0.71 / 0.65 · protect 0.36 / 0.33 | OK |
| Mud | Quagmire Crash | PASSIVE: drops slowing sludge wherever it walks (interval from Intelligence) | control | cc | SUPPORT (board) | SCALER | 0.06 / 0.02 / 0.03 / 0.02 · control 532 / 1106 | OK |
| Water | Tidal Guard | Circular sweep, then a whirlpool that pulls and slows | control | cc | SUPPORT | EARLY | 2.09 / 1.63 / 1.73 / 1.53 · control 684 / 339 | curve (SUPPORT, measured EARLY) |

### Wing (beams)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | Vine Beam | Kills become flowers; collected flowers power up the wing | damage | damage | RAMP (board) | EARLY | 1.74 / 1.54 / 1.28 / 1.06 | over-heals at P70 (1.4x); over-heals at P90 (1.9x); over-heals at P100E10 (3.7x); curve (RAMP, measured EARLY, no in-run ramp) — design drift: heals the orb per resolve instead of powering up the wing; over-heals 1.4-3.7x incoming |
| Air | Tornado Drill | Beam blows bodies back | control | damage | EARLY | EARLY | 1.40 / 1.30 / 1.09 / 0.87 | OK |
| Dust | Sandstorm Beam | Dusts bodies so shooters fire on each other | control | cc | SUPPORT | SCALER | 1.61 / 1.39 / 1.21 / 0.98 · control 38 / 60 | weak P50 |
| Lava | Eruption Trench | Beam leaves a burning scar that hurts bodies crossing it | damage | damage | STEADY | STEADY | 2.95 / 2.76 / 2.66 / 2.33 | OK |
| Poison | Venom Spine | Fires all round, leaving a poison ring round the map edge | damage | damage | STEADY | STEADY | 3.16 / 2.93 / 2.64 / 2.25 | OK |
| Blood | Crimson Lance | Locks onto the lowest-health body and executes | damage | damage | EARLY | STEADY | 1.56 / 1.53 / 1.42 / 1.21 | OK |
| Earth | Boulder Beam | Standard beam, and the orb fires one too | damage | damage | STEADY | STEADY | 3.72 / 3.06 / 3.01 / 2.68 | strong P50 (3.7x) |
| Light | Radiant Beam | A kill splits the beam into two refracted beams | damage | damage | SCALER | STEADY | 2.68 / 2.82 / 2.63 / 2.00 | curve (SCALER, measured STEADY) |
| Spirit | Reaper Beam | Tethers to the ship, which then lasers the nearest bodies too | damage | damage | STEADY | EARLY | 5.06 / 4.04 / 4.00 / 3.25 | strong P50 (5.1x); strong P70 (4.0x); strong P90 (4.0x); curve (STEADY, measured EARLY) |
| Crystal | Prism Refraction | Beam damage heals the orb | support-heal | heal | SUPPORT | SCALER | 1.61 / 1.42 / 1.18 / 0.95 · heal 0.31 / 1.00 | OK |
| Fire | Sweeping Flamebeam | Sweeps a beam round the whole map; big damage | damage | damage | SCALER | STEADY | 2.35 / 2.08 / 1.57 / 1.74 | curve (SCALER, measured STEADY) |
| Lightning | Chain Lightning Web | Charges, then one heavy blast | damage | damage | SCALER | STEADY | 2.23 / 2.00 / 1.45 / 1.64 | curve (SCALER, measured STEADY) |
| Steam | Boiler Shear | Kills the first body it touches and leaves 5-10 steam clouds | damage | damage | EARLY | STEADY | 2.34 / 2.62 / 1.93 / 2.02 | OK |
| Dark | Void Rake | PASSIVE: laser and autos fire twice as fast | damage | damage | SCALER (board) | EARLY | 4.68 / 5.29 / 4.48 / 3.04 | strong P50 (4.7x); strong P70 (5.3x); strong P90 (4.5x); curve (SCALER, measured EARLY) |
| Ice | Ice Lance Burst | Held beam builds frost; enough freezes the target | control | damage | SUPPORT | STEADY | 2.06 / 1.85 / 1.73 / 1.38 | OK |
| Mud | Mire Rake | Bodies the beam touches are slowed for good | control | cc | SUPPORT | SCALER | 2.46 / 2.37 / 1.74 / 1.54 · control 593 / 2189 | OK |
| Water | Tidal Beam | Heals the lowest-health ally or ship by % max HP; damages along the beam | support-heal | heal | SUPPORT | SCALER | 1.72 / 1.74 / 1.41 / 1.29 · heal 0.32 / 1.12 | over-heals at P100E10 (1.1x) |

### Let (meteors)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | Seed Bombardment | A kill grows five vine traps that each strike the first body | damage | damage | STEADY | SCALER | 1.06 / 1.03 / 1.39 / 1.77 | curve (STEADY, measured SCALER) |
| Air | Atmospheric Bomb | Meteor; any hit shoves everything nearby back | control | damage | EARLY | STEADY | 1.40 / 1.26 / 1.29 / 1.58 | curve (EARLY, measured STEADY) |
| Dust | Sandstorm Meteor | Impact leaves a slowing dust cloud | control | damage | SUPPORT | STEADY | 1.58 / 1.45 / 1.71 / 1.97 | OK |
| Lava | Volcanic Bombardment | Impact leaves burning ground | damage | damage | STEADY | STEADY | 2.98 / 2.40 / 2.28 / 2.04 | OK |
| Poison | Toxic Storm | Poisons what it hits | damage | damage | STEADY | STEADY | 2.52 / 1.99 / 2.05 / 1.99 | OK |
| Blood | Transfusion Meteor | A kill splits it into leeches that drain bodies and heal the team | support-heal | heal | SUPPORT | SCALER | 0.95 / 0.87 / 1.09 / 1.55 · heal 0.06 / 0.14 | OK |
| Earth | Moon Drop | Heaviest meteor; a share of damage dealt heals the lowest-HP ally or ship | damage | damage | SCALER | STEADY | 2.28 / 2.23 / 2.48 / 2.59 | curve (SCALER, measured STEADY) |
| Light | Celestial Rain | A kill leaves a pool of light that heals allies and ship | support-heal | heal | SUPPORT | SCALER | 0.88 / 0.82 / 1.11 / 1.55 · heal 0.46 / 0.81 | OK |
| Spirit | Soul Harvest | Chance to one-shot (20%, rising with stats) | damage | damage | EARLY (board) | SCALER+RAMP | 0.76 / 0.78 / 1.00 / 1.45 | curve (EARLY, measured SCALER) |
| Crystal | Starfall | Half cooldown, weaker hits, 90% slow on what it hits | control | damage | EARLY (board) | STEADY | 2.53 / 2.14 / 2.31 / 2.50 | OK |
| Fire | Flame Meteor | A kill sets off a big explosion | damage | damage | SCALER | STEADY | 6.73 / 5.75 / 5.37 / 5.67 | strong P50 (6.7x); strong P70 (5.7x); strong P90 (5.4x); strong P100E10 (5.7x); curve (SCALER, measured STEADY) |
| Lightning | Orbital Strike | Hits chain to nearby bodies | damage | damage | STEADY | SCALER | 0.90 / 0.89 / 1.38 / 1.67 | curve (STEADY, measured SCALER) |
| Steam | Geyser Strike | A kill leaves a long-lived geyser that pushes bodies | control | damage | SUPPORT | EARLY | 3.44 / 2.82 / 2.53 / 2.24 | strong P50 (3.4x); curve (SUPPORT, measured EARLY) |
| Dark | Void Meteor | A kill throws up to five more, bigger meteors | damage | damage | SCALER | STEADY | 3.69 / 3.08 / 3.74 / 4.89 | strong P50 (3.7x); strong P90 (3.7x); strong P100E10 (4.9x); curve (SCALER, measured STEADY) |
| Ice | Comet Cluster | Freezes what it hits | control | damage | SUPPORT | SCALER | 0.76 / 0.78 / 1.11 / 1.55 | OK |
| Mud | Quagmire Meteor | A kill leaves a pool that stuns bodies inside | control | damage | SUPPORT | STEADY | 1.60 / 1.41 / 1.69 / 1.76 | OK |
| Water | Tidal Meteor | Impact splashes the bodies around it | damage | damage | STEADY | STEADY | 1.28 / 1.17 / 1.57 / 1.83 | OK |

### Pip (ricochet)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | Thorn Ricochet | Kills feed the alchemy meter 50% more | utility | damage | STEADY | STEADY | 0.29 / 0.36 / 0.29 / 0.36 | weak P50/P90 — harness-blind: pays out in alchemy meter |
| Air | Cyclone Chain | Ricochets; survivors are pushed back | control | cc | EARLY | NONE | 0.48 / 0.50 / 0.50 / 0.57 · control -1 / 3 | weak P50/P70/P90/P100E10 |
| Dust | Sand Chain | Ricochets; a kill leaves a small slowing dust cloud | control | cc | SUPPORT | SCALER | 0.59 / 0.56 / 0.62 / 0.67 · control 1890 / 8434 | OK |
| Lava | Magma Chain | Survivors burn | damage | damage | STEADY | EARLY | 0.26 / 0.26 / 0.17 / 0.14 | weak P50/P70/P90/P100E10; curve (STEADY, measured EARLY) |
| Poison | Pandemic Chain | Draws a poison line between hit bodies that lasts until the next cast | damage | damage | STEADY | EARLY | 1.30 / 1.07 / 0.94 / 0.82 | curve (STEADY, measured EARLY) |
| Blood | Hemorrhage Chain | Kills heal the blood pip | damage | damage | EARLY | EARLY | 0.42 / 0.27 / 0.27 / 0.25 | weak P70/P90/P100E10 |
| Earth | Tremor Chain | Each auto shaves the special cooldown | damage | damage | SCALER (board) | SCALER | 1.02 / 1.07 / 1.17 / 2.15 | OK |
| Light | Blessing Chain | Kills heal the orb | support-heal | heal | SUPPORT | SCALER | 0.23 / 0.29 / 0.28 / 0.24 · heal 0.08 / 0.43 | OK |
| Spirit | Haunt Chain | Kills stack; at the threshold, a window of up to 10x attack speed | damage | damage | RAMP (board) | STEADY | 0.37 / 0.31 / 0.36 / 0.25 | weak P100E10; curve (RAMP, measured STEADY, no in-run ramp) |
| Crystal | Crystal Shatter | The last kill leaves a taunting crystal | support-protect | protect | SUPPORT | SCALER | 0.31 / 0.27 / 0.40 / 0.39 · protect 0.02 / 0.06 | weak P50 |
| Fire | Flame Ricochet | Kills leave burning pools | damage | damage | STEADY | STEADY | 1.58 / 1.33 / 1.40 / 1.75 | OK |
| Lightning | Thunder Chain | Double the ricochets (most bounces) | damage | damage | SCALER (board) | STEADY | 1.12 / 1.21 / 1.25 / 1.28 | curve (SCALER, measured STEADY) |
| Steam | Steam Ricochet | A steam cloud ramps its attack speed 50% -> 300% over a window | damage | damage | RAMP (board) | SCALER | 0.15 / 0.29 / 0.09 / 0.29 | weak P50/P70/P90/P100E10; curve (RAMP, measured SCALER, no in-run ramp) |
| Dark | Black Hole Passive | PASSIVE: auto kills open black holes that suck bodies in | control | damage | STEADY | EARLY | 3.29 / 2.44 / 2.02 / 1.76 | curve (STEADY, measured EARLY) |
| Ice | Frost Chain | Survivors freeze | control | cc | SUPPORT | SCALER | 0.30 / 0.40 / 0.40 / 0.46 · control 3 / 23 | weak P50/P70/P90/P100E10 |
| Mud | Mire Ricochet | Hit bodies leave mud trails that slow others | control | cc | SUPPORT | STEADY | 0.32 / 0.19 / 0.21 / 0.35 · control -57 / 4 | collapses at P50/P70/P100E10; weak P50/P70/P100E10 — control reading is noise around zero (trails are budgeted, kPipMudTrailBudget 48); the collapse flag is not real |
| Water | Tidal Ricochet | Each kill splashes; a last-hit kill splashes hugely | damage | damage | SCALER | STEADY | 2.37 / 2.23 / 2.06 / 2.22 | curve (SCALER, measured STEADY) |

### Mane (catapult / piercing)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | Vine Lariat | Thickens with every body pierced; roots; rooted kills explode | damage | damage | STEADY | STEADY | 6.05 / 4.95 / 5.67 / 5.72 | strong P50 (6.1x); strong P70 (4.9x); strong P90 (5.7x); strong P100E10 (5.7x) |
| Air | Windblade Sweep | Fast shot that carries the bodies in its path | control | damage | EARLY (board) | STEADY | 2.12 / 2.01 / 2.14 / 2.39 | curve (EARLY, measured STEADY) |
| Dust | Sandblade Fan | Leaves a dust trail; bodies inside cannot shoot | control | damage | SUPPORT | STEADY | 3.40 / 2.71 / 3.07 / 3.44 | strong P50 (3.4x); strong P100E10 (3.4x) |
| Lava | Molten Cleave | Drops a lava blob at every body it pierces | damage | damage | STEADY | STEADY | 4.17 / 3.40 / 2.84 / 2.81 | strong P50 (4.2x); strong P70 (3.4x) — pool-capped from P50 (M9): measured output is a floor set by the 220-slot pool, and it starves a party |
| Poison | Venom Edge | Each body pierced adds a poison stack; stacks hit harder | damage | damage | SCALER | STEADY | 2.65 / 2.48 / 2.63 / 3.08 | curve (SCALER, measured STEADY) |
| Blood | Bloodedge Rush | Heals the orb for each body pierced | support-heal | heal | SUPPORT | SCALER | 2.35 / 2.15 / 2.33 / 2.81 · heal 1.36 / 8.03 | over-heals at P50 (1.4x); over-heals at P70 (2.2x); over-heals at P90 (3.9x); over-heals at P100E10 (8.0x) — over-heals: 1.4x-8x of all incoming orb damage |
| Earth | Faultline Guardbreak | Starts huge, crawls, breaks apart into smaller shots | damage | damage | SCALER | STEADY | 3.55 / 3.06 / 3.43 / 3.64 | strong P50 (3.5x); strong P90 (3.4x); strong P100E10 (3.6x); curve (SCALER, measured STEADY) |
| Light | Radiant Ward | Orbiting ward rings that grow every cast (up to 10 feedings) | damage | damage | RAMP (board) | STEADY | 1.17 / 1.00 / 0.80 / 0.79 | curve (RAMP, measured STEADY, no in-run ramp) |
| Spirit | Phaseblade Rush | Each cast adds a shot to the stream, 1 -> 10, then resets | damage | damage | RAMP (board) | STEADY | 2.66 / 2.26 / 2.48 / 2.43 | curve (RAMP, measured STEADY, no in-run ramp) |
| Crystal | Prism Edge | Explodes for huge AoE when it hits a boss | damage | damage | SCALER | STEADY | 3.55 / 2.90 / 3.14 / 3.85 | strong P50 (3.5x); strong P100E10 (3.8x); curve (SCALER, measured STEADY) — boss instakill at every band (user ruling keeps it) |
| Fire | Flameblade Combo | 3-8 fast fireballs | damage | damage | SCALER (board) | STEADY | 5.63 / 5.03 / 5.66 / 7.07 | strong P50 (5.6x); strong P70 (5.0x); strong P90 (5.7x); strong P100E10 (7.1x); curve (SCALER, measured STEADY) |
| Lightning | Storm Rod Field | 5-10 orbs placed on the map shock nearby bodies | damage | damage | SCALER (board) | STEADY | 2.22 / 1.80 / 1.85 / 2.01 | curve (SCALER, measured STEADY) |
| Steam | Pressure Vent Cuts | Geyser shot leaves steam damage zones as it travels | damage | damage | STEADY | STEADY | 2.93 / 2.80 / 2.74 / 3.19 | OK |
| Dark | Voidcut Drive | Slow bolt that drags bodies in and eats low-health ones | damage | damage | EARLY | STEADY | 5.97 / 4.34 / 4.48 / 5.24 | strong P50 (6.0x); strong P70 (4.3x); strong P90 (4.5x); strong P100E10 (5.2x) |
| Ice | Frostguard Cleave | Freezes everything it touches | control | damage | SUPPORT | STEADY | 2.66 / 2.15 / 2.49 / 2.66 | OK |
| Mud | Bogbreaker Combo | Breaks on the first body into 10 shards | damage | damage | STEADY | EARLY+RAMP | 0.91 / 0.66 / 0.61 / 0.56 | curve (STEADY, measured EARLY) |
| Water | Tidecross Volley | A wall of water that carries bodies with it | control | damage | SUPPORT | STEADY | 2.18 / 1.95 / 2.34 / 2.82 | OK |

### Mask (traps)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | Vine Snare Construct | One vine, fed bigger every cast; attacks and slows | damage | damage | RAMP (board) | EARLY | 0.32 / 0.32 / 0.13 / 0.17 | weak P90/P100E10; curve (RAMP, measured EARLY, no in-run ramp) |
| Air | Cyclone Lure Field | 3-25 traps that blow bodies back | control | cc | SUPPORT (board) | EARLY | 0.33 / 0.24 / 0.22 / 0.39 · control 5 / 3 | weak P50/P70/P90/P100E10; curve (SUPPORT, measured EARLY) |
| Dust | Caltrop Lure Field | A dust shield round each alchemon that hurts what collides | support-protect | protect | SUPPORT | EARLY | 0.21 / 0.10 / 0.03 / 0.14 · protect 0.02 / 0.01 | weak P50/P90/P100E10; curve (SUPPORT, measured EARLY) |
| Lava | Volcanic Taunt Idol | 5-15 lava pools | damage | damage | SCALER (board) | SCALER | 0.16 / 0.18 / 0.22 / 0.37 | weak P50/P70/P90 |
| Poison | Plague Snare Grid | Poison clouds | damage | damage | STEADY | SCALER | 0.15 / 0.42 / 0.27 / 0.41 | weak P50/P90; curve (STEADY, measured SCALER) |
| Blood | Blood Lure Obelisk | Bodies through the blob are drained for good, healing all alchemons | support-heal | heal | SUPPORT | SCALER | 0.06 / -0.11 / -0.05 / 0.09 · heal 0.02 / 0.05 | weak P50/P70/P90 |
| Earth | Monolith Taunt Field | 2-5 heal pools for ship and alchemons | support-heal | heal | SUPPORT (board) | SCALER | 0.03 / -0.02 / 0.04 / 0.05 · heal 0.01 / 0.05 | weak P50/P70/P90/P100E10 |
| Light | Beacon Snare Field | A light void kills the first body to touch it | damage | damage | EARLY | STEADY | -0.02 / -0.11 / 0.02 / 0.07 | weak P50/P70/P90/P100E10; curve (EARLY, measured STEADY) — never matters: one execute trap per minute |
| Spirit | Phantom Lure Totem | Wisps the ship collects; enough of them nukes every non-boss | damage | damage | RAMP (board) | SCALER | 0.47 / 0.79 / 0.60 / 1.60 | curve (RAMP, measured SCALER, no in-run ramp) |
| Crystal | Prism Snare Totem | 3-7 big crystals; each breaks into 3 on contact | damage | damage | SCALER (board) | SCALER | 0.08 / 0.06 / 0.09 / 0.30 | weak P50/P70/P90 |
| Fire | Inferno Lure Grid | 5-15 fireballs; a contact leaves a burning pool | damage | damage | SCALER (board) | STEADY+RAMP | 0.50 / 0.24 / 0.36 / 0.44 | weak P70; curve (SCALER, measured STEADY) |
| Lightning | Tesla Snare Grid | A field that grows with every body that hits it | damage | damage | RAMP (board) | EARLY+RAMP | 1.19 / 0.94 / 0.41 / 0.77 | OK |
| Steam | Steam Pressure Lure | Mini geysers that shoot at bodies | damage | damage | STEADY | SCALER | 0.54 / 1.08 / 0.70 / 0.85 | curve (STEADY, measured SCALER) |
| Dark | Void Taunt Well | A hole that throws bodies out of the arena | control | protect | EARLY (board) | EARLY | 0.07 / -0.10 / -0.07 / -0.01 · protect 0.02 / -0.03 | weak P50/P70/P90/P100E10 |
| Ice | Frost Snare Totem | A pillar that makes nearby allies hit 2-5x harder | utility | damage | SCALER (board) | EARLY | 0.13 / 0.01 / -0.05 / 0.02 | weak P50/P70/P90/P100E10; curve (SCALER, measured EARLY) — harness-blind: the amp is for allies |
| Mud | Bog Snare Pit | A mud pool that slows | control | cc | SUPPORT | SCALER | -0.06 / -0.05 / -0.05 / 0.04 · control 1109 / 6060 | OK |
| Water | Tidal Lure Net | Traps that splash bodies on contact | damage | damage | STEADY | EARLY+RAMP | 0.44 / 0.48 / 0.30 / 0.29 | weak P90/P100E10; curve (STEADY, measured EARLY) |

### Kin (rare support)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | Divine Bloom | A garden that drops healing flowers for the ship to collect | support-heal | heal | SUPPORT | SCALER | -0.00 / -0.02 / -0.02 / -0.01 · heal 0.33 / 0.77 | OK |
| Air | Hurricane Blessing | An updraft round the ship that flings bodies away | support-protect | protect | SUPPORT | SCALER | 0.19 / 0.18 / 0.29 / 0.42 · protect 0.17 / 0.45 | OK |
| Dust | Sandstorm Blessing | Dust clouds that pile up cast after cast; shots inside may miss | support-protect | protect | RAMP (board) | STEADY | 0.10 / 0.07 / -0.06 / -0.04 · protect 0.41 / 0.53 | curve (RAMP, measured STEADY, no in-run ramp) |
| Lava | Volcanic Blessing | Plate armour that splashes lava back at whatever strikes | support-protect | protect | SUPPORT | STEADY | 3.95 / 2.74 / 2.15 / 1.61 · protect 0.36 / 0.36 | strong P50 (4.0x) |
| Poison | Plague Blessing | A burst of homing poison darts | damage | damage | STEADY | EARLY | 0.60 / 0.39 / 0.29 / 0.35 | weak P90; curve (STEADY, measured EARLY) |
| Blood | Blood Well | A pact: damage any alchemon takes is shared and healed across the others | support-heal | heal | SUPPORT | STEADY | -0.02 / 0.05 / -0.01 / -0.01 · heal 0.42 / 0.53 | OK |
| Earth | Fortress Blessing | A stone wall bodies cannot path through | support-protect | protect | SUPPORT | SCALER | 0.32 / 0.43 / 0.23 / 0.24 · protect 0.33 / 0.59 | OK |
| Light | Divinity | Escort orbs that block shots and heal the ship and orb | support-heal | heal | SUPPORT | STEADY | 0.09 / 0.04 / 0.08 / 0.04 · heal 0.30 / 0.29 | OK |
| Spirit | Divine Ascension | A wisp that grows a tier with the kin's auto kills | damage | damage | RAMP (board) | NONE | -0.04 / -0.01 / 0.00 / 0.04 | weak P50/P70/P90/P100E10 — BROKEN: the wisp does nothing measurable at any band |
| Crystal | Prism Shelter | Shards round the ship that block shots and refract them back | support-protect | protect | SUPPORT | SCALER | 1.20 / 1.03 / 0.86 / 0.72 · protect 0.14 / 0.25 | OK |
| Fire | Inferno Blessing | PASSIVE: saves the orb once at 25%, then an orbiting flame for good | support-protect | protect | EARLY | EARLY | -0.00 / 0.01 / 0.00 / 0.01 · protect -0.01 / -0.01 | does nothing measurable; weak P50/P70/P90/P100E10 — dormant by design in this harness (orb never truly dies); not a verdict |
| Lightning | Tempest Blessing | While it channels, every auto chains | utility | protect | SCALER | EARLY | 0.04 / 0.04 / -0.02 / 0.01 · protect 0.04 / -0.00 | weak P70/P100E10; curve (SCALER, measured EARLY) — harness-blind: team-auto chaining; solo it can only chain its own autos |
| Steam | Scalding Veil | Damage taken becomes team attack speed (10 stacks) | utility | protect | SUPPORT (board) | EARLY | 0.20 / 0.10 / 0.05 / 0.02 · protect 0.04 / 0.02 | weak P70/P90/P100E10; curve (SUPPORT, measured EARLY) — BROKEN at high stats: stacks zeroed by every recast; also a team buff the solo harness under-reads |
| Dark | Eclipse Blessing | Companions untargetable and the orb hidden; bodies go for the ship | support-protect | protect | EARLY | EARLY | 3.67 / 2.72 / 1.90 / 1.40 · protect -0.06 / -0.05 | strong P50 (3.7x); weak P50/P70/P90/P100E10 — harness-limited: the veil is a decoy for a pilot to fly; its damage reading is the kin's own uninterrupted autos |
| Ice | Glacier Blessing | Charge, then a frost burst that slows 90%; reach grows to the whole field | control | cc | SCALER (board) | EARLY | 0.04 / -0.12 / -0.24 / 0.01 · control 4597 / -1 | collapses at P100E10; weak P100E10; curve (SCALER, measured EARLY) — BROKEN at P95+: never releases once its cast interval is shorter than its charge |
| Mud | Quagmire Blessing | The ship leaves a slowing mud trail | control | cc | SUPPORT | SCALER | 0.24 / 0.29 / 0.16 / 0.09 · control 1812 / 3722 | OK |
| Water | Divine Fountain | A rain cloud that follows the ship and heals what is under it | support-heal | heal | SUPPORT | SCALER | -0.01 / -0.00 / -0.00 / -0.01 · heal 0.38 / 0.83 | OK |

### Mystic (worlds)

| Element | Name | Does | Role | Judged on | Intended | Measured | Share P50 / P70 / P90 / P100E10 | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Plant | The Grove | The Grove: one vine lashes with knockback, one spits thorns | damage | damage | STEADY | EARLY | 7.31 / 4.63 / 3.64 / 2.62 | strong P50 (7.3x); strong P70 (4.6x); strong P90 (3.6x); curve (STEADY, measured EARLY) |
| Air | The Tornado | The Tornado: walks a circuit, lifts and grinds what it passes | damage | damage | STEADY | EARLY | 4.38 / 2.95 / 2.41 / 1.98 | strong P50 (4.4x); curve (STEADY, measured EARLY) |
| Dust | The Haze | The Haze: shooters' rounds go off in their own faces | control | protect | EARLY | SCALER | 0.09 / -0.01 / 0.05 / 0.04 · protect 0.03 / 0.05 | weak P90; curve (EARLY, measured SCALER) |
| Lava | The Fissures | The Fissures: a boss crossing a crack calls meteors down | damage | damage | SCALER | NONE | -0.03 / -0.06 / -0.03 / -0.00 | weak P50/P70/P90/P100E10 — boss-only by design; flat fissure count (M6) |
| Poison | The Miasma | The Miasma: the ship trails poison patches as it flies | damage | damage | STEADY | EARLY | 4.40 / 3.13 / 2.47 / 1.82 | strong P50 (4.4x); curve (STEADY, measured EARLY) |
| Blood | The Crimson Tithe | The Crimson Tithe: every auto (party and ship) drains into orb and caster | support-heal | heal | SCALER | STEADY | -0.06 / 0.00 / -0.04 / -0.00 · heal 0.04 / 0.05 | weak P50/P70/P90/P100E10; curve (SCALER, measured STEADY) — harness-limited: tithes party + ship autos; solo it is one creature's autos |
| Earth | The Quaking | The Quaking: arena-wide quake damages and floors everything | damage | damage | SCALER | EARLY | 6.71 / 4.25 / 3.37 / 2.53 | strong P50 (6.7x); strong P70 (4.3x); strong P90 (3.4x); curve (SCALER, measured EARLY) |
| Light | The Dawn | The Dawn: a star charges, then heals orb, ship and alchemons to full | support-heal | heal | SUPPORT | SCALER | 0.09 / -0.08 / -0.04 / -0.04 · heal 0.00 / 0.03 | weak P50/P90/P100E10 |
| Spirit | The Turning | The Turning: dead chaff rises on our side and hunts | damage | damage | RAMP | EARLY | 3.69 / 2.03 / 1.29 / 0.83 | strong P50 (3.7x); curve (RAMP, measured EARLY, no in-run ramp) |
| Crystal | The Vein | The Vein: kills may drop shards that feed the alchemy meter | utility | damage | STEADY | EARLY | 0.06 / -0.06 / -0.01 / -0.02 | weak P50/P70/P90/P100E10; curve (STEADY, measured EARLY) — harness-blind: pays out in alchemy meter |
| Fire | The Ember Season | The Ember Season: drifting embers ignite on contact | damage | damage | STEADY | EARLY | 2.08 / 1.54 / 1.24 / 0.97 | curve (STEADY, measured EARLY) |
| Lightning | The Storm | The Storm: a bolt on a fixed clock onto a random target; stuns bosses | damage | damage | STEADY | EARLY | 0.38 / 0.13 / 0.18 / 0.15 | weak P70/P90/P100E10; curve (STEADY, measured EARLY) |
| Steam | The Pressure | The Pressure: vents throw every body outward from the orb | control | protect | EARLY | STEADY | -0.09 / -0.13 / -0.04 / -0.06 · protect 0.21 / 0.31 | curve (EARLY, measured STEADY) |
| Dark | The Maw | The Maw: a hole drags bodies in and throws them out at the rim | control | protect | EARLY | SCALER | -0.09 / -0.19 / -0.10 / -0.12 · protect 0.27 / 0.40 | curve (EARLY, measured SCALER) |
| Ice | The Blizzard | The Blizzard: every body slowed, always | control | cc | SUPPORT | SCALER | -0.18 / -0.21 / -0.10 / -0.12 · control 26047 / 46621 | OK — saturated: full strength at every band from stat 3 (M6); strongest single protect in the game (~73% of incoming) and flat |
| Mud | The Weight | The Weight: ship autos bog bodies down 60% -> 90% | control | protect | SUPPORT | SCALER | 0.27 / 0.07 / 0.20 / 0.10 · protect 0.03 / 0.08 | OK — harness-limited: works through the ship's autos |
| Water | The Maelstrom | The Maelstrom: a whirlpool on the orb holds and carries bodies | control | protect | SUPPORT | SCALER | 4.70 / 4.33 / 3.70 / 3.24 · protect 0.18 / 0.58 | strong P50 (4.7x); strong P70 (4.3x); strong P90 (3.7x) |


## Phase 1 results (2026-10-09)

User answers on the review page: RAMP means growing within a run. Mask rides SPECIAL. Mystic holds steady. Wing is STEADY. Horn's lost boss damage is acceptable (tank), so its cooldown freeze stays. Heals are capped and Wing Plant gets its power-up back. The standouts are trimmed to about 3×. The wave roll on continue stays.

Re-measured with the same harness. Each value is the mean of 4 fights × 3 seeds, in a 45 s window, before → after.

| Ability | What changed | P50 | P100E10 |
| --- | --- | --- | --- |
| Kin Ice | A recast mid-charge no longer restarts the charge | control 4,142 → 4,206 body-s | control 828 → 23,939 body-s (fires again) |
| Kin Steam | A recast while the boiler is lit keeps its stacks | team buff, harness-blind; covered by `survival_ability_bug_fixes_test` | — |
| Mane Blood | Per-pierce heal and pierce leech under `HealCeiling` | orb healed 14,494 → 338 | 308,402 → 609; damage unchanged |
| Mane Lava | Blobs can't drop blobs; at most 4 blobs per shot | live pieces 220 → 15 | 220 → 43; damage 198k → 236k |
| Mane Dust | Trail budget of 48 puffs | live pieces 163 → 133 | 188 → 136 |
| Wing Plant | The flower beam effect no longer heals the orb; flowers power up the wing | orb healed 7,829 → 9 | 141,725 → 14 |
| Wing Water | Leech under `HealCeiling` | orb healed 3,337 → 2,171 | 44,286 → 29,815 |
| Wing Crystal | Leech under `HealCeiling` | orb healed 3,206 → 1,940 | 41,285 → 26,408 |

`HealCeiling` (lib/games/cosmic/cosmic_ability_runtime.dart) is per caster. It refills 1.2% of the objective's max health a second at average Beauty and about 2% at perfect, and banks 2 s of that. For scale, a Kin Light cast restores about 1.1% of the orb a second at P70.

The harness's "orb lost" is far above real play. One creature defends alone with the orb held at 60%, so compare the heals with each other, not with that column.

The pierce-effect call now passes `family`/`element`, so Mane Blood's pierce leech reaches the ceiling and Pip's two leeches get their authored targets on pierce too.

## Phase 2 results (2026-10-10)

Power, scaling and stacking: M7, M5, the reaches that never scaled, and the blow-ups at perfect. Every rule lives in a shared runtime, so survival, open space and dungeons run it the same way. Not in this phase: Mystic hooks and world intensity, M6, Mask cadence, Wing, and the balance trims (Phase 3).

### M7: one stacking rule

`CasterPieces` (lib/games/cosmic/cosmic_ability_runtime.dart) is called where each game fires a special: survival, the open-space party and garrison, and dungeons. A caster keeps the pieces of its last two casts, or three for a Kin. At each cast, every piece the caster already has counts one more recast. A piece is anything stationary, orbiting, riding someone, or a decoy, of the caster's family and element. A piece that has seen its window of recasts fades out over 0.35 s.

- A caster whose pieces die of age before its window ends never meets the rule. An average caster rarely does. The exception is Horn Steam, whose kill resets chain its casts: its P50 geysers drop from 18 to 11 live, with no change in damage.
- Kin keeps three because its pieces are authored, through trap persistence ×3, to span about three casts at an average stat. A window of two cut an average Kin's heal at P70 by about a sixth (Plant and Water −16%).
- Exempt:
  - shots still in flight, such as Mane Earth's slab and Mane Steam's vent shot;
  - fixtures a recast feeds or refreshes in place: the Mane Light ward, the Mask Plant vine, Mask Dust shields and the Kin Spirit wisp;
  - mastery pieces;
  - Kin Dust, whose pile-up to its own cap of 10 is the ability.
- Pip Poison uses a window of one, since its web lasts until the next cast.
- Mask traps are covered, so Phase 3's faster Mask holds at most two casts' worth of field.

### M5: hooks on the anchored curve

The new functions are `abilityHookValue` and `abilityHookGrowthFactor` (cosmic_data.dart) and `abilityHookScale` (horn_runtime.dart). `hornStatScale` itself is unchanged.

- At or below internal 4.25, a moved hook reads exactly its old value.
- Past 4.25, it grows from its 4.25 value: ×1 → ×1.75 at 12, with the log tail beyond. That is ×1.10 at P70, ×1.28 at P90 and ×1.66 at P100E10.
- It never reads below the old curve, so P70 gives up nothing it had.

Moved:

- **Kin:**
  - every timed support and piece duration;
  - the heal, blessing and support scales;
  - Ice reach and slow;
  - Steam's per-stack haste;
  - Dust's cloud;
  - each piece's tick power: the garden's and rain cloud's heal, the updraft's shove, the dart's poison;
  - the Earth wall: its life, and its length. It is ten stones over 120° at average, and longer at the same spacing above that, up to 240°.
- **Horn:** guard durations (Light's barrier, decoys, walls, lanes), Plant's root, and Mud's drop rate.

Left on the legacy curve:

- Horn Air: its board intent is a flat shove (EARLY).
- Damage hooks: Horn Lava's flames, Steam's kill geysers, and Wing's scars and clouds.
- Every Mystic hook.

### Reaches that never scaled

All of these are ×1 at and below 4.25:

- Horn impact zones (`hornZoneReach`, up to ×1.57 at P100E10), and the ram-burst snare and effect caps with them. The taunt cap stays at 180: a wider taunt hauled more of the wave onto the impact beside the orb, and measured as less protect for Dust, Dark, Earth, Spirit and Steam.
- Let ground zones (`letZoneReach`, by the caster's Intelligence, ×1.44).
- Pip snare and intercept fields (×1.25).
- Mane Light's rings (×1.22).

### Blow-ups at perfect

`scaledAbilityReach` holds a radius to 1.6× its decent-band (4.65) size. At perfect, the Let blast, Earth's crater and Dark's twice-as-big follow-ups were already 1.52× decent. What kept growing was the log tail (Enhancement and high-base species), and that is now capped: the blast tops out at about 257 px, where it reached 275 px at internal 14 and 335 px at 30. Mask keeps its authored per-cast counts; its live field is bounded by M7.

### Measured

The same harness, horde, siege and shooters fights (no boss), MODE=both, four seeds, all four bands. "Before" is the tree as it stood when this phase began, Phase 1 included. Each value is the ability's judged axis (damage share, heal or protect as a share of incoming, or control in body-seconds); the trend is P100E10 ÷ P50. Only abilities whose numbers moved are listed. Mask and Mystic did not move: one Mask cast is in flight at today's cadence, and a Mystic casts once.

| Ability | Judged on | P50 | P70 | P100E10 | Trend | Live pieces, P50 → P100E10 |
| --- | --- | --- | --- | --- | --- | --- |
| Horn Crystal | protect | 0.25 → 0.25 | 0.23 → 0.24 | 0.32 → 0.34 | 1.28 → 1.35 | 1.4 → 2.5 before; 1.4 → 2.4 after |
| Horn Dark | protect | 0.27 → 0.26 | 0.27 → 0.27 | 0.21 → 0.18 | 0.78 → 0.67 | 0.2 → 0.3 before; 0.2 → 0.3 after |
| Horn Dust | control | 889 → 846 | 1,224 → 1,447 | 1,044 → 639 | 1.17 → 0.76 | 0.6 → 1.6 before; 0.6 → 1.5 after |
| Horn Earth | protect | 0.43 → 0.47 | 0.49 → 0.50 | 0.52 → 0.49 | 1.19 → 1.05 | 0.7 → 2.0 before; 0.6 → 1.1 after |
| Horn Fire | protect | 0.48 → 0.49 | 0.52 → 0.52 | 0.55 → 0.53 | 1.15 → 1.08 | 5.9 → 16.0 before; 6.0 → 13.6 after |
| Horn Ice | protect | 0.36 → 0.36 | 0.36 → 0.36 | 0.33 → 0.37 | 0.90 → 1.01 | 3.2 → 8.8 before; 3.2 → 8.4 after |
| Horn Light | protect | 0.43 → 0.43 | 0.47 → 0.48 | 0.44 → 0.49 | 1.02 → 1.15 | 0.5 → 0.7 before; 0.5 → 0.7 after |
| Horn Lightning | damage | 1.77 → 1.79 | 1.42 → 1.55 | 0.85 → 1.42 | 0.48 → 0.79 | 0.2 → 0.4 before; 0.2 → 0.4 after |
| Horn Mud | control | 532 → 532 | 816 → 816 | 1,107 → 1,174 | 2.08 → 2.20 | 4.7 → 7.4 before; 4.7 → 7.8 after |
| Horn Plant | damage | 1.00 → 1.00 | 0.94 → 0.94 | 1.34 → 1.32 | 1.34 → 1.33 | — |
| Horn Spirit | protect | 0.18 → 0.18 | 0.19 → 0.19 | 0.22 → 0.22 | 1.27 → 1.23 | 0.8 → 1.8 before; 0.8 → 1.8 after |
| Horn Steam | damage | 3.08 → 3.12 | 2.32 → 2.29 | 1.91 → 1.73 | 0.62 → 0.55 | 17.8 → 50.9 before; 10.9 → 23.3 after |
| Horn Water | control | 684 → 626 | 549 → 769 | 340 → 692 | 0.50 → 1.10 | 0.7 → 1.6 before; 0.7 → 1.3 after |
| Kin Air | protect | 0.17 → 0.18 | 0.20 → 0.18 | 0.45 → 0.41 | 2.63 → 2.31 | 1.9 → 7.0 before; 1.9 → 2.5 after |
| Kin Blood | heal | 0.42 → 0.42 | 0.44 → 0.44 | 0.53 → 0.55 | 1.26 → 1.30 | — |
| Kin Crystal | protect | 0.14 → 0.14 | 0.19 → 0.19 | 0.25 → 0.19 | 1.76 → 1.36 | 1.6 → 5.7 before; 1.6 → 4.0 after |
| Kin Dust | protect | 0.41 → 0.41 | 0.47 → 0.48 | 0.53 → 0.55 | 1.29 → 1.36 | 2.3 → 6.1 before; 2.3 → 6.1 after |
| Kin Earth | protect | 0.33 → 0.31 | 0.38 → 0.44 | 0.59 → 0.56 | 1.82 → 1.84 | 13.6 → 63.8 before; 13.6 → 42.2 after |
| Kin Ice | control | 4,597 → 4,597 | 15,234 → 15,253 | 31,044 → 33,223 | 6.75 → 7.23 | — |
| Kin Lava | protect | 0.36 → 0.36 | 0.33 → 0.33 | 0.36 → 0.36 | 0.98 → 0.98 | — |
| Kin Light | heal | 0.30 → 0.30 | 0.29 → 0.29 | 0.29 → 0.35 | 0.97 → 1.19 | 0.5 → 1.2 before; 0.5 → 1.2 after |
| Kin Plant | heal | 0.33 → 0.33 | 0.37 → 0.38 | 0.77 → 0.56 | 2.32 → 1.68 | 1.6 → 6.6 before; 1.6 → 2.5 after |
| Kin Poison | damage | 0.60 → 0.60 | 0.40 → 0.39 | 0.35 → 0.39 | 0.59 → 0.64 | — |
| Kin Water | heal | 0.38 → 0.38 | 0.43 → 0.43 | 0.83 → 0.62 | 2.20 → 1.63 | 1.7 → 6.8 before; 1.7 → 2.5 after |
| Let Dust | damage | 1.58 → 1.58 | 1.46 → 1.55 | 1.97 → 1.97 | 1.24 → 1.24 | 0.8 → 2.3 before; 0.8 → 1.7 after |
| Let Earth | damage | 2.28 → 2.28 | 2.24 → 2.24 | 2.59 → 2.56 | 1.14 → 1.13 | 0.5 → 1.3 before; 0.5 → 1.3 after |
| Let Lava | damage | 2.98 → 2.98 | 2.42 → 2.53 | 2.04 → 2.34 | 0.68 → 0.79 | 0.6 → 1.7 before; 0.6 → 1.7 after |
| Let Light | heal | 0.46 → 0.46 | 0.48 → 0.48 | 0.81 → 0.81 | 1.77 → 1.77 | 0.6 → 1.7 before; 0.6 → 1.7 after |
| Let Mud | damage | 1.60 → 1.60 | 1.42 → 1.59 | 1.76 → 1.76 | 1.10 → 1.10 | 0.7 → 2.0 before; 0.7 → 1.7 after |
| Let Plant | damage | 1.06 → 1.04 | 1.04 → 1.04 | 1.77 → 1.76 | 1.68 → 1.68 | 1.2 → 4.4 before; 1.2 → 4.0 after |
| Let Poison | damage | 2.52 → 2.52 | 2.01 → 2.12 | 1.99 → 2.18 | 0.79 → 0.87 | 0.6 → 1.8 before; 0.6 → 1.7 after |
| Let Steam | damage | 3.44 → 3.36 | 2.83 → 2.78 | 2.24 → 2.10 | 0.65 → 0.63 | 1.6 → 4.4 before; 1.5 → 1.7 after |
| Mane Dust | damage | 3.16 → 3.27 | 2.82 → 2.75 | 3.36 → 3.36 | 1.07 → 1.03 | 98.9 → 95.7 before; 92.1 → 88.3 after |
| Mane Lava | damage | 3.12 → 3.11 | 3.06 → 3.01 | 3.22 → 3.16 | 1.03 → 1.02 | 4.1 → 12.6 before; 4.1 → 6.6 after |
| Mane Light | damage | 1.17 → 1.23 | 1.00 → 0.97 | 0.79 → 0.69 | 0.67 → 0.56 | 2.3 → 3.4 before; 2.3 → 3.4 after |
| Mane Lightning | damage | 2.22 → 2.22 | 1.81 → 1.86 | 2.01 → 1.33 | 0.91 → 0.60 | 7.2 → 22.3 before; 7.2 → 11.4 after |
| Mane Steam | damage | 2.93 → 2.93 | 2.81 → 2.81 | 3.19 → 3.29 | 1.09 → 1.12 | 14.8 → 50.6 before; 14.8 → 49.7 after |
| Pip Crystal | protect | 0.02 → 0.02 | 0.05 → 0.05 | 0.06 → 0.08 | 3.37 → 4.37 | 0.6 → 3.9 before; 0.6 → 3.8 after |
| Pip Dust | control | 1,890 → 1,890 | 2,886 → 2,886 | 8,435 → 7,270 | 4.46 → 3.85 | 8.7 → 57.5 before; 8.7 → 42.1 after |
| Pip Fire | damage | 1.58 → 1.58 | 1.34 → 1.34 | 1.75 → 1.49 | 1.11 → 0.94 | 3.8 → 26.7 before; 3.8 → 17.7 after |
| Pip Light | heal | 0.08 → 0.08 | 0.13 → 0.13 | 0.43 → 0.38 | 5.60 → 4.94 | — |
| Pip Poison | damage | 1.30 → 1.25 | 1.07 → 1.13 | 0.82 → 0.83 | 0.63 → 0.66 | 8.3 → 15.6 before; 8.2 → 16.1 after |
| Wing Lava | damage | 2.95 → 2.95 | 2.77 → 2.77 | 2.33 → 2.24 | 0.79 → 0.76 | 11.4 → 42.9 before; 11.4 → 41.4 after |
| Wing Mud | control | 593 → 593 | 1,117 → 1,053 | 2,190 → 1,581 | 3.69 → 2.67 | 12.6 → 48.6 before; 12.6 → 30.5 after |
| Wing Plant | damage | 1.74 → 1.74 | 1.55 → 1.55 | 1.06 → 1.03 | 0.61 → 0.59 | 8.3 → 32.1 before; 8.3 → 26.7 after |
| Wing Poison | damage | 3.16 → 3.16 | 2.94 → 3.01 | 2.25 → 2.04 | 0.71 → 0.65 | 16.4 → 64.2 before; 16.4 → 45.6 after |
| Wing Steam | damage | 2.34 → 2.34 | 2.63 → 2.63 | 2.02 → 2.03 | 0.86 → 0.87 | 11.6 → 41.4 before; 11.6 → 40.9 after |

Read the table this way:

- **Kin supports keep growing, without piling up.** Plant, Water and Earth trend ×1.6–1.8 (they were ×1.8–2.3 on piles of up to 64 pieces). Their live pieces now grow ×1.5, or ×3.1 for Earth, whose wall itself grows longer. Air sits at ×2.3. Crystal falls to ×1.4: its orbitals were the pile. Light, Blood and Lava stay flat, because their heal or splash is bounded by the damage taken, not by the piece.
- **P50 and P70 hold, with a few exceptions.**
  - Horn Water's control at P70 is +40% and Horn Dust's +18%. Both control readings are noisy at P50 and P70.
  - Kin Earth is +17% at P70, from its longer wall.
  - Let Mud is +12% at P70.
- **What M7 costs.** Zone damage loses its stacking at the top, as the README predicted:
  - Mane Lightning −34% at P100E10;
  - Horn Steam −30% at P90, −9% at P100E10;
  - Pip Fire −15%, Wing Poison −9%;
  - Wing Mud control −28%, Pip Dust control −14%.
- **Horn reach is mixed.** Water (control ×0.50 → ×1.10 trend) and Lightning (0.85 → 1.42 at P100E10) are the big winners. Dust (control −39%) and Dark (protect −14%) lose at P100E10: a wider pull or void drags more of the wave together beside the orb.
- **Piles that still grow ×3 or more**, none of them overlap:
  - Pip Fire and Dust: their pieces come from kills, and kills per cast grow;
  - Wing Lava and Steam: more pieces per cast, each shorter-lived than a recast;
  - Mane Earth and Steam: crawling shots still in flight, not placed pieces.

## Final results (2026-10-10)

The final balance pass is in `lib/`; what changed and why is in [`final_balance_applied/README.md`](final_balance_applied/README.md). Everything below was re-measured on a snapshot of HEAD plus the working tree, with the same harness and recipe as above: the main pass (all 136, 4 bands × horde/siege/shooters × 4 seeds, 45 s, full and special-held), the held-boss pass (`BOSS_HOLD=1`, 4 seeds) and the long pass (120 s, horde and boss, 2 seeds). `profiles.csv` is re-aggregated from those three; its authored columns are kept. Mask Dark is now judged on control (`axis` = cc), and Mask Light's single execute per cast is noted as a design question in its `review` cell; its behaviour is unchanged.

### By family

Median share of the median special's added damage (all 17 elements), and verdict counts.

| Family | P50 | P70 | P90 | P100E10 | OK | Flagged |
| --- | --- | --- | --- | --- | --- | --- |
| Horn | 0.84 | 0.90 | 0.96 | 0.72 | 14 | 3 |
| Wing | 1.65 | 1.87 | 1.51 | 1.26 | 14 | 3 |
| Let | 1.20 | 1.37 | 1.40 | 1.55 | 9 | 8 |
| Pip | 0.34 | 0.34 | 0.39 | 0.36 | 4 | 13 |
| Mane | 2.23 | 2.54 | 2.26 | 2.51 | 6 | 11 |
| Mask | 0.34 | 0.49 | 0.39 | 0.47 | 8 | 9 |
| Kin | 0.06 | 0.07 | 0.11 | 0.07 | 11 | 6 |
| Mystic | 0.17 | 0.16 | 0.12 | 0.10 | 7 | 10 |
| **All 136** | 1.05 | 1.09 | 1.00 | 1.15 | **73** | **63** |

- The first pass had 46 OK and 90 flagged.
- The Mystic median counts its control and support worlds. Its eight damage worlds hold 2.06 / 1.91 / 2.08 / 2.27, the "about 2–3× at every band" the user asked for.
- The damage-judged median is 1.73 / 1.86 / 1.52 / 1.52.
- **Nothing is above the 3.3 ceiling at any band** except Mystic Water, the support exception. The highest damage share otherwise is Mane Crystal's 3.24 at P100E10.

### The standouts, before → after

Share, P50 / P70 / P90 / P100E10. "Before" is the tree after the eight validated changes and before the hand fixes, measured in the same run set.

| Ability | Lever | Before | After |
| --- | --- | --- | --- |
| Mane Plant | rate (1.13 tier), root blast 165 → 70 px, vine cap 18 → 9 | 5.30 / 4.98 / 4.34 / 4.71 | 2.47 / 2.56 / 2.32 / 2.51 |
| Mane Dark | pull reach 180 → 80 | 4.38 / 4.46 / 3.82 / 4.49 | 2.65 / 2.76 / 2.55 / 3.05 |
| Mane Fire | count 4/8/16 → 4/5/6, rate (1.13 tier) | 4.34 / 4.80 / 4.80 / 6.25 | 2.61 / 2.67 / 2.52 / 3.08 |
| Wing Dark | half the seekers, 1.6 s life | 4.11 / 4.78 / 3.61 / 2.32 | 2.21 / 3.04 / 2.36 / 1.71 |
| Wing Spirit | spirits live 2.0 s | 3.55 / 3.83 / 3.51 / 2.71 | 2.37 / 2.95 / 2.55 / 1.99 |
| Mystic Poison | reach, life and wake ride tempo | 3.35 / 2.75 / 2.08 / 1.49 | 3.05 / 2.83 / 2.37 / 2.31 |
| Mystic Earth | quake beat 31 → 33 s | 2.22 / 1.90 / 2.60 / 3.41 | 2.17 / 1.87 / 2.60 / 2.84 |
| Let Steam | kill vent 12 → 9 s | 3.01 / 2.67 / 2.07 / 1.72 | 2.63 / 2.56 / 2.07 / 1.72 |
| Mask Steam | turret 0.75 → 0.5 SPECIAL | 1.58 / 2.03 / 1.64 / 1.94 (boss 7.1 / 10.5 / 12.9 / 12.8) | 1.52 / 2.09 / 1.67 / 1.95 (boss 6.0 / 8.2 / 13.0 / 10.0) |

The eight validated changes landed as measured in the validation record: Mask Spirit 3.18 / 3.00 / 2.53 / 2.44, Kin Spirit 1.90 / 1.63 / 1.51 / 1.54 (was 0), Let Fire 1.73 / 2.02 / 1.99 / 2.18, Let Dark 1.80 / 1.82 / 2.25 / 2.76, Wing Earth 2.75 / 2.89 / 2.31 / 1.97, Mane Lightning 1.33 at P100E10 (1.18 before), Horn Dust control 1,216 body-s at P100E10 (938 before), and the Mystic damage worlds above.

What moved them confirms the earlier finding: trimming damage does nothing to an ability whose hits already kill what they reach. Every fix is a reach, a count or a rate. Two measurements show it plainly:

- Making Wing Dark's seekers non-piercing took it from 4.1–4.8× to 1.0–1.9×, while a 40% damage trim on the same ability moved it by less than 0.5.
- Mane Fire's life (how far a fireball flies) did nothing, but each fireball removed at P100E10 was worth 0.1–0.4×.

### Remaining exceptions

Each flagged ability, with the reason it stands. Many intents in `profiles.csv` are still the first pass's proposed drafts (`intended_is_proposed`), so most "wrong curve" flags say more about the draft label than the ability.

**Too strong**
- Mystic Water (3.7 / 4.1 at P50 / P70): a support world whose hold kills by grinding; left as the support exception by the user.

**Too weak or nothing measurable: blind spots of a one-creature harness**
- Horn Poison: the cast adds little on top of its passive aura. This has been known since the first pass and is not a power lever.
- Wing Dust (P50 control 38 body-s): its disorient turns shooters on each other, which the body-second count does not credit.
- Pip Plant, Air, Lava, Blood, Spirit, Steam, Ice, Mud and Crystal: Pip is single-target darts (family median 0.34–0.39) and faint on hordes by design.
  - Plant's meter payout and Steam's haste are harness-blind.
  - Spirit's kill stacks peak at 4–6 in a 45 s window.
  - Mud's control is noise around zero.
- Mane Blood (judged on heal): its heal sits under `HealCeiling` by the Phase 1 ruling.
- Mask Plant (its vine feeds over many casts; the long pass reads +RAMP), Mask Air (control), Mask Dust (shields; small protect), Mask Crystal (P50 only) and Mask Ice (its amp works through allies).
- Mask Light: one execute per cast, a design question (see above).
- Kin Fire: the phoenix needs the orb to die.
- Kin Lightning: chains the party's autos.
- Kin Steam: team haste.
- Kin Dark: the decoy needs a pilot who flies it.
- Mystic Lava: only a boss crossing a fissure triggers it. Its held-boss share is 0.5 / 1.2 / 2.5 / 3.2.
- Mystic Blood: tithes the party's autos.
- Mystic Light: a heal.
- Mystic Crystal: an alchemy-meter payout.

**Wrong curve only (under the ceiling at every band)**
- Mane:
  - Air, Poison, Earth, Crystal, Fire, Lightning and Dark measure STEADY against SCALER or EARLY drafts. The family rides its cadence like the median.
  - Light and Spirit read EARLY or STEADY against RAMP; their ramps are short (finding 8).
  - Mud reads EARLY.
- Let:
  - Plant, Spirit and Lightning gain on the median (SCALER) against STEADY or EARLY drafts.
  - Air, Crystal, Earth and Fire hold STEADY against EARLY or SCALER drafts.
  - Steam: its SUPPORT intent is judged on damage, so it reads EARLY.
- Pip: Poison and Dark read EARLY; Lightning and Water read STEADY against SCALER.
- Horn:
  - Air: a flat passive shove that reads STEADY, not EARLY.
  - Blood: holds level against an EARLY draft.
- Wing:
  - Plant: its flowers' power-up needs pickups the pilot rarely collects.
  - Fire: EARLY at a trend of 0.67, because Wing reaches the ×6 cadence cap first (M4).
- Mask: Poison reads SCALER, Fire STEADY, Dark SCALER on control (against an EARLY draft), and Ice STEADY.
- Kin:
  - Dust: protect falls at the top.
  - Spirit: tiers up over a run, but reads STEADY in 45 s against RAMP.
- Mystic:
  - Earth reads STEADY against SCALER. The 45 s window holds three or four quakes at P100E10, so this world reads in steps.
  - Spirit reads STEADY against RAMP.
  - Dust, Steam and Dark are control or support worlds judged on protect against EARLY drafts.
