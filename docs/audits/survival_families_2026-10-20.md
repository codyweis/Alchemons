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
