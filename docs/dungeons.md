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

**THE DESCENT RIDDLE (built):** species choice is REASONED, never guessed —
every layout carries a `riddle` (one verse line per entry slot). AUTHORING
RULE: hint the ideal family **by its dungeon VERB, never its body part** (no
"wings/horn/mane/mask/small one" — that reads the answer aloud). The
decoding language, consistent across planets: Wing = "those the ground
cannot keep" / "shepherds the wind" · Mask = "sight that pierces the
hidden" / "second sight" / "reads ash as scripture" · Horn = "where the
grip is strongest" · Mane = "greens along a wild thing's passing" / "a cold
that paves a road behind it" (the trail) · Pip = "what my smallest doors
admit". Shown at the planet ("— the planet whispers —" card) on the
descent-party chip and above DESCEND until the planet is 3-starred.
Layout-test enforced (riddle length == entry slots). Author one for every
planet.

**PERFECT IS CLEAN, VALID IS SLOW AND LOUD (built):** the right family acts
instantly and silently; the wrong family pays in TIME and in NOISE — the
consequence layer hears it. Built examples: a non-Pip tide-valve turn waits
~5s on groaning pipes AND draws brine wisps at once (a Pip is instant +
silent); off-family vine growth rustles the ash awake (a Mane grows clean);
off-family/recipe pool-freezes rouse the brine (a Mane lays ice clean); a
non-Horn conduit channel holds only HALF as long. Kin's one-touch guardian
calm and Wing's traversal dominance are INTENTIONAL — Kins and Wings are
legendary creatures; their power is the rarity payoff, never nerf-target.

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

## 5.5 STRUCTURAL UNIQUENESS — the anti-template mandate

**The problem, named honestly:** after five builds the macro-skeleton has
fossilized. Every planet so far is literally
`gate → court/hub → three star wings → signature-gated vault room → sealed
finale → guardian heart` (compare the room ids: `tide_gate → drowned_court →
… → pearl_vault → leviathan_depths` vs `boiler_gate → pressure_court → … →
gauge_vault → escapement_engine → boiler_heart`). A signature MECHANIC alone
does not make a unique planet — if the map, the flow, and the vault trick
repeat, the planet is a reskin with a different verb. Steam made this visible;
the mandate below stops it from happening again.

**What stays invariant (the game's grammar — engine/test-enforced, do NOT
vary):** 3 stars · Star 3 = the mystic guardian · the rite gate behind Stars
1+2 · exactly one `vaultCache` · one Lost Maxim egg · a mercy shrine · the
descent riddle · the eased entry reveal. These are the sentence structure.
Everything else is the sentence — and must be written fresh each planet.

**Three axes MUST differ from every already-built planet:**

1. **TOPOLOGY — the shape of the map.** No more hub-and-spokes by default.
   Each planet claims a distinct room-graph archetype (see table below); a
   topology, once used, is TAKEN. The archetype should EMBODY the element —
   the map itself is part of the theming.
2. **THE STRATEGIC QUESTION — the decision that defines the run.** Every
   planet names ONE trade-off the player must reason about (not execute —
   DECIDE): route order, a global resource budget, what to sacrifice, when to
   commit. If a planet's stars can each be solved by walking to the room and
   doing the mechanic, there is no strategy — only sequence. Steam's
   choose-your-breach ("breaching a wet section floods your own chamber") is
   the model: the DECISION is the puzzle.
3. **VAULT CONCEALMENT — a different KIND of trick every time.** "Side room
   behind a signature-gated door" is retired. The cache keeps its invariant
   (exactly one, layout-test enforced) but how it hides must be novel:
   inside a hazard, a map state that must be induced, plain sight but
   unreachable until a sacrifice, only existing in one world-state, etc.

**Authoring checklist — answer IN THIS DOC before writing any layout code:**
- Which topology archetype does this planet claim, and is it untaken?
- What is the strategic question, in one sentence with a trade-off in it?
- How is the vault hidden, and which previous vault trick does it NOT repeat?
- Which verbs do previous planets already own (see the Steam NOTE in §6 —
  keep that ledger growing), and what does this planet own that they don't?
- Which structural convention are we deliberately breaking this time
  (no hub? no wings? no static rooms? no fixed star locations?)

### Structural assignment table — all 17

Topology archetypes are claimed here so no two planets collide. Built planets
keep what shipped; **Steam is flagged for a structural pass.**

| Planet | Topology (claimed) | Strategic question | Vault trick |
|---|---|---|---|
| **Air** (built) | Vertical spire, hub-and-spokes | which trial order suits my trio | behind the loom (shipped) |
| **Fire** (built) | Linear procession w/ side chapels | interpret the rite's order from two hint layers | reliquary behind the rite (shipped) |
| **Water** (built) | Hub + wings, but rooms CHANGE with tide state | which tide stand to settle, and when | low-tide-only passage (shipped) |
| **Earth** (built) | The map IS a body — anatomy as architecture | hunt the scale's answer through rooms you've walked | beyond the chasm, needs the ribs (shipped) |
| **Steam** (built) | Pressure ring-main: NO hub — a clamped boiler loop spending one global pressure budget | junctions cost 15 from a head of 40 — pick a direction; cooling condenses fuel back, stoking pays in wisps | vent the WHOLE main (≥60) into a burst-disc — the sacrifice must be whole (shipped) |
| Lava | Foundry line: one long production line the player re-routes | limited molten pours — what do you cast, in what order | cast a key whose mold is hidden elsewhere on the line |
| Lightning | Ring circuit: rooms wired in a literal loop; door states follow circuit state | powering one arc of the ring unpowers the other — where do you break the circuit | walk the DEAD segment in the dark (only reachable unpowered) |
| Mud | Shifting field: one huge open bog, no fixed rooms — islands whose connections you terraform | every path you harden sinks another — shape the map you'll have to live with | let the vault knoll SINK, ride it down to the drowned level |
| Ice | Vertical shaft: descending is one-way slides; ascending must be engineered | plan the descent so you can climb back — refrozen slides are your only ladder | visible only in a mirror; enterable only from a slide you can't repeat |
| Dust | Buried city, two Z-layers: streets above, excavation below; digging swaps layers | conservation of dust — uncovering one thing buries another | a fully buried building visible only as a roof bump on the streets |
| Crystal | Rearranging 3×3 sliding grid — sliding moves rooms AND you | every slide solves one adjacency and breaks another | a room that only ENTERS the grid in one configuration |
| Plant | Nested scales: the same map at tiny and huge, overlaid | which scale to be, where — passages exist at one scale only | visible at huge scale, enterable only at tiny |
| Poison | Quarantine wards: sealed wards; opening one lets the contagion in | you cannot cure every ward — choose what to sacrifice | inside the ward you chose NOT to save |
| Spirit | Two overlaid worlds: living/ghost layers, same geometry, different doors | which layer to cross each junction in — deaths in one open doors in the other | exists only in the ghost layer, marked only in the living one |
| Dark | Inverting maze: light/dark flips swap walls and doors | every flip you make for a door closes one elsewhere | the vault room only EXISTS in the dark state |
| Light | One great hall: no corridors — light beams partition the space into moving "rooms" | aiming light builds paths AND exposes you — illuminate as little as possible | stands in plain sight; reachable only through un-lit ground |
| Blood | Systole loop: a figure-eight of veins around the heart; surges circle it on the beat | move WITH the pulse or against it — timing is the map | reachable only in the flatline window between beats |

## 6. Per-planet matrix

Format: **Entry** · ideal team · *world rule*; Star 1 / Star 2 / Star 3; key recipe.

1. **Fire — Cinder Cathedral** · Fire+Air+Plant · Firemask/Airwing/Plantmane ·
   *fire remembers the order it was lit.* **(BUILT)**
   Entry: Fire rekindles the cold narthex hearth (one-time reveal). S1 (Ember
   Star) the choir's **6** braziers lit in the remembered, non-spatial order;
   two hint layers — a CRYPTIC FLOOR MURAL at the choir's heart (broken soot
   path + a faint ember that endlessly walks the true order; patient eyes can
   decode it unaided, Mask insight brightens path/pips) and the scriptorium
   soot mural as the explicit key (Mask insight, Int-tiered; reading in the
   choir caps at tier 1); a wrong flame snuffs the rite + ash wisps. S2 (Ash
   Star) cloister beds: Plant grows vines (Mane = perfect), Fire burns them
   (**Plant+Fire→Dust**) revealing groove sigils; every burn breathes out 3
   cinder wisps, escalating to unstable pouncers from the 3rd sigil; PARITY:
   a Dust creature lays ash directly. S3 (Pyre Star), behind the chancel
   gate: Fire lights a censer — the ash rises to smother it AT ONCE (ignite =
   instant wisp wave; the rite is tended under attack) — the vesper flame
   crawls and starves between censers, Air gusts carry it (Wing strongest,
   Speed-scaled; censers = re-ignite checkpoints; a starved flame = a bigger
   unstable fury wave); 3 ember bells → Simurgh (calm or defeat) in the
   sanctum. Mercy shrine = high altar. Rooms: narthex, nave (hub, rose window
   + star vigil lights), scriptorium, choir, cloister, reliquary, vestry,
   bell_gallery, high_altar, sanctum.
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
4. **Water — Mirror-Tide Temple** · Water+Spirit+Ice ·
   Waterpip/Spiritmask/Icemane · *every chamber answers one temple-wide tide —
   and the tide MOVES (animated floods/drains, never a teleport).* **(BUILT)**
   Entry: Water fills the dry offering-bowl. Tide system: `tideLevel` 0/1/2
   with `tideAnim` easing (~2.3s per stand; a live tide gauge on screen);
   basins drain to walkable floor / flood to swimmable water (non-Water swims
   at 0.62×), LEDGE walls sink under the swell (swum over at high; emergence
   drifts caught creatures to footing), tide-gated doors only answer a
   SETTLED tide. Master valves = any Water creature (Pip instant, others a
   sluggish 1.4s gurgle); pipe-mouths elsewhere cycle one stand, PIP ONLY.
   S1 (Tide Star) three sluice seals, one per stand: drained basin, mid
   walkway, swum-over high ledge (+brine wisps per seal). S2 (Current Star)
   the ghost gallery: eddies are INVISIBLE until any Spirit creature's
   insight bares the current (Mask longest, Int-tiered: next eddy → full
   course → order pips); wade five in order, a later eddy mid-sequence
   scatters it + ghost wisps. S3 (Deep Star), behind the mirror gate: at
   settled MID tide freeze the two TRUE moon-pools (Spirit insight names
   them) — Ice direct (Mane cleanest) or **Spirit+Water→Ice** (recipe rouses
   brine); false pools SHATTER + fury wisps; both bridged → Leviathan (calm
   or defeat). Mercy = moon well. The pearl vault hides behind a low-tide-only
   passage. Rooms: tide_gate, drowned_court (hub, moon + star vigil),
   tide_works, ghost_gallery, pearl_vault, reflection_court (egg), moon_hall,
   moon_well, leviathan_depths.
5. **Ice — Frozen Observatory** · Ice+Light+Air · Icemane/Lightmask/Airwing ·
   *the solution is visible only through reflection.*
   S1 Icemane freezes floors; slide star-blocks into orbit sockets. S2 Lightmask
   reveals star lines through telescopes (reflection shows truth). S3 Airwing
   redirects cold winds; **Ice+Light→Air**, **Air+Ice→Water**; solve before mirrors thaw.
6. **Steam — The Molten Labyrinth** · Steam+Earth+Fire · Steampip/Earthhorn/Firemask ·
   *the boiler holds only so much — spend the ring wisely.* **(BUILT — first
   planet under the §5.5 mandate: topology = PRESSURE RING-MAIN, no hub.)**
   The map is a closed loop — south manifold → west Ember Causeway (S1) →
   north manifold → east Cinder Forge (S2) → back south — around the central
   Crucible (rite) with the furnace-heart beneath it. THE ECONOMY: the main
   starts at 40 pressure; each of the 4 ring junctions costs 15 to unclamp
   (layout-test-enforced: the whole ring can never be bought up front).
   Cooling lava CONDENSES +4/cell back to the main — the flood is also fuel;
   Fire STOKES a firebox +20 but the roar draws wisps (fireboxes in both
   manifolds, so an empty main is never a softlock). VAULT: a riveted
   burst-disc etched "60" in the south manifold — the only way in is to VENT
   THE WHOLE MAIN in one surge (≥60; below that the valve refuses and takes
   nothing). Death re-clamps the ring (puzzle state). Tile star mechanics
   kept: S1 choose-your-breach dam (wet faces glow, sealed pockets, dry slot
   threads through), S2 bunker-before-melting sanctuary, rite = bunker/break/
   quench band gates. Pressure gauge with a burst-disc tick always on the
   HUD. Egg: Hidden Harmony (zero scalds) unchanged. Rooms: boiler_gate,
   manifold_south, ember_causeway, manifold_north, cinder_forge, crucible,
   burst_vault, boiler_heart.
   Each star room is a tile grid of sleeping lava cisterns that WAKE the moment
   Fire breaks rock (**Earth+Fire→Lava**): Fire melts walls to lava, Steam cools
   lava to stone (breath-metered), Earth dams the creep. S1 choose-your-breach:
   the causeway wall is a dam — wet sections glow with ember cracks (molten
   behind; breaching them floods your own chamber), one is dry. S2 bunker the
   sanctuary gate BEFORE melting it. Rite: break the crucible band, quench the
   source, take the pedestal → Boilrog.
   NOTE for future builds — verbs Steam now owns: "cool lava into paths"
   (Lava planet must lean into CASTING/molds instead), tile wall raise/remove
   (Mud's reshaping should drag/flow terrain), tile-flood spreading (Poison's
   spread must behave differently — pulses, or spreading the antidote).
7. **Earth — The Buried Giant** · Earth+Lightning+Crystal ·
   Earthhorn/Lightningpip/Crystalmask · *the dungeon IS a buried body —
   rooms are anatomy, the bones are the machinery.* **(BUILT)**
   Entry: Earth raises the fallen lintel. S1 (Marrow Star) the rib hall:
   three fossil ribs on carved tracks — TRACK-NOTCH shoves (user-chosen over
   free physics): each shove is an animated grind one notch along the
   groove (direction follows which side you stand); a rib is a solid wall
   anywhere except settled in the chasm groove (last notch), where it drops
   in and becomes walkway; Horn = clean 0.9s, off-family Earth = 2.4s +
   bone wisps; the marrow chasm is impassable until bridged and the sternum
   plate beyond banks the star once all three lie true. S2 (Crystal Star)
   the pillar crypt: four buried sockets — Lightning arcs them and the lock
   grows as crystal (**Earth+Lightning→Crystal**). Each socket must CHARGE
   (an animated fill ring + gathering storm-crackle) before it lights, and
   the charge ROUSES THE MARROW AT ONCE — the consequence wave spawns on
   charge START, so the player DEFENDS the socket until it completes: Pip =
   fast charge (~2s) + light wave; off-family Lightning = slow charge (~4.5s)
   + heavier/unstable wave; PARITY: Crystal sets a fast direct charge; the
   completed charge blooms the crystal (grow animation). S3 (Heart Star),
   behind the rite-shut jaw: the giant's crystal eye is BLIND — its pupil
   TRACKS the active creature (the giant watches you) — until the player
   BUILDS IT A LENS on the bare plinth in its
   sightline: Earth raises a stone core, Lightning's arc crystallises it
   (**Earth+Lightning→Crystal**, the planet's own braid; Crystal sets it
   direct) → the GAZE PRISM stands, the pupil locks on, a gaze-beam
   refracts through it toward the scale. Four weights, left/right pans,
   only the giant's remembered arrangement balances — and the solution is
   ROLLED PER RUN (always two-sided; wikis can never spoil it). CRUCIALLY
   the answer is NOT noise: the giant's BODY remembers it — each stone's
   true pan is carved as a leaning bone-mark in a different chamber of the
   anatomy (skull→skull_antechamber, root→palm_hollow, geode→marrow_vault,
   seed→pillar_crypt), discoverable while exploring for the earlier stars.
   So Star 3 is a treasure hunt through the body you've walked, not binary
   search. The stones give NO feedback; the prism count ("n of 4 sit true")
   is VERIFICATION of what the marks already told (read only by communing at
   the prism). Crystal insight tier-2 glows each true pan (a shortcut); the
   scale's visible tilt follows PAN LOADING only (never leaks truth); every
   3rd toggle shakes crystal wisps loose; balanced → Terradon (calm or
   defeat) in the heart-chamber, whose great heart visibly starts BEATING.
   Mercy = eye chamber. The marrow vault hides beyond the chasm. Rooms:
   barrow_gate, sternum_court (hub, rib-arch vault + star vigil), rib_hall,
   marrow_vault, pillar_crypt, palm_hollow (egg), skull_antechamber,
   eye_chamber, heart_chamber.
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

MYS01 Simurgh=Fire (built: 6×512² frames, 1 row) ·
MYS02 Leviathan=Water (built: 4×512² frames, 1 row) ·
MYS03 Terradon=Earth (built: 4×512² frames, 1 row) ·
MYS04 Roc=Air (built) · MYS05 Boilrog=Steam · MYS06 Magmara=Lava ·
MYS07 Raikuma=Lightning · MYS08 Bogdrya=Mud · MYS09 Frowyrm=Ice ·
MYS10 Ashdjinn=Dust · MYS11 Prismalith=Crystal · MYS12 Botanica=Plant ·
MYS13 Blightfang=Poison · MYS14 Wraithord=Spirit · MYS15 Noctryos=Dark ·
MYS16 Solarin=Light · MYS17 Sanguorath=Blood.

### Vault caches (one per planet, +5 gold once — built for Air/Fire/Water/Earth)
Every dungeon's treasure room (relic chamber / reliquary / pearl vault /
marrow vault — each gated behind that planet's signature mechanic) holds
the planet's BOTTLED ESSENCE: an element-tinted shimmer with orbit-motes
over the shrine. Walking to it makes the essence FIZZLE INTO THE AIR (a
rising mote burst in the element's colour, no blast) and grants **5 gold,
once ever** — `cache:<element>_vault` on the persisted discovery channel;
the screen pays the gold in `_onCloudDiscovered`. The claimed shrine keeps
its art but loses the shimmer. AUTHORING RULE: every future planet's vault
room declares `vaultCache` (layout-test enforced: exactly one per dungeon).

### Easter eggs — the Lost Maxims (one per planet, +20 gold once)
Every dungeon hides ONE difficult secret with little-to-no hint: a lost
maxim that pays **20 gold, once ever**. Plumbing (built): the discovery
rides the persisted cloud-discovery channel with an `egg:` id; the dungeon
screen pays the gold + toast the first time the id lands
(`_onCloudDiscovered`). Authoring rules: hard to stumble into, at most one
oblique hint, prefer ADVANCED element combos beyond what the stars demand,
and the maxim itself is the fanfare (long hint, public-domain quote).

1. **Fire — Ember Epitaph (BUILT):** the dead words live in the soot mural
   panel's upper half as a near-invisible MIRROR-CIPHER (every word written
   backwards — decodable, hidden). Mask insight makes an ember-quill WRITE
   the cipher in, line by line (still scrambled — insight bares the writing,
   not the meaning), then the garden planter settles in below. Plant fills
   it → Fire lights it → THREE gusts of Air swell the blaze until a
   burn-front consumes the cipher and UNSCRAMBLES it into fire-script that
   stays lit forever — and the planter flame keeps its full height: *"Death
   is nothing to us. When we exist, death is not; and when death exists, we
   are not."* (Epicurus). Entirely WORDLESS — no hint popups at any step
   (cached TextPainters, clip-reveal + burn-front animation; the mural shows
   no placeholder smudges — unread glyphs are simply absent).
2. **Air — First Wind (BUILT):** with all three stars banked, commune at the
   exact heart of the hub compass — the Roc's first-wind memory. PERMANENT
   completion state (persisted with the discovery): the hub mechanism wakes
   for good — the compass spokes turn forever, the four rune pillars ride a
   slow perpetual orbit of the hub, and three gust-heads endlessly circle
   the compass trailing arc streaks.
3. **Water — Frozen Moon (BUILT):** at the settled MID tide only, a faint
   glint drifts on the reflection-court pool; Ice laid exactly on it freezes
   the moon's reflection — a permanent ice disc with frost cracks, forever.
   One oblique hint (Mask in the room: "the pool remembers the moon best
   when the tide stands between"). *"Nothing is softer than water, yet
   nothing better overcomes the hard."* (Lao Tzu)
4. **Ice — Star-Walker:** align every telescope on the unmarked 13th star —
   visible only in reflection. *"When I trace the circling courses of the
   stars, my feet no longer touch the earth."* (Ptolemy)
5. **Lightning — Thunderbolt:** power EVERY door of the overload maze inside
   one charge window. *"The thunderbolt steers all things."* (Heraclitus)
6. **Steam — Hidden Harmony (BUILT):** finish the whole labyrinth — the rite
   included — without the molten ever swallowing your footing: zero scalds,
   one run. *"The hidden harmony is better than the obvious."* (Heraclitus)
7. **Earth — The Giant's Palm (BUILT):** the giant's open fossil hand lies
   in the palm hollow, far off the puzzle path; a Crystal creature laying a
   crystal in it earns the maxim — the crystal takes root in the palm
   forever. One oblique hint (Mask in the room: "the hand lies open… and
   misses it"). *"Loss is nothing but change, and change is Nature's
   delight."* (Marcus Aurelius)
8. **Lava — Black Glass:** quench the casting font mid-pour three times —
   the spoiled keys cool into a black-glass mirror. *"All things are an
   exchange for fire, and fire for all things."* (Heraclitus)
9. **Mud — No Mud, No Lotus:** plant a seed in the DEEPEST sink-pit, water
   it, and let it sink utterly — it re-blooms. *"From the deepest mud grows
   the lotus."*
10. **Dust — Nothing Perishes:** reveal, then sweep away (Air) EVERY ancient
    footprint in the ruins. *"All things change; nothing perishes."* (Ovid)
11. **Crystal — Know Thyself:** stand all three creatures inside one split
    prism beam at once — it casts their merged reflection. *"Know thyself."*
    (Delphi)
12. **Plant — The Unseen Shade:** at tiny scale, tend the seed hidden under
    the giant root until it towers at huge scale. *"Plant trees whose shade
    you will never sit in."*
13. **Poison — The Dose:** one sick wisp wanders the monastery; cure it with
    an antidote instead of a blade. *"The dose alone makes the poison."*
    (Paracelsus)
14. **Spirit — Stuff of Dreams:** stamp the minimap on your OWN position —
    the grave that replays is yours. *"We are such stuff as dreams are made
    on."* (Shakespeare)
15. **Dark — The Abyss:** stand utterly still in the total-darkness chamber
    for a full minute, casting no light. *"When you gaze long into the
    abyss, the abyss gazes also into you."* (Nietzsche)
16. **Light — Afraid of the Light:** cross the blinding maze revealing
    NOTHING — no light cast at all. *"The real tragedy is men who are afraid
    of the light."* (after Plato)
17. **Blood — The Blood Is the Life:** strike the heart-drum in sync with
    the dungeon's pulse for twelve straight beats. *"The blood is the
    life."* (Stoker)

### Signature mechanic summary
Fire=ritual order · Lava=cast/cool · Lightning=living circuit · Water=tide states ·
Ice=reflection · Steam=molten flood containment · Earth=buried giant · Mud=reshaping maze ·
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

### Campaign difficulty scaling (built)
Dungeon enemies — and ESPECIALLY guardians — scale with the campaign clock:
`clearedGuardianCount` = how many OTHER planets' guardians (Star 3) have
fallen (0..16), computed by the screen via
`PlanetStarState.guardiansDefeated(excluding: element)` and passed into the
game. Stats run 0–5.0, so the curve stretches from "first dungeon, mid-bred
trio" to "seventeenth dungeon, near-perfect team":
- **Guardian HP** ×(1 + 0.45·n) → ≈8.2× at n=16; **damage** ×(1 + 0.12·n)
  → ≈2.9× (lethality comes from the longer fight, not one-shots); the rage
  aura DPS scales with the damage mul.
- **Lull strikes to fell the guardian**: 4 + 0.75·n → 16 strikes by the
  last dungeon (the strike chunk is maxHp-fractional, so HP alone wouldn't
  lengthen the strike path).
- **Wisps / raid adds**: HP ×(1 + 0.22·n), damage ×(1 + 0.07·n).
- **Raids** stack their own 3×/1.5× on top — late-campaign raids are brutal
  by design. Replaying an early dungeon late in the campaign IS harder (the
  clock is global). Tests: `planet_dungeon_scaling_test.dart`.

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
- ✅ Elemental background shaders (Air + Fire + Water + Earth built; 13 to
  add via config + `.src.frag`).
- ✅ **FLOOR TRANSLUCENCY RULE:** room floor body fills stay at alpha
  ≈ 0.50–0.60 (like Air's islands) so the per-element shader atmosphere
  glows THROUGH the stone — the shader is the room's mood; never paint
  over it with near-opaque floors. (Fire + Water corrected from 0.88/0.94.)
- ✅ **ANIMATED-STATE RULE (no instant pops):** every puzzle/architecture
  state change EASES, it never snaps. The reference bar is Earth's entry
  (the dolmen heaves up as beveled masonry over ~1.6s + strewn rubble + dust
  kicks). Concretely: (1) entry rites share the `_entryReveal` 0→1 timer
  (advanced once for ALL planets in `update` via `_updateEntryReveal`, snapped
  to 1 when loaded already-open, `_entryRevealPrev` lets a planet fire one-shot
  FX as it crosses a threshold) — Fire kindles, Water fills, Air ignites, Earth
  rises; (2) locks/mechanisms GROW or build (Earth crystal locks `easeOutBack`,
  gaze-prism core-rise→crystal-grow, eased scale-beam tilt); (3) solids are
  drawn as MASONRY — shadow + body + lit bevel + outline (`_drawDolmenStone`),
  never thin floating lines or hard rectangles; (4) consequence layers are
  ACTIVE where it earns it (Earth crypt: a socket CHARGES with a fill-ring +
  storm-crackle and looses its wave AT charge start, so the player defends it).
  AUTHORING RULE: when building a new planet, give its entry/rite/lock the same
  eased, kindle-style polish — budget the animation work, don't ship a boolean
  flip. (Memory: keep per-frame cost low — prefer eased draw-time interpolation
  + threshold-gated bursts over per-frame particle spam.)
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
- ✅ **Engine genericized (roadmap step 5)**: `DungeonLayout` now declares its
  identity — `title`/`descentTitle`, `DungeonStarSpec` (star names + earn
  announcements + hidden `revealDoors`), `entranceRevealDoor`, `finaleDoor` +
  `riteAnnouncement`/`finaleSealedHint`, `mercyShrineRoomId`. The engine
  composes all copy/door gating from these (no Air room ids left in
  `isDoorHidden`/`isDoorLocked`/`earnStar`); the full-map atlas, section auras
  and room labels are per-element maps in `dungeon_minimap.dart`; guardian
  descend/enrage copy is per-mystic. The raid arena inherits authored titles.
- ✅ **Fire — Cinder Cathedral built** (see §6 entry 1): layout + new data
  verbs (`RitualBrazier`/`brazierStarIndex`, `VineBed`/`vineStarIndex`,
  `IncenseChain`), puzzle logic + rendering in
  `planet_dungeon_game_fire.dart` (a `part of` the engine file: extension
  shares private state; Fire-only fields live in the main class behind
  `_isCathedral`). Visuals: fire shader (smoke veils, rising embers,
  breathing hearth-light), cathedral stone floor + crimson runner + ember
  veins, per-room landmarks (rose window, soot mural, braziers, ash-garden
  sigils, sagging incense chains, black-flame altar, scorched roost), ember
  drift + ember ambient motes, per-room moods. Simurgh wired into
  `_guardianSheets` + `kRaidGuardianIds` (raid-eligible). Entry trio
  `Fire+Air+Plant` in `kCosmicPlanetEntry`. Tests:
  `planet_dungeon_fire_full_run_test.dart` (full 3-star headless run incl.
  wrong-order consequence + rite-lock checks) + layout integrity extended
  to brazier orders / beds / chains / layout door refs.
- ✅ **Water — Mirror-Tide Temple built** (see §6 entry 4): the ANIMATED tide
  is the headline engine addition — `tideLevel`/`tideAnim` global state, tide
  zones (basins + sinking ledge walls) wired into movement/collision, swim
  speed, tide-gated doors with settled-tide rules, a live screen-edge tide
  gauge. New data verbs (`TideValve`/`TideSeal`/`GhostEddy`/`MoonPool`/
  `TideZone`/`TideDoorRule`), logic + rendering in
  `planet_dungeon_game_water.dart` (part-file pattern, `_isTemple` guard).
  Visuals: water shader (caustic web, god-rays, rising bubbles), animated
  basin/ledge water surfaces, drowned-court moon, ghost-eddy spirals, moon
  pools that freeze into cracked ice discs, kelp arena. Leviathan wired
  (sheets + raids + enrage copy). Frozen Moon egg built. Tests:
  `planet_dungeon_water_full_run_test.dart` (animated-flood asserts,
  pip-only valve gate, tide-door lock/unlock, false-pool shatter, recipe
  freeze, egg) + layout integrity extended to all tide verbs.
- ✅ **Earth — The Buried Giant built** (see §6 entry 7): track-notch rib
  shoves (`FossilRib` + `_RibSlide` animated grinds, side-dependent
  direction, solid-except-bridging collision, chasm + sternum plate),
  socket arcs (`FossilPillar`, Pip clean / sluggish pending-arc / Crystal
  parity), the stone scale (`StoneScale`/`ScaleWeight`, counting-feedback
  logic puzzle, insight truth-glow, beating heart). Logic + rendering in
  `planet_dungeon_game_earth.dart` (part-file pattern, `_isBarrow`).
  Visuals: earth shader (sediment strata, seismic pulse, crystal glints,
  sifting dust), translucent bone-ochre floors, rib-arch hub vault, marrow
  chasm veins, vertebra pillars, the eye + pivoting scale, the beating
  heart, dust-sift atmosphere. Terradon wired (sheet + raids + enrage).
  Giant's Palm egg built. USER DEVICE-TESTED Air/Fire/Water — good.
  Tests: `planet_dungeon_earth_full_run_test.dart` (animated-grind asserts,
  clean-Horn no-wisps, Crystal parity lock, rite-locked scale, egg,
  guardian+relic, off-family slow-and-loud penalty) — 163 dungeon tests
  green. **The Nexus 4-relic gate (Air/Fire/Water/Earth) is now fully
  buildable in-game.**
- ⬜ More Mystic guardian sprites for future planets (map in
  `_guardianSheets`, enroll in `kRaidGuardianIds`; roster in §6).
- ⬜ The other 13 planets' signature mechanics.

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
5. ✅ **Genericize the Air-hardcoded engine bits** — done (see §8): layouts
   declare titles, star specs (names/announcements/reveal doors), entrance
   reveal + finale doors, sealed-door copy, mercy shrine; minimap atlas and
   labels are per-element; guardian copy is per-mystic.
6. **Planets one at a time**, reusing the framework; each adds its signature
   mechanic. ✅ **Fire (Cinder Cathedral)** · ✅ **Water (Mirror-Tide
   Temple)** · ✅ **Earth (Buried Giant)** — the Nexus 4-relic gate is
   complete. NEXT: Lightning/Dust/Steam/Mud →
   Plant/Poison/Ice → Crystal/Spirit/Dark/Light/Blood (hard). When building
   the next planet, follow Fire's pattern: new data verbs in
   planet_dungeon_data.dart, a `part` file for the planet's logic/rendering
   (planet-only fields in the main class behind an `_is<Planet>` guard),
   per-element minimap atlas entries, shader `.src.frag` + config + pubspec,
   `_guardianSheets`/`kRaidGuardianIds`, entry trio, and a full-run test.
   **Hook the entry into the shared `_entryReveal` timer with an eased,
   kindle-style reveal (see §8 ANIMATED-STATE RULE) — no instant pops.**
   **AND: before any layout code, complete the §5.5 anti-template checklist —
   claim the planet's topology from the structural assignment table, name its
   strategic question, and design a novel vault trick. `gate → hub → three
   wings → vault → finale → heart` is retired as a default.**
7. **Combat-core extraction (before the kin specials port / next ability
   batch):** the per-hit resolver layer exists as near-identical copies in
   survival and the dungeon (and open space has its own variant). Extract to
   `lib/games/shared/` like enemy_flight_steering, with per-mode adapters
   (heal target: orb vs creature; arena vs room clamp; particle sink; kill
   rewards). FIRST write characterization tests around survival's hit
   pipeline (it has no headless harness — the dungeon does) so the
   extraction can't silently change live behavior. This is what turns
   "identical today" into "identical by construction".
