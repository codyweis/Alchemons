# Survival families audit (2026-10-20)

Why some families carry survival and others are dead weight, measured and then traced to the code. Written before any balance change, so it can be compared against afterwards.

## How it was measured

`test/family_balance_survival_test.dart` (tag `preview`) builds parties of five families (no Mystics; every set of five of the seven in turn, elements drawn at random), jumps them to one wave with the stat-wall benchmark's twenty picks and its pilot, and records each Alchemon's share of its party's damage and kills, and how often a party with a family held the wave against one without it. 105 parties per band, 60 frames a second, lifesteal on a different slot each party. `FAMILY_MASTERY=1` equips one strong path per family, every node bought.

Two cautions when reading it:

- **Damage share books only the health a hit removes.** Overkill is not counted. A family that touches full-health bodies first (Wing on the rim, Mane's long lines) is credited with all of their health; a family that finishes hurt bodies (Pip hunts them) is credited with what was left.
- **Hold rates are noisy.** Each family is missing from about 30 of 105 parties, so "without" carries about ±9 points.

An earlier run gave the benchmark's lifesteal to slot 0, which was the Horn in most parties. Each Horn kill then healed the orb by about 10%, which made Horn look essential (82% held with, 50% without). With the lifesteal rotated, that disappears.

## Results without masteries

Share of the party's damage (a fifth is even):

| Family | P20 w41 | P50 w56 | P80 w101 | P100 E10 w141 |
|---|---|---|---|---|
| Mane | 41% | 39% | 46% | 45% |
| Mask | 34% | 34% | 28% | 25% |
| Wing | 28% | 25% | 33% | 32% |
| Horn | 16% | 15% | 15% | 15% |
| Kin | 10% | 8% | 8% | 6% |
| Let | 7% | 10% | 6% | 11% |
| Pip | 4% | 9% | 3% | 5% |

Held with the family minus held without it, in points:

| Family | P20 | P50 | P80 | P100 E10 |
|---|---|---|---|---|
| Kin | +9 | +12 | +15 | +34 |
| Mane | +23 | −11 | +10 | −8 |
| Horn | 0 | +7 | +1 | −4 |
| Wing | −5 | +3 | +1 | +6 |
| Mask | +9 | −7 | −9 | −4 |
| Let | −19 | −7 | +5 | 0 |
| Pip | −19 | +3 | −23 | −22 |

Elements that trail across families: Mud (Horn 1–7%, Mane 19–24%, Pip 1–4%), Light (Horn 1–3%, Mane 21–27%, Mask 12–27%), Air and Spirit Horn.

## Results with masteries (P80)

With Horn Juggernaut, Mane Resonance, Let Ground Zero, Pip Control, Mask Contagion, Wing Tracer and Kin Longline:

| Family | Damage share w101 | w121 |
|---|---|---|
| Mask | 72% | 73% |
| Wing | 22% | 20% |
| Mane | 20% | 20% |
| Kin | 15% | 15% |
| Horn | 7% | 7% |
| Let | 3% | 3% |
| Pip | 2% | 2% |

Contagion makes any Mask, of any element (63–84%), the party's whole damage. Parties with it held wave 101 87% of the time against 57% without.

## Why, family by family

**Mane (carries).** One piercing catapult shot per cast, and the scaler forces every shot to pierce with no limit, multiplies its life by 3.1 (11–19 s, crossing a whole front) and inflates its hitbox 1.15–2.34×. Every contact one-shots chaff, and the frame gives it the fastest special (0.70). Riders that work on corpses (Crystal splash, Dark pull, Plant's root explosion) widen each line into a 120–200 px corridor.

**Wing (strong).** Patrols the rim and touches every body first. Most of its special is not the beam: a piercing primary that re-hits at 60 Hz, piercing secondaries, trails of zones, Fire and Poison damage discs around the Wing. 13 of the 17 beams end at the nearest body, so a beam cannot sweep a line. Hits the special-cadence cap first.

**Mask (middle).** Its share is mostly the basic dart, a 936 px piercing line that one-shots chaff from P50. Its traps land in front of the Mask in the middle ring, on bodies Wing and Mane also shoot, and never near the orb.

**Horn (holds by lures).** Its damage share understates it. The ram clears the bodies nearest the orb, and its fixtures (Fire, Steam, Earth, Dust, Dark, Spirit, Ice, Light) lure every conduct, including chargers and artillery, to stand still and silent until they die.

**Kin (support).** Five to nine percent of the damage, but the steadiest hold value. Every cast echoes heals into the orb, uncapped; Steam and Lightning lift the whole party's basics (booked to the others).

**Let (weak).** Not short of damage but of bodies per second. One meteor per cast at the slowest cadence of any family, lands 9–22× a wisp's health, aims at one fresh leaker near the orb from the inner ring (no density seeking), and nine of seventeen elements' effects act on bodies the crater has already killed. An empty crater wastes the cast.

**Pip (weakest).** Four to eighteen bodies per cast at P80 (Lightning 49). Dart counts and bounces barely grow with breeding, pierce never adds a body, first hits are 3–10× a wisp's health, riders only work on survivors, and basics are single-target darts that hunt hurt bodies. Every dart is spent on its first boss touch.

**Mystic.** Every real Mystic waits a flat 60 s for its world (its SPECIAL is past the formula's cap at P20). Lava, Crystal and Dust worlds do nothing against an ordinary horde wave.

## Bugs found

Crashes and exploits:

- **Fixed:** Mask Contagion and the Infernal orb's burn aura damaged while walking the enemy list; a splitter they kill adds shards mid-walk and the run threw "concurrent modification during iteration". Now walked by index (test in `survival_mastery_mask_combat_test.dart`).
- Mane Light with the Endless Circuit node throws on an empty ward list when the ring's append was dropped at the projectile cap.
- Mane Crystal deals a boss its whole health plus one: the first Crystal cast in range ends any boss fight, even while it is still arriving.
- Wing Light: the parent beam splits on every kill (only the children are marked as split), up to the 14-beam cap, evicting other Wings' beams and healing without a ceiling.
- Horn Bodyguard: damage diverted to the Horn vanishes inside its 0.45 s invulnerability, so each Bastion is a near-free 25% off the orb's damage.

Bosses dodge whole kits: the Horn ram, Horn and Mane zones, Mane Lightning, Kin's laser and the shared nearby-area helper (Horn Anvil, Last Stand, the Juggernaut pulse, Mask Plague, Kin Fire and Lava) never touch a boss. Pip darts are spent on the first boss touch.

Design paths that never deliver: Wing Ice's freeze (the thaw runs every frame), Wing Water never heals the ally it aims at, Wing Plant's riders, the Mane Light ward (decays for good after its first rings expire), Mane riders on corpses, Let's nested effects, Let Dark's follow-ups (all land west of the kill), Mask's scatter (overwritten by placement), Mask Ice's amp (fixed 2.4, the board says 2–5× scaled), Mask Dark's pull (weaker than walking), Kin Light orbs (die on the first body), Mystic cadence (always 60 s). Mastery nodes that do nothing: Kin Grounding, Mystic Sanctum, Pip Pin Cushion's per-Pin bonus.

Shared limits that bite the weaker families most: the 220-slot companion projectile list drops appends silently when full (a Let cast is lost after its cooldown is spent); stationary pieces retire after two recasts, cutting Let and Mask zones short.

The per-family reports with file and line references were written to the session scratchpad on 2026-10-20 and are summarized here.

## Mastery sweep (2026-10-21)

Every survival Family Mastery path (23) measured on its own and its nodes read against their text. User brief: some families may simply be better in survival; what must not happen is one path carrying a party the way Contagion once did, a path that does nothing measurable, or a node that does not do what it says.

### How it was measured

`test/family_balance_survival_test.dart` with `FAMILY_MASTERY=<path> FAMILY_MASTERY_ONLY=1`: that family's path is bought whole and no other family has any mastery, so the same 105 parties run with and without it. Bands near today's walls: P50 wave 36 and P80 wave 41, and P100 E10 wave 91 for the outliers; Mystic paths with `FAMILY_MYSTIC=1 FAMILY_MYSTIC_LIT=1`. `FAMILY_MASTERY_TIER=n` buys only the first n nodes, which is how each outlier was traced to one node. The single-target paths were also run on a boss wave (P50 wave 35), their intended scenario. Each family line now also prints the part of its damage mastery dealt, and its basic-attack part.

Cautions:

- **Share is health removed, and a horde is mostly chaff.** A path that adds a percentage to hits that already kill (Twin Fang, Needlepoint, Burn Through, Longshot, Falling Star) moves the share by a point at most; a path that reaches more bodies (Contagion's spread, the Endless Circuit, Longline's length, Deathmask's graves, Bombardment's craters, Tracer's cadence) moves it by ten or more. That, more than the numbers, is why the outliers were outliers.
- **Hold rates carry about ±6 points**, and runs are not exactly reproducible: some shared specials draw from an unseeded `Random()` (Mask's trap scatter and a Dust sandblast in `cosmic_data.dart`), so a party without the family can come out differently from one run to the next.
- Other sessions changed Dark Kin's heal and the Light Mask void during the sweep; each "after" is read against a no-mastery run made at the same time.

### Before and after

Each cell is no mastery → the path before the sweep → **the path after**, for the family's share of party damage and the hold rate of parties with that family (the no-mastery figure from the before runs; the after runs' own came within two points). P100 E10 was run for the outliers only. Mystic rows are from parties with a Mystic, its world lit as the wave opens.

| Path | P50 w36 share | P50 w36 held | P80 w41 share | P80 w41 held | P100 E10 w91 share |
|---|---|---|---|---|---|
| Horn Bulwark | 12% → 19% → **19%** | 47% → 53% → **53%** | 10% → 14% → **14%** | 88% → 93% → **91%** |  |
| Horn Bastion | 12% → 15% → **15%** | 47% → 53% → **53%** | 10% → 11% → **11%** | 88% → 95% → **95%** |  |
| Horn Juggernaut | 12% → 16% → **15%** | 47% → 49% → **49%** | 10% → 12% → **12%** | 88% → 91% → **91%** |  |
| Mane Twin Fang | 35% → 35% → **36%** | 47% → 52% → **55%** | 31% → 31% → **32%** | 89% → 89% → **92%** |  |
| Mane War Rhythm | 35% → 39% → **39%** | 47% → 59% → **60%** | 31% → 32% → **32%** | 89% → 92% → **91%** |  |
| Mane Limitless | 35% → 51% → **42%** | 47% → 75% → **60%** | 31% → 44% → **37%** | 89% → 96% → **91%** | 26% → 36% → **34%** |
| Let Falling Star | 23% → 26% → **26%** | 43% → 51% → **51%** | 19% → 20% → **20%** | 85% → 87% → **88%** |  |
| Let Bombardment | 23% → 31% → **31%** | 43% → 55% → **53%** | 19% → 26% → **26%** | 85% → 93% → **92%** |  |
| Let Ground Zero | 23% → 24% → **25%** | 43% → 49% → **52%** | 19% → 20% → **20%** | 85% → 89% → **88%** |  |
| Pip Needlepoint | 12% → 13% → **13%** | 41% → 45% → **47%** | 30% → 29% → **30%** | 91% → 91% → **89%** |  |
| Pip Scattershot | 12% → 15% → **15%** | 41% → 49% → **44%** | 30% → 31% → **31%** | 91% → 92% → **92%** |  |
| Pip Salvo | 12% → 19% → **18%** | 41% → 56% → **55%** | 30% → 40% → **38%** | 91% → 96% → **96%** | 31% → 41% → **40%** |
| Mask Deathmask | 23% → 33% → **33%** | 45% → 72% → **72%** | 18% → 27% → **27%** | 88% → 97% → **97%** | 17% → 26% → **26%** |
| Mask Rearm | 23% → 26% → **26%** | 45% → 60% → **60%** | 18% → 22% → **22%** | 88% → 91% → **89%** |  |
| Mask Contagion | 23% → 40% → **35%** | 45% → 69% → **69%** | 18% → 34% → **30%** | 88% → 93% → **89%** | 17% → 32% → **29%** |
| Wing Burn Through | 28% → 27% → **28%** | 47% → 52% → **52%** | 27% → 28% → **29%** | 87% → 89% → **92%** |  |
| Wing Longshot | 28% → 28% → **29%** | 47% → 56% → **59%** | 27% → 29% → **30%** | 87% → 92% → **93%** |  |
| Wing Tracer | 28% → 38% → **38%** | 47% → 71% → **69%** | 27% → 36% → **36%** | 87% → 96% → **95%** | 29% → 35% → **35%** |
| Kin Longline | 7% → 32% → **19%** | 51% → 73% → **63%** | 5% → 21% → **13%** | 92% → 97% → **96%** |  |
| Kin Conduction | 7% → 6% → **6%** | 51% → 56% → **64%** | 5% → 4% → **4%** | 92% → 95% → **99%** |  |
| Kin Benediction | 7% → 6% → **6%** | 51% → 91% → **76%** | 5% → 4% → **4%** | 92% → 100% → **100%** |  |
| Mystic Quickening | 19% → 35% → **35%** | 50% → 75% → **75%** | 22% → 35% → **35%** | 88% → 97% → **97%** |  |
| Mystic Firmament | 19% → 22% → **23%** | 50% → 56% → **60%** | 22% → 23% → **23%** | 88% → 94% → **96%** |  |

The single-target paths on a boss wave (P50 wave 35, where every party held), share of party damage, no mastery → before → after, and the part of the family's damage the path dealt:

| Path | Share | Mastery part, before → after |
|---|---|---|
| Mane Twin Fang | 29% → 32% → **35%** | 13% → 25% |
| Pip Needlepoint | 12% → 14% → **15%** | 17% → 23% |
| Let Falling Star | 29% → 36% → **36%** | 27% → 27% |
| Wing Burn Through | 25% → 27% → **28%** | 6% → 12% |
| Wing Longshot | 25% → 30% → **35%** | 5% → 26% |
| Horn Bulwark | 16% → 17% → **20%** | — → 19% |

### What was found

Outliers:

- **Mane Limitless** (51% at P50, 44% at P80). Far Throw, Overdraw and No Horizon together moved a Mane by a point; the Endless Circuit was all the rest. A horde crosses the rim on its way in, and the blade met most of a wave twice a lap at the full strength of a special.
- **Kin Longline** (7% → 32%, 5% → 21%). Full Span alone took a Kin from 8% to 22%: every short laser run out to 1,012 or more into the thick of the horde. Crossfire's full-strength back line was most of the rest. Kin is the support family.
- **Kin Benediction** held 91% of P50 waves against 51% (100% against 92% at P80). Communion copied a Kin's blessing whole to every ally — a fortieth of the Kin's large health a second, near-constant under Devotion — and every copy echoed half of itself into the orb again.
- **Mask Contagion** (40% at P50 alone; the 2026-10-20 cap was read with every family's path bought). Virulence and Plague each added about eight points; cutting their damage by a third moved neither, and fewer spreads a carrier did nothing either, because what they touch is chaff that dies to any of it and Plague's burst re-infects everything it reaches.
- **Pip Salvo** (40% at P80, 41% at P100 E10): four extra darts at full strength on a special of about three.

Paths that added nothing: Twin Fang (+0, +1), Needlepoint (+1, −1), Burn Through (−1, +1), Longshot (0, +2), Ground Zero (+1, +1), Conduction (−1, −1; hold +5, +3).

Nodes that did not do what they said:

- Burn Through's ramp fell away on every frame between two beam ticks, so before No Reprieve Bore and Deeper never held more than one tick's worth (a held body peaked at 0.21 s of dwell; now the whole hold).
- On bosses: Ironhead, Longshot, Burn Through, Weight of Heaven and Home Ground reached bodies only.
- Home Ground lifted auto-attacks only; Longshot ("everything you do") auto-attacks and the beam only.
- Weight Behind It was dead for the three Horns whose special strikes nothing (Air, Mud, Light).
- Pin Cushion read the auto-attack's darts only; Three Fronts paid the dart that reached the third body and not the first two.
- Sighted paid the Let's auto-attack meteor, about a fifteenth of a Let's damage since the rebuild.
- Hair Trigger's "re-arming no longer shortens how long it lasts" did nothing: a trap came back for a flat 6 s, where they are placed for 8-30 s.
- Deep Reserves strengthened the blessing alone (not the heals, shields or the Steam boiler); Communion never reached the ship.
- Virulence ticks raw damage, not the element's effect (the text now says what it does: an element payload on up to 160 carriers a second would cost too much and swing Contagion several-fold for an area element). Extended Coil's text described Full Span.

Also: Longshot walked every body on the field on every hit any mastery Wing landed, whatever its path (now a grid query, once a frame, and only for Standoff). Mastery damage through the shared area helper (Plague, Anvil, Last Stand, the Juggernaut pulse, payload bursts) and Bulwark's weight were filed as nobody's, and a beam tick or laser hit with any ramp at all was filed wholly as mastery; telemetry now files each path's own share. `startGame` now clears every family's run state, not three of eight.

### What changed

Numbers (`survival_mastery_*.dart`, node text in `lib/models/survival_family_mastery.dart`):

- **Mane Limitless**: the Endless Circuit strikes at 15% of its shot, once a lap per body (full, twice a lap). Far Throw, Overdraw and No Horizon unchanged.
- **Mane Twin Fang**: Honed Pair 80% a slash (70%), Crosscut +40% (+20%), Predator Step +40% (+25%), Blade Dance returns 60% (35%).
- **Kin Longline**: Full Span runs every shot to at least 60% of its longest reach (92%), the longest reach 900 (1,100), Crossfire's back line at half strength (full).
- **Kin Benediction**: Communion shares half the blessing (all of it), and the shared copies no longer echo into the orb.
- **Kin Conduction**: shield 30% of the laser's damage up to 18% of the ally's health (20%, 12%); Transfusion reaches 120 off the line (70).
- **Mask Contagion**: Plague reaches 90 (130) and one Mask's infection holds at most 160 bodies (320). Its damage numbers are back where the rebuild left them: cutting them by a third moved nothing.
- **Pip Salvo**: the extras hit at 60% (70%), and the capstone's four at 75% (full); an extra is also spent after that share of a dart's contacts in a crowd.
- **Pip Needlepoint**: +5% a Pin (+3%), Pluck 80% (55%).
- **Wing Burn Through**: Bore +60% (+45%), Deeper +120% (+80%).

Implementations (`cosmic_survival_game.dart`, `cosmic_survival_spawner.dart`):

- Burn Through's dwell is held for a tick interval after each beam tick (`wingBeamHold`), and the ramp runs on bosses.
- `damageBoss` gives Longshot, Home Ground, Bulwark's weight and Weight of Heaven as `_damageEnemy` does; Home Ground (`_homeGroundPower`) and Longshot apply to everything a companion deals, not its auto-attacks only.
- Weight Behind It puts its share on the auto-attacks of a Horn whose special strikes nothing (`hornSpecialStrikes`).
- Pin Cushion reads the special's darts; Three Fronts holds the first two bodies and pays them with the third; Sighted pays all of a Let's damage on what it Sighted (`_letSightedBonus`).
- Hair Trigger: a fixture's placed life is kept (`MaskMasteryState.placedLives`) and a re-armed trap comes back with it (Spring Again alone: `MaskTuning.rearmLife`, 6 s).
- Deep Reserves scales the special's self-heal, ship heal, shield and the Steam boiler's haste; Communion blesses the ship (`_updateShipBlessing`).
- Telemetry: `masteryUplift` on `_damageEnemy` and `damageBoss` files a multiplier's own share; `_damageEnemiesNear` takes a `masterySource`. Longshot's Standoff check is a grid query cached per frame. `startGame` clears every family's mastery state.

Tests: `test/survival_mastery_sweep_test.dart` (15, each shown failing on the code before the sweep). `test/survival_mastery_pip_test.dart` reads the capstone's new 75%. The probe gained `FAMILY_MASTERY_ONLY`, `FAMILY_MASTERY_TIER`, and per-family mastery, basic, healing and shielding columns.

### Where it stands, and what is left

- Two paths sit on the 40% line. Limitless is at 42% at P50, where a Mane already stands at 35% with no path; the circuit could go lower still. Salvo is at 40% at P100 E10: its damage and reach trims moved it a point or two, because a Pip dart in a crowd kills as it goes and the extras are worth how many there are. The next lever is the count, which the rebuild's own test pins at four (`survival_family_audit_fixes_2_test.dart`, "Pip Salvo loads a Dark Pip's black hole"); that is the user's call.
- Strong but under the line: Contagion now (35%, 30%, 29%), and, left as they were, Tracer (38%, 36%, 35%), Deathmask (33%, 27%, 26%; a party with one held 72% of P50 waves against 47%), Bombardment, Bulwark and Quickening. Benediction still lifts a party from 51% to 76% at P50, about where those leave theirs.
- The single-target paths (Twin Fang, Needlepoint, Falling Star, Burn Through, Longshot) still move a horde wave by a point or two; on a boss wave they now carry 12-27% of their family's damage. That is what they are for, but a player buying them for horde waves gets little.
- Not measured here: boss waves past P50, and every family's path bought at once.
