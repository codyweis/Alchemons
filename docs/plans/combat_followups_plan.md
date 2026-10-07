# Combat follow-ups: what is left after the raid work

Status: **plan**, 2026-10-07. Written for an implementing agent. Builds on
commit `ef4db386` (pushed to master). Nothing here is built. Read the whole
brief before touching code.

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
