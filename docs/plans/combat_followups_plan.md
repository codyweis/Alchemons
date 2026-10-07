# Combat follow-ups: what is left after the raid work

Status, 2026-10-07 (evening): **Phase 1 measured and reported, nothing
tuned (waiting for the author). Phase 2 built. Phase 3 answered.** Two bugs
found on the way are fixed (Botanica's lull burned strikers; a strike by
Crystal's anneal ring reset the keep), and one is reported, not fixed
(Blightfang can be felled without a brew). Results first; the brief as
written follows from "Where things stand".

## Results (2026-10-07)

### The harness had to play like a player first

`tier table, every planet` (`test/raid_threat_harness_test.dart`, preview)
runs the same 3 squads × 12 rows as `tier table` on all 16 raid planets but
Blood. Each squad carries its planet's key Alchemon(s) (`_ruleNeeds`,
`_withKeys`: a hand the first four slots already hold is used, otherwise it
takes a damage dealer's element from the back, keeping the family; never
the healer's slot). The first run was mostly harness habits, not fights:

| habit | what it did | now |
|---|---|---|
| the key was set down at its prop | Poison's pot → pot → dose took three frames: Blightfang was open almost the whole fight | it walks, at the game's 187.5 px/s (`walkTo`) |
| the key pressed every frame while the guardian was shut | Lava's head dropped before Magmara came past (2.2 s cooldown), and the body stood on the ring as it arrived; Crystal's key stood on the heart plate, inside the aura, until the shared clock opened | it steps in only while a press can work (`guardianAnswerReady`), else the fighter fights from outside the aura; a head is dropped only as Magmara comes within 170 |
| Solarin: the nearest square to strike from, straight over lit glass | ~60 health lost walking in, more on every swing | a route that crosses the least lit glass (`solarinShadedStep`); while it swings, stable shade away from the lamp |

The fighter's own 130 ↔ 60 px stance step is still set down, as the Phase 6
table that tuned the tiers did: walking it too costs about a notch on Air
(the fighter is in the aura while it walks out), `--dart-define=WALK=true`.
Three read-only getters let a harness wait the way a player reads the hint:
`raikumaSurging`, `hoarfrostRegrowing`, `hollowSettling`.

### Phase 1: the table on every planet (after Phase 2 and the Botanica fix)

Each cell is the mean of 3 runs on the author's scale: 0 clears losing none,
1 clears losing one, 2 loses two or three, 3 loses four or more or does not
clear. `str` = stats 4.5, `K` = a Water Kin played as a healer. **Bold** is
more than one notch off. Three runs a row: one run moving is a third to a
whole notch, so read rows, not decimals.

| planet | L1 mid | L1 mid K | L1 str | L1 str K | L2 mid | L2 mid K | L2 str | L2 str K | L3 mid | L3 mid K | L3 str | L3 str K |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| table | 1 | 0 | 0 | 0 | 2 | 0-1 | 1 | 0 | 3 | 1-2 | 2 | 0-1 |
| Air | 1 | 0 | 0 | 0 | 3 | 1 | 0.3 | 0 | 3 | 1 | 1 | 0 |
| Fire | 1.3 | 0.3 | 0 | 0 | 3 | 1 | 0 | 0 | 3 | 1 | 1.3 | 0 |
| Water | 1 | 0 | 0 | 0 | 3 | 1 | 0 | 0 | 3 | 1.7 | 1.3 | 0 |
| Earth | 1.3 | 0.3 | 0 | 0 | 3 | 1 | 0 | 0 | 3 | 1 | 1.3 | 0 |
| Steam | 1.3 | 0.3 | 0 | 0 | 3 | 1 | 0 | 0 | 3 | 1 | 1.3 | 0 |
| Dark | 1.7 | 1 | 0 | 0 | 3 | 1 | 0.3 | 0 | 3 | 1.3 | 1.3 | 0 |
| Lightning | 1.7 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 3 | 2.3 | 2 | 0 |
| Mud | 2 | 0 | 0 | 0 | 3 | 1 | 0 | 0 | 3 | 2 | 2 | 0 |
| Plant | 1 | 0 | 0 | 0 | 2.7 | 0 | 0 | 0 | 3 | 2.3 | **0.7** | 0 |
| Ice | **2.7** | 0 | 0 | 0 | 3 | 0.3 | 0 | 0 | 3 | 1.7 | 2 | 0 |
| Dust | **2.3** | 0.7 | 0 | 0 | 3 | 0.7 | 0.3 | 0 | 3 | 2.7 | 3 | 0 |
| Spirit | **2.7** | 0 | 0 | 0 | 3 | 0 | 0.3 | 0 | 3 | 1.3 | 3 | 0 |
| Crystal | **3** | 0 | 0 | 0 | 3 | 0 | 0.7 | 0 | 3 | 1 | 2.3 | 0 |
| Lava | **3** | 0 | 0 | 0 | 3 | 0.7 | 0.3 | 0 | 3 | 2.3 | 2.7 | 0 |
| Poison | 0 | 0 | 0 | 0 | **0.3** | 0 | 0 | 0 | 2 | 0.7 | **0** | 0 |
| Light | **3** | **1.3** | **3** | 0 | 3 | 1.7 | **3** | 0 | 3 | 3 | 3 | 0 |

Within a notch everywhere: Air, Fire, Water, Earth, Steam, Dark, Lightning,
Mud. The accepted miss (mid L2 without a healer loses 4–5) holds on every
planet. Off the table, and why (traced, not guessed):

- **Light (worst).** Without a healer every squad wipes in 90–106 s, at
  every tier and both stat levels; with one, it clears. Solarin's bolts
  (14 every 2.6 s, a fan of three once hurt) take whoever is out on the
  glass in turn, and that empties five pools in about 100 s, while the
  fighter only strikes from shadow (about 5 lulls in that time). Phase 2
  trims a bolt ~20% at level 10, not enough to move a row. Light is a
  healer-or-nothing raid. Levers within its rule: `kSolarinHold` /
  `kSolarinSwing` (more time to strike), or the bolt cadence
  `kSolarinBoltEvery`.
- **Poison (too easy), and a bug.** Fights last 17–106 s against 43–220 s
  on the shared-clock planets. Blightfang's shells only come off when its bar
  empties *inside* a brew window (`_applyBlightfangStrain`); outside one it
  still takes chip damage, and when the bar empties then it simply dies,
  shells and all, and the star is banked. Measured: a mid squad that never
  doses it clears L1 in 83 s (strong: 36 s), 0 lulls. The dungeon's own
  Blightfang (three full bars) has the same hole: its fresh fight is the
  shortest of all 16 (13 s). **Not fixed: the author's call** — keep the bar
  from emptying outside a window (floor it at 1, as Blood's shell floor
  did), or let nothing reach it through a shell ("Nothing reaches it
  through one", its own comment). Retune Poison only after.
- **Lava (mid L1 unhealed wipes; healed rows on the table).** Magmara rides
  the ring toward its *dive target*, not the played body. When it fixes on
  an idle Alchemon (they station at its edge), it sits on the far arc and
  no head is in reach: 40 s in one trace while the squad wears down. The
  dungeon fight shows the same (30 s with no head in reach). A design
  question, not a pacing constant: `_kHeadCooldown` / `_kBeachSeconds` do
  not reach it.
- **Ice, Dust, Spirit, Crystal: mid L1 without a healer loses 2–5 (target
  ~1).** Every other row is within a notch. These are the planets whose key
  leaves the fight to answer (11–18% of it), and on Crystal it presses from
  the heart plate, inside the aura. Mid L1 unhealed is the loosest row, so
  this may be acceptable; if not, the plan's levers are their pacing
  constants (`_kHoarfrostRegrow` for Ice).
- **Plant: strong L3 unhealed is a little easy** (0.7 against 2), and mid L3
  with a healer is slow (485 s mean, one clear in three), near the
  10-minute limit.

Per the brief, nothing was tuned.

### Phase 2: a guardian's own attacks are trimmed by E-DEF (built)

`_guardianAttackMitigation(c)` (beside `defenseMitigation`) is applied to
the rage aura, Simurgh's pillars, Solarin's light and Solarin's bolts. A
level-1 body takes the authored figure, more E-DEF less, never under 60%.
Left as authored, with a comment saying so: `_hazardDps`, Steam's geyser
throws and scalds, Poison's ward strains. Tests: `dungeon_hit_defense_test`
(each of the four at E-DEF 35 / 150 / 999, and the same a second at 60 and
120 fps); Solarin's bolt test now expects the trimmed hit. Effect: the
three tuned planets barely move (mid L2 unhealed clears 2/9, was 1/9);
Light's unhealed wipe moves from ~90 s to ~100 s.

### Found on the way, fixed

- **Botanica's lull burned whoever struck it.** The rage aura reads the
  shared 6 s clock inside `_updateAltar`; Botanica opens on its own clock,
  which runs later, so for half of every 6 s window the aura burned the
  striker (28 a second). Spirit already had the exemption
  (`_funeralHoldsGuardian`); Botanica gets the same (`_botanicaLullOpen`).
  Raids and dungeon. Test: `raid_planet_ports_test`, "nobody burns striking
  it in its window".
- **A strike by Crystal's anneal ring reset the keep mid-fight.** In the
  choir, the ring sits in the corner the fight drifts into; a lull strike
  pressed within 64 px of it rang the anneal instead, reset the keep and
  sent the party out of the fight. The lull now outranks the ring, as it
  already outranked the plate shove. Test: `planet_dungeon_crystal_keep_test`,
  "the lull outranks the ring too".

Not fixed, for the record: for Ice, Mud, Dust and Crystal the aura is also
off during the shared clock's lull while their prop holds the guardian shut
(the lenient side of the same mismatch). Fixing it would make those fights
harder, so it is the author's call.

### Phase 3

1. **Plant's late guardian: it was the fight, not the harness.** The aura
   bug above. Dungeon harness, Plant late (mid): NOT 300 s, 4 downs, 168% of
   the pool → CLEAR 42 s, 0 downs, 58%. Stepping the hands in only to make
   the fix is worse (77 s, 2 downs): the walk costs the window. Every
   dungeon guardian now clears fresh and late (16 of 16 each; late was 15).
   Botanica's rules are unchanged.
2. **Mid L2 without a healer:** Phase 2 barely moved it (1/9 → 2/9 clears,
   still losing 4–5). Not revisited.

Dungeon guardian harness, before → after (only rows that moved):

| | before | after |
|---|---|---|
| fresh Plant | 26 s, 2 downs, 66% | 21 s, 0 downs, 17% |
| fresh Lava | 25 s, 1 down, 27% | 65 s, 1 down, 75% |
| late Dust | 63 s, 4 downs, 150% | 62 s, 3 downs, 119% |
| late Crystal | 68 s, 3 downs, 140% | 70 s, 4 downs, 137% |
| late Plant | NOT, 300 s | 42 s, 0 downs, 58% |
| late Lava | 83 s, 5 downs, 149% | 108 s, 6 downs, 205% |

Lava is slower for the reason above (Magmara away from both heads); a
lighter aura only moved where its targets stood. One run per row, so treat
single-row moves of this size as noise unless a trace says otherwise.

### For the author

1. Poison: which fix for the shells (see above)?
2. Light: is healer-or-nothing intended? If not, which lever: more time to
   strike (`kSolarinHold`/`kSolarinSwing`) or fewer bolts
   (`kSolarinBoltEvery`)?
3. Lava: should Magmara ride toward the played body rather than its dive
   target?
4. Ice/Dust/Spirit/Crystal mid L1 unhealed: acceptable, or tune?
5. The aura's lenient side on Ice/Mud/Dust/Crystal: leave or close?


## Where things stand

On 2026-10-07 raids and dungeon boss fights were reworked
(`docs/plans/raid_threat_plan.md` is the full history):

- Every raid guardian fights by its planet's dungeon rule in a generated
  arena (`buildRaidArenaLayout`, `lib/games/planet_dungeon/planet_dungeon_data.dart`).
  The placard above ENTER RAID says what a squad must bring
  (`kRaidOpeningLines`).
- One squad hit lands on every Alchemon: raids 6%, dungeon guardians 3% ×
  the campaign clock (`_updateSquadHit`).
- Healing works (the HP-sync bug, the Kin ship/blessing translations).
- Raid tiers were tuned against the author's tier table, **but only on the
  Air, Earth and Fire arenas**.
- Party members you are not driving move like Alchemons now
  (`companionStation`, `lib/games/shared/companion_stance.dart`).

Tools that already exist:

| tool | what it does |
|---|---|
| `test/raid_threat_harness_test.dart` (tag `preview`) | `tier table`: 3 squads × 3 planets × with/without a Kin healer, L1–L3, stats 3 and 4.5; asserts the author's table loosely. `healer audit`, `raid threat`, `breakdown`. |
| `test/dungeon_guardian_harness_test.dart` (tag `preview`) | every dungeon guardian with its own entry trio, fresh and late campaign, nobody refilled |
| `test/guardian_rule_harness.dart` | answers each planet's rule the way a player would: `guardianAnswerAt`, `blightfangStep` (Poison), `solarinShadow` (Light) |
| `test/raid_every_planet_test.dart`, `test/raid_planet_ports_test.dart` | every raid can be won; each ported rule gates its guardian |

Run a preview test with
`flutter test <file> --tags preview --plain-name "<test name>"`. Each takes
seconds.

## The author's tier table (the target)

For a **mid** squad (all stats 3, level 10, five families); a **strong**
squad (stats 4.5) sits one notch easier on every row. "Healer" = one Kin in
place of the weakest damage dealer, swapped to and cast when anyone is
under 60% (the harness's `healer:` policy).

| tier | squad WITHOUT a healer | squad WITH a healer |
|---|---|---|
| L1 | loses ~1 Alchemon, still clears | loses none, clears |
| L2 | loses 2–3 (may still clear) | loses 0–1, clears |
| L3 | wipes | clears, with 1–3 losses, inside the 10-minute limit (aim ≤ 6 min) |

Known and accepted: mid L2 without a healer loses 4–5 on Air/Earth/Fire
(the squad hit lands evenly, so an unhealed squad wears down together).

## Phase 1: raid balance on every planet (measure, then report)

The tier table has only been measured on Air, Earth and Fire. The other
raids now open on their own rule, at their own rate, and need their own
Alchemon alive to open at all, so some may sit far off the table.

1. Add a preview test, `tier table, every planet`, beside `tier table`: the
   same squads and rows for every raid-eligible planet except Blood (its
   raid runs the shared clock while Blood is being rebuilt).
2. Each squad carries the planet's key Alchemon(s), in place of a damage
   dealer, never the healer:

   | planet | key | how the harness answers it |
   |---|---|---|
   | Ice | an Ice Alchemon | `guardianAnswerAt` (the pillar) |
   | Mud | a Mud Alchemon | `guardianAnswerAt` (the anchor) |
   | Dust | a Dust or Earth Alchemon | `guardianAnswerAt` (the cut) |
   | Spirit | a **Blood Pip** | `guardianAnswerAt` (the chime) |
   | Crystal | a Crystal Alchemon | `guardianAnswerAt` (the plate beside the gap) |
   | Plant | Crystal, Spirit and Water, together in one ring | `guardianAnswerAt` + the other two stood in the ring |
   | Poison | Poison, and Plant or Mud | `blightfangStep` |
   | Lightning | a Lightning Alchemon | `guardianAnswerAt` (the spike) |
   | Lava | anyone | `guardianAnswerAt` (the ring head) |
   | Light | anyone | `solarinShadow`; stand there to strike too |
   | Air | none required (an Air Alchemon can rank the rods; the harness does not) | — |
   | Fire, Water, Earth, Steam, Dark | none | — |

   `test/raid_every_planet_test.dart` shows how the key Alchemon answers
   while the fighter stance runs otherwise.
3. Print the 12 rows per planet and flag every planet more than one notch
   off the table.
4. **Report to the author before tuning anything.** Levers, if a planet is
   off: only its own rule's pacing constants, e.g. `_kRaikumaSurge`
   (Lightning), `_kHeadCooldown` / `_kBeachSeconds` (Lava),
   `_kHoarfrostRegrow` (Ice), `_kBlightLull` (Poison), `kSolarinHold` /
   `kSolarinSwing` (Light). Never a new rule. `RaidConfig` is per tier and
   shared by every planet: do not bend it for one.

Likeliest outliers: **Light** (its burn takes 42% of the played body's
health a second on lit glass, and its bolts hit anyone; both ignore stats,
see Phase 2), **Poison** (every 3.4 s window costs a trip to the pot;
the pool is split across three shells), **Lightning** (3.4 s windows with
a 2.6 s surge between), **Plant** (all three hands stand in one ring
under the dives to fix the climate).

## Phase 2: a guardian's own attacks are trimmed by defence

Four guardian attacks take a flat share of a body's health whatever its
stats, tier or defence (a dungeon body's health is a flat 100-point pool).
The 2026-10-07 defence pass trimmed dives (P-DEF) and plague strikes (E-DEF)
only, with `PlanetDungeonGame.defenseMitigation`, which only ever reduces
(a level-1 body takes the authored figure; floor 60%).

| attack | where (search by name) | now |
|---|---|---|
| a guardian's rage aura (the played body, within 90, outside a lull) | `_guardianHazardDps`, in `_updateAltar` (`planet_dungeon_game.dart`) | 28 a second × `progressDmgMul` |
| Simurgh's pillars | `_kTelegraphDps` (`planet_dungeon_game_fire.dart`) | 5.5 a second × `progressDmgMul` |
| Solarin's light | `kSolarinBurnDps` (`planet_dungeon_layout_light.dart`), applied in `_applySolarinOrbit` | 42 a second × `progressDmgMul` |
| Solarin's bolts | `kSolarinBoltDamage`, applied in `_solarinBolts` | 14 a bolt × `progressDmgMul` |

Do: multiply each by `defenseMitigation(comp.elemDef)` of the body it hits,
where `comp` is `combatCompanions[i]` for creature `i`. Say why in a comment.

**Leave alone**, and say so in a comment where it helps: these are a room's
rules, not a guardian's attacks: `_hazardDps` (`_checkHazards`), Steam's
geyser throws and molten scalds (`planet_dungeon_game_steam.dart`), and
Poison's ward strains (`_tickStrains`).

Tests: extend `test/dungeon_hit_defense_test.dart`: for each of the four,
more E-DEF loses less; a level-1 body (E-DEF ≈ 35) loses the authored
figure; nothing loses less than 60% of it. Then re-run both harnesses and
Phase 1's table. Light's fight gets gentler: check its rows.

## Phase 3: two known misses (investigate, report)

1. **Plant's late guardian never clears** in the dungeon harness, before
   and after the 2026-10-07 work. Find out whether that is the harness (it
   parks all three in one ring under the dives for as long as the guardian
   is shut) or the fight. Try: the three hands step into the ring only to
   make the fix, then out. If a mid trio still cannot win at the 17th
   dungeon, report it with numbers. Do not change Botanica's rules.
2. **Mid L2 without a healer** loses 4–5 (target 2–3). Already analysed in
   `raid_threat_plan.md`, Phase 6. Revisit only if Phase 1 or 2 moves it.

## Not in this plan

- Survival's rim-vanish bug (enemies vanish at the arena edge as new ones
  spawn; game logic was ruled out on 2026-09-29). Its own task.
- Earth's and Steam's guardians have no planet twist yet, in the dungeon or
  the raid (`docs/dungeons.md` §7: "Terradon's tremors knock the scale
  loose", "Boilrog vents the main"). Design work for the author first.

## Rules from the author (hard constraints)

- **Strategy, not execution.** No dodge-or-die timing; attrition is
  answered by composition.
- **No chance.** Deterministic numbers. No random procs.
- **Not gimmicky.** Reuse what exists; no raid-only rules, no special
  cases.
- **Frame rate.** Nothing per frame: rates are `× dt`, decay is
  `pow(k, dt × 60)` or `1 − exp(−k·dt)`. Check at 60 and 120 fps.
- **Performance.** Keep per-frame cost low; no `MaskFilter.blur` in
  per-frame paint. Ask before adding visual effects.
- **Copy.** Plain words, no riddles; hints say what is wrong, never a
  recipe.

## Working in this checkout

- Other sessions edit and **commit to master in this same checkout** while
  you work, and the git index is shared. Stage only your own files, by
  explicit path, and commit right away. Never `git add -A` or `git add .`,
  never `git stash`.
- Never run `flutter install` (it wipes the phone's save). Device testing
  goes through the author.
- Before handing back: `flutter analyze` (no new errors) and
  `flutter test --exclude-tags preview`. `test/cosmic_companion_motion_test.dart`
  sometimes fails under the full suite's load; re-run it alone.
- Record results in this file and in `docs/dungeons.md`.

## For the author: what to check on the phone

Nothing from 2026-10-07 has been played on a device yet:

- raids on every planet, with the placard line above ENTER RAID;
- the squad hit: is its 1.5 s gather readable, and does the grain wash hold
  frame rate in a busy raid?
- Kins healing the whole squad;
- the companions' new movement (horn at the boss's edge, wing loops);
- Lightning's new grounding spike, and the arena dimming on each window;
- the Magmara and Raikuma pacing fixes, and Sanguorath's shell pushing
  allies clear when it forms;
- Plant's guardian late in the campaign (Phase 3).
