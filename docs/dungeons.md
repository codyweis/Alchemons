# Alchemons — Planet Dungeons: Design & Plan

The master reference for the 17 planet dungeons. **Vision + framework + per-planet
matrix + build roadmap.** Keep this in sync as we build.

---

## 1. Vision

Each element has a planet; each planet is a 3-star dungeon (Mario-64 style: enter
with the right creatures, earn stars by solving distinct puzzles, bank rewards on
exit). Every planet has a **signature mechanic** so it has its own identity, not
just a recolor.

## 2. Core framework

The cleanest, most scalable model — separate **element identity** from
**family utility**:

- **Element = the power** (Fire, Air, Lightning, …). Gates entry; drives recipes.
- **Family = the interaction method** (Pip/Mane/Horn/Mask/Wing/Kin/Mystic).
- **Stats = quality** (Speed/Intelligence/Strength/Beauty → hint quality, speed,
  duration, stability).
- **Recipe = alternate solution** (an element combo solves a puzzle a different,
  usually messier way).

Design interactions per **Element + Family**, not per individual creature.
Special-case only Kin, Mystic guardians, and signature planet puzzles.

## 3. Family interaction roles

| Family | Dungeon ability | Interacts with |
|---|---|---|
| **Pip** | `smallAccess` | pipes, vents, tiny doors, inner machinery, hidden tunnels |
| **Mane** | `terrainTrail` | dash paths, element trails, temp bridges, terrain shaping |
| **Horn** | `heavyForce` | breakable walls, heavy gates, blocks, conductors, plates, seals |
| **Mask** | `insight` | runes, murals, ritual order, truth/lie, hidden doors, map pings |
| **Wing** | `aerialTraversal` | wind rings, updrafts, floating islands, aerial switches, shafts |
| **Kin** | `ancientStabilize` | ancient machines, cores, relic vaults, guardian seals (rare, not mandatory) |
| **Mystic** | `guardianRelic` | planet guardian / optional boss / relic protector (NOT a normal tool) |

## 4. Interaction Quality System

Every puzzle object evaluates the active Alchemon:

- **Perfect** = correct element **and** correct family (instant / best).
- **Valid** = correct element, wrong family (works, slower/weaker).
- **Weak** = recipe workaround (element combo) — works but with a downside
  (spawns wisps, raises a hazard meter, etc.).
- **Failed** = no valid element / family / recipe.

This keeps clears flexible while rewarding breeding the ideal mon.

## 5. Implementation model

Terminology: the **four stats are Speed, Intelligence, Strength, Beauty**
(never "Power" — "power" only ever means an element's role). Mystics are NOT in
the interaction model; they use a separate guardian-encounter type.

```dart
enum DungeonAbility {            // family interaction method
  smallAccess,      // Pip
  terrainTrail,     // Mane
  heavyForce,       // Horn
  insight,          // Mask
  aerialTraversal,  // Wing
  ancientStabilize, // Kin
  guardianRelic,    // Mystic (not used as a normal requirement)
  none,
}

class DungeonInteractionRequirement {
  final String element;             // required element
  final DungeonAbility? preferred;  // best family (null = any family = Perfect)
  final bool allowWrongFamily;      // element ok, wrong family → Valid
  final bool allowRecipe;           // element-combo → Weak
  // Soft stat gates (1..5; 0 = none). Quality (element/family) and stat-
  // sufficiency are separate: a creature can be the right element+family yet
  // still need more of a stat to act at full power.
  final double minSpeed, minIntelligence, minStrength, minBeauty;
  bool meetsStats(CosmicPartyMember m);
}

// Mystics kept OUT of the requirement model — a guardian declares this instead.
class GuardianEncounterRequirement {
  final String element;
  final String mysticId;   // 'Roc' (Air), 'Simurgh' (Fire), …
  final bool canCalm;      // Beauty/Kin path
  final bool canDefeat;    // strike path
}
```
`evaluateInteraction(member, req, {recipeAvailable})` returns
`Perfect | Valid | Weak | Failed` (element/family). **Stats are orthogonal:**
`meetsStats` gates, and the pure tunables (`glideSeconds`, `revealHintTier`,
`channelHoldSeconds`, `charmOk`, …) scale OUTPUT magnitude
(low-Int Mask = vague clue → high-Int = ghost outline; low-Str Horn = slow →
high = instant; high-Speed Wing = longer glide). Recipes = `dungeonRecipeResult`
table of element-combo results.

> **Status:** built — `planet_dungeon_verbs.dart` has `DungeonAbility` (7),
> `evaluateInteraction`, the recipe table, the `min*` stat gates, and
> `GuardianEncounterRequirement`. Air is wired through it (conduit channel is
> quality-graded; guardian = Roc encounter).

## 6. Per-planet matrix

Format: **Entry** · ideal team · *world rule*; Star 1 / Star 2 / Star 3; key recipe.

1. **Fire — Cinder Cathedral** · Fire+Air+Plant · Firemask/Airwing/Plantmane ·
   *fire remembers the order it was lit.*
   S1 light 4 braziers in ritual order (Firemask reads it). S2 Plantmane vines →
   Fire burns them to ash revealing floor symbols (**Plant+Fire→Dust**). S3 Airwing
   sends flame through incense chains to ring 3 ember bells → black-flame guardian.
2. **Lava — Molten Reliquary** · Lava+Earth+Ice · Lavahorn/Earthmask/Icemane ·
   *lava can be cast into keys/bridges/monsters.*
   S1 Lavahorn casts the right key shape per gate. S2 Icemane cools lava paths;
   **Ice+Lava→Steam** powers vault pistons (timed: platforms crack). S3 Earthmask
   reads tectonic runes to seal vents → lava-pressure maze.
3. **Lightning — Storm Circuit** · Lightning+Air+Fire · Lightninghorn/Airwing/Firepip ·
   *the dungeon is a living circuit.*
   S1 Lightninghorn charges pylons; rotate conductor mirrors to route power. S2
   Airwing moves cloud echoes + Firepip heats Anvil (**Air+Fire→Lightning**) →
   Thundercloud. S3 overload maze (powered doors open/unpowered close) → guardian.
4. **Water — Mirror Tide** · Water+Spirit+Ice · Waterpip/Spiritmask/Icemane ·
   *every room has 3 tide states.*
   S1 Waterpip enters pipes to set low/mid/high tide (changes doors/platforms). S2
   Spiritmask reveals invisible ghost currents to follow. S3 drain/flood/freeze a
   chamber; **Spirit+Water→Ice**, Icemane freezes correct pools into bridges.
5. **Ice — Frozen Observatory** · Ice+Light+Air · Icemane/Lightmask/Airwing ·
   *the solution is visible only through reflection.*
   S1 Icemane freezes floors; slide star-blocks into orbit sockets. S2 Lightmask
   reveals star lines through telescopes (reflection shows truth). S3 Airwing
   redirects cold winds; **Ice+Light→Air**, **Air+Ice→Water**; solve before mirrors thaw.
6. **Steam — Pressure Cathedral** · Steam+Fire+Water · Steampip/Firemask/Waterhorn ·
   *pressure phases.*
   S1 Steampip opens valves to route pressure. S2 balance 4 gauges
   (**Fire+Water→Steam**). S3 *pressure clock* (Tick-Tock-Clock): enter the engine
   in the right phase (still/fast/reverse/slow).
7. **Earth — Buried Giant** · Earth+Lightning+Crystal · Earthhorn/Lightningpip/Crystalmask ·
   *the dungeon is a buried body.*
   S1 Earthhorn pushes fossil ribs into a bridge. S2 four fossil pillars
   (Shifting-Sand): **Earth+Lightning→Crystal** locks each → skull opens. S3
   Crystalmask reads the eye; balance stone scales → crystal wisps.
8. **Mud — Sinking Altar** · Mud+Plant+Water · Mudmane/Plantpip/Watermask ·
   *ground firmness changes everything.*
   S1 Mudmane crosses sinking mud leaving hard trails. S2 **Plant+Water→Mud**:
   soften ground for roots, firm for walking. S3 mud maze: reshape walls (Water
   softens / roots harden) to 3 altars; **Plant+Mud→Poison** dissolves seals.
9. **Dust — Ruins of Time** · Dust+Air+Earth · Dustmask/Airwing/Earthhorn ·
   *dust reveals the past and buries the present.*
   S1 Dustmask reads runes; rotate hourglass statues into locks. S2 **Air+Earth→Dust**
   reveals footprints/buried locks; Earthhorn breaks false walls. S3 four sinking
   obelisks → Hourglass Core opens → escape the collapse (dust wisps chase).
10. **Crystal — Prism Labyrinth** · Crystal+Lightning+Spirit · Crystalmask/Lightninghorn/Spiritpip ·
    *rooms can be rearranged.*
    S1 Crystalmask rotates prisms to match beam colors. S2 Spiritpip enters mirror
    cracks → reflection layer reveals doors. S3 *sliding 3×3 room grid* (Sky Keep):
    **Lightning+Crystal→Spirit**, **Crystal+Spirit→Light** awakens the prism guardian.
11. **Air — Wind-Crown Spire** · Air+Fire+Lightning · Airwing/Firemask/Lightninghorn ·
    *clouds are puzzle pieces.* **(PILOT — built; tuning pending)**
    S1 Airwing rides updrafts/crosswinds/wind rings to the spire top (movement). S2
    Sky Loom: EARN the wonder-clouds via per-chamber elemental trials —
    Spiral: ride 3 gale eddies in order (Air-friendly) · Ring: seal the orbit
    when the Air/Fire/Lightning reagent motes align (Mask widens the window) ·
    Anvil: crack the storm shell (Lightning strike, or **Air+Fire→Lightning**
    arc from the wind current) then defeat the spark trio · Feather: catch 3
    falling plumes (Air attracts them) · Veil: pin breathing shimmer-folds
    (Lightning pins from range, Fire flare reveals, Mask ghost-marks). Earned
    echoes go to star-anchors; **Air+Fire→Lightning** charges the Anvil into
    the Thundercloud → relic. PARITY RULE: anything the Air+Fire braid
    electrifies, a Lightning creature arcs DIRECTLY (entry rune, conduit B,
    the carried Anvil, the storm shell). S3 Storm Altar: Lightninghorn channels, Airwing
    stabilizes wind, Firemask reads storm-rune order; sync conduits → storm
    wisps + guardian (Roc).
12. **Plant — Verdant Crypt** · Plant+Light+Mud · Plantmane/Lightmask/Mudpip ·
    *tiny and huge scale states.*
    S1 Plantmane grows vine bridges toward redirected Light. S2 *Tiny-Huge Island*
    growth altar; relic needs both scales (**Mud+Light→Plant**). S3 **Plant+Mud→Poison**
    blooms dissolve cursed roots; Light purifies the central flower before it spreads.
13. **Poison — Venom Monastery** · Poison+Lava+Mud · Poisonmask/Lavahorn/Mudmane ·
    *every poison has a matching antidote.*
    S1 Poisonmask matches venom pools to doors. S2 Lavahorn melts seals, Mudmane
    carries venom (**Lava+Mud→Poison**) → corrodes vault (spreading hazard). S3
    antidote maze in fog; activate altars in order, Poisonmask spots real portals.
14. **Spirit — Echo Grave** · Spirit+Water+Crystal · Spiritmask/Waterpip/Crystalwing ·
    *the past replays but can't be changed directly.*
    S1 Spiritmask reveals a ghost route to memorize/follow. S2 *Phantom-Hourglass
    minimap stamp*: a room shows half a sigil, the minimap the other half — stamp at
    the right spot. S3 **Crystal+Spirit→Light**, **Spirit+Water→Ice**: freeze ghost
    bridges, align mirrors, make Light → spirit wisps.
15. **Dark — Eclipse Vault** · Dark+Poison+Spirit · Darkmask/Poisonpip/Spiritmane ·
    *darkness has shortcuts but moves the maze.*
    S1 Darkmask flips light/dark room states (bridges swap). S2 shadow-portal maze
    (Spirit reveals destinations, Poisonpip unlocks anchors). S3 extinguish every
    light (**Poison+Spirit→Dark**) → final door in total darkness.
16. **Light — Beacon Archive** · Light+Crystal+Spirit · Lightmask/Crystalmask/Spiritpip ·
    *light reveals truth but also exposes danger.*
    S1 Lightmask reveals truth/lie statues → pick the true door. S2 Crystalmask
    splits Light into bridges, Spiritpip activates machines. S3 blinding maze:
    reveal only the correct parts (**Crystal+Spirit→Light**).
17. **Blood — Sanguine Orrery** · Blood+Dark+Light · Bloodkin/Darkmask/Lightmask ·
    *the dungeon is alive and beats on a rhythm.*
    S1 Bloodkin stabilizes heartbeat doors (time movement). S2 route life-flow
    through correct veins (Darkmask reveals, Lightmask flags corrupted). S3
    **Dark+Light→Blood**: balance dark/light beams around the heart → guardian wave.

### Mystic guardian roster (Star-3 boss + raid boss per planet)
Verified against `assets/data/alchemons_creatures.json`; spritesheets in
`assets/images/creatures/mystic/MYSxx_*_spritesheet.png` (verify each sheet's
frame count/size before adding to `_guardianSheets` + `kRaidGuardianIds`).

MYS01 Simurgh=Fire · MYS02 Leviathan=Water · MYS03 Terradon=Earth ·
MYS04 Roc=Air (built) · MYS05 Boilrog=Steam · MYS06 Magmara=Lava ·
MYS07 Raikuma=Lightning · MYS08 Bogdrya=Mud · MYS09 Frowyrm=Ice ·
MYS10 Ashdjinn=Dust · MYS11 Prismalith=Crystal · MYS12 Botanica=Plant ·
MYS13 Blightfang=Poison · MYS14 Wraithord=Spirit · MYS15 Noctryos=Dark ·
MYS16 Solarin=Light · MYS17 Sanguorath=Blood.

### Signature mechanic summary
Fire=ritual order · Lava=cast/cool · Lightning=living circuit · Water=tide states ·
Ice=reflection · Steam=pressure clock · Earth=buried giant · Mud=reshaping maze ·
Dust=buried/revealed · Crystal=sliding rooms · Air=cloud constellation ·
Plant=tiny/huge · Poison=venom/antidote · Spirit=memory/minimap stamp ·
Dark=shadow portals · Light=truth/danger · Blood=heartbeat rhythm.

## 7. Star / reward loop (built)

Stars bank instantly on earn; cleared stars hide their objectives. On End Run a
reward popup grants once: **S1=10 gold, S2=5 random powerups, S3=the planet's
GUARDIAN RELIC (first time only, headline art) + choice of 25 gold / 10
powerups / 10 Instant Fusion Extractors**. (See `planet_dungeon_*`.)

### Guardian relics (replaces the retired turn-based Boss Gauntlet)
The relic economy moved here: defeating a planet's mystic guardian (Star 3)
grants `key.boss_trait.{element}` once per element. Relics still feed the
Mystic Altar (place relic + sacrifices → summon the element's mystic). The
turn-based boss feature is deleted; legacy `boss_progress` defeats migrate
their relics one-time on home-screen load (`_migrateLegacyBossRelics`). The
altar keeps the legacy `boss_NNN` slot ids so no save migration is needed
(`lib/data/mystic_altar_data.dart`).

### Timed raids (built — Air pilot)
A raid "takes over" a conquered planet (guardian beaten + gate unsealed) for a
real-time **24h window**; rotation auto-spawns one every **48h** on a random
eligible planet, and a **Raid Beacon** (`item.boss_refresh`, shop + boss
lootbox drop) force-summons one. While live: crimson corruption aura on the
planet, countdown chip in the cosmic HUD, and **ENTER RAID replaces DESCEND**.
The run is a generated one-room arena (`buildRaidArenaLayout`) — no puzzles,
guardian awake from spawn at **3× HP / 1.5× damage**, add waves at 70%/35% HP,
enrage beat unchanged. Victory → `RaidRewardPopup`: 3 rolls of the element's
boss lootbox + order-scaled silver/gold; raid marked cleared (persisted,
force-quit safe). Retreat/wipe keeps the window open for retries. State:
`cosmic_raid_state` + `cosmic_raid_next_rotation_utc` (SharedPrefs, UTC).
Files: `lib/games/cosmic/raid_state.dart`, `lib/services/raid_service.dart`,
raid branches in `planet_dungeon_game/screen`, CTA + chip in `cosmic_screen`.
Eligibility = `kRaidGuardianIds` (add an element only after wiring its mystic
spritesheet into `_guardianSheets`). Tests: `raid_state_test.dart`,
`planet_raid_arena_test.dart`.

### Star authoring principle — the shape of every dungeon
**Star 3 is ALWAYS the mystic guardian** (relic drop + raid eligibility key off
`guardian.starIndex == 2` — layout-test enforced). **Stars 1–2 are order-free
puzzles**, and the guardian rite is engine-gated behind both of them:
`guardianRiteUnlocked` (raids exempt, banked Star 3 exempt for legacy saves)
keeps the altar conduits inert and the storm door sealed until the pair is
banked, with hints naming the missing keys. The storm-door reveal fires when
the SECOND of the pair lands, whichever it is.

### Star authoring principle — keep each star FOCUSED
One **core mechanic** + one **consequence** + a **success**. Family/stat quality
are *modifiers*, not extra required steps. e.g. Air Star 3 = "sync the conduits
(core) → mistakes spawn storm wisps (consequence) → success awakens Roc," with
Lightninghorn/Airwing/Firemask making it smoother — NOT
rune-order+conduits+stabilize+recipe+guardian+wave all mandatory at once.

## 8. Build status

- ✅ Overworld gate flow: a gated planet's recipe is a ONE-TIME element
  offering ("UNSEAL GATE"). Success permanently unseals the planet (persisted
  in `cosmic_planet_gates_unsealed`) and reveals the descent-party
  requirements chip; DESCEND then needs only the carried trio, forever. The
  legacy planet pathway/summon-encounter flow is fully removed for gated
  planets — the dungeon IS their content.
- ✅ Dungeon chassis: rooms, swap-control, collision, fog/minimap, death/restart.
- ✅ **Element+Family ability framework**: 7 `DungeonAbility`, interaction-quality
  eval (Perfect/Valid/Weak/Failed), `min*` stat gates, recipe table,
  `GuardianEncounterRequirement`.
- ✅ Air pilot puzzles wired on the framework; quality-graded conduits;
  guardian = Roc (calm or defeat); cleared-star hiding; onboarding/room hints.
- ✅ Progression: Stars 1+2 freely interleavable (Mario-64 style); **the
  guardian rite is engine-gated behind BOTH of them** (`guardianRiteUnlocked`:
  altar conduits inert + storm door sealed until stars 1+2 are banked, hints
  name the missing keys, the storm-door reveal fires on whichever star lands
  second; raids and legacy star-3 saves are exempt). AUTHORING RULE enforced
  by layout test: Star 3 is ALWAYS the mystic guardian — exactly one per
  dungeon, no other star-2-index source, stars 0/1 earnable without it.
  Door pairs are orientation-consistent (descend → arrive at the top; a
  layout test enforces this for every planet).
- ✅ Elemental background shaders (Air built; 16 to add via config + `.src.frag`).
- ✅ Procedural look (shaders + drifting clouds + winged wisp guardian). NOTE:
  the PNG/TexturePacker atlas pipeline was built then **removed** by art-direction
  decision — Air is fully procedural. (Re-add `DungeonArt`/`DungeonAtlas` if PNGs
  are ever wanted.)
- ✅ Star tracker + earn animation + end-run reward popup; HUD decluttered.
- ✅ Enemy system: floaty hover/dive steering (orbit ring + telegraphed swoop,
  separation, nearest-living-creature targeting), wisps pursue through doors,
  death bursts. The steering machine lives in
  `lib/games/shared/enemy_flight_steering.dart` and is SHARED with cosmic
  survival (melee strikers/hunters on mobile targets) and open cosmic space
  (committed attack runs) via per-mode `FlightSteeringProfile` presets. Idle party members auto-fire basics (1.35× cooldown) when
  enemies are in range. Downed creature ≠ run reset: control auto-swaps and
  only a full wipe restarts. One unified Roc (combat body drives position,
  hit flash and a single HP pool; lull = burst window, rage = 0.35× ranged
  damage, lull strikes paced ~1.2s). Covered by
  `test/planet_dungeon_combat_test.dart`.
- ✅ Combat-ability parity with survival: horn wind-up→dash→burst (Water
  circle, Ice wall, Fire trail, Plant root, Poison DoT, Dark void-suck+slam,
  Lightning 3s brew, Blood sacrifice), kin charged-laser basics,
  Mane+Spirit stream stacking, Mane+Lightning scatter orbs→shock fields,
  Mask+Plant feedable vine, Mask+Dust ally auras, support effects
  (shield/heal/blessing/haste), snare fields slow dungeon enemies.
  EXCEPTIONS (ship/orb collection loops don't exist here): Mask+Spirit
  wisp pickups → plain projectiles; kin support paths; mystic environment
  washes. Covered by the `survival-parity abilities` test group.
- ✅ Audited end-to-end: `test/planet_dungeon_full_run_test.dart` plays a full
  3-star run headless with the authored trio (entry ignition → 3-ring ascent →
  complete loom incl. Thundercloud charge → conduit sync → Roc); layout tests
  assert door reciprocity, no-gap spawns, complete ring sequences, and
  in-room craftability of derived anchors / arc conduits.
- ✅ Polish pass: guardian renders its REAL Mystic sprite (Roc = MYS04,
  perches during the lull, sheds feathers on dives, half-HP screech beat);
  updraft columns lift WALKERS (no Wing hard-requirement — rings count while
  riding; thermal added to reach the feather door); per-room sky moods
  (summit bright, storm bruised, permanent dawn at 3 stars) + ambient wind
  streaks + hub constellation celebration; conduit drain-timer arcs +
  door-unlock reveal rings; idle creatures catch feathers; carried echoes
  trail wind and are torn loose by landed dives; rune-hall mural diagrams
  the conduit sync (Mask completes it); storm-altar mercy heal (once/run);
  hub-compass secret at 3 stars.
- ✅ **Guardian relic drop**: Star 3 grants the element relic once
  (feeds the Mystic Altar; turn-based Boss Gauntlet deleted — see §7).
- ✅ **Timed raids**: 24h takeover windows on conquered planets, 48h rotation
  + Raid Beacon summon, one-room arena reusing the dungeon engine, boss
  lootbox + currency rewards (see §7 "Timed raids").
- ⬜ More Mystic guardian sprites for future planets (map in
  `_guardianSheets`, enroll in `kRaidGuardianIds`; roster in §6).
- ⬜ The other 16 planets' signature mechanics.

## 8.5 Ability parity with survival — status

Casts share `createCosmicSpecialAbility`; the dungeon now also mirrors
survival's PER-HIT verb layer (planet_dungeon_game.dart hit loop):
hit sparks on every impact (`_spawnHitSpark`/`_spawnProjectileHitSpark`,
capped at 150 particles), mane per-element pierce verbs
(`_resolveAbilityPierce`: Air shove, Water-wall carry, Plant root tag,
Light growth, Lava blobs, Blood heal→caster's creature, Poison stacks,
Dark execute), pip ricochet bounce chain + poison web + final-hit water
splash + mud-trail tag (+ enemy-side puff dropper), Mane+Mud split, and
the horn charge-trail visual + landing spark. The generic pierce-damage
falloff was removed (survival has none).

KNOWN REMAINING GAPS:
- KIN SPECIAL UTILITIES: survival runs a custom per-element kin cast branch
  (cosmic_survival_game.dart ~6230: Ice charged release, Steam boiler stacks,
  Dust clouds, Mud ship enchant, Spirit wisp, Dark cloak, Earth equip...).
  Dungeon kin specials use only the generic builder. Lightning tesla IS
  ported (timer + chain trigger). This is the polish-pass headliner — port
  alongside the project_kin_specials_design contract.
- Wing+Earth orb mirror beam (orb-specific by design — intentionally absent).

CLOSED (ported to planet_dungeon_game.dart): taunt/decoy steering (beacons
hijack enemy steering by pull strength; decoys soak contact via decoyHp),
Kin+Lightning tesla cast, Horn+Lava wind-up ember telegraph, per-hit resolver
layer
(`_resolveAbilityHit`/`_resolveAbilityPierce`/`_resolveAbilityKill`), faithful
effect dispatcher (knockback scaling, root damage, stun cooldown, disorient,
geyser knock-up, pull/blackHole 0.18 execute, leech/buff/Mask+Ice amp), mask
trap contact dispatcher (Light void, Dark yeet, Crystal shards, Fire pools,
Lightning grow, Blood drain tag + per-frame drain healing the party), let
meteor on-hit verbs + aftermath zones + Dark child meteors + chain lightning,
kill-side verbs (`_onEnemyKilledByPlayer`: mane-root detonation, horn
Steam/Lava/Blood on-kill payoffs via `hornSpecialActiveWindow`, pip kill
placements, Pip/Mask Spirit streaks), hit sparks, charge-trail render, and
the `_damageEnemyDirect` funnel so every damage source fires kill verbs.

## 9. Roadmap

1. ✅ **Framework:** `DungeonAbility` (7) + `DungeonInteractionRequirement`
   (+ `min*` stats) + quality eval + recipe table + `GuardianEncounterRequirement`.
2. ✅ **Air polished** on the framework (quality-graded conduits, Airwing
   stabilize, Firemask read, Roc guardian calm/defeat, room hints).
3. ⏳ **Device tuning of Air** — the proof. Verify spire traversal, timers,
   animation feel. (Only thing between Air and "100%".)
4. ✅ **Enemy/wisp spawning** — the shared "consequence" layer (storm wisps
   etc.) with floaty hover/dive AI, idle auto-attacks and down handling.
5. **Dungeon #2 — STEP 0 first (≈half a day): genericize the Air-hardcoded
   engine bits** (~22 spots in planet_dungeon_game/screen):
   - `isDoorHidden`/`isDoorLocked` hardcode `'sky_loom'`/`'spire_summit'`/
     `'storm_rune_hall'` → each `DungeonLayout` should declare its shortcut
     door + finale door ids.
   - `earnStar` announcements hardcode "Wind Star"/"Sky Loom" copy and queue
     reveals for Air room ids → per-layout star names + reveal targets.
   - Descent intro title hardcodes `'WIND-CROWN SPIRE'` → per-element map
     (names in §6).
   - `kCosmicPlanetEntry` has only Air → add the new planet's trio (§6).
   - Verify the mystic spritesheet geometry, add to `_guardianSheets` +
     `kRaidGuardianIds` (one line auto-enrolls the planet in raids).
6. **Planets one at a time**, reusing the framework; each adds its signature
   mechanic. RECOMMENDED ORDER: **Fire → Water → Earth** first — those plus
   Air are the Nexus 4-relic gate, so each unblocks real progression (Fire
   also has strong recipe coverage + verb contrast vs Air). Then
   Lightning/Dust/Steam/Mud → Plant/Poison/Ice →
   Crystal/Spirit/Dark/Light/Blood (hard).
7. **Combat-core extraction (before the kin specials port / next ability
   batch):** the per-hit resolver layer exists as near-identical copies in
   survival and the dungeon (and open space has its own variant). Extract to
   `lib/games/shared/` like enemy_flight_steering, with per-mode adapters
   (heal target: orb vs creature; arena vs room clamp; particle sink; kill
   rewards). FIRST write characterization tests around survival's hit
   pipeline (it has no headless harness — the dungeon does) so the
   extraction can't silently change live behavior. This is what turns
   "identical today" into "identical by construction".
