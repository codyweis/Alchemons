# Cosmic Ability Family Contracts

The authored design intent for each family, per element. This is the spec the
implementation in `lib/games/cosmic/cosmic_data.dart` answers to, and what
`test/cosmic_balance_test.dart` should assert against.

**Why this file exists.** These contracts previously lived only outside the
repo. Several families were redesigned (Horn from a uniform shield+charge to a
per-element tank, Kin to one Rare-Support path per element) and nothing in the
repo recorded it, so the balance tests kept asserting the superseded shapes and
rotted into 14 permanent failures. Anything that changes a family's shape
belongs here in the same commit.

**Gap: Mystic has no recorded contract.** The other seven are below. Mystic is
implemented (17 elements, `mysticOrbital` payloads, the premium long-cooldown
ultimates) and its balance tests pass, but no authored per-element intent was
ever written down — so nothing says whether the implementation is right, only
that it is bounded. Worth writing before Mystic is next touched.

See also `docs/cosmic_ability_contract.md` for the plumbing rules and the
contact-sheet commands.


---

## Let

Let family theme: **Meteors**. Each special drops a single heavy meteor projectile that crashes at the target location. The element layers an on-collide or on-kill effect on top. Source: hand-drawn design board the user shared 2026-05-29.

Per-element intent (must not stray from this):

- **Air**: If enemy destroyed by the meteor, blow back all surrounding enemies.
- **Dust**: If collides, create a dust cloud that slows enemies.
- **Lava**: If collision, create an area of burning ground with DoT around the impact.
- **Poison**: Poisons enemies if it collides with them.
- **Plant**: If meteor kills, vines grow from the ground that persist until an enemy collides with them. Vines damage.
- **Blood**: If enemy dies, meteor breaks into pieces and leaches onto nearby enemies and drains HP. HP drained is split as healing across all alchemons.
- **Earth**: When collides, % of damage dealt heals the lowest-HP alchemon or ship.
- **Light**: If meteor kills, create a pool of light that heals allies and ship.
- **Spirit**: 20% chance to one-shot (execute). Chance increases with stats.
- **Crystal**: Special CD halved. Weaker damage, but if collides, slows enemy by 90%.
- **Fire**: If enemy dies, create a big explosion that damages nearby enemies.
- **Lightning**: If hits and there are enemies nearby, do chain damage.
- **Steam**: If kills, create a geyser that remains for a long time and pushes enemies.
- **Dark**: If enemy killed, immediately throw another meteor (up to 5 more, twice as big) at surrounding enemies.
- **Ice**: When collides, freeze the enemy for a certain time.
- **Mud**: If kills, create a pool that stuns enemies caught inside.
- **Water**: If meteors collide, create a big splash damage to surrounding enemies.

**Why:** Continuing the per-family design-audit workflow started with pip/wing/horn/mane. User shared the Let design board after locking in those four families.

**How to apply:** When auditing or modifying any let special, verify the current code delivers the listed behavior. The shared shape is "one heavy meteor that crashes at the target"; element layers an on-collide or on-kill effect on top. Tune damage/visuals freely but do NOT change *what* the per-collide / per-kill effect is.

Related: [[project-pip-specials-design]], [[project-wing-specials-design]], [[project-horn-specials-design]], [[project-mane-specials-design]], [[feedback-performance]].


---

## Pip

Pip family theme: **Ricochet**. All Pip specials are ricocheting darts. The element layers a kill/persistence behavior on top. Source: hand-drawn design board the user shared 2026-05-28.

Per-element intent (must not stray from this):

- **Air**: ricochet shots, push back enemies that survive
- **Dust**: ricochet shots, creates small dust clouds that slow if enemy dies
- **Lava**: burns (DoT) on enemies that don't die
- **Poison**: creates a line between enemies that persists until next usage; enemies that pass through are poisoned (DoT)
- **Blood**: enemies that die heal the blood pip
- **Earth**: auto-attack cooldown decreases (each basic shaves the special CD, per current code at [cosmic_survival_game.dart:1780](lib/games/cosmic_survival/cosmic_survival_game.dart:1780))
- **Light**: enemies that die heal the orb
- **Spirit**: kills are stacked; at a threshold the spirit pip enters a boosted window with up to 10× atk speed (scaling)
- **Crystal**: last enemy killed creates a taunting crystal that taunts enemies
- **Fire**: if enemy dies, fire pools persist that burn (DoT)
- **Lightning**: double the ricochet (highest bounce count)
- **Steam**: steam cloud forms around the steam pip; atk speed increases for a window (50%–300%)
- **Dark**: PASSIVE — enemies killed with autos form black holes that suck in enemies (no projectile special)
- **Ice**: enemies that don't die are frozen
- **Mud**: cover enemies in mud; affected enemies permanently leave mud trails that slow other enemies (see `pipMudTrail` flag on [cosmic_data.dart:3069](lib/games/cosmic/cosmic_data.dart:3069))
- **Plant**: killed enemies grow alchemical meter 50% more on death (kill effect = `alchemyBonus`)
- **Water**: each enemy killed does splash damage; if last enemy hit dies, huge splash damage

**Why:** User explicitly said "make sure we don't stray away from what the ability is written to do" when greenlighting the pip special buff + visual overhaul.

**How to apply:** When buffing or visually reworking any pip special, verify the current code delivers the listed behavior. Tune damage/visuals freely but do NOT change *what the kill/hit effect is*. Related: [[feedback-performance]] — visual upgrades must stay cheap (no MaskFilter.blur, reuse paints).


---

## Mane

Mane family theme: **Catapult / Piercing**. Each special is a single big projectile fired in a line that pierces through enemies. The element changes what happens AS the projectile pierces (or on impact). Source: hand-drawn design board the user shared 2026-05-29.

Per-element intent (must not stray from this):

- **Air**: Projectile travels at 2× speed. Enemies in the path get pushed the distance of the projectile.
- **Dust**: Projectile leaves a dust cloud trail along its path. Enemies that enter the trail can no longer shoot projectiles (disorient/suppress).
- **Lava**: For every enemy collision, leave a blob of lava at the collision point. Lava blobs DoT.
- **Poison**: Applies a stack of poison to every enemy hit. The more enemies hit, the more damage the poison does (stacks make each hit stronger).
- **Blood**: For every enemy pierced, restore HP to the orb.
- **Earth**: Starts huge, slowly moves and breaks apart over time, shooting smaller projectiles out as it disintegrates.
- **Light**: Ball starts tiny and grows bigger each enemy it hits — does more damage with each hit (ramping).
- **Spirit**: Starts at 1 projectile. Every cast increases the count up to 10, then resets back to 1.
- **Crystal**: If it hits a boss, instantly explodes for huge AOE damage.
- **Fire**: (3–8) fireballs shot out and travel fast.
- **Lightning**: (5–10) lightning orbs are placed on the map. Shock nearby enemies.
- **Steam**: Big geyser projectile travels and releases steam damage zones as it travels (similar to Lava-blob but steam-flavored).
- **Dark**: Bolt moves slowly through the field and constantly pulls enemies toward it, eating low-health enemies (execute).
- **Ice**: Ball freezes anything it touches as it travels.
- **Mud**: First enemy hit, ball breaks apart and goes in 10 different ways.
- **Water**: Projectile is a massive wall of water that brings enemies with it (carry/sweep effect).
- **Plant**: Every enemy passed through is temporarily rooted. If enemy dies while rooted, explode into AOE damage. (Plant kept its existing root + explode design — this matches current code.)

**Why:** User shared the Mane design board during the family-rework sequence after pip/wing/horn were already reworked. The existing `_maneSpecial` flavors had distinct named techniques per element (Tidewall Crash, Bloodedge Rush, etc.) — many already match these intents but several need rework.

**How to apply:** When auditing or modifying any mane special, verify the current code delivers the listed behavior. The shared shape is "one big piercing projectile" — element layers the unique behavior on top. Tune damage/visuals freely but do NOT change *what* the per-enemy effect is.

Related: [[project-pip-specials-design]], [[project-wing-specials-design]], [[project-horn-specials-design]], [[feedback-performance]].


---

## Wing

Wing family theme: **Beams**. All Wing specials shoot a laser/beam. The element layers a targeting or effect behavior on top. Source: hand-drawn design board the user shared 2026-05-28.

Per-element intent (must not stray from this):

- **Air**: blows back enemies hit by the beam
- **Dust**: surrounds enemy with dust; disorients them so shooter enemies fire at other enemies instead of the player
- **Lava**: laser leaves a glowing scar on the ground/path; enemies passing/standing through take damage
- **Poison**: shoots laser all around creating a poison ring around the map perimeter
- **Blood**: laser locks onto the lowest-health enemy and executes (% or low-HP threshold)
- **Earth**: standard laser — additionally, the orb also fires a laser alongside the earth wing
- **Light**: if the beam kills an enemy, it "refracts" — splits into two smaller beams targeting nearby enemies for the remainder of the beam's duration
- **Spirit**: tethers the laser to the ship; the ship then shoots its own laser at the nearest enemies
- **Crystal**: laser damage heals the orb (lifesteal-to-orb)
- **Fire**: sweeps a beam in a circle around the map; big damage
- **Lightning**: charges for a duration, then unleashes one big blast of heavy damage
- **Steam**: laser kills first enemy it touches and creates 5–10 steam clouds that DoT
- **Dark**: PASSIVE — dark wing pulses its laser; both the laser and the dark wing's auto-attacks fire twice as fast
- **Ice**: beam builds up frost on target; if held on long enough enemies freeze
- **Mud**: permanently slows enemies the beam touches
- **Water**: targets lowest-health ally or ship and heals % of max HP; also damages enemies along the beam
- **Plant**: enemies killed turn into flowers; collect flowers to power up the plant wing

**Why:** User explicitly said "make sure we don't stray from what the ability is written to do" when reviewing pip specials, and is now applying the same audit to wing specials.

**How to apply:** When auditing or modifying any wing special, verify the current code delivers the listed behavior. Tune damage/visuals freely but do NOT change *what* the targeting/effect contract is. Related: [[project-pip-specials-design]], [[feedback-performance]].


---

## Mask

Mask family theme: **Traps**. Each special scatters or places one or more trap fixtures across the field. The element determines what the trap does on enemy contact / over time. Source: hand-drawn design board the user shared 2026-05-29.

Per-element intent (must not stray from this):

- **Air**: Throws out 3–25 (stat-based) air traps that blow back enemies on contact.
- **Dust**: Surrounds each alchemon in the field with a dust cloud that shields them and damages enemies who collide.
- **Lava**: Throws out 5–15 lava pools that DoT enemies who walk through them.
- **Poison**: Scatters poison clouds dealing DoT to enemies in them.
- **Plant**: Places a small vine. Every time the ability is cast, feeds the vine and it gets bigger. Attacks enemies and slows.
- **Blood**: Throws out a blood blob. Enemies that go through it permanently have life drained to all alchemons until those enemies die.
- **Earth**: Creates 2–5 earth heal pools that heal the ship or alchemons standing in them.
- **Light**: Throws out a light void. Remains until an enemy collides. On collision, instantly kills that enemy.
- **Spirit**: Scatters spirit wisps. Ship collects them; once a certain count is reached, nukes all enemies (not bosses).
- **Crystal**: Throws out 3–7 (stat-based) large crystals. If enemies collide, each crystal breaks into 3 smaller crystals. Does damage.
- **Fire**: Throws out 5–15 fire balls. If a ball collides with an enemy, creates a fire pool that DoTs.
- **Lightning**: Throws out a lightning field that increases in size for each enemy that hits it. Does DoT.
- **Steam**: Throws out mini geysers around the field that shoot at enemies.
- **Dark**: Throws out a void hole. Enemies that enter are sent out of the area (yeeted). Hole's suction radius scales with stats.
- **Ice**: Throws out a giant ice pillar. When ship/alchemons are near it, their strength increases (~2×–5× damage buff).
- **Mud**: Throws out a mud pool that slows enemies.
- **Water**: Throws out traps; when enemies collide, splash damage.

**Universal shape**: scattered placements (not a single projectile). Each placement is a trap or aura that activates on enemy contact, persists as a damage zone, or buffs allies. Unlike Let's "one big meteor" or Mane's "one piercing projectile," Mask scatters many things.

**Why:** Continuing the per-family design-audit workflow started with pip/wing/horn/mane/let. User shared the Mask design board after locking in those five families.

**How to apply:** When auditing or modifying any mask special, verify the current code delivers the listed trap behavior. The shared shape is "scattered traps" — multiple placements (counts vary by element). Tune damage/visuals freely but do NOT change *what kind of trap* each element places (a Lava-mask must remain a DoT pool, not a heal pool, etc.).

Related: [[project-pip-specials-design]], [[project-wing-specials-design]], [[project-horn-specials-design]], [[project-mane-specials-design]], [[project-let-specials-design]], [[feedback-performance]].


---

## Horn

Horn family theme: **Bulky Defense Tank**. The cast pattern depends on the element — heavy charge, wind-up dash, always-on passive, or stationary channel. Not a uniform "shield + charge" shape like the legacy design; the new design lets each element pick the structure that fits its identity. Source: spec the user iterated through 2026-05-29.

Per-element intent (must not stray from this):

- **Fire**: Charges through enemies, painting a burning trail of DoT zones along the dash path. Trail patches taunt + burn.
- **Lava**: Slow heavy charge with a glowing build-up telegraph. Enemies killed by the slam explode into homing flames that seek nearby targets (only spawn flames when there are nearby targets to seek).
- **Lightning**: Quick dash to target → 3s storm brews around the horn (movement locked, alchemical particle storm) → discharges as a chain shockwave. Damage taken during the dash + brew is absorbed and amplifies the final blast (`hornLightningAbsorbed × 1.4` added to chain `effectPower`).
- **Water**: Charges in a circular sweep around the cast point (one full revolution over ~1s), then drops a whirlpool at the center that pulls and slows trapped enemies.
- **Ice**: Dashes SIDEWAYS perpendicular to the enemy direction. Paints an ice wall segment-by-segment along its path (`_spawnIceWallSegment` every 0.05s). Each segment taunts, slows, and reflects enemy projectiles.
- **Steam**: Heavy slam drops a steam geyser at impact. If the slam KILLS an enemy: `specialCooldown` resets to 0 AND another geyser spawns at the kill site. Streak through enemies → chain-cast.
- **Earth**: Heaviest tank. Impact leaves a high-HP substitute clone (decoy) that taunts and pulses periodic mini-earthquakes via the `zoneDamage` tick effect.
- **Mud**: PASSIVE — drops slowing sludge sigils wherever the horn moves. Interval scales with intelligence (1.45s at stat 3.0 → 0.58s at stat 5.0). Disabled while `comp.tethered` (magnet-to-ship recall).
- **Dust**: Impact creates a dust cyclone that pulls nearby enemies inward (`tickEffect: pull`) and disorients shooter-enemies (they fire at each other via `friendlyFire`).
- **Crystal**: 1.2s wind-up gathers 6 crystal shards orbiting the horn, then standard dash. Shards have `followSourceCompanion: true` so they orbit the moving horn through the dash and after impact. Each intercepts 2 enemy projectiles, then shatters into shrapnel (death explosion) on expiry.
- **Air**: PASSIVE — enemies near the horn are continuously pushed radially outward toward the arena's outer ring. 90px inner deadzone (so the horn can melee enemies inside it), 230px outer aura with falloff. Visualized by outward-flying wind particles.
- **Plant**: Charges through enemies. Each surviving enemy hit gets `hornPlantRootTimer = 3.0s` — immobilized and wearing a green vine-wrap visual on its sprite. No AoE zone — root only fires on direct hits.
- **Poison**: Active charge applies a heavy poison DoT to each enemy the dash sweeps through (40% elemAtk × 4.5s). Also has a continuous passive toxic aura that ticks poison damage to enemies within 140px every 0.6s.
- **Spirit**: 2.0s wind-up where phantom particles swarm the horn (movement locked, 60% damage reduction). On dash, 6 mobile phantom wisps release outward in a ring, drifting at ~0.32 speed and taunting enemies for their lifetime. Damage reduction persists through the dash.
- **Dark**: 5.0s void-suck wind-up — enemies within 260px are dragged toward the horn each frame (pull speed ramps 90 → 310 px/s over the wind-up). Then a fast dash (2.10× speed, +380px overshoot) toward the original fire direction (map edge). Captured enemies (snapshotted at wind-up completion within 200px) teleport to the dash destination and take `chargeDamage × 1.2`.
- **Light**: NO ram. Stops moving and channels a stationary light barrier for ~5s (scaled by stats via beauty `shieldVisualScale`). Barrier reflects enemy projectiles at the visible perimeter, bounces enemies that touch the edge back outward (90 px/s knockback), and allies inside take 30% incoming damage (70% reduction).
- **Blood**: No taunt. Sacrifices 18% of current HP on cast and adds `(sac × 0.25)` to `chargeDamage`. Every kill during the post-cast `hornSpecialActiveWindow` (~5s) heals back 5% max HP.

**Cooldown rule:** `specialCooldown` does NOT tick while a horn ability is mid-execution (wind-up, charge, post-dash wind-up, or Light barrier active). It only starts counting down after the ability fully finishes.

**Why:** User explicitly asked for this audit when verifying the design ("lets make sure their descriptions match the abilities though"). The legacy descriptions in `cosmicFamilySpecialInfo` Horn case described an entirely different (now-abandoned) design — replaced wholesale to match the new spec.

**How to apply:** When tuning or visually reworking any horn special, verify the current code delivers the listed behavior. Tune damage/visuals freely but do NOT change *what* the structural pattern is (charge vs wind-up vs passive vs channel) without flagging it. Related: [[project-pip-specials-design]], [[project-wing-specials-design]], [[feedback-performance]].


---

## Kin

Kin family theme: **Rare Support**. Kin are the user's RAREST creatures and should feel legendary / build-defining when drafted. Each one provides a unique support utility — no overlap with Horn/Mask/Mystic/Wing equivalents. Source: design conversation 2026-05-30.

**Universal shape (every Kin):**
- Heals the caster (% of caster maxHp, scales with Beauty)
- Some heal the ship too (Light/Water/Crystal/Steam carry the strongest ship-heal)
- Casts a Blessing buff on allies (duration + HP-per-tick over time)
- Spawns the element-specific signature piece (varies wildly per element — that's the identity)

**Each Kin gets ONE ability path (not 2).** An earlier brainstorm proposed roguelike Support/Attack branching unlocked via a power-up meter, but that was scrapped — Kin is single-ability per element.

**Per-element signature (must not stray from this):**

- **Light**: Heal escort orbs. Orbs orbit caster, migrate to the ship, intercept enemy projectiles, and continuously heal the ship/orb in their path. *Iconic priest-healer; current implementation is already correct.*
- **Water**: Rain cloud that follows the ship. Drips HP to all allies under it as it travels. *Mobile/vertical metaphor — distinct from Horn's whirlpool (ground control) and Mask's splash traps.*
- **Plant**: Healing garden placed at ally footing — over its lifetime drops collectible HP flowers the ship harvests. *Harvest pattern, mirrors Wing+Plant flower-collect mechanic.*
- **Earth**: Stone barrier wall. Physical wall enemies cannot path through. No HP — times out. Pure cover/terrain. *Distinct from Horn's substitute decoy (which takes hits and dies) — this wall just blocks.*
- **Air**: Updraft column attached to the ship. Moves with the ship; enemies cannot path through it (lifted up and pushed away). Anti-melee bubble. *Distinct from Horn's passive radial blow-back and Mask's static knockback pads.*
- **Fire**: Phoenix orb save. Once per cast, if the orb dies during the buff window, it instantly recovers to ~25% HP with a fiery rebirth animation. **After the save triggers, the Fire kin gets an ongoing orbiting flame orb** that damages enemies who get near, for the remainder of the cast duration. *Reactive miracle save + post-trigger reward.*
- **Lava**: Molten plate — reactive armor on ship + companions. When struck, splashes burning lava back at the attacker. *Spike-armor "counter" — punishes incoming melee.*
- **Ice**: Charged radial frost. Kin holds still to charge; on release, all-direction frost burst slows enemies hit by **90%** for a duration. Range scales from local → **global at max stats** (high-stat caster freezes the whole field). Slow magnitude is fixed at 90%; range and slow duration scale with stats.
- **Steam**: Boiler — damage taken by ship/allies converts into stacking companion attack-speed boost. **Cap at 10 stacks** (max +50% AS at base, scales with Beauty). Every ~8% maxHP damage taken = 1 stack. Stacks decay slowly when no recent damage. Buff duration scales with Intelligence. *Stress-into-tempo lever — uniquely rewards staying in danger.*
- **Crystal**: Prismatic refractor shards. Equips the ship with N orbiting refractor shards. Each absorbs one incoming enemy projectile and refracts it back at the sender as a damaging beam. *Defensive equip with counter-attack.*
- **Lightning**: Tesla charge. Kin holds the charge actively. While charging, the ship is buffed so its (and companions') auto-attacks chain to nearby enemies. **Charge time equals buff duration 1:1** — hold 3s → buff lasts 3s after release. Releasing early ends the charge and starts a shorter buff. *Active engagement: longer hold = longer buff, but kin is locked in.*
- **Dust**: Field-placed dust clouds. First cast places 1 cloud at the target; each subsequent cast adds another (persistent placements that accumulate across casts, similar pattern to Mask+Plant vine growth). Projectiles entering any cloud have a chance to miss (or fully miss). *Field-control — player chooses placement to build dodge corridors.*
- **Mud**: Ship enchant. Kin slings mud onto the ship; ship gains a temporary buff that causes it to leave a slowing mud trail as it moves. *Enchant pattern — the kin gives the ship a temporary movement trail ability.*
- **Poison**: Releases a swirling burst of poison darts that fire out in all directions, each homing on nearby enemies. *Scattered offensive — defensive area control via mass crowd-poke.*
- **Spirit**: Releases a wisp companion that grows tier-by-tier off enemies the Spirit kin's auto-attacks kill. Tiers unlock progressively:
  - Tier 1: passive flight, glows softly
  - Tier 2: gains taunt aura (draws enemy aggro)
  - Tier 3: gains a basic auto-attack of its own
  - Tier 4 (top tier): heals the Spirit kin for a portion of damage the wisp deals
  Wisp persists until killed (or until Spirit kin dies). *Growing companion mechanic — pattern is similar to Mask+Plant vine but the wisp is a flying companion, not a rooted plant. Kills must come from the SPIRIT KIN's auto-attacks (not other allies) — they're feeding their own spirit.*
- **Dark**: Void cloak — for the cast duration, companions become untargetable. Enemies retarget to the ship (or wander) and cannot lock onto companions. *Pure aggro redirect — protects squishy DPS allies.*
- **Blood**: Blood pact — for the cast duration, % of damage taken by any alchemon is converted into healing distributed across the other living alchemons. *Internal team blood share — "we bleed together, we heal together."*

**Why:** Continuing the per-family design-audit workflow. Kin is the 7th family redesigned (after pip/wing/horn/mane/let/mask). User considers Kin their RAREST creatures and wanted creative, unique, build-defining tools rather than generic "damage zone with a heal pulse" wards (which is what most of the prior Kin implementation was).

**How to apply:** When auditing or modifying any kin special, verify the current code delivers the listed support. Each Kin has a distinct **mechanic-shape** (follow / equip / charge / reactive / passive aura / wake / aggro shift / growing companion / etc.) — preserve that shape. Tune damage/visuals/durations freely but do NOT change *what kind of support* each element delivers (a Lava kin must remain reactive splash armor, not a heal pool, etc.).

**Mechanic-shape distribution (for variety auditing):**
- Follow auras: Light, Water, Air
- Terrain placements: Earth, Plant, Dust
- Equip/reactive armor: Lava, Crystal, Ice
- Active charge: Ice, Lightning
- Passive conversions: Steam, Blood
- Periodic auras: Fire (post-revive flame), Poison
- Reactive one-shots: Fire (phoenix), Spirit (growth-companion gate)
- Aggro shift: Dark
- Wake trail (ship enchant): Mud
- Growing companion: Spirit

Related: [[project-pip-specials-design]], [[project-wing-specials-design]], [[project-horn-specials-design]], [[project-mane-specials-design]], [[project-let-specials-design]], [[project-mask-specials-design]], [[feedback-performance]].
