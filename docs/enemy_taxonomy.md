# Enemy Taxonomy — audit and proposed convergence

Status: **partially implemented.** §7 tracks what has landed.
Evidence: read from code 2026-08-21, line refs are to that state.

---

## 1. What exists today

Two modes, two entity classes, sharing exactly one enum.

| Axis | Open world (`CosmicEnemy`) | Survival (`CosmicSurvivalEnemy`) |
| --- | --- | --- |
| Body | `EnemyTier` (6) | `EnemyTier` (6) — **the only shared axis** |
| Conduct | `EnemyBehavior` (6) | `CosmicEnemyRole` (4) |
| Trait | `CosmicEnemyVariant` (3) | `SurvivalEnemyVariant` (8) |
| Modifier | — | `SurvivalEliteAffix` (5) |

No enemy ever carries all of these. An open-world enemy is
tier + behaviour + variant; a survival enemy is tier + role + variant, rarely
plus an affix.

---

## 2. The four real problems

### 2.1 The same concept is defined twice

`crusher` and `pouncer` exist as values in **both** `CosmicEnemyVariant` and
`SurvivalEnemyVariant` — same names, same intent, two independent enums, two
independent implementations. Any change to "what a crusher is" has to be made
in two places, and nothing enforces that they agree.

`EnemyBehavior` and `CosmicEnemyRole` are both "how does it move and pick a
target". They overlap without matching:

| Open world behaviour | Survival role | Same idea? |
| --- | --- | --- |
| aggressive | striker | yes |
| stalking | hunter | yes |
| — | orbiter | survival only |
| — | shooter | survival only |
| drifting, feeding, territorial, swarming | — | open world only |

### 2.2 Role and variant are not orthogonal — variant overrides role

`cosmic_survival_game.dart:3805` picks a movement vector from the role:

```
striker => norm      hunter  => norm
orbiter => norm*0.55 + tangent*0.85
shooter => dist > 240 ? norm : tangent*0.8
```

…and then the very next lines discard it if the variant says so:

```
crusher => norm * 1.08
pouncer => dist > 140 ? norm*1.15 + tangent*0.12 : norm
```

So these are not two independent dimensions. They are one dimension —
movement — written twice, with variant winning.

Note also that **striker and hunter produce identical movement** (`norm`).
They differ only in threat scoring and one targeting exemption
(`:3901`). Two role values, one behaviour.

### 2.3 The same concept lives at two different layers

Swarming is an **enemy behaviour** in the open world — `EnemyBehavior.swarming`,
packs of 20–32 flyers sharing a `packId`, spawned by `_spawnSwarmCluster`
(`cosmic_game_world_systems.dart:584`).

In survival the same idea is a **wave pattern** — `wispHorde` and `swarmRush`
(`cosmic_survival_spawner.dart:46`), which only scale spawn count and interval
(`:485`, `:509`).

The same is true of `hunterPack`, `siegePush` and `shooterScreen`: survival
expresses at the *composition* layer what the open world expresses at the
*entity* layer. Neither is wrong, but having both means "a swarm" is two
unrelated code paths depending on which mode you are in.

### 2.4 Variant is derived, not chosen

From `cosmic_survival_spawner.dart:679-751`, variant is a pure function of
tier + role + wave state:

| Variant | Assigned when |
| --- | --- |
| siegeShooter | role == shooter (36%) |
| crusher | tier ∈ {brute, colossus} ∧ pattern ∈ {siegePush, fortified} (34%) |
| orbBreaker | role ∈ {striker, orbiter} ∧ tier ∈ {brute, colossus} (34%) |
| pouncer | tier ∈ {drone, phantom} ∧ pattern ∈ {hunterPack, swarmRush} (32%) |
| summoner | wave ≥ 12 ∧ tier ∈ {sentinel, phantom} (18%) |
| splitter | wave ≥ 14 ∧ tier ∈ {brute, colossus} (22%) |

A player can never meet a "pouncer colossus" or a "crusher wisp". Four of the
eight variants carry no information the tier and role did not already imply —
they are labels for a correlation, not a fourth axis.

**This is the actual over-complication.** The taxonomy looks like
6 × 4 × 8 × 5; it behaves like roughly 6 × 4, with three genuinely new
mechanics bolted on.

---

## 3. Proposed taxonomy

Three axes plus a rare modifier, one definition each, shared by both modes.

### BODY — `EnemyTier` (6, unchanged)

What it is. Drives silhouette, size, HP class. Already shared; keep as-is.

wisp · drone · sentinel · phantom · brute · colossus

### CONDUCT — one enum replacing `EnemyBehavior` + `CosmicEnemyRole`

How it moves and what it wants. The single movement authority — nothing else
may override the vector it produces.

**Every value is available to both modes.** Mode belongs in *spawn policy*,
not in the type system: survival simply chooses not to roll `graze` today
because its arena has nothing to graze on. Baking "open world only" into the
enum is what produced two enums in the first place.

| Conduct | Movement | Was |
| --- | --- | --- |
| `charge` | straight at target | aggressive / striker |
| `stalk` | trails at range, strikes on weakness | stalking / hunter |
| `orbit` | holds a ring, strafes | orbiter |
| `standoff` | closes to range, then kites | shooter |
| `drift` | aimless, harmless until provoked | drifting |
| `graze` | clusters on a resource, pack-aggros | feeding |
| `patrol` | guards a zone | territorial |
| `swarm` | moves as a pack, shared `packId` | swarming / wispHorde / swarmRush |

`swarm` as a conduct subsumes survival's swarm wave patterns: a `wispHorde`
becomes "a wave composed of wisps with `swarm` conduct" rather than a separate
spawn-rate multiplier. Wave patterns stay, but as *filters over the taxonomy*
("this wave rolls mostly standoff conduct") instead of a parallel vocabulary.

`charge`/`stalk` stay separate despite identical movement today, because they
differ in targeting and threat — but that difference should be made explicit
rather than left as an accident of scoring.

### TRAIT — only mechanics not implied by body + conduct

Drop the four derived labels. Keep the three that add something genuinely new,
and let them apply to any body:

| Trait | Mechanic | Was |
| --- | --- | --- |
| `summoner` | periodically spawns wisps while alive | survival variant |
| `splitter` | bursts into fast drones on death | survival variant |
| `breaker` | prioritises and heavily damages structures/orb | orbBreaker |

Removed as redundant: `crusher` (= brute/colossus body + charge conduct),
`pouncer` (= drone/phantom body + stalk conduct), `siegeShooter`
(= standoff conduct + orb target), `standard` (= no trait).

### AFFIX — `EliteAffix` (5, unchanged values)

Rare elite modifier, genuinely orthogonal, and already the most readable thing
in the game. Rename off the `Survival` prefix and use in both modes — an elite
brute in open space is exactly as meaningful as one in a survival wave, and
costs nothing to support since the renderer already draws it.

bulwarked · volatile · vampiric · overclocked · relentless

---

## 4. What this buys

- **One definition per concept.** No more crusher-in-two-enums.
- **Movement has a single authority.** Conduct decides; nothing overrides.
- **Traits become real choices.** Three orthogonal mechanics that can appear on
  any body, instead of six labels that only ever appear on the body that
  implied them. A summoner wisp or a splitter drone becomes possible and
  interesting.
- **Fewer values, more combinations that matter.** 6 bodies × 8 conducts × 3
  optional traits × rare affix, all reachable — against today's nominal
  6 × 4 × 8 where most cells are unreachable by construction.
- **One vocabulary across modes.** A "swarm" is one thing, not an entity
  behaviour in one mode and a spawn-rate multiplier in the other. Wave patterns
  and world spawn rules become *policies that select from* the taxonomy, which
  is where mode differences belong.
- **Visual language falls out of it.** Body = silhouette, conduct = motion,
  trait = inscribed sigil, affix = ring + pip bar. Four channels, one meaning
  each. See `cosmic_enemy_vfx.dart` for the sigil/affix primitives.

## 5. Where mode differences DO belong

Not in the type system. Three places:

1. **Spawn policy** — which bodies/conducts/traits each mode rolls, and how
   often. Survival's wave patterns and the open world's behaviour weights both
   become tables over one shared taxonomy.
2. **Targets** — survival has an orb to defend; the open world has the ship and
   structures. `CosmicEnemyTarget` stays mode-aware.
3. **Lifecycle** — survival despawns on wave end; the open world needs a
   distance cull (currently missing entirely: enemies are only ever removed
   when dead, `cosmic_game.dart:5697`).

Everything above that line is shared.

## 6. Migration risk

- `SurvivalEnemyVariant` is referenced in the survival game, spawner, enemy VFX
  and `planet_dungeon_game.dart`. Dropping values is not local.
- Wave patterns and mutators currently select variants directly; they would
  need to select conduct + trait instead.
- Saved runs (if any persist enemy state) would need the old values mapped.
- Do the renderer convergence first: two renderers implementing a new taxonomy
  is twice the work and twice the drift.


---

## 7. Implementation status

Landed:

- `lib/games/shared/enemy_taxonomy.dart` — `EnemyConduct` (8), `EnemyTrait` (3),
  `EliteAffix` (5).
- `EliteAffix` renamed off the `Survival` prefix; the duplicate declaration in
  the spawner is gone. Both modes can use it.
- `lib/games/shared/enemy_movement.dart` — movement extracted out of the
  survival update loop into pure functions, then converted to
  `conductMoveVector`. Conduct is now the sole movement authority; the
  variant-overrides-role bug from §2.2 is gone.
- The crusher's hidden `* 1.08` moved out of the direction vector into
  `effectiveSpeed` via `conductSpeedMultiplier`.
- Both `CosmicSurvivalEnemy` and `CosmicEnemy` carry a derived `conduct`;
  survival also carries `trait`.
- `test/enemy_movement_test.dart` — 20 tests. Characterisation tests pin the
  old behaviour, equivalence tests prove `charge == striker`,
  `orbit == orbiter`, `standoff == shooter`, and cross-mode tests prove
  `crusher`/`pouncer` now mean the same thing in both modes.

**One deliberate behaviour change:** `stalk` takes the old *pouncer* vector,
not the old *hunter* one. Hunter and striker produced an identical vector, so
mapping hunter onto `charge`-like movement would have carried §2.2's redundancy
forward. Enemies that were hunters now hold at range and lunge. There is a test
asserting this difference is intentional.

Also landed (second pass):

- **§2.4 fixed.** The spawner picks conduct and trait directly. Traits are
  rolled independently of the body, so any tier can carry any trait — summoner
  was previously reachable only on sentinel/phantom and splitter only on
  brute/colossus. `test/enemy_spawn_policy_test.dart` asserts each rolled trait
  appears on more than one tier.
- The body-locked summoner/splitter roll is deleted.
- The archetype sigil keys off `trait`, not `variant`, so the mark means the
  same thing on a wisp as on a colossus.
- `variant` is now *derived* from conduct+trait for the call sites that have
  not migrated, so the two cannot disagree.

Third pass — **`SurvivalEnemyVariant` is deleted.** Zero references remain in
`lib/` or `test/`. Everything that read it now reads `trait` or `conduct`:
the dungeon's anvil waves and shard spawns, the boss-adds table, the
summon cooldown, and the visual squash. Stat multipliers that had a row per
variant are split into independent trait and conduct terms, which is why
`breaker` and `crusher` no longer need separate rows for the same idea.

Fourth pass — **`CosmicEnemyRole` is deleted too.** Both legacy enums are gone;
`grep -rn 'CosmicEnemyRole\|SurvivalEnemyVariant' lib test` returns nothing.

- `_roleForWave` became `_conductForWave`, so **wave patterns now filter over
  the taxonomy directly** rather than through a second vocabulary.
- Boss disciplines field a `(conduct, trait)` pair per add instead of a role
  they then translated.
- Targeting, threat scoring, `isShooter` and the orbiter damage bonus all read
  conduct.

## 8. Status

The four axes are real, shared, and each has exactly one definition:

| Axis | Enum | Where it lives |
| --- | --- | --- |
| BODY | `EnemyTier` | `cosmic_data.dart` |
| CONDUCT | `EnemyConduct` | `shared/enemy_taxonomy.dart` |
| TRAIT | `EnemyTrait` | `shared/enemy_taxonomy.dart` |
| AFFIX | `EliteAffix` | `shared/enemy_taxonomy.dart` |

Mode differences live only where §5 says they should: spawn policy, targets,
and lifecycle.

Remaining, and deliberately not done:

- The open world's 65 `EnemyBehavior` sites still steer ad hoc rather than
  calling `conductMoveVector`. `EnemyBehavior` maps cleanly onto conduct and
  the mapping is tested, but the steering itself is bespoke per behaviour
  (feeding packs, territorial leashes, swarm cohesion) and is not a mechanical
  substitution. This is the last real piece.
- Conduct has no visual channel: of the eight, only `charge` (on a heavy body),
  `stalk` and `standoff` differ in silhouette. The other four are identical
  stills because conduct is expressed through MOTION. Defensible, but a
  stationary patroller and a drifter are indistinguishable until they move.
