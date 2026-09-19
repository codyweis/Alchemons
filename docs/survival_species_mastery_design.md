# Survival Family Mastery

Status (2026-09-18): Phases 1 and 2 complete. **All eight families are implemented in combat.** Seven carry twelve nodes across three paths; Mystic carries eight across two. Each lives in its own file (`survival_mastery_mane.dart`, `_let.dart`, `_pip.dart`, `_horn.dart`, `_mask.dart`, `_wing.dart`, `_kin.dart`, `_mystic.dart`) with its own test suite. Tuning is open for all of them and none has been played on device. Tuning is open for all three and none has been played on device. The Base Command Mastery tab is polished (the first item of Phase 6).

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

Every family has three paths with three sequential silver nodes and one gold capstone.

| Tier | Cost | Purpose |
| --- | ---: | --- |
| Path I | 1,000 silver | Establishes the path's core behavior |
| Path II | 5,000 silver | Adds its first meaningful interaction |
| Path III | 10,000 silver | Completes the path's combat loop |
| Capstone | 10 gold | Dramatically changes the visible combat rhythm |

Rules:

- A later node requires every earlier node in that path.
- Buying the first node automatically equips that path if no path is selected.
- Buying another path does not automatically replace the equipped path.
- A partially purchased path may be equipped and grants its purchased nodes.
- Selecting or resetting a family branch costs nothing.
- Owning every unlock across all eight families costs 384,000 silver and 240 gold before discounts.

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

**Existing chassis:** two close-angle slash projectiles at 65% physical damage each. Mane is a flexible skirmisher that rewards positioning both blades.

### Assault — Twin Fang

Single-target pressure and kill chaining.

1. **Honed Pair** — Narrow slash spread by 35%. Each slash deals 70% physical damage instead of 65%.
2. **Crosscut** — A dual hit deals an additional 20% physical damage and triggers one elemental payload per cast.
3. **Predator Step** — A basic kill gives the next cast within 3 seconds stronger tracking and 25% more main-hit damage.
4. **Capstone: Blade Dance** — Casting the special empowers the next five basic casts. Their slashes return to the Mane for 35% of outgoing damage. Returning hits cannot trigger Crosscut or another payload.

### Limitless

One idea, four times: the catapult shot does not stop.

1. **Far Throw** — Special projectiles carry 45% longer before fading, piercing more on the way.
2. **Overdraw** — The special deals 15% more damage. Deliberately plain: several elements already grow as they travel (Light ramps per pierce, Earth sheds fragments), so a "gains power with distance" node would describe what the element was already doing.
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

### Resonance — War Rhythm

Build rhythm with basics and release it around the existing special.

1. **Measured Cuts** — A dual hit grants one Rhythm, up to five. Each Rhythm grants 2% basic attack speed. Missing with both blades removes one Rhythm.
2. **Rising Tempo** — Each Rhythm also grants 3% basic damage. At three or more Rhythm, slashes are 15% wider.
3. **Crescendo** — Casting the special consumes Rhythm and empowers that many subsequent basic casts with 12% damage and one payload on their primary target.
4. **Capstone: Encore** — Consuming five Rhythm also creates a 6-second Encore: 25% faster basics and wider slashes. Basic kills extend the current Encore by 0.4 seconds, up to 2 additional seconds total; Encore cannot otherwise refresh itself.

---

## Let

**Existing chassis:** one large, slow meteor at 115% physical damage, thrown flat at a single target. Let is the deliberate heavy artillery family, and its targeting already prefers the toughest enemy and bosses.

**Two meteors — every node names which one it changes.** A Let throws two different things, and the tree text must never leave the player guessing which:

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

So Let mastery works only in what no element owns: damage, marks, attack speed, range, targeting, and the shape of the auto-attack's delivery.

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

### Ground Zero — special meteor

The big one tells the rest where to land: the special meteor marks, the auto-attack meteor punishes. Marks and attack speed are owned by no element, so this path reads the same for all seventeen and takes nothing from any of them.

1. **Sighted** — Every body the special meteor's crater catches is Sighted for 6 seconds. The Let's auto-attack meteors deal 20% more to Sighted bodies. Sight is applied alongside the element's own effect, never instead of it.
2. **Walking Fire** — The Let's auto-attack targeting prefers Sighted bodies, and each auto-attack hit on one adds 1 second to its Sight, up to 10 seconds remaining.
3. **Called Shot** — Every companion deals 10% more damage to Sighted bodies.
4. **Capstone: Fire for Effect** — While any body is Sighted, the Let attacks 30% faster. When a Sighted body dies its Sight, with its remaining time, passes to the nearest living enemy — one hop per death, so it cannot cascade within a frame.

### Let implementation notes (2026-09-17)

- **Where it lives.** Numbers, node ids and the per-hit bonus rule are in `survival_mastery_let.dart`; the game wires them in under "Let mastery" in `cosmic_survival_game.dart`. The body statuses (`letFractureTimer`, `letSightTimer` and the Sight's owner flags) live on the shared `MasteryPayloadStatuses`, so enemies and bosses carry them alike.
- **One place for the auto-attack bonuses.** Cratermaker, Dead Weight, the Ranging Shots streak and the Sighted bonus are resolved together in `resolveLetAutoAttackBonus`, called from `_damageEnemy` and `damageBoss` only for damage that belongs to a Let *basic* cast. Crater splash carries no cast, so it never earns them. The bonus is additive, and its share of the hit is credited to mastery in telemetry.
- **Called Shot credit.** The +10% applies to every companion's damage against a Sighted body, and its share is credited to the Let whose special applied the Sight, not to whoever fired.
- **Deadfall** builds its falling rock through the same `letSkyfallDrop` geometry as the special, and marks it `letDeadfall` so it lands through its own `_detonateLetDeadfall` — nearest body under the crater takes the rock, the rest take the crater share, and `_resolveLetMeteorHit` (the special's element behaviour) is never reached. Its ground telegraph draws the auto-attack crater, not the special's, and it sheds about a third of the special's descent embers.
- **Comets** (Extinction Event) still fly flat; the crater opens on first contact through `_openLetCrater`, once.
- **Skyreach** fires from `_tryFireLetSkyreach` before the in-range attack block, on its own target (the healthiest boss, else the healthiest enemy, anywhere), whether or not anything is near the Let. It spends the cooldown, which is what stops the ordinary attack firing a second rock that frame. The Let does not walk to the target. A capstone activation is recorded only when the target was beyond ordinary reach.
- **Fire for Effect's hop** runs from `_killEnemy` and the boss death path, before the body is marked dead, and moves the Sight's remaining time to the nearest living body. The body it lands on is alive, so no hop can cascade inside a frame.
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
unclaimed — marks, dart counts, target spread — is what these paths are made
of.

### Assault — Needlepoint

All three darts into one body.

1. **Tight Grouping** — Spread narrows 45%; each dart deals 32% physical.
2. **Pin Cushion** — A full volley on one body banks a Pin, up to five. Each Pin adds 3% to Pip damage against it. Pins lapse after 6 seconds untouched.
3. **Pluck the Pins** — Hitting a five-Pin body spends them for 55% physical. A boss keeps two, so the loop can restart against something that will not die to one detonation.
4. **Capstone: Thousand Cuts** — Every fourth full volley throws a second five-dart volley 0.2s later at 16% each. The bonus volley cannot bank Pins, or it would feed itself.

### Control — Scattershot

One dart into each of three bodies.

1. **Wide Spray** — Spread widens 40% and each dart curves toward its own nearby enemy. Widening without seeking would only miss.
2. **Three Fronts** — Three darts on three different bodies pays every one of them 20% extra.
3. **Fourth Barrel** — The volley fires a fourth dart.
4. **Capstone: Scatter Storm** — Every fifth attack throws eight darts, each seeking its own body, at 22% each. Not counted as another scheduled attack.

### Salvo

Leaves the volley alone and loads the special instead.

1. **Spare Needle** — One more dart on the special, at 70% of an authored dart.
2. **Double Load** — Another.
3. **Full Quiver** — Another.
4. **Capstone: Perfect Salvo** — A fourth extra dart, and every extra now hits at full strength.

Each extra is a *copy of the element's own dart*, so a Lightning salvo still
ricochets five times and a Blood salvo still heals on a kill. The path adds
darts; it never decides what a dart does.

Two consequences, both accepted:

- **A flat dart is worth different amounts per element.** Lava throws two
  darts, so four more nearly triples it; Lightning throws six, so four more is
  a 1.7x lift. Scaling by percentage instead would be fairer and far less
  legible on a tooltip.
- **Salvo gives a Dark Pip nothing.** Pip+Dark is passive-only and has no cast
  at all, so all four nodes are dead for it. That is the intended shape of the
  choice rather than an oversight: a Dark player takes Needlepoint or
  Scattershot, and a test asserts the zero so nobody later "fixes" it.

---

## Mask

**Existing chassis:** one fast piercing dart at 90% physical damage. Mask specials create snares, lures, taunts, and persistent fixtures.

### Assault — Phantom Needle

Piercing lanes and priority-target punishment.

1. **Long Needle** — Projectile life increases by 25%, speed by 10%, and first-target damage becomes 100% physical attack.
2. **Through the Veil** — Each enemy pierced increases damage to the next enemy by 8%, up to 24%.
3. **Chosen Victim** — The first elite or boss hit is Marked for 3 seconds. Mask basics deal 12% more damage to their own Marked target.
4. **Capstone: Phantom Lance** — Every fourth cast becomes a broad spectral lance that pierces indefinitely, deals 145% physical damage, and applies one elemental payload to the first three targets.

### Control — Hexweaver

Basics prepare space for existing trap specials.

1. **Inscribed Dart** — The first enemy hit receives a 4-second Sigil. Only one Sigil per Mask may exist. Mask basics deal 10% more damage to the Sigiled enemy.
2. **Binding Script** — Striking the Sigiled enemy again triggers one elemental payload and briefly slows it by 15%. Internal cooldown: 1 second.
3. **Prepared Ground** — Casting the special near the Sigiled enemy transfers the Sigil to the created fixture, increasing its radius or reach by 15% and duration by 20%.
4. **Capstone: Haunted Ground** — The empowered fixture fires a reduced copy of the Mask's basic at a nearby enemy every 1.2 seconds. Copies deal 30% physical damage and cannot create Sigils.

### Resonance — Grand Masquerade

Manipulates enemy attention and turns trap success into offense.

1. **False Face** — Basic hits make ordinary enemies 20% more likely to choose a Mask fixture or decoy as their target for 2 seconds.
2. **Applause** — When a Mask fixture controls an enemy, the Mask gains 12% basic attack speed for 2 seconds. This refreshes but does not stack.
3. **Curtain Call** — An enemy killed while controlled releases a small payload at 60% strength. Internal cooldown: 0.5 seconds.
4. **Capstone: Grand Masquerade** — While a Mask fixture is active, every third basic originates a second 35%-damage spectral dart from that fixture toward a different target. The copy cannot trigger Curtain Call.

---

## Horn

**Existing chassis:** one slow, oversized projectile at 160% physical damage. Horn specials center on charges, impact sweeps, passive auras, and defensive effects.

### Assault — Breaker

Close-range impact and armor destruction.

1. **Heavy Head** — Basic projectile speed falls by 8%, but damage rises to 175% physical attack.
2. **Sunder** — Basic hits apply 6% physical vulnerability for 3 seconds, up to two stacks. Boss stacks are half strength.
3. **Point Blank** — Hits inside 45% of attack range deal 22% additional damage and briefly stagger ordinary enemies.
4. **Capstone: Siege Horn** — Every fourth cast becomes an impact shell dealing 220% physical damage and a 55% shockwave around the target. It consumes Sunder to enlarge the shockwave, not increase boss damage.

### Control — Bastion

Protects space and converts attacks into guard.

1. **Guarded Shot** — Casting a basic grants a small temporary shield equal to 1.5% maximum HP, capped at 6%.
2. **Hold the Line** — Hitting an enemy moving toward the orb pushes it back and triggers the elemental payload at 70% strength. Internal cooldown: 1 second per target.
3. **Interposition** — At maximum Guarded Shot shield, the next projectile that would hit the orb or a nearby ally is intercepted; the shield is consumed.
4. **Capstone: Countercharge** — Consuming the shield through Interposition primes the next basic within 4 seconds into a 190%-damage countershot with a strong push and one full payload.

### Resonance — Stampede

Basics build Momentum for the existing charge or passive special.

1. **Gather Momentum** — Each basic hit grants one Momentum, up to five. Momentum expires after 5 seconds without a hit. Each Momentum grants 2% basic damage.
2. **Rolling Weight** — Each Momentum grants 3% basic projectile speed and 2% attack speed.
3. **Impact Reserve** — Casting an active Horn special consumes Momentum to add 6% impact or field power per stack. Passive-only Horns instead release a payload pulse at five stacks and reset.
4. **Capstone: Unstoppable** — Consuming five Momentum makes the next charge ignore ordinary collision control, increases sweep width by 25%, and causes the landing to fire the Horn's basic in four directions at 35% damage. Passive-only Horns receive an equivalent 6-second empowered aura window.

---

## Wing

**Existing chassis:** two same-angle projectiles at 50% physical damage each with slightly different speed and lifetime. Wing specials are beams and long-range elemental lanes.

### Assault — Twin Lance

Converging long-range pressure.

1. **Synchronized Flight** — The paired projectiles align their speed and converge slightly; each deals 53% physical damage.
2. **Rangefinder** — Hits beyond 60% of attack range deal 15% additional damage.
3. **Double Tap** — A dual hit on the same target deals 25% additional physical damage and triggers one payload at 70% strength.
4. **Capstone: Twin Suns** — Every fifth cast fuses the pair mid-flight into one homing lance dealing 165% physical damage. It pierces once and triggers a payload on its first hit.

### Control — Razor Horizon

Wide firing lanes and distributed pressure.

1. **Open Wings** — The two projectiles fire at opposite 9-degree angles and each pierces one enemy at 46% physical damage.
2. **Crosscurrent** — After piercing, each shot bends toward a different nearby target for 35% remaining damage.
3. **Elemental Contrails** — The first pierced enemy on each side receives the elemental payload at 60% strength.
4. **Capstone: Razor Horizon** — Every fourth cast sweeps a thin line between the two shots for 1 second. Enemies crossing it take 65% physical damage and one reduced payload, once per cast.

### Resonance — Beamweaver

Basics tune the next existing beam special.

1. **Sightline** — Dual hits grant one Focus, up to five. Focus expires after 6 seconds without a hit. Each Focus grants 2% basic range.
2. **Coherent Light** — Each Focus also grants 3% basic damage.
3. **Beam Feed** — Casting the special consumes Focus, adding 4% beam or special duration and 4% effect power per stack. One-shot specials receive equivalent total output rather than duration.
4. **Capstone: Continuum** — Consuming five Focus leaves a reduced echo of the special's primary line or impact after it ends, dealing 35% of its original power. This never modifies special cooldown; Dark Wing receives no additional firing-rate multiplier.

---

## Kin

**Existing chassis:** a dedicated 1.5-second charged laser scaled from physical attack. Kin specials are primarily blessings and team support effects.

### Assault — Overcharge

Transforms the charged laser into a deliberate offensive weapon.

1. **Hot Coil** — Charge time falls from 1.5 to 1.25 seconds, while laser damage falls to 90% of its prior coefficient.
2. **Burn Through** — The laser pierces one additional enemy for 55% remaining damage.
3. **Critical Mass** — Holding a valid target for the entire charge adds 20% damage and one payload to the primary target.
4. **Capstone: Judgment Line** — Every fourth completed charge overcharges for an additional 0.35 seconds, then fires a much wider beam at 180% normal laser damage. The player receives a clear windup cue; interrupted charges do not consume it.

### Control — Conduit

Conductive marks and battlefield lanes.

1. **Conductivity** — A laser hit marks its target for 4 seconds. Only one Kin Conductivity mark may exist per caster. The marked target takes 8% more damage from all companions.
2. **Ground Path** — Firing through the marked target leaves a 2-second lane between Kin and target. Enemies crossing it receive the payload at 60% strength once.
3. **Relay Point** — An ally autoattack hitting the marked target sends a 20%-elemental-attack pulse to one nearby enemy. Internal cooldown: 0.8 seconds.
4. **Capstone: Living Circuit** — While the Kin's timed support special is active, Conductivity may link up to three targets. An instantaneous support special instead opens this link window for 6 seconds. Laser and allied pulses travel the link once, using a shared chain budget to prevent recursion.

### Resonance — Aegis Relay

Laser hits feed the Kin's existing support identity.

1. **Guard Charge** — Completing a laser grants the lowest-health ally or the orb a shield equal to 1% of the Kin's maximum HP. Per-target cap: 4%.
2. **Shared Current** — Shielding an ally gives that ally 8% basic attack speed for 2 seconds. This refreshes but does not stack.
3. **Blessing Reserve** — Laser hits store one Reserve, up to five. Casting the special consumes Reserve for 4% increased healing, shielding, duration, or support strength per stack.
4. **Capstone: Guardian Relay** — Consuming five Reserve sends the Kin's elemental payload through every living companion once at a support-safe interpretation: harmful payloads strike a nearby enemy; Blood and Light heal or ward allies. It cannot trigger another Reserve.

---

## Mystic

**Existing chassis:** three 40%-damage spell projectiles. Basic attacks already reduce special cooldown. Mystic specials transform the world and normally cast only once per deployment.

Mystic mastery never adds further special-cooldown refunds.

### Assault — Starcaller

Makes the ordinary spell volley a credible offensive choice before and after the world arrives.

1. **Aligned Stars** — Volley spread narrows by 30%; each bolt deals 42% physical damage.
2. **Conjunction** — A full volley hit deals 30% elemental attack and triggers one payload per cast.
3. **Falling Sign** — Every fourth full volley marks the target. The next volley against it gains light homing and 20% main-hit damage.
4. **Capstone: The Stars Answer** — Every fifth cast converges into a sigil at the primary target after 0.45 seconds, dealing 85% elemental attack in an area. While the world is active, the sigil uses a stronger visual and 20% larger radius.

### Control — Worldshaper

Basics seed locations that the existing world special later awakens.

1. **Seed the Field** — Every third cast leaves a Seed at the primary hit location for 8 seconds. Maximum three. Each Seed pulses 10% elemental attack to nearby enemies every 2 seconds.
2. **Local Omen** — Enemies near a Seed receive a weak, non-damaging version of the elemental payload once every 2 seconds.
3. **Awakening** — When the world activates, all current Seeds awaken for its lifetime, gaining a small element-specific damage or control pulse.
4. **Capstone: Living World** — While the world is active, every fifth cast creates a temporary awakened Seed for 5 seconds. Maximum five total Seeds; replacing the oldest does not trigger an exit effect.

### Resonance — Covenant

Uses basic accuracy to support the party without accelerating the one-use world cast.

1. **Witness** — A full volley hit grants one Insight, up to five. Insight does not expire while the Mystic remains deployed. Each Insight grants 2% basic damage.
2. **Shared Vision** — At five Insight, the party gains 5% attack range and the Mystic's basics seek targets not already being attacked when possible.
3. **Oath Fulfilled** — Casting the world consumes Insight to grant all living companions a 5-second element-themed boon. The boon changes behavior or utility, not raw special cooldown.
4. **Capstone: Worldbond** — While the world is active, every five full-volley hits release a covenant pulse: allies receive a small shield or heal, and nearby enemies receive one payload at 60% strength. Internal cooldown: 2 seconds.

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

All twelve nodes live in `lib/games/cosmic_survival/survival_mastery_mane.dart`
(numbers, per-slot state, and the pure shape resolver) and in the game's
"Mane mastery" section (the hooks that spawn and apply). The split is the one
phases 4 and 5 should copy: anything that can be decided without the world
lives in the family file, so it can be read and tested on its own.

Three things worth knowing before the next family:

- **The pair is rebuilt, not edited.** Spread, width, damage and tracking are
  decided together, and `homing` is final on a projectile, so a Predator Step
  cast cannot be made to track by tweaking what the chassis factory returned.
  Per-slash damage is still derived from that factory's own output, so the
  chassis stays the single source of base scaling.
- **A cast's empowerment is decided before the cast exists.** The shape pass
  spends the Crescendo and Blade Dance counters, then `beginCast` runs, then
  the tag is applied. The counter cannot be re-read to decide the tag — a
  one-cast Crescendo spends its counter to zero and would tag nothing.
- **Exclusions are structural where they can be.** A Blade Dance return
  carries no cast id and no return fraction of its own, which is exactly why
  it cannot trigger Crosscut, cannot fire a payload and cannot boomerang
  again. Nothing checks for those three cases.

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

### Horn — Bulwark, Bastion, Juggernaut (2026-09-18)

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

So all three replacement paths key only to what every Horn has — a body with
hit points, an auto-attack, and an element:

- **Bulwark** turns maximum HP into damage. Nothing else in the game scales a
  companion's damage off its own bulk.
- **Bastion** takes hits meant for the orb, mitigated by that bulk, so the team
  comes out ahead rather than the damage merely moving. Nothing else in the
  game redirects damage onto a companion.
- **Juggernaut** runs the special a second time — a charge ploughs back, a
  wind-up releases twice, Light's barrier re-ups, and a passive Horn, which can
  never cast, gains a pulse instead.

Two things worth keeping from the implementation:

- **The weight goes into the charge once, at cast**, not per contact. A charge
  that ploughs through six bodies would otherwise add a Horn's whole bulk six
  times, which is how a tank path quietly becomes the best damage path.
- **`hornSpecialActiveWindow` is useless as a completion signal.** It is a flat
  five seconds and Horn's own special cooldown is about four, so a Horn that
  keeps casting re-opens it forever and it never closes. Juggernaut arms off
  `chargeTimer`/`windUpTimer`/the Light barrier instead, and only after it has
  actually seen the ability running — otherwise the second run arms on the
  frame of the cast and the two overlap into one doubled hit.


### Mask — Deathmask, Rearm, Contagion (2026-09-18)

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
the tree is the three phases of one trap's life — how it gets placed, how often
it goes off, and what happens after:

- **Deathmask** puts traps down on kills.
- **Rearm** stops a trap spending itself on contact.
- **Contagion** makes what a trap catches carry it onward. Enemy-to-enemy
  spread was the one genuinely unclaimed mechanic left: a grep for
  `contagion`, `spreadTo` and `infect` returned nothing.

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


### Wing — Burn Through, Longshot, Tracer (2026-09-18)

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


### Kin — Longline, Conduction, Benediction (2026-09-18)

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


### Mystic — Quickening, Firmament, and only two paths (2026-09-18)

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

Two implementation notes worth keeping:

- **Weight of Heaven is applied once in `_damageEnemy`**, not at seventeen
  bespoke world sites. A world's output is everything a spent Mystic deals
  that is not its own auto-attack, which is exactly what the condition says.
- **`mysticWorldInterval` threw on a world authored faster than its own
  floor** — `clamp(0.35, 0.2)` puts the lower limit above the upper one. A
  world already faster than the floor is now left exactly as it is.

Supporting this needed two structural changes: the catalog validator expects
two paths for Mystic and three for everyone else, and `_columnsFor` spaces
however many columns a tree has instead of hardcoding the sixths — Mystic's
two land on the quarters rather than leaving the right third of the crown
empty. The catalog is now eight trees, 23 paths and 92 nodes.


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
