# Raid threat: every raid fights like its planet, and the boss hurts the squad

Status: **plan**, rewritten 2026-10-07. Written for an implementing agent.
**All phases are done** (0–7): raids fight by their planet's rule with a
squad hit, healers heal, the tiers are tuned, and dungeon guardians carry a
lighter squad hit. What is left is playing it on the device.

## The ask

The author, in two passes:

> *"I feel like some should be dying, not just attacking the boss
> constantly. So we need healers, or DoT, for bosses that heal, etc."*

> *"Each raid should have some type of mechanic to it and bosses should
> actually do dmg to my mons. Also the special mechanics in actual dungeon
> bosses should be similar too."* Then: *"make sure nothing is gimmicky or
> over designed."*

## The design, and all of it

Two things.

1. **The planet's mechanic.** A raid guardian fights by its own dungeon
   rule: Frowyrm only opens while the pillar stands, Raikuma while its
   spike is grounded, and so on. The raid **invents nothing**. Where the
   dungeon has a rule, the arena gets the prop that rule reads and the
   dungeon's own code runs on it. Where the dungeon has no rule, the raid
   has none either. Raid and dungeon boss are the same fight; the raid is
   the hard version (five Alchemons, add waves, downs that last the fight).
2. **The squad hit.** One shared, telegraphed hit that lands on every
   living Alchemon on a steady beat. It is the only new mechanic in this
   plan. It runs in raids, and later, lighter, in dungeon boss fights.
   Healers and defence answer it.

### What "not gimmicky" means here (hard rules)

- **No raid-only rules.** A raid never gets a mechanic its dungeon doesn't
  have.
- **No special cases on the squad hit.** No element immunities, no "fliers
  dodge it", no per-planet variants. It is trimmed by E-DEF like every
  other elemental hit, and shields absorb it first.
- **A port is the dungeon code running in the arena**, not a
  re-implementation. The arena gets the prop; the dungeon hook runs; the
  hook's consequences that reach *outside* the guardian room (Ice scouring a
  stair, Dust refilling a city dig, Crystal shunting the keep, Mud
  swallowing a road) are skipped in raids. If a port needs more than that,
  **stop and report the cost to the author** instead of building it.
- **Cut from the previous draft as unnecessary:** blight on dive hits, the
  growing-per-phase pulse, guardian regeneration countered by DoT, and the
  seven invented per-planet threats. Revisit any of them only if the
  measurements after Phase 6 show a gap the squad hit does not close.

### The author's standing rules

- **Strategy, not execution.** No dodge-or-die timing. A telegraph exists
  to be read, not reacted to. Attrition is answered by composition.
- **No chance.** Deterministic numbers. No random procs.
- **Frame rate.** Nothing per frame: rates are `× dt`, decay is
  `pow(k, dt × 60)`. Check every new mechanic at 60 *and* 120 fps.
- **Performance.** Low per-frame cost. No `MaskFilter.blur` in per-frame
  paint. Ask the author before adding new visual effects.
- **Look.** Lit grains on dark: material, not stroked lines. Flowy and
  eased, never bursty or flashing.
- **Sound.** Material sounds (`tool/sounds/*.py`). Never sine jingles or
  chimes.
- **Copy.** Plain words, no riddles.
- **Parity.** Survival is the source of truth for shared abilities. Keep
  survival, space and dungeon parity for anything shared.

## Phase 0: broken raids (DONE 2026-10-07)

The raid arena is generated, so it has none of a dungeon's puzzle props.
Each planet's guardian hook must either skip raids (`isRaid`) or have its
prop generated in `buildRaidArenaLayout`. Six planets already skipped. Five
hooks did neither, and two more dungeon paths leaked in.

| planet | what was wrong | fix |
|---|---|---|
| Ice | the lull never opened (no pillar to stand) | `_updateFrowyrm` skips raids |
| Mud | the lull never opened (no anchor to firm) | `_updateBogdrya` skips raids |
| Crystal | the lull never opened (the gap never reaches the heart cell) | `_updatePrismalith` skips raids |
| Dust | the lull opened once, then the cut stayed buried | `_updateAshdjinn` skips raids |
| Blood | the guardian could never drop below 80% (the shell floor) | `_riteHoldShell` skips raids |
| Poison | the ability button threw (`room.doors.first` on a door-less arena), so no lull strike ever landed | `_tryMonastery` skips raids |
| Dark | swapping the active Alchemon threw and left the run on a room that doesn't exist | `_sunFollowActive` skips raids |

Pinned by `test/raid_every_planet_test.dart`: every raid-eligible planet,
with its own element in the squad, an active swap every 3 s and the
ability button pressed every frame, must open its lull ≥ 3 times and fell
the guardian within 120 s. It fails on all seven with the old code. **Every
port in Phase 4 must keep it green.** Extend it when a planet's lull starts
needing its verb.

## What raids did to the squad (measured 2026-10-07, after Phases 0–1, before 3–6)

`test/raid_threat_harness_test.dart` (preview tag). Air arena, nobody's
health refilled. The four idle Alchemons follow the game's own AI. The
fighter backs off to 130 px outside a lull and steps in to 60 px to strike
in one (`Stance.step`). The healer squad swaps to its Kin and casts whenever
anyone standing is under 60%. Squads: Fire wing · Earth horn · Lightning
mane · Water pip · *fifth* (Lava let / Fire mask / Water kin).

| tier | stats | Let Lava | Fire Mask | Water Kin (cast to heal) |
|---|---|---|---|---|
| L1 | 3.0 | clear 87 s, 0 downs | clear 91 s, 0 | clear 92 s, 0 (healed 184) |
| L1 | 4.5 | clear 41 s, 0 | clear 43 s, 0 | clear 45 s, 0 |
| L2 | 3.0 | **wipe** 135 s | wipe 143 s | wipe 141 s (healed 449) |
| L2 | 4.5 | clear 85 s, 1 down | clear 82 s, 0 | clear 82 s, 0 (healed 986) |
| L3 | 3.0 | wipe 73 s | wipe 77 s | wipe 78 s (healed 268) |
| L3 | 4.5 | wipe 144 s | wipe 122 s | clear 182 s, 4 downs (healed 1,535) |

1. **Composition barely matters.** The three squads land within seconds of
   each other in every row. L1 threatens nobody; a mid squad wipes at L2
   and L3 whatever it brings.
2. **Healers are far too weak.** An idle Kin heals nothing: it only heals
   when it is the active Alchemon and casts. Cast on cooldown, it restores
   ~3 HP/s across the squad against ~23 HP/s coming in at mid L2.
3. **Dives concentrate.** The Horn (slot 1, nearest the guardian) takes most
   of them and is usually the first down.
4. **The rage aura is a stat-blind wall.** Every dungeon creature has a flat
   100-point pool, and the aura burns 28 of it a second outside a lull,
   ignoring stats, tier and defence. A fighter who hugs the guardian
   (`Stance.hug`) dies in ~11 s at every tier and both stat levels; the
   whole squad is gone in ~37 s. It is the dungeon's own "don't stand on it
   outside a lull" rule, avoided by a plan (back off, step in on the lull),
   so this plan leaves it alone.
5. **Nothing hits the idle Alchemons** except dives. Poison's plague and
   Light's bolts, the two dungeon guardians that do, are off in raids.

**The 2026-10-07 baseline before this one was an artifact.** It parked the
fighter at exactly 90 px: the edge of both the aura (< 90) and the lull
strike's reach (<= 90). Whether the aura landed each frame then depended on
which way the guardian drifted. That is where "Let Lava carries L1" and
"healers make it worse" came from. Never park a harness at 90 px.

**Tier targets (the author's):**

| tier | squad WITHOUT a healer | squad WITH a healer |
|---|---|---|
| L1 | loses ~1 Alchemon, still clears | loses none, clears |
| L2 | loses 2–3 (may still clear) | loses 0–1, clears |
| L3 | wipes | clears, with 1–3 losses, inside the 10-minute limit (aim ≤ 6 min) |

These are for a **mid** squad (all stats 3, level 10, five families). A
**strong** squad (stats 4.5) sits one notch easier on every row. "Healer" =
one healing-capable Alchemon (a Kin, to start) in place of the weakest
damage dealer, cast the way the harness casts it.

So: L1 needs threat added, L2 and L3 need threat moved from the dives
(which pour into one body) to the squad hit (which a healer can answer),
and healers need to heal.

## Plan

Do the phases in order. **Re-measure with the harness after each one.**
Numbers are starting points to tune, not answers.

### Phase 1: the heal bug (DONE 2026-10-07)

Each dungeon frame copies creature health into the combat body
(`_syncCombatFromCreatures`), runs `_updateCombat`, then copies it back
(`_syncCreaturesFromCombat`). Heals inside the tick write the creature
(`_healCreature`), so the copy back erased every one of them the frame it
landed: Kin blessing regen, Kin supports, drain, kill and zone heals. Only
button-press heals and Wing Water's beam survived.

Fixed by making the copy back carry only what the tick changed
(`_combatHpAtSync`), not by also writing the combat body in
`_healCreature`: that body's health is an `int`, so a 40/s regen (0.33 a
frame at 120 fps) would have rounded to nothing. Pinned by
`test/dungeon_combat_heal_test.dart` (a 40/s blessing restores 80 in 2 s —
it restored 0.5 before — and the same at 60 and 120 fps). Full suite green.

### Phase 2: why Let Lava carried L1 (DONE 2026-10-07)

It didn't. The harness stood on the 90 px edge (see above). With a
deliberate stance, all three squads clear L1 with no downs. Nothing to
change.

### Phase 3: the squad hit (raids) (DONE 2026-10-07)

Built as designed; the author approved the look.

- **Beat:** every 8 s (L1) / 7 s (L2) / 6 s (L3) after the guardian lands,
  with a 1.5 s gather first. Its own clock in seconds (`_squadHitClock`),
  not the lull. Stops for the raid death and the 10-minute loss; a gather
  the fight ends under never lands.
- **Damage:** 6% / 8% / 10% of each living Alchemon's health, trimmed by
  `defenseMitigation(comp.elemDef)`, shields first. Invincibility frames
  block it (as they block dives); the Dark Kin's veil does not.
- **Code:** `RaidConfig.squadHitInterval` / `squadHitFraction`;
  `_updateRaidSquadHit` and `_landSquadHit` beside `_updateRaidFightTimer`.
  The dive's shield → health → reactive-kit step is now one helper,
  `_landHitOnCompanion`, used by both, so Kin plates, boilers and pacts and
  a Lightning Horn's guard answer the squad hit the way they answer a dive.
- **Look:** `lib/games/planet_dungeon/raid_pulse_fx.dart`. 140 grains drift
  in on staggered spirals and pack into the guardian's body, brightening;
  on the hit the packed sphere swells straight out as a thick band of grains
  that crosses the arena and goes out (frames:
  `docs/plans/raid_squad_hit_frames.png`). One `GrainBatch`, ≤ 420 points,
  halo drawn as the same points wide and faint, no blur. Element-tinted.
- **Sound:** existing material cues, `combatDanger` (glass straining) on the
  gather and `combatHitHeavy` on the hit. A bespoke sound in
  `tool/sounds/` is optional, later.
- **Hint:** "Its pulse hits every Alchemon", once, on the first gather.
- **Tests:** `test/raid_squad_hit_test.dart` — on the tier beat in the real
  tick, the gather precedes it, every living member hit and the fallen
  skipped, heavier per tier, E-DEF trims, shields first, same beat at 60 and
  120 fps, nothing outside a raid.

**Measured after Phase 3** (same harness and squads as above):

| tier | stats | Let Lava | Fire Mask | Water Kin (cast to heal) |
|---|---|---|---|---|
| L1 | 3.0 | clear 91 s, 1 down | clear 93 s, 1 | clear 93 s, 1 (healed 719) |
| L1 | 4.5 | clear 41 s, 0 | clear 43 s, 0 | clear 45 s, 0 |
| L2 | 3.0 | wipe 62 s | wipe 69 s | wipe 232 s (healed 3,395) |
| L2 | 4.5 | clear 92 s, 2 downs | clear 98 s, 4 | clear 94 s, 1 |
| L3 | 3.0 | wipe 62 s | wipe 63 s | wipe 68 s |
| L3 | 4.5 | wipe 68 s | wipe 74 s | wipe 82 s |

Damage is spread now (mid L1 unhealed: 525/852/387/322/507 per slot, was
474/838/0/0/177), and mid L1 loses about one, as targeted. **L2 and L3 are
harder than before**, because the hit stacks on the dives. Phase 6 takes
damage back out of the dives. The healer now changes the outcome at mid L2
(232 s against ~65 s) without saving it.

### Phase 4: port each planet's mechanic into its raid (DONE 2026-10-07: 11 planets)

Each port: the arena gets the prop (`buildRaidArenaLayout`), the hook's
`isRaid` skip goes, the consequences that reach outside the guardian room are
skipped in raids, and the hint lines that mentioned the dungeon around it get
a raid variant. No fallback when the key Alchemon falls: a fallback to the
shared clock would make losing your Ice Alchemon turn Frowyrm into an easier
timed fight. Protecting it is the strategy.

| planet | rule in the raid | what was ported / fixed | needs |
|---|---|---|---|
| Fire | braziers (already worked) | — | — |
| Water | the tide (already worked) | stale "raids exempt" comments | — |
| Air | a bolt led up ranked rods stuns the Roc | storm cell (`_raidStormOrbit`); **12 rods, not 6** (6 sat 220–300 apart, past the 165 hop, so no staircase could be climbed); "way on is hidden" / "last star" lines skipped in raids. Misrouted bolts spawn wisps, as in the dungeon | Air helps; not required (the clock still runs) |
| Ice | lull only while the hoarfrost pillar stands | pillar at (430,560); stair scour skipped | an Ice Alchemon |
| Mud | lull only while the floor is hard | anchor at (430,560); road swallow skipped; the fen chart HUD hidden in raids | a Mud Alchemon |
| Dust | lull only while the cut is clear (first window free) | cut at (700,560); city undo skipped | Dust or Earth |
| Spirit | the chime parts Wraithord's shadow for a lull | chime at (410,610); the dungeon's **Blood Pip** gate copied in; 5 raid gates removed | a Blood Pip (squads allow one Pip) |
| Lava | Magmara rides the heart ring; a dropped ring head beaches it | 1 gate. **Stun-lock fixed in both modes**: a head re-caught a beached Magmara forever (head back in 2.2 s, beach 3.4 s, and it lies by the head). The head now stays down until 2.2 s after the beach ends | anyone |
| Crystal | lull only over the gap in the choir floor | 3×3 floor, heart plate under the guardian; `_slideChoirPlate` read a hard-coded room id; keep shunt skipped; **the floor's render crashed on the missing anneal ring** (guarded) | a Crystal Alchemon |
| Plant | lull only once the arena's climate is mended | two tending rings at (420,560) / (980,560) | Crystal, Spirit and Water (as its descent) |
| Lightning | ground the spike to cut Raikuma's trunk | spike at (460,625) + one trunk (`raid_core`) lighting the arena. **The spike had no art, even in the dungeon**: now the planet's circuit post with a brass spike under a glass head, humming while Raikuma feeds (`_renderGroundingSpike`; author approved). **Re-ground lock fixed in both modes**: Raikuma re-seized the trunk and the spike bit again the same frame; the trunk now surges 2.6 s first (`_kRaikumaSurge`), the shared clock's 6 s rhythm at best | a Lightning Alchemon |
| Poison | dose Blightfang with a brew from its pot, never the same twice running; three shells | pot at (380,650) (the crypt's pot, never dry); entry rite skipped in raids; **the raid pool is split across the three shells** (author approved; each shell refilled to full, so it would have been ×3 HP); add waves read the whole fight across shells | Poison, and Plant or Mud |
| Light | stand in Solarin's shadow two squares off | `raid_solarin`: the orbit room's pattern in the middle of a 21×13 floor, stone ledge + landing three squares from the orbit (only shadow is in reach). The swing arcs round the def's dais (`swingCentre`; the orbit room's is (5,4), unchanged). **Five bodies on three names**: in raids the body you play always has a name, then the squad in order (own element's name if free); the last two cast no shadow. A blow does not swing it in raids (that is its three-blow dungeon fight; a raid takes dozens) | anyone |
| Earth, Steam | twist planned, never built | — (dungeon first) | — |
| Dark | plain combat, by the author's call | — | — |
| Blood | being rebuilt | — | — |

**What the squad must bring is shown before it is picked**: one plain line on
the descent placard above ENTER RAID (`kRaidOpeningLines` in
`planet_dungeon_data.dart`, `_buildDescentPlacard` in `cosmic_screen.dart`)
for Ice, Mud, Dust, Spirit, Crystal, Plant, Poison and Lightning. The placard no longer shows
the dungeon's required-element dots under a raid (the raid squad is picked
fresh). The pick stays free; nothing refuses a squad.

Tests: `test/raid_planet_ports_test.dart` (each guardian shut when left
alone, open when the right Alchemon answers, refusing the wrong one; the Roc
staircase; the beach running out); `test/raid_every_planet_test.dart` now
answers each rule the way a player would; `test/raid_guardian_furniture_test.dart`
(props per planet, in bounds, rods within hop reach, opening lines). Every
ported arena was rendered headlessly to check the props draw. The tier table
still holds (Air: mid L2 without a healer now clears 4/9, was 6/9, from the
misrouted-bolt wisps).

### Phase 5: healer audit (DONE 2026-10-07)

`test/raid_threat_harness_test.dart`, "healer audit": every healing family ×
element in the fifth slot of a mid squad at L2, played as a healer. HP/s to
allies before → after:

- **Kins healed only themselves.** Two survival → dungeon translations were
  broken, both in `_applySpecialSupportEffects`:
  1. A *ship heal* is authored as a share of the ship's 100 points (Water 5,
     Light 8, Crystal 3, Steam 2; Horn Water 2.5, Horn Light 3.5). The
     dungeon paid it as flat HP, halved: 2.5 HP of a ~640 pool. It now pays
     each ally the same **share of its own pool**, survival's own rule for
     the orb.
  2. In survival every *blessing* also mends the orb at half the caster's
     rate (`_healOrb(blessingHeal * 0.5)`). The dungeon dropped that half.
     It now lands on **each ally** as a half-rate blessing.
  Kins to allies, 0–0.2 HP/s → 5–30 HP/s: Light 29.8, Plant 17.2, Blood 14.2,
  Crystal 13.4, Water 12.3, Spirit 11.9, Earth 10.2, Steam 9.6, Dust 9.0,
  Mud 7.9, Lava 7.8, Ice 7.4, Lightning 6.9, Air 6.5, Poison 6.2, Dark 4.8.
  Fire Kin ~1 (it has no heal of that kind).
- **Earth Let** already healed allies (~15 HP/s) and still does.
- **Blood/Light Pip, Mask Blood drain, Horn Blood kill heals** do ~nothing
  against a guardian: they ride hit effects, which a boss does not take
  (`_isBossBody`, by design and survival parity). They heal on adds. Left
  alone.
- **Wing Water, Let Blood, Mane Blood** heal themselves only. Left alone.

No per-element number was changed; only the two translations. Pinned in
`test/dungeon_combat_heal_test.dart`.

### Phase 6: tune to the targets and pin them (DONE 2026-10-07)

Tuned with `test/raid_threat_harness_test.dart`, "tier table": three squads
× three planets (Air, Earth, Fire), each without and with a Water Kin
played as a healer. The old ramp grew every knob at once per tier (HP ×5 /
×10 / ×18, damage ×1.6 / ×2.3 / ×3.2, dive share 8 / 12 / 16%, adds ×8 /
×18 / ×35 HP and ×1.5 / ×2.25 / ×3 damage). Tier HP alone makes an L3 fight
~3.5× an L1 fight, and the squad hit lands evenly, so the per-second ramp on
top wiped a mid squad at L2 and L3 whatever it brought. Two findings drove
the result:

- **Adds were the L3 killer.** With no adds, a mid squad with a Kin cleared
  L3 with one loss; with them it wiped at 74 s. Every add contact took
  12–20% of a body (as much as the guardian's dive), and ×35 HP adds
  outlived the squad.
- **A tier should be harder by lasting longer and bringing more adds, not
  by hitting harder.**

`RaidConfig` now (L1 / L2 / L3):

| knob | was | now |
|---|---|---|
| `hpMul` | 5 / 10 / 18 | **5 / 7 / 11** |
| `dmgMul` | 1.6 / 2.3 / 3.2 | **1.6 / 1.9 / 2.4** |
| `guardianHitFraction` | 0.08 / 0.12 / 0.16 | **0.06** |
| `squadHitFraction` | 0.06 / 0.08 / 0.10 | **0.06** |
| `squadHitInterval` | 8 / 7 / 6 s | **8 / 8 / 7 s** |
| `addHpMul` | 8 / 18 / 35 | **8 / 8 / 12** |
| `addDmgMul` | 1.5 / 2.25 / 3.0 | **1.0** (adds hit like dungeon wisps, ~9%) |
| add waves | 1 / 2 / 3 | unchanged |

**Result** (9 runs per row: 3 squads × 3 planets):

| tier | stats | no healer | Water Kin | target (no healer / healer) |
|---|---|---|---|---|
| L1 | 3.0 | clears 9/9, loses 1–2 | clears 9/9, loses 0 (one run 1) | ~1 / 0 ✓ |
| L1 | 4.5 | clears, 0 | clears, 0 | one notch easier ✓ |
| L2 | 3.0 | clears 6/9, loses 4–5 | clears 9/9, loses 0–1 | 2–3 / 0–1 — **no-healer row harsher** |
| L2 | 4.5 | clears, 0 | clears, 0 | one notch easier ✓ |
| L3 | 3.0 | wipes | clears 9/9, loses 1, ~207 s | wipe / 1–3 ✓ |
| L3 | 4.5 | clears, loses 1–2 | clears, 0 | one notch easier ✓ (no-healer a little easy) |

No body takes more than 46% of the squad's damage at L2+ (was 100% of the
dive damage on the front line).

**The one miss:** mid L2 without a healer loses 4–5 (and clears two runs in
three), not 2–3. The squad hit lands evenly, so without healing a squad wears
down together near the end of a ~140 s fight. Shortening L2 (×6 HP) pulled
the add waves closer and made it worse; weaker hits overall would make L1 and
the healed rows too easy. The direction is the author's: at L2 the healer is
the difference between losing four and losing one.

Pinned: `test/raid_squad_hit_test.dart` (hit sizes flat, L3 beat quicker),
`test/planet_raid_arena_test.dart` ("a raid tier is harder by lasting
longer and bringing more adds"), and the tier table itself asserts the
targets loosely (preview tag).

### Phase 7: the squad hit in dungeon boss fights (DONE 2026-10-07)

One system for both (`_updateSquadHit`, was `_updateRaidSquadHit`): the same
gather, wash, hint and sound. In a dungeon's own guardian fight it lands
every `kDungeonSquadHitInterval` (8 s) for `kDungeonSquadHitFraction` (3%,
half the raid's) × `progressDmgMul`, the campaign clock every guardian attack
already grows by: 3% fresh, ~9% at the seventeenth dungeon. Only while the
party is in the guardian's room; never in Sanguorath's fight (the shell
rites, being rebuilt). Tests: `test/dungeon_squad_hit_test.dart`; the raid's
seams were renamed (`squadHitsLanded`, `debugTickSquadHit`).

Measured with `test/dungeon_guardian_harness_test.dart` (preview): each
planet's own entry trio, mid (stats 3), in the guardian's room, nobody
refilled, downs reviving. Where the guardian fights by its planet's rule the
trio answers it (`test/guardian_rule_harness.dart`, shared with the raid
tests), so the mechanic-lull guardians are timed for the first time, not
only upper-bounded. Before → after:

| | fresh (first dungeon) | late (seventeenth) |
|---|---|---|
| clears | all 16 → all 16 | 15 of 16 → 15 of 16 (Plant does not, either way) |
| time | 13–32 s (Light 5 s, the harness's best case) → unchanged | 29–92 s → 29–83 s |
| trio's pool lost | 0–60% → 3–59% | 8–235% → 30–170% |
| the two not fighting | 0–4% each → 1–7% each | 0–12% → 7–49% |
| downs | 0–2 → 0–2 | 0–6 → 0–4 |

Fresh fights last two or three beats, so the hit is a light touch there (the
target asked for a mid trio to clear every fresh guardian: it does). Late,
it is what spreads the fight across the trio instead of one body. Light's
5 s is the harness teleporting into each new shadow; a player walks there
(the 2026-10-07 table's 40–46 s). Plant late fails in the harness before and
after: it stands all three in the ring under the dives, a harness habit as
much as a balance fact; worth a look on the device.

## Author decisions (2026-10-07)

1. **A raid needs its planet's element to open the guardian, as the
   dungeon does.** After a port, an Ice raid without an Ice Alchemon never
   lulls, and the boss takes ×0.35 damage for the whole fight. Say so on
   the raid entry in plain words (e.g. "Frowyrm only opens while the pillar
   stands. An Ice Alchemon raises it."). Part of each Phase 4 port.
2. **The Dark Kin's veil does not block the squad hit.** It keeps blocking
   dives, which pick a target; the squad hit picks none.

## Code map

All in `lib/games/planet_dungeon/planet_dungeon_game.dart` unless noted.
Search by name; line numbers drift.

| what | where |
|---|---|
| Raid tuning (`hpMul` 5/10/18, `dmgMul` 1.6/2.3/3.2, `addPhaseThresholds`, `guardianHitFraction`, `squadSize`) | `RaidConfig`, `lib/games/cosmic/raid_state.dart` |
| 10-minute limit | `kRaidFightLimit`, same file; `_updateRaidFightTimer` |
| Raid arena + generated props | `buildRaidArenaLayout`, `_raidStormRods`, `_raidBraziers`, `_raidTideZones` in `planet_dungeon_data.dart` |
| Per-planet guardian hooks | run after `_updateAltar` in `update`; each lives in `planet_dungeon_game_<element>.dart` (names in the Phase 4 table) |
| Add phases | `_updateRaidPhases` |
| Dive damage | impact block in `_updateCombatEnemies` (`if (isRaid && isGuardian)`) |
| Defence trim | `PlanetDungeonGame.defenseMitigation` |
| Rage aura (active creature only, 28 HP/s) | `_guardianHazardDps`, inside `_updateAltar` |
| Downs (permanent in raids), wipe | `_handleDowns`, `onRaidCreatureDown`, `onRaidWiped` |
| HP syncs | `_syncCombatFromCreatures`, `_syncCreaturesFromCombat` |
| Heals | `_healCreature`, `_healAllCreatures`, `_healSourceCreature`, `_applySpecialSupportEffects`, `_activateDungeonKinSupport`, `_updateDungeonKinSupports` |
| Boss rules | `_isBossBody`, `_applyBossCrowdControl` |
| Production companion for tests | `debugCreateCombatCompanion` |
| Raid tests | `test/raid_every_planet_test.dart`, `test/planet_raid_arena_test.dart`, `test/raid_*_test.dart` |

## Working in this checkout

- This builds on the **uncommitted** 2026-10-07 combat pass (boss rules,
  defence, contact clock, specials pass; see the resolution section of
  `docs/audits/combat_balance_2026-10-07.md`) and the Phase 0 fixes. Work on
  top of the current working tree.
- Other sessions have unrelated uncommitted edits (breed, feeding, shop,
  hatch, Blood rites…). Don't touch them, and **never `git stash`**. Compare
  with `git show` or a worktree instead.
- Never run `flutter install` (it wipes the phone's save data). Device
  testing goes through the author.
- Run `flutter test --exclude-tags preview` before handing back.

## Appendix A: measurement harness

`test/raid_threat_harness_test.dart`, tagged `preview` (run with
`flutter test test/raid_threat_harness_test.dart --tags preview`, ~5 s).
It prints one line per raid: result, downs with times, damage taken per
slot (`taken=`) and HP healed. Add arenas, squads and stances there for
Phase 6. Two rules learned the hard way: never park the fighter at exactly
90 px, and play the healer (swap, cast, swap back), because an idle Kin
heals nothing.
