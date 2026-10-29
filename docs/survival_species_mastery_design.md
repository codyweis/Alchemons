# Survival Family Mastery

Status (2026-10-29): **all eight families are implemented in combat, two paths each** — sixteen paths, sixty-four nodes. Each family had a third path until 2026-10-29; the seven that went (Twin Fang, Ground Zero, Needlepoint, Rearm, Juggernaut, Burn Through, Longline) barely moved a horde wave or were plain bonuses, and twelve number-only nodes in the paths that stayed were rewritten so every node changes how the family fights. Each family lives in its own file (`survival_mastery_mane.dart`, `_let.dart`, `_pip.dart`, `_horn.dart`, `_mask.dart`, `_wing.dart`, `_kin.dart`, `_mystic.dart`) with its own test suite. None of the 2026-10-29 rework has been played on device. The Base Command Mastery tab is polished (the first item of Phase 6).

Nothing in the panel is purchasable-but-inert any more.

## Purpose

Family Mastery gives each of the eight survival families one persistent, configurable combat path. It transforms the existing family autoattacks and selectively connects them to existing family-by-element specials. Every deployed member of a family uses that family's currently selected branch.

The system is intentionally not a separate tree for every creature. The catalog has more than 160 collectible creatures and variants; a bespoke progression tree for each would be difficult to understand, author, balance, and maintain.

The scalable identity formula is:

```text
family attack chassis
+ selected family-wide path
+ automatic elemental interpretation
+ the individual creature's existing stats
```

## Non-negotiable rules

- There are eight trees: Let, Pip, Mane, Mask, Horn, Wing, Kin, and Mystic.
- Unlocks are shared by every creature in that family.
- The selected path is stored once per family.
- Every creature in that family uses the same selected path.
- A family may select exactly one path at a time.
- Players may eventually purchase every path, but cannot activate them together.
- Switching paths is free outside a survival run.
- The selected path is snapshotted and locked when a run begins.
- Existing specials remain intact unless a node explicitly defines a bridge interaction.
- Elemental interpretations are automatic and are never separately purchased.
- Temporary run power-ups continue to stack on top of the permanent family build.

## Tree and economy

Every family has two paths of three sequential nodes and a capstone, bought with that family's own mastery points. Since 2026-10-09 masteries are earned by playing survival, not bought with silver and gold.

| Tier | Cost | Purpose |
| --- | ---: | --- |
| Path I | 25 mastery | Establishes the path's core behavior |
| Path II | 75 mastery | Adds its first meaningful interaction |
| Path III | 150 mastery | Completes the path's combat loop |
| Capstone | 300 mastery | Dramatically changes the visible combat rhythm |

Earning (per creature since 2026-10-10, `familyMasteryCreatureAwards`): when a survival run ends in a death, its base is `1 + w ~/ 10` points for each wave `w` it cleared (`familyMasteryPointsForRun`; a run lost on wave 41 cleared 40; 19 waves is 29, 39 is 99, 59 is 209, 79 is 359). Each creature in the party earns its own points: `0.5 × base` if it was deployed at any point (`CosmicSurvivalGame.deployedCompanionSlots`, kept in the suspended run), or `0.125 × base` if it sat in reserve the whole run; plus `0.5 × base × N × c`, where N is how many were deployed and c is its share of the team: the mean, over damage dealt, kills and healing done (only the axes the team has any of), of its part of the team total (all zero: an even split). Capped at `1.5 × base`, rounded, at least 1 if deployed. A family is paid the sum of its creatures, so bringing more of a family earns it more; an average deployed creature earns about one base. The results list each family's points as a reward row with each creature's part under it. Balances (and lifetime earned) live in the settings key `survival.family_mastery_points_v1`, so the cloud save carries them. Nodes bought with silver or gold before the change stay owned; nothing was refunded, and every family started at 0.

Rules:

- A later node requires every earlier node in that path.
- Buying the first node automatically equips that path if no path is selected.
- Buying another path does not automatically replace the equipped path.
- A partially purchased path may be equipped and grants its purchased nodes.
- Selecting or resetting a family branch costs nothing.
- Owning a family's whole tree costs 1,650 of its mastery (Mystic 1,100).

The economy controls collection progression. The one-path limit preserves build choice after everything is owned.

## Current scaling contract

The existing combat model remains authoritative:

- Strength produces physical attack and therefore main autoattack damage. It also contributes to critical chance and durability.
- Beauty produces elemental attack and therefore special damage and mastery payload damage — **except where a family defines its own ability stat contract**. See *Per-family ability stats* below; Mane has one, the other seven do not yet.
- Speed produces movement speed and cooldown reduction.
- Intelligence produces range and defenses and may scale spatial utility.
- Guardian upgrades continue modifying derived companion stats.
- Temporary survival surges continue feeding those same stats.

Evaluation order:

1. Derive combat stats from level, genetics, enhancement, family multipliers, Guardian upgrades, and in-run stat bonuses.
2. Create the existing family basic attack from physical attack.
3. Apply the equipped Family Mastery path.
4. Apply temporary run perks and keystones.
5. Resolve critical hits, damage amplification, mitigation, statuses, hit effects, and kill effects.

Main and elemental portions scale separately:

```text
main hit = physical attack × family coefficient × mastery allocation
elemental payload = elemental attack × payload coefficient
```

Splits, returns, ricochets, echoes, and additional projectiles divide a defined damage budget rather than copying the full original hit.

## Shared combat language

### Cast accounting

A **basic cast** is one scheduled autoattack, regardless of how many projectiles it creates. Cast-based nodes increment once for a Mane pair, a Pip volley, a Wing pair, or a Mystic volley. This prevents multishot families from triggering effects three times as often.

A **dual hit** means two projectiles from the same cast hit one target within 0.35 seconds. A **full volley hit** means every eligible projectile from the cast hits that target.

### Elemental payload

Some nodes trigger the equipped creature's elemental payload. Unless a family node overrides it, one payload uses the following initial tuning. Values are prototypes and should be simulation-tuned.

| Element | Payload |
| --- | --- |
| Fire | Scorch for 30% elemental attack over 2 seconds |
| Water | Pull 24 units and slow by 12% for 1.2 seconds |
| Earth | Stagger for 0.25 seconds; bosses receive a brief 8% slow instead |
| Air | Push 45 units and interrupt ordinary enemies |
| Plant | Root for 0.4 seconds and deal 15% elemental attack as a thorn hit |
| Ice | Add Chill for 2 seconds; three stacks freeze for 0.45 seconds |
| Lightning | Arc for 30% elemental attack to one nearby enemy |
| Poison | Add a toxin dealing 12% elemental attack per second for 3 seconds, up to three stacks |
| Steam | Burst in a small radius for 22% elemental attack and push slightly |
| Lava | Leave a 2-second molten patch dealing 10% elemental attack per second |
| Mud | Apply Heavy, slowing by 25% for 1.5 seconds |
| Dust | Apply Haze, reducing movement and attack cadence by 10% for 2 seconds |
| Crystal | Fire a shard at another target for 25% elemental attack |
| Spirit | Echo 25% of the triggering elemental damage after 0.5 seconds |
| Dark | Pull 35 units and expose the target to 5% more damage for 2 seconds |
| Light | Illuminate the target, increasing allied damage to it by 5% for 2 seconds; maximum 10% |
| Blood | Heal the owner for 1% maximum HP; at most once per second |

Payload rules:

- A node states whether it triggers once per cast, once per target, or on a cooldown.
- A payload cannot recursively trigger another payload.
- Mastery Lightning and the temporary Chain Lightning perk share a chain budget instead of multiplying one another.
- Status durations are reduced against bosses where necessary, but payload damage is not silently removed.
- Mastery projectiles retain source slot, family, species, element, and basic-attack attribution.

## Family speeds

**Mane throws at half speed (2026-09-17).** Every Mane projectile — the two basic blades and all seventeen special catapults, authored outliers included — had its travel speed halved, and the specials' lifetime doubled to match, so each shot keeps exactly the reach it had and simply takes twice as long to get there. A Mane shot should read as a thrown weight whose pierce can be followed, not as a bullet. The blades keep their two-second life: at 300 units a second that still carries them 600 units, three times the companion's attack range, so nothing falls short. The constant is `kManeBasicSpeedMultiplier`; the special clamps live in the family rewrite in `cosmic_data.dart`.

## Family trees

All percentages below are initial balance targets, not final shipping numbers.

Design rules for nodes (revised 2026-09-16):

- **Every node pays off on its own.** A node that builds a resource (Rhythm, Tempo, Momentum, Focus, Insight) or places a mark (Sigil, Conductivity, Seed, Sight) also grants a small immediate bonus, so a first purchase is never inert.
- **A bonus must act on something the branch already has.** No payload-strength bonuses on a branch that has not yet produced payloads.
- **Resource branches spend their resource coherently.** An earlier node must not drain the reserve that a later node consumes.
- **In-game text is player language.** The catalog descriptions (`survival_family_mastery.dart`) say what the node does, with its numbers, in terms the player sees: "attack", "your special", "your element's effect", "both slashes hit the same enemy". Never use "payload", "cast", "basic", "dual hit", or "full volley hit"; a test enforces this. This doc keeps the precise combat terms.

---

## Mane

**Existing chassis:** two close-angle slash projectiles at 65% physical damage each, and a slow piercing catapult as the special. Mane is a flexible skirmisher that rewards positioning both blades.

**Two paths since 2026-10-29**, one for each half of the chassis: War Rhythm changes what the slashes earn, Limitless changes how the catapult travels. Every node changes what an attack does; none is a bare percentage.

- **Twin Fang was cut.** Honed Pair, Predator Step and Blade Dance were damage on hits that mostly killed anyway: the 2026-10-21 sweep measured the whole path at a point of party share (35% to 36% at Potential 50, 31% to 32% at 80). Its one node that changed what an attack does, **Crosscut**, moved to War Rhythm with the same numbers, where a clean pair already earned a Rhythm.
- **Crescendo was cut** from War Rhythm. It spent the reserve on +12% damage and a payload for a few attacks, so the special was the drain on a resource Encore wanted full. The special now spends Rhythm only for an Encore.
- **Overdraw became Hunter's Arc.** A flat 15% on the special became a change to where the special goes.

Saves that owned the removed nodes simply drop them, as with Tempest Claw (`FamilyMasteryCatalog.sanitizePurchases`). The game is unreleased, so nothing is refunded.

Measured with `test/family_balance_survival_test.dart` (`FAMILY_MASTERY=<path> FAMILY_MASTERY_ONLY=1`, 105 parties), a Mane's share of party damage and the hold rate of parties with a Mane: no mastery, then the path before the change, then after.

| Path | P50 w36 share | P50 w36 held | P80 w41 share | P80 w41 held |
| --- | --- | --- | --- | --- |
| War Rhythm | 35% → 39% → **40%** | 49% → 51% → **49%** | 31% → 33% → **34%** | 87% → 89% → **89%** |
| Limitless | 35% → 42% → **42%** | 49% → 63% → **60%** | 31% → 36% → **39%** | 87% → 92% → **93%** |

The probe is not fully deterministic: the hold rate of parties *without* a Mane, which no Mane path can touch, read 53% and 57% on two runs of the same build, so hold differences of a few points are noise. War Rhythm's hold lift was within that noise before the change and still is; its share sits at the 40% ceiling, so there is no room to buy one with damage.

**2026-10-29, second pass: Crosscut reaches bodies instead of adding to one.** +40% on a body both blades had already struck was damage on a body that mostly died to the pair. Crosscut now sends the pair on through it to the next body ahead, carrying the element, and a crossed pair can cross again, up to three bodies an attack (node 2 below). Re-measured with 420 parties (the 105 above were too few to call a hold lift either way), P50 wave 36, Mane share / held: no mastery 33% / 60%; War Rhythm before 38% / 61%; one crossing 38% / 62%; up to three 39% / 62%. P80 wave 41: no mastery 30% / 91%, before 34% / 91%, after 34% / 93%. **The path still lifts no waves held.** The trace below (Wing, "what breaks a party") is why: at P50 wave 36 the orb is lost to brutes' siege beams, fired from 300-560 out, and a Mane's slashes go to whatever is closest to the Mane. Reaching three more of those bodies is still reaching chaff; the hold rate moves with what the catapult does, which is Limitless's half of the chassis. Encores roughly doubled (1.4 to 2.9 a party at P50) now that a special below five no longer empties the reserve. Hunter's Arc was first measured with a third of a lap to turn (44% at P50, 39% at P80); a quarter and a sixth both measured 42% and 39%, and a quarter was kept. What keeps Limitless above 40% at Potential 50 is still the Endless Circuit, as in the 2026-10-21 sweep: through No Horizon the path carries a Mane to 38%, and the circuit takes it to 42%.

### Resonance — War Rhythm

Clean pairs build Rhythm and pay out; a full reserve is spent on the special.

1. **Measured Cuts** — A dual hit grants one Rhythm, up to five. Each Rhythm grants 2% basic attack speed. A cast that misses with both blades removes one Rhythm.
2. **Crosscut** — When both blades of an attack land on one body, the pair crosses through it and flies on: the attack's own two slashes, at their own damage, thrown again from the body's far side at the nearest body ahead (inside ±60° of the pair's heading, within 240) or straight on, for 0.9 s (`_crossManePair`). The crossed pair's first hit carries one elemental payload, and if both of its blades land on one body it crosses that one too, up to three bodies an attack (`ManeTuning.crosscutCrossings`). A crossing is its own tagged cast (`ManeCastTags.crosscut`), not a scheduled attack: it earns no Rhythm, and its damage is filed as mastery. Until 2026-10-29 (second pass) it was +40% physical on the body both blades had struck, and one payload per cast (20% until the 2026-10-21 sweep).
3. **Tempest Ring** — Every fourth scheduled attack also throws eight radial slashes at 20% physical each that pierce, strike a body at most three times between them, and carry one payload on the ring's first hit. The ring is its own cast that does not count as a scheduled attack. Tier 2 until 2026-10-29.
4. **Capstone: Encore** — Casting the special at five Rhythm spends all five and opens a 6-second Encore: 25% faster basics and slashes 20% wider. Basic kills extend the current Encore by 0.4 seconds, up to 2 additional seconds total; Encore cannot otherwise refresh itself. Below five, or while an Encore is running, the special spends nothing — nothing else spends Rhythm, so a reserve built during an Encore waits for the next special after it. The rule lives in `ManeMasteryState.trySpendForEncore`.

### Limitless

One idea, four times: the catapult shot does not stop.

1. **Far Throw** — Special projectiles carry 45% longer before fading, piercing more on the way.
2. **Hunter's Arc** — After its first hit, each of the special's projectiles bends toward the nearest body ahead of it: inside about ±60° of its heading (`arcConeHalfAngle`), within 260 units, that it can still strike and is not already passing through. A shot with nothing ahead flies straight, and a shot that has struck nothing yet never bends. It turns no tighter than a 160-unit circle and no faster than 2.6 rad/s (about 1 rad/s at the catapult's crawl), so it reads as an arc, and no more than a quarter of a lap in all (`arcTurnBudget`), so a No Horizon shot that keeps finding bodies still leaves the arena (a Lightning orb has no budget: it comes down where it is going). It re-picks its body every 0.15 s from the enemy grid, as homing does. No new art: the shot is drawn where it is. In each element's own terms:
   - the thirteen single catapults, Fire's fan and Spirit's stream turn their heading shot by shot; what a shot sheds on the way (Earth's quakes, Steam's geysers, Dust's cloud, Lava's blobs) falls along the curve it takes;
   - **Lightning**'s orbs fly to a landing point rather than on a heading, so an orb that has crossed a body swings its landing point round, onto the body ahead at that body's range, and its field blooms there;
   - **Mud**'s ball is spent by its first hit, which is what throws the shards, so the shards bend from the moment they are thrown, and they skip the body that broke the ball. Without the node all ten are spent on that body in their first frame, because they are thrown from inside it (the base game's behaviour, left alone);
   - **Light**'s ward does not fly. A ring that has struck something leans out of (or into) its orbit toward the body ahead of it on its round, up to 80 units at 150 units a second, and eases back when nothing is ahead;
   - the Endless Circuit does not bend: it is the rim.

   Replaced **Overdraw**, a flat 15% on the special, on 2026-10-29. Overdraw was plain on purpose — several elements already grow as they travel, so a "gains power with distance" node would have described what the element was already doing — and that is why it was replaced with a node about direction instead of power.

3. **No Horizon** — Special projectiles stop ageing. Only leaving the arena ends them.
4. **Capstone: Endless Circuit** — One shot sweeps to 72% of the arena radius and circles it at 0.575 rad/s (a lap in about eleven seconds), permanently, dragging a burning arc behind it. Enemies spawn on a ring around the orb and walk inward, so the rim is the line every wave crosses — this is a perimeter, not a shot thrown away.

   **It collides as the blade it draws (2026-09-17).** On device the circuit visibly hit almost nothing. A slash is drawn eight units per point of visual scale to either side of its position and collided as a circle about a fifth of that — invisible on a shot that crosses the arena in a second, and a plain lie on a blade parked across the rim for the rest of the run, where enemies walked through the drawn slash and took nothing. The circuit now collides as what it draws. Measured across bodies walking in at twelve angles, with nothing else in the arena: 7 of 12 caught before, 9 of 12 after — and the three it still misses are bodies that cross while the blade is on the far side of the arena, which is the shape of a single perimeter guard rather than a bug. Halving its sweep to 0.575 rad/s costs nothing here, because coverage never came from speed — a faster point covers no more of the circle.

   **The capstone lays nothing down.** It stops the shot; it does not add an ability. An element whose special already leaves something behind as it travels keeps doing so on the rim — Steam drops its geysers, Dust its cloud — and an element that does not, like Ice, leaves the rim clean. An earlier pass had the head emit its own trailing embers to cover the rim; that was the capstone inventing an ability the element never had, and it was removed.

   **Per-lap hit ledger.** The head carries the family's ordinary two-hits-per-body ceiling, cleared once a lap. Unlimited was wrong in both directions: contact is re-tested every frame, so a body the head overlaps was billed four times a pass (eight at the halved speed), while a flat ceiling with no reset would have retired the head against anything that survived one pass.

   **It points where it travels.** The blade's angle follows the tangent of its lap, so a slash sweeping the rim is drawn along the rim rather than frozen at the angle it was thrown.

   **Light rides its ward instead.** Light is the one element whose special never becomes a projectile in flight — the ward swallows it — so there is no first shot to peel off. Its outermost ring leaves the Mane and takes up the same circuit, which is the same idea in the element's own language: the ward stops guarding the creature and starts guarding the map. The ward hangs a replacement on its next cast, because a ring that became a circuit no longer counts as one of its own.

   **Built once, not per cast.** The first special that finds no circuit turning builds one; every cast after that fires normally. Taking the first shot of *every* cast would have meant something quite different for the fifteen Mane elements that throw a single projectile — their special would have been permanently spent rebuilding a perimeter that already existed, and would never have reached a target again. One cast is the price; the circuit is the thing bought. If it is ever lost — carried out of the arena — the next cast quietly builds another.

Audited across all seventeen elements: fifteen build one circuit on their first cast and fire normally thereafter, Fire keeps seven of its eight shots for the target on the cast that builds it, and Light rides its ward as above. Lightning is the one exception — its orbs are authored to bloom into shock fields on arrival, which consumes them, so its circuit is lost and quietly rebuilt each cast. It never accumulates and it self-corrects, so it is left alone.

*Replaced Tempest Claw on 2026-09-16.* That path measured last of the three and three of its four nodes had no idea in them: two stat tweaks and a node (Crosswind) that re-applied the element the node above it had already applied to the same bodies. Its one good node, Tempest Ring, moved to War Rhythm where a cadence counter belongs.

---

## Let

**Existing chassis:** one large, slow meteor at 115% physical damage, thrown flat at a single target. Let is the deliberate heavy artillery family, and its targeting already prefers the toughest enemy and bosses.

**Two meteors — every node names which one it changes.** A Let throws two different things, and the tree text must never leave the player guessing which. Both paths change the auto-attack meteor; the special meteor is the element's.

- **The auto-attack meteor** — the rock thrown on every attack (the chassis above).
- **The special meteor** — the skyfall that drops onto a locked target and craters, carrying the element's own effect from the design board (see the Let specials design memory: Air shoves, Fire explodes on a kill, Dark throws follow-up meteors, and so on).

**Nothing in this tree may take over an element's signature (2026-09-17).** Each Let element's special owns one mechanic, and a mastery path that grants that mechanic to every Let erases what made that element distinct. The owned mechanics are:

| Mechanic | Owned by |
| --- | --- |
| Shoving enemies | Air (Steam's geyser also shoves) |
| Slowing | Dust, Crystal |
| Burning ground | Lava |
| Poison | Poison |
| Vines and rooting | Plant |
| Healing and lifesteal | Blood, Earth, Light |
| Execute | Spirit |
| Explosion on a kill | Fire |
| Chaining | Lightning |
| Extra meteors | Dark (Blood's meteor also breaks into pieces) |
| Freezing | Ice |
| Stunning | Mud |
| Splash damage | Water |
| Faster special cooldown | Crystal |

So Let mastery works only in what no element owns: damage, range, targeting, and the shape of the auto-attack's delivery.

**Replaced 2026-09-17.** The earlier tree was Falling Star, Scatterfall and Orbital Cycle. Scatterfall was built from owned mechanics (fragments and extra meteors are Dark's and Blood's, crater splash is Water's, and Lingering Fall invented ground effects for elements that have none). Orbital Cycle had the Tempest Claw problem — an abstract counter carrying three "more damage near the special" nodes — and its capstone repeated the special's entire aftermath, which for Dark means re-running a five-meteor bombardment. Falling Star's Terminal Velocity was pure numbers that only made sense while the auto-attack flew flat. Saves that owned the removed nodes simply drop them, as with Tempest Claw.

### Falling Star — auto-attack meteor

One enormous hit.

1. **Dense Core** — The auto-attack meteor deals 135% physical damage instead of 115%, is 12% smaller and flies 10% slower.
2. **Cratermaker** — An auto-attack meteor hit applies Fracture for 4 seconds; the next auto-attack meteor hit on that body deals 18% more.
3. **Dead Weight** — The auto-attack meteor deals 25% more to bodies above half health. Let's targeting already prefers the toughest body, so this pays for the family doing what it already does.
4. **Capstone: Extinction Event** — Every fifth auto-attack meteor is a giant comet dealing 210% physical damage in a wide crater. Only the direct target can be critically hit. This is a bigger meteor, not more meteors.

### Bombardment — auto-attack meteor

The auto-attack stops being thrown and starts falling — the same motion as the special, which is what makes a Let read as a Let.

1. **Deadfall** — The auto-attack meteor becomes a skyfall through the shared `letSkyfallDrop` / `CosmicAbilityRuntime.advanceSkyfall` runtime: target-locked, undodgeable, landing in a crater a third of the special's radius. It carries no element effect — the special's on-collide and on-kill behaviours stay the special's. The price is the descent: damage arrives after the fall rather than on release.
2. **Heavy Ordnance** — The auto-attack crater is 35% wider, and bodies in it other than the one landed on take 75% of the hit instead of the skyfall's usual 55%.
3. **Ranging Shots** — Attack range rises 25%. Each drop on the same body within 3 seconds of the last deals 10% more, up to 30%; changing target resets it.
4. **Capstone: Skyreach** — The auto-attack is no longer limited by range: it can land on any enemy in the arena and always chooses the one with the most health, bosses first. One drop per attack, as ever — this changes where it lands, not how many land.

### Ground Zero — cut 2026-10-29

Every family went to two paths, and Ground Zero was the Let's weakest. The special meteor marked what its crater caught (Sighted), the auto-attack meteor hit marked bodies 20% harder and preferred them (Walking Fire), the whole team hit them 10% harder (Called Shot), and the Let attacked faster while anything was Sighted (Fire for Effect). Three of the four were percentages on hits that mostly killed anyway, and the 2026-10-21 sweep measured the whole path at a point of party share (23% to 25% at Potential 50, 19% to 20% at 80) against Bombardment's eight and seven. The `MasteryPayloadStatuses` Sight fields went with it. Saves that owned its nodes drop them, as with Tempest Claw.

### Let implementation notes (2026-09-17)

- **Where it lives.** Numbers, node ids and the per-hit bonus rule are in `survival_mastery_let.dart`; the game wires them in under "Let mastery" in `cosmic_survival_game.dart`. The body status (`letFractureTimer`) lives on the shared `MasteryPayloadStatuses`, so enemies and bosses carry it alike.
- **One place for the auto-attack bonuses.** Cratermaker, Dead Weight and the Ranging Shots streak are resolved together in `resolveLetAutoAttackBonus`, called from `_damageEnemy` and `damageBoss` only for damage that belongs to a Let *basic* cast. Crater splash carries no cast, so it never earns them. The bonus is additive, and its share of the hit is credited to mastery in telemetry.
- **Deadfall** builds its falling rock through the same `letSkyfallDrop` geometry as the special, and marks it `letDeadfall` so it lands through its own `_detonateLetDeadfall` — nearest body under the crater takes the rock, the rest take the crater share, and `_resolveLetMeteorHit` (the special's element behaviour) is never reached. Its ground telegraph draws the auto-attack crater, not the special's, and it sheds about a third of the special's descent embers.
- **Comets** (Extinction Event) still fly flat; the crater opens on first contact through `_openLetCrater`, once.
- **Skyreach** fires from `_tryFireLetSkyreach` before the in-range attack block, on its own target (the healthiest boss, else the healthiest enemy, anywhere), whether or not anything is near the Let. It spends the cooldown, which is what stops the ordinary attack firing a second rock that frame. The Let does not walk to the target. A capstone activation is recorded only when the target was beyond ordinary reach.
- **Tests** check every node against the real combat loop, including that a falling Air rock shoves nothing and a killing Dark rock calls no follow-up meteors, and that each capstone records itself.

## Pip

**Existing chassis:** three fast spread darts at 30% physical damage each. Pip is the rapid, precision-volume family.

A rule the whole family is built around: **no path may take a mechanic an
element already owns.** Pip's seventeen specials between them claim push
(Air), slow fields (Dust, Mud), damage over time (Fire, Lava), persistent
lines (Poison), healing (Blood, Light), cooldown shaving (Earth),
attack-speed windows (Steam, Spirit), taunts (Crystal), ricochets
(Lightning), freezing (Ice), meter gain (Plant), kill-splash (Water) and
black holes (Dark). The family's first design had a ricochet path and an
attack-speed path, which would have handed Lightning's, Steam's and Spirit's
identities to every Pip that bought them. Both were replaced. What was left
unclaimed — dart counts, target spread, when the darts fly — is what these
paths are made of.

Two paths since 2026-10-29 (every family has two). **Needlepoint** — all
three darts into one body, banking Pins and plucking them for a burst, with a
bonus volley every fourth full one — was cut: its nodes were percentages on
hits that already killed, and it moved a horde wave by a point (13% → 13% of
party damage at P50, 30% → 30% at P80 in the 2026-10-21 sweep).

### Control — Scattershot

One dart into each of three bodies.

1. **Wide Spray** — Spread widens 40% and each dart curves toward its own nearby enemy. Widening without seeking would only miss.
2. **Three Fronts** — Three darts on three different bodies pays every one of them 20% extra.
3. **Fourth Barrel** — The volley fires a fourth dart.
4. **Capstone: Scatter Storm** — Every fifth attack throws eight darts, each seeking its own body, at 22% each. Not counted as another scheduled attack.

### Salvo

Leaves the volley alone and loads the special instead. One more dart per node
(1, 2, 3, 4 extra), each at 60% of an authored dart's damage and reach, 75% at
the capstone. The middle two nodes used to be the same node twice ("another
dart, also at 60%"); since 2026-10-29 each also changes how the extras are
thrown.

1. **Spare Needle** — One more dart on the special, at 60%.
2. **Second Volley** — Another dart, and the extras are held back and thrown
   0.25 s after the special, as a second volley: at the body the special was
   thrown at, or the body nearest the Pip (within 420) if that one died, or
   along the old aim if nothing is near. Aimed from where the Pip stands when
   it throws. (`_applyPipSpecialMastery`, `_throwPipSecondVolley`.)
3. **Wide Load** — Another dart, and the extras leave the volley's flanks
   instead of its edge: alternating sides, the first pair 0.42 rad (24°)
   either side of the aim and each pair after 0.30 rad further, about 82° in
   all against 15-25° for most elements' authored volley. A fanned dart flies
   straight for 0.2 s before it seeks, so the fan opens before each dart turns
   for the body nearest it (`pipSalvoOffset`, `PipTuning.wideLoadHold`).
4. **Capstone: Perfect Salvo** — A fourth extra dart, and every extra hits and
   reaches at 75%.

Each extra is a *copy of the element's own dart*, so a Lightning salvo still
ricochets five times and a Blood salvo still heals on a kill. The path adds
darts and decides when and where they leave; it never decides what a dart
does. Sixteen elements throw their special as darts from the Pip; Air's and
Light's leave as a ring and Steam's do not seek, and the extras leave from the
aim all the same, so both behaviours read alike for all sixteen.

**Dark** throws nothing: its special is the black hole an auto kill opens. Salvo
loads the hole, which spits one dart per node at the bodies round it, once per
special interval (`_loadPipDarkSalvo`). Second Volley holds them in the hole
for the beat, so the hole opens and then spits. Wide Load, with no arc to
widen on a hole that already spits all the way round, spits each dart straight
at a different body within 320 of the hole, nearest first, where they used to
set off round the ring and chase whichever body was nearest them
(`_fanPipDarkDarts`). That matters more than it sounds: a hole's darts fly at
1,200 a second and turn at 3 radians a second, so set off the wrong way they
rarely come back. With a body 60 from the hole and three more 170 out, three
darts spat round the ring struck 0-1 of them over six seeds; fanned, three.

One consequence, accepted: **a flat dart is worth different amounts per
element.** Lava throws two darts, so four more nearly triples it; Lightning
throws six, so four more is a 1.7x lift. Scaling by percentage instead would
be fairer and far less legible on a tooltip.

---

## Mask

**Existing chassis:** one fast piercing dart at 90% physical damage. Mask specials place fixtures — traps that persist and wait, and whose element decides what they do when something touches them.

Two paths since 2026-10-29: **Deathmask** and **Contagion**. The draft tree
these replaced (Phantom Needle, Hexweaver, Grand Masquerade) and why it was
dropped are under *Mask — Deathmask, Contagion* below. **Rearm** (a trap that
goes off re-arms: Spring Again, Hair Trigger, Snap Shut, Held Ground) was cut
in the move to two paths.

### Deathmask

Every kill leaves a trap behind.

1. **Grave Goods** — A dart kill leaves a small trap of the Mask's element where the body fell, at 35% strength. Only a dart kill, never a trap's own; at most twelve graves a Mask and one every 0.35 s.
2. **Restless Graves** — The graves move at a walking pace (75 units a second) to the nearest body standing still — planted for its signature attack (a brute charging its siege beam, a sentinel its volley), siege artillery at its hold, or anything rooted, frozen or stunned (`_enemyStandingStill`) — and lie under it, keeping with it while it lives and stays within 360. With nothing standing still in reach, a grave makes for the thickest press of bodies near it and sits in the middle (`_thickestCrowdNear`, the densest enemy-grid cell's bodies); with no body at all, a boss. Each grave looks again four times a second (one grid query, and the grid's own cell counts). Only graves move: the traps the special places stay where they were laid. A moving grave keeps the look it was laid with (`Projectile.lookAnchor`). Replaced Open Grave (40% wider, 50% longer), which was a plain size bonus; until 2026-10-29 (second pass) the graves crept at 18 after the nearest body. (`_updateMaskRestlessGraves`.)
3. **Cold Ground** — Graves carry the element's full effect instead of a weakened one.
4. **Capstone: Necropolis** — A dart kill inside one of the Mask's own traps leaves a full-strength grave.

### Contagion

What the traps catch carries it on.

1. **Carrier** — A body that walks out of a Mask trap alive is infected for 6 s.
2. **Spread** — An infected body passes it to up to five others within 110 once a second, for at most four generations from the trap.
3. **Virulence** — Infection eats at its carrier every half second.
4. **Capstone: Plague** — An infected body that dies bursts, infecting everything within 90 and dealing damage. One Mask's infection holds at most 160 bodies.

---

## Horn

**Existing chassis:** one slow, oversized projectile at 160% physical damage. Horn specials center on charges, impact sweeps, passive auras, and defensive effects.

Two paths since 2026-10-29: **Bulwark** and **Bastion**. The draft tree these
replaced (Breaker, Bastion's first draft, Stampede) and why it was dropped are
under *Horn — Bulwark, Bastion* below. **Juggernaut** (the special runs a
second time: Second Effort, Full Weight, Relentless, Second Front) was cut in
the move to two paths.

### Bulwark

Turns bulk into damage.

1. **Ironhead** — Attacks hit for an extra 2.5% of maximum HP.
2. **Weight Behind It** — The special carries the same weight at 60%, folded into the charge once at cast. A Horn whose special strikes nothing (Air, Mud, Light) carries it on its attacks instead.
3. **Braced** — The weight rides current health: 1.5x at full, 0.5x nearly down.
4. **Capstone: Anvil** — A body killed by the weight ruptures for 12% of maximum HP within 120.

### Bastion

Takes the hits meant for the team.

1. **Guarded Shot** — Each attack banks a shield of 1.5% of maximum HP, up to 6%.
2. **Bodyguard** — Within 260 of the orb, a quarter of the orb's damage is taken by the Horn instead, 40% less of it.
3. **Shield Wall** — While the shield holds, allies within 150 take 20% less.
4. **Capstone: Last Stand** — A shield broken through ruptures for 2.2x the shield it had, within 160, and gives back 20% of the special's cooldown; once every 4 s.

---

## Wing

**Existing chassis:** two same-angle projectiles at 50% physical damage each with slightly different speed and lifetime. Wing specials are beams and long-range elemental lanes.

Two paths since 2026-10-29 (the reasoning is under "Wing — Longshot and Tracer" below). Burn Through, a damage ramp on a held target, was cut.

### Longshot — the further out, the harder you hit

1. **Rangefinder** — Everything the Wing does to an enemy past 60% of its range deals +15%.
2. **Long Lens** — Range +20%, and an auto-attack at a body past 60% of range is aimed where the body will be when the shots arrive (its heading and speed, the slower shot's flight time, capped at 0.8 s of travel). Bosses and near bodies are fired at straight.
3. **Standoff** — While nothing is inside 30% of range, the +15% applies at any distance.
4. **Capstone: Overwatch** — Every body that comes into the band from 60% of range to its edge takes one free auto-attack, aimed as Long Lens aims, paid the Longshot bonus as any hit there is. Once per body per Wing. Looked for ten times a second over the grid cells the band covers. Since 2026-10-29 (second pass), a body that begins to take aim within twice the Wing's range — a brute charging its siege beam, a sentinel gathering its volley — takes a free shot too, each time it does (`_onEnemyTakesAim`, called where the wind-up starts, so nothing scans for it). Both come out of one bank of six, refilled at twelve a second. Long Lens no longer leads a body planted for its own attack: it is not walking (`_enemyPlanted`).

### Tracer — your shots feed your beam

1. **Tracer Rounds** — Each auto-attack that lands takes 0.25 s off the special's cooldown.
2. **Loaded Beam** (saved id `wing.tracer.ranging_shots`; it was sold as Ranging Shots, which is also a Let node) — Each landed auto-attack also adds 0.1 s to the next beam, up to 1.5 s.
3. **Hot Barrel** — While the Wing's beam is firing, its auto-attacks come twice as fast.
4. **Capstone: Live Feed** — While a beam is firing, landed auto-attacks lengthen that beam instead of banking for the next one.

---

## Kin

**Existing chassis:** a dedicated 1.5-second charged laser scaled from physical attack. Kin specials are primarily blessings and team support effects.

Two paths since 2026-10-29 (the reasoning is under "Kin — Conduction and Benediction" below). Longline, the laser's reach, was cut.

### Conduction — the line carries help, not just harm

1. **Live Current** — Allies the laser passes through gain a shield worth 30% of the damage it dealt (at most 18% of their health, topped up rather than stacked).
2. **Lifeline** — An ally below half health is healed instead, for half again as much.
3. **Grounding** — The Kin's element lands on every enemy down the line.
4. **Capstone: Transfusion** — The shield and heal are worth 50% more and reach allies within 120 of the line.

### Benediction — the support reaches the whole team

1. **Kindred** — The ally standing nearest the Kin when it casts gets the cast's support as the Kin does: its heal, its blessing and any shield, at full strength and for as long. For Kin+Fire, which never casts, the ally nearest it when the phoenix fires is reborn with it, keeping the same haste and damage for the rest of the run.
2. **Vigil** — While any ally is below half health, the special recharges twice as fast. For Kin+Fire, the reborn flame burns twice as often instead.
3. **Unbroken** — Being downed no longer ends the support; it runs its full course.
4. **Capstone: Communion** — The blessing reaches every ally and the ship, however far: Kindred's ally keeps all of it, the rest get half.

---

## Mystic

**Existing chassis:** three 40%-damage spell projectiles. Basic attacks already reduce special cooldown. Mystic specials transform the world and normally cast only once per deployment.

Mystic mastery never adds further special-cooldown refunds. Two paths (the reasoning is under "Mystic — Quickening and Firmament" below).

### Quickening — the world acts far more often

1. **Quickening** — Each time the world acts, the next body to die (to anything, anywhere) makes it act again at once at half strength: its latest act, the same way, in the same place. One repeat per act of its own, however many die after it. An Ice world, whose blizzard has no act of its own, gains one: every 6 s at P50 (its beat, quickened by the surge and SPECIAL as the other clocked worlds are) the blizzard freezes everything in it for 12% of the beat. Without the path the blizzard is exactly the steady slow it was. Until 2026-10-29 (second pass) each body the world killed brought its next act 0.2 s sooner, which reached nine worlds of seventeen.
2. **First Light** — The world acts the moment it ignites: the clocked worlds (Lightning, Earth, Steam, and a Quickening Ice) act on the frame they are lit, and Light's dawn breaks on the next one. The placed worlds act on their first contact anyway, and the rule worlds (Spirit, Blood, Dark, Mud, Crystal, Dust) when their trigger first comes.
3. **Aftershock** — Each time the world acts, it acts again half a second later at 40% strength, in the same place. A repeat is not repeated.
4. **Capstone: Relentless Sky** — Each time the world acts, it acts once more a quarter of a second later at full strength (the aftershock still follows). An Ice repeat holds the freeze still running that share longer.

### Firmament — the world shelters its makers

1. **Native Air** — Allies standing in the world take 15% less damage.
2. **Home Ground** — They deal 15% more while they stand in it.
3. **Tended** — The world mends allies inside it, 1.2% of their health a second.
4. **Capstone: Sanctum** — Their attacks carry the world's element.

## Elemental interpretation principles

The shared payload table is the baseline, not the full presentation. Each family expresses the same element through its chassis:

- Mane applies elements through crossed or sweeping slashes.
- Let applies them through impacts, fragments, and craters.
- Pip applies them through volley completion and ricochets.
- Mask applies them through marks, pierced lanes, and fixtures.
- Horn applies them through impact, guard, and Momentum release.
- Wing applies them through paired trajectories and beam geometry.
- Kin applies them through laser marks and ally relays.
- Mystic applies them through sigils, Seeds, and its active world.

This creates distinct Fire Mane, Fire Let, and Fire Kin behavior without requiring separate authored trees.

## Interaction with temporary run power-ups

- Stat surges remain fully effective because mastery reads derived stats.
- Double Cast affects the authored special, not mastery-generated repeats.
- Chain Lightning uses a shared maximum chain count with Lightning payloads and Living Circuit.
- Elemental Fury may trigger from mastery kills but cannot be triggered by its own splash.
- Attack-speed effects obey the existing minimum cooldown and Pip passive ownership rules.
- Mastery-created fixtures and echoes count toward existing projectile and world-object budgets.
- A mastery capstone may not be offered again as a temporary power-up.

## Persistence model

Dedicated Drift tables are preferable to adding dozens of settings keys.

### `survival_family_mastery`

- `family_id` text primary key
- `purchased_node_ids_json` text
- `selected_path_id` text nullable
- `updated_at_utc_ms` integer

### Legacy `survival_family_loadouts`

The former per-creature table remains readable for save compatibility. Migration promotes the most recently changed valid creature selection to the shared family row; new writes no longer use per-creature loadouts.

The service validates all data against the catalog. Unknown node IDs are ignored. An equipped path is legal only when its first node is purchased. Removing or renaming a node must not delete unrelated purchases.

At run startup, the persistence records become an immutable `SurvivalFamilyMasterySnapshot` keyed by party slot. Combat never reads the database.

## Runtime architecture

Recommended catalog and state types:

- `FamilyMasteryTreeDef`
- `FamilyMasteryPathDef`
- `FamilyMasteryNodeDef`
- `MasteryModifierDef`
- `EquippedFamilyPath`
- `SurvivalFamilyMasterySnapshot`

Reusable modifiers cover projectile allocation, angle, width, speed, return, orbit, pierce, ricochet, homing, cast counters, marks, payloads, zones, shields, and special bridges. Bespoke capstones use stable handler IDs rather than scattered species checks.

Runtime hooks:

- `transformBasicAttack`
- `onBasicCast`
- `onBasicHit`
- `onBasicKill`
- `beforeSpecialCast`
- `afterSpecialCast`
- `onSpecialResolved`
- `onCompanionDamaged`
- `tick`

Events carry slot, instance, species, family, element, derived stats, cast ID, and recursion-safe event ID.

## Player experience

- Add a **MASTERY** tab to Base Command.
- Selecting a family shows a connected three-branch node tree rooted in its base autoattack.
- The selected branch is clearly highlighted and applies to every creature in that family.
- Purchased, purchasable, equipped, and locked nodes have distinct states.
- Survival party slots display the family's selected path and capstone.
- The pause screen separates permanent mastery from temporary power-ups.
- A training preview shows baseline and mastered attacks against one target and a small group.
- `SELECT BRANCH` and `RESET` are free.

### Mastery tab layout (implemented)

The tab reads as a growing power tree with a tower-defense upgrade dock (`family_mastery_panel.dart`):

- **Family selector** — eight creature-portrait medallions, each ringed by its 0–12 purchase progress.
- **Tree** — reads top-down like an upgrade track and is split in two. The **crown** is docked under the family selector and never scrolls. It holds the family portrait as the root, flanked by the family title, 0–12 progress, ALL <FAMILY>S, and the base-attack chassis. Beneath the portrait the trunk splits into three boughs, which run behind the branch banners (name, tier pips, ACTIVE / EQUIP / LOCKED; tapping anywhere on a banner equips an owned branch). The **body** scrolls beneath the crown: the boughs continue down through three hex gem sockets to a gold eight-point capstone. Owned tiers fill the boughs with sap that flows downward, and the next purchasable segment is dotted. The equipped branch is lit and the others are dimmed. The body is always at least 80 px taller than its viewport, so it can always scroll the header back.
- **Base Command chrome** — Mastery is the first tab. Scrolling a tab down slides the header, tab bar, and (on Mastery) the family selector away, and drops in a slim BASE COMMAND silver/gold bar; they only return once the content is back at the top (or on a tab switch).
- **Nodes** — every node has its own glyph (`kFamilyMasteryNodeIcons`, pinned by a test), a price tag or tier tag, and owned/locked badges. The focused node gets corner selection brackets.
- **Upgrade dock** — pinned at the bottom: gem, branch and role, node name, I/II/III/★ tier track, description, EQUIP BRANCH / ACTIVE, and a large UPGRADE button with the price. Buying takes two taps (UPGRADE → TAP TO CONFIRM, which disarms after 3 s or when focus moves); the button also shows NEED, REQUIRES <previous node>, and UNLOCKED states. After a purchase, a one-shot flourish plays, sap flows into the new segment, and the dock advances to the next tier.
- **Performance** — the tree is one static `CustomPaint` behind a `RepaintBoundary`. Nothing loops, and glows are layered translucent strokes; a test forbids blur in the file.
- `test/family_mastery_panel_preview_test.dart` (tag `preview`, `MASTERY_OUT=<dir>`) renders the tab to PNGs with real fonts for visual review.

## Balance targets

- A complete path should improve total contribution by roughly 20–35% in its intended scenario.
- No path should outperform both alternatives in single-target, crowd, and utility scenarios.
- Unconditional shape changes remain near 95–110% baseline single-target DPS.
- Conditional payoffs may reach 120–140% when executed correctly.
- Capstones change rhythm or geometry rather than simply adding a large passive multiplier.
- Control, healing, shielding, and special amplification are valued in the same contribution report as damage.
- No node may create recursive projectiles, permanent special loops, unbounded summons, or uncapped cooldown refunds.

Telemetry should separately attribute basic damage, mastery damage, special damage, healing, shielding, control uptime, payload applications, special amplification, and capstone activations.

## Implementation plan

### Phase 1: catalog, economy, and persistence — done

1. Add the eight family tree definitions and validation rules.
2. Add Drift tables, migration, DAO, and service.
3. Implement atomic silver and gold purchases with sequential prerequisites.
4. Implement one selected path per family, free reset, and immutable run snapshots.
5. Test affordability, duplicate purchase prevention, invalid saves, renamed nodes, and multiple family members sharing one selected path.

### Phase 2: combat event foundation — done 2026-09-16

1. ~~Give every basic cast and projectile stable source and cast IDs.~~
2. ~~Add cast, hit, kill, special, and damage event hooks.~~
3. ~~Implement recursion guards, per-cast accounting, proc cooldowns, and object budgets.~~
4. ~~Add the shared elemental payload resolver.~~
5. ~~Add combat attribution telemetry.~~

See *Combat runtime* below for what shipped and where it lives.

### Phase 3: Mane vertical slice — in progress

1. ~~Implement all three Mane paths and capstones.~~ Done 2026-09-16; see *Mane implementation notes*.
2. ~~Validate them with Fire, Ice, Lightning, Blood, and one control-heavy element.~~ Done 2026-09-16 (Mud as the control element); see *Mane element validation*.
3. Build the initial Mastery screen and training preview around Mane.
4. Tune single-target, crowd, and special-bridge scenarios.

Exit criterion: the five tested Mane elements feel meaningfully different while sharing one selected path, and a second Mane in the party inherits that path and its bonuses without bespoke species code. (The original wording asked for two Manes on *distinct* paths, which the family-wide rules above forbid; it predates that change.)

### Phase 4: projectile families

Implement and tune Let, Pip, Wing, and Mask. These exercise impact, multishot, beam, piercing, fixture, and ricochet systems.

### Phase 5: exceptional families

Implement Horn, Kin, and Mystic after the shared runtime is stable. These require charge, passive-only special, support, and persistent-world adapters.

### Phase 6: complete interface and rollout

1. ~~Polish the Base Command tree and family selector.~~ Done 2026-09-16; see *Mastery tab layout*.
2. Add run-lock messaging, party badges, and pause summaries. (Not a Rhythm
   counter — see *Decisions intentionally made*.)
3. Add VFX and sound distinctions for all capstones and payload forms.
4. Run full survival simulations and regression tests.
5. Ship family trees in batches if balance or art production requires it.

## Combat runtime

Built in Phase 2. Nodes are written against this surface and nothing else; a
node that reaches into the combat loop directly is a node that will be missed
when the shared rules are audited.

| Piece | Where |
| --- | --- |
| Cast identity, accounting, guards, budget, telemetry | `lib/games/cosmic_survival/survival_mastery_runtime.dart` |
| The seventeen-element payload table | `lib/games/cosmic_survival/survival_mastery_payload.dart` |
| Payload application, event dispatch | `cosmic_survival_game.dart`, "Family Mastery combat events" |
| Per-body statuses the payloads write | `MasteryPayloadStatuses` in `cosmic_survival_spawner.dart` |
| Run snapshot lock | `FamilyMasteryService.snapshotForParty`, called once in `_startGame` |

### Cast identity

`SurvivalMasteryRuntime.beginCast` opens a cast and returns an id; the game
stamps it onto every projectile that cast produces (`Projectile.masteryCastId`).
One scheduled attack is one cast however many projectiles it throws, so a Mane
pair, a Pip volley and a Wing pair each count once. Specials are re-stamped
after the per-family rewrites, because several families rebuild their
projectile list from a seed rather than editing it.

Two deliberate exceptions:

- **Kin's charged beam opens a cast** with one projectile. It is the family's
  autoattack, and a body the line touches has taken everything that cast had.
- **Wing's sustained beams do not.** They are attributed to the special, but a
  six-second stream of ticks tied to one cast id would read as "the volley
  fully landed" for as long as the beam burned.

Cast id 0 means "no cast", so every stamping site can stamp unconditionally.
When no party member has a path equipped the runtime is inert and hands out 0,
which is what keeps the system free for players who own nothing.

### What a node may ask

- `hasNode(slot, nodeId)` / `hasPath(slot, pathId)` — is this purchased and equipped.
- `MasteryHit` — `isDualHit`, `isFullVolleyHit`, `hitIndexOnTarget`, `fromBasic`.
- `MasteryKill` — which cast killed, and whether the body was a boss.
- `claimPayloadTarget(castId, targetId)` — the "once per target per cast" rule.
- `tryProc(slot, effectId, seconds, targetId:)` — the only rate limiter nodes use.
- `requestObjects(count)` — the only way to spawn. Refused means skip, never queue.
- `runGuarded(...)` — mastery work that must not nest.

Node reactions attach at `_onMasteryHit` and `_onMasteryKill`, which are
deliberately empty until Phase 3.

### Payloads

`triggerElementalPayload` is the only way a payload may be applied. A node
supplies the slot, an effect id, a target, a strength and an optional cooldown;
the element table supplies the behaviour. The resolver is pure and returns
`PayloadAction` descriptors that the game's two appliers — one for bodies, one
for bosses — turn into survival's own status fields. A payload runs inside the
recursion guard, so a payload that kills can never trigger another payload.

Against bosses, control durations are scaled by `kBossControlScale` and the
forms a boss cannot take become the table's stated substitutes: every control
becomes a chill on boss movement, Earth's stagger becomes a slow, and pushes,
pulls and interrupts do nothing rather than fighting the discipline AIs.
Payload *damage* is never reduced.

### Telemetry

`MasterySlotTelemetry` separates basic, special and mastery damage, healing,
shielding, control seconds, payload applications, special amplifications and
capstone activations, per slot. `masteryShare` is the headline: how much of a
companion's damage its path is actually responsible for. Cast counts are
recorded even with the runtime disabled, so a no-mastery run is still a usable
balance baseline.

## Mane implementation notes

All eight nodes live in `lib/games/cosmic_survival/survival_mastery_mane.dart`
(numbers, per-slot state, and the pure rules: Encore's spend, Hunter's Arc's
cone, turn and ring lean) and in the game's "Mane mastery" section (the hooks
that spawn and apply). The split is the one phases 4 and 5 should copy:
anything that can be decided without the world lives in the family file, so
it can be read and tested on its own.

Things worth knowing (revised 2026-10-29, when Twin Fang and Crescendo went):

- **The pair is edited, not rebuilt.** Encore's width is the only thing a path
  changes about the slashes, so `_applyManeBasicMastery` scales the chassis's
  own pair in place. It used to rebuild the pair, because Predator Step's
  tracking is final on a projectile; the rebuilt slashes lost the chassis's
  render tag (`basicFamily`) on the way.
- **Hunter's Arc is per projectile.** `Projectile.masteryArc` is stamped by
  the special-shape pass after every per-element rewrite, so Spirit's stream
  and Lightning's orbs carry it; the ward ring and Mud's shards are stamped
  where they are made. `_steerManeArc` runs in the projectile update before the
  shot moves, arms on `pierceCount`/`hitBoss` (or `masteryArcArmed`), re-picks
  its body from the enemy grid every 0.15 s and turns by at most
  `maneArcTurn`. A ring's lean is `masteryArcReach`, added to its orbit radius
  where the orbit is resolved; the circuit resets it.
- **Damage after a bend stays the special's.** The arc changes where a shot
  goes, not what it deals, and a hit after a slight bend is not one the shot
  would otherwise have missed, so none of it is filed as mastery. Crosscut's
  bonus and the Tempest Ring are what War Rhythm files as mastery.

Two rules needed runtime support that phases 4-5 will reuse: `MasteryCast.tag`
for "this cast was empowered", and `maxHitsPerTarget` with a pre-damage veto
in the hit loop, because Tempest Ring's three-hit cap counted after the fact
would not be a cap.

## Mane element validation

Measured over twenty seconds against a standing crowd, all three paths, the
five elements the phase calls for. The differentiation the exit criterion asks
for is real: Fire burns one body, Ice stacks toward a freeze, Lightning does
all of its work on a *different* body, Mud slows hard, Blood pays the caster.
`test/survival_mastery_mane_elements_test.dart` fails if any two of them ever
become the same thing.

Two findings worth carrying forward.

### Telemetry could not see two of the three paths

War Rhythm and half of Twin Fang do their work *inside* a basic hit — Rhythm's
damage per stack, Predator Step's kill bonus, Honed Pair's sharper blades. All
of that was landing in the basic bucket, so both paths reported a mastery share
near zero while visibly doing something. A cast now carries the share of its
damage the path is responsible for, and that portion is attributed to mastery.
War Rhythm went from 0-1.7% to 9.8-11.7%, which is a number balance can argue
with.

A path that *trades damage away* for reach (Sweeping Claws) is owed nothing
here on purpose; its payoff is counted in payloads and control.

### Mane's catapult billed a standing body once a frame

A piercing projectile is not consumed by a hit and contact is re-tested every
frame, so a slow one parked inside an enemy charged for every frame it
overlapped. Measured against a single standing body: Ice landed 21 hits for
3,777 damage and Blood 27 for 3,135, while the same family's Fire shots passed
through for almost nothing. A special's real output was set by how slowly its
projectile happened to travel.

Mane specials now carry `maxHitsPerEnemy = 2` (`kManeSpecialMaxHitsPerEnemy`),
enforced before damage in the survival hit loop. Two rather than one so a body
wide enough to stay in the shot's path takes a second hit — a catapult rolling
through a brute should land twice. Piercing a line of enemies is untouched,
because the ceiling is per body rather than per projectile.

The same per-frame billing applies to every other family's piercing abilities.
Only Mane is capped so far.

### Blood cannot feed a path built on spreading an element

Blood's payload is a 1%-maximum-HP self-heal capped at once per second. That is
the table working as specified, but it means a Blood Mane on Tempest Claw — the
path whose whole role is "spread your element across groups" — spread nothing:
15 payload applications over twenty seconds against Fire's 51, and 23 points of
healing to show for it. Every node that fires more than once a second is
throttled to the element's cooldown.

This is a gap in the payload table, not in the nodes, and it will repeat for
every fast-triggering node in phases 4 and 5. Options, none of them taken yet:

- Leave it, and accept that Blood is a sustain element that ignores throughput.
- Make Blood a leech — damage that heals for a fraction — so a payload always
  does something and the *heal* keeps its cap.
- Scale the heal down and remove the cooldown, so throughput pays.

### Per-family ability stats

Every special used to be paid for out of Beauty, and on Mane that made Beauty
multiply itself: it set the fireball count *and* the damage of each fireball,
so Fire scaled 24x across the stat band while Ice scaled 4.7x. A stat that
pays twice is a stat that has no competition.

Mane's contract splits the jobs. `CosmicSurvivalCompanionStats.abilityAtk` is
a per-family blend — Mane is 80% Strength, 20% Intelligence — and the special
is cast from that instead of from elemental attack. Beauty keeps the other
half: how much of the ability there is.

| Stat | Job on a Mane |
| --- | --- |
| Strength (80%) + Intelligence (20%) | how hard the catapult hits |
| Beauty | how much of it there is, and how it looks |
| Intelligence | range, spread, ability duration |
| Speed | attack cooldown, movement |

Beauty buys exactly one thing per element, never two:

- **Fire and Lightning** — the count (4/8/16 and 5/7/12).
- **Light** — orbs. Its open-world ball must stay singular and tiny, because
  the board has it growing per pierce and a large start leaves the ramp
  nothing to climb (a test guards this). In survival Light is the *ward*, and
  there the amount is how many rings turn: two, three or four by Beauty. Each
  ring is still born small and still earns its size by being fed, so a fourth
  ring is more ward rather than a shortcut past the growth.
- **Everything else** — width. A wider ball catches more bodies down a line
  and stays in contact longer, which is more total damage without Beauty ever
  touching a damage number.

Measured, one cast into six standing bodies:

| Build (Ice) | Projectiles | Radius | Damage |
| --- | ---: | ---: | ---: |
| All average | 1 | 5.52 | 739 |
| Strength 9 | 1 | 5.52 | 1,527 |
| Beauty 9 | 1 | 8.00 | 907 |

Strength doubles the damage and changes nothing else; Beauty widens the shot
by 45% and gains a fifth of the damage through reach. They are different
builds rather than the same build at different speeds.

The other seven families still fall back to elemental attack, which is what
every special did before. Each should get its own contract when its tree is
built — a Wing beam is not paid for out of the same stat as a Horn ram, and
they should not feel as though they are.

### Speed had no top end

`companionCooldownReduction` ran on the legacy 1-5 band and clamped at 1.20,
which it reached at a Speed of **9** — so every point past 9 was worth
literally nothing, and the whole stretch from an average creature to a perfect
one bought 13% more attacks. Strength bought 90% more damage across the same
stretch. It is now anchored on the real band like everything else: 0.92 at
low, 1.06 at average (both unchanged, so ordinary creatures are untouched) and
1.55 at perfect, which is +46% attack rate over an average creature.

Nothing about cadence is capped. Past the perfect anchor the curve keeps
paying on a logarithmic tail rather than clamping, because Enhancement ranks
push a stat well past 12 and a clamp there would make those points worth
exactly nothing — the same bug one ceiling higher. It cannot run away either:
a stat of 30 is worth about a fifth more than a stat of 12, not three times
more. Counts still stop, because half a fireball is not a thing.

One related oddity, not changed: `effectiveBasicCooldown` also divides by a
physical-attack factor that clamps at 3.0, which every creature above roughly
a 3 in Strength already exceeds. So Strength quietly buys attack speed at the
very bottom of the range and nothing at all above it. Harmless today, but it
is a saturated term masquerading as a stat contribution.

That fixed the broken part. It did not make Speed a damage stat. Trading
Strength for Speed point for point, five seeds averaged, twenty seconds
against eight bodies:

| Strength / Speed | Total damage |
| --- | ---: |
| 14 / 0 | 11,072 |
| 11 / 3 | 9,821 |
| 9 / 5 | 8,353 |
| 7 / 7 | 8,666 |
| 5 / 9 | 7,837 |
| 3 / 11 | 4,389 |

Every point moved off Strength loses damage, because Strength supplies output
and Speed only multiplies it — and its multiplier (+46%) is smaller than
Strength's (+90%). To make Speed damage-competitive its perfect anchor would
need to be near 2.0 rather than 1.55.

Whether it *should* be is open. This scenario gives movement a value of zero,
and movement is Speed's other half: in a real run it is how a companion stays
alive and stays in range, and a dead companion deals no damage at all. A third
option is to give Speed a job the other stats do not have — weighting its
reduction toward *special* cooldowns, which would pair it with the mastery
capstones that trigger on a cast (Crescendo, Blade Dance) instead of competing
with Strength head-on.

### 95 is where the last step lands; 100 is still strongest

Two different things scale off a stat and they must not be conflated.

**Countable things** — a fireball, a ward ring — can only change in whole
steps, and the last step should land somewhere a player can actually reach.
The internal stat blends species base with potential, so a median species bred
to 100 sits near 8.6 and never touches the anchor a top species hits at 11.75;
left alone, the final fireball would exist only for a handful of species.
`scaledAbilityCount` therefore awards its top count at
`kAbilityFinalStepPotential` (95) regardless of species.

**Continuous things** — damage, cadence, size — keep climbing the whole way,
so 100 is strictly stronger than 95 and Enhancement is stronger still.

A median-species Mane across the last stretch of breeding:

| Potential | Beauty | Fireballs | Ward rings | Ice ball radius | Cadence |
| --- | ---: | ---: | ---: | ---: | ---: |
| 50 | 4.31 | 8 | 3 | 5.61 | 1.035 |
| 90 | 7.25 | 11 | 3 | 7.59 | 1.210 |
| 95 | 7.93 | **16** | **4** | 7.77 | 1.249 |
| 100 | 8.63 | 16 | 4 | **7.92** | **1.289** |

The counts finish at 95 and hold; everything else still rewards the last five
points.

### Abilities scale across the band the player actually plays

The old count scaler moved a total of 0.72x to 1.34x — not something a player
can see, let alone chase. `scaledAbilityCount` replaces it with three anchors
on the real fielded range (`kAbilityStatLow` 2.5, `kAbilityStatAverage` 4.25,
`kAbilityStatPerfect` 12.0), which are what
`speciesBase / 20 * potentialMultiplier(potential)` actually produces at level
10 for a weak creature, a median one at potential 50, and a top species at
potential 100. Enhancement pushes past perfect, so the curve clamps.

Every family scales off whichever stat its ability is about and picks its own
three numbers. Two families sharing one curve is one family with two names.
Mane's:

| Ability | Stat | Low | Average | Perfect |
| --- | --- | ---: | ---: | ---: |
| Fire fireballs | Beauty | 4 | 8 | 16 |
| Lightning orbs | Beauty | 5 | 7 | 12 |

Fire is the steep one because the count *is* the ability; Lightning places
rods that cover ground, so a field of twenty would be a carpet rather than a
reward.

Measured against six standing bodies, one cast:

| | Low (B 2.6) | Average (B 4.31) | Perfect (B 11.75) |
| --- | ---: | ---: | ---: |
| Fire | 140 | 823 | 3,388 |
| Ice | 375 | 754 | 1,774 |

At average stats the two are now within 10% of each other, where they used to
sit 12x apart. Note that Fire's curve is far steeper — 24x low-to-perfect
against Ice's 4.7x — because a scaling count compounds with the elemental
attack that already scales. That is a deliberate consequence of making the
count the ability, but it is the number to watch if perfect-stat Fire Manes
start outclassing everything.

### What is authored difference, not imbalance

Mane's element specials differ by design, and a single-target damage
comparison between them is not apples to apples. The family contract is one
big slow piercing shot whose element decides what happens as it pierces, with
two deliberate exceptions the design board writes in the plural: Fire's 3-8
fast fireballs and Lightning's 5-10 orbs placed around the map. Ice's single
wide, slow projectile is the chassis working, not a bug.

Two consequences are worth knowing before tuning any Mane node:

- **Mane+Lightning contributes almost no measurable damage** in a fight around
  the caster. Its orbs scatter 170-730 units from the *ship*, so against
  enemies clustered on the companion they mostly land nowhere. That is what
  the board asks for; whether it survives contact with a real wave is a
  separate question.
- **Mane+Fire's fireballs fan wide enough to miss a lone target.** Traced at
  150 units, all four passed either side of a standing body.

Both mean the *special* half of a Fire or Lightning Mane's output is near
zero, which is why their mastery share reads high while Ice's and Blood's
reads low. The share is measuring the denominator, not the path.

## Is a path worth buying

Measured against the same creature owning nothing, five seeds averaged, twenty
seconds against eight standing bodies. The target is 20-35% for a complete
path.

| Path | Fire | Mud |
| --- | ---: | ---: |
| Twin Fang | +23% | +8% |
| Tempest Claw | +13% | +9% |
| War Rhythm | +37% | +43% |

Twin Fang and War Rhythm are worth their silver; War Rhythm is above target on
both and is currently the obvious pick.

Two things this does not resolve:

- **Tempest Claw's middle nodes measure as nothing.** Rending Wake and
  Crosswind moved the total by 1-2% on both elements; the capstone carries the
  whole path. Part of that is the scenario — a control path measured against
  stationary bodies gets no credit for control — and part of it is real: on
  Fire, Rending Wake fires a payload every cast into a burn that cannot stack,
  so most applications only refresh one that was already running.
- **Five seeds cannot resolve differences under about 10%.** The Mud column
  bounced between +9% and +15% across runs of the same build. Treat these as
  directional.

## Developer tools unlock the whole tree

With the developer switch on in the profile screen, every node of every family
reads as owned. It is a read-time override in `FamilyMasteryService` and writes
nothing, so turning the switch off hands the account back exactly what it paid
for rather than leaving it permanently rich.

Unlocking is not equipping. A path still has to be chosen, and still only one
at a time — testing the trees means switching between them, which is the thing
the override is for.

## Per-family stat contracts

Three separate contracts, each answering a different question.

**What pays for the ability** — `cosmicFamilyAbilityStatWeights`. All eight
families declare weights across Strength, Intelligence and Beauty. Speed is
deliberately absent: it improves cadence, never secretly damage.

**How often the special comes back** — `cosmicFamilySpecialCooldownWeights`.
Basic attacks remain Speed's alone, for every family, because that is the
stat's plain promise. A special is a different question and the answer should
differ by family:

| Family | Speed | Intelligence | Strength | Why |
| --- | ---: | ---: | ---: | --- |
| Horn | 0.70 | — | 0.30 | Bracing and turning a heavy body is physical recovery |
| Mane | 0.60 | 0.40 | — | A skirmisher's blade work, mostly reflex |
| Pip | 0.50 | 0.50 | — | Reflex and calculation, evenly |
| Wing | 0.40 | 0.60 | — | A beam is aimed before it is fired |
| Let | 0.30 | 0.70 | — | Artillery reloads on ranging, not on twitch |
| Mask | 0.25 | 0.75 | — | Placing a trap well is reading the field |
| Kin | 0.20 | 0.80 | — | Support is knowing when, far more than being quick |
| Mystic | 0.15 | 0.85 | — | A world is willed into being |

Mask previously ignored stats entirely: a flat 22.5 seconds meant Intelligence,
its own cadence stat, changed nothing about how often it laid a trap. It
divides by the contract now like everyone else.

**How much of the ability there is** — Beauty, per family, on the anchored
curve. This is the half that was missing everywhere but Mane. The old generic
scalers spanned roughly 0.75x to 1.30x across the *entire* stat band, which is
not something a player can see, let alone chase.

Every family answers Beauty now, and each answers in its own currency.

| Family | What Beauty buys | Weak | Average | Perfect |
| --- | --- | ---: | ---: | ---: |
| Mane | fireballs / ball width | 4 | 8 | 16 |
| Pip | ricochets | 3 | 5 | 8 |
| Let | blast radius | 5.18 | 7.00 | 11.55 |
| Mask | traps placed | 5 | 9 | 15 |
| Mystic | world radius | 0.70x | 1.00x | 1.85x |
| Wing | beam width | 0.72x | 1.00x | 1.70x |
| Horn | guard and sweep radius | 0.74x | 1.00x | 1.65x |
| Kin | aura radius | 0.80x | 1.00x | 1.48x |
| Pip | dart width | 0.86x | 1.00x | 1.28x |
| Mane | ball width | 0.88x | 1.00x | 1.25x |

Pip's ricochets used to read *Intelligence* through a 0.74x–1.26x scaler — the
thing the family is for, on the wrong stat and on a curve nobody could feel.

The swings are deliberately unequal. Mystic has the widest because a world's
edge is the entire cast. Pip and Mane have the narrowest because Beauty already
buys them ricochets and fireballs, and one stat should not pay twice for the
same volley.

Three of these were not slow curves but missing wiring, found by writing the
test before trusting the code:

- **Kin's aura did not scale at all.** `effectRadius` and `effectDuration` were
  never touched by the family's scaling pass, so the radius of the thing the
  entire support family is built around was the same for a perfect Kin as for a
  terrible one. Beauty sets its reach now and Intelligence its duration.
- **Wing's beam width rode `powerScale`**, which also multiplies beam damage —
  so widening it would have handed Beauty a damage lever that belongs to
  Strength and Intelligence. Width has its own anchored curve now.
- **Wing's `effectRadius` fell back to a bare `82.0`** whenever an element
  authored none, and that literal was multiplied by nothing.

Mask keeps Intelligence on how far each trap reads and how long it holds; only
the *number* of traps moved to Beauty. That number is discrete, so it takes its
last step at P95 like every other count, and the stat points above it buy reach
instead.

`_footprint` in `test/family_ability_stat_contract_test.dart` measures widest
reach times placements, which is the only metric that compares a family that
widens one beam against a family that scatters more traps. It also had to learn
that Kin and Mystic author most of their specials survival-side and put nothing
in the shared table — Kin/Fire produces no projectile at all.

Two balance tests moved with this, both for the same reason: the neutral point
of a scaler is now the real average stat (4.25) rather than the 4.0 the old flat
scalers baselined on. A Wing test read an authored width against a caster
slightly below average and found it 4% short; a Mane test compared Beauty 2 to
Beauty 5, which sit either side of average on a 2.5–12 scale, and asked for a
20% radius gap that Mane's deliberately narrow curve no longer owes between two
ordinary creatures.

### Horn — Bulwark, Bastion (2026-09-18; Juggernaut cut 2026-10-29)

Horn's draft tree spent six of its twelve nodes on mechanics its own elements
already owned, and its third path was Mane's War Rhythm down to the numbers.
The audit, kept because the same trap is waiting in the four families left:

| Draft node | Already owned by |
| --- | --- |
| Hold the Line, Countercharge (knockback) | Air, whose *entire passive* is pushing enemies; Steam's payload also pushes |
| Interposition (block enemy shots) | Crystal's shards, Ice's wall, Light's barrier — three elements |
| Sunder (+damage taken) | Dark's `vulnerable` |
| Point Blank (stagger) | Earth's `stagger` |
| Stampede (5 stacks, +2% each, spent on the special) | Mane's War Rhythm, identically |

It also kept promising things to "your next charge", and **Horn is the family
whose cast pattern changes with its element**: Air and Mud never cast at all,
and Light never moves. `Unstoppable` was dead content for three of seventeen
Horns, and `Impact Reserve` carried a bolt-on clause conceding it.

So the replacement paths key only to what every Horn has — a body with hit
points, an auto-attack, and an element:

- **Bulwark** turns maximum HP into damage. Nothing else in the game scales a
  companion's damage off its own bulk.
- **Bastion** takes hits meant for the orb, mitigated by that bulk, so the team
  comes out ahead rather than the damage merely moving. Nothing else in the
  game redirects damage onto a companion.

A third, **Juggernaut**, ran the special a second time (a charge ploughed
back, a wind-up released twice, Light's barrier re-upped, a passive Horn
pulsed). It was cut on 2026-10-29, when every family went to two paths.

Two things worth keeping from the implementation:

- **The weight goes into the charge once, at cast**, not per contact. A charge
  that ploughs through six bodies would otherwise add a Horn's whole bulk six
  times, which is how a tank path quietly becomes the best damage path.
- **`hornSpecialActiveWindow` is useless as a completion signal.** It is a flat
  five seconds and Horn's own special cooldown is about four, so a Horn that
  keeps casting re-opens it forever and it never closes. Anything that needs
  to know a Horn's ability has finished should read `chargeTimer`,
  `windUpTimer` and the Light barrier instead (Juggernaut did).


### Mask — Deathmask, Contagion (2026-09-18; Rearm cut 2026-10-29)

Mask's draft was more derivative than Horn's. Every collision below was
checked against the code, not assumed:

| Draft node | Already owned by |
| --- | --- |
| Chosen Victim (*Mark*), Inscribed Dart (*Sigil*) | Pip banks Pins, Let marks Sighted — claimed twice over |
| Phantom Lance (every 4th), Grand Masquerade (every 3rd) | `cometCadence 5`, `thousandCutsCadence 4`, `scatterStormCadence 5`, `tempestRingCadence 4` |
| Binding Script (slow) | Mask/Mud's own trap is the slow pool |
| Haunted Ground (trap shoots darts) | Mask/Steam's own traps are the shooting geysers |
| False Face (lure enemies) | Kin's aggro shift; Horn taunts on Fire, Ice, Earth and Spirit |
| Applause (+attack speed) | Mane's Rhythm and Encore |

Its whole first path was "pierce lines", which is **Mane's** identity. Mask's
dart happens to pierce, but a path built on that just makes Mask a worse Mane.

Mask has Horn's structural problem in a different shape. **Placement counts
swing wildly by element**: Air scatters 3 to 25, Lava and Fire 5 to 15, Crystal
3 to 7, Earth 2 to 5 — but Light, Dark, Ice, Lightning, Blood, Plant and Mud
each place exactly one. Any path keyed to "your many traps" is dead content for
seven of seventeen, so nothing in the tree counts fixtures. There is a test
for that.

What every Mask does have is at least one fixture that persists and waits, so
the tree is the two ends of one trap's life — how it gets placed, and what
happens after:

- **Deathmask** puts traps down on kills, and (Restless Graves) sends them
  after what stands still, or into the thick of the crowd.
- **Contagion** makes what a trap catches carry it onward. Enemy-to-enemy
  spread was the one genuinely unclaimed mechanic left: a grep for
  `contagion`, `spreadTo` and `infect` returned nothing.

A third, **Rearm**, stopped a trap spending itself on contact. It was cut on
2026-10-29, when every family went to two paths.

**2026-10-29, second pass: Restless Graves, three ways, none of them a lift.**
Measured as tier 2 against tier 1 (`FAMILY_MASTERY_TIER`, 420 parties, P50
wave 36; Mask share / held), where tier 1 (Grave Goods alone) is 34% / 68%
and no mastery 26% / 58%:

| Restless Graves | Share | Held |
| --- | --- | --- |
| creep at 18 after the nearest body (as shipped) | 34% | 68% |
| 75 after the nearest body, riding it once caught | 34% | 68% |
| 75 to the thickest crowd near it | 36% | 70% |
| 75 to the nearest body standing still, else the thickest crowd (kept) | 36% | 68% |

A grave is a contact trap at 35% of the special's fixture. Riding one body
it is walked into by fewer than lying in the stream; in the thick of the
crowd or under a planted brute it catches more (two points of share) but
nothing that changes whether the orb holds — at P50 wave 36 that is decided
by brutes' siege beams (see Wing, below), and a third-strength trap under a
brute does not bring it down before it fires again. Tier 2 does not beat
tier 1 by more than the probe's noise in any version. The kept one is the
version that goes after the bodies that matter; the next lever is what a
grave *is* at tier 2 rather than where it goes. Full path: before 36% / 71%,
after 38% / 73%; P80 wave 41 before 29% / 90%, after 30% / 92%.

**Two ceilings exist because of a bug this game has already had.** A Mask trap
chain once doubled per frame until a single frame cost 2.2 seconds, and both of
these paths are that bug waiting to happen:

- A grave may only be left by an **auto-attack kill**, never by a trap's own
  kill — `MaskTuning.graveSourcesAreDartsOnly`. Dart kills are bounded by
  attack speed; a trap's kills are bounded by nothing.
- An infection may only jump `MaskTuning.maxGenerations` times from the trap
  that seeded it, so a dense crowd cannot keep re-infecting itself long after
  the traps are gone.

Plus a flat cap of twelve live graves per Mask and a proc cooldown on placing
them. All four are pinned by tests, in the group named for the failure.


### Wing — Longshot and Tracer (2026-09-18, reworked 2026-10-29)

**2026-10-29: two paths, and every node changes how the Wing fights.** The
user cut every family to two paths and asked that no node be a plain number.
Burn Through went whole: its ramp was a number that climbed, and it moved a
horde wave by a point (`docs/audits/survival_families_2026-10-20.md`, "Mastery
sweep"). In the two that stayed:

- **Long Lens** stopped climbing the bonus to +35% at the edge and now aims:
  an auto-attack at a body past 60% of range is fired at where the body will
  be (`wingLeadPoint`, read in `_wingShotAngle`). Wing's shots do not home, so
  a far body walking across the line used to be missed.
- **Overwatch** replaced Horizon (another +35% range): every body that comes
  into the far band takes one free auto-attack (`_updateWingMastery` →
  `_watchWingFarReach`). It looks ten times a second over the grid cells the
  band covers (`_visitEnemiesNear`'s `innerRadius` skips the cells wholly
  inside 60%), keeps a per-Wing set of the bodies it has shot (dropped as
  they die, `_forgetWingOverwatch`), and fires out of a bank of six refilled
  at twelve a second, so a wave arriving at once is shot down in turn rather
  than in one frame. The shot is the Wing's own attack, filed as the path's.
- **Loaded Beam** is Ranging Shots renamed (Let's Bombardment has a Ranging
  Shots), keeping the saved id `wing.tracer.ranging_shots` through `_path`'s
  `slugs`.
- **Hot Barrel** stopped growing Tracer's numbers and now doubles the
  auto-attack rate while the Wing's beam is firing
  (`wingBasicCooldownMultiplier`, read in `_masteryBasicCooldownMultiplier`).
  With Tracer Rounds that is a loop — faster shots shave the special faster —
  which is what the path is for; Tracer Rounds and Loaded Beam keep their
  0.25 s and 0.1 s.

Measured with `test/family_balance_survival_test.dart`
(`FAMILY_MASTERY_ONLY=1`, 105 parties; share of party damage, then how
often a party with a Wing held), against no mastery at 27%/55% (P50 wave 36)
and 27%/88% (P80 wave 41): Tracer 40%/71% and 38%/99%; Longshot 35%/57% and
34%/91%, the path dealing 37-40% of the Wing's damage. Longshot's hold lift
is inside the probe's ±6 points: what it adds lands on bodies far out, which
the rest of the party was killing anyway. Overwatch fired six shots a second
at first (32%/56%, 31%/89%).

**2026-10-29, second pass: what breaks a party, and Overwatch on the
brutes.** Traced over 105 parties at P50 wave 36 with no mastery (a
temporary probe that filed every hit on the orb by its caller): **brutes'
siege beams are 55-70% of what the orb takes** (`_updateEnemyHazards`;
colossus shockwaves a sliver of it), ordinary contact 15-26%, enemy rounds
(sentinel volleys, shooters, artillery shells) 15-18%. A party of five
brutes fires about 114 beams a wave. Three in four were fired by a brute at
75% of its health or more, and from 300-560 out from the orb (the brute's
action reaches 560). The Wing works the outer edge (its family targeting is
"furthest from the orb"; it stood 634 from the orb on average, range 291):
four in five beams came from a brute further than 160% of the Wing's range
from it, three in five from one more than 750 away. So far-band shots fell
on bodies the party was killing anyway, and the bodies breaking the orb were
nowhere near the Wing.

Two levers were tried at 420 parties, P50 wave 36, Wing share / held (no
mastery 27% / 59%; Longshot as shipped 35% / 64%):

- Overwatch as a *target*: a body taking aim within twice the range became
  the Wing's first target, and in reach of its attack (no free shots). 33% /
  61%. The Wing left the far band to chase brutes it could not bring down
  before they fired (a brute has ~1,150 health at P50 wave 36; a Wing shot
  is ~70), and lost the free shots' work.
- Overwatch's free shots *also* at whatever takes aim within twice the
  range, every time it does (kept). 36% / 66%; at 840 parties
  36% / 67% against 28% / 57% with no mastery. P80 wave 41: no mastery 28% / 90%, before 35% / 94%,
  after 34% / 93%.

Nothing here takes another family's signature: the shots are the Wing's own
attack, the reach is range, and a body taking aim is read from the enemy's
own action phase, which no other node reads.

The 2026-09-18 reasoning below still holds for the two that stayed.

Wing's draft was Mane's tree with "shots" written over "slashes". Side by side:

| Wing draft | Mane, already shipped |
| --- | --- |
| "When both **shots** hit the same enemy, deal +25% and apply your element's effect." | "When both **slashes** hit the same enemy, deal +20% and apply your element's effect." |
| "Landing both shots on one enemy builds **Focus** (max 5)… each gives +2% attack range" | "Landing both slashes on one enemy builds **Rhythm** (max 5)… each gives +2% attack speed" |
| Synchronized Flight — shots fly closer, damage up | Honed Pair — slashes fly closer, damage up |

That was the third family whose draft resonance path was War Rhythm. It also
added two more every-Nth-attack nodes to the four the game already has, built
a path on piercing (Mane's identity), left a damaging lane on the ground
(Wing/Lava's own scar) and ended with an echo of the special after it
finishes, which is Horn's Juggernaut.

**Wing's real difficulty is that its own seventeen elements have claimed
nearly every beam behaviour.** Sweeping is Fire's, charging is Lightning's,
refracting is Light's, ground scars are Lava's, executing is Blood's,
lifesteal is Crystal's, freezing is Ice's. So the test a Wing path has to pass
is not "is this unclaimed" but **does it take an element's signature, or a
neutral property of a beam?** There is a test for exactly that.

Three neutral properties survived:

- **Burn Through** is dwell. `enemy.frostBuildup` already proves Wing
  accumulates on a held target — but only Ice uses it, and only to freeze. A
  damage ramp generalises the idea without touching Ice's signature, and the
  two accumulate side by side.
- **Longshot** is distance. Nothing in the game reads range, and a sniper that
  gets worse as enemies close is a real tactical identity rather than a
  number. Standoff reads the *nearest* body rather than the target, so the
  path pays for actually keeping away instead of merely aiming far.
- **Tracer** is the auto-attack, which both beam paths ignore completely. It
  is what makes the two halves of Wing's kit talk to each other.

One thing the wiring corrected: the capstone was going to be "you keep firing
while the beam is up", and Wing already does — the basic is not gated on an
active beam. It became Live Feed instead, which puts the time into the beam
already running rather than banking it for the next one.


### Kin — Conduction and Benediction (2026-09-18, reworked 2026-10-29)

**2026-10-29: two paths.** Longline went whole — a longer line and a bigger
number at its end, and still a support family turned damage dealer after the
2026-10-21 trims (7% of its party's damage to 19%). Benediction's first two
nodes were numbers (+40% duration, +25% strength) and became behaviours:

- **Kindred** (`_applyKinKindred`, from `_applyCompanionSpecialSupportEffects`):
  the ally standing nearest the Kin when it casts gets the cast's support as
  the Kin does. What every Kin's cast hands its caster is a heal (15-50% of
  its health by element) and a blessing (a heal over 3.5-8 s); that is what
  Kindred copies, whole and for as long (and a shield, should a cast carry
  one), with the orb echo paid once. Each element's own support
  already reaches past the Kin — the Steam boiler hastes every ally, the Dark
  veil hides every ally, the Blood pact and the Lava plate answer the whole
  team's damage, the Lightning charge chains everyone's attacks, the Light,
  Crystal, Water and Air pieces ride the ship, the Earth wall rings the orb,
  the Plant garden and Dust clouds are placed, Mud enchants the ship, the Ice
  release and Poison darts and Spirit wisp go at enemies — so the part that
  stopped at the Kin is the heal and blessing, and every casting element has
  both. Kin+Fire never casts: its support is the phoenix, so Kindred hands
  the ally nearest it when the phoenix fires the same rebirth haste and
  damage, for good (`_applyKinKindredRebirth`,
  `CosmicSurvivalCompanion.kindredRebirthDamageAmp`/`kindredRebirthHaste`).
- **Vigil** (`_kinVigilRate`): while any ally is below half health the Kin's
  special recharges twice as fast — on `specialCooldown`, in
  `_updateCompanion`. Kin+Fire has no cooldown to hurry, so its reborn flame
  burns twice as often instead (`_updateKinSupportTick`).
- **Communion** now leaves Kindred's ally the whole blessing and gives the
  rest of the team and the ship half.

Unbroken and Conduction are as they were. Measured the same way as Wing
above: a party with a Benediction Kin held 84% of P50 wave 36 against 52%
with no mastery (Kindred and Vigil alone 75%, with Unbroken 76%), and 96%
of P80 wave 41 against 89%; the Kin stays at 4-6% of the damage. The old
path, after the 2026-10-21 trims, held 76% and 100%. Communion's half share
is the lever if it should come down. The 2026-09-18 reasoning below still
holds for what stayed.

Kin's draft was the worst of the six. Its first path, "turn the laser into a
weapon", made the Rare Support family a damage dealer, which is the one thing
its own design board explicitly did not want; the `Burn Through` node shared a
name with a Wing path and `Critical Mass` *was* that Wing path. Its second
path marked enemies (Pip's Pins, Let's Sighted), applied `vulnerable` (Dark's),
left a damaging lane (Mask's and Wing/Lava's) and chained shocks between
enemies, which is **Kin/Lightning's own signature**. Its third was War Rhythm
for the fourth family running, with a shield-per-attack opener that is Horn's
Guarded Shot and an ally attack-speed buff that is **Kin/Steam's own boiler**.

Reading the implementation rather than the description is what produced the
replacement. Kin's *basic attack* charges for 1.5s **with movement locked to
zero**, then fires a line that hits every body near the segment at four times
a normal hit. No other family roots itself to throw a basic, and no other
family's basic is a line through space rather than a thing aimed at a target.
So the laser has exactly three levers, and the user's split was two on the
laser and one on the seventeen bespoke supports:

- **Longline** is reach — how far down the field the line runs, and Deep Line
  pays more at the far end so the length is worth buying rather than just
  looking longer. It is *not* Wing's Longshot: Wing reads the gap between the
  caster and its target, Kin reads the length of the line itself.
- **Conduction** is what the line carries. It already hits every enemy it
  crosses, so this makes it shield and heal every ally it crosses too.
- **Benediction** is the support itself: longer, stronger, surviving the
  caster, and finally reaching the whole team.

**Unbroken was dead code on the first attempt, and the test caught it.** A
companion that goes down is removed from `activeCompanions` outright, so a
guard inside that loop can never fire for a dead Kin — the node would have
been purchased and done nothing, which is the exact failure this whole audit
has been removing from the drafts. Orphaned supports are now held in
`_unbrokenKin` and walked by the support tick alongside the living, pruned as
their timers expire, and the three "is some Kin support up?" reads consult
them too.


### Mystic — Quickening and Firmament (2026-09-18, reworked 2026-10-29)

**2026-10-29: Quickening acts instead of multiplying.** It was three number
bumps (acts 25% more often, lands 30% harder, acts twice as often), all read
through the world surge (`_mysticWorldPower`). Reading the worlds again: only
Lightning, Earth and Steam keep a clock; the rest act on their own terms — an
ember catches, a revenant strikes, a vine lashes or spits, a patch bites, the
water and the wind grind, a crack drops meteors, a shard bursts as the ship
takes it, the maw swallows, the haze turns a round or a body, the dawn
breaks, the tithe is drawn, the mud weighs on a hit. So each world now marks
its act where it happens (`_mysticActed`) and hands over how to do it again,
at a strength, in the same place: the bolt on the same spot
(`_landMysticLightning`), the quake over the same field
(`_shakeMysticEarth`), the vent (`_ventMysticSteam`), the meteor on the same
ground (`_landMysticMeteor`), the shard's burst where it was taken
(`_burstMysticCrystal`), the lash down the same arc (`_lashMysticVine`), the
ember at the same point (`_catchMysticEmber`), and so on. The repeats queue
in `_mysticReplays` (at most 240 waiting) and land from
`_updateMysticMastery`; a repeat never queues another. Mud's act is the
weight on every hit the field takes, so its repeats are banked per body
(`_echoMysticMire`). **Ice was the one world with no act** — its blizzard
holds every body every frame — so Aftershock and Relentless Sky did nothing
for it (until the second pass, below).

- **Quickening**, first pass (`_quickenMysticWorld`, gone in the second
  pass below; from the kill in `_damageEnemy` and `damageBoss`): every body
  the world kills (anything its spent Mystic deals
  that is not an auto-attack) takes 0.2 s off the world's next act — the
  clock, each ember's catch, each revenant's strike, each vine, each patch,
  the water's and wind's grind, each crack's rearm — never below a third of a
  second (`mysticQuickenedTimer`), so no act comes round more than three
  times a second. Worlds that never kill (Blood, Dark, Mud, Ice, Steam,
  Light) and the two whose acts keep no clock (Crystal, Dust) have nothing
  for it to hurry.
- **Aftershock** replaced Weight of Heaven (+30%): each act again half a
  second later at 40%.
- **Relentless Sky** replaced "acts twice as often". The first choice was a
  world that stays lit until the wave ends; but a world never fades during a
  wave — it holds until its Mystic falls or is recalled — and one that
  outlives its Mystic is Kin's Unbroken (the reason the uptime path was
  rejected, below) and would mean rewiring every world's caster check. So it
  is the visible alternative: each act comes twice in a row, the second a
  quarter of a second after at full strength, and the aftershock follows.

Measured with `FAMILY_MYSTIC=1 FAMILY_MYSTIC_LIT=1` (105 parties): a lit
Mystic with no mastery took 20% of its party's damage and its parties held
54% of P50 wave 36; with Quickening 34% and 63%. At P80 wave 41, 21%/91% and
33%/93%. (The old path: 35%/75% and 35%/97%.) A repeat's damage is filed as
the path's (`_mysticReplaying` in `_damageEnemy` and `damageBoss`).

**2026-10-29, second pass: Quickening reaches all seventeen worlds.** The
kill rule above hurried nine worlds: Blood, Dark, Mud, Ice, Steam and Light
never kill, and Crystal and Dust keep no clock. Ice had no act at all, so
Aftershock and Relentless Sky did nothing for it either.

- **Ice's act.** Only Quickening gives the blizzard one, so without the path
  it is exactly the steady slow it was. On a beat of 6 s at P50
  (`MysticTuning.iceActInterval`, through `_mysticBeat`, so the surge and
  SPECIAL quicken it as they do the bolt, quake and vent) the blizzard
  freezes everything in it to 5% speed (`iceFreezeSpeed`, the freeze effect's
  own figure) for 12% of the beat (`_freezeMysticBlizzard`). It is written
  to the blizzard's own multiplier, so it costs no walk the blizzard was not
  already making, and it holds bosses to the slow as the blizzard does. A
  repeat adds its strength's share to the freeze still running, so Aftershock
  and Relentless Sky hold one freeze longer (about a third of the time frozen
  with the whole path). It looks like the blizzard: the frost that settles
  on held bodies (`_rimeMysticBlizzard`) settles on more of them while the
  freeze holds. First Light freezes on ignition; the readout shows the next
  freeze. Light's First Light was also dead (the star waited out its first
  turn); dawn now breaks the frame after a First Light star is raised.
- **Quickening** (`_noteMysticDeath` from `_killEnemy` and the boss kill,
  `_quickenMysticWorlds` from `_updateMysticMastery`): each time the world
  acts, the next body to die, to anything, makes it act again at once at
  half strength — its latest act through the same `_mysticActed` hook, the
  same way, in the same place. The death only raises a flag, and the act
  lands in the mastery pass of the same frame, so an act that kills never
  runs again from inside itself. Mud's act, the weight on a hit, is kept as
  the body and the weight's share of the hit and re-landed by one closure
  (`_relandMysticMire`). The brief suggested "every death acts again, at
  most twice a second"; a flat rate does not fit worlds whose acts run from
  an ember catching several times a second to a quake every 33 s and a dawn
  that mends everything, which at two a second would have been a quake a
  second and an orb that could not fall. One repeat per act of the world's
  own gives every world the same half, and a repeat is never repeated.
  Driven for all seventeen in
  `survival_mastery_mystic_combat_test.dart` ("Quickening reaches all
  seventeen worlds").

Measured with `FAMILY_MYSTIC=1 FAMILY_MYSTIC_LIT=1 FAMILY_MASTERY_ONLY=1`,
420 parties, Mystic share / held: P50 wave 36 no mastery 19% / 51%, the kill
rule 36% / 66%, now 30% / 62%; P80 wave 41 22% / 90%, 35% / 94%, now
30% / 94%. The nine worlds the kill rule hurried were pinned at an act
every third of a second in a crowd, so the path gave up a little where it
had worked to reach the eight where it did nothing.

Firmament is as it was. The 2026-09-18 reasoning below still holds for it.

Mystic is the one family with two paths instead of three, and that is a
decision rather than an omission. Only one Mystic may be fielded at a time, its
cast is spent for the whole deployment, and its seventeen worlds are each a
bespoke rule or placement — Spirit's world is a rule with no placement at all,
Blood's likewise. There is far less shared surface to hang a path on than any
other family has, so it carries two paths that work for all seventeen rather
than three where one is filler for eleven.

Reading the runtime settled which two. There is no shared "world damage" or
"world radius" field. Two things are universal:

- **`_mysticClock`**, the interval a world acts on. **Quickening** drives it,
  using the same divisor the existing powerup surge already established.
- **The element, and the fact that a world is a place.** **Firmament** drives
  that: shelter for allies inside, and the world's element lent to them.

So one path is what the world does to the enemy and the other is what it does
to the team, which is the whole of what an environment can be.

**The third path I rejected** was uptime. A world holds until its caster dies,
so "survive longer" is literally "world duration" — but every version collided
with something built days earlier: a world that lingers past your death is
Kin's Unbroken, and surviving a lethal hit so the world holds is Kin/Fire's
phoenix.

Two implementation notes from then (both gone with the 2026-10-29 rework):

- **Weight of Heaven was applied once in `_damageEnemy`**, not at seventeen
  bespoke world sites. A world's output is everything a spent Mystic deals
  that is not its own auto-attack — the same condition Quickening's kill now
  reads.
- **`mysticWorldInterval` threw on a world authored faster than its own
  floor** — `clamp(0.35, 0.2)` puts the lower limit above the upper one.

Supporting two paths needed `_columnsFor` to space however many columns a
tree has instead of hardcoding the sixths. Since 2026-10-29 every family has
two (`FamilyMasteryCatalog.validate`).


## Decisions intentionally made

- **Rhythm and Encore are not shown to the player.** War Rhythm's stack count
  and its Encore window exist only in run state; the player feels the attack
  speed change rather than reading a counter. `maneMasteryFor(slot)` exposes
  the state if that is ever revisited, but the absence is deliberate — do not
  add a HUD for it on the assumption it was forgotten.

## Decisions intentionally deferred

- Whether families should eventually support saved branch presets.
- Whether discounts unlock after purchasing a complete path in another family.
- Whether discovery rarity should affect prices. The initial recommendation is no.
- Whether family mastery later changes behavior in cosmic exploration. The initial scope is survival only.
- Whether a late-game system may permit one non-capstone node from another path. The initial recommendation is no.
