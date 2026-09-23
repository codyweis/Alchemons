# Mask ability review — Survival and open Cosmic

Reviewed against `docs/cosmic_ability_families.md`. Scope: companion and garrison placements in open Cosmic, and Survival including Double Cast. Dungeon and battle-ring opponent abilities are separate runtimes.

## Functional findings and changes

| Element | Practical role | Review result |
| --- | --- | --- |
| Air | Push approaching enemies away | Existing knockback retained; stationary contact now happens once per enemy rather than every frame. |
| Dust | Protect allies while damaging nearby enemies | Added Cosmic attached shields and interception charges; Survival Double Cast now refreshes shields instead of leaving an inert seed. |
| Lava | Damage enemies standing in pools | Area damage retained; damage now reaches bosses inside the field. |
| Poison | Cover an area with damage over time | Area damage retained; boss damage enabled. |
| Plant | Build a persistent, growing damage-and-slow zone | Cosmic now feeds one vine per caster. Removed Cosmic's automatic radius shrink. Feeding now scales from the vine's original damage in both modes; Survival echoes feed the same vine. |
| Blood | Mark enemies for continuing damage and party healing | Added Cosmic persistent drain. Fractional healing accumulates so companions actually receive small heals. |
| Earth | Create safe places to recover | Pools now heal living allies inside their radius, rather than healing globally. |
| Light | Remove one dangerous regular enemy | A void consumes exactly one enemy, including armored enemies; its visual collapse cannot kill additional bodies. No boss execution. |
| Spirit | Collect six wisps to clear regular enemies | Added Cosmic ship collection and threshold handling. Survival echoes now produce collectibles; armored regular enemies no longer survive the clear. Bosses remain unaffected. |
| Crystal | Contact damage followed by three smaller traps | Parents split once; children cannot split again. Removed Survival's duplicate direct hit. Boss contact also releases shards. |
| Fire | Turn a contact trap into a burning area | A ball creates one pool; pools cannot generate more pools. Removed duplicate direct damage. Pools damage bosses. |
| Lightning | Grow a damage field as new enemies enter | A lone enemy anywhere within the field takes damage. Growth is counted once per distinct body instead of requiring overlap with a tiny central hitbox. |
| Steam | Area damage plus targeted geyser shots | Existing turret firing retained; the field also damages bosses. |
| Dark | Pull enemies in and eject them unharmed | Cosmic now respects the harmless-ejection rule, without the generic black hole's low-health executions. Survival behavior retained. |
| Ice | Strengthen nearby allies and ship | Buffs work with no enemies present, respect the actual radius, and include ship weapons. Ally buffs have a short refresh window rather than lasting the pillar's entire lifetime after leaving. |
| Mud | Slow enemies crossing a pool | Existing spatial snare retained. Cosmic no longer permanently reduces base movement speed through the generic slow handler. |
| Water | Contact damage with nearby splash | Existing splash retained; continuous overlap no longer causes damage every frame. |

## Regression coverage

`test/mask_ability_runtime_test.dart` exercises actual game handlers and update loops: parent/child trap bounds, armor-safe executions, local healing, enemy-free buffs, field growth, permanent drain, fractional healing, boss area damage, collision cadence, Double Cast, Spirit collection, and persistent placements. Existing board-conformance and Mask mastery/chain suites cover descriptors, growth limits, contagion, death placements, and bounded spawning. Visual tests remain separate from mechanics tests.

## Balance assessment

Each element now has a functioning role; this is not a claim that all have equal power. Positional support (Earth/Ice), one-victim removal (Light), collection (Spirit), and long-term growth (Plant) are intentionally situational. Plant still takes 100 feeds to reach its authored maximum; practical time-to-grow should be judged in full runs. Fire, Crystal, and Water may show lower damage than before because repeated-contact and duplicate-hit bugs no longer inflate their output. Reassess clear speed and survival at comparable stats in played runs before changing damage numbers or cooldowns.

Boss policy confirmed by the user: damaging fields hurt bosses; Light and Spirit do not instantly kill them. No blanket damage or cooldown rebalance was made.

## Survival placement follow-up

Survival now repositions casts according to their role. Earth prioritizes injured allies and avoids spending every pool on one cluster. Ice chooses ally positions or midpoints to cover the largest group, preferring the ship on ties. Spirit creates a short collection ring near the ship. Offensive multi-trap casts cover the selected target and a compact area along its approach toward defended bodies. Additional traps increase density instead of multiplying scatter distance. Placement accounts for field radius at the arena boundary. Dust still follows its hosts. Both normal casts and Double Cast use these rules; authored counts, damage, lifetime, and stat scaling are preserved. Open Cosmic uses its existing placement rules.
