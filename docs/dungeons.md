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

## 4. Interaction model v2 — ELEMENT OPENS, FAMILY UNLOCKS

**(DIRECTION CHANGE 2026-08-10 — supersedes the Perfect/Valid/Weak/Failed
quality ladder. v1 shipped in the first six planets; §9.0 is the refit.)**

The old ladder made family half-matter: any same-element creature could do
almost anything, just "slower and louder". That muddied both identities —
family requirements read as suggestions, and element identity got buried
under family-penalty noise. The new rule separates them cleanly:

- **ELEMENT interactions (the default — most objects).** The object needs an
  element, and ANY family of that element performs it identically, at full
  power. No off-family speed penalty, no off-family wisp noise, no "sluggish"
  animations. Element is the star of the show: valves answer Water, braziers
  answer Fire, sockets answer Lightning — whoever carries it.
- **FAMILY-GATED interactions (the marquee locks — rare and ABSOLUTE).** The
  object needs element + family (e.g. a Lightning HORN). Wrong family = clean
  refusal with one clear line — no slow path, no half-strength workaround.
  If a puzzle says Horn, only the correct Horn passes. These are the
  breeding hooks; there is no halfway.
- **RECIPES substitute for a missing ELEMENT, never a family.** An element
  combo (Air+Fire→Lightning) can stand in where an element is called for —
  with its authored downside (wisps, hazard meter) as the price of the
  workaround. A family gate can never be recipe'd around.
- **STATS scale magnitude; they don't create pass/fail middle grounds.**
  Glide length, hint tier, channel duration, charm threshold — quality of
  outcome, not a mushy second way to succeed. Hard `min*` stat gates are
  allowed on family-gated objects only, and failure must be surfaced.
- **Kin & Mystic unchanged.** Kin calm is an alternate RESOLUTION (defeat
  always exists), not a gate; Mystics stay out of the model entirely.

**Family-gate budget + discoverability (the anti-frustration contract):**

- Max ONE family gate per star, 1–3 per planet, each tied to one of the
  planet's three entry slots — the §6 ideal team is exactly the trio that
  clears everything.
- At least one star per planet must be earnable by ANY trio of the correct
  elements, so a first descent always progresses.
- **THE SEAL REMEMBERS:** first contact with a family gate permanently stamps
  the requirement onto the planet's descent panel as an explicit chip
  (element + family badge, e.g. ⚡ HORN). You learn it in-world once and the
  ship remembers it forever — no wiki, no blind re-runs. The verse riddle
  stays as flavor above the chips, never as the only signal.
- At the gate itself, refusal is one clear line ("Only a horn's force can
  shift this") — see §5.6 hint standard.

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
planet. **v2 note:** the riddle is FLAVOR, not the requirement UI — the
explicit descent chips (element always; family badge once discovered via
"the seal remembers") are the canonical signal.

**RETIRED (v1): "Perfect is clean, Valid is slow and loud."** The shipped
slow-and-loud penalty layer is exactly the half-assery v2 removes. The §9.0
refit converts every shipped instance to one of the two clean kinds —
**routine / repeated mechanics → element-only (full power for any family;
penalties deleted)** · **the one marquee lock per star → hard family gate
(refusal, stamped chip)**.

### The verified conversion inventory — 13 sites

**CODE-AUDITED 2026-08-10** (an earlier hand-written list here was ~43%
wrong on numbers/locations and missed 5 sites; this table replaces it and is
the authority). 8 sites go through `evaluateInteraction`; 5 are hardcoded
`ability ==` checks that bypass the framework entirely — the refit must
catch both kinds.

| # | Planet / star / object | Today (v1) | → v2 |
|---|---|---|---|
| 1 | **Air** S3 Storm Altar conduit A — `planet_dungeon_game.dart:5888` | Lightning Horn full hold; any other Lightning `hold * 0.5` | **HARD GATE** Lightning+Horn |
| 2 | **Earth** S1 marrow rib shove — `planet_dungeon_game_earth.dart:479` | Horn 0.9s clean; other Earth 2.4s + 2 bone wisps | **HARD GATE** Earth+Horn |
| 3 | **Water** S1 master valves — `_water.dart:305` | Pip instant; other Water **5.0s** delay (`_valveDelay`, NOT 1.4s) + 2 wisps | element-only, instant |
| 3b | **Water** pipe-mouth valve — `_water.dart:308` | already a clean hard Pip check, no fallback | **KEEP as HARD GATE** Water+Pip (the temple's stamped gate) |
| 4 | ~~**Water** S2 ghost-eddy reveal~~ | — | **RETIRED 2026-08-14** with the ghost gallery. Its replacement (the canal reading) is element-only Spirit with Int tiering, carrying the same rule forward |
| 5 | **Water** S3 moon-pool freeze — `_water.dart:454` | ⚠ off-family Ice AND the Spirit+Water recipe share ONE `q != perfect` wisp branch | **SPLIT the branch**: recipe keeps its wisps (v2-legal), off-family Ice loses them |
| 6 | **Earth** S2 socket charge — `_earth.dart:525` | Pip 2.0s/2 wisps; other Lightning 4.5s/3 unstable | element-only, one 2.0s charge; defend-wave stays for everyone |
| 7 | **Fire** S2 vine bed | off-family Plant spawns 2 wisps | element-only; the Fire-burn wisp ramp stays (unconditional). Survives the 2026-08-14 garden rework unchanged: growing is the anti-softlock verb, so it is never punished |
| 8 | **Fire** S3 vesper gust — `_fire.dart:621` | Wing push 120–190; other Air 70–110 | element-only, use the Wing formula (now 110–170, glided) |
| 9 | **Lightning** S1 pylon wake — `_lightning.dart:137` | Horn clean; other Lightning fewer particles + 2 unstable wisps | element-only |
| 10 | **Lightning** entry rite charge — `_lightning.dart:788` | Horn 8s window; other Lightning 4s + wisps | element-only, one 8s window |
| 11 | **Lightning** S2 cell deposit — `_lightning.dart:833` | non-Wing deposit spawns 2 unstable wisps | element-only |
| 12 | **Steam** Earth dam-wall raise — `_steam.dart:576` | self-labeled `// FAMILY-QUALITY`: Horn clean, other Earth "rough + racket draws wisps" | element-only |
| 13 | **Air** Ring wonder-trial — `planet_dungeon_game.dart:360` | Mask seal tolerance 0.72 rad vs 0.45 | element-only (SHIPPED). **The "or moot" note was wrong** — this is a Star 2 wonder-trial and Air's §9.1 rework left Star 2 alone; only Star 1's `SkyRing` sequence retired. Same word, different mechanic. |

**Citation caveat:** the line numbers above are from the pre-refit tree and
drift by 2–10 in several files; the identifications were all correct. One
audit claim was wrong: `planet_dungeon_game.dart:3786` ("the kin hums with
storm-charge") is a COMBAT special-ability hint, not an interaction-quality
branch — it was left alone.

**Corrections worth remembering** (the doc was wrong before the audit): the
Water valve penalty is **5.0s, not 1.4s**; Lightning's famous "8s Horn / 4s
other" decay gates the **entry rite** (`arc_gate`), *not* Star 1 — Star 1 is
a separate non-decaying latch (row 9), and the entry-rite window is **not** a
hidden Horn gate (220px to cross at 150px/s — 4s is ample), so it converts
cleanly; Fire's **brazier rite has no family logic at all** and needs no
conversion.

**Resulting gate budget — all planets legal:** Air 1 (S3) · Earth 1 (S1) ·
Water 1 (S1 pipe-mouth) · Fire 0 · Lightning 0 (its marquee gate is authored
during the §9.1 rework) · Steam 0. Every planet keeps at least one star
earnable by any correct-element trio.

**INTENTIONAL family exclusives — do NOT convert:** Kin's one-touch guardian
calm (`planet_dungeon_game.dart:6080`) · ~~Wing's `_tryStabilize` conduit
refresh (`:5869`, the solo-sync aid that keeps Air's gated altar solvable)~~
**— SUPERSEDED 2026-08-11 by Air's §9.1 rework: `_tryStabilize` is DELETED.**
It existed only to make a pair of DECAYING conduit timers beatable solo, and
the rework retired the timers (conduits latch; conduit B is struck by the
storm). Nothing else depended on it, and an exclusive that holds nothing up is
not an exclusive. · Mask's passive lava-creep forecast in Steam (informational
only, gates nothing). Kins and Wings are legendary; their power is the rarity payoff,
never a nerf target. Note the shape these share: a family-exclusive *bonus*
that no puzzle requires — that is always legal in v2; a family-exclusive
*penalty* never is.

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

// v2 TARGET (refit §9.0) — `preferred`/`allowWrongFamily` are retired:
class DungeonInteractionRequirement {
  final String element;                 // required element (always)
  final DungeonAbility? requiredFamily; // null  = element-only: ANY family of
                                        //         [element] acts at FULL power
                                        // non-null = HARD gate: this family or
                                        //         clean refusal. No middle tier.
  final bool allowRecipe;               // element-combo may substitute the
                                        // ELEMENT (never the family)
  // Hard stat gates (1..5; 0 = none) — family-gated objects only; failure
  // must be surfaced ("needs more Strength").
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
`passed | passedViaRecipe | blockedElement | blockedFamily | blockedStat`
(v1's Perfect/Valid/Weak/Failed ladder is retired — a `blockedFamily` result
is what fires the refusal line AND stamps the descent chip). **Stats scale
OUTPUT magnitude** via the pure tunables (`glideSeconds`, `revealHintTier`,
`channelHoldSeconds`, `charmOk`, …): low-Int Mask = vague clue → high-Int =
ghost outline; high-Speed Wing = longer glide. Recipes = `dungeonRecipeResult`
table of element-combo results — element substitutes only.

> **Status:** what's BUILT is the v1 ladder (`planet_dungeon_verbs.dart`:
> `InteractionQuality`, `allowWrongFamily`, quality-graded conduits, and
> slow-and-loud penalties across six planets). The §9.0 refit rewrites the
> enum + requirement to the shape above, converts every shipped interaction
> per the §4 inventory, and rewrites the tests that assert slow-and-loud
> behavior. `GuardianEncounterRequirement` is unchanged.

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
- Which mechanic-ledger rows are already claimed (see below), which fresh
  archetypes does this planet take, and what is each one's distinct visual
  grammar?
- Which 1–3 HARD FAMILY GATES does this planet declare (§4 — which star,
  which object, which element+family), and which star stays earnable by any
  trio of the right elements?

### Structural assignment table — all 17

Topology archetypes are claimed here so no two planets collide. Built planets
keep what shipped; **Steam is flagged for a structural pass.**

| Planet | Topology (claimed) | Strategic question | Vault trick |
|---|---|---|---|
| **Air** (built) | Vertical spire, hub-and-spokes | *(rework)* in what ORDER do I wake the winds — each one is permanent, and each is somebody's ladder and somebody's wall | behind the loom (shipped) |
| **Fire** (built) | Linear procession w/ side chapels | interpret the rite's order from two hint layers | reliquary behind the rite (shipped) |
| **Water** (built) | Hub + wings, but rooms CHANGE with tide state | which tide stand to settle, and when | low-tide-only passage (shipped) |
| **Earth** (built) | The map IS a body — anatomy as architecture | hunt the scale's answer through rooms you've walked | beyond the chasm, needs the ribs (shipped) |
| **Steam** (built) | Pressure ring-main: NO hub — a clamped boiler loop spending one global pressure budget | junctions cost 15 from a head of 40 — pick a direction; cooling condenses fuel back, stoking pays in wisps | vent the WHOLE main (≥60) into a burst-disc — the sacrifice must be whole (shipped) |
| **Lava** (built) | Foundry line: one long production line the player re-routes | limited molten pours — what do you cast, in what order | cast a key whose mold is hidden elsewhere on the line |
| **Lightning** (built; rework §9.1) | Hub dynamo + zero-sum branch circuit (the "ring" claim is retired — it shipped as a hub and Steam owns the ring; the loop promise is honored LOGICALLY: door states follow circuit state) | powering one trunk darkens the others — where does the power go, and what must you do in the dark | walk the DEAD segment in the dark: the vault only opens unpowered (rework) |
| **Mud** (built) | Shifting field: one huge open bog, no fixed rooms — islands whose connections you terraform | every path you harden sinks another — shape the map you'll have to live with | let the vault knoll SINK, ride it down to the drowned level |
| **Ice** (built) | Vertical shaft: descending is one-way slides; ascending must be engineered | plan the descent so you can climb back — refrozen slides are your only ladder | enterable only by falling onto its ledge off the head (the old "visible only in a mirror" glow was cut 2026-09-20) |
| **Dust** (built) | Buried city, two Z-layers: streets above, excavation below; digging swaps layers | conservation of dust — uncovering one thing buries another | a fully buried building visible only as a roof bump on the streets |
| **Crystal** (built) | Rearranging 3×3 sliding grid — sliding moves rooms AND you | every slide solves one adjacency and breaks another | a room that only ENTERS the grid in one configuration |
| **Plant** (built) | Nested scales: the same map at tiny and huge, overlaid | which scale to be, where — passages exist at one scale only | visible at huge scale, enterable only at tiny |
| **Poison** (built) | Quarantine wards: sealed wards; opening one lets the contagion in | you cannot cure every ward — choose what to sacrifice | inside the ward you chose NOT to save |
| **Spirit** (built) | Two overlaid worlds: living/ghost layers, same geometry, different doors | which layer to cross each junction in — deaths in one open doors in the other | exists only in the ghost layer, marked only in the living one |
| **Dark** (built) | Inverting maze: light/dark flips swap walls and doors | every flip you make for a door closes one elsewhere | the vault room only EXISTS in the dark state |
| **Light** (built) | One great hall: no corridors — light beams partition the space into moving "rooms" | aiming light builds paths AND exposes you — illuminate as little as possible | stands in plain sight; reachable only through un-lit ground |
| **Blood** (built) | Systole loop: a figure-eight of veins around the heart; surges circle it on the beat | move WITH the pulse or against it — timing is the map | reachable only in the flatline window between beats |

### Mechanic ledger — core star mechanics, claimed

Topology diversity (above) isn't enough on its own: the star PUZZLES must
also draw from different mechanic archetypes. A new star's CORE mechanic may
not repeat a ledger row — family/stat/consequence dressing does not count as
new. The ledger grows with every build:

| Claimed by | Core mechanics owned |
|---|---|
| **Air** | flow traversal (currents/updrafts) · set-collection constellation matching · **irreversible wind-authoring** (BUILT: gust shrines wake permanent gales that help AND hinder; the waking ORDER is the puzzle — CLAIMED: no other planet may hand the player a permanent world-edit whose ordering is the whole question) · **storm-steering by height-ranking** (BUILT: the bolt climbs one rank at a time, so the rod field must be a staircase) · **coherence composition** (BUILT 2026-08-14, the Gale Eye: a SET of irreversible edits that must agree with one another — no order, no sequence, just whether the four winds turn the same way) |
| **Fire** | sequence-execution / order-memory ritual under attack (CLAIMED — no other planet may hand a sequence to execute) · flame-relay escort between checkpoints · *(rework)* forensic-evidence deduction at the object itself (rolled per run) · **reagent transport / deposition planning** (BUILT 2026-08-14: a burn's PRODUCT travels downwind onto other beds, so the question is where a reaction lands, not what order you were told; distinct from Fire's own sequence row — nothing hands you an order, you author one from the wind and the cuts) |
| **Water** | global state machine (tide) that regates SPACE itself · **holding a live set-point against a one-way drift, where the value you must hit also sets the cost of reaching it** (DESIGNED 2026-08-31, the Moon Well — see §6; distinct from Fire's tended process, which is a spatial route through a consuming medium) · **piloting a drifting object by editing the world state that carries it** (BUILT 2026-08-14: the lantern is never touched — you move the TIDE it floats on, and a dam only ever removes a destination; CLAIMED: no other planet may steer a thing it cannot touch) ~~flow-graph ordering deduced from spin~~ (RETIRED with the ghost gallery — it played as arbitrary, and the seat is free again for a later planet) |
| **Earth** | track-notch sokoban shoves · clue-hunt logic deduction (answers carved into REMOTE architecture, rolled per run — the treasure-hunt variant; Fire's forensic variant reads the object itself) |
| **Lightning** | beam routing/reflection via rotatable mirrors (+ *(rework)* negative constraints, provably unique) · element STATIONING pads · decoy-pad deduction · *(rework)* zero-sum power routing (power here = dark there) |
| **Steam** | global resource economy (spend/condense/stoke one shared budget) · sacrifice-the-whole-budget vault |
| **Poison** (BUILT 2026-08-24) | **diagnosis-by-behaviour** (a strain is identified by how it MOVES, not by a label or a clue — CLAIMED: no other planet may make observation-of-motion the read) · **forced partial sacrifice** (a budget that provably covers all but one target, so the question is which one you abandon — CLAIMED, and distinct from Steam's spend-it-all: here the shortfall is structural and the choice is named) |
| **Ice** (BUILT 2026-08-24) | **reading a room only through a reflection whose content depends on WHERE YOU STAND** (the pool holds the quarter of sky opposite the party and nowhere else; the room is walked to be read, and what is learned is recorded across the ring from where it was seen — CLAIMED 2026-09-15; distinct from Poison's diagnosis-by-behaviour, which reads MOTION, and from Light's occlusion, where the player places the shadow) · **one-way descent with an engineered return** (traversal that consumes the route behind you; the ladder home is something you must have built on the way down — CLAIMED) · ~~treasure-or-ladder exclusivity~~ (RETIRED 2026-09-15: it was one hole with two doors, and played as "the same door sends me to two places". The ledge has its own chute now and nothing is coupled — the seat is free again for a later planet, and any taker must make the exclusivity VISIBLE) · costly full-state reset valve as the anti-softlock (a pattern, not a claim — reusable) · **footing that bears ONE body** (BUILT 2026-09-20, the roof of the hollow: bare ice over the lair holds one of the three, snow holds all, and LOOKING is what makes a pane thin — so information costs footing, and the party is split by where it may stand; CLAIMED: no other planet may make per-body load the constraint. Distinct from Light's exposure, which is a quantity you raise and lower at will, and from Steam's throws, which move one body but never limit where the others stand) |
| **Lava** (BUILT 2026-08-24) | **production-line re-routing** (program a path, then spend a limited fungible charge down it; what the charge BECOMES is decided by where it went — CLAIMED) · **the dual-purpose product** (the thing you cast is both a road and a plug, so ordering falls out of physics rather than instruction — this is how Lava stays out of Fire's order-memory seat; any planet reusing it must derive the order, never hand it over) |
| **Mud** (BUILT 2026-08-24) | **terraforming-as-map-authoring** (the player authors the EDGES, not the rooms; the question is the SHAPE left behind — CLAIMED, and deliberately ORDER-INDEPENDENT: A-then-B lands on the same fen as B-then-A, pinned by a test, which is what keeps it out of Air's ordering seat) · **drainage as the cost function** (hardening a crossing drowns its neighbours up- and downstream, so you choose what to KEEP and the physics decides what dies — distinct from Poison's triage, where you choose what to abandon) |
| **Dust** (BUILT 2026-08-24) | **conservation as the cost function** (one object owns every write, and every mutator is a PAIRED TRANSFER — dig here, heap there, atomically, so the total cannot leak; CLAIMED: no other planet may make a conserved quantity the puzzle) · **Z-layer swap driven by load count** (0 bared = the street is a pit and the cellar opens · 1 = plain street · 2 drifted = a dune-wall, and a ramp opens instead — the layer you are on is a CONSEQUENCE of the ledger, not a toggle; Spirit's living/ghost layer swap is a different reading and stays free) · **the inverted vault verb** (the buried house is the one thing digging cannot reach — you bury it HARDER until the weight cracks the wall) |
| **Crystal** (BUILT 2026-08-25) | **the self-rearranging map as a permutation group** (the 8-puzzle as architecture: nine fixed lattice cells, eight glass chambers and one hollow permuting through them, and the player rides or hauls — CLAIMED) · **REVERSIBLE world-edits** (the only built planet whose mechanic cannot strand, so it carries no reset valve; its risk is authoring an UNREACHABLE target, not a dead end) · **mutually exclusive stars** (Stars 0 and 1 are provably never holdable at once — 0 states — which is the strategic question expressed as a number) |
| **Plant** (BUILT 2026-08-25) | **scale as a property of the OBSERVER** (one geometry, seventeen passages, each cut for exactly one size of body; the ground never changes, you do — CLAIMED, and deliberately distinct from Dust's Z-layer, where the deck you are on is a consequence of a load ledger) · **scale-determined authorship** (a seed set by a huge hand comes up a creeper only a small body walks; set by a tiny hand it comes up a trunk only a giant walks — each product is a road for the size you were NOT, so the route dictates the product; distinct from Ice's treasure-or-ladder, where you choose between two uses of one edit) |
| **Spirit** (BUILT 2026-08-25) | **the living/ghost reading of two overlaid worlds** (one deck of rooms, two worlds over it; every crossing walkable in exactly one world — CLAIMED; Dust holds the Z-layer reading, Plant the observer-scale reading) · **death as an irreversible world-edit** (a revenant holds the ghost lintel up while the stone that killed them blocks the living way; hearing them out finishes the death, clears the living way and drops the ghost way — the doc's "deaths in one open doors in the other", verbatim) |
| **Dark** (BUILT 2026-08-25) | **state-flip maze inversion** (a GLOBAL flip rewrites the whole maze at once and every flip made for one door closes another — CLAIMED; distinct from Spirit, whose layers coexist and are chosen at a junction, and from Lightning's electrical zero-sum: this one is spatial) · **safety by additivity** (the only irreversible edits are portals that open and never close; an additive edit cannot shrink reachability, so it cannot strand — a reusable argument, not a claim) |
| **Light** (BUILT 2026-08-25) | **light-cone occlusion — the player places the SHADOW, not the beam** (nothing is aimed at anything; low pitch breaks on the great stacks and lights the rim only, and that shadow is the move — CLAIMED, and this is the line against Lightning's mirror-routing seat: the question is never "where does the beam go") · **exposure as an instantaneous, free-moving quantity** (lumens count lit cells and go up and down at will — NOT Steam's spend-budget — and the light is simultaneously the floor you walk on and the thing that reveals you) |
| **Blood** (BUILT 2026-08-25) | **rhythm/timing windows — the last seat, and the only planet whose state the player does not author** (a four-phase pulse runs free and unstoppable; a vein is a road only while blood is pushed through it, downstream only — CLAIMED) · **hidden in TIME** (the vault leaflet is held shut by pressure from either side, so it opens only in the pause between beats; no prior vault trick hides a room in time rather than space) · **the closed cycle as the safety argument** (a periodic system returns to every phase, so one-way passages are safe PROVIDED waiting is survivable everywhere — the lesser lobe never reverses, and opening it costs 272 strandable states) |
| **Nexus** (reserved) | RULE MANIPULATION — transmutation circles rewriting element bindings (the Baba Is You seat; no planet may touch it) |

**THE POOL IS EMPTY.** All seventeen planets are built and every archetype
in the original pool is claimed by exactly one of them. A new planet — the
reserved Nexus aside — would need a genuinely new core mechanic, not a
re-dressing of a ledger row.

~~one-way-descent route planning~~ (CLAIMED by Ice) ·
~~irreversible sacrifice choice~~ (CLAIMED by Poison — Mud must claim
terraforming-as-map-authoring instead, and must also differ from Air's
irreversible wind-authoring, whose ORDER is the question; Mud's question is
the resulting SHAPE) · ~~production-line re-routing + mold casting~~
(CLAIMED by Lava) · ~~terraforming as map-authoring~~ (CLAIMED by Mud — Dust
must claim CONSERVATION, the invariant that dust moved from here arrives
there, not shape-authoring; excavation and terraforming are close enough
neighbours that a cold author will reach for the wrong one) ·
~~conservation~~ (CLAIMED by Dust) ·
~~self-rearranging map / sliding rooms~~ (CLAIMED by Crystal) ·
~~scale shift tiny/huge~~ (CLAIMED by Plant) ·
~~two-overlaid-worlds layer swap~~ (all three readings now CLAIMED — Dust
Z-layer, Plant observer-scale, Spirit living/ghost) ·
~~state-flip maze inversion~~ (CLAIMED by Dark) ·
~~light-cone occlusion + exposure management~~ (CLAIMED by Light) ·
~~rhythm/timing windows~~ (CLAIMED by Blood).

**VISUAL GRAMMAR RULE:** every core mechanic gets its own rendering language,
distinct from every prior planet that shares a surface resemblance. Light's
soft volumetric cones must read NOTHING like Lightning's jagged bolts; Mud's
dragged/flowing terrain nothing like Steam's tile floods; Crystal's sliding
rooms nothing like Water's tide regating. If a new mechanic would look like
an old one in a screenshot, restyle it — or redesign it.

## 5.6 Hint & popup standard — one voice, element-first

The shipped hint layer grew organically (proximity ambient lines + stat nags
+ per-planet objective lines + toasts) and reads cluttered. This standard is
applied in the §9.0 refit and is MANDATORY for every new planet:

**AUDITED 2026-08-10 — ~280 surfaces, 265 of them direct hint calls.** Two
findings rewrote this standard: (1) roughly **80 of the 265 calls are not
narrative at all** — they are progress counters and control feedback that the
original three channels had no home for; (2) the OBJECTIVE channel is
currently leaking **complete solutions** (see the rule below). The standard
now separates the capsule from the readouts.

### THE ENTRY LINE IS AUDITED (2026-08-31)

The WHAT/HOW split is easy to cross by accident — a helpful second clause and
the puzzle is answered on the way through the door. A pass over every
`*ObjectiveHint` in all seventeen found four:

  · **Air / ring_cloud** — "seal the orbit WHEN the three reagents gather",
    and its refusal said the same thing again on a failed press.
  · **Air / sky_loom** — "match it with the echo it describes".
  · **Earth / eye_chamber** — "build it a lens of stone and storm", then
    "set the stones, THEN ask the eye at its prism".
  · **Water / tide_works** — "turn the valves, stand the tide, open all three
    sluices": a three-step procedure read out at the door.

All four now name the state and stop. `dungeon_objective_hints_test.dart`
holds the line by grammar rather than by vocabulary: it fails any entry line
with a clause after a dash or semicolon that OPENS with a bare imperative,
which is the shape all four shared. The guardian rooms keep a written
exemption — "face X: calm it, or strike in its lulls" is a fight's rules, not
a puzzle's answer, and it is deliberately identical on every planet.

### ARRIVING IS NOT NARRATING (2026-09-14)

At some point the OBJECTIVE channel stopped speaking. The "dungeon does not
narrate" rule — written against 382 world-response lines that answered every
tap — installed an unasked-for gate, and the room-entry line went through it
with them; three tests were then written to pin the silence, on the reasoning
that *crossing a threshold is not an event worth narrating.*

Played, that reads as disorientation: **"sometimes I walk through doors and
it's not intuitive where I am — it shouldn't be a secret when walking
through."** §5.6 had it right the first time. A room naming itself as you
enter is a LABEL, not a lesson, and it is the one thing the capsule should
always say.

Two separate causes, because the fix needed both:

  · **The line was gated.** `_announceRoomEntry` goes through the unasked
    gate now. Everything else stays behind it — a refusal is still remembered
    rather than spoken, ambience is still dropped, insight is still Mask's to
    give — and a live BLOCKED or INSIGHT line still outranks an arrival, so
    walking in mid-read does not stomp the read.
  · **124 of the 169 rooms had no name.** `kDungeonRoomLabels` covered 45,
    so the minimap caption was blank for three quarters of the game as well.
    Every room is named now, and the arrival line FALLS BACK to that label
    when a room has no goal — a connective room has an identity even when it
    wants nothing. The chart and the capsule deliberately read from the same
    table, so one place never has two vocabularies.

**What survives from the silent era is the part that was always the point:**
an objective line may state WHAT and never HOW. The solution-leak rule is
pinned again on the room it was written for (Air's twin conduit, which once
read out the complete answer at the door), and `dungeon_arrival_names_test`
walks every door of every planet and fails any arrival that says nothing.

**Known wart:** `kDungeonRoomLabels` is keyed by room id ALONE, so two
planets sharing an id share a caption. `mirror_gallery` is the only collision
today and both really are mirror galleries; a future planet that reuses an id
will silently inherit its name.

### THE CAPSULE CARRIES NARRATIVE ONLY — four prioritized channels

Everything that is *state* rather than *speech* leaves the capsule entirely
(next subsection). What remains is narrative, in **four** channels where
higher interrupts lower and nothing ever stacks:

> **BLOCKED > INSIGHT > OBJECTIVE > AMBIENT.** (An earlier draft of this
> section said "three channels" while simultaneously requiring Mask insight
> to be priority-protected — which makes it a channel. It is four. Built
> that way in `DungeonHintChannel`.)

1. **BLOCKED** — fires ONLY on a failed interaction ATTEMPT, never on
   proximity, and is **attempt-edged**: it speaks once per attempt and
   remembers it has spoken, so standing against a sealed door never
   repeats the same refusal. (Correction to an earlier draft: `_checkDoors`
   did not re-fire *every frame* — it used `_setStatHint`, whose 3.5s
   self-cooldown made it re-latch every 3.5s. The on-screen effect — an
   endlessly repeating refusal — was as described; the mechanism wasn't.)
   **Known limit:** a sealed door has no attempt event at all today — the
   only available signal IS proximity, so attempt-edging (speak once per
   approach, re-arm on leaving) is the closest honest approximation. A true
   attempt edge needs doors routed through a verb; revisit once the
   interaction refit lands. One short clause naming exactly
   what's missing, element-first: "Only a horn's force can shift this" ·
   "This seal answers Lightning" · "Needs more Strength to hold". Never two
   sentences, and never a how-to-fix method (Steam's seal refusal currently
   breaks both). This is also the moment a family gate stamps itself onto
   the descent panel (§4 "the seal remembers"). Stat nags obey the same
   rule — on the failure moment, never while riding a current or standing
   near a conduit.
2. **INSIGHT** — Mask's earned how-to, and the only channel allowed to teach
   method. Priority-protected: a revealed answer must never be stomped
   mid-read by flavor or a room line.
3. **OBJECTIVE** — on room entry, one line, WHAT not HOW. Stops showing
   once the room's star is banked.
4. **AMBIENT** — rare atmospheric flavor only. NO mechanics, NO stats, NO
   family names, NO element requirements, hard cooldown. If a line teaches
   anything, it belongs to Mask insight, not ambience. All 36 current
   ambient lines fire on proximity and most of them teach — this channel is
   the largest single rewrite in the pass.

**Ordering note:** the three continuous stat nags (`:1392`, `:1410`,
`:1439`) are semantically refusals, but they fire per-frame while riding a
current — promoting them to BLOCKED before giving them a failure-moment edge
would let a continuous nag repeatedly stomp INSIGHT, which is strictly worse
than leaving them where they are. Fix the edge first, then re-channel.

**THE SOLUTION-LEAK RULE (the audit's worst finding — 9 sites):** an
OBJECTIVE line may state the goal but must never state the method. Today
Air's `twin_conduit` room entry reads *"channel A with Lightning; arc B with
Fire through the wind, or Lightning's own touch"* — the complete answer,
free, to every player, before they have looked at anything. Lightning's
Storm Spire is worse (a full step-by-step). These become goals ("The twin
conduits sleep"), and the method moves behind Mask insight where it was
always supposed to live.

**Mask insight is the how-to engine — mechanics knowledge is EARNED:** tier 0
= the objective only · tier 1 = the method, narrowed · tier 2 = ghost outline
/ marked answer. Tier-1+ content must never leak through ambient or objective
lines. Insight output is also **priority-protected** — today it writes to the
same field as everything else and can be stomped mid-read by a stray ambient
line.

### STATE LEAVES THE CAPSULE — two non-narrative surfaces

About 80 current hint calls are not speech and must stop competing for the
capsule. They split cleanly, and both destinations already have precedent in
the codebase (Steam's pressure gauge, Water's tide gauge):

- **PROGRESS READOUT** — persistent and glanceable, beside the star tracker:
  "Rings 2/5" · "Stones 2 of 4 true" · "Pressure 40". Progress is STATE the
  player wants to check at will, not a sentence that fades after 2.4s.
  Generalize the existing gauges into one per-planet readout slot.
- **CONTROL FEEDBACK** — on the control itself. "Ability cooling down"
  belongs on the ability button as a cooldown ring, not as a line of prose
  that evicts whatever the room was telling you.

### THE HINT VOICE — plain words, and a press always answers (2026-09-22)

The playtest verdict on the capsule was *"the hints read too cheesy"* and too
cryptic. The whole game had drifted into one register: comma-spliced
narration ("The weed slides away, three crossings, and none of them sure"),
aphorism ("One water table, and it has to go somewhere"), and a low-tier
reading that was a riddle rather than a shorter answer. A hint the player has
to decode is a second puzzle stacked on the first, and the HINT button is
the one place they asked for help. Every planet was rewritten to one voice:

  · **Say it plainly.** Name the thing on screen and what it does: *"Firming
    a crossing floods the crossings next to it."* No riddles, no aphorisms,
    no "X, and Y" narration, no archaic phrasing ("will not", "for ever",
    "answers only"). Contractions are fine. Sentences end with a full stop,
    not a comma splice.
  · **Use the names the player can see** — room labels, element and family
    names, the object as it is drawn.
  · **Tiers get SHORTER, never vaguer.** Tier 0 is the goal and what stands
    in the way; tier 1 the rule; tier 2 the next concrete step. A low-
    Intelligence reading is less, not a riddle.
  · **Refusals say what is missing, in words:** "Only Water can fill this
    basin" · "The font needs the X and Y stars first". A family gate names
    the family outright — "Only a Mud Mane can cross these rotten planks" —
    since a gate line is shown only at the gate.
  · **A reading that can say "never" must.** A player who cannot tell "not
    yet" from "never in this state" keeps trying forever. Where a state is
    dead (Mud's basin on a knoll with a drowned crossing, a fen with no road
    left to the altar), the reading says so and names the reset.
  · **Verse survives in two places only:** the descent riddle and the Lost
    Maxim's one oblique line — and the oblique line is plainer now too.

**A PRESS ALWAYS ANSWERS.** The capsule's priority rule (a live refusal
outranks a reading) was also being applied to the player's own presses:
HINT showed the refusal, and HINT again showed *nothing* until the refusal
timed out, although the room's reading was ready. `askForRoomHint` now
clears the live line first, so the priority rule only arbitrates between
lines emitted by that one press; a pending refusal already on screen is
skipped straight to the reading; and a reading with nothing to say leaves
the previous line up rather than blanking the capsule. Pinned in
`planet_dungeon_mud_fen_test.dart` ("a second HINT press shows the next
line at once"). Several tests used to press HINT twice to re-read the same
line; they press once now.

### Popups — four occasions, one chrome

Banked star · first discovery (cache/egg/cloud) · end-run rewards · guardian
intro. All through `dungeon_popup_chrome.dart`. **Today only end-run rewards
(plus its raid variant) actually is one**: star-banked and both discovery
types are plain unstyled toasts, ordinary cloud discoveries get nothing at
all, and **the guardian intro has no popup whatsoever** — a mystic's arrival
currently reads as a 2.4s status line indistinguishable from "Ability cooling
down". The death overlay is a fifth ad-hoc full-screen surface that should
adopt the same chrome. NEVER a mid-puzzle tutorial popup; the world and Mask
do the teaching.

**Language rules:** the element is named with its color accent; a family is
named ONLY at its hard gate; verse/riddle voice is reserved for the descent
card and the Lost Maxims; hint lines are one short clause, no stacked
sentences.

## 5.7 Doorway standard — WHAT IS OPENED STAYS OPENED

**A door that a one-time act opened must never ask for that act again.** If
the player solved it, they solved it: the entry rite, a star gate, a rite sung
at an altar, a ward turned, a burst disc blown, a graft laid. Walking back
into a room does not re-seal it, leaving the planet does not re-seal it, and
dying does not re-seal it — the entry reveal in particular is KNOWLEDGE and
rides in `discoveredClouds`, so it survives a wipe and a session.

Pinned for all seventeen by `test/dungeon_unlocks_stay_unlocked_test.dart`:
the entry rite survives a party wipe, conduits latch and never run back down
(§9.1 retired the decay timers), and a finale door with both stars banked and
the mystic roused is open — with **no per-planet exemptions**, which the test
started with and did not need.

**THE ONE LEGITIMATE EXCEPTION IS A STATE, AND IT IS NOT AN UNLOCK.** Six
planets re-gate space on purpose, and on every one of them the gate is a world
state the player authors and can author back: Water's tide, Ice's flues, Dark's
flip, Mud's fords, Crystal's sliding chambers, Blood's beats. A tide that shuts
a passage has not "re-locked a door you unlocked" — the passage was never
unlocked, it is open while the water stands there, and the whole puzzle is
knowing that. The test of whether an author is on the right side of this line:

  · **Can the player put it back?** A state gate is reversible by playing —
    turn the tide, freeze another flue, flip the maze. An unlock that re-locks
    leaves the player re-doing a puzzle they have already answered, which is
    the one thing that is never interesting.
  · **Did the closing cost them something they chose?** Ice is the model: a
    flue is a ladder or a shelf and never both, and when Frowyrm scours a stair
    the roar SAYS SO in the same beat. A way that shuts silently is a bug even
    when the rule behind it is sound.
  · **Would a returning player be confused or annoyed?** If the answer is
    annoyed, it is an unlock wearing a state's clothes.

**A CLOSING WAS NOT ANNOUNCING ITSELF, ON EITHER PLANET THAT HAS ONE
(2026-09-15, found in play).** `passThroughDoor` calls the per-planet transit
hook and `_clearHints()` one line later, so Ice's thaw and Mud's heave set
their line and had it wiped inside the same call, and the room's own entry
line took the slot. Both planets' one world-scale act has been silent since it
was built. Transit lines are parked in `_transitLine` now and announced after
the clear, outranking the room-entry line on the arrival they belong to.

**AND A WARNING NOBODY IS SHOWN IS NOT A WARNING.** The first instinct was to
warn at the foot of the rimefall on the BLOCKED channel — which §5.6 holds
back until the hint button asks, so it would never have been read. Unasked,
only two things speak: a room-entry line and a ONE-TIME TEACH. A price that
must be known before it is paid is therefore a teach, keyed and persisted like
any other: said once in a lifetime, at the object, and only when there is
something to lose (an empty shaft costs nothing to reset, so it says nothing).

And one rule that binds both kinds: **a closing announces itself.** Every place
in the game that takes a route back — the thaw, Frowyrm's roar, Mud's heave,
the tide falling — says what it took, on the BLOCKED or ambient channel, at
the moment it happens. The player may lose a road; they may never find out by
walking into it.

## 6. Per-planet matrix

Format: **Entry** · ideal team · *world rule*; Star 1 / Star 2 / Star 3; key recipe.

**v2 AUTHORING RULE:** before building, each planet's entry here must also
declare its HARD FAMILY GATES (1–3, max one per star, per §4) — which star,
which object, which element+family. Everything else is element-only at full
power. Unbuilt entries below still describe v1-era "familyX does Y" flavor;
read their family mentions as *candidate* gates to be declared at build time,
not as soft modifiers.

### Fire Star 2 — THE BURN (design, 2026-08-14; supersedes the ash garden)

*Playtest killed the demand-garden: "icons mean nothing to me or anyone
playing the game… we should use logic physics and alchemy," and then "it may
be too abstract, we may need to redesign." The verdict was right and it was
structural — a bed "wanting ash" is a LABEL, not a fact, so no amount of
prettier signalling could fix it. Three rendering passes were spent proving
that. What follows uses only rules a player already owns: fire needs fuel,
fire follows the wind, burnt ground is spent.*

**THE LOOP.** The cloister floor is plantable soil. **Plant** grows vine on a
cell; **Fire** lights one cell to start the burn; **Air** swings the vane a
quarter. The flame then walks ITSELF: one cell per beat, DOWNWIND, into
whatever vine is in front of it. The player never moves the fire directly —
they lay fuel ahead of it and turn the wind to bend it.

**THE SNAKE.** A burnt cell is spent: it carries nothing and cannot be
replanted for the run. So the fire's own trail becomes the wall it can crash
into, exactly as in snake — the constraint is not imposed, it FALLS OUT of
what burning is. Routing a long chain means never sealing yourself into a
pocket of your own ash.

**THE SMOULDER (fairness).** If the cell downwind of the head holds no vine,
the head SMOULDERS for one beat before it dies — one beat to plant ahead of
it or swing the vane. So a mistake is a scramble, not an instant loss, and
the tense expert play (laying track in front of a running flame) is the same
verb as the calm planning, just later.

**AND THEN THE BOARD TURNS OVER** (2026-08-31 playtest). A fire that dies
short has already failed — the goal is ONE chain — so the garth wipes itself
back to bare soil a beat and a bit later (1.3s, long enough to watch the
flame go out; wiping on the same frame reads as a glitch). The manual re-lay
stays for abandoning a half-planted board, and a hand on it cancels the
pending wipe. This retired `BurnField.canStillFill` / `reachableCoverage`:
"is this run doomed" was a question worth asking only while a doomed board
could be left standing.

**THE RING** (was the pool, 2026-08-31). Coverage is the win, and it is read
off a gauge wrapped around the wind vane: a filling arc with ONE TOOTH PER
SQUARE the garden owes, lit as the chain takes them. A short greedy chain
does not close it — only a route that covers the board does. Diegetic and
analogue (§5.6 STATE, and the playtest verdict on badges: "the beds should
really glow… not number counter badges"); the teeth are there because "burn
the WHOLE garden" is a count, and a bare arc turns a count into a guess.

It was an ember pool standing at the garth's edge — a fine object in the
wrong place. The thing you watch while you burn is the vane, because it is
what you steer with, and a basin in the corner was off the edge of a phone
for most of the puzzle.

**THE BOARD, AT A SIZE YOU CAN SEE** (2026-08-31 playtest). The field used to
be stretched across the WHOLE cloister, which made one square 137x148: a
portrait phone held about three columns of six, so the chain reaction — the
entire puzzle — happened mostly off-screen. It is a fixed 60px grid now
(6x5 = 360x300, inside a 390pt portrait viewport with its kerb on), laid in
the upper half of the room with cloister paths around it. The vane and its
fountain moved OUT of the field and stand below it: the ring is 108 across
and a square is 60, so parked at the middle it covered the four squares a
chain most often turns on. Burnt ground also grew a visible ash crust —
before, ash was a near-black fill plus a sprite puff, indistinguishable from
the near-black soil beside it, which hid the one rule the board must state
out loud ("nothing will take here again").

**THE NAVE** (2026-08-31 playtest). The hub is crossed a dozen times a run
and was an unlit floor with eight lollipops on it. It now has an aisle runner
from the porch to the chancel gate, blind arcading down both long walls,
piers with capitals and bases (both rows standing the same way up), and —
the part that answers to being walked through — a candle stand at every pier
foot that CATCHES as the party passes and stays lit, so crossing the nave
leaves a lit avenue behind you. Reach (130) is measured ACROSS the nave only
and lights both stands of a bay at once: a radius around each stand meant
detouring to the wall and back twice per bay, which is not walking a nave.

**THE CHOIR** (2026-08-31 playtest). Same pass, same rule — the three
evidence channels say exactly what they said before, they are just drawn as
objects instead of as marks. The braziers were 16px half-discs that the
tallow column covered outright, so a tier-3 brazier read as a pale mushroom;
the basin is a tapered iron cup on a plinth now, and its RIM stands above
anything the wax can climb. The wax column is narrower and tallow-coloured,
drawn BEHIND the iron, with the melt line — the one edge the eye measures —
still on top and still the brightest thing on the object. Soot fans are
tapering smudges rather than three hard black spikes; drift streaks carry a
grain or two so they read as blown ash, not as scratches in the floor. Around
them: blind arcading (as the nave), stalls with backs and dividers instead of
six bare lines, and the ember-walk redrawn as a worn roundel with uneven
circuits and turn-spurs, with one processional line out to each brazier so
the six read as one arrangement. The spokes are identical for all six — the
composition must never hint at the order.

**THE BARRIERS.** The garth is not an open board — two kinds of obstacle give
it its shape, and both say what they do by looking like what they are:
  · **Fallen stone** (cloister rubble, toppled columns): vine will not take
    and flame will not cross. The wall of the maze, plain and readable.
  · **Wet ground** (the seep around the dry fountain, a cracked cistern):
    vine grows there happily, but it will NOT catch — so a chain routed
    through it dies at the water. It looks plantable and is, which makes it
    the trap that teaches the rule: fuel is not the same as fire.
A route therefore has to bend around stone it cannot use and around water it
CAN plant but cannot burn, which is what stops the field being a lawn you
scribble over.

**AUTHORING NOTES.** Dead ground where vine will not take gives the field its
maze and forces the route to bend. Growth is slow enough that the baseline is
plan-then-light. Restart re-lays the whole garth (a stranded fire caps your
coverage, so the room needs its clean slate like the molten rooms have).

**LEDGER (§5.5).** Fire claims *route-building under an irreversible
consuming process* — distinct from Water's lantern row (pilot a drifting
thing through FIXED terrain by editing world state) because here the player
BUILDS the medium and the process EATS it, and distinct from Air's
irreversible wind-authoring (that wind is permanent and the ordering is the
question; this wind is freely re-turnable and the route is the question).
Consumption is the identity — keep single-use chains and unreplantable ash,
or it drifts into Water's seat.

1. **Fire — Cinder Cathedral** · Fire+Air+Plant · Firemask/Airwing/Plantmane ·
   *fire remembers the order it was lit.* **(BUILT)**
   Entry: Fire rekindles the cold narthex hearth (one-time reveal). S1 (Ember
   Star) the choir's **6** braziers lit in the remembered, non-spatial order;
   two hint layers — a CRYPTIC FLOOR MURAL at the choir's heart (broken soot
   path + a faint ember that endlessly walks the true order; patient eyes can
   decode it unaided, Mask insight brightens path/pips) and the scriptorium
   soot mural as the explicit key (Mask insight, Int-tiered; reading in the
   choir caps at tier 1); a wrong flame snuffs the rite + ash wisps. S2 (Ash Star) THE
   WIND CARRIES THE REACTION (**REWORKED 2026-08-14**; the old bed-by-bed
   grow/burn loop is retired — playtest verdict: too easy and basic, a
   two-verb loop with nothing to plan). The garth is open to the sky and holds
   a CROSSWIND. Six beds on a 3×2 grid around an iron wind-cross. Three verbs,
   all element-only at full power: **Plant grows** a bed (burying whatever lay
   there — ash, brand or ruin; shoots need 1.2s to take before they catch) ·
   **Fire burns** grown vines, and **Plant+Fire→Dust now GOES SOMEWHERE**: the
   burn brands its own bed *and* throws a plume of ash down the whole lane
   downwind onto every bed behind it · **Air swings the wind-cross** a quarter
   turn (eased, unlimited, free). Six grooves, ROLLED PER RUN, each cut for one
   gift: the **drift** (ash carried onto it), the **brand** (burned itself,
   never dusted after), or **nothing at all** (a swept groove that must stay
   clean). Ash landing on a standing brand SPOILS it until the bed is regrown.
   All six true at once banks the star. Every burn still breathes 3 cinder
   wisps, escalating as before — the cost rides the burn, never the regrow,
   because regrowing is also the anti-softlock verb. The plume FORECAST draws
   before you commit (a bright downwind streak from the bed under your hand,
   with a ring on each groove it would dust). PARITY NOTE: the old "a Dust
   creature lays ash directly" path is DELETED — it satisfied every drift
   groove with no burn at all, collapsing both the wind and the ordering; the
   alchemy survives where it belongs, as the travelling product itself.
   **Proof (`solveAshGarden` / `ashGardenStrandable`, public, walk the real
   transitions):** the entire state graph is swept (15,625 boards × 4 quarters
   = 62,500 states; 53,252 reachable from the empty garth). Of the 729 groove
   assignments **728 are solvable** — the one impossible garth is all-drift
   (every groove wants ash, so nothing is left to burn to feed the last one).
   **176** assignments need the vane turned, and the run rolls only from the
   **137** of those in the 8–12-move band, so **every run needs the wind** and
   no wiki can spoil a garden. **`strandable == 0`** over every reachable
   state: growing is legal on any non-green bed, so a fouled garth is always a
   detour, never a wall. S3 (Pyre Star), behind the chancel
   gate: Fire lights a censer — the ash rises to smother it AT ONCE (ignite =
   instant wisp wave; the rite is tended under attack) — the vesper flame
   crawls and starves between censers, Air gusts carry it (Wing strongest,
   Speed-scaled; censers = re-ignite checkpoints; a starved flame = a bigger
   unstable fury wave); 3 ember bells → Simurgh (calm or defeat) in the
   sanctum. Mercy shrine = high altar. Rooms: narthex, nave (hub, rose window
   + star vigil lights), scriptorium, choir, cloister, reliquary, vestry,
   bell_gallery, high_altar, sanctum.
   **REWORK BUILT 2026-08-11 — the forensic rite + the route decision:** the
   rite's order is no longer read off a key; it is INFERRED from evidence —
   the fire remembers, and so does the wax. The order is ROLLED PER RUN
   (`riteOrder`; Earth's precedent — wikis can never spoil it) and each
   brazier carries generated physical testimony of the last rite, in three
   channels that are each deliberately PARTIAL: **wax** melted lowest = lit
   first, burned longest (three coarse tiers, two braziers each → eight
   candidates, never the answer) · **soot** shadows lean AWAY from the
   nearest neighbour already burning, and the fire lit FIRST wears an EVEN
   COLLAR (the thread-end of the deduction) · **ash** drifts pile downwind of
   the whole sequence, one quantised compass direction streaked across the
   floor. Sufficiency is GUARANTEED, not hoped for: every roll is re-rolled
   until `solveRiteOrder()` — which reads only the testimony the braziers
   actually render — returns exactly one consistent order (~39% of the 720
   orders qualify at a 23° reading tolerance, so variety is ample). All
   three channels are load-bearing: drop the ash drift and unique-solvability
   falls from ~39% to ~11%. A patient player solves it with NO Mask in the
   party (test-proven); Mask insight only ASSISTS — t1 marks the readable
   evidence, t2 annotates ONE sticky middle link and never recites the
   order. The scriptorium mural is demoted to CONFIRMATION: two of the six
   positions, never adjacent, each named wordlessly as a constellation of
   the choir with one bowl filled (t0 recovers one, t1+ both). The choir's
   ember-walk survives as flavour, DEFANGED into a soot labyrinth so it can
   no longer imply a sequence it was never told. Wrong flame still snuffs the
   rite + wisps, and lays the evidence back down. Testimony is eaten (eased)
   by each brazier's own fire; the order and its evidence survive death (the
   cathedral's memory), while the rite itself restarts.
   S3 gained its DECISION: two censer runs to the same three bells, declared
   at two stands in the gallery and committed the moment the first censer
   takes flame (death re-opens it). SHORT — the ash-storm nave: 2 censers,
   wide gaps no single gust can clear, a fuse at 0.55× (~2.2s per feeding),
   3 unstable wisps per ignition. LONG — the calm cloister: 4 censers (two
   extra to keep alight), every gap crossed by ONE comfortable gust so the
   flame never has to survive a wait, full 4.0s fuse, 2 stable wisps. Both
   ring all three bells at brisk AND harried tending (test-proven both ways);
   the unlit run is sketched on the floor (DOTTED, so it reads as a way you
   could go rather than as more ironwork) so the choice can be weighed before
   it is made.
   PACE (2026-08-31 playtest): the flame crawls at 15px/s (was 24) and holds
   4.0s per feeding (was 2.6) — the room played as a scramble, not a rite. The
   gust is 110-170px (was 120-190) and, more to the point, it GLIDES at
   260px/s instead of teleporting the flame its whole distance on the frame
   you press it: a shove whose travel you never see reads as far too strong.
   The route trade is untouched, because it turns on the RATIO of gap to
   gust — a cloister gap is still one gust, a nave gap still strands.
   THE GALLERY (same pass): roof beams over each chain with a hanger down to
   every censer and to the bell, so the chains are attached to something and
   each run has a shelf of its own; censers are lidded cups on swivels rather
   than 9px half-discs; the chains carry links (a hairline curve between two
   cups is cobweb, not iron); the bells hang in headstocks; blind arcading on
   the long walls; and each vesper stand has a floor ring, because the stand
   is a SPOT you declare from and read as scenery without one. Simurgh §7 retrofit: it RE-LIGHTS the rite braziers as its
   telegraph — phantom iron rings the roost in the choir's own arrangement
   and walks THIS RUN'S rolled order, one readable flare then a pillar of
   black flame per beat, silenced and rewound by every lull. The order is the
   bullet pattern: Star 1's deduction is Star 3's footwork. Raids exempt (the
   generated arena has no choir to remember). No hard family gate declared —
   Fire stays element-only at full power, and deliberately so: the rite is
   built to be solved without a Mask, so gating it behind one would contradict
   its own design. Prose to the §5.6 standard (goal-only objectives, method
   tiered into insight, one-clause BLOCKED refusals) and BRAZIERS / SIGILS /
   BELLS·<run> all live in the `DungeonProgressReadout` chip. Tests:
   `planet_dungeon_fire_full_run_test.dart` (19, per-mechanic).
2. **Lava — Molten Reliquary** · Lava+Earth+Ice · Lavahorn/Earthmask/Icemane ·
   *the foundry line still runs — program it, and the metal becomes what
   the line makes of it.* (Re-authored 2026-08-10 from the §5.5 row;
   supersedes key-shape matching.)
   One long production line snakes the whole map (§5.5 topology): tap →
   channels → stations → molds. A POUR is finite and irreversible — the
   crucible holds only so many. Switch-tracks route each pour past STATIONS
   that transform it (chiller hardens it early into a bridge where it
   stands · stamper keys it · vent-pass gasses it into a drifting hazard);
   the puzzle is PROGRAMMING the line so the pour ARRIVES as the thing you
   need, where you need it — Opus Magnum by way of Zelda, and deeply
   alchemical. S1 (Bridge or Key): too few pours to cast every bridge AND
   every gate key — route and allocate (the strategic question). S2 (the
   Hidden Mold): the vault key's mold exists but is installed somewhere
   ELSE on the line — find it (Earthmask reads the foundry's tectonic
   manifest), then re-route a pour the long way around to fill it (§5.5
   vault trick). S3 Magmara wakes IN the line and rides the conveyors —
   fight it by casting against it: chill its path, stamp barriers ahead of
   it. Candidate family gates (declare at build, §4 budget): Lavahorn opens
   the crucible tap (S1) · Icemane manual mid-channel chill (S2). Key
   recipe **Ice+Lava→Steam** drives the piston stations.
3. **Lightning — Storm Circuit (Voltara)** · Lightning+Air+Fire ·
   Lightninghorn/Airwing/Firemask · *the dungeon is a living circuit —
   charge decays, mirrors route it.* **(BUILT)**
   8 rooms: arc_gate → dynamo_court (hub) → pylon_hall / capacitor_vault /
   cloud_works / mirror_gallery + rite-shut breaker → storm arena →
   storm_core. Living-circuit engine: `CircuitNode` graph (source / bus /
   mirror w/ per-orientation conducting links / sink, latching), per-frame
   BFS power propagation, `PoweredBarrier` doors, DECAYING charge (~8s;
   Horn-clean channel — refit per §4 inventory). S1 (pylon_hall) and S3
   (overload_maze) are now ONE mechanic at two scales — see §9.2. S2
   (cloud_works): storm-cells bared in the mirror_gallery, herded onto
   sockets; the anvil socket needs Fire heat (**Air+Fire→Lightning**) →
   Thundercloud. Egg: Thunderbolt. Vault cache: capacitor_vault. Tests:
   `planet_dungeon_lightning_full_run_test.dart` + circuit-graph layout
   integrity.
   **REWORK BUILT 2026-08-10 — the zero-sum dynamo:** the shipped hub stays
   (the ring-topology claim is retired — Steam owns the ring; §5.5 row
   amended) and the circuit is now ZERO-SUM: four TRUNK BREAKERS ring the
   hub dynamo (`DynamoTrunk` on the layout; pylon / cloud / vault / core
   wings), any Lightning throws one (element-only) and the dynamo feeds
   THAT trunk alone — the others darken (eased tint overlay under the
   entity layer, `_trunkDark`), and powered barriers/lights/door states
   follow. The run STARTS on the vault trunk (the treasury hoards the
   storm), so every star wing begins dark. Dead segments stay walkable but
   unlit, spark wisps prowling (capped 2, ~7s top-up). VAULT RE-HIDE
   delivered: capacitor_vault's cache sits in a walled sanctum behind the
   VAULT BOLT (`vaultBolt`), which holds while the trunk is POWERED and
   slides open (eased) in the dark — cut the very trunk you stand in and
   walk back in the dark. S1: 4 mirrors + 2 fulminate vats (negative
   constraints — a bolt cooking a vat detonates it and TRIPS the dynamo
   dark); the threading is PROVABLY UNIQUE (a brute-force solver over all
   16 orientations, run against the real beam engine in the layout test;
   vat A is the load-bearing constraint that kills the second solution).
   S3 keeps the stationing shape + one dead-aligned decoy vent/converter
   pair (VD+FD) that is geometrically impossible (no conductor beyond FD;
   solver-proven 0/32) — eliminated by reasoning, tiered into Mask insight.
   Raikuma §7 retrofit: it SEIZES the dynamo on wake and FEEDS on the core
   trunk — no lull while it drinks; the GROUNDING SPIKE (`coreBreaker`,
   Lightning-only) cuts the trunk and forces the vulnerability window, and
   Raikuma seizes the trunk back when the window shuts. Banked wings freeze
   LIT (solved is solved); no hard family gate declared — Lightning stays
   element-only at full power. Prose to the §5.6 standard (objectives =
   goals, method tiered into insight, one-clause BLOCKED refusals) and the
   terminal/socket/dynamo state lives in the `DungeonProgressReadout` chip.
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
   walkway, swum-over high ledge (+brine wisps per seal). S2 (Current Star) FLOAT THE
   MOON-LANTERN ON THE TIDE (**REWORKED 2026-08-14**; the 2026-08-11 ghost
   gallery is RETIRED — playtest verdict: it hung on one hidden rule, so the
   spins read as arbitrary rather than strategic, and it never once touched
   the temple's own signature system). The gallery is one CANAL NETWORK: ten
   directed grooves cut between a spring mouth, five basins and the sea
   drain. Every groove is permanently visible and wears its SILL on its lip —
   *the whole problem is public from the doorway; there is no hidden rule to
   hold.* **THE SILL RULE** (`canalChannelLive`): a groove runs when the water
   tops its sill — LOW at every stand · MID from the middle water up · CREST
   only at high water · and a DEEP cut runs low and mid but drowns into a
   swallowing TORRENT at high. **THE SPILL RULE** (`canalSpillFrom`): a basin
   pours down the LOWEST live groove leaving it — so the tide decides most
   forks, and the temple's own natural fall runs all the way down into the
   BLIND SUMP, a throatless basin with no groove out. Two verbs: **play the
   tide** at the gallery's sluice-bank (element-only Water; the walk there is
   the commitment, since a stand takes ~2.3s to ease over and the lantern is
   already drifting), and **plug a basin with ICE** to remove it as a
   destination and force the next-lowest groove (element-only, toggled — a dam
   can only ever take an option AWAY; nothing but the water opens a dry sill).
   Spirit's reading is FORESIGHT, never the answer: t0 names the deep cuts for
   the run · t1 shows where the water would take the lantern next · t2 traces
   the whole fall at the water as it stands — and all of it is knowable
   without a Spirit, the expensive way. Losing the lantern is cheap and never
   a softlock: grounded or sumped, it washes back to the last mouth it passed
   and is re-lit by hand; the spring always answers. **Proof
   (`solveLanternDrift`, public, walks the real sill/spill functions):** the
   authored stone is reachable, **`strandable == 0`**, and the route is
   **unsolvable at any single stand** AND **unsolvable without a dam** — both
   verbs are load-bearing by proof, not by assertion. S3 (Deep Star), behind the mirror gate: **THE MOON WELL (BUILT
   2026-08-31 — see below).** The moon drives the tide, Spirit wanes it, the
   pip's still buys the walk, Ice locks a basin when the moon stands where
   that basin asks. It replaced the true-pool quiz (freeze the two TRUE pools
   at settled mid tide; false pools shattered), which was a one-shot
   identification check. Both bridged →
   Leviathan (calm or defeat). **LEVIATHAN TURNS THE TIDE** (§7 retrofit, 2026-08-11): the
   depths carry tide zones of their own (a sink that becomes swimmable, two
   piers that drown at high water), and on every roar — the beat its lull
   shuts — the deep hauls the water one stand, rolling low→mid→high→mid so
   the fight is played across all three. The lull only opens on SETTLED
   water: the swell itself is the guardian's armour, and the player never
   holds the valve. Raids exempt (the generated arena has no tide zones).
   Mercy = moon well. The pearl vault hides behind a low-tide-only
   passage. Rooms: tide_gate, drowned_court (hub, moon + star vigil),
   tide_works, ghost_gallery, pearl_vault, reflection_court (egg), moon_hall,
   moon_well, leviathan_depths.
5. **Ice — Frozen Observatory** · Ice+Light+Air · Icemane/Lightmask/Airwing ·
   *the solution is visible only through reflection.*
   **Stars number in the order the shaft reaches them (2026-09-15):** the
   gallery is L1 and banks Star 1 (index 0); the orrery is L2 and banks Star
   2 (index 1). It was the other way round, from a house habit of making
   index 0 the ungated star — but §4's rule is only that SOME star is
   earnable by any trio, and the orrery is still that star at index 1.
   The orrery: Ice glazes a ROAD and the star-block runs it to the end (Light
   melts a glaze back); a kerbed socket catches whatever slides in. THE MIRROR
   GALLERY — the chart is on a ceiling of glacier ice and is never read
   directly: the still pool shows the quarter of sky OPPOSITE where you stand
   and etches it on the frame across the ring, so one lap of the rim puts the
   whole sky on the walls. Every figure appears twice save one, and silvering
   the stranger is the star. Light+Mask wakes the pool (the marquee gate);
   Air's sweep flashes the whole chart for a breath, then it fades.
   S3: THE ROOF OF THE HOLLOW (2026-09-20, §9.19) — the rite room's floor is
   the ice over the wyrm's lair in panes under snow; Light bares a pane and
   thin glass over the hollow bears ONE body; every bared pane says which
   way the head lies; open the glass over the head and the Airwing turns
   the last breath down that throat, Ice sings the font on its pier, and
   the three of you go down the throat together.
   (S2 REPLACED 2026-09-15 — it used to be a lap against a melt clock, which
   is a dexterity puzzle and Blood's claimed ledger seat besides.)
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
   threads through).
   **RITE REWORKED 2026-08-14 — THE SOURCE, QUENCHED.** The crucible was a
   3.0s walk: break either band gate, drop through, touch the pedestal, done —
   both gates played identically and the reservoir overhead never acted. The
   structural reason is worth recording, because it governs every flood room
   on this planet: **molten creeps one cell (70px) per 2.2s beat ≈ 32px/s, and
   a walker moves 150px/s — so a flood can NEVER threaten someone who only has
   to walk somewhere once.** A creeping flood only bites when the player must
   STAND AND WORK while it converges (S2's two-thick plug) or must cross
   ground it already holds (paying breath). So the pedestal now demands what
   the planet has been teaching all along: the SOURCE, stilled. It will not
   sink while the reservoir above the band still runs, and the order is the
   whole rite — quench it while the chamber SLEEPS (quenching never wakes
   anything; only breaking rock does), because breaking in first sets the
   reservoir pouring down through your own hole, multiplying past what one
   breath per beat can ever answer. The source is found STRUCTURALLY, not by
   hand-counted rows (`_riteSourceCells`): flood-fill the authored floor out
   from the pedestal, and any authored molten the fill cannot see is a source,
   because the band is exactly what separates them — so a re-authored crucible
   cannot silently drift from the rule. The lower cisterns stay a hazard, not
   a checklist.
   **S2 REWORKED 2026-08-14 — THE TWO POURS** (playtest: "this seems to not
   have any strategy... I build 3 walls, then what"). Both halves of that were
   right. Modelled against the real rules the old sanctuary cleared in **2.6
   SECONDS** — melt the gate, cool it, walk to the pedestal — with the first
   creep beat never landing and all three cisterns too far off to act; and the
   authored "bunker before melting" line was actively harmful, walling the
   player IN beside the cell they were about to turn to lava, with no retreat.
   The vault is now shut by a plug **two walls thick**, workable only from one
   gallery cell, and two cisterns sit under that cell's neighbours, each boxed
   in bedrock so it pours in exactly one direction: UP, onto the road. Melting
   the plug is the WAKE, so the flood runs while you are pinned in front of
   it. The counterplay is to **CAP** a pour (Steam quenches it to stone, Earth
   walls the stone) for a breath and a beat — and capping the pour you are
   standing on walls your own road, so *which one* is the decision. Breath
   (3, +1/beat) is the budget; the two-thick plug is what makes the beats bite.
   **Fairness, same pass:** the beat clock free-runs, so a melt used to leave
   anywhere from 2.2s down to a few frames before your own fresh lava took the
   tile you made it from — a reaction test on a randomised timer. Fresh molten
   from a **dry** wall now waits one whole beat before it creeps; a **wet**
   face still bursts at once, because that is what wet means (S1's lesson is
   untouched). The clock is deliberately NOT reset on a melt: an earlier draft
   did that, and the model caught it letting a player stall the entire flood
   by breaking rock on a loop. Pressure gauge with a burst-disc tick always on the
   HUD. Egg: Hidden Harmony (zero scalds) unchanged. Rooms: boiler_gate,
   manifold_south, ember_causeway, manifold_north, cinder_forge, crucible,
   burst_vault, boiler_heart.
   **STARS 1 AND 2 ARE GEYSER FIELDS (reworked 2026-08-14; this paragraph
   described the retired tile-lava rooms until 2026-09-01).** S1 (Ember
   Causeway): five mouths ring the floor and a sixth waits under a slab at the
   heart; one ring mouth starts choked, so four blow — exactly three bodies
   plus the one stone an Earth hand can raise. Every cap sends its head to the
   mouths still open, so the field gets angrier the closer you are to solving
   it, and the stone has to be placed while it is still calm enough to cross.
   Shut them all and the heart takes the whole head. S2 (Cinder Forge): the
   same field with a chasm through it — three cappable hobs, a choked mouth,
   and two RISERS whose throats are too wide for a body to smother. Cap the
   hobs and a riser throws whoever rides it, as far as the shut field allows —
   but every body sent across is one fewer holding the field down, so **the
   longest throw has to be taken first** and the last one across rides the
   weakest field. Star banks when the whole party stands on the far shore.
   S3 (the Crucible) is THE FURNACE. Its molten grid is the ARENA, not the
   puzzle: the melt creeps, Steam cools it, Earth dams it, and the band's
   gates still offer choose-your-breach (of each pair the inner one has a
   cistern behind it and bursts into your own chamber). What banks the rite is
   the planet's own gauge — bring the furnace to a working heat and HOLD it
   there. Fire feeds it OUT OF THE MAIN, so the ring is what fires the finale;
   Steam trims it for nothing; a cold furnace bleeds, so nobody can leave the
   tap. The needle has to SIT in the band for eight seconds, not pass through
   it, which means topping up INSIDE the band — a stoke taken from the floor
   of it buys six seconds against an eight-second hold. Meanwhile the flood is
   awake and coming, and Steam is both the trim and the only thing that stops
   it. → Boilrog.
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
   refracts through it toward the scale. FIVE weights, left/right pans,
   only the giant's remembered arrangement balances — and the solution is
   ROLLED PER RUN (always two-sided; wikis can never spoil it). CRUCIALLY
   the answer is NOT noise: the giant's BODY remembers it — each stone's
   true pan is carved as a leaning bone-mark in a different chamber of the
   anatomy (skull→skull_antechamber, root→palm_hollow, geode→marrow_vault,
   seed→pillar_crypt, **spine→sternum_court**), discoverable while exploring for the earlier stars.
   So Star 3 is a treasure hunt through the body you've walked, not binary
   search. The stones give NO feedback; the prism count ("n of 5 sit true")
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
   *nothing perishes here — dig, and the dust must go somewhere.*
   (Re-authored 2026-08-10 from the §5.5 row; supersedes hourglass-statue
   rotation.)
   Two Z-layers — streets above, excavation below — under CONSERVATION:
   every cell you clear pours its spoil onto a square you choose, so
   uncovering one thing always buries another, and buried = sealed for the
   run. S1 (the Three Seals): expose all three street-seals AT ONCE when
   every spoil placement wants to land on one of them — a 15-puzzle played
   in earth; plan the dig, then live in the map you made. S2 (the
   Observatory): the buried observatory below is the prize — but its roof
   is the street's only bridge; excavating the one deletes the other
   (decide; Airwing can cross what the dig destroyed). S3 Ashdjinn rides a
   rolling sandstorm that RE-buries your work — hold the excavation open
   under pressure. Candidate family gates: Earthhorn breaks the false
   walls (S1) · Airwing the roofless crossing (S2). Recipe
   **Air+Earth→Dust** lays spoil remotely. Vault: the building that never
   unburies, visible only as a roof bump on the streets (§5.5).
10. **Crystal — Prism Labyrinth** · Crystal+Lightning+Spirit · Crystalmask/Lightninghorn/Spiritpip ·
    *rooms can be rearranged.*
    S1 Crystalmask rotates prisms to match beam colors. S2 Spiritpip enters mirror
    cracks → reflection layer reveals doors. S3 *sliding 3×3 room grid* (Sky Keep):
    **Lightning+Crystal→Spirit**, **Crystal+Spirit→Light** awakens the prism guardian.
11. **Air — Wind-Crown Spire** · Air+Fire+Lightning · Airwing/Firemask/Lightninghorn ·
    *clouds are puzzle pieces — and the winds are yours to wake.*
    **(PILOT — built; §9.1 rework BUILT 2026-08-11; DEVICE TUNING still owed)**
    S1 Airwing rides updrafts/crosswinds/wind rings to the spire top (movement). S2
    Sky Loom: EARN the wonder-clouds via per-chamber elemental trials —
    Spiral → **THE GALE EYE** (**REWORKED 2026-08-14**; "ride 3 gale eddies in
    order, Air-friendly" is retired — playtest verdict: way too basic, three
    fixed dots walked in a fixed order). Seven vents ring a still eye;
    communing opens a jet PERMANENTLY for the attempt (Star 1's verb and Star
    1's irreversibility, in miniature). The eye closes only when four jets
    COMPOSE — all tangent to the rim, all turning the same way; a mouth that
    stabs inward/outward or turns against the coil SHEARS the forming vortex
    on screen, the instant it opens. It is a SET, not a sequence (§5.5 hands
    sequence-execution to Fire alone). ROLLED PER RUN (4 coil · 2 counter · 1
    radial, random handedness and placement) and readable BEFORE touching —
    every mouth wears a carved chevron along its flow plus drifting chaff.
    ANY HAND at full power: the old Air catch-radius perk is retired, because
    an element affordance on the READABILITY channel would undercut the whole
    premise. Leaving the chamber re-arms the trial (no softlock, structurally
    — the one door is never lockable); death re-rolls the ring. **Proof
    (`solveSpiralVents`, public, walks the real `spiralVortexClosed`):** over
    **all 420 configurations the roll can produce**, 840 ordered attempts →
    24 closing sequences → **exactly ONE answering set**, 816 torn, every tear
    attributable (320 radial · 496 counter-coil). · Ring: seal the orbit
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
    **REWORK BUILT 2026-08-11 — the pilot grows up (biggest pass):**
    *(The planned block from 2026-08-10 is superseded. Where the plan and the
    code disagreed, the code and the reasons are recorded here — see "spec
    corrections" at the end.)*

    **S1 — WAKE THE WINDS (execution → planning).** The spire is born CALM.
    Four **gust shrines** each wake one **gale** PERMANENTLY for the run
    (`GustShrine.wakesGale` → `WindCurrent.galeId`; no timers, eased swell over
    `_kGaleWakeSeconds`, never a snap). A woken gale pushes EVERYTHING — the
    active walker (`_applyGaleToWalker`), gliders, and the wisps
    (`_applyGalesToEnemies`, applied *after* the steering AI so pathing can't
    quietly undo the wind) — so it is at once the ladder to a ledge footing
    could never reach and the wind that scours the walkway beside it. The
    marquee case: the **First Breath**'s spill runs down the ridge stair at
    strength 150 against a 150px/s walk, so you can walk straight *into* it and
    win slowly (the ledgewalk) but cannot climb *across* it (the stair). Wake it
    before the Ridge Riser and the stair is gone — the ridge shrine is then only
    reachable the long way, up the thermal and back along the scoured ledgewalk.
    **The wind graph is authored data** (`WindLedge` / `WindRoute` /
    `GustShrine`), the collision map is built from the same rects, and a layout
    test asserts they agree (a swept route's path must lie inside the sweeping
    gale's rects; a ride's gale must actually touch both ledges; no shrine may
    stand inside a gale in its own room). Sky rings **retired** with the
    sequence-execution ascent; the `RINGS` readout became `WINDS n/4`.
      - **Proof (`solveWindWaking()`, public, walks the real graph):** of 24
        wake orders, 8 are achievable and **exactly 1 is fall-free**
        (ridge → first → crown → span). **`strandable == 0`**: every state the
        player can reach always has a next move, and the crown is reachable at
        the end — checked exhaustively, not assumed. Death resetting the winds
        is the belt and braces, not the mechanism.
    **S2 — unchanged** (the five wonder-cloud trials and the Sky Loom). The
    "Ring" wonder-trial is untouched; only Star 1's `SkyRing` retired.

    **S3 — STORM-ROD STEERING (timer-sync → prediction).** The decay timers are
    gone. **Conduit A** keeps its hard Lightning+Horn gate and its stamped chip,
    and now **LATCHES**. **Conduit B answers no hand at all** — not Fire's braid,
    not Lightning's own arc; a hand on it gets one clause ("This pylon waits on
    the storm, not on a hand"). A live **storm-cell** circles the altar; every
    `strikeInterval` it discharges a **leader** that climbs the rod field.
      - **THE LEADER RULE:** the bolt leaps to the tallest conductor within
        `kStormHopReach` **that stands exactly one rank above the one it is on**,
        nearest first; it begins on rank-0 iron and stops where nothing one rank
        higher is in reach. Rods rank 0–3 (any Air creature cranks them —
        element-only); conduit B stands at rank 4.
      - **Proof (`solveRodRanking()`, public, uses the real
        `stormLeaderFrom`):** authored as a **FAMILY**, not a unique answer —
        of 1024 rankings × 72 cell positions, **11 rankings (1%)** route the bolt
        to B from some position. The two mis-rankings the design names fail from
        EVERY position: all rods down (nothing to climb, 0 hits) and all rods up
        (a plateau the leader cannot start on, 0 hits). Cheapest valid ranking
        costs 6 cranks. Anything else dies on a rod: wild strike + storm wisps.
      - **Gusts herd the cell** (Air-only, `_kCellGustReach`), so the player
        chooses where the climb begins.
      - **B stands HIGH in the far corner** (`(770,150)`, 2026-08-14): above
        and beyond every rod, out of the cell's reach by 224 > `kStormHopReach`,
        and inside a single leap of exactly ONE rod (`rod_north`). The room now
        states its own rule geometrically — the pylon is somewhere iron has to
        climb to — at the cost of half the solution family (21 → 11; the six
        rankings that used to finish on `rod_south`/`rod_axis` are gone, the
        cheapest answer and its 105° firing window are not). Layout-tested.
      - **The winning chain LATCHES with the conduit it fed**
        (`latchedLeaderPath`): once the storm finds B the ladder keeps burning
        on a slow breath instead of guttering after `_kLeaderFlashSeconds`, so
        the room goes on showing the circuit the player built. A fresh leader
        still flashes brighter over the top of it. It is anchored to the spot
        the bolt came down from while the cell is still standing there (which
        is always, once both conduits latch the cell freezes) and starts at the
        first iron if the cell has drifted on — never an arc into empty air.
    **Roc (§7 retrofit):** the guardian **drags the cell on a leash**
    (`_kRocLeash`, always further than one leap from the bird) across a ring of
    eight perch-rods at radius 150. The shared lull/strike cycle is untouched;
    a bolt **led into the bird** forces a full window (`_kRocStun`). Raids are
    exempt — a generated arena has no rods.

    **SPEC CORRECTIONS (where the 2026-08-10 plan met the code):**
      1. *"herd the cell with gusts (S2's own verb, reused)"* — **S2 has no
         gust verb.** Air's Star 2 is five trials (ride / seal / crack / catch /
         pin); the gust verb in this codebase is Fire S3's element-only Air gust
         (`_kGustRadius`). The herd gust is built in that shape, and it now
         shares its vocabulary with Star 1's shrines instead.
      2. *"its bolt always lands on the TALLEST conductor in its path"* — as
         written this is **not a puzzle**: conduit B outranks every rod, so any
         rod adjacent to B hands the storm the conduit for free whatever the
         rest of the field does (verified: 2 of 2 flat-field angles routed). The
         rule needed the **one-rank-at-a-time** clause above to become a
         staircase problem. The "tallest" language survives; the reach does not.
      3. *"never a softlock — death resets the winds"* — relying on death is not
         a design, and a player wedged on a ledge with no hazards **cannot
         die**. The build makes no-strand **structural** (every ledge keeps a
         way in under every reachable woken-set, solver-proved) and keeps the
         death reset as redundancy.
      4. *"blown off = fall + climb back"* — a plain walkway is physically
         symmetric, so one-way "drops" are not implementable without a new
         mechanic. Cost is instead carried by **swept** routes (closed) and
         **costly** routes (open, but you grind into the wind and can be shoved
         off), which is the same feeling with an honest implementation.
      5. §4's conversion inventory row 13 ("Air Ring wonder-trial … *or moot*,
         this trial retires") — **it does not retire.** The Ring wonder-cloud
         trial is Star 2 and was left alone; only Star 1's ring SEQUENCE went.
         Its family-neutral window shipped in §9.0 and is still tested.
      6. `_tryStabilize` retired (see §4's superseded exclusives note). Nothing
         else depended on it; the Wing keeps its glide, and Air's slot no longer
         carries a family requirement anywhere in the planet — so the descent
         riddle's first verse was re-cut from "those the ground cannot keep"
         (which promised flight was the road) to "my crown is woken, never
         climbed — send one who shepherds the wind".
      7. One **optional** Speed-3.5 wind (the east *flue*) is authored in
         `lower_spire`: it is not part of the wind graph and the crown never
         needs it, so its threshold scales a BONUS, not progress — which is the
         only shape §4 permits for a hard stat gate off a family-gated object.
    **DEVICE-TUNABLE KNOBS** (this planet has never been device-tuned; all in
    `planet_dungeon_game_air.dart`): `_kGaleWakeSeconds` · `_kShrineReach` ·
    `_kGaleWalkerScale` · `_kGaleEnemyScale` · `_kGaleCoyote` ·
    `_kCellGustReach` · `_kCellGustShove` · `_kRodReach` · `_kRodEaseSeconds` ·
    `_kLeaderFlashSeconds` · `_kWildStrikeWisps` · `_kRocLeash` ·
    `_kRocLeashSpeed` · `_kRocStrikeReach` · `_kRocStun` / `_kRocStunEnraged`;
    plus `kStormRodMaxHeight` · `kStormHopReach` in `planet_dungeon_data.dart`,
    and each gale's `strength` in the layout.
12. **Plant — Verdant Crypt** · Plant+Light+Mud · Plantmane/Lightmask/Mudpip ·
    *tiny and huge scale states.*
    S1 Plantmane grows vine bridges toward redirected Light. S2 *Tiny-Huge Island*
    growth altar; relic needs both scales (**Mud+Light→Plant**). S3 **Plant+Mud→Poison**
    blooms dissolve cursed roots; Light purifies the central flower before it spreads.
13. **Poison — Venom Monastery** · Poison+Lava+Mud · Poisonmask/Lavahorn/Mudmane ·
    *every strain BEHAVES — behavior is the diagnosis; and one ward cannot
    be saved.* (Re-authored 2026-08-10 from the §5.5 row; supersedes
    pool-to-door matching.)
    The monastery is sealed into quarantine WARDS; opening one lets its
    contagion meet you. Each strain is identified by BEHAVIOR, never by
    color — one pulses on a rhythm, one creeps along walls, one leaps
    between hosts, one plays dead until touched. S1 (Diagnosis): observe a
    ward's strain, then brew the matching antidote at the apothecary (the
    monastery's own recipe rite); a wrong brew FEEDS it. S2 (Triage): the
    doses are finite and the wards outnumber them — the strategic question
    is which ward you SURRENDER; cured wards open their sacristies, the
    surrendered ward seals for the run. S3 Blightfang is patient zero,
    fought inside the ward you chose to lose, among everything you didn't
    save. Vault: inside the surrendered ward (§5.5) — you may only loot
    what you sacrificed. Candidate family gates: Mudmane carries live
    venom uninfected (S2) · Lavahorn burns a breach into a sealed ward
    (S1). Recipe **Lava+Mud→Poison** brews the counter-strains.
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
    *the statues lie; their shadows cannot — and every lumen you spend is
    seen.* (Re-authored 2026-08-10 from the §5.5 row; supersedes truth/lie
    statue-picking.)
    One great hall, no corridors: aimed beams PARTITION the space into
    moving rooms of light (§5.5 topology), and the archive keeps an
    EXPOSURE meter — light builds your paths AND wakes the moth-wardens.
    The run-long question: how little can you afford to see? S1 (the
    Shadow Court): statues claim doors, but a statue's SHADOW shows its
    true shape — aim a beam, compare silhouette to stone, follow what the
    shadow says (Crystalmask splits one beam to throw two shadows at
    once and compare). S2 (the Dark Stacks): route light-bridges through
    the archive while staying under the exposure threshold — every beam is
    both road and alarm. S3 Solarin is wounded light: it BLINDS wherever
    it looks — fight it from inside its own shadows. Vault: stands in
    plain sight, reachable only across un-lit ground (§5.5) — approach
    with everything dark, which is also how the egg is earned. Candidate
    family gates: Spiritpip walks the unlit dark (S2) · Crystalmask the
    beam-split (S1). Recipe **Crystal+Spirit→Light** kindles remote
    beacons.
17. **Blood — Sanguine Orrery** · Blood+Dark+Light · Bloodkin/Darkmask/Lightmask ·
    *the dungeon is alive and beats on a rhythm.*
    S1 Bloodkin stabilizes heartbeat doors (time movement). S2 route life-flow
    through correct veins (Darkmask reveals, Lightmask flags corrupted). S3
    **Dark+Light→Blood**: balance dark/light beams around the heart → guardian wave.
18. **The Nexus — The Great Work** (endgame; beyond the 4-relic gate —
    designed 2026-08-10, RESERVED, build LAST).
    The rule-manipulation dungeon the 17 planets never touch — the Baba Is
    You seat, and for a game about alchemy it is the thesis:
    TRANSMUTATION. Transmutation circles rewrite element BINDINGS for the
    whole floor — inscribe "FIRE is WATER" and every brazier douses, every
    basin burns, and the party's own elements answer the rewritten law
    too. Rooms are impossible under the standing rules BY CONSTRUCTION;
    the aha is always "which law do I rewrite — and what else breaks when
    I do." Circles are found and carried, and hold one binding at a time.
    It must remix objects the player already knows from many planets
    (braziers, valves, conduits, vines), so it grows richer the more
    planets exist — hence build last. Guardian: the Magnum Opus (design
    open — a mirror of the player's own trio is the candidate). No raid.

### Water Star 3 — THE MOON WELL (BUILT 2026-08-31; supersedes the true-pool quiz)

*What is built is four pools, two of them true, frozen at mid tide. You read
the room, you pick two, you are done — a one-shot identification check with no
play in it, and the thinnest star on the planet. It also wastes the room: an
oculus open to the sky with a moon standing in it, used as a backdrop.*

**THE REVEAL THIS IS BUILT AROUND.** You spend the whole temple turning
wheels. Every sluice, every master valve, every pipe-mouth — the tide is a
thing you crank. The moon well is where you find out the wheels were only ever
bleeding water off. **The moon is what moves the sea**, and up here, under an
open oculus, it moves it directly. Nothing already built has to be rewritten
for that to be true: the valves admit and drain LOCALLY, which is exactly what
they have always done everywhere else.

It also makes the Frozen Moon easter egg rhyme with the finale. Freeze the
moon's *reflection* in the mirror room and it holds forever; freeze the moon
*itself* here and it holds for five seconds.

**THE MOON.** A disc over the well, at one of **seven notches** (new → full).
It **waxes on its own**, one notch every `_kMoonWaxSeconds` (4.5s), and it
never stops. That one-way drift is the clock — there is no timer on screen and
none is wanted, because the moon IS the timer and it is the thing you are
already looking at.

The notch sets the tide TARGET, which the water then eases toward exactly as
it does everywhere else (`tideAnim`, ~2.3s a stand — no engine change):

| notch | 0 | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|---|
| stand | low | low | mid | mid | mid | high | high |

**THREE STATIONS, ONE PER ELEMENT.** The room is a balancing act because the
three controls are three different creatures in three different places, and
swap-control means only one of them is ever in your hands:

  · **SPIRIT — the moon dial.** One press WANES the moon a notch. The sky
    pushes it forward, Spirit pulls it back; that is the whole loop, and it is
    one button, which is what keeps a three-system room legible. This is also
    the Spiritmask's first verb on this planet — it only ever read before.
  · **WATER (pip) — THE BROKEN MAIN.** A spout in the south wall, running the
    whole time. While it runs the well stands one water ABOVE what the moon
    calls for, so **no basin can agree with the sky at all**. Only a Water pip
    fits the mouth, and it plugs it by **STANDING** there — it is a place, not
    a press, so the pip is pinned for the whole rite and the other two do all
    the walking. Step away and the main opens again.
  · **ICE — the basins.** ALL FOUR listen, and no two want the same moon. When
    the moon sits at a basin's notch, has held for `_kPoolHold` (1.2s), AND
    the well is actually holding that water, Ice locks it — frozen forever.

**THE MOON IS DRAWN CONTINUOUSLY.** `moonNotch` is the mechanic; `moonPhaseAnim`
is the sky, and it slides — easing toward the notch and running on ahead of it
while the sky waxes, so the face is never still while the well is turning. A
moon that snapped between seven poses read as a dial with moon pictures on it.

**AND THE DEEP ANSWERS THE FOURTH.** Four locked basins is the loudest thing
anyone has done in this temple. It does not merely open a door: three BRINE
WARDENS come up out of the well — elites, not the harassing wisps every other
rite throws — and they have to be put down before the bridge is yours.

**THE ICE RAISES THE WELL, AND THAT IS THE DECISION.** Every basin you freeze
is a slab of ice taking up room in a closed well: once **two** stand, the
water rides a notch higher for the same moon and the thresholds slide down. A
basin wants the stand its own moon called for BEFORE any of that — so the two
whose notches sit at the top of their band are DROWNED by the rise and can no
longer be taken. **They have to be locks #1 and #2**, and working out which
two those are is the question the room asks. Exactly two of the four are
fragile for every roll (pinned by test), so the answer is never trivial and
never impossible: 4 of the 24 orders work.

WITHOUT THIS THE ROOM WAS A ROUTINE. Four basins, no failure state, nothing
consumed, no irreversibility — the drift was a wait rather than a pressure and
the order was a weak preference about walking distance. The rise turns it into
something to work out.

**AND IT CANNOT STRAND, WHICH IS WHY THE RISE IS ALLOWED TO EXIST.** ICE ON A
FROZEN BASIN BREAKS IT OPEN. The count falls, the well drops, and everything
is reachable again. Freeze the free pair first and the fragile pair drowns —
recoverable, but you must unwind BOTH, because the fragile pair can only ever
be locks #1 and #2. A wrong order costs the walk; it never costs the run. A
drowned basin says so on its own face: its moon goes dim under water with the
well's line struck across it.

**THE COUPLING THAT MAKES IT A PUZZLE.** The notch you have to hit also
decides how hard it is to reach the pool that wants it. Drive the moon to 5 to
serve a fat-moon pool and the room floods — the water is swimmable at high,
and a non-Water creature swims at 0.62×, so the very act of setting the value
lengthens the walk you have to make while it drifts. A thin-moon pool drains
the floor and the walk is quick, but the moon is waxing away from you the
whole time. **Neither pool is hard on its own; the pair is hard because they
pull in opposite directions.**

**ROLLED PER RUN.** The four wantable notches are {1, 2, 4, 5} — never 0 or 6,
because the drift PARKS at full and waning bottoms out at dark, so a basin
asking for either could be served by doing nothing. The SET is fixed and only
which basin wants which is rolled, which is enough: the room is a walk between
basins and the walk is what changes. Spirit's reading is tiered and answers
the thing in the way first — while the main is running it says so, and only
once the well can hold a moon at all does it start naming phases.

**NOTHING IS CONSUMED, SO NOTHING CAN STRAND.** The version this replaced
SHATTERED a false pool and threw fury wisps — a consumed attempt in a finale,
which is cruel and which this drops; the wrong moon simply refuses. The moon always waxes and Spirit can always wane,
so every notch is reachable forever from every state. The mercy shrine is
already this room, so a wipe here is a reset rather than a run.

**THE WISPS COME LAST.** Brine wisps off the drowned pier, on a slow cadence,
and they attack the party rather than the moon. The drift is already a clock,
and two clocks make a room noisy instead of tense. This is the dial to turn if
playtest says the room is too calm — not the first thing to build.

**THE LEVIATHAN INHERITS IT** (§7 guardian principle: the guardian fights WITH
the planet's rule). Its roar currently hauls the tide a stand. It should wrench
the MOON now, and let the tide follow — same effect, but it reads as the deep
fighting you for the thing the antechamber just taught you to hold. The lull
still opens only on settled water, so the swell is still its armour.

**WHAT CHANGES IN DATA.** `MoonPool.isTrue` becomes `wantsNotch` (int?, null =
deaf). The four authored pools stay where they are. The pip-only pipe-mouth
stays where it is and gains the calm verb. The room's tide zone is unchanged.

**LEDGER (§5.5).** Water claims *holding a live set-point against a one-way
drift, where the value you must hit also sets the cost of reaching it.* It is
close to Fire's "tend a fragile process under attack" and deliberately not the
same: Fire's is a ROUTE — spatial, consuming, a thing carried along a path —
and this is a SCALAR held in a band, where nothing is spent and the terrain is
the consequence rather than the medium. Any planet reusing it must couple the
value to the cost; a bare "hold the needle steady" minigame is not this row.

**TESTS** (`dungeon_water_moon_well_test.dart`, 11). The roll always gives a
pair at least 2 apart and never 1 or 6; the sky waxes and PARKS at full rather
than wrapping (wrapping would make the drift a way of reaching a low notch and
quietly remove Spirit from the room); every notch is reachable from every
notch, swept 7x7, which is the no-strand argument; a deaf basin and a wrong
moon both cost nothing; a moon still in motion is refused; and the moon takes
the standing water the moment you walk in.

**TWO THINGS THE BUILD FOUND.** The temple was never seeded in the
constructor's per-planet block — every other planet is, and Water's absence
meant the well's basins came up empty until something happened to call the
reset. And the well can be entered at ANY stand, because the tide is
temple-wide and set three rooms away, so a moon that disagreed with the
standing water dragged the tide to a new stand on its first wax with nobody
touching anything; the moon reconciles to the water on entry now.

**STILL OWED: the tuning playtest.** Whether 4.5s of wax makes the walk to a
basin tense or tedious is the one thing the design cannot settle on paper.

### Mystic guardian roster (Star-3 boss + raid boss per planet)
Verified against `assets/data/alchemons_creatures.json`; spritesheets in
`assets/images/creatures/mystic/MYSxx_*_spritesheet.png` (verify each sheet's
frame count/size before adding to `_guardianSheets` + `kRaidGuardianIds`).

MYS01 Simurgh=Fire (built: 6×512² frames, 1 row) ·
MYS02 Leviathan=Water (built: 4×512² frames, 1 row) ·
MYS03 Terradon=Earth (built: 4×512² frames, 1 row) ·
MYS04 Roc=Air (built) · MYS05 Boilrog=Steam · MYS06 Magmara=Lava (built) ·
MYS07 Raikuma=Lightning · MYS08 Bogdrya=Mud (built) · MYS09 Frowyrm=Ice (built) ·
MYS10 Ashdjinn=Dust (built) · MYS11 Prismalith=Crystal (built) · MYS12 Botanica=Plant (built) ·
MYS13 Blightfang=Poison (built) · MYS14 Wraithord=Spirit (built) · MYS15 Noctryos=Dark (built) ·
MYS16 Solarin=Light (built) · MYS17 Sanguorath=Blood (built).

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

**WHAT A SECRET MUST BE — THE MAXIM STANDARD (the rule, from 2026-09-01).**

Fire's Ember Epitaph is the shape every one of these has to reach, and the
shape is not "a hidden thing you touch". It is:

  1. **A CHAIN, not a press.** Three or four beats that must happen in order,
     each one visible in the world before the next is possible.
  2. **ALL THREE ELEMENTS of the descent trio**, each doing the thing it does
     everywhere else on that planet. If one of the three has no job, the
     payout — which is a reaction built from all three — is a promise the
     puzzle did not keep.
  3. **THE PLANET'S OWN ALCHEMY.** The braid the rest of the dungeon already
     taught (Earth+Lightning→Crystal, Plant+Fire→Dust, Spirit+Water→Ice) does
     the transforming beat. Nothing new has to be learned to solve a secret.
  4. **ONE REPEATED BEAT** near the end — Fire's three gusts, Air's four
     winds, the palm's three creases. It turns the finish into something you
     are DOING rather than a state you flipped.
  5. **WORDLESS past the first nudge.** One oblique line on the HINT button
     and nothing else; every subsequent step is legible from what is standing
     there. No popups narrating progress.
  6. **NOTHING CONSUMED.** A wrong element answers with a small burst and a
     sentence about what it sees. A secret that can be spent is a secret that
     can be lost, in a room built for curiosity.

**WHERE THE SEVENTEEN STAND AGAINST THAT.** Ten clear it; the rest are the
queue:

| Planet | Beats | Elements | Verdict |
|---|---|---|---|
| **Fire** — Ember Epitaph | 4 | Mask-read · Plant · Fire · Air×3 | ✅ the reference |
| **Air** — The Four Winds | 4 | Lightning · Fire×4 · Air×4 | ✅ |
| **Earth** — The Giant's Palm | 4 | Earth · Lightning · Crystal×3 | ✅ rebuilt 2026-09-01 |
| **Water** — The Stilled Mirror | 4 | Water (stand still) · Spirit×3 · Ice | ✅ rebuilt 2026-09-01 |
| **Lightning** — Thunderbolt | 3 | Air · Fire×4 · Lightning | ✅ rebuilt 2026-09-01 |
| **Steam** — Hidden Harmony | 1 | the whole main, spent on something that is not a door | ✅ §9.6 |
| **Lava** — Black Glass | 1 | the pour you throw away | ✅ §9.7 |
| **Poison** — The Dose | 3+ | Poison · Plant · Mud, each walked home | ✅ rebuilt 2026-09-04 |
| **Mud** — No Mud No Lotus | 5 | the fen at full drown · Water · Plant · Mud×3 | ✅ rebuilt 2026-09-13 (§9.8) |
| **Dust** — Nothing Perishes | 5 | Dust/Earth lay the count · Air lights the pits | ✅ rebuilt 2026-09-19, §9.13 |
| **Crystal** — Know Thyself | 5 | Crystal wedges the cell · Pip finds the flaw · Lightning strikes ×3 · Crystal reads | ✅ rebuilt 2026-09-19, §9.16 |
| **Plant** — The Unseen Shade | 5 | Plant grows the trunk · Mud, Plant, Light tend in the shade · Plant looks from huge | ✅ rebuilt 2026-09-19, §9.17 |
| **Spirit** — Stuff of Dreams | 5 | the cold world · Water · Crystal · Spirit×3 | ✅ rebuilt 2026-09-13 (§9.9) |
| **Dark** — The Abyss | 5 | Dark lights the Deep (vane) · Spirit reads · Poison frees · Dark hauls ×3 | ✅ rebuilt 2026-09-19, §9.14 |
| **Light** — Afraid of the Light | 4 | Light blazes ×3 · Crystal reads · Light douses in order · Spirit draws | ✅ rebuilt 2026-09-19, §9.15 |
| **Blood** — The Blood Is the Life | 4 | Dark turns a dead cock · Light shows the clot · Blood breaks it on the pause · both | ✅ rebuilt 2026-09-20, §9.18 |

Take them a planet at a time, with the planet's polish pass — a secret
designed away from the dungeon it lives in will not use its braid.

**HOW A SECRET PAYS OUT — THE RITE OF THREE (the rule, from 2026-08-31).**

All seventeen used to end the same way: a permanent change to the room, and a
hint popup carrying an italic quotation from a dead philosopher (Heraclitus
three times over, plus Ovid, Nietzsche, Shakespeare, Plato…). The change was
the good part. The quotation was a label stuck on it, and having every planet
reach for the same borrowed shelf made seventeen different discoveries land
identically.

What pays out now is a REACTION, and it is made from **the party you brought**.
Call `beginMaximRite(eggId, focus)` instead of `_discoverCloud` + a quote:

  · **DRAW** (0 → 1.25s) — each of your three creatures' elements is drawn out
    of it and winds in to the thing you found, each thread bending its own way
    so three approaches never overlap into one.
  · **BIND** (→ 2.45s) — they close into an alchemical figure over the focus: a
    ticked gold circle contracting as it turns, the triangle through the three
    element nodes, and the opposed figure coming up through it late.
  · **FLASH** (2.45s) — the binding takes. **This is where the gold is granted**
    — deliberately deferred from the trigger, so the payout lands on the beat
    the reaction gives it rather than three seconds early.
  · **YIELD** (→ 4.2s) — the figure is consumed and coined light is thrown out
    of it, arcing over and falling.

Descend with a different trio and it is a visibly different reaction. The
secret is the same; what the planet makes of it depends on who was standing
there. Nothing in it is glow-only — a first pass drew the heads, the nodes and
the coins purely as mote blits and the whole thing collapsed to three hairlines
whenever the sprite was missing.

Safety, pinned in `dungeon_maxim_rite_test.dart`: the gold arrives exactly
once, it arrives even if the player dies or walks out mid-reaction, a second
trigger during the reaction cannot double it, and a found secret never
replays. A quotation is now OPTIONAL per planet — keep one only where it is
about the room it is hidden in (Air's Seneca and a compass), and prefer the
world's own answer everywhere else.

**AND INSIGHT ADMITS THE SECRET EXISTS.** The reading used to answer "Nothing
hidden stirs here" full stop — in the Air hub, that was said to a player
standing in the one room on the planet that IS the secret, and everywhere else
it taught them there was nothing to look for at all. Two fixes: the hub now
has its own tiered reading (the compass is a mechanism · its heart wants
current · the wind ate the four faces unequally — never the ORDER), and the
generic line admits what it knows: *"Nothing hidden stirs here — but the
planet is still keeping one"*, until the planet's `egg:` id is banked. Derived
from the discovery channel, not a hand-kept map of which room holds what, so
it cannot fall out of step with the planets.

**Adoption: ALL SEVENTEEN.** Every planet's secret goes through it, and the
quotation constants are deleted from the code — nothing left to drift.

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
2. **Air — The Four Winds (BUILT, REBUILT to the Fire template):** the four
   rune pillars ringing the hub compass. Any hand touching one flares its rune
   and throws a spark at the compass heart — the lure, and the pointer.
   **ALL THREE ELEMENTS SOLVE IT**, because the payout is a reaction built
   from all three and a puzzle must keep the promise its own payout makes:

     · **LIGHTNING** at the compass heart puts current through the mechanism.
       The ring wakes.
     · **FIRE** burns the rime off each of the four faces. Clean all four and
       the wear is legible.
     · **AIR** wakes the winds, OLDEST FIRST — the longest-blown wind ate its
       rune down the most, so the stone says the order out loud to anyone who
       looks. Rolled per run (like the choir's brazier order), so it is
       deduced, never memorised. A wrong pillar scatters them and the walk
       restarts; the wear survives, because what the player learned is still
       true.

   What hangs over the rose is **the compass's own ring, in pieces** — broken
   while the winds are unspoken, closing as the last one is spoken, whole and
   lit forever after. It replaced three lines of Seneca and does the job
   better: a visibly broken ring says "unfinished" from across the hall, where
   italic verse said "there is text here, walk over and read it". PERMANENT
   completion state: the compass spokes turn forever, the pillars ride a slow
   perpetual orbit and stay lit, three gust-heads circle trailing arc streaks.

   *What it replaced, and why:* one press on the exact centre of the hub,
   gated on all three stars. No puzzle, nothing marking the spot — and the hub
   declared no furniture at all, so `roomOffersAction` was false, the action
   pad never appeared in that room, and the secret **could not be reached by
   any means**. The pillars are authored data now (`DungeonRoom.windRunes`),
   which fixes the pad as a side effect. Not star-gated any more: a secret you
   can only find after finishing the dungeon is a secret nobody finds.

3. **Water — THE STILLED MIRROR (BUILT; REWORKED to the MAXIM STANDARD
   2026-09-01):** it began as one press on a drifting dot, became two beats
   (stand still, then freeze), and is a full chain now — the middle beat is
   the one that was missing, and it is the job SPIRIT did not have in its own
   secret despite this being the MIRROR-tide temple.
   **WATER** stands motionless in the pool at the settled HIGH stand and the
   surface flattens to glass
   over `kMirrorStillSeconds` (3.2s) — the one place in the game that asks you
   to stand still, in a temple made of moving water. On the glass the moon
   comes apart into **three shards, each showing the wrong phase**, because a
   reflection is a lie until it is turned true — and the real moon is hanging
   over the room where anyone can compare it. **SPIRIT** turns a shard one
   phase per press (wrapping, so no piece can be stuck past its mark) until
   all three agree with the moon above. Only then will **ICE** take it, or
   Spirit via the temple's own Spirit+Water→Ice braid.
   The tell is wordless: three wrong moons under one right one. Nothing is
   consumed — walking the Water creature out breaks the glass and costs the
   stillness, never the shards you have already turned.
   **THE PIECES TRAVEL BACK.** They do not snap together the frame the last
   shard agrees: over `kMirrorMergeSeconds` (1.35s) each one slides in from
   where it lay and swells while its break-ring fades, so the moon is
   assembled in front of you. The ice waits for it — pressing early says the
   pieces are still coming together.
   **AND WHAT IS LEFT BEHIND IS A REFLECTION, STILL MOVING.** The permanent
   mark used to be a bright disc with two cracks on it, which is a coin lying
   in a pool. It is drawn the way the moon well draws its own now — inverted,
   broken across three horizontal slices sliding against one another. It
   keeps wobbling, slower and shallower than the well's: **the ice holds the
   moon, not the pool**, and a reflection that stopped read as a picture of
   one rather than as water.
4. **Ice — Star-Walker (REBUILT to the MAXIM STANDARD 2026-09-19, §9.12):**
   THE STRANGER. A shaft ridden bare is a mirror and the pool under it sees
   the sky: one star hangs there on a bearing that no frame charts. Carry
   the bearing down chute B, turn the lens to it with Air, lock the sighting
   with Ice. Built on the state the primer tells you never to make.
5. **Lightning — Thunderbolt (BUILT; REBUILT to the MAXIM STANDARD
   2026-09-01):** it used to fire off Star 3's beam if a Lightning HORN
   happened to be standing among the conductors when the tower lit — a secret
   that rode a star's coat-tails and asked nothing of its own.
   It is built out of the one thing this planet owns that no other does: the
   dynamo is **ZERO-SUM**. It feeds one trunk and darkens the rest, and every
   wing you have ever lit cost you the other three. The secret is refusing
   that. **AIR** winds the rotor past its limit and it bleeds back down on its
   own, so the over-speed is the clock the rite runs against · **FIRE** fuses
   a breaker's blade shut, but only while the rotor is over, because a breaker
   built to open will not weld on the current it was designed for — four
   breakers, four welds · **LIGHTNING** throws a dynamo with nowhere left to
   choose, every trunk takes at once, and the works lets go.
   Nothing is consumed: Lightning blows a weld back off (which is the undo the
   rite needs to be allowed a wrong turn), and a lapsed over-speed costs the
   walk back to the rotor.
   **What it leaves behind is the rule broken for good**: the dynamo never
   chooses again — every wing lit this run and every run after, the welds
   standing cold in all four breakers, and the burn the discharge struck
   across the bed plate and out into the floor.
6. **Steam — Hidden Harmony (BUILT):** finish the whole labyrinth — the rite
   included — without the molten ever swallowing your footing: zero scalds,
   one run.
7. **Earth — The Giant's Palm (BUILT; REBUILT to the MAXIM STANDARD
   2026-09-01):** what it was is one press — stand a Crystal creature in the
   hand, and the trio always carries a Crystal, so the whole puzzle was
   noticing the room. It is a chain in the barrow's own braid now: **EARTH**
   raises a core of stone into the open hand · **LIGHTNING** arcs it and
   Earth+Lightning→Crystal wakes it as a seed (Crystal may set it direct, the
   same parity the gaze-lens has) · **CRYSTAL** refracts down each of the
   palm's three creases in turn, because a seed roots along light and the
   creases are the only roads out of the hand. The third crease taken, the
   cluster comes up through the palm and stays there forever. One oblique line
   on the HINT button — "the hand lies open… and misses it" — and nothing
   after it; every step is legible from what is standing in the hand. Nothing
   is consumed: a wrong element gets a small burst and a sentence about what
   it sees. Knowledge survives death, the growth does not.
8. **Lava — Black Glass:** quench the casting font mid-pour three times —
   the spoiled keys cool into a black-glass mirror.
9. **Mud — No Mud, No Lotus:** THE BLACK LEAD (§9.8). Drown the fen to the
   one shape that carries the most water it can — the three short roads, the
   shape both stars forbid — and the cutters' dead drain runs. Water reads
   the three peat cuts out of it, Plant seeds the sink, and Mud drags each
   cut's lip in turn until the seed is buried utterly. It blooms.
10. **Dust — Nothing Perishes (REBUILT to the MAXIM STANDARD 2026-09-19,
    §9.13):** THE TALLY. The granary's five grain pits hold the dead's last
    count of the city, one per mound, marked with the mound's survey glyph.
    Lay the streets back to that count — the observatory's roof DRIFTED, the
    state Star 1 forbids — and Air blown across each pit lights it. Five lit
    at once, and the cist opens.
11. **Crystal — Know Thyself (REBUILT to the MAXIM STANDARD 2026-09-19,
    §9.16):** THE BLACK CELL, WEDGED. Ride the Black Cell into the one
    corner where both its doorways meet the frame — the jam the keep's whole
    valve exists to rescue you from — and its glass shows nothing but the
    three of you. The smallest body finds the flaw, Lightning runs it three
    times, Crystal reads the three shapes. The anneal is the way back out.
12. **Plant — The Unseen Shade (REBUILT to the MAXIM STANDARD 2026-09-19,
    §9.17):** THE SHADE THE TRAP THROWS. Grow the giant root's TRUNK — the
    trap the whole planet warns you off, because it costs the only small
    road to the islet — and its bough throws a shade across the gallery
    floor. Under it, small, tend the seed nobody planted the altar's own
    three ways in the altar's own order; then come back at your own size and
    see what grew.
13. **Poison — The Dose:** the sick wisp wears one element at a time and only
    a hand of THAT element can touch it. Each press shoves it a stride toward
    the lustral cross — about six, walked with it — and at the cross it sheds
    the colour and comes back out wearing the next. Purple, then green, then
    brown, which are the game's own element colours, so there is no code to
    crack: the player has been looking at those three on their own party
    since they picked it. Rebuilt 2026-09-04.
14. **Spirit — Stuff of Dreams:** THE UNDUG GRAVE (§9.9). At the far end of
    the mourners' walk, down a spur no door uses, is a grave somebody scored
    out and never dug — and in the cold world it stands open, full of black
    water, with an UNCUT headstone. The telling that finishes all six of the
    dead has nothing here to work on. Water draws the water off, Crystal
    sets a lamp at its head, and the Spirit hand tells three names into it,
    one apiece, with all three of you standing in it. The seventh funeral is
    yours.
15. **Dark — The Abyss (REBUILT to the MAXIM STANDARD 2026-09-19, §9.14):**
    THE FOURTH FINGER. The font's well has a bottom, and it shows only while
    the Deep stands in LIGHT — the one arrangement the whole lower vault
    punishes, and one only the arena's vane can make from below. On it lies
    a gnomon that fell an age ago, chained to a rusted ring at the rim:
    Spirit reads the chain, a Poison pip eats the rust, Dark hauls it up a
    length a press. Three, and it stands.
16. **Light — Afraid of the Light (REBUILT to the MAXIM STANDARD 2026-09-19,
    §9.15):** THE INDEX. The catalogue on the ledger walk is a case of ten
    panes, one per cell of the hall, whole only when every cell is lit — ten
    lumens, the state every star forbids. Crystal reads it whole and it
    names one of five slabs under the oculus; the volume under it is afraid
    of the light and comes out in TOTAL darkness only, to a Spirit pip. The
    hall's two maps, both extremes, and the douse ORDER between them.
17. **Blood — The Blood Is the Life (REBUILT to the MAXIM STANDARD
    2026-09-20, §9.18):** THE THROMBUS. The two dead vessels the Graft Star
    tells you to leave alone: turn them anyway, Light shows the clot for what
    it is, and on a flatline, with nothing pushing on it, Blood breaks it and
    the vessel takes. Both, and every road in the eight carries. The drum is
    gone, and with it the last reaction window in the set.

### Signature mechanic summary
Fire=ritual forensics · Lava=production-line casting · Lightning=zero-sum living
circuit · Water=tide states · Ice=reflection · Steam=pressure economy ·
Earth=buried giant · Mud=reshaping maze · Dust=conservation dig ·
Crystal=sliding rooms · Air=authored winds + cloud constellation ·
Plant=tiny/huge · Poison=diagnosis/triage · Spirit=memory/minimap stamp ·
Dark=shadow portals · Light=shadow-truth/exposure · Blood=heartbeat rhythm ·
Nexus=transmutation (rule manipulation).

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
- **Guardian HP** ×(1 + 0.18·n) → ≈3.9× at n=16; **damage** ×(1 + 0.12·n)
  → ≈2.9× (lethality comes from the longer fight, not one-shots); the rage
  aura DPS scales with the damage mul. (HP slope cut from ×0.45·n on
  2026-08-14 — see the balance pass below: once the base pool was sized
  against real party damage, the old slope pushed the last fights past two
  minutes.)
- **Lull strikes to fell the guardian**: `kGuardianBaseStrikes` (14) +
  0.75·n → 26 by the last dungeon. The strike chunk is `maxHp / strikesNeeded`,
  so this number is also the fight's **length CAP**: at ~2 paced strikes per
  3.0s lull in a 6s cycle the strike path alone runs ≈3× the strike count in
  seconds, however fat the pool is (42s fresh, 78s last).
- **Wisps / raid adds**: HP ×(1 + 0.22·n), damage ×(1 + 0.07·n).

#### The 2026-08-14 boss balance pass — MEASURED, not guessed
The complaint was that early guardians got one-shot. A headless sim (the
ideal trio parked on the perch, ATTACK + SPECIAL mashed the frame they come
up, utility pressed every lull) put numbers on it: **a three-Alchemon party
deals ~172 dmg/s at stat 2.0, ~393 at 3.0 and ~1005 at 4.5** against a
guardian pool of **341**. The mystic died inside a second — no cycle, no
planet twist, no half-HP enrage, none of what the fight was built to show.
Two structural facts came out of it:
1. The strike chunk being maxHp-fractional means **strike count caps fight
   length** — raising HP alone can never lengthen a fight past ≈3× the
   strike count in seconds.
2. Everything else has to be sized against **party DPS**, which the old
   pool was not: 341 HP is two frames of a mid trio.
So: `kGuardianBaseStrikes` 4 → **14**, `kGuardianBaseHp` (new) 220 → **6000**
(×1.3125 wave-7 curve ≈ 7.9k on a fresh save), contact damage 20 → 24, lull
strike pacing 1.2s → 1.5s (a 3.0s lull still fits exactly two), and the
campaign HP slope ×0.45·n → ×0.18·n. Measured result, seconds to kill and
lull windows seen:

| trio | first dungeon | seventeenth |
|---|---|---|
| stat 2.0 (early breeding) | **50s**, 9 cycles | does not finish |
| stat 3.0 (mid) | **32s**, 6 cycles | 128s, 22 cycles |
| stat 4.5 (near-perfect) | **13s**, 2 cycles | 68s, 12 cycles |

A near-perfect trio still blitzes planet #1 — that is the "you overprepared"
case, and it is left alone deliberately. Regression-pinned in
`planet_dungeon_full_run_test.dart` ("a guardian is not a wisp"): five
seconds of the party's whole kit may not halve a fresh guardian, and the
fight must run >15s and show ≥3 lull windows.

**Open observation (not yet acted on):** in the sim only ~3 of the available
lull strikes actually landed per fight — the utility press competes with the
room's own verbs (Air's rods/herd gust sit in the same button) and needs the
party inside 90px of a guardian that is actively hunting. The fights above
are therefore carried mostly by companion DPS, with strikes as punctuation.
If the strike is meant to be the spine of the fight, the dispatch order (or
its reach) is the thing to revisit.
- **Raids** stack their own 3×/1.5× on top — late-campaign raids are brutal
  by design. Replaying an early dungeon late in the campaign IS harder (the
  clock is global). Tests: `planet_dungeon_scaling_test.dart`.

### The guardian chamber — SEALED, then an ARRIVAL (built 2026-08-14)
Two rules, engine-shared, so every planet's finale opens the same way:
- **The chamber is sealed until its mystic is ROUSED.** `isDoorLocked` seals
  any door whose target room holds a `GuardianNode` while `!guardianAwake`
  (`_guardianDoorSealed`). A boss is walked into on purpose — never wandered
  into, and never found asleep on its perch. Each planet's rite is what
  rouses it (Air's twin conduits · Fire's ember bells · Water's frozen true
  moon-pools · Earth's hung scale · Steam's sunk crucible pedestal ·
  Lightning's latched beam), every one of them performed in a room OUTSIDE
  the chamber. The refusal names the rite and never the method, per planet,
  via `DungeonLayout.guardianSealedHint`. A banked Star 3 unseals it for good
  (solved is solved) and raids skip it (their guardian is already loose).
  **Lightning needed one retrofit:** Raikuma used to wake on ARRIVAL in the
  core, which would have sealed the room against itself, so it now rouses at
  the beam LATCH out in the maze (the same act that throws the powered
  barrier open) and SEIZES the dynamo only when it lands — stealing the
  trunk at the latch would have darkened the room the player was standing in.
- **The mystic ARRIVES.** Entering a roused chamber stages
  `kGuardianArrivalSeconds` (1.9s) of cinematic before the fight exists: the
  room shakes (`_shake`, applied to the camera in `render`, ramping through
  the fall and spiking to `_kImpactShake` on landing), a ground shadow
  tightens and a warning ring closes on the perch, and the mystic falls onto
  it with an eased-in drop. **The combat body does not exist until IMPACT** —
  no lull clock, no rage aura, no enrage, nothing to hit and nothing that
  hits you — so every fight starts from one clean readable beat. The chrome
  intro banner fires at the START of the fall, over the animation. Standing
  under it during the fall is refused ("It is still coming down — brace"),
  but the room's own verbs stay live everywhere else — ranking rods while a
  guardian falls is smart play, not a bug. Death resets the arrival, so a
  retry plays it again.

### Star authoring principle — the shape of every dungeon
**Star 3 is ALWAYS the mystic guardian** (relic drop + raid eligibility key off
`guardian.starIndex == 2` — layout-test enforced). **Stars 1–2 are order-free
puzzles**, and the guardian rite is engine-gated behind both of them:
`guardianRiteUnlocked` (raids exempt, banked Star 3 exempt for legacy saves)
keeps the altar conduits inert and the storm door sealed until the pair is
banked, with hints naming the missing keys. The storm-door reveal fires when
the SECOND of the pair lands, whichever it is.

### Guardian authoring principle — the guardian fights WITH the planet's rule
Seventeen finales must not be seventeen copies of one fight. The
lull/strike/calm grammar stays engine-shared, but every mystic WEAPONIZES
its planet's signature mechanic so no two encounters play alike:
✅ Leviathan turns the tide mid-fight (the arena floods and drains on its
roar, and its lull only opens on settled water — BUILT 2026-08-11) ·
✅ Raikuma FEEDS on powered trunks — cut its power to force the lull ·
✅ Simurgh re-lights the rite braziers as attack telegraphs — the order IS
the bullet pattern (BUILT 2026-08-11) · Boilrog vents the main (your own
budget becomes its
weapon) · Terradon's tremors knock the scale loose · Roc drags the
storm-cell across the rod field · Magmara rides the conveyors (§6.2).
AUTHORING RULE: every unbuilt planet's §6 entry declares its guardian
twist; retrofits for built guardians ride each planet's §9.1 rework pass.

### Star authoring principle — keep each star FOCUSED
One **core mechanic** + one **consequence** + a **success**. Family/stat quality
are *modifiers*, not extra required steps. e.g. Air Star 3 = "sync the conduits
(core) → mistakes spawn storm wisps (consequence) → success awakens Roc," with
Lightninghorn/Airwing/Firemask making it smoother — NOT
rune-order+conduits+stabilize+recipe+guardian+wave all mandatory at once.

## 7.9 Polish status — which planets have had the pass

BUILT is not POLISHED. All 17 are built and proved; this tracks which have
been through a device playtest and had their art, chrome and feel worked on
afterwards.

**ELEVEN of seventeen (2026-09-25): Fire · Air · Water · Earth · Lightning ·
Steam · Lava · Poison · Mud · Ice · Dust.** Poison was promoted 2026-09-14;
**MUD (pass 2026-09-13) and ICE (pass 2026-09-15) were promoted 2026-09-23**
on the author's account that both have been played; **DUST was promoted
2026-09-25** after its night-dig / sand-throw / observatory pass was played. This list is mirrored in code as `kPolishedDungeons`
(`lib/games/cosmic/cosmic_data.dart`), and it is what decides whether a planet
offers DESCEND or the coming-soon placard — the other ten keep their gate
ritual and cannot be descended. Promoting a planet is one line there, pinned
by `test/dungeon_polish_gate_test.dart`.

The through-line of all seven is that the suite was green the whole
time. Every fault that mattered came out of a device session or a rendered
screenshot — arrivals, doorways, unreachable ground, art that reads as
something it is not — and none of them out of a test that already existed.
Write the test AFTER play tells you what to look for; then it bites forever.

### ✅ LIGHTNING — complete (2026-09-01)

**It began as the inverse of Earth — the puzzles the strongest of the
unpolished set, the art the whole problem — and ended up rebuilt twice over
anyway.** The zero-sum trunk system under everything (power here = dark there)
was good from the start and still is; it is now what three of the four
mechanics are actually made of. The art pass came first, then the puzzles:

  · ✅ **THE BEST PUZZLE MOVED TO STAR 1.** The Storm Spire's stationing
    puzzle was the only one of the two beam halls that is actually alchemy —
    Air opens a vent, Fire stands in the wind and it becomes lightning AT THE
    FLAME, Lightning's iron carries it home. It teaches from the front now, in
    Pylon Hall, small: three vents, three converters, four conductors, one
    mast, provably unique. Its one deliberate trap is a vent and a converter
    lying in a line together, so the tempting pair really does catch — a real
    bolt is born and it dies in the east wall. *Making lightning is not the
    puzzle; landing it is.* The old threading star was retired rather than
    kept as a second unrelated mechanic.
  · ✅ **STAR 3 IS THAT BRAID AT SPIRE SCALE** — §9.4, and rebuilt three times
    to get there. See that section: one chain on all three masts at once, the
    last mast standing ON the core gate, a switchyard lattice instead of
    scattered coordinates, and a decoy net whose whole job is to give the
    wrong answers somewhere convincing to go.
  · ✅ **THE MIRROR GALLERY STOPPED PAYING OUT FOR WALKING AROUND** — §9.3.
    Which wing, and which side of the glass.
  · ✅ **THE DOORS LED SOMEWHERE** — the mirror gallery's two doors were on
    exactly the wrong walls, which is what made that wing read as a loop.

  · ✅ **THE HUB HAD NO ACTION PAD.** The four trunk breakers are declared on
    the LAYOUT, not on a room, so `hasVerbs` could never see them — and the
    run starts on the vault trunk with every star wing dark. Lightning could
    not be started on a phone, and passed every test, because tests call
    `activateAbility()` past the HUD's gate. Fifth instance of that blind
    spot and the worst of them.
  · ✅ **The floor is a storm-works, not graph paper.** It was a 96px square
    lattice under every chamber — the single biggest reason a dungeon whose
    premise is *the dungeon IS a living circuit* read as a circuit DIAGRAM. It
    is iron plate bolted down in offset courses now, with rivets, three heavy
    cable runs sunk into it under clamps, and the scorch blooms and branching
    scars of everything that has ever arced across it.
  · ✅ **Everything is bolted to something.** `_drawCircuitPost` — a bolted
    base plate, an iron column and a stack of porcelain insulator rings — goes
    under every source, sink, mirror, emitter, converter and terminal. The
    conductors were 42x8 white lozenges lying on the floor, the most schematic
    object on the planet and the one the player handles most; they swing in a
    yoke on a pivot bolt now.
  · ✅ **The hub reads at a glance.** Two faults, both navigational. The
    north wall carried the FINALE GATE at x 610-690 and the TREASURY at
    700-810 — **ten pixels apart**, a locked endgame door and a reward room
    reading as one doorway; the gate is dead centre now, directly over the
    dynamo, with 145px and 225px of wall either side. And the four trunk
    breakers sat in a blob around the rotor, so which switch woke which wing
    had to be traced along a wire or memorised — **every breaker stands in
    front of the door it feeds** now, so the geography IS the mapping. Both
    pinned in the layout test.
  · ✅ **The breakers are knife switches.** A backboard, two brass jaws, a
    hinged blade with a ceramic grip, and a contact arc when it closes — open
    and up when the trunk is dead, swung flat when it feeds. This is the verb
    thrown more than any other on the planet and it was a 15px circle with a
    stick on it.
  · ✅ **The rest of the furniture.** The DYNAMO was rings and spokes floating
    on the floor — the biggest machine on the planet, mounted on nothing; it
    has a bolted bed plate and two field-magnet coil blocks flanking the drum.
    The CELL SOCKETS were rings; something is meant to be SET into one, so
    they are cradles with a seat and two contact horns. The FULMINATE VATS
    were flat discs — the one thing in Star 1 that can kill a run, reading as
    a token on a board; they are riveted cauldrons on three legs. And the
    VAULT BOLT is banded and bolted, so a slab holding a treasury looks like
    one.
  · ✅ **THE THUNDERBOLT IS ITS OWN CHAIN** (see §7's maxim entry). It used to
    fire off Star 3's beam if a Lightning Horn happened to be in the room when
    the tower lit — a secret riding a star's coat-tails. It is built out of
    the one thing this planet owns that no other does: **the dynamo is
    ZERO-SUM**, it feeds one trunk and darkens the rest, and every wing you
    have ever lit cost you the other three. The secret is refusing that.
    **AIR** winds the rotor past its limit, and it bleeds back down on its
    own — that is the clock. **FIRE** fuses a breaker's blade shut, but only
    while the rotor is over, because a breaker built to open will not weld on
    the current it was designed for; four breakers, four welds, the repeated
    beat. **LIGHTNING** throws a dynamo that has nowhere left to choose, every
    trunk takes at once, and the works lets go. Nothing consumed: Lightning
    blows a weld back off, and a lapsed over-speed costs the walk to the rotor.
  · ⬜ CARRIED: device playtest of the Spire's difficulty specifically. The
    first lattice was solved in about five minutes; the decoy net is the
    answer to that and has not been timed yet. If it is still quick, the next
    lever is a mast that wants WIND rather than lightning, which squeezes the
    flame into a window instead of an extreme — verified buildable, not built.

### ✅ STEAM — complete (2026-09-02)

**The record and the game had come apart.** On 2026-08-14 both star rooms were
rebuilt from tile-lava chambers into geyser fields. That rework reached the
code and nothing else: the docs above still described a dam, the room's own
data comment still described its retired 10×12 grid, the Cinder Forge's
comment still called itself Star 1, eight tests still played rooms that no
longer exist — and **the objective line the player reads still promised "a dam
of old stone bars the way"** in a room that had not had one for weeks.

  · ✅ **The rooms stopped being diagrams.** A 104px square lattice under every
    chamber, on the planet whose whole premise is a PRESSURE RING-MAIN. It is
    firebrick in offset courses now, kilned unevenly and heat-bloomed, with the
    ring-main's own pipe runs sunk into the floor of every room under bolted
    flanges and a condensate grate down the low side.
  · ✅ **The Crucible stopped being a board game** — and the third star happens
    in it. Lava is a crust with its bright body showing through the cracks;
    rock is split basalt; walls are dressed blocks with a lit top and shadowed
    foot. The biggest single change was to stop drawing an outlined tile for
    the EMPTY cells: the lattice was the loudest thing in the room. The floor
    is continuous now and only the material sits on it.
  · ✅ **The geyser mouths got their geology** — sinter terraces built
    unevenly, a wet stain that never dries at the lip, a broken ring of stone
    teeth around a dark throat. (Everything the FX layer already did — steam,
    glow, the strain of a shut mouth — was left alone. The headless render
    lacks the baked sprites, so it shows the skeleton and not the room.)
  · ✅ **CHOOSE-YOUR-BREACH EXISTED NOWHERE.** The crucible's cisterns sat one
    column off — diagonally beside the meltable gates instead of orthogonally
    behind them — and `_wallIsWet` only looks at the four orthogonal
    neighbours. So not one gate on the planet was ever wet, the renderer's
    ember-crack state never fired, and the dungeon's first lesson had no
    instance in the built game. Two characters in the authored rows put it
    back, and the inner gate of each pair is the wet one, so **the greedy
    breach is the punished one**. A layout invariant now asks the REAL rule.
  · ✅ **THE PLANET WAS UNWINNABLE IN ITS INTENDED ORDER.** Three bugs, all the
    same shape — run-global state that should have been per-room:
      1. `capstoneBurst` is one latch shared by both geyser rooms. Star 1 sets
         it, and Star 2's win condition is guarded by `!capstoneBurst`, so once
         Star 1 was banked Star 2 could never fire at all.
      2. `earthRock` is one stone for the whole run. Raised to cap a mouth in
         the causeway it was still standing in the forge, where Earth is told
         "your stone already stands" — and the forge needs its stone to free a
         third body to ride. Worse, the stale coordinates were measured against
         the NEW room's mouths, so a stone left behind could cap a mouth in a
         chamber it was not in.
      3. `_tryEarthRock` claimed EVERY non-Earth press anywhere in a geyser
         room, and both geyser rooms have pressure-sealed doors — so a Steam
         creature standing on a clamped junction got "only Earth raises stone
         from this floor" and the junction was never thrown. A refusal must
         never outrank a thing that would actually work.
    The first two are scoped by room now rather than cleared on a room-change
    TICK: a tick-based reset fires on the first frame AFTER the change, which
    is after an action, and it was quietly wiping stones that had just been
    raised. (I shipped that version first and it broke the geyser tests, which
    is how I found out.)
  · ✅ **The eight stale tests are gone** — the suite is at two failures, both
    pre-existing balance tests unrelated to dungeons. Star 2's script now plays
    the field's real puzzle (cap, ride, and watch the throw decay as each body
    leaves), and the vault test was rewritten against the burst disc, since the
    forge plug it described no longer exists.
  · ✅ **STAR 2 WAS AWARDED FOR OPENING A DOOR.** Reported from the device as
    "I walked up to where star 2 is and instantly got it", and that is exactly
    what happened: the Cinder Forge is won by standing the whole party on the
    far shore across a chasm, and its south door sat AT (295,816) — inside the
    far shore. Walking in from the south manifold put the party down on the
    goal and banked the star on the first tick, chasm uncrossed.
      Moving the one door was not enough, and the layout test said why. The
      forge sits BETWEEN the two manifolds on the ring, so it is entered from
      above and below, and "vertical travel lands on the matching side" forces
      those arrivals to opposite ends of the room — so ANY chasm splitting it
      top from bottom has a door on each side, whichever shore holds the
      pedestal. The chasm runs north-south now, both doors open on the west
      shore, and the throw numbers were mirrored to keep the decay intact
      (r_long needs four mouths held, r_short needs two).
      New invariant, because this is a class and not an incident: **no way
      into a room may put you inside that room's own win region**, and no door
      may open on to it.

  · ✅ **AND THEN YOU COULD NOT GET BACK OUT.** Moving the forge's chasm put
    both doors in the north and south walls — but the near shore stopped at
    y=40/800 and the door mouths are at y=0/816, and **in a room with
    platforms only a platform is solid ground**. So both doors stood off the
    end of the floor: you step toward one, the walk refuses because the next
    step is void, and the room can only be LEFT by teleport. The shore runs
    the full height of the room now.
      The existing guard skipped this: "every molten-room door is passable on
      foot" only swept rooms with a molten grid, and the geyser rooms have
      none — they have PLATFORMS, which is the stricter case. It sweeps every
      Steam door now, skipping only doors the game itself reports as locked or
      hidden, so a gated door stays a design decision and an unreachable one
      is a bug.

  · ✅ **THE FORGE IS A DIFFERENT ROOM.** Rebuilt from play, in two passes.
      **Two mouths, not five.** It began with three hobs and two risers, which
      on a device is five near-identical circles when the whole puzzle turns
      on which is which. It is TWO hobs and ONE riser: cover both — Earth's
      stone on one, a body on the other — and the field is at full head.
      **Two caps against three Alchemons SPLITS THE PARTY.** One body has to
      stay holding the field while the other two ride the wide throat
      together, so the far shore must be finishable by whoever went. Steam is
      the one that stays, because the far shore is Earth's and Fire's work.
      **The gauge reads 0-99.** Counting mouths is the physics; "the riser
      needs 99" is a far better thing to know than "the riser needs two".
      **THE THROW LEFT THE BODY, NOT THE MOUTH — so a half-held field cleared
      the chasm.** Reported from play as "we didn't need 99 pressure". You may
      ride from anywhere within 44px of the throat and the throw was measured
      from the CREATURE, so standing on the east lip of the ring handed you up
      to 44px of free distance against the 25px that separates a full head
      from half of one. It leaves the mouth now, and a test rides from the far
      lip and requires it to still fall short.
      **PLUGGED MOUTHS FEED THE MAIN, and the riser wants an OVERPRESSURE.**
      A mouth you smother stops venting, so its head goes back into the
      boiler; a mouth still roaring BLEEDS it. The field and the ring are the
      same gauge. A plug is worth +40 and an open mouth is worth −45 —
      deliberately more, so that a boiler at its rated maximum with one mouth
      left open reads 94 and CANNOT clear the chasm however hard it is stoked.
      Both plugs are necessary rather than merely helpful, and the main has to
      be brought past 99 on top of them.
        (Without the bleed the main simply bought its way past a mouth that
        had never been covered, and the chasm could be cleared under the
        redline — reported from play as "it's still letting me bounce over if
        I'm not at max".) It is the one place on the planet
      where the ring's economy and a star puzzle are the same number, and the
      only place the main is asked to go over its rated maximum.
      The gauge says all of it: the boiler in amber, what the plugs put back
      stacked on in cyan, a dark red bite taken off the end for every mouth
      still roaring, a redline at 99, and the surplus spilling out past the bar
      in hot orange. The header counts the venting mouths by name. That spill
      IS the win condition, so it is the loudest thing on the screen.
      **A short throw is now watchable.** The throw used to TELEPORT — the one
      spectacular thing in the room was invisible, and a throw that fell short
      was indistinguishable from one that did nothing. Bodies arc now, lift
      scaled to the distance, and a throw that lands in the void drops into it
      in full view before scrambling back onto the shore it left. That arc is
      the room's only wordless way of saying *not enough head*.
      **THE FAR SHORE IS A CASTING MOAT.** One boulder lip at the head of a
      channel that runs the length of the shore down to the pedestal at its
      foot. Earth heaves a rock on; Fire melts it (**Earth+Fire→Lava**) and the
      melt runs DOWN — further with every press, and creeping back up the hill
      whenever it is left alone, because the front of a run of lava skins over
      the moment nobody is feeding it. A rock is worth about three pours and
      the moat wants more than one, so the pair over there have a rhythm to
      keep: Fire works the melt, Earth feeds it. Steam is the one element that
      would kill it outright and the one that cannot come. An objective line
      fires once, the first time anyone lands over there.
        (It was first built as three separate sockets to fill in any order —
        a row of switches, and a sequence rather than a thing you keep going.)
      **And the star condition had to change with it**: "the whole party on
      the far shore" is now impossible by construction, since the field needs
      a body holding it. The pour is the star.
      Two authoring notes worth keeping. The pedestal was never drawn in a
      riser room at all — the capstone body renders only in non-riser rooms —
      so the one room whose point is *get over there* had nothing over there
      to look at. And the mould's lips first went in side by side, 56px apart
      against a 62px working reach, so standing at one put you in range of its
      neighbour and only the first could ever be worked; they are stacked down
      the shore now, and the verb takes the NEAREST lip rather than the first
      in the list.

  · ✅ **THE WAY HOME IS THE THING YOU MADE.** Splitting the party leaves two
    Alchemons on the far shore with nothing to carry them back — the riser is
    on the near one. The finished cast runs out of the moat's foot and sets as
    a SPAN between the shores: impassable while the mould is still being
    worked, walkable the moment the star banks. (A door on the far shore would
    have done the job too; this is the same job done by the room's own
    fiction, and it is visibly the thing you just poured.) It is authored as a
    platform listed BETWEEN the two shores — so `platforms.last` is still the
    far shore, which the greeting and the win region both read — and held shut
    in the collision rules rather than added at runtime, so the geometry stays
    in one place.
  · ✅ **REGROUP RECALLS TO THE WAY IN.** It used to snap the inactive
    creatures next to the ACTIVE one, which is a traversal aid and not a way
    out of anything: a party split across a chasm could regroup on the wrong
    side and be no better off. It puts everyone back on the room's own
    doorstep now — the door's arrival point, or the entrance spawn. That costs
    you whatever the room had given you, so it can never be an exploit, and it
    is the one control that guarantees no room can strand a run.

  · ⬜ **The ring's economy shifted and nobody noticed.** Both star rooms used
    to make you cool lava on the way through, and cooling pays the main back.
    Geyser fields pay nothing, so Fire's stoke port is the only income before
    the crucible: the head buys two junctions, then every further junction is
    bought with a stoke and the wisps it draws. The ring can still be fully
    opened — on exactly one stoke, ending on an empty main. Playable, and
    arguably better (it costs fights, not arithmetic), but it is not what §6
    describes and it has never been felt on a device.
  · ⬜ CARRIED: device playtest; the rest of the art pass (the capstone slab is
    still a flat disc); Boilrog and the boiler heart unexamined.

### FIVE DOWN, TWELVE TO GO (2026-09-01)

**Polished: Fire · Air · Water · Earth · Lightning.** What that has come to mean, on top
of the art pass Fire set as the reference:

  1. **No star is one verb repeated.** Every "do the thing N times" star has
     been rebuilt into a mechanism, an order, or a deduction. This was the
     single most common fault and it was in six stars across the four.
  2. **Every room draws what it IS**, not a diagram of its own mechanic — and
     every piece of state a puzzle turns on is visible ON the thing it belongs
     to, never in a corner of the HUD.
  3. **The secret meets the MAXIM STANDARD** (§7): a chain, all three
     elements, the planet's own braid, one repeated beat, wordless past one
     line, nothing consumed.
  4. **Nothing can strand.** Every irreversible-looking edit has an undo, and
     the undo costs walking rather than the run.
  5. **The room can be navigated.** Lightning added this one: no two doorways
     on a wall close enough to read as one, and a control stands where the
     thing it controls is. Both are layout-test invariants now.
  6. **You arrive somewhere sensible.** Also Lightning's, and the most
     embarrassing class of bug found so far: doors on the wrong walls, an
     arrival landing on another door's hatch, an arrival in the far half of
     the room, and border iron laid straight across a doorway so the door had
     no reachable point in it at all. Four invariants across all 17 now, the
     last of them a flood fill rather than a rectangle test.
  7. **UNIQUE IS NOT HARD.** The single most useful thing learned in this
     pass. A provably-unique puzzle is unambiguous, which is a different
     property from difficult — with a live preview the player steers into the
     one answer instead of searching for it. Difficulty comes from wrong
     answers that look right, not from a bigger search space. §9.4 is the
     worked example.
  8. **Render the room before you trust it.** Three separate faults this pass
     were invisible to a green test suite and obvious in one screenshot: a
     wall painter laying rock over storm-glass, "light" drawn as a flat grey
     rect on the floor, and — twice — a cast block standing in a lane and
     eating a decoy's wind before it left the vent. The debug seam has been
     wrong twice too (no floor, then no walls/doors), so a shot that shows
     nothing is a claim about the SEAM until proven otherwise.

**AND CHECK THE ACTION PAD FIRST, EVERY TIME.** Five planets shipped with a
room whose verbs live outside `DungeonRoom` and therefore had no pad at all —
Air's hub, Water's reflection court, Earth's palm hollow, four of Lava's seven
rooms, and Lightning's hub, which made the planet unstartable. Tests never
catch it because they call `activateAbility()` past the HUD's gate.

  · ✅ **STAR 3 IS FOUR CORNERS NOW** — §9.5. The pour was the right KIND of
    puzzle and still the wrong room: a board on a floor rather than somewhere
    three creatures are. The crucible is a void with four terraces, each with
    two mouths, a riser and a socket naming the element that shuts it; held
    mouths feed the main, the main buys reach, and **the room opens only as
    you shut it**. The ladder (2 held → the hop, 4 → the crossing, 6 → the
    diagonal) is a layout test, so the geometry and the arithmetic cannot
    drift. Its worst bug was a DEADLOCK I costed wrong on paper: a body
    standing on an already-sealed mouth adds nothing, so "two sealed plus two
    holders" was really just two sealed, and the room could not be finished
    from the inside.
  · ✅ **BOILROG COULD NEVER BE REACHED.** A guardian's door stays shut until
    the guardian wakes, and Boilrog only woke from inside his own room. Every
    test that had ever reached the heart got there by teleport, so nothing
    had asked the door to open. The rite wakes him from the antechamber now.
  · ✅ **THE LAVA RUNS.** A growing rounded rectangle is a progress bar; melt
    in a stone gutter wobbles along both walls and leads with a tongue. Applied
    to the forge's casting moat and to the chamber grids, which merge into one
    mass instead of a field of tiles.
  · ✅ **AND YOU ARRIVED STANDING IN THE DOORWAY.** Reported from the first
    play of the four-corner room: the crucible's arrival sat 24px below the
    sill and the 34px spread ring put a body back inside the frame. The rule
    is now an invariant — an arrival stands 32px clear of any WALL door in
    the room it lands in — and it caught four more the same shape, in three
    other planets: Air's lower spire (16px) and both cloud-platform arrivals,
    Dust's three side doors and Dark's shade gallery (all 16px). A floor
    HATCH is exempt on purpose: Mud's risen wallows are climbed out of, so
    arriving on top of one is the fiction rather than a fault.
  · ✅ **THE MAXIM IS A PLACE** — §9.6. Hidden Harmony was a run-long
    condition (zero scalds, then zero short throws), which is an achievement
    rather than a puzzle, and the short-throw version punished the exact move
    the Cinder Forge teaches. The north manifold now runs 600px west into a
    dead spur, the main is split at the end of it, and only a main at 99
    carries a body down. §7's table moves Steam from ⬜ to ✅.
  · ✅ **THE LAST HOP WAS IMPOSSIBLE** — §9.5. The throw landed at exactly
    its reach, so four sealed corners (head 340, reach 774) sailed a body
    five hundred pixels past a heart two hundred and seventy away. It finds
    the first ground along the aim now. Two things hid it: the full run
    PLACED a body on the plinth instead of throwing one, and the landing
    check asked `_onSolidGround`, which does not know that the heart is not
    there yet.
  · ✅ **PLAYED, and the playing is what found the rest of it.** Every
    remaining fault on this planet came out of a device session and none of
    them out of the suite: arriving inside a doorway, terraces with no floor
    left for Earth's stone, a jet that read as cartoon smoke, a way home with
    no art on it, and a last hop that could not be made at all. Simulated and
    rendered is not played.

**The ten left** — and as of 2026-09-13 every one of them has had its ART
FOUNDATION and nothing else: Poison, Mud, Dust, Crystal, Plant, Spirit,
Dark, Light, Blood, Ice. See §7.10 for exactly how far each got and what is
still owed. None is promoted; none is descendable — all BUILT and proved, none through a polish pass. Their
secrets are the queue in §7's maxim table, and Steam moved that count: five of
seventeen clear the standard now, because a maxim that is a PLACE is the shape
the other twelve should be reaching for (§9.6).

One carried fault belongs to that queue rather than to any one planet:
**`MaskFilter.blur` in per-frame paint** is still the repo's main jank
source, ~310 sites, mostly cosmic. (The other, *Mud's fane arrivals land
inside their wallow hatches*, is settled — see the MUD entry. The exemption
was right, and it was right for a reason nobody had written down.)

### AMBIENT IS TEXTURE, NOT CONTENT (2026-09-14)

**The metric caused this, and the metric was mine.** The eight parallel art
passes were steered by an "emptiness ranking" — edge pixels per room — with
the note that under ~600 is a box. A number that rewards ink gets you ink.
Rooms went from 400 edge pixels to eleven thousand, and played, the verdict
was: *"you're adding too much detail to the world… it crowds things and makes
it hard to know what to do."*

The clearest case was Ice's orrery floor. Three brass orbits crossed the
whole room at the same weight and brightness as the socket rims — the four
things you actually seat a block in — so the room read as a diagram of
itself and the puzzle hid inside its own decoration.

**THE STANDARD IS HIERARCHY, NOT DENSITY.** The things you can act on are the
loudest things in the room; everything else is texture behind them. A room
earns its detail by having somewhere for the eye to land first.

Two levers, and Ice is the worked example:

  · **One knob per decorative layer, not twenty re-authored call sites.**
    `_kAmbientThin` (how many) and `_kAmbientFade` (how much they assert) are
    applied inside the generators, so the relative weights a pass chose are
    preserved and the whole ambient bed sits back behind the furniture.
    Raising them restores the busy version; they are the whole lever.
  · **Decoration is INLAY.** The orbits are sunk into the floor — thinner,
    dimmer, falling away outward — so the brightest brass in the room is the
    brass you can use.

Ice's orrery went 10,518 → 6,934 edge pixels and got BETTER, which is the
proof that the ranking was measuring the wrong thing. The harness is
recaptioned as an INK RANKING and reads as a smoke alarm: it can tell you a
room drew almost nothing, it cannot tell you a room is good, and a falling
number is not a regression.

**Still to do:** the same pass is owed on the other seven planets the batch
touched (Dust, Crystal, Plant, Dark, Light, Blood, and Spirit's field), each
of which needs its own judgement about what the furniture is and what the
texture is.

### §7.10 THE TEN — where each actually stands (2026-09-13)

All ten unpolished planets now have an ART FOUNDATION. **None of them is
polished, none is promoted, and `kPolishedDungeons` is unchanged**, so none
of the ten can be descended. This section exists so nobody reads the volume
of work below as a finished pass.

| Planet | Ground | Maxim | Sounds | Device |
|---|---|---|---|---|
| **Mud** | ✅ | ✅ §9.8 | ✅ | ⬜ **the gate** |
| **Spirit** | ✅ | ✅ §9.9 | ✅ | ⬜ |
| **Poison** | ✅ | ✅ 2026-09-04 | ⬜ | ✅ played |
| **Dust** | ✅ | ✅ §9.13 (2026-09-19) | ✅ (2026-09-19) | ⬜ **the gate** — see its entry |
| **Crystal** | ✅ | ✅ §9.16 (2026-09-19) | ✅ (2026-09-19) | ⬜ **the gate** — see its entry |
| **Plant** | ✅ | ✅ §9.17 (2026-09-19) | ✅ (2026-09-19) | ⬜ **the gate** — see its entry |
| **Dark** | ✅ | ✅ §9.14 (2026-09-19) | ✅ (2026-09-19) | ⬜ **the gate** — see its entry |
| **Light** | ✅ | ✅ §9.15 (2026-09-19) | ✅ (2026-09-19) | ⬜ **the gate** — see its entry |
| **Blood** | ✅ | ✅ §9.18 (2026-09-20) | ✅ (2026-09-20) | ⬜ **the gate** — see its entry |
| **Ice** | ✅ | ✅ §9.12 (2026-09-19) | ✅ | ⬜ **the gate** — see its entry |

Blood's generic fixtures were rebuilt as objects on 2026-09-20 and its
obstacles on 2026-09-25 (see its entry). Dust's observatory carries a local patch for a shared bug (below).

**WHAT THE EIGHT PARALLEL PASSES TAUGHT, beyond their own planets.** Every
one of them failed the same way at least once, and it is always the same
sentence: *a shape that is geometrically correct and reads as the wrong
object.* Trabeculae that grew from one wall and stopped in mid-air read as
fallen branches until they bridged wall to wall. A sinus was four
scaffolding poles until a throat was drawn as a hollow. Arcade arches
floated above their piers as croquet hoops. A stair was invisible from above
until its treads cast shadows — the shadow is what makes a shelf a shelf.
Ledger slabs outlined bright read as index cards; a mosaic with every tile
drawn read as a keyboard; a bronze lemniscate over two plinths read as
spectacles over a smile.

Three of those generalise hard enough to state as rules:

  1. **FLOOR IS STONES DIVIDED BY DARK; WALL IS STONES DIVIDED BY LIGHT.**
     A highlight on a stone's upper edge says the stone has a FACE and the
     light is above it, so a floor full of them reads as an elevation. Toxica
     read as a wall seen face-on for a whole pass because of that one line,
     and jittering the corners did not fix it — the courses had to go, the
     floor's vertical gradient had to go, and the tones had to split warm
     against cool.
  2. **A BLOCK WITH NO VISIBLE SIDE HAS NO HEIGHT**, whatever its shading
     says. A near face projecting below the collision rect is worth more
     than any amount of gradient, and a body ramps across its SHORT axis,
     because that is the axis a solid turns through.
  3. **"NOT A GRID" IS NOT THE GOAL.** Wandering lines that share nothing
     are as far from a floor as graph paper is, and read as scratches.
     Glazing is a MESH; paving TESSELLATES; what varies is cell size and
     angle, not whether the cells connect.

**Two shared-engine faults came out of it**, one fixed and one deliberately
not:

  · ✅ **An obstacle belongs to its planet.** `_renderWalls` drew every wall
    rect in all seventeen dungeons as the same fixed blue-grey with a bright
    top band — the fault the FLOORS were fixed for in §8, and worse, because
    an obstacle sits in the middle of a room the planet just drew. It read
    as a UI panel on the Beacon Archive's reading floor. Now derived from
    the planet's own sky palette, and `_planetOwnedWalls` lets a module that
    draws its obstacles properly (Plant's three) opt out entirely.
  · ✅ **`_renderIslandAndVoid` only sliced a room into HORIZONTAL BANDS**
    (fixed 2026-09-19, in the Dust pass). Any room whose `gaps` formed a ring
    left real walkable ground undrawn — Dust's observatory had no floor under
    Star 1's marquee gate, and Dust patched it locally. The shared renderer
    now takes a MOAT branch for any room with a gap that does not run the
    room's full width: the ground is the stage with every gap subtracted
    (built once per room), drawn as the same stone as a banded ledge with its
    rim run round the gaps' lips. Rooms whose gaps span the full width keep
    the banding untouched — only Dust's observatory has a partial gap
    (checked by script across every layout), so by construction no other
    room takes the branch. The room render metrics were captured before and
    after as a second check: the handful of rooms whose edge counts moved
    are the time-animated ones (Earth's ribs, Fire's choir, Poison's wards)
    that move between ANY two runs, and none of them has a gap. Dust keeps
    its own cut floor on top, as its art rather than as a patch.

**And a process note for the next time this is parallelised.** Eight agents
in eight worktrees, one planet's `part` file each, is a good shape — the
files never collided. What did bite: every worktree branched before the
shared work landed, so a returning file could silently REVERT a change
master had made to it in the meantime (Ice came back with the sound funnel
undone). A per-file merge is only safe if you diff it against what master
did to that file, not only against what the agent changed.

### ✅ ICE — complete (pass 2026-09-15, promoted 2026-09-23)

**The suite was green over a run-ending softlock, and that is the whole
lesson again.** Thirty tests, a full no-strand proof over 122 shaft states,
an authored orrery solution walked move by move — and one shove of the west
star-block put it in column 0, where no cell exists to push it back from and
no socket stands. **1,718 of the 2,330 reachable boards could never be
solved**, and the only way out of one was a party wipe. The proof the planet
already had was about the PARTY (`solveShaftDescent`); nobody had asked the
same question about the STAR.

  · ✅ **THE ORRERY CANNOT BE SHOVED INTO A DEAD BOARD.** A pusher may now
    stand one cell OFF the floor — the margin was always there, it was only
    `_orreryCellAt` that refused to name a cell out there — which takes the
    dead boards to **0 of 7,140**, pinned by `solveOrreryBoards()` in the
    module and a test that demands zero. The rimefall's thaw resets the
    blocks and the glass with the stairs as well (a full-state valve that
    resets half the state is half a valve), and an earned star is never
    given back.
  · ✅ **THE HOLE YOU FALL DOWN AND THE KERB YOU SEAT A BLOCK IN WERE THE
    SAME 66px.** Flue C's mouth sat on top of the last row's socket, so Ice
    standing on the kerb froze the flue instead of glazing, and every other
    element was told "only Ice sets this fall into a stair" and lost its
    shove. The floor moved up 40px, the mouth down, and a body standing
    inside the floor's own edge now works the FLOOR — the mouth is worked
    from the margin, where it is the only thing there.
  · ✅ **THE FOUR IRON STANDARDS ARE SOLID.** They stop a sliding block dead
    and a body walked straight through them. (Star-blocks stay passable: the
    authored solution stands on a block's own cell to glaze past it.)
  · ✅ **STAR 1 IS NO LONGER A FOOT-RACE.** See §9.10.
  · ✅ **THE BOSS ROOM DREW NOTHING AND TAUGHT NOTHING.** Frowyrm's hoarfrost
    pillar — the fight's only verb, and the thing its lull is gated on —
    starts SHATTERED, and shattered was five 16px stumps in wall-colour: a
    smudge in a dark hollow. It is a broken pillar now, bright fracture faces
    on a lit socket with the GHOST of the whole pillar standing over it, so
    the room says what it is missing. Insight in that room fell through to
    the flue line (the one room whose verb is not a flue was the one room the
    hint button would not discuss); it reads the fight now, and the room
    teaches itself once on arrival.
  · ✅ **THE PENALTY WAS INVERTED.** Every strike beat scours a stair — which
    costs a party that rode everything down exactly nothing, so the only
    player Frowyrm ever punished was the one who had done what the planet
    asks. With no stair standing it takes the RIMEFALL instead, which has to
    be re-frozen. Never a strand: Ice re-freezes it from the sump at any time.
  · ✅ **TWO IDENTICAL HOLES, OPPOSITE RULES.** The mouth's floor carries flue
    A and the THROAT, and both were drawn as heaped snow — one a ride you can
    freeze into your way home, the other the melt-fall's gullet that takes no
    frost and plunges past every level to the bottom. The throat is running
    water down a wet black pipe now, with its own ambient line, and the entry
    cap plates BOTH holes while the floor is sealed (one plate over one of two
    identical holes read as "that one is blocked, take the other").
  · ✅ **THE VAULT'S ONLY CLUE WAS A SPECK.** The cache is visible in exactly
    one place in the dungeon — the gallery's pool — and it was a 13px dot in a
    432px black disc. It is a lit thing standing on a LEDGE hanging in the
    reflected shaft, with rays, so it reads as a light up there rather than as
    a coin down here (Water's moon-well lesson).
  · ✅ **THE RITE'S PLINTHS WERE INDEX CARDS** (§7.10): flat rectangles with a
    bright outline round them. Blocks now — top face, near face, courses, and
    the only bright line along the front edge where the two meet. (Superseded
    2026-09-20: the plinths went with the rite, §9.19. The pier the font
    stands on keeps the block treatment.)
  · ✅ **SOUNDS**: one `_cue` in the whole planet became seventeen — the cap,
    every freeze, the ride that scours, the thaw, the block's run and its
    seat, every quarter read, the lodestone, the mark, the sweep, the font,
    the pillar.
  · ✅ **THE FULL MAP DRAWS THE SHAFT.** Ice had no atlas entry and fell back
    to the derived layout; the levels descend the middle of the chart now,
    each shelf hangs off its flue, and the throat runs down past every level
    to the sump.
  · ✅ **A STATES RENDER HARNESS** (`planet_dungeon_ice_states_render_test`):
    every flue state, the pool dead and reading, a road laid, the pillar up
    and down — asserted to be DIFFERENT PICTURES, which is Mud's lesson about
    a checksum that passes on a change nobody can see.
  · ✅ **THE FIRST TWO FAULTS THE DEVICE FOUND (2026-09-15), and both were
    the room refusing to talk.** *"Why does Light thaw, and why does it only
    work on the right one?"* — the cap seals the WHOLE floor and both holes
    are drawn plated, but the verb answered at one of them, so pressing Light
    at the other did nothing, said nothing, and taught the player that the
    ELEMENT was wrong rather than the spot. Either plate is the same plate
    now; the wrong hand is refused at both; insight at a sealed mouth reads
    the plate instead of falling through to the flue line; and the floor names
    the black ice once, when you first walk up to a hole (not on arrival,
    where it would talk over the primer). *"I froze the top left, went
    through, came back, and it is not frozen any more"* — the thaw, working
    exactly as designed and completely silently: see §5.7.

  · ✅ **"YOU GO THROUGH THE SAME DOOR AND END UP IN TWO SPOTS"** (device,
    2026-09-15) — **TWO MOUTHS NOW, AND THE TRADE IS GONE.** The flue was one
    hole carrying two doors on one rect, of which the module kept exactly one
    live; the layout test even exempted identical rects for it, on the
    argument that it reads as ONE opening that behaves differently depending
    on its snow. Played, it reads as one door with two exits, which is not a
    thing a player can hold in their head.

    The first fix was to TELL it better — primer, ambient, a line on the ride.
    That was the wrong instinct and the author said so: the second attempt
    tried to keep the exclusivity by making the two mouths share one heap of
    snow, and the verdict was *"spending snow or whatever this free vs cost is
    makes no sense and there's nothing showing that or intuitive about it, so
    probably remove that."* **An invisible shared resource is not a mechanic,
    it is a rule you have to be told.** So:

      · A head has TWO OPENINGS, each with ONE destination for the whole run
        and its own visible snow: the **shaft** (down a level, and the only
        thing frost turns into a stair) and the **ledge chute** (into the
        pocket, and nowhere else).
      · Nothing couples them. Freezing the shaft does not shut the chute;
        riding the chute does not touch the shaft.
      · A chute is a RAMP OF SNOW, and it is a ramp every time. It used to
        spend itself (the snow came down after you, and a bare slot was no
        ramp) to keep "enterable only from a slide you can't repeat" as a
        physical fact; that went on 2026-09-20 — see the Ice status below.
      · **What is lost is the ledger's "treasure-or-ladder exclusivity" row**
        — the two purposes are no longer one edit. Ice keeps its CLAIMED row,
        one-way descent with an engineered return, which was always the
        stronger half: the shaft must be frozen on the way down or there is no
        way back up it, and a ridden shaft is bare forever.
      · **Light drinks ONE PLATE AT A TIME.** Every hole in the mouth's floor
        carries its own black ice, melted separately and persisted separately.
        One press opening the whole floor taught that the holes were one
        thing, which is precisely the misreading the room has to prevent.

    The drawn mouths differ in kind, not just in state: the shaft is a wide
    black hole (heaped / stepped / bare), the chute is a smaller canted slot
    with its snow spilling over the lip toward the pocket it feeds, and the
    throat is running water. Pinned by the states-render harness, which now
    demands six distinguishable pictures of that one floor.

  · ✅ **WHERE YOU STAND TELLS YOU HOW TO SOLVE IT — both stars now**
    (author, 2026-09-15: *"I want the place we are standing to give us hints
    on how to solve the puzzle, like mirrors"*). The gallery already had it —
    the pool holds the quarter opposite you and nowhere else — and the orrery
    had nothing: you laid glass, shoved, and found out. Stand behind a block
    now and **the floor draws the run it would take**, dashed, with the cell
    it would stop on ringed — gold and kerbed if it seats, pale if it does
    not, and the cells it would CRACK behind it crossed out in red. It is the
    same deterministic walk the shove performs (`_orreryRun`, shared by both,
    so the preview and the shove can never disagree), shown before you spend
    anything: §8's plan-then-commit, and the Spire's wind preview precedent.
    **Knowing the answer and having it are now the same thing on this planet.**

  · ✅ **THE HINTS WERE TOO WORDY** — §5.6 says one short clause and this
    planet was writing paragraphs. Every line cut, the tiers hardest: the
    lodestone's rule went from 43 words to 13.

  · ✅ **THE LODESTONE STOPPED PRETENDING TO BE DATA.** Lit, it held two
    identical figures side by side as a worked example of the rule — and a
    frame carrying figures, in a room whose entire puzzle is comparing
    figures, reads as a CLUE. The author went looking for what it meant; it
    meant nothing. It is a lamp now and looks like one: a warm face, a glow,
    no chart, and no engraved plate under it.

  · ✅ **THE MAXIM HAS HAD THE TREATMENT (2026-09-19)** — see §9.12. It was
    a sighting gated on the Mirror Star and one press at the end of a shelf
    you can only fall onto. It is THE STRANGER now: a chain built on the one
    state the primer tells you never to make.
  · ✅ **THE SOLVED GALLERY STANDS ON RE-ENTRY (2026-09-19).** The banked
    chart stayed lit only for the run it was won in; a later descent found
    the pool dead black and every frame dark, as if the room had never been
    solved. The water holds the whole chart now, true end to end, with the
    lodestone lit — which is also what keeps the maxim open to a player who
    cleared the stars first.
  · ✅ **THE LEDGE CHUTES ARE RAMPS EVERY TIME (2026-09-20).** A chute used
    to spend itself on the ride — snow down after you, a bare slot, no way
    back onto that ledge until a thaw. It was a commitment that gated
    nothing: a ledge's only door scrambles back out to the level it hangs
    off, so the one-shot never cost a route, only a RETURN — and on flue B
    that return is the lens, which made the maxim's last two links a thing
    you got one visit at per run. No one-shots. The chute's snow holds now,
    `spentChutes` is gone, and the no-strand proof's state space dropped a
    dimension (the `shelfLosable` audit still passes, because what loses a
    shelf is gravity — being below it with no stair up — not the chute).
    The vault's §5.5 line is "enterable only by falling onto its ledge".
  · ✅ **THE VAULT GLOW IN THE POOL IS GONE (2026-09-20).** The cyan light
    bobbing in the reflected shaft was the vault's "visible only in a mirror"
    tell. Played, it was *"the blue star floating thing"* — an unexplained
    object in a room whose whole puzzle is reading objects in the water, so
    it read as a clue for the chart and confused it. With the ledge chute a
    ramp every time, the vault needs no tell: it is the pocket off the head
    that the chute obviously goes to. The pool shows the sky and the chart
    now, and the only extra thing that ever hangs in it is the stranger.
  · ✅ **AIR'S SWEEP IS A FLASH, NOT A REVEAL (2026-09-20).** Played: *"the
    wind mon in the mirrors shouldn't reveal everything."* The sweep stilled
    the water for 12s, so the room's reading verb was Air at the vent and the
    walked lamp was a formality. It holds the whole chart for 0.5s now and
    fades over 1.2s, laid OVER whatever the lamp is reading (`sweepLight`,
    combined by max), and re-arms in 4s instead of 14 because a glimpse is
    all it gives. The stranger still counts as seen if it shows in the flash —
    the once-in-a-lifetime line fires and says what was there.
  · ✅ **THE RITE IS A ROOM NOW, NOT TWO PRESSES (2026-09-20)** — see §9.19.
    Played: *"we need a way better puzzle to get into the boss area, it's
    really bad right now."* It was Air+Wing on one plinth and Ice on the
    other. The room is THE ROOF OF THE HOLLOW: the ice over the wyrm's lair,
    in panes under snow, and the way in is down through it.
  · ✅ **The device playtest — done; promoted to `kPolishedDungeons`
    2026-09-23** on the author's account.

### §9.19 ICE'S RITE — THE ROOF OF THE HOLLOW (2026-09-20)

**What it was.** Two plinths on a sundial floor: Air+Wing channelled conduit
A, Ice sang the font, both latched and the wyrm woke. Every §4 box ticked —
the hard gate on the right slot, one refusal for a party without the Wing,
nothing timed — and nothing to think about. The verdict from play was *"really
bad"*, and it was: a rite is the approach to a boss, and this one was a
corridor with two buttons in it.

**What it is.** The Star Font room's floor is the ICE OVER FROWYRM'S HOLLOW,
a 9×5 field of panes under snow between two stone shores (the near one under
the sump's door, the far one where the hollow's own way up comes out), with
the glacier for rims. The rules, all of them physical and all of them things
the planet already said:

  1. **SNOW BEARS ALL AND SHOWS NOTHING.** The primer's own words. Walk
     anywhere on it, three abreast.
  2. **LIGHT BARES THE PANE AHEAD**, and bare ice shows what it lies on. Over
     ROCK it is white and THICK — it holds everyone (the four corners, and
     the pier). Over the HOLLOW it is dark glass and THIN — **it bears ONE
     body**. A second is refused: *the ice groans under one already, it will
     not take two.* Said once, forced, the first time the hollow shows: *bare
     ice over the hollow bears one body, snow bears all.*
  3. **EVERY BARED PANE IS A BEARING.** The wyrm's breathing pushes the water
     under the roof AWAY from its head, and a bared hollow pane shows the
     drift — four motes with tails, running one way. Under its body the
     scales run the other way, TOWARD the head. Over the head: an eye, and
     hoarfrost blooming on the glass above it. So the head is triangulated
     from two bares, or found by baring the roof pane by pane — and every
     pane you bare over the hollow is a pane only one of you can stand on.
     **Information costs footing.** That is the whole strategic loop.
  4. **LIGHT MELTS BARE GLASS TO WATER**, and Ice freezes water back to thin
     glass (the pane AHEAD, never under your own feet, never under a
     companion's). Open water bears nobody. Over the head, the melt is not
     water: it is **THE THROAT**, and cold comes up it.
  5. **THE RITE.** The AIR WING turns the last breath down the open throat —
     the planet's second hard gate, stamped on a wrong family exactly as
     before (§4: the seal remembers). ICE sings the font on its pier. The
     pier is an island, water on three sides, so it is reached across the
     roof or by Ice freezing a way; a body standing on the pier is working
     the FONT (the orrery's lesson — the floor wins inside its own edge). Both
     halves sung, *under the roof the wyrm turns over, and every pane of it
     shudders.*
  6. **THE WAY IN IS DOWN THE THROAT, TOGETHER.** Awake, the throat bears a
     body — but only with the other two at its edge, each on its own pane
     (*not one at a time into that, gather at its edge*), and then the glass
     gives under the three of you. The hollow's door on the wall is never
     shown and never walked; the module takes it, so the fall is bookkept
     like every other transit (anchor, regroup, the wyrm's own descent).

**Why it is a puzzle and not a walk.** The head is rolled per run (a
connected line of five hollow panes, never water, never the pier — pinned).
You cannot see it. Looking weakens the roof under exactly the bodies that
have to cross it. The pier wants a crossing or a bridge. The throat wants
three standable neighbours. And the party is SPLIT by where it may stand,
which no other room on this planet — or any other — does: Steam throws one
body across a chasm; nothing before this limited where the OTHER two may be.

**What it refuses, and how (§5.6).** Every refusal is one clause naming what
is missing and is REMEMBERED for the hint button, never spoken unasked: the
ice that groans, the water that bears nobody (silent — a hole needs no line),
the stone that will not open, the body on the glass, the throat that will not
take frost, the breath with no throat to go down, the sleeping wyrm under a
throat you try to step into. Reads (what a bared pane shows) go on the
INSIGHT channel, because the line is the payload. Insight in the room tiers:
snow over glass → what bare ice shows and which way the black drifts → the
whole method. The room names itself on arrival (*the Star Font, on the roof
of the wyrm's hollow*) and again once it is awake.

**No strand, by construction.** Nothing cracks, nothing is spent, nothing is
timed. A bared pane stays bared; water can always be frozen back; Ice makes
its own footing and so can reach anything; the only water that ever appears
is water Light chose to make. The two-on-thin rule that an earlier draft
carried was cut for exactly this reason: two bodies stranded on thin glass
would have made Ice the third, and Ice is the rescue.

**Pinned** (`planet_dungeon_ice_shaft_test` · THE ROOF OF THE HOLLOW): the
authored roof (one pier, an island, the drop door hidden); the wyrm's roll
over 40 runs; Light bares the pane AHEAD and never its own; the drift runs
away from the head and the scales toward it; snow bears all, thin bears one,
rock bears all, water none; melt and refreeze; the head opening into the
throat on the second press and refusing frost; the Wing gate stamping its
chip, the stars gating the breath; the pier working the font; both halves
waking the wyrm; the drop refused with a body on the shore and taken with all
three at the edge. The states render harness draws snow, bared, throat and
awake as four different pictures — and the pictures were LOOKED AT before
this was written (glass had to be pulled apart from water by tone; the motes
had to be big enough to read).

**Not yet.** The device. The pane-ahead targeting is the orrery's facing
idiom and has the orrery's preview (the pane the hand would work is outlined
in its element's colour), but whether a thumb finds it natural on glass is
the device's to say.

### §9.12 ICE'S LOST MAXIM — the shaft you were told never to make

Star-Walker was one press: a telescope on flue B's shelf, gated on the Mirror
Star, answering Ice. The shelf was a real commitment (a slide you cannot
repeat), but nothing on it was a puzzle — §7's table graded it ⬜ and the Ice
entry carried it as the last thing owed.

**THE STRANGER.** Mud's lesson (§9.8) applied to this planet: *the best place
to hide a secret is the state your own stars punish.* Ice's primer opens with
its one rule — *a shaft goes down, and only down, unless you freeze the snow
in it into steps* — and every hint on the shaft steers you toward freezing.
A shaft ridden bare is the mistake. It is also, physically, the only mirror
on the planet: snow shows the water nothing and cut steps show it nothing, but
polished ice reflects, and the pool under a bare shaft sees past the mouth to
the sky.

  1. **RIDE FLUE A BARE.** Nothing is pressed for this. The reflected mouth of
     the shaft in the pool goes pale with sky — the one wordless tell — and
     it costs you the way back up until the rimefall, which is the commitment
     the secret rides on. A party that froze A (the right move) never sees
     it; to go back for it they thaw, and ride A down on purpose.
  2. **WAKE THE WATER AND WALK THE LAMP.** Light+Mask strikes the lodestone,
     as the star needs; then the stranger is read the way everything in this
     room is read — the Light hand parked across the ring from it, or the
     flash of Air's sweep. One star hangs out past the chart's
     band, warm where the chart is cold, flared where it is points, on ONE
     FRAME'S BEARING. Seeing it is what unlocks the lens (`strangerSeen`, per
     run), and it is said once in a lifetime: *up the bare shaft the water
     sees the sky, and one star hangs in it that no frame charts.*
  3. **RIDE CHUTE B.** The niche is a shelf you can only fall onto. You carry
     the bearing down with you, and you can come back for another go.
  4. **TURN THE WHEEL.** Air turns the lens a notch a breath, twelve notches
     round, always the same way: the repeated beat. The tube swings, eased,
     and an azimuth ring cut in the floor round the mount has the set notch
     lit — the old declination arc graded an angle nothing ever changed.
  5. **LOCK THE SIGHTING.** Ice, on the stranger's bearing, and the rite of
     three pays out. On any other bearing: a puff of frost and *empty sky*.
     Nothing is ever spent.

**What it refuses, and how.** The lens with nothing shown upstairs: *the lens
finds nothing the water has not shown* — WHAT is missing, held for the hint
button. A Light hand in the lens sees its own eye. The hint button in the
niche gives the one oblique line and nothing after it: *snow shows the water
nothing; a shaft ridden bare is a mirror, and the lens wants what the water
saw in it.* It does not tier and it does not track progress.

**Against the standard:** a chain (bare shaft → read → chute → turn → lock),
all three of the trio doing what they do everywhere else here (Light reads,
Air breathes, Ice freezes), a repeated beat at the end, wordless past the
first nudge, nothing consumed. The one thing it does NOT use is a recipe,
because Ice's dungeon teaches none — every verb on this planet is
element-only, and a secret may not introduce a braid the rest of the run
never taught.

**Two things this rebuild forced.** The bearing is rolled per run and never
the lodestone's (the lens RESTS on that one, and a secret the rest position
solves is no secret); tests pin both. And the gallery had to stand solved on
re-entry: the banked chart used to stay lit only for the run it was won in,
so a player who cleared the stars first would have come back to a dead pool
that could show them nothing. The water holds the whole true chart now with
the lodestone lit, which makes the stranger readable without a lamp once the
shaft above is bare — the secret stays open to exactly the player most likely
to go looking for it.

**Brute force is bounded and still gated.** Twelve breaths and a press each
lands it — but only after the water has shown the stranger, so the gallery
step cannot be skipped, and a player who saw the star knows the bearing and
has no reason to turn twelve times. Pinned by a test that walks the
brute-force loop and by one that refuses the unseen lens.

**The star path never passes it.** The niche banks nothing, its only door
goes back to the gallery, and a clean three-star run freezes A and never has
a bare shaft over the pool.

### §9.11 THE STANDING ORRERY — solid, directional, and it slides (2026-09-15)

Played, the floor was *"too easy"*, its star-blocks were walk-through, and
they teleported to the end of their run. All three are the same fault in
different clothes: **the one object you take hold of was not behaving like an
object.**

  · **SOLID.** A block you can stand inside is a decal. It stops a body now
    (its lump, not its whole cell, so you can still slip round it).
  · **AND THEREFORE JAMMABLE.** Three solid blocks can be packed into a corner
    where each stands on the only square the next could be pushed from —
    **151 of 7,140 reachable boards**. The answer is not a rule against it:
    it is **THE CRANK**, off the board at the east wall, which Light turns to
    put every loose block back on its standard and take the road up. Free,
    instant, local — a re-plan, never a re-descent — and it leaves SEATED
    blocks alone, so it undoes your working and not your progress. The search
    now asserts `startDead == false` rather than `dead == 0`: jams exist and
    are recoverable, which is the honest shape of this floor.
    (First built at the CENTRE of the grid, where its 66px reach covered four
    playable cells: Ice glazing near the middle was told "the crank answers
    Light", and Light melting there reset the whole floor instead of trimming
    one cell. **A lever that overlaps the board is a lever you pull by
    accident.** It answers only from off the floor now.)
  · **A KERB OPENS ONE WAY.** The sky turns one way, so a socket takes a block
    only if it is running WITH its orbit — east along the top, west along the
    bottom — and stops it dead at the lip otherwise. Sockets used to take
    anything from any side, which made the floor a five-shove formality: the
    nearest block was always already lined up with the nearest kerb. The
    minimum is **8 shoves** now, every one of them an approach, and the lip is
    drawn cut away on the side it opens with the orbit's arrow beside it.
  · **A GLAZE THROWS A ROAD** — three cells down the way you face, because the
    longer routes at one cell a press are a grind and not a puzzle.
  · **AND LIGHT TAKES THE WHOLE SHEET, NOT A CELL.** Played once more, the
    verdict was *"still a bit too easy, especially being able to melt
    individual pieces"* — and that is exactly right: per-cell melting let you
    lay any road at all and whittle it down afterwards, so **"where does this
    road END" — the only real question on this floor — never had to be
    answered before you laid it.** Light melts the connected sheet it touches
    now. A road is planned, and the way to make a short one is to throw it at
    something that stops it: an edge, a standard, a kerb, a block.
  · **AND A KERB IS CUT FOR ONE BLOCK.** Each socket bears a figure and takes
    only the block that carries the same one — so the sockets cannot be
    traded between blocks, and each block's route is its own problem. With
    the one-way orbits that takes the minimum from **8 shoves to TEN**, none
    of them a nudge into the nearest hole: the block you would expect to seat
    first has to be walked out to the west wall, up it, and brought back east
    into its kerb. The figure is cut into the kerb's stone and onto the block,
    because a rule you cannot see is a secret, not a puzzle.
  · **AND IT SLIDES.** Eased along its run, with spray off the leading edge.
    The board moves at once underneath, so nothing can desync off a drawing.
  · **A BLOCK IN REACH SAYS SO** — a cold ring under it when you are close,
    brighter and breathing on the one your facing would actually shove.

### §9.10 THE MIRROR GALLERY — the chart assembles in the water (2026-09-15)

Star 1 was rebuilt four times in one day. The first three are worth keeping
on the record, because each one failed for a reason that generalises.

  1. **A lap against a melt clock.** Silver eleven frames inside 13 seconds.
     A lap is ~7.2s at the engine's 187.5px/s, so it was not even tight — it
     was **walking speed as a puzzle**, and it sat in Blood's claimed rhythm
     seat besides.
  2. **"Silver the figure with no twin"**, read by walking the rim (the
     author's own suggestion, and the right instinct). It played as *"I just
     tap every one with Ice until I get a star."* **The answer was one of
     eleven, so eleven presses beat thinking.** A deduction is only a
     deduction when brute force costs more than reasoning.
  3. **Claim versus truth, per frame** — each frame cut with the quarter of
     sky it claimed, the water holding what was really there. Brute force was
     dead (the answer was a set) and it still was not a puzzle: **eleven
     independent comparisons, in any order, none affecting any other.** A
     checklist with good art is a checklist. *Nothing you learned changed
     what you did next, and nothing you did changed what you could learn.*

**THE FIX IN ONE LINE: make the evidence RELATIONAL.** If a single look can
settle a single frame, you have a list of chores. If a look settles a
*relation between two* frames, the parts have to talk to each other, and the
player has to reason across them.

**What it is now.** The ceiling's chart is one closed figure of 24 stars
running right round the ring; it is never seen directly.

  · **Silvering a frame throws its stretch of chart into the pool**, and
    frost comes off as easily as it goes on. The water is a workbench, free
    to rearrange, all day, for nothing.
  · **Neighbouring frames overlap** — two stars each, five covered — so no
    frame can be judged alone. Where two silvered frames disagree about where
    a star hangs, the line **FORKS**: two lines out of one star.
  · **A fork names a pair, never a frame.** One false frame forks against
    both neighbours; two false frames set apart fork independently; and
    pulling a TRUE frame out can quiet a fork just as well as pulling the
    false one. So the evidence never spells the answer — you chain it.
  · **The LODESTONE is the anchor**, and this is the first version where the
    marquee gate is load-bearing: Light+Mask strikes it, it hangs true, its
    stretch goes into the water, and every other frame is judged outward from
    it. Without it the room is not solvable, only guessable.
  · **THE LIGHT HAND IS A LAMP, AND THE LAMP IS WHERE YOU LEFT IT**
    (author, 2026-09-15). The pool is black glass to every other hand. A
    Light CREATURE — wherever it is standing, active or not — is shown the
    stretch ACROSS the ring from it, and the water closes again behind it as
    it walks. So **reading is a thing you are doing**, and the lamp is a thing
    you PARK: stand it on the rim, take Ice round the frames, and the stretch
    it is holding stays readable while you work. Three passes to get there:
    built sticky first (opened water staying open), which turns the read into
    a chore you clear and stop thinking about; then tied to the ACTIVE hand,
    which meant the water went black the moment you switched to Ice to act on
    what you had just seen. Tied to the light-bearer's POSITION it is finally
    both — a read you perform, and one you can set down.

    Three tunings from the same session, all of them felt rather than
    reasoned: the reach **eases off** at its edge (star-by-star snapping read
    as jaggy while walking), it is **narrower** than it was (42° full, dark by
    62°), and standing the lamp **over the pool itself shows nothing** — a
    lamp on the water has no far side to be reflected from, and the room may
    not hand you the whole chart for standing in the middle of it.

    **AIR's sweep** FLASHES the whole surface for half a second and fades
    over the next one (2026-09-20 — it used to still the water for 12s, which
    made the sweep the way to read the room and the lamp a formality). A
    glimpse of where to walk the lamp: help, never a gate, never a reveal.
  · **BANKING IT LIGHTS THE CHART UP.** The answer to this room is a PICTURE
    the player assembled out of twelve frames and a walked lamp, and it used
    to be banked with a line of prose. A cold fire runs once round the ring,
    each star flaring as it arrives and the whole figure holding bright behind
    it — and the solved chart then STAYS readable without the lamp, because a
    trophy you have to keep walking a light round is not one.

**AND THE STAR PAYOUT LOOKS LIKE THE REST OF THE GAME AGAIN (2026-09-15).**
The dungeon reward popup (and the raid one, and the elemental cache payout
that was deliberately matched to them) still carried a warm brown palette of
its own — panel `14120E`, amber `C4A35A`, border `74613A` — while cosmic and
survival had moved to black grounds and brighter ink. A star payout therefore
read as a screen from an older game than the one that opened it. All three
alias onto `CosmicScreenStyles` now: one set of tokens, and the dialogs cannot
drift apart again. (The in-dungeon HUD is still on its own browns — it is
in-world chrome rather than a dialog, and worth judging on its own terms.)
  · The star: **the chart covered end to end with nothing forking.** Some
    frames are hung false and are won by leaving them OUT; no two of them are
    ever adjacent, or a stretch would have no cover and the room would have
    no answer. Pinned by a test that enumerates all 2,048 sets a player can
    put in the water and checks what wins.

**And what it costs to be wrong: nothing.** No frost is ever spent, there is
no feedback until the chart closes, and silvering the whole ring — the brute
force move — always fails, because a false frame in the water always forks.

### ◐ BLOOD — the pass, minus the device session (2026-09-20)

The seventeenth and last, and the one §7.10 singled out for GENERIC
FIXTURES: ostia, cocks, balance, drum and vagal node were circles, rings and
bars standing on very good tissue. It also carried the set's last reaction
window — the heart-drum — and no sound at all, on the planet that IS a
sound. Rendered room by room first, then:

  · ✅ **THE MAXIM HAS HAD THE TREATMENT** — see §9.18. The drum is gone.
    The secret is THE THROMBUS now, in the exact act the Graft Star punishes,
    and every window in it is a whole phase.
  · ✅ **THERE IS NO REACTION WINDOW LEFT ON THE PLANET.** The layout header
    used to carve out "one deliberate exception" for the drum's ±0.85s
    window because it was optional. Optional or not, it was a reflex test on
    the one planet built to have none, and it broke the author's first rule
    (puzzles reward thinking, never timing). The header says so now, and a
    test pins that the shortest ask on the planet is the shortest phase.
  · ✅ **THE FIXTURES ARE OBJECTS.** An ostium is a SPHINCTER — a ring of
    fleshy folds round a dark throat that dilates on its own phase and stays
    open and wet once primed. A cock is a brass STOPCOCK on a stub of vessel
    let into the wall, its handle across the stub shut and along it turned;
    a grafted stub runs red with a thread of flow, a dead one is packed dark,
    and a seen clot shows its granules the whole length. The balance is a
    beam on a pivot post with two sconces hung by chains, tilting until the
    rite levels it. The vagal node is a KNOT of nerve, five cords into one
    ganglion, throbbing while it will answer. The pericardium's stitching
    stays.
  · ✅ **THE BEAT IS AUDIBLE, AND THE PLANET HAS A COUNTDOWN.** No sound in
    the whole orrery became nine, and one of them is the heart itself: a
    thud at the top of every systole, once a cycle, so it is a heartbeat and
    not a metronome. The pulse readout now carries the seconds to the next
    turn beside its four marks — the header promised windows a player can
    PLAN for, and a plan needs to know how long it has.
  · ✅ **A CLOSING ANNOUNCES ITSELF (§5.7).** A thrombosed cock's clots, the
    vagal arrest shutting every vein at once, and Sanguorath's skip shutting
    every leaflet all spoke on the plain hint channel. Consequences now.
  · ✅ **A typo in the cocks' insight** ("at rest'it") that would have read
    as a glitch on the one line that explains the Graft Star.
  · ✅ **A STATES RENDER HARNESS** (`planet_dungeon_blood_states_render_test`):
    the gate across the beat with its mouth shut / dilated / primed, the arch
    with its cocks shut / flagged / a clot shown on the pause / both
    carrying, the balance tilted and level, the node ready and spent —
    eleven states asserted to be DIFFERENT PICTURES.
  · ⬜ **CARRIED, AND IT IS THE PROMOTION GATE: the device playtest.** And
    the build note's tuning target with it: the longest forced wait (~20s in
    the reliquary). `Blood` stays out of `kPolishedDungeons` until it has
    been played.
  · ✅ **THE REVIEW (2026-09-25)** — every room rendered, every star checked
    for hidden rules and clocks.
      – *Two presses still had to land INSIDE a phase:* priming an ostium
        (one of them in the 4 s backwash) and breaking a clot (the 5 s
        flatline). The header's rule is WHERE, not WHEN, and the doors
        already honoured it (stand in the doorway; the beat opens it). Now a
        right hand pressed off-phase is LAID: a collar of the element's
        colour breathes round the mouth or the cock, and it takes by itself
        when its phase comes round, as long as the party is still in that
        chamber. Leaving lifts the hand. Pinned in the orrery test.
      – *The heart, felt:* a heavy lub-dub haptic the whole time you are on
        Hemavorn, silent on the flatline (so the pause the valves and clots
        wait for is felt in the hand), 60 bpm at rest rising to 140 as the
        stars, Sanguorath's waking and its falling health bring the end
        closer; it settles once the Systole Star is won. Its own tempo, laid
        over the 25 s puzzle clock — the clock stays as slow as planning
        needs. Respects the haptics setting.
      – *The obstacles were the shared rounded bar:* a fallen rib, a
        collapsed span, a keystone, a baffle and a knot of capillary were
        one crimson pill. Now a curved bone, a buckled tube with its lumen
        pressed to a slit, a cracked plaque wedge, a veined valve leaf and a
        ball of fine vessels, each with footing; the tissue ones swell on
        the beat.
      – *Left as is, knowingly:* rushing the lung can clear the stair and the
        weave on one diastole with about a second to spare; dawdling costs
        one beat's wait and nothing else. Worth watching on device.

### §9.18 BLOOD'S LOST MAXIM — the thrombus

*The Blood Is the Life* was the heart-drum: strike it inside a ±0.85s window
on the systole onset, twelve beats running — five minutes of standing in the
atrial gallery tapping on the beat. The layout header defended it as "the ONE
reaction-timed thing on Hemavorn", kept because it was optional and no star
sat behind it. §7's table graded it ⬜ *rhythm, one verb*. Both were right,
and the author's rule is simpler than either: puzzles reward thinking, never
timing. A reflex test does not become a puzzle by being optional.

**THE THROMBUS.** Mud's lesson (§9.8) on the planet with the cleanest
punishment in the set: the Graft Star's one consequence is that a thrombosed
cock, turned, wakes clots and takes nothing. The Light flag exists precisely
so you never turn one. So the secret is what a party does with a dead vessel
anyway — and "the blood is the life" is what a clot is not: old blood,
standing still.

  1. **TURN A DEAD COCK ANYWAY.** Two of the five collaterals are thrombosed
     each descent, and the flag tells you which. Turn it (Dark, the same
     element-only act as every graft). The clots come, as promised, and the
     cock stands turned on a vessel packed solid.
  2. **LIGHT SHOWS THE CLOT FOR WHAT IT IS** — the flagging hand's own verb,
     at the same cock: *the clot runs the whole vessel; old blood, standing
     still, and nothing is pushing on it.* The stub shows its granules the
     whole length.
  3. **ON A FLATLINE, BLOOD BREAKS IT.** With no pressure on it in the pause
     between beats, the heart's own hand moves old blood, and the vessel
     TAKES like any sound graft — a road the beat never gave the eight. The
     window is the five-second flatline, the ask is WHERE to be standing, and
     the readout now counts you down to it. Too early: *pressure holds the
     clot where it is; it wants the pause.*
  4. **BOTH DEAD VESSELS** — the repeated beat — and all five collaterals
     carry at once: the rite of three, at the last cock.

**What it refuses, and how.** Blood before the clot is shown: *dark inside,
and no telling how far the clot runs.* Any other hand once it is: *old blood
moves for blood, and nothing else.* The hint button in a chamber where a dead
cock stands turned gives the one oblique line and nothing after it: *a dead
vessel is old blood standing still; nothing moves it while the heart is
pushing — blood might, when it is not.* Until a dead one is turned, the
cocks' own teaching keeps that slot, because the flag is the most important
thing those rooms have to say.

**Against the standard:** a chain (turn → show → break on the pause, twice),
all three of the trio doing what they do everywhere else here (Dark turns a
cock, Light shows a vessel for what it is, Blood is what a heart answers to),
the Dark+Light→Blood braid standing in for a downed Blood hand as always, a
repeated beat, wordless past the first nudge, nothing consumed. It is also
the first maxim in the set whose place moves: which two vessels are dead is
rolled per descent, so it cannot be looked up.

**And the proof did not move.** A broken clot is a graft, and a graft only
ever ADDS a passage — reason 6 of the layout header — so the no-strand
argument is exactly as it was, and the descent test re-runs the search with
all five vessels carrying and still reads zero. The drum's egg id is kept
under the new name so a save that ever found it stays found.

### ◐ PLANT — the pass, minus the device session (2026-09-19)

Plant arrived closest to done of the unpassed six: two good stars that are
genuinely about size, the best safety result in the set (size-lock 0 without
the valve, by geometry), and a maxim §7 had already graded ▶. What it did not
have: any sound, a maxim with a PLACE or a reason, and a valve, a bed and a
gall that all fired silently. Rendered room by room first, then:

  · ✅ **THE MAXIM HAS HAD THE TREATMENT** — see §9.17. It hangs off the
    planet's own trap now: the giant root's trunk throws the shade the seed
    grows in.
  · ✅ **SOUNDS**: none in the whole planet became eleven — the briar, every
    gall, the pit's warning and the withering, each lamp, each of the altar's
    three steps, the sepulchre, a creeper and a trunk, Botanica's beat, each
    tending, the look.
  · ✅ **A CLOSING ANNOUNCES ITSELF (§5.7).** A gall changes every passage in
    the crypt for you; a trunk fills the crack it grew in; the pit's first
    turn is a warning and its second takes every road you grew; Botanica's
    beat rots a vine from two rooms away. All spoke on the plain hint channel
    and were dropped unasked. Consequences now.
  · ✅ **TWO FIXTURES ARE OBJECTS.** The seed-gall was three concentric
    circles — a target — and it is the one thing in the crypt that changes
    your size. It is a swelling on a stub of root now, and it BREATHES: the
    slit in it opens and closes. The grave-lamps were a rounded rectangle
    with a dot; they are bone sconces on brackets with a cup, a blackened
    wick when dead and a moving flame when lit, at a mourner's eye or a
    thumb's height.
  · ✅ **A STATES RENDER HARNESS** (`planet_dungeon_plant_states_render_test`):
    the porch knotted / open / small, the gallery's bed bare / creeper /
    trunk-with-shade / tended / risen, a sconce dead and lit, the bowl dry
    and woken — twelve states asserted to be DIFFERENT PICTURES.
  · ⬜ **CARRIED, AND IT IS THE PROMOTION GATE: the device playtest.** And
    the build note's open question with it: the party's drawn radius does
    not halve at tiny, and whether the redrawn ground carries the scale
    without that is exactly what a phone will tell us. `Plant` stays out of
    `kPolishedDungeons` until it has been played.
  · ✅ **THE REVIEW (2026-09-25)** — the Dust/Earth/Crystal pass: every room
    rendered, every star checked for hidden rules and clocks.
      – *A clock:* the mulch pit's second turn had to land within 4 s of the
        first. It stays armed now until you leave the room, and steams while
        it is (pinned in the crypt test).
      – *The hidden rule the planet turns on:* what a bed grows depends on
        the size of the hand that plants it, and nothing at the bed said so;
        the road it opens was a door that did not exist until it grew. At a
        bare bed you now see, ghosted, what a seed set at your size NOW would
        grow — at full size a creeper running to the door it will open, small
        a trunk with its bough out to its door and bark over the crack it
        will fill.
      – *The beds were invisible:* a dark slit on a dark floor. A bare bed is
        a kerbed plot of turned soil with the split down it.
      – *Growth snapped in one frame, as a rectangle and a circle.* A creeper
        now UNROLLS from the bed to its door (~1.8 s); a trunk rises from a
        root flare, puts its bough out over the floor to its door, leafs, and
        bark swells over the crack it filled. The far room shows the road's
        other end coming in at its door.
      – *A size change swapped the room in one frame.* The old size's ground
        dissolves over the new one (0.7 s) and the altar bowl swells/shrinks.
      – *The sepulchre was a blank tan slab.* A stone chest with a carved lid
        and clay along its seam; the rite drops the clay and slides the lid.
      – *Decorative clutter that read as machinery:* the walk's chevron
        runner (arrows), the court's jointed ring (a dial), the porch's
        root-boss and the hall's flower are gone; only the niche's effigy and
        the arena ring stay. Floor roots no longer come in through doorways
        or cross to the far wall, where they read as boughs and creepers.

### §9.17 PLANT'S LOST MAXIM — the shade the trap throws

*The Unseen Shade* was the closest of the unpassed maxims: three tendings
small, then a look from your own size. §7 graded it ▶ and asked to check the
elements. What it lacked: a place with a REASON (a spot under a root you
already cross), an order, and any hint anywhere.

**THE SHADE THE TRAP THROWS.** Mud's lesson (§9.8), and this planet has the
sharpest trap in the set to hang it on. The layout header names it: b_root's
trunk is the bough over the gallery wall that fills the worm-run and costs
the only small road to the islet — Star 1's seed step and the vault both.
Every hint on the planet steers you off it, and 142 of the 448 states are
strandable without the withering, every one of them a b_root trunk. So the
seed nobody planted lies exactly where that bough throws its shade, and a
shade is what a seed that wants to grow unseen would want.

  1. **GROW THE TRUNK.** Plant b_root while small. The bough comes up over
     the gallery wall, the worm-run is gone, the small road to the islet is
     gone — and a long shade lies across the gallery floor from the bed to
     the far wall. Nothing is pressed for the secret here; the shade IS the
     room's clue, and a small body in it finds the seed.
  2. **TEND IT THE ALTAR'S THREE WAYS, IN THE ALTAR'S ORDER.** Loam (Mud),
     seed (Plant), sun (Light) — the same three verbs the Bloom Star already
     taught, in the same order the ground puts them in. Small, in the shade.
     Out of order is a puff and a sentence: *dry shade, it wants loam before
     anything* · *loam in the shade, and nothing set in it yet* · *set and
     fed, and it has never seen a sun.* The repeated beat, and nothing spent.
  3. **COME BACK AT YOUR OWN SIZE.** A small body in the gallery has no gall
     to hand; the nearest is the porch's, out along the moss walk and back.
     What grew in the shade is only visible to a body that can stand back
     from it, and a Plant hand at your own size brings the rite of three.

**What it refuses, and how.** Before the trunk: *bare ground, and nothing
above it to throw a shade.* A huge hand at the seed: *something small in the
shade, too small for this hand.* Tended but still small: *it has everything
it wants; nothing this size can see it grow.* The hint button in the gallery
keeps the bed's own teaching (the trap is the most important thing that room
has to say) until the trunk stands — and then gives the one oblique line and
nothing after it: *something small lies where the bough throws its shade, and
it wants what the altar wanted, in the order the altar wanted it.*

**Against the standard:** a chain (trunk → three tendings in order → change
size → look), all three of the trio doing exactly what they do at the altar,
a repeated beat, wordless past the first nudge, nothing consumed. The
withering takes the shade but not the tending — the seed keeps what it took —
so a player who sprang the trap and had to ring the valve is not sent back to
zero. The star path never passes it: the authored descent grows b_root as a
CREEPER, and no star wants its trunk.

### ◐ CRYSTAL — the pass, minus the device session (2026-09-19)

Crystal arrived with the deepest proof in the set (parity, 1.6 million
player-aware states, the anneal measured load-bearing against 7,404 jams),
two real sliding puzzles with live readouts, and good cell art. What it did
not have: any sound, a maxim that was one positional beat nothing taught,
and a valve that fired silently. Rendered room by room first, then:

  · ✅ **THE MAXIM HAS HAD THE TREATMENT** — see §9.16. "All three in the
    split beam" became THE BLACK CELL, WEDGED: a chain that lives in the one
    state this planet was built to rescue you from.
  · ✅ **SOUNDS**: none in the whole planet became ten — the face cracking,
    the lamp, the shard, the font, every shunt, the chain both ways, every
    choir plate, Prismalith's beat, the anneal, the flaw, each strike.
  · ✅ **A CLOSING ANNOUNCES ITSELF (§5.7).** The anneal costs every slide
    you made; the berth chain sets the whole keep solid; Prismalith's beat
    moves the keep from two rooms away. All three spoke on the plain hint
    channel and were dropped unasked. Consequences now.
  · ✅ **A STATES RENDER HARNESS** (`planet_dungeon_crystal_states_render_test`):
    the Black Cell sealed / flawed / crazed clear, the hearth cold and warm,
    the beam row dark and lit, the choir's gap in the corner and under the
    mystic — nine states asserted to be DIFFERENT PICTURES.
  · ⬜ **CARRIED, AND IT IS THE PROMOTION GATE: the device playtest.**
    `Crystal` stays out of `kPolishedDungeons` until it has been played.

### §9.16 CRYSTAL'S LOST MAXIM — the Black Cell, wedged

*Know Thyself* was one positional beat: stand all three bodies in the split
the Shard Hearth throws when it stands in the lit row. §7's table graded it
⬜, and the module's own comment admitted *no hint anywhere teaches this.*

**THE BLACK CELL, WEDGED.** Mud's lesson (§9.8) on a planet that cannot
strand: Vitrea's one failure state is the JAM — a body inside a chamber whose
cut faces both give onto the frame, with the hollow out of reach — and the
layout header names the Black Cell in a corner as the clean case. The
reachability search counted 7,404 of them, and the anneal exists for exactly
this. It is the state every hint on the planet steers you away from, and it
is the one room in the keep whose every wall is black glass. So that is where
the secret is, and "know thyself" is what the glass does: it shows nothing
but whoever stands in it.

  1. **WEDGE YOURSELF ON PURPOSE.** The Black Cell is cut north and west.
     Ride it into the north-west socket and both doorways meet the keep's
     own frame — a sealed box, the party inside. Nothing is pressed for this;
     inside, every wall throws the three of you back, a beat late (the room's
     own ambient line, *your own shape walks the far wall, a moment late*,
     was already saying so). The keep OPENS with the Black Cell in that very
     corner, empty: the first thing a player sees is the box they will later
     have to be inside.
  2. **THE SMALLEST FINDS THE FLAW** in the east face — the rite's own
     declared Pip gate, the body that slips a crack, doing here what it does
     at the tuning hall.
  3. **LIGHTNING RUNS IT, THREE TIMES** — the entry rite's verb, the one hand
     that cracks glass, as the repeated beat. The craze spreads from the flaw
     with each strike, and at the third the black goes clear.
  4. **CRYSTAL READS THE GLASS** — the mask's own job on this planet — and
     the three shapes resolve. The rite of three, over the hearth-mark.

Then out: the plate you rode in on rides the cell straight back (the hollow
is where you came from), or the anneal from the boss in the cell's own corner
rings the keep home and puts you out on the oriel. Writing the test caught
the wording: the sealed Black Cell is a box with no DOORWAY, not a strand —
the search's true jams need the hollow out of reach as well, and riding in
always leaves it adjacent. The secret asks for the shape of the jam without
its cost, which is the right shape for a room built for curiosity.

**What it refuses, and how.** In the Black Cell anywhere but the corner:
*black glass, and a doorway still cut in it somewhere.* Lightning before the
flaw: *a flaw in the glass, and nothing here to run it.* Crystal before the
strikes: *three shapes in clear glass, and only Crystal reads glass.* The
wrong family at the flaw: *only the smallest finds the flaw in this glass.*
The hint button in the Black Cell gives the one oblique line and nothing
after it: *the black glass shows nothing but whoever stands in it; wedge it
where no door meets a door, and see who is there.*

**Against the standard:** a chain (wedge → flaw → three strikes → read), all
three of the trio doing what they do everywhere else here (Crystal shunts and
reads glass, a pip slips a crack, Lightning cracks glass), a repeated beat,
wordless past the first nudge, nothing consumed. The star path never passes
it: no star wants the Black Cell anywhere in particular, it is neither clear
glass nor a throne, and no star ever wants a body inside a chamber with both
doorways on the frame. The wedge is reached by the engine's own shunt from an
arrangement four legal moves off the opening, which the test walks.

### ◐ LIGHT — the pass, minus the device session (2026-09-19)

Light arrived with the cleanest safety argument in the set (every move has
an inverse; 0 strandable with no valve) and two good stars. What it did not
have: any sound, a maxim that was anything but the vault's own dark walk, a
readout that let you see what a press had done to bays you were not in — and
one real bug in the boss room. Rendered room by room first, then:

  · ✅ **THE MAXIM HAS HAD THE TREATMENT** — see §9.15. "Cross casting
    nothing" was the same walk the vault demands, awarded twice. It is THE
    INDEX now, hidden in the opposite extreme: the hall blazing at ten.
  · ✅ **SOLARIN'S PILLARS SHADE YOU IN THE RULES, NOT JUST THE PICTURE.**
    The glare was drawn with the three pillar shadows bitten out of it and
    the lull was gated on standing in one — but the BURN ignored the pillars
    entirely, so a body standing exactly where the room said it was safe
    took damage every frame. The room said one thing and the floor another,
    which is §7.10's whole rule. One geometry now, shared by the lull and
    the burn, and a test stands a body behind a pillar in the glare and
    checks it keeps every point of health.
  · ✅ **LESS BROWN** (author, 2026-09-19: *"light looks too brown"*). The
    sky's shadow was a brown-black and its stone a warm tan, the module's
    ink a brown-black and its stone a greige, and the bays were oak on tan
    on brown. A shadowed hall is COOL: the sky's shadow is slate now and its
    stone bone limestone; the ink is cool; the glass, its lead and the
    limewashed masonry all moved off the warm side. The oak stays oak and
    the beams stay gold — the warmth belongs to what the light lands on,
    not to the dark.
  · ✅ **THE HALL IS IN THE READOUT.** Five marks beside the lumen count, one
    per sector, the top half its rim band and the bottom its inward band
    (Dark's eclipse marks) — so what a beacon press did to bays you cannot
    see reads at a glance, and the smallest light that is still a road can
    be PLANNED. The catalogue is the same map as a physical object.
  · ✅ **A CLOSING ANNOUNCES ITSELF (§5.7).** A beacon press rewrites floors
    in bays you are not standing in, and the line that named the setting was
    an ordinary hint — dropped unasked. It is a CONSEQUENCE now, as is the
    wardens lifting off the gallery when the hush is crossed.
  · ✅ **SOUNDS**: none in the whole planet became nine — the shutter, every
    press (and a kindle), the wardens waking, a stone read, a slip drawn,
    the ring, the index read, the slab.
  · ✅ **A STATES RENDER HARNESS** (`planet_dungeon_light_states_render_test`):
    the doorway shut / blazing / dark, the court under the keepers' fan / a
    low fan / two read, the catalogue as the hall stands / whole / read, the
    slabs unread / named in the dark, and the glare with its bites — twelve
    states asserted to be DIFFERENT PICTURES.
  · ✅ **THE REVIEW (2026-09-25)** — the Dark pass, applied: every bay
    rendered with the real sky, every star checked for hidden rules and
    clocks. No clock anywhere: every verb is a press at a place, and
    Solarin's safe ground is the pillars' shadows, which do not move.
      – *A beacon press was blind.* Each beacon cycles DARK → four settings,
        and you learned a setting only by committing it. At a beacon with a
        hand that can throw it the readout is NEXT PRESS: the lumens and the
        hall's five marks as they would be after one more press (pinned: the
        preview changes nothing and matches the press).
      – *The effigies were four identical busts* with no word of who reads
        them, and a read one drew the same as an unread one. Each is its own
        carving (moth wings shut, scholar with a key, warden facing the door,
        sun on a pole) with its element's planet glass in the plinth. Its
        shadow falls only while the stone is lit, and while the niche is
        dark too it is the TRUTH, crisp and black — wings open, a knife,
        facing away, a hole — which is exactly when it can be read. Read, the
        truth stays and the plinth gets a line of gold.
      – *A glared mirror sill was drawn LOCKED* (bars, gold keyhole). Its
        glass is white glare now, no bars; at its foot black mirror flags,
        and a pool of glare spills in over them while lit. An open glass
        leaf has a threshold of lit panes. The coloured plates are gone.
      – *Sills swapped in one frame.* Dark's eased doors are shared now
        (`_worldDoorWalls` / `_easeWorldDoors` in the glass part): glass
        leaves split open or seal over, mirror sills flood with glare, over
        ~0.55 s.
      – *Clutter.* Every bay was furnished — presses, carts, benches,
        carrels, card cabinets, desks and stools, arcades, cocoons, piers,
        a balustrade, worn ways, a brass plan, a ringed stair (a target), a
        ticked drum wall (a dial), scorch arcs, loose pages over every
        floor, boarded panes and panes drawn missing (a hole in a floor, on
        the planet where a hole means you cannot walk). All gone. What stays
        is what a bay is for: the two great stacks, the shelves each slip is
        filed behind, the Dark Stacks' own runs, the effigy plinths, the
        reliquary shrine, the prism oriel and the arena's pillar footings.
      – *A won star drew un-won after a fall* — seeded on every reset and
        in onLoad, pinned. *Solarin woke silently* — it has a
        `riteWakeLine`. The full map shows each bay's light (a gold disc,
        half for the rim only, or dark), with a legend.
  · ⬜ **CARRIED, AND IT IS THE PROMOTION GATE: the device playtest.** Same
    sentence as Mud's, Ice's, Dust's and Dark's. `Light` stays out of
    `kPolishedDungeons` until it has been played.

### §9.15 LIGHT'S LOST MAXIM — the index

*Afraid of the Light* was a RESTRICTION: walk from the doorway to the
reliquary with no lumen showing. That is the same total-darkness walk the
vault's essence already demands — §6 said so outright — so the "secret" was
paid for the treasure, and §7's table graded it exactly what it was.

**THE INDEX.** Mud's lesson (§9.8) applied to a planet whose every objective
wants LESS light: the effigies want a shadow to read, the slips want the hush
of two, the vault wants none at all, and the wardens count every lumen over
two. Nothing in the archive wants the hall lit whole. Ten lumens — every
beacon thrown high, every niche flooded, every heart sill glared shut, the
wardens off the gallery — is the state the whole planet spends the run
steering you away from, and it is where the index is whole.

  1. **BLAZE THE HALL.** Three beacons walked to and thrown high until all
     ten cells are lit: the repeated beat, and the planet's whole verb. It is
     reachable — the rim's glass is all floor when it is all lit — and it
     costs you the wardens once, as the hush is crossed.
  2. **READ THE INDEX.** The catalogue on the ledger walk is a case of ten
     panes, one per cell, each lit with its cell — a live map of the hall in
     every state (the readout's marks made physical), whole in only one.
     CRYSTAL, which splits one shaft in two, splits the full light into its
     letters, and the lens under the case shows a numeral: one of the five
     slabs under the oculus, rolled per run.
  3. **PUT THE ARCHIVE OUT — IN AN ORDER THAT LEAVES YOU A ROAD.** The oculus
     stair is a heart room with nothing but mirror sills onto it, so the
     dark is the only way in. Every beacon stands in a rim bay whose ways
     out are glass, so the LAST beacon you douse has to be the narthex, from
     the doorway, whose undercroft is mirror-stone and opens as the light
     dies. Douse the ledger last and you stand in its bay on glass with no
     floor — a re-press, never a strand (a press is its own undo), but the
     plan has to be made before the first pan goes out. The planet's thesis,
     *the road and the wall are the same object*, as the last move.
  4. **THE SLAB GLOWS IN THE DARK** — what the light wrote, read where there
     is none — and a SPIRIT PIP draws the volume from under it: the same
     hand and the same declared gate (`hush_slip`) as every slip behind the
     shelves. The rite of three over the slab.

**What it refuses, and how.** Crystal at a half-lit index: *the index shows
what the hall shows it, and N of its ten panes are dark.* Any other hand:
*ten panes of glass, only a Crystal splits them into letters.* A slab with a
lumen still showing: *afraid of the light — nothing comes out while N lumens
still show.* A slab before the read: *five slabs, and nothing filed under one
until the index has been read.* The wrong slab: a puff and *nothing filed
under this one.* The hint button on the ledger walk gives the one oblique
line and nothing after it: *every star here wants the hall dark; the index
wants all of it lit, and what it names is drawn in no light at all.*

**Against the standard:** a chain (blaze → read → douse in order → draw), all
three of the trio doing what they do everywhere else here (Light throws and
douses the beacons, Crystal reads by splitting light, a Spirit pip reaches
behind a shelf), the Crystal+Spirit→Light braid standing in for a downed
Light hand at every beacon as always, a repeated beat, wordless past the
first nudge, nothing consumed. The star path never passes it: every star
wants the hush, and nothing on the authored line lights the hall whole.

**And it cost the safety argument nothing.** Ten lumens is one of the 963
states the proof already enumerated; the douse order is the proof's own
"every move has an inverse" felt from the inside; and the descent test walks
the whole chain through the real door rules and re-runs the proof at the
end, still zero.

### ◐ DARK — the pass, minus the device session (2026-09-19)

Dark arrived with the strongest proofs in the set (0 strandable of 392 with
no valve, the algebra measured) and the best-argued ground — and every
FIXTURE on it was a diagram: the gnomon a bar with a bar for a shadow, the
dial two circles and four squares, the anchors plain rings, the snuffer
three yellow dots, the abyss a black disc. No sound anywhere, and a maxim
graded "a wait". Rendered room by room first, then:

  · ✅ **THE MAXIM HAS HAD THE TREATMENT** — see §9.14. A sixty-second vigil
    became THE FOURTH FINGER, hidden in the one arrangement the lower vault
    punishes: the Deep in light.
  · ✅ **THE FIXTURES ARE OBJECTS** (§7.10's rule: a shape that is
    geometrically correct and reads as the wrong object). A gnomon is a
    tapered finger of black glass on a bronze collar, and its shadow a hard
    WEDGE lying toward the quarter it holds. The dial has its hour ticks and
    its stones are plinths with a top face and a near face — a block with no
    visible side has no height. An anchor is an iron ring in a socket that
    weeps rust down the stone until a pip eats it, and turns slowly in its
    hole once the far side is really open. The snuffer's lamps stand on
    brackets and BURN — a flame is a shape that moves, not a dot. The pall
    hangs in folds from a knot. The vane is a graduated floor disc with a
    handle lying to the quarter it holds. The abyss is a WELL.
  · ✅ **WHERE YOU STAND TELLS YOU WHAT THE PRESS WILL DO** (§9.11's
    precedent). With a night-hand in reach of a gnomon, the wedge it would
    throw on the OTHER side is ghosted in, breathing — the turn can be read
    before it is made, which is §8's plan-then-commit on the planet whose
    every verb is a commit.
  · ✅ **SOUNDS**: none in the whole planet became ten — the pall, every
    turn (and the vane), a stone seating, the rust off a ring, a Spirit
    read, a portal transit, the snuffer, Noctryos' beat, a haul, the finger.
  · ✅ **A CLOSING ANNOUNCES ITSELF (§5.7).** A turn shuts every passage cut
    through the quarter the shadow left, somewhere you cannot see, and the
    line that said so was an ordinary hint — dropped unasked. It is a
    CONSEQUENCE now, as is Noctryos' beat (from update, where a plain line
    was always silent) and the first portal transit's "something comes out
    with you".
  · ✅ **A LOT DARKER** (author, 2026-09-19: *"we should make the background
    for dark a lot darker"*). Two faults. The porch and the court sat ABOVE
    the shader's mood baseline (0.70 and 0.60 against 0.5), so the top of
    the vault was brighter than a neutral planet; every room's mood now sits
    well below baseline (porch 0.34 down to the font at 0.06). And the sky
    palette itself was an umbral indigo with a cream corona at full
    intensity — a blue dusk; the horizon is a bruise now, the corona a dim
    violet, the intensity halved. The lit quarters keep their pewter floor
    on purpose: the coin-coloured light is the contrast the eclipse is read
    against. Also found on the way: the render AUDIT was lying about every
    planet's sky. With no shader in a test, the engine fell back to one
    generic blue-dusk gradient, so every room-audit PNG of every planet
    carried the same summer-evening backdrop. The fallback draws the
    planet's own palette now, shaped by the same mood the shader would use,
    so a picture of a room is a picture of it.
  · ✅ **A STATES RENDER HARNESS** (`planet_dungeon_dark_states_render_test`):
    the pall hung, a gnomon holding each quarter with the ghost wedge, the
    dial bare and half seated, a ring rusted / clean / through, the lamps lit
    and out, the abyss dark / lit / read / half-hauled / standing, the vane
    both ways — seventeen states asserted to be DIFFERENT PICTURES.
  · ✅ **THE REVIEW (2026-09-25)** — the Plant/Blood pass: every room
    rendered, every star checked for hidden rules and clocks. No clock was
    found anywhere: every verb is a turn, a seat or a press with no window,
    and Noctryos' lull is the fight's own rhythm. What was hidden or wrong:
      – *A hidden way looked like a way.* A shadow-way in a lit quarter was
        bricked back with the shared plug, which was 46 px deep against the
        vault's 36 px wall face and uncoursed — a flat blank patch standing
        proud of the wall exactly where a door would be. The plug now lays
        the planet's own face back (depth per planet, the shell's courses
        and cornice); shared, so Blood, Light, Mud and Spirit get it too.
      – *Walls swapped in one frame.* A turn now opens and closes passages
        over ~0.55 s — the stone splits on lit seams, or closes back over
        the fading glass — and the flourish plays only for the passages that
        actually just opened (every open door used to "open" again).
      – *A light-walk in shadow was drawn LOCKED* — smoked glass, iron bars
        and a gold keyhole, which says "find a key". It has no bars now; the
        causeway of pale flags at its sill (the old thin board glyphs) is
        there in light and has a black hole where its middle flags were in
        shadow. The shadow-way notch glyphs are gone: glass or wall says it.
      – *The wipe was a bar sliding over a room that had already flipped.*
        It is a real wipe now (0.8 s, eased): behind the edge the room is
        turned over, ahead of it it is still what it was, under a violet
        band of light; the gnomon's wedge shortens out of one side and grows
        into the other on the same clock, and the ghost is a filled wedge.
      – *The court's stones did not say who seats them* — Dark, Poison and
        Spirit are all purples in the element palette, and you learned the
        element by pressing. Each stone carries a pane of its element's
        PLANET glass (umbra violet, venom green, wraith pale). Whether it
        will seat is the floor under it — a pool of umbra while its quarter
        is in shadow, a coin-light patch while lit — changing on the wipe of
        the turn that changed it (it was a stroked violet hoop).
      – *A won star drew un-won after a death or a new run:* the dial came
        back bare and the rings rusted. Both are seeded from the banked
        stars on every reset and in onLoad (additive, so the proof holds);
        pinned in the vault test.
      – *The map could not see the eclipse.* Each room on the full map wears
        its quarter's state (an eclipsed disc, or a pale one), and a portal
        once read or walked stays drawn between its two rooms, bright while
        it would carry you — the Spirit reading used to be a 4 s line you
        had to remember across rooms. Legend entries added.
      – *Noctryos woke silently* (checklist item 11): it has a `riteWakeLine`.
        The rite's announcement said the lamps "go out" when the stars were
        won, which was false — it says they can be put out now — and the
        sealed-guardian line names the reredos as well as the lamps.
      – *Floor motifs that read as instruments:* the ring of hour marks
        round the court's dial, the three contour rings round the abyss (a
        target) and the spoked double ring under every gnomon are gone; the
        abyss has a coursed stone kerb, each gnomon a squared plinth, and
        the analemma itself is a groove with a bronze inlay and bronze studs.
      – *THE BLACK HOLE PASS* (author, same day: *"dark has unused clutter
        still and doesn't look like the black hole mystical level it
        should"*). Every prop you could not use is gone — the fallen
        columns, drums, pierced screens, loculi, lamp brackets, rubble,
        dropped flags, cracks and bars of fissure light in every room, the
        porch's piers, the gallery's dry well, the nave's arcades, the
        arena's ring of piers, the reliquary's racks, and the entrance
        sigil the porch shared with every planet. What stays is what a room
        is for: the stair, the abyss kerb, the reliquary plinth, the
        gnomons' and the vane's plinths. The sky holds a BLACK HOLE
        (`dark.src.frag`), IMPLIED rather than shown: the first version was
        the stock picture (even disc, clean lensed arch, a white hairline
        photon ring) and the author called it cheesy — a hairline hoop is a
        UI circle, and a centrepiece is the brightest thing on the darkest
        planet. Now it is a patch of sky with nothing in it, stars pushed
        out of it and smeared along its edge, and on ONE side a dim, broken
        streak of disc that fades before it can close a ring; hung high to
        one side so it is never over the party. A LIT quarter is obsidian
        lit from the hole's side, dying across the floor (a turning swirl of
        light arms was tried and read as a screensaver); a SHADOWED one
        thins until the void shows through, with sixteen motes of dust
        spiralling into the room's focus. The three obstacles are obsidian
        slabs. Sky alone: `planet_dungeon_dark_sky_preview_test`. The render audit loads the real sky shader now
        (`debugLoadSky`), for every planet.
      – *Left as is, knowingly:* the ECLIPSE readout's four unlabelled marks
        (the map now labels the same state), and the rings' spinning arc.
        Worth a look on device.
  · ⬜ **CARRIED, AND IT IS THE PROMOTION GATE: the device playtest.** Same
    sentence as Mud's, Ice's and Dust's. `Dark` stays out of
    `kPolishedDungeons` until it has been played.

### §9.14 DARK'S LOST MAXIM — the fourth finger

*The Abyss* was a WAIT: stand utterly still in the abyssal font, in the dark,
for a full minute. §7's table graded it exactly that, and §9.6 had already
said why a condition is an achievement and not a puzzle. It was also the one
maxim in the set a player could earn by putting the phone down.

**THE FOURTH FINGER.** Mud's lesson (§9.8) again: *the best place to hide a
secret is the state your own stars punish.* Every objective in Nythralor's
lower half wants the Deep in SHADOW — the gulf, the causeway, the slot, the
reliquary's very existence, Noctryos' lull. The Deep in LIGHT is the one
arrangement nothing down there wants, and you cannot even be down there in
it by accident: the stair gnomon that lights the Deep stands upstairs behind
the gulf it shuts. The only hand that lights the Deep from below is the
arena's floor-vane, behind the rood door — so the secret is post-rite, and
the first beat of it is turning the fight's own verb the wrong way.

  1. **LIGHT THE DEEP FROM INSIDE IT.** Turn the vane. The gulf and the slot
     are gone behind you; the reliquary is not there. Walk back to the font
     by the undercroft, which is a light-walk and exists now.
  2. **THE HOLE HAS A BOTTOM.** Light falls into the abyss for the first time
     and the well shows its courses stepping down, and on the floor of it a
     gnomon — the vault's fourth finger, fallen an age ago — on a chain to a
     rusted ring at the rim. Nothing is pressed for this; the room is the
     clue. (In the dark it is a hole with nothing drawn in it, and every hand
     is told *no bottom to it, nothing has ever lit the way down.*)
  3. **SPIRIT READS THE CHAIN** — the job it does at every anchor here:
     *three lengths of chain, and a finger at the end of them.* Until it
     has, a Dark hand on the chain finds it runs and runs.
  4. **A POISON PIP EATS THE RUST** off the rim's ring — the same verb, and
     the same gate declared on the layout, as every anchor ring on the
     planet (`anchor_ring`, so `dungeon_no_undeclared_family_test` is
     satisfied without a new gate).
  5. **DARK HAULS, a length a press** — the repeated beat. The finger rises a
     course a haul; three, and it stands on the rim on its own collar, and
     the rite of three plays over the well. The Poison+Spirit braid hauls
     too: a hand that has done its own beat falls through to stand as half
     of Dark.

**What it refuses, and how.** A wrong hand or a wrong beat is a puff and a
sentence, and nothing moves: *only Dark takes hold of what a shadow left
behind* · *the chain runs and runs, nobody knows how much there is* · *rust
holds the ring shut.* The hint button in the font gives the one oblique line
and nothing after it: *nothing has ever been dropped far enough to find the
bottom of this. Nothing but light.* It does not tier and it does not track
progress — the well's own picture is the only readout.

**Against the standard:** a chain (vane → light in the well → read → rust →
three hauls), all three of the trio doing what they do everywhere else here
(Dark turns and takes hold, Spirit reads, a Poison pip eats rust), the
planet's own braid standing in for a downed Dark hand, a repeated beat at the
end, wordless past the first nudge, nothing consumed. The star path never
passes it: every star wants the Deep dark down here, and the vane is behind
the finale door.

**And it cost the algebra nothing.** The raised finger is scenery, not a
fourth gnomon — three shadows over four quarters is the load-bearing claim of
the whole planet (never all four dark, which is Star 0), and a secret may not
quietly buy the player a way round it. The no-strand proof is re-run at the
end of the authored descent with the finger standing, and is still zero.

### ◐ DUST — the pass, minus the device session (2026-09-19)

Dust arrived at this pass with an art foundation, two exhaustive proofs
(conservation, no-strand) and a solved survey yard — and NO sound at all, a
maxim graded "one verb, N times", and the shared-renderer bug it had patched
around. Rendered room by room first (every room read as what it is; the
faults were in what the rooms did not SAY), then:

  · ✅ **THE MAXIM HAS HAD THE TREATMENT** — see §9.13. Four footprints
    swept with Air became THE TALLY: the granary's five pits hold the dead's
    count of the city, and the count is a state Star 1 forbids.
  · ✅ **SOUNDS**: none in the whole planet became eleven — the silt, every
    spadeful, every gust, the vane winding and the sirocco, the rings, the
    glass, the cut, the storm's re-burial, a pit answering, the cist.
  · ✅ **A CLOSING ANNOUNCES ITSELF (§5.7).** Every spadeful shuts two street
    crossings, and the line that said so was an ordinary hint — dropped
    unasked, like every world-response line. It is a CONSEQUENCE now
    (`speakConsequence`), as are the vane's warning (a warning nobody is
    shown is not a warning), the sirocco, and Ashdjinn's storm re-burying a
    dig from update. Ice's Frowyrm roar had the same fault and got the same
    fix in passing.
  · ✅ **WHERE YOU STAND TELLS YOU WHAT THE PRESS WILL DO** (Ice's orrery
    precedent, §9.11). Both yard verbs act on the cell in front and a spade
    throws behind, and nothing on the floor said which cells those were
    until the load had moved. The bite is ringed bright and the square the
    spoil will land on is ringed in ochre (for the wind: the cell underfoot
    and the cell in front), before anything is spent.
  · ✅ **EVERY MOUND CARRIES ITS MARK.** A chalked tag on a survey stake at
    each square's corner, in every state — the same five marks cut over the
    granary's pits. A rule you cannot see is a secret, not a puzzle; the mark
    is what makes the tally readable at all.
  · ✅ **THE SHARED MOAT BUG IS FIXED IN THE SHARED RENDERER** — §7.10's
    entry, above.
  · ✅ **A STATES RENDER HARNESS** (`planet_dungeon_dust_states_render_test`):
    the gate silted / open / vane armed, a mound at all three heights, the
    yard with its press preview, the observatory roofed and roofless, the
    granary unread / one pit / five pits, the hollow's cut open and buried —
    asserted to be DIFFERENT PICTURES.
  · ✅ **THE MUD CHECKLIST, RUN (2026-09-23).** What Mud taught on device,
    checked here before Dust's own session:
      – *Both stars wake the guardian:* yes — the whole descent test walks
        stars → false wall → glass → `guardianAwake` → the hollow door. But
        the SHARED altar woke Ashdjinn with the Air pilot's four yellow
        LIGHTNING wisps and a line nobody saw (update-time `_setHint` is
        dropped). The altar now wakes in the planet's own element (every
        planet that latches A+B there, not just Dust) and a layout may name
        a `riteWakeLine`, which is SPOKEN. Dust's is.
      – *A won star's world survives the valve and a new run:* it did not.
        The sirocco and every new run re-buried the three bronzes, and the
        armillary drew dead under a restored roof. A banked Seal Star now
        rests the yard on a solved ledger (`kSealYardWonArt`, pinned as a
        reachable goal by the seals test); the won armillary stays set.
      – *Clues without cross-room memory:* the chart now marks every street
        the ledger has shut — a pit for a trench, a heap for a dune — and
        each spadeful's spoken consequence names both squares it changed.
      – *Refusals that lie:* a drifted city square said "Only Air can move a
        dune"; Air moves heaps in the yard, never in the city. The Wing and
        Horn gates said "Air Wing"/"Earth Horn" but take any Wing/Horn. The
        Wing gate could never be heard by a grounded party (the island is out
        of reach), so it now answers from the moat's edge and stamps its chip.
      – *Props:* conduit A drew as the generic storm obelisk; it is now the
        riddle's false wall (bricked-up infill, broken into a doorway). The
        observatory moat's corners double-filled into four dark pits; the
        hollow's first fill course hung out of the cut. Both fixed.
      – ✅ **THE ARMILLARY STAR WAS TRIVIAL — now it takes a plan** (the
        user's pick of two proposals). Nine end ledgers satisfied "roof
        bared" and one spadeful thrown either way reached one (enumerated
        against the real doors). The armillary now needs the sky TWICE: the
        roof, and a bronze sighting tube in the observatory's east wall whose
        top opens on the kiln square (its tag carries the kiln's survey
        mark; `kArmillarySights`). Two spoils, two squares with room (agora,
        bump), and only kiln→bump + roof→agora leaves a road to the second
        dig: exactly ONE end ledger (12020), pinned by a player-moves search
        in the ruins test. It cuts both streets to the court, so the sirocco
        is part of the way on (Mud's lesson), and the vault cracks as a side
        effect. It shares the kiln→bump spadeful with the Lost Maxim's
        tally, which is then its mirror (roof bared vs roof heaped); the
        test still pins that the star's city is never the count.
      – ✅ **DUST WAS A CHECKBOX — now the city is its job.** Earth dug every
        square Dust did. The city's five squares are Dust's alone; Air+Earth
        stand in only while Dust is DOWN (the party clusters, so an always-on
        braid would hand the job straight back). Earth keeps the yard's
        spade and the Horn wall; Air the gusts, vanes, Wing and pits.
  · ⬜ **CARRIED, AND IT IS THE PROMOTION GATE: the device playtest.** Same
    sentence as Mud's and Ice's. `Dust` stays out of `kPolishedDungeons`
    until it has been played.

### §9.13 DUST'S LOST MAXIM — the count the dead left

*Nothing Perishes* was "sweep every ancient footprint with Air": four prints,
each showing only while its mound was bared, with conservation capping the
city at two bared mounds so a sirocco had to be paid in between. §7's table
graded it ⬜ *one verb, N times*, and it was also not a PLACE — the prints lay
on the street squares you already cross.

**THE TALLY.** Mud's lesson (§9.8) again: *the best place to hide a secret is
the state your own stars punish.* Star 1 spends its whole room on one
sentence — take the observatory's roof OFF, the sky comes down, the rings
read. The count the dead left has the roof DRIFTED: two loads on it, the
observatory buried twice over, and the star shut for as long as you hold it.
And the planet already had the room for it: the granary under the gate
square, five decorative grain pits in a cellar nothing needed.

  1. **READ THE COUNT.** Five pits in a row, one per mound, each holding grain
     to the dead's last count of that square — a black mouth, a level lying
     low, a heap over the lip — with the mound's survey mark cut on a plate
     over it. The same mark hangs on a chalked tag at the corner of the
     mound's own square, in every state. No verb: the room is the clue.
  2. **LAY THE STREETS TO IT.** Two spadefuls, the planet's whole grammar,
     each a decision made with the body: the kiln onto the bump (the vault
     cracks below as a side effect), then the agora onto the roof. Exactly
     one pair of digs reaches the count (enumerated in the test), and in
     exactly one ORDER: bare the agora first and the street east is shut,
     the ramp never rises, and the terrace — where the kiln's crown is —
     cannot be reached at all without a sirocco. The plan has to be made
     before the first spadeful.
  3. **COME DOWN.** Three of the four street crossings are shut by then. The
     granary is reached the way the buried city is always reached: the
     tower's stair, the windcatch, the undercity — the lower deck that never
     closes, which is what keeps the secret from ever being behind a route
     that can be lost.
  4. **THE REPEATED BEAT.** Air blown across each pit. A pit whose mound
     stands at the count LIGHTS — the grain goes warm, motes rise off it,
     the plate turns bronze: nothing perishes, and the grain says so. One
     whose mound does not answers with a puff and *the grain lies still; the
     street above does not agree with it.* The gate square opens AT the
     count, so its pit answers the very first breath — the room's wordless
     teach that the others want their streets changed.
  5. **FIVE LIT AT ONCE**, and the cist in the floor opens: the rite of three
     over it.

**The read is LIVE.** A lit pit goes dark the moment its street changes —
the storm undoing a dig, a spadeful, the sirocco — and answers again when the
count is restored. It is the ledger, read in grain; it never lies about the
city and it never has to be reset.

**What it refuses, and how.** A spade at a pit: *old grain, kept dry; only a
breath stirs it.* The hint button in the granary gives the one oblique line
and nothing after it: *the dead counted the city before they left; lay the
streets to their count, and the wind will find the grain still living.* It
does not tier and it does not track progress.

**Against the standard:** a chain (read → two digs in one order → come down →
five breaths), all three of the trio doing what they do everywhere else here
(Dust and Earth dig, Air breathes; the Air+Earth→Dust braid stands in for a
downed Dust hand exactly as it does at every mound), a repeated beat at the
end, wordless past the first nudge, nothing consumed. The star path never
matches it: the authored descent throws the roof WEST onto the agora, and no
state on that line agrees with the count.

### ✅ MUD — complete (pass 2026-09-13, promoted 2026-09-23)

**Mechanically the best-proved planet in the set, and visually unbuilt.** The
fen's rules had a solver, two independent no-strand searches pinned equal, a
provably-unique choir and thirty-odd green tests — and on screen the planet
whose entire premise is *what is the ground like under you* stood on the
generic rounded slab with a 92px smudge of colour at each wall standing in for
a crossing. The first render of the mire gate was an empty dark box. A drag to
sod and the drowning it caused changed a few hundred bytes of the frame and
nothing a person could see; the render harness's own checksum passed on
exactly that, which is why it now also asserts the states look different.

  · ✅ **THE FLOOR IS A FEN.** Pools in the low ground, sphagnum hummocks with
    moss caps, the black bog-oak the peat has been keeping, cotton-grass
    wherever the ground is briefly sure. Nothing on a grid (§5.5, and Steam's
    note that Mud must read nothing like a tile flood), laid out once per room
    and cached; only the sheen on the water moves.
  · ✅ **A CROSSING RUNS TO ITS DOORWAY.** Every ford head sat hard against
    its wall, so the crossing — the thing you author, the thing the planet IS
    — happened off-screen between rooms and showed only its last 60px, behind
    its own door plate. Heads stand 150px in now and the ribbon runs the whole
    way out. Pinned, so they cannot slide back.
  · ✅ **THE THREE STATES READ ACROSS THE ROOM.** Mire is a broken-edged wet
    ribbon that quakes; sod a raised causeway with a lit crown and a root
    fringe; drowned is wider than the crossing ever was, weed on it, the bank
    broken off at the near end. *The first cut of mire was a constant-width
    band with rungs across it and read as a BOARDWALK* — a poor look for the
    one crossing nobody built.
  · ✅ **THE POOLS ARE THE DRYNESS GAUGE.** A dry-footed knoll was announced
    by a 150px hairline circle round the room's centre: a HUD ring drawn on
    the floor. The knoll's own pools go to cracked mud instead. And a
    moor-altar's bowl visibly DRINKS ITS OFFERING AWAY while its knoll still
    swims, which is how the dry-footed rule gets taught with no caption.
  · ✅ **THE FIXTURES ARE THINGS.** The Sinking Altar was a flat brown disc in
    the room the planet is named for; it is a kerbed socket packed with the
    bog-resin cap (the cap retired 2026-09-22 — see below). The sough is a
    stone throat with the cutters' plug rammed
    in it, the wallow pulls, the sarsen lies where it fell until you walk it.
  · ✅ **THE DROWNED LEVEL STOPPED PRETENDING TO BE A KNOLL**, and then the
    hollow stopped pretending to be the fane. Three rooms under the fen were
    drawing moss caps and cotton-grass; the FANE is a building that went down
    (flagstones drowning in silt, column drums, roots through the peat
    ceiling), and the HOLLOW and the BOWL are not buildings at all — soft pans
    that quake and the ribs of what the fen has eaten. In the one room where
    standing on the wrong ground loses the fight, a temple floor was telling
    the player the opposite of the truth.
  · ✅ **THE MIRE ANCHOR was the same size and colour as the soft ground it
    is the exception to.** It is the only firm footing in Bogdrya's hollow and
    the whole reason the mystic can be struck.
  · ✅ **THE ENTRY RITE HAD NOTHING TO AIM AT.** The fen opens under a skin of
    floating weed that Water sluices off — and nothing drew the weed, so the
    first room was a bog with three doorways missing and no reason on screen
    to press anything. **Air's rite failed the same way, from the same cause.**
    Sixth instance. The raft lies on the water where the crossings are and
    thins westward across the knoll you stand on.
  · ✅ **THREE DOORWAYS ON ONE WALL ARE ONE DOORWAY** — Lightning's rule,
    failed in four rooms. The mire gate is the head of all three sloughs and
    carried its three crossings 45px apart; reed 40; hag and altar 80 and 90.
    Worst, the cairn and the lotus each carried TWO doors to the other 85px
    apart — one the ford, one the PLANK ROAD, which moors nothing and is the
    entire vault trick. Every wall clears 100px now (the gate grew from 480 to
    560 tall to carry its three rather than shrinking its doors), and the
    plank draws as sawn timber on black water: the only worked wood in the
    fen, boards grey with rot with every fourth one gone, trestle posts going
    down into water and not into ground.
  · ✅ **THE GAUGE MEASURED THE WRONG THING** (§7.9, "a gauge can be wrong
    with every number right"). "ROADS n of 9" counted what you had built,
    going up — which here says almost nothing: three sod crossings can leave
    the bog cut in two and four can be the whole southern road. It counts
    CROSSINGS LEFT now. Nine, and it only ever goes down.
  · ✅ **THE CARRIED WALLOW FAULT IS SETTLED.** Every knoll's wallow drops you
    inside the fane hatch you came through, exempted by the doorway invariant
    because a hatch is climbed out of. That exemption was only ever safe for a
    reason nothing had written down — a risen wallow is shut until the sough
    is freed, and climbing one HEAVES, which re-plugs the sough behind you. If
    either half had ever stopped being true, landing on the hatch would have
    handed the player an unasked-for heave half a second after arriving, and
    every road they had dragged with it. Both halves are invariants now, plus
    one test that stands a party on the hatch for four seconds.
  · ✅ **THE MAXIM IS THE FEN YOU ARE PUNISHED FOR MAKING** — §9.8.
  · ✅ **THE FLOOR WAS COMPETING WITH THE FURNITURE** (2026-09-20, straight out
    of the first device session — *"too much things on the map that occlude
    what I can see and interact with"*, which is the pass's own prediction
    coming true on schedule). The fen was scattered uniformly across the whole
    room with no knowledge of anything in it: the mire gate's 720x560 carried
    about **fifty-four pieces of ground** — 6 pools, 11 hummocks with a moss
    cap each, 23 cotton tufts, 3 bog-oaks — plus the weed raft, against
    **one 54px pad** you can actually press while the weed is down. It all
    draws UNDER the fixtures, so nothing was ever hidden; it was the same size
    and brightness as the things that matter, which is the same fault wearing
    a different hat. Three changes, no new art: the ground now takes a
    **keep-out list** (every doorway, the strip of floor a crossing runs down,
    the wallow, both altars, the sough, the lead, the sink, the peat cuts, the
    mire anchor, and every ford head) and re-rolls a spot that lands on one;
    counts are down about 40% (pools 6→4, hummocks 11→7, cotton 23→14, and
    cotton is the palest colour in the room, so on a floor this dark the
    brightest thing should be something you can press); and the fen is
    **clipped to the stage** it lies on. The floating weed is deliberately
    exempt from that clip — a mat cut off flat along the room's edge is the
    straight seam this render has refused from the start, so it still runs out
    into the dark and thins on its own. The drowned rooms take the same
    keep-out: Bogdrya's hollow is a fight room whose one firm footing is the
    mire anchor, and burying that in soft pans is the same fault with worse
    consequences.
  · ✅ **THE DECISION IS THE ROAD; THE REST WAS ERRANDS** (2026-09-22). A
    design review asked the planet's own question — *is this complex for a
    reason?* — and the answer was that the puzzle is clean (the choir tells
    you the road; never drag a middle) but the verbs around it were not:
    the sarsen was hauled one crossing per press, worked at each crossing's
    head on whatever knoll it stood on — four walk-and-press errands — and
    the socket carried a Plant+Mud resin cap that was a checkbox and
    Plant's ONLY job on the namesake star. Both are gone. Once an unbroken
    sod road joins the stone to the altar, **PLANT's roots carry it the
    whole way in one press** and seat it: Water opens the fen, Mud builds
    the road, Plant moves the stone. The readout reads ROAD whole/broken.
    And a moor basin on a knoll whose crossing has DROWNED now says "never"
    rather than "still swims", with the reading naming the sough — the one
    moment a player most needs to hear it (the old line sent people back to
    try again forever).
  · ✅ **WALKING RIGHT LOOPED** (2026-09-23, device). *"I walked right into a
    door and kept walking right and it would put me in a loop."* The cairn
    and the lotus each carried their crossing to the other on their EAST
    walls and arrived on the other's east side, so the next step right went
    straight back. The altar is the fen's far east shore now — every
    crossing onto it lands on its west wall (hag, reed, cairn) — and the
    cairn sits between lotus (west) and altar (east). Plant's pollen stair
    and niche had the same ping-pong on their west walls; the stair-wall
    thread goes NORTH now. `dungeon_door_compass_test` holds all seventeen:
    no door arrives on the side it left from, and following east or south
    doors never comes back round (Spirit, Light and Blood are rings by
    design and exempt from the east rule only).
  · ✅ **THE PLUG IS THE RESET** (2026-09-23, device): *"it should reset
    when we activate it in the drowned fane instead of leaving."* Pulling the
    sough now heaves the fen on the spot, with the line spoken there; the
    risen wallows open with it and climbing one only re-plugs the sough
    behind you (the carried-fault invariant is unchanged). The no-strand
    proof models the new valve: still 0 strandable, 1028 reachable states
    (was 1284 — a freed sough and a dragged fen can no longer coexist) and
    944 dead without the valve.
  · ✅ **TWO STARS OPENED NOTHING** (2026-09-23, device). Mud was the one
    planet with no rite: the hollow door waits for `guardianAwake` and
    nothing on the planet ever set it (the tests set it by hand). Bogdrya now
    wakes the moment the second star banks, as Lava's Magmara does, and a
    test walks two stars up to the open door.
  · ✅ **THE SARSEN STAR WAS FREE AFTER THE MOOR STAR** (2026-09-23,
    device): *"I don't think there's strategy there."* The choir's long road
    is also a whole road to the altar, so once the basins held, the stone was
    one press. The altar is the SINKING altar now: it holds the stone only on
    DRY ground (all three of its crossings firm), and no fen shape has both a
    road to it and a dry altar — enumerated in the test. So the star is a
    plan across two fens: carry the stone on any road, pull the plug (the
    heave takes the roads back but not a stone already at the altar), then
    firm the altar's three crossings and the last drag seats it. The reset
    is part of the answer, not just an undo.
  · ✅ **WHAT A STAR DID STAYS DONE** (2026-09-23, device): a banked Moor
    Star keeps its three basins full through every heave and every later
    drag; a banked Sarsen Star keeps the stone seated; and a new run opens
    with both, not with a fallen stone and dry basins.
  · ✅ **The device playtest — begun 2026-09-20 (the floor fault above was
    its first finding) and done; promoted to `kPolishedDungeons` 2026-09-23**
    on the author's account.

### ◐ SPIRIT — THE REVIEW (2026-09-25), minus the device session

The Dark/Light pass, applied to Requia: every room rendered in BOTH worlds
(`planet_dungeon_spirit_states_render_test`, new — the audit only ever drew
the living one), every star checked for hidden rules and clocks. No clock on
a star: the passing is free and unlimited, the telling has no window, the
sigil is a deduction. Wraithord's crossing every 4.5 s is the fight's own
rhythm, answered at the arena's stone.

  – *The one irreversible act had no preview.* A telling finishes a death
    for good and decides one crossing forever, and nothing said WHICH. In
    the cold each restless dead one now has a ribbon of cold light running
    to the doorway it holds up; standing at it with a Spirit hand, the
    ribbon brightens and the lintel that will fall there for the dead is
    ghosted into that doorway, breathing.
  – *Every shut way wore the shared bars and keyhole,* and a road the other
    world holds was a doubled hairline box. The doorway now says why: the
    stone lying across it for the living (a restless dead one's crossing),
    its fallen lintel for the dead (a finished one's), a line of salt for
    the dead (consecrated ground) — and a faint pane of the other world's
    light where the other body could pass.
  – *Wraithord's crossing was silent* — its line ran from update through
    `_setHint`, which drops unasked lines, on the one fact the fight turns
    on. It is a consequence now, and says to follow it at the stone.
  – *The fixtures were primitives:* the lych-stone an outlined box (a stone
    bier now, with a wraith-glass figure laid in its top), the dead two
    stroked hoops (hooded figures, filled, thinning to a wisp; a warm eye
    gets a cold patch), the undug grave four corner brackets (a cut of
    lifted turf), the lamp a disc (a lantern on a post), the drowned cut a
    rectangle (black water with the cold moving on it, or plates of ice).
    The cold barrow was a doubled hairline oval and the dead's half of the
    sigil a hairline arc with ticks: both are filled light now.
  – *Clutter:* a field of graves over every floor, grass tufts, a row of
    kerb stones and the undug grave's spur lines. At most four graves stay
    per room, against the walls, so the two worlds still show one place
    before and after and the undug grave's blank stone still has named ones
    round it. The entrance sigil ring is gone from Spirit, Light and Dark.
  – *The bier was the shared grey bar,* and stayed after the Cold Road said
    it had gone. It is a shrouded body on trestles, and the trestles stand
    empty once the road is won (objective: "the bier stands empty").
  – *A won sigil drew unset after a fall* — seeded on reset and in onLoad,
    pinned. *Wraithord woke silently* — it has a `riteWakeLine`, and the
    sealed line names the name stone as well as the lamp.
  – ⬜ Device playtest owed. `Spirit` stays out of `kPolishedDungeons`.

### §9.9 SPIRIT'S LOST MAXIM — the seventh funeral is yours

*Stuff of Dreams* was one press: stand three bodies anywhere inside the vault
room in the cold world. No chain, no braid, no repeated beat — and its
"place" was the vault's own room, so the secret and the treasure diluted each
other. §7's table graded it ⬜ *"one press"*, which was right.

**THE UNDUG GRAVE.** The mourners' walk runs 260px further west than the rite
needs, into a dead spur no door uses (§9.6, and Steam's precedent). At the end
of it is a grave somebody scored out and never dug. Warm, it is four scoring
marks in the turf. Cold, it is open, standing full of black water, with an
**uncut headstone** — blank, where every other marker in the field carries a
name. That blank IS the secret, stated in one object: the telling that
finishes all six of Requia's dead has nothing here to work on.

  1. **BE DEAD.** Warm there is nothing to work. Nothing is pressed for this.
  2. **WATER** draws the black water off — the job it already does at the gate
     arch to open the planet.
  3. **CRYSTAL** sets a grave-lamp at its head, exactly as the rite's own lamp
     is set, and the light shows the slot is uncut.
  4. **SPIRIT, THREE TIMES** — the repeated beat, and the same telling verb
     that finishes the six. You cannot tell a name that was never cut, so the
     Spirit hand gives the three names it DOES have: yours. One apiece, with
     all three standing in the grave.
  5. The third name lands and the field takes all three.

One oblique line on the HINT button: *six were buried here and told; this one
was never cut a name, so nobody can tell it but the one it was dug for.*

**AND THE FIRST CUT OF IT WAS WRONG IN A WAY WORTH RECORDING.** The repeated
beat was originally three tellings by three different SPIRIT bodies — which
is a better sentence and a worse design, because the ideal trio is Spirit ·
Water · Crystal and carries exactly one Spirit. §4 guarantees that trio the
planet. A maxim may ask for more thought than a star does; it may never ask
for a party the dungeon told you not to bring. The full-run test caught it,
which is the one place a demand like that shows up as an error rather than as
a shrug.

### §9.8 MUD'S LOST MAXIM — the fen you are punished for making

NO MUD, NO LOTUS was three presses at one coordinate in the fane: Plant, then
Water, then Mud, each answered with a line of narration. Three keys in one
lock. Against §7's standard it kept nothing — no chain (no step changed
anything a later step needed), no braid, no repeated beat — and its "place"
was a dot on a floor you already cross. §7's table graded it *"▶ closest of
the rest"*, which was generous.

**THE BLACK LEAD.** The peat-cutters' old drain leaves the fane's water and
runs away south-west into a dead corner with no door at the end of it (§9.6 —
a maxim has to be a PLACE). It is choked and dry, and it runs only when the
fen above is carrying all the water it can.

  1. **FULL DROWN.** Every slough is a chain of three. Hardening its MIDDLE
     drowns both the others; hardening an end drowns one; hardening both ends
     drowns the one between. So the most water this fen can carry is six of
     nine crossings, reached by the three middles together and by nothing
     else — **one shape out of a hundred and twenty-five**, enumerated in the
     test rather than argued. It is also exactly the shape both stars forbid:
     the three middles are the short roads, and the choir demands the four
     that make the long southern one. The secret costs you the run's stars for
     as long as you hold it, and the sough's heave is the only way back.
     Nothing is pressed for this beat — you come down a wallow and the cut is
     running.
  2. **WATER** reads the three PEAT CUTS out of the black water: the job it
     already does at the cairn's basin.
  3. **PLANT** sets a seed in the sink, where it lies in clean water doing
     nothing, because a seed in clean water is not a lotus.
  4. **MUD** drags each cut's lip in turn — the repeated beat, and the
     planet's one verb, with the braid **Plant+Water→Mud** carrying it here as
     it does everywhere else. Each pour runs down the lead and the sink
     thickens: water, slurry, peat. The seed goes under.
  5. The third pour buries it utterly, and it blooms.

One oblique line on the HINT button and nothing after it: *the cut was dug to
take the fen's worst, and nothing has ever bloomed out of clean water.* It
does not tier and it does not track progress — the sink's own colour is the
only readout the secret has. Nothing is consumed; a wrong hand gets a burst
and a sentence about what it sees, and a heave washes the lead out so it can
always be walked again.

**THE GENERAL LESSON, for the nine secrets still in the queue.** Steam's was
that a maxim has to be a PLACE. Mud's is the next one along: **the best place
to hide a secret is the state your own stars punish.** Every dungeon here
teaches a rule and then rewards obeying it; the shape a planet spends the
whole run steering you away from is somewhere the player has never been and
has a reason to remember, and building the secret there costs nothing but the
valve you already shipped for softlocks.

### ✅ LAVA — complete (2026-09-03)

**The line was built well and drawn as a diagram.** Fifteen channels, fourteen
nodes, five levers, a solver that walks the real map — and on screen a vertical
gradient with a 96px SQUARE GRID ruled over it, flat orange bars for the
runners, and grey rectangles for the crucible, the drop hammer, the
accumulator and the purge cowl. Twenty-two tests, all green, none of which can
see any of that.

  · ✅ **THE FLOOR IS A CRUST WITH SOMETHING UNDER IT** — and it took three
    goes to get there, wrong the same way twice. First a 96px ruled GRID.
    Then cast-iron plates in running bond: better material, still a lattice,
    reported from play as *"too tiley"* with the note that matters beside it
    — **it needs to look dangerous.** That is the general lesson and it is
    worth more than the floor: **regular anything reads as safe**, because
    regularity is what people build. A room you are meant to be careful in
    cannot be tiled. It is black basalt now, split by wandering fissures
    that branch, mostly cold scars with a few carrying real heat and
    breathing on their own phases, ash and cinder over the top, and embers
    drifting up off it. The runs bloom the ground around them, so heat still
    marks where the line goes.
    (Bloom is faked with a wide low-alpha stroke, never `MaskFilter.blur` —
    that is this repo's main per-frame jank source and the floor draws every
    frame.)
  · ✅ **AND THE RUNNERS RUN.** Refractory lip in courses, a glazed inner
    edge, a narrow burning core with cooling shoulders, and broken crust that
    does not reach both banks — even slabs of one length read as conveyor
    treads. The bands travel **the way the metal actually goes**: the segment
    model has always known (`reverse`) and that knowledge had never once
    reached the screen. It is the single most useful thing this planet can
    draw, because the puzzle is re-routing a line and now the route can be
    read off the floor instead of guessed at a lever.
  · ✅ **THE FIXTURES GOT MATERIAL.** The silhouettes were right and are
    untouched; what they had no trace of was what they are made of. A
    crucible hung in a trunnion frame with a pouring lip, a drop hammer on
    guide columns with collars and a crown, a riveted accumulator with hoop
    bands, a hooded purge stack with louvres (it was a flat green triangle
    and read as a Christmas tree), a slag pit with a ragged crusted rim, and
    flasks with a parting line and corner clamps instead of dark boxes.
  · ✅ **EVERY LEVER SHOWS ITS WAYS.** A notched quadrant with one notch per
    setting and the handle in the notch it is actually in — so a three-way
    sluice announces that it is three-way before you throw it to find out.
  · ✅ **THE STAR IS AN INGOT.** Still hot, stamped, on a pallet. It was a
    flat trapezoid: the shape of an ingot with none of the substance. On a
    planet whose entire fiction is casting, the reward has to look like the
    product.
  · ✅ **THE HEART CIRCULATES.** The guardian's ring was the last thing still
    drawn in the old flat style — one orange stroke with grey ticks — in the
    one room the player fights in. It is a circular runner now, with the
    metal travelling round it and launders on the rim that go dark while
    they cool.
  · ✅ **A MOLD SHOWS WHAT IT WANTS.** Both forms drew the same dark
    rectangle, so the one that takes PLAIN metal and the one that takes
    WARDED metal were visually identical — standing between them you could
    not tell which was which, and a puzzle whose entire question is *what do
    you cast, and in what order* felt like guessing. Each cavity is cut to
    its form now (a smooth slab; a key with its wards and bow) and tinted
    the colour that metal runs down the channel as, so the bead you are
    watching and the mold it is heading for are the same colour.
  · ✅ **A DEAD RUNNER LOOKS DEAD** — the worst thing this planet did to a
    player. A plugged arm silently EATS a pour (`_leaveBy`: *"it congeals
    against cold metal and is simply gone"*), one of only five, and the floor
    drew that arm hot, flowing and glowing right up until the metal vanished
    into it. Three states are drawn apart now: **live** runs; **shut** (a
    branch its junction is not feeding) stands still and dark with no
    travelling bands; **plugged** is cold blue-grey set metal end to end with
    the shrinkage crack cooling always leaves down the middle.
  · ✅ **AND A JUNCTION SHOWS ITS GATE.** A junction was nothing on the floor
    — a place two troughs met, with the answer only on a lever plate some
    paces off. It is a real switch now: a pivot, the paddle swung back along
    the arm it feeds, and swung ACROSS the mouth of every arm it does not. At
    the mill you can see the metal going up the purge and not on down the
    line, without reading a word. (The paddle first drew from the node to the
    arm's start point, which is a zero vector whenever an arm begins exactly
    on its junction — most of them — so it was skipped on precisely the arms
    that needed it. It takes the direction along the segment now.)
  · ✅ **AND THE ROOMS SAY WHAT YOU ARE FOR.** Every objective line on this
    planet was an OBSERVATION — *"the line forks under the foreman's board"*,
    *"the north channel cuts the house in two"*. All true, all scenery.
    Reported from play, after the art pass had made everything legible:
    *"the user still doesn't really know what the overall goal is."* A room
    can be perfectly readable and still leave you with no idea why you are
    standing in it. They name the thing you WANT now, and they change as you
    get it — the gantry line goes from bolted to open, the mould floor goes
    from "the Ember Star stands across the runner" to "the span is laid".
    Still no method: what you want, never how.
  · ✅ **THE PRIMER LEADS WITH THE GOAL.** It is shown **once, ever**, joined
    into one eight-second line on the first descent — so a planet's whole
    statement of purpose gets one showing and then is gone for good, which
    is worth knowing before writing another one. Lava's spent half its length
    on what a pour becomes and what cold metal does; both of those are on the
    floor now and both are in the hint button. What was nowhere at all was
    why you are here. It is two lines: *"Every road out of this works is
    something you have to cast first. Five pours, never refilled."*
  · ✅ **THE METAL AND THE PARTY NOW LEAVE BY THE SAME SIDE.** Reported from
    play, and it is the worst kind of fault this planet can have: *"in switch
    yard I made lava go south. I go right, where it looks like lava is
    flowing. In the next room no lava is flowing."* Exactly so — the arm the
    lever called SOUTH ran EAST out of the room, and the east door led to the
    chill house, which is the OTHER arm and was therefore dark. An audit found
    three crossings like it: `ch_mill_in` left east against a south door,
    `ch_north` left north against an east door, and `ch_tail` left the mould
    floor north against a west door. On a planet whose puzzle is following
    metal, that is not a blemish — it is the puzzle lying. All four sides of
    every crossing agree now, in and out, and **an invariant walks every
    channel hand-off against the door for that room pair**, so it cannot
    drift back. The lever labels went with it: `NORTH`/`SOUTH` named a compass
    the channels did not obey, and they name the destination now — `CHILL` and
    `MILL` — which is both truthful and more use than a bearing.
  · ✅ **AND A POUR TOOK FORTY-THREE SECONDS.** Nobody had added the line up.
    At `kLavaPourSecondsPer100 = 0.62` the key pour ran 25s, the span 20s and
    the reliquary — mill, tail, sump — **43s**: five pours, each committed in
    advance, then most of a minute of watching a bead crawl with nothing left
    to decide. In a puzzle whose whole pleasure is planning, that is dead air,
    not tension. At 0.20 they are 8s, 6s and 14s. **Measure the thing the
    player waits on**; a duration nobody has summed is a duration nobody has
    designed. (The geometry fix above added five seconds to the mill arm and
    pushed the run test past its 40s cap, which is how the pre-existing 38s
    came to light at all.)
  · ✅ **THE PLANET COULD NOT BE FINISHED.** Chasing the pipe alignment one
    room further turned up the real thing: **the damper lever stood in a
    sealed pocket.** Walled by the vent riser (x 606-634), the vent-out run
    above it, the bottom channel below and the room's own east wall — and
    nothing could stand within its 70px reach, the nearest floor outside
    being 74 away across running metal. The damper starts on PURGE. Both keys
    need warded metal down the mill arm, and warded metal that reaches the
    vent is gassed. So Lava was unwinnable, by anyone, from the day it was
    authored. **Twenty-two tests passed the whole time, because a test sets a
    lever by hand and never walks to one** — the same shape as Steam's
    Boilrog, who could not be reached because every test teleported into his
    room.
  · ✅ **AND A NEW INVARIANT SAYS SO OUT LOUD**: from every arrival you did
    not have to earn, you can reach every lever and every door in the room
    you land in. It caught the damper, and it caught two regressions of my
    own within minutes of being written — a full-height drop that halved the
    switch yard, and an arrival that landed in the pocket between the two
    arms and the east wall, which had no door in it at all. What it
    deliberately does NOT flag: access-gated levers (the tail switch wants
    the catwalk), warded doors (the gantry hangs beyond the north channel),
    the star-gated finale, and arrivals that come back THROUGH one of those —
    those are gates, and a gate is not a severed room.
  · ✅ **AND THE DOOR UNDER A PIPE IS THAT PIPE'S DOOR.** Wall-level agreement
    was not enough: the mill arm crossed the yard's east wall and the door
    immediately beneath it was the CHILL house's. Whichever door sits nearest
    a pipe is the one the eye pairs with it, so the two were swapped. The
    yard's own shape is what forces the compromise — `ch_tap` runs across the
    top and walls off everything above it, so both doors have to live low on
    the east wall while the chill arm crosses at the very top.
  · ✅ **WALKWAYS — and they are why the layout works at all.** The switch
    yard's fork was re-plumbed three times chasing one complaint (*which door
    did the metal just go down?*) and every arrangement traded one confusion
    for another. I then tried to talk my way out of it with SIGNS bolted over
    each door, and that was worse: more furniture saying what the room should
    have been showing.

    The actual constraint was self-imposed. **A channel was an absolute wall**,
    so every arm that reached a wall fenced off part of it, and the layout had
    to be contorted around that. A foundry has walkways over its runners.
    `FoundryBridge` is a plate with handrails laid across a channel, and with
    it the yard is laid out the way it always should have been: the feed comes
    in the west wall, the junction sits **in the middle of the room**, the
    chill arm runs east to the east wall with the chill door beside it, the
    mill arm runs south to the south wall with the mill door beside it, and a
    walkway crosses the mill arm so the west half still reaches the east wall.
    You can see the fork, and each arm ends at its own door. Same in the mill:
    the arm drops in through the roof beside the door and a walkway crosses it.

    **The lesson is the one I got wrong twice.** When a room will not read,
    the answer is not to relabel it and it is not to shuffle the same pieces —
    it is to ask which rule is making the layout impossible. Here it was
    "metal is a wall", and it was never a requirement, just an assumption
    nobody had written down.
  · ✅ **AND A CROSSING MEETS ITS DOORWAY.** Same wall was not enough. From
    play, with screenshots: *"in tap head there are two flowing pipes, then I
    come out of the door and they're both gone and there's one right above
    me."* The feed ran along the tap head's CEILING and entered the yard just
    above the doorway, so it appeared to jump as you walked through. Measured
    across the works, the gaps were 62 · 22 · **466** · 16 · **206** · 100 ·
    **272** px. Every one is now ≤ 100 and most are under 20, by the fix the
    report itself suggested — bring the run DOWN to the door before it
    leaves, then along the wall to wherever it is going. An invariant measures
    every hand-off against its door.
  · ✅ **THE MAXIM IS THE POUR YOU THROW AWAY** — §9.7.
  · ✅ **PLAYED, room by room, and that is where all of it came from.** Not
    one item above was found by reading the code or by the suite: the tiley
    floor, the metal leaving by the wrong wall, the pipe that jumped through
    a doorway, the unwinnable damper, the free first star, the spoil that
    said nothing, the plug the game lied about, the door you could see and
    not reach. The tests were green throughout. §7's table grades **Black Glass** ⬜ *"one verb,
    three times"* — quench three times with Ice. That is an achievement, not
    a puzzle, and Steam has just shown what the fix looks like (§9.6): a
    maxim has to be a PLACE.
  · ⬜ CARRIED: device playtest. Nothing here has been played.

### ✅ FIRE — complete (2026-08-31)

The reference. What "complete" meant, so the next planet has a target:

  · **Rooms drawn as places.** The nave got an aisle runner, blind arcading,
    piers with capitals and bases, and candle stands that CATCH as the party
    walks the bay. The choir's braziers became iron cups on plinths whose rims
    stand clear of the tallow, its ember-walk a worn labyrinth rather than
    four hairline circles, its stalls actual stalls. The bell gallery hangs
    from roof beams with a hanger to every censer and bell.
  · **Puzzle legibility.** The garth is a 60px board that fits a 390pt screen
    (it was 137x148 squares, three columns of six visible); burnt ground grew
    a crust so it cannot be mistaken for soil; coverage reads off a toothed
    ring on the vane, one tooth per square owed.
  · **Rules that hold.** A dead fire turns the board over. A trap cannot lay
    another trap. The projectile pool has survival's ceiling.
  · **Feel.** Flame crawls at 15px/s and holds 4.0s; the gust glides rather
    than teleports; the boss fight runs inside the frame budget again.

### ✅ AIR — complete (2026-09-01)

  · ✅ **The long gold diagonals** across crosswind_hall were not a wind
    effect at all: `_drawBrokenBridgeLines` walked `platforms` in AUTHORING
    order and joined each to the next, stringing lines between ledges that
    are not neighbours — through the islands and off the room edges.
    Neighbours are decided by position now, gaps outside 24–300px are skipped,
    and the bridge is drawn genuinely broken (sagging ropes that stop short,
    planks hanging from the stumps).
  · ✅ **Route marks.** Chalk dashes and chevrons on the wind ledges, rungs on
    the vertical climbs, instead of pasted-on amber glyphs floating mid-air.
  · ✅ **The Spiral** resets the moment a wrong vent is opened, and a completed
    ring reads as a galaxy rather than a diagram.
  · ✅ **The hints** no longer name the method (see §5.6).
  · ✅ **THE FOUR WINDS** — the hub secret rebuilt to Fire's template, and the
    hub made actionable at all (it declared no furniture, so it had no action
    pad). See §7 lost maxims, entry 2.
  · ✅ **Device playtest passed (2026-09-01).** The gale columns — flagged
    from a whole-room render as "translucent rectangles that read as UI
    panels" — read fine in motion on the device, which is the reason that
    call belongs to a playtest and not to a static render.
  · The floating islands themselves are good and were left alone.
  · ⬜ Not chased: `storm_rune_hall` and `storm_altar` came up verb-less in
    the action-pad sweep. They are probably a reading room and a landing, but
    nobody has confirmed it.

### TEACHING A VERB WITHOUT SPENDING IT

The problem: a verb nobody guesses is a verb nobody uses, and a verb spelled
out in a line of text has been spent — you cannot un-tell it, and the moment
of working it out is the moment the puzzle was for.

**The answer that keeps working is to make the OBJECT react to the hand.**
Not a prompt, not a highlight, not a tutorial: the thing itself behaves
differently when the one creature who can change it comes near, and the
player is left to press the button and find out what they have.

Three of these on Lava now, and they are all the same move:

  · A frozen plug **warms** when a Lava heart is within melting reach. (Which
    exists because the alternative — a line saying the arm was shut for good
    — was both a lie and a run-ender. See below.)
  · Running metal **frosts** as an Ice heart walks toward it, harder the
    closer they get, well outside the reach so the APPROACH is what reads.
    This is the sump crossing, the one verb the whole of Star 2 turns on, and
    nothing in the works had ever hinted it existed.
  · A warded door's keyhole **lights and pulses** when you are carrying its
    key.

Two rules fall out of doing it three times. **Start the reaction outside the
reach**, so walking closer is the sentence — a tell that only appears once
you are already in range teaches nothing, because by then pressing was going
to be tried anyway. And **show it to the element, not the family**: Lava's
cold tell fires for any Ice heart, not only an Ice mane, so the family gate
still gets to be the thing that says *which* cold sets metal. The verb is the
discovery; the gate is the lesson.

### A RULE THE ENGINE DOES NOT ENFORCE, STATED AS THOUGH IT DOES

Worse than saying nothing, and the hardest class of copy bug to notice: the
line is well written, it is in the right channel, it fires at the right
moment, and it is **false**. The player believes it, stops trying, and
abandons a run that was never lost.

Found from play on Lava. Freezing an arm printed *"a road, and a plug behind
it. Nothing runs up this arm again."* A Lava heart melts any casting back out,
plugs included — RULE 5 on that planet is literally *the world is never what
ends a run* — and every part of the mechanic worked. The only account of it
anyone ever got said the opposite.

**A sweep of the six polished planets found one more, and it is starker.**
Lightning's welded breaker says *"This one is fused — it will not open
again"*, eight lines above a branch whose own comment reads *"A FUSED BREAKER
IS NOT STUCK. The storm blows the weld off it, which is the undo the whole
rite needs in order to be allowed a wrong turn."* And the dynamo court's
ambient line said *"The great rotor never slows"* — about the very rotor an
Air heart winds past its limit, which IS the Thunderbolt rite. Atmosphere is
allowed to be evocative; it is not allowed to make a mechanical promise, and
certainly not a false one.

The rest checked out, and it is worth recording that they did: Fire's wet
vine never catches (wet is authored and nothing dries it), Air's woken gales
never sleep (`wokenGales` is cleared only on a run reset), Earth's sealed
pillars are sealed for good (same), and Steam's ring genuinely cannot be
bought whole (4 × 15 against a head of 40).

**The check, whenever a line claims something is permanent:** find the code
that would undo it. If it exists, the line is a bug. If it does not, say so
plainly — a real irreversibility is worth stating, and is the reason this
kind of copy exists at all.

### THERE IS NO REVEAL VERB — IT IS THE HINT BUTTON

Say it here once, because it has now been got wrong from inside the project.
The Mask "insight / REVEAL" ability is **removed**. Every `_<planet>Reveal`
function still exists and is still the right place for a room's reading, but
it is the **content of the HINT button** (`askForRoomHint`), tiered by the
party's Intelligence — not something the player presses on the action pad, and
not something a Mask creature unlocks. Any party can ask.

`abilityLabel()` kept returning `'REVEAL'` for `DungeonAbility.insight` long
after the button went, with no callers anywhere. That dead string was enough
on its own to make a reader describe Lava's room readings as *"gated behind
the Mask insight verb"* — exactly backwards. It is deleted.

The design question this changes: when a room's information is only available
through its reading, that is not a gate, it is a HINT. So the right follow-up
is always *does the room show it too?* — which is what found Lava's two
identical mold cavities.

### THE ACTION PAD READS ONLY ROOM DATA — and several planets don't use it

`roomOffersAction` gates the whole pad, and it consulted `DungeonRoom` fields
only. Four planets keep their interactables somewhere else: **Lava's**
production line is one global object indexed by room id, **Dust's** mounds are
a const table indexed by room id, **Water's** moon glint is computed from the
tide, and **Earth's** open palm is a bare `const Offset` inside a method.
Those rooms reported "nothing here", the pad never appeared, and they could
not be worked at all — including **four of Lava's seven rooms** and the
reflection court, which is the only place Water's lost maxim can be taken.

It never showed in a test because `activateAbility()` does not consult the
getter: the gate is the HUD's, so only a human holding a phone ever hits it.
`_planetOffersAction` is the hook a planet uses to declare verbs it keeps
outside the room, and `dungeon_room_offers_action_test.dart` asserts the
getter directly for exactly that reason.

STILL UNEXPLAINED, found by the same sweep and not yet chased: Air's
`storm_rune_hall` and `storm_altar`, Fire's `nave`, `vestry` and `high_altar`
(the mercy shrine — suspicious), Earth's `sternum_court` (Star 1 banks there)
and `skull_antechamber`, Lightning's `dynamo_court`, and Dust's `undercity`,
`granary` and `kiln_cellar`. Some are certainly corridors and reading rooms.
Some are not.

### WATER'S MOON — you do not see it until the oculus

You are underground for the whole temple. The moon reaches you as GLOW, as a
SHAFT, and as a REFLECTION lying in the water; the one place you ever look up
and see the disc itself is the oculus over the moon well, which is Star 3.
Both earlier rooms drew a moon and spent that reveal, so both now draw only
the light:

  · **drowned_court (hub)** — the moon's glow hangs over the middle of the
    court and its REFLECTION lies in the central basin: absent at the low
    stand, half-drowned at the middle, and at HIGH water the largest thing in
    the temple, with a broken moon-path column running up to the glow. Same
    construction as the well and the mirror room — an inverted moon across
    sliding horizontal slices — because three rooms should share one way of
    drawing water. (The court's moon also used to hang at centre+190, x≈670 in
    a 960-wide room, with the mirror gate's doorway at 610–720: it was sitting
    directly in front of the locked finale door. Dead centre clears both top
    doors and puts it above the basin, where its reflection belongs.)
  · **reflection_court** — glow and shaft only. The shard puzzle does not need
    a moon overhead to compare against: a piece turned right takes a bright
    white ring of its own.

**AND THE SECRET MOVED TO THE HIGH STAND.** It wanted the middle water, which
made the mirror room brightest in the middle and dark at both ends — a shape
with no meaning. The moon is nearest when it has pulled the most water, so the
tell now rises continuously with the tide (`tideMoonReach`), and the hub's
basin shows its largest reflection at exactly the moment the mirror room is
worth standing in.

### §9.2 LIGHTNING'S TWO HALLS — one braid, taught then tested

Voltara used to hold two unrelated beam puzzles. The first hall was a pure
routing exercise (thread one bolt through three terminals with four
conductors); the third was the STATIONING puzzle — park Air on a vent, park
Fire in the wind it makes, and the wind becomes lightning at the flame.

The stationing puzzle is the better of the two, because it is the only one
that is actually **alchemy**: three elements, each doing something only it can
do, and a real transmutation you can see happen at a point in space. So it
moved to **Star 1**, where the planet teaches, and Star 3 became the same idea
at spire scale.

**PYLON HALL (S1) — the braid, small.** Three vents, three converters, four
conductors, ONE mast. Provably unique: of the nine vent/converter pairings ×
16 conductor sets, exactly one combination crowns the mast.
  · Vent VB and converter FC sit in a line together at the west end, so the
    tempting pair really does catch — the flame lights, a real bolt is born,
    and it dies in the east wall two seconds later. That is the hall's whole
    lesson: **making lightning is not the puzzle; landing it is.**

**STORM SPIRE (S3) — the braid, at scale.** Four vents, four converters, seven
conductors, three pillars, and **three masts that must all be crowned at
once**. 128 conductor sets per pairing; exactly one pairing in exactly one set
works.
  · Because there is one beam and the converter is a point ON it, the choice
    of converter decides HOW MUCH of the run is charged. Crowning three masts
    with the charged half forces the conversion high on the east fall, so
    nearly the whole route is lightning. That is the complexity: not more
    corners, but an ordering constraint that the corners have to satisfy.
  · **Fulminate is half-blind.** Wind may lie across a vat all day; the
    charged half cooks it off in 1.6s and trips the dynamo dark. The Spire
    hangs one vat in plain sight on the very first leg so the player runs wind
    over fulminate before they know it should scare them. Four of the 128 sets
    detonate — including one a single conductor away from the answer.
  · The dead-aligned decoy survives: vent VD runs the east aisle 20px clear of
    every conductor, so it can never be bent, and converter FD sits right in
    that aisle. Eliminating it is geometry, not grinding — asserted at zero
    across all 128.

Both halls are brute-forced against the REAL beam engine by
`solveBeamHall(roomId:ventIndex:converterIndex:)` in the layout test, so the
game and its proof cannot drift. Note the vats are HAZARDS, not the uniqueness
constraint — the geometry alone is already unique, and that is the stronger
guarantee.

### §9.3 THE MIRROR GALLERY — the room that only works in the dark

Star 2 has two halves: the gallery FINDS the three storm-cell echoes, the
cloud works SPENDS them. The works half was always fine. The finding half was
not a puzzle at all — an echo bared if you walked within 40px of it, or if you
stood anywhere near the middle and used Lightning, which bared everything
inside 220px. Nothing to reason about, nothing you could get wrong: you swept
the floor and the room paid out.

It asks two questions now, and both are rules you can state out loud.

**WHICH WING.** The gallery shares the CLOUD trunk with the works, so feeding
that trunk lights the room — and its own light drowns what the glass carries.
Feed any *other* wing and the gallery goes dark, and that wing's light reaches
it through one pane of storm-glass, showing the one echo that belongs to it.
  · Spark ← the pylon trunk. Veil ← the vault trunk. Anvil ← the core trunk.
  · So every echo costs you the wing you were standing in. That is this
    planet's zero-sum stated as a puzzle instead of as a fact, and it is the
    one thing Voltara owns that no other planet does.
  · It also sets the order of the whole star: go dark three times to gather,
    then feed cloud to seat and bank. And dark segments prowl with
    spark-wisps, so gathering is never free.
  · The Anvil echo — the one the works wants heated by Fire — is handed to you
    by the SPIRE's light. The wing you need for Star 3 gives you the cell that
    needs a flame.

**WHICH SIDE.** The glass is a mirror, so it lies about the side. What stands
in the pane is the echo's REFLECTION; the echo waits the same distance the
other way, and Lightning bares it at the true spot only. Grasping at the image
is the mistake the room is built to spring exactly once, so it answers —
*your hand closes on glass* — rather than doing nothing.
  · The panes are solid, and walking around one is how you cross to the side
    the echo is really on.
  · The render states the RELATION without giving the answer: motes run the
    glass out to the image, and a dotted perpendicular hangs the image off its
    mirror. It says *this is a picture, and that is what it is a picture in* —
    it never points at the far side.

Two rendering traps worth remembering. The panes are walls, so the generic
`_renderWalls` rock body painted straight over the top and turned three panes
of storm-glass into three grey slabs — it skips storm panes now. And the
"borrowed light" first went in as a flat translucent rect between pane and
image, which reads as a grey box lying on the floor; light has to travel.

### §9.4 THE STORM SPIRE — one chain, and the last mast stands on the gate

Star 3 was provably unique, which made it unambiguous and not hard — you
flipped conductors and hill-climbed to the one answer — and it was laid out at
coordinates chosen to make a snake path work, so it looked like scatter.

**IT IS A LATTICE.** Four columns (250·480·710·940) by three rows
(170·370·540). Every conductor, mast and vent on a lattice point, every
converter on a lattice edge, three cast blocks standing in the gaps. The lanes
read off the floor before you touch anything, and the layout test asserts the
lattice so it cannot drift back into scatter.

**ONE CHAIN, ALL THREE MASTS, AT ONCE**, and the answer is an inward spiral:

```
VA(90,170) →──────────────────────────────→ A(940,170) '\' ↓
              converts at FA(595,170)
   ↓ MAST(940,370) ↓ B(940,540) '/' ←──────────────────────
   ← MAST(710,540) ← C(480,540) '\' ↑
   ↑ D(480,370) '\' ← E(250,370) '/' ↓ MAST(250,540) ↓ THE GATE
```

**AND THE ROOM IS FULL OF CHAINS THAT ARE NOT IT.** The first cut of this
layout was solvable in about five minutes, and the reason was not that it was
small — it was that nothing in it resisted you. Live preview makes turning a
conductor free and instant, so you steer into the answer rather than search for
it; three of the four vents visibly died in a wall, so that choice was made by
looking; and the one insight collapsed into a heuristic you could execute
without understanding it — *push the flame as far back as it goes*.

So the fix was not more spiral. Three of the eight conductors — F(825,370),
G(825,270), H(710,270) — stand nowhere near the true route. What they do is
give the OTHER vents somewhere to go: a wrong start no longer dies in a wall
after one bounce, it winds through four, five, eight corners and comes out
looking like an answer. Six vents and five converters make thirty pairings and
**fourteen of them light a mast**; four reach two of the three.

**VD is the honest trap.** Its column holds a real mast at (710,540) and a
converter *above* it, so the flame catches, the chain runs eight corners and
lights the east mast. What you see is your own bolt passing straight through a
mast that stays dark — because the wind reached it and the lightning was born
above it. The room's own rule, demonstrated on you.

Thirty pairings × 256 conductor sets, and exactly **one route** lights all
three. Eight bitmasks satisfy, all tracing that same route: the decoy
conductors are never touched by it, so their orientation is genuinely free.
Uniqueness here is asserted of the ROUTE — the thing the player actually finds
— not of the bitmask, and `solveBeamHall` reports both.

**THE LAST MAST STANDS ON THE CORE GATE.** It sits at (250,540), centred over
the barrier at (200,600), so the bolt drives down into the mast and through
the doorway below it — the thing you are powering and the thing it opens are
one object. A layout invariant asserts that exactly one mast stands over the
gate and close enough above it to read as standing on it.

**THE REAL QUESTION IS HOW EARLY YOU CONVERT.** Three of the four converters
sit *on* the true route at different depths — FA(595,170) on the opening run,
FC(940,455) most of the way down the east column, FB(365,370) near the end.
Standing Fire on any of them makes a real bolt. Only the earliest leaves enough
of the route charged to reach all three, **because everything before the flame
is merely wind**. That is the insight the room is built around, and it is not
something you stumble into by flipping conductors.

**PLANNING IS FREE.** With Air on a vent and nobody on a converter there is no
charged half, so the wind draws the whole spiral and lights nothing. Lay a
route out, look it over, then decide where the flame goes.

**LATTICE HALF-STEPS.** Iron is allowed on the lattice points AND on the
half-steps between them (365·595·825 across, 270·455 down). The decoy net lives
on the half-steps, which still reads as a switchyard and never as scatter; the
layout test asserts it.
  · **Lane discipline.** A cast block standing in a lane eats a decoy's wind
    before it leaves the vent and quietly turns a tempting lie into a dead
    prop. That happened TWICE while building this room, and both times the
    only thing that caught it was rendering the room and looking. The three
    blocks live at x 540–650 and 960–1070, clear of every column and of the
    decoy chain's own run along row 270.

**FULMINATE LIVES IN PYLON HALL.** Every vat position on this lattice that
bites kills every solution — the routes are too tight — and an inert vat is
worse than none. So the half-blind lesson went to the teaching hall, where the
geometry has slack: vat A sits on the WIND leg of the correct answer (solving
it properly means running wind over fulminate and watching nothing happen),
sixteen wrong charged routes cook each of the two, and the hall's teaching lie
now bites — vent VB with converter FC in front of it makes a real bolt that
crosses vat B on its way to dying in the east wall.

> **TWO MECHANICS WERE BUILT HERE AND REMOVED, recorded because the trade-offs
> are real.** First, *welding*: crowning a mast fused every conductor that bolt
> had turned on, so with no run reaching all three the ORDER became a budget —
> seven distinct openings, three of which stranded you, the same two masts
> costing three irons or five. It made the room a decision rather than a
> search, and it made a wrong guess expensive. Second, *banked crowns across
> multiple firings*. Both went for the same reason: this room is for trying
> things freely. The proof seams they used were `solveSpireOpenings` and
> `solveSpireRoutes`, in this file's history.

### §9.5 STEAM'S FINALE — four corners, and the room opens only as you shut it

**Two rewrites, and the second one was the wrong KIND of fix.**

The rite began as a QUENCHING: still every "source vein", then touch the
pedestal — where source meant lava the pedestal's own floor could not reach. A
flood-fill rule with no expression on screen. The refusal counted veins and
never said which; the three that counted were drawn exactly like the two that
did not. Reported from play as *"how do I even beat star 3?"*

I replaced it with a HOLD — bring a furnace to heat and keep the needle in a
band for eight seconds — and that was worse, because it was the wrong kind of
difficulty. Knowing the answer was not enough; you also had to perform it
against a clock. The reply was the design note that now governs every planet
left: *"I don't like games where I have to be mechanically good, I like
strategy."*

**THE POUR** followed, and it was *right in kind* — everything answerable
standing still — but it was still a board on a floor: two cisterns, a band of
gates, a mould at the bottom of a fall, and a run of melt that fell on its own
once you committed. It played as a puzzle you solved with walls rather than as
a room three creatures were in. The design note that replaced it came straight
from play: *"what if we did more of the geysers jumping over things with
pressure … leaving rocks and lava one side and having to plan sides out before
jumping back and forth"*, and then, exactly: *"you plan geysers on both sides
to create strategy on who and when you send certain alchemons across."*

(The pour's own lessons are kept below the rule — they were paid for and they
generalise. Its machinery survives in code for star grids; no room authored
today has one.)

**THE FOUR CORNERS.** The crucible is a void with four terraces in it and a
heart that is not there yet. Each corner carries two field mouths, one riser
to be thrown from, and one SOCKET naming the element that shuts it: Steam at
the north-west where you arrive, Earth south-west, Fire north-east, and Earth
AND Fire together at the far south-east. Sealing a corner caps its two mouths
for good.

**A TERRACE HAS TO BE MOSTLY EMPTY.** They were built 260x220 and every one of
them was ALL furniture — two mouths, a riser, and a socket whose 74px reach is
a dead zone for Earth's stone, which between them left nowhere on the terrace
a stone could actually come out of. Reported from the first play as *"I can't
even build a rock with earth guy."* They are 400x340 now, with the mouths
pushed onto the outer edge and the socket set high, so the middle-bottom of
every corner is open floor. The room grew with them (1280x1000), and the risers
did NOT move relative to each other — the ladder below is exactly what it was,
which is the point of having it written down as arithmetic rather than as
positions.

**The head is the whole puzzle, and it is a ladder.** A mouth that is HELD —
by a body standing on it, or by a corner that has been sealed — feeds the main
40 instead of bleeding it, and a throw clears `340 + 1.8` per unit over 99. So:

| held | head | reach | what it buys |
|---|---|---|---|
| 2 | 100 | 342 | the 300px hop to the corner below |
| 4 | 180 | 486 | the 460px crossing east |
| 6 | 260 | 630 | the 549px diagonal to the far corner |

You arrive with one corner's worth of hands and the short hop is the only
thing on. The room opens **only as you shut it** — every rung is bought by
sealing the corner you are standing on, which is what makes the order of
travel the decision rather than the aim of a throw.

**TOO MUCH HEAD WAS AS FATAL AS TOO LITTLE.** A throw landed at EXACTLY its
reach — not "up to" it — and with all four corners sealed every mouth is
capped, so the head is 340 and the arc carries 774. The heart is 272 away.
The last hop of the room could not be made at all, by anyone, ever: you sailed
five hundred pixels past it into the far corner. Reported from play as *"how do
I get to the middle square?"*, which was a fair question with no answer.

A throw finds the **first ground along the aim** now, or ends in the dark if it
crosses none. Every rung of the ladder survives — not enough head still means
the arc ends over the void, because there is no ground on the way — and what
goes away is a failure mode that could not be seen, reasoned about, or beaten
by playing better. It is also what a launch looks like to anyone who has been
on one.

Two things made this invisible for as long as it was. The full run *placed* a
body on the plinth rather than throwing one, so the last hop was the one move
in the room no test ever made; it throws now, and reverting the fix puts the
landing at (215, 232) — the opposite corner — so the test bites. And the
landing test asked `_onSolidGround`, which only knows the platform LIST: the
heart is a platform in the layout and is not there until four corners are
sealed. Only the block rule knows that. **Ground you cannot stand on is not
ground to land on** — a landing asks `_blocksPlacement`.

**A BODY ON AN ALREADY-SEALED MOUTH ADDS NOTHING**, and that is the trap the
first tuning fell into: I costed the crossing as "two corners sealed plus two
holders" and the holders were standing on mouths the seals had already capped.
Head stalled at 180 with nothing left on the west side to hold, and the room
was unwinnable from the inside. The ladder above is now the layout test —
`reach(2) > vertical`, `reach(2) < horizontal`, `reach(4) > horizontal`,
`reach(4) < diagonal`, `reach(6) > diagonal` — so the geometry and the
arithmetic cannot drift apart again. The last rung also asserts that the heart
is reachable from **any** corner on the thinnest head, because by then there is
nothing left to seal to buy more, and a room whose final hop can strand you is
a room that lied.

**THE HEART.** With all four shut, a plinth exists in the middle; standing in
it is the rite. Before that it is drawn as a thing being ASSEMBLED — one
quarter of its rim lit per corner held, under a scrim that lifts as you go —
rather than as floor you can see and are mysteriously blocked from. The block
is honest, so the art is too.

**AND THE CORNERS HAVE TO NAME THEMSELVES FROM ACROSS THE VOID.** You are
planning who to send where before anyone moves, so a socket has to be readable
at distance: element-coloured arcs, split down the middle when a corner wants
two, lifted toward white because Earth's brown and Steam's grey-blue both sit
too close to the terrace stone to read unlit. Sealed corners become bolted
caps — **cross-braced, not saltire**: at 45° the four sealed corners read as
four big red X's, and this planet has already been told once, in play, *"why
did some x out?"* A cross-braced cap is a plug; an X is a refusal.

**Nothing can go wrong except a wasted throw.** A short throw drops the
creature back where it launched from rather than into the void, and the room
has no timer, no creep and no failure state — the plan is the entire game.
Hidden Harmony is keyed to taking the room with no short throw at all.

**WHAT ATE THE SEAL PRESS, TWICE.** `_tryEarthRock` swallowed the seal button
for a non-Earth hand and then again inside Earth's own branch. That is the
FOURTH time on this planet that one verb's refusal has eaten another verb's
legal press. The rule stands and is worth restating: *a refusal must never
outrank a thing that would actually work.*

**AND BOILROG COULD NEVER BE REACHED.** `_guardianDoorSealed` holds a
guardian's door shut until the guardian is awake, but Boilrog only woke from
INSIDE his own room — so the finale door was sealed by a condition that could
only be met on the far side of it. The rite wakes him from the antechamber
now, which is what the rite's own hint had always claimed happened ("Boilrog
heaves up BEYOND it"). No test caught it because every test that reached the
heart got there by teleport; the full run now opens that door by asking.

**LAVA HAS TO LOOK LIKE IT IS RUNNING.** The forge's casting moat was a
rounded rectangle that grew — which is a progress bar. Molten rock crawling
down a stone gutter wets one wall more than the other and leads with a TONGUE,
so both edges wobble on a travelling phase and the front bulges past the fill
line (clamped at the channel's end, because a full moat is a full moat and not
an overflow). The same treatment merged the chamber grids into one mass with
rounded outer corners instead of a field of separate tiles.

---

**KEPT FROM THE POUR**, because they generalise:

  · **The sources had to look like sources.** Three doors in a wall and only
    two giving melt is a decision made blind unless the pairing is drawn: a
    wet gate lit from behind, with a molten throat joining it to the cistern
    leaning on it. Reported from play as breaking one and getting *"just one
    square of fire"* — correct behaviour, unreadable.
  · **The mould sat in a pocket.** With row 8 open across, any run that
    reached the floor crawled into the mould and the room won itself.
  · **A wrong answer cost a re-plan, never a run** — the property the four
    corners inherited whole.

### §9.7 LAVA'S LOST MAXIM — the pour you throw away

**A secret you can only buy by forfeiting the dungeon is a price list.** Black
Glass was *quench three pours at the font with Ice*: one verb three times,
which §7's table grades ⬜ — and worse than weak, because three quenches cost
three of five pours against a works that needs four. The maxim and the planet
could never be had in the same run. There was even a test asserting the
sacrifice, which is how you know it was deliberate and still wrong: nobody
gives up a planet to see a reaction.

**It is the SLAG PIT now.** One charge down the waste line — the single thing
the works marks as pure loss, the branch the tail switch labels SLAG, the
place a pour is *simply gone* — and obsidian cools in it. Go and take it.

**The budget is what makes it a decision.** The intended solve costs four of
five, so the spare pour is exactly what this costs: the planet's whole economy
turns out to have had one pour in it for the person who wondered what the
waste line was for. It is discoverable from the lever plate, it is one
deliberate act against every instinct the works has trained, and it does not
cost you the run. Melt cooled fast in slag is obsidian, and the pit gives it
back — *"cooled too fast to be iron; it gives back your own face."*

It also sits on a road you already walk: the pit is on the catwalk, which you
need anyway to throw the tail switch for the Reliquary Star. The secret is not
a detour, it is a **choice at a junction you were already standing at.**

### §9.6 STEAM'S LOST MAXIM — a maxim has to be a PLACE

**A run-long condition is an achievement, not a puzzle.** Hidden Harmony began
as *finish without one scald*, then — when the labyrinth stopped being three
tile-grid chambers and the old rule had quietly become free — as *finish with
no short throw*. Both are things you avoid rather than things you work out,
which is the grade §7's table gives most of the seventeen.

The short-throw version was worse than merely weak. **The Cinder Forge teaches
by letting you watch a throw fall in** — that is the room telling you the
arithmetic, and it is the correct thing to do the first time you stand on a
riser. Doing it once silently spoiled the maxim twenty minutes before you could
have claimed it, with nothing on screen saying so. A secret that punishes the
lesson the dungeon just taught is not a secret; it is a trap.

**IT IS A ROOM NOW.** The north manifold runs 600px further west than the ring
needs, past the last junction, into a dead spur no door uses. At the end of it
the main is split, and **a hole only carries a body when the main is
screaming**: at anything under 99 the pipe refuses and names its key. Down the
split is the scald cellar, an undercroft the foundry forgot, with the maxim
lying on a plinth. Take it and step back into the pipe — the way out costs
nothing, because a maxim you cannot carry home is not a reward.

**AND THE ROOM SENDS YOU HOME.** Chromeless art has a cost, and it landed
within a minute of the cellar first existing: *"how do I get back?"* The way
out is a hole in a wall with no door frame on it, so it cannot announce
itself. Two answers, both needed. The mouth is DRAWN now — a riveted collar
round a dark throat that breathes, the only moving thing in a dead room, which
is what makes the eye find it from the far end. And the cellar returns you
itself three seconds after the rite settles: three seconds of HAVING the thing,
not three seconds of watching the reaction. A player who has just been paid
should not then have to hunt for the exit.

(That needed one extraction: the whole door transit — per-planet transit
bookkeeping, the anchor the regroup button recalls to, the hint reset — used to
live inline inside the walk-into-a-rect check. It is `passThroughDoor` now, so
a room that sends you somewhere does everything walking there would have done.)

**Why this is the RIGHT question for this planet.** Steam's whole economy is
one shared budget: the main holds forty and every junction costs fifteen.
Everything you have ever spent it on has been a *door*. The maxim asks you to
carry the entire budget somewhere that is not one — and stoking to 99 draws two
wisps a time, so it is a real price and not a walk.

**A DOOR PAINTED OVER THE THING YOU ARE MEANT TO READ.** The engine's door
chrome — frame, locked slab, rune — is drawn on top of the room's own art, so
the split came out as a door with a pipe behind it and every readable thing
about it was hidden underneath. `DungeonDoor.chromeless` says *the planet's
renderer owns the whole appearance of this way through*, and the minimap
honours it too: a secret way draws no mark on the chart and no thread between
its rooms. (The cellar itself is left on the chart on purpose — a player who
opens it and finds a room with nothing joining it has been invited to explore,
which is the point.)

**AND THE STEAM HAS TO BE COUNTABLE.** The first jet was a translucent lozenge
with hard circles rising through it, which read as cartoon smoke beside the
sprite-puff plume every other vent on the planet uses. It is that same plume
now — and it is quantised to the gauge: **one mark of steam per mark of
pressure**, a wisp at twenty and a column at ninety-nine, so you can read the
main off the pipe without looking at the gauge, and a little pressure visibly
does a little something. At the tear itself there is a tight hot slot, because
steam is only fog once it has spent itself; at the hole it is a hard fast
thing, and that is the part that says PRESSURE rather than weather.

**AND THE SPUR HAS TO SAY SOMETHING.** Six hundred pixels of nothing is a bug;
six hundred pixels of a spur that was CLOSED is a story. A capped dead end, a
seized stop-valve and a dead gauge with its needle slack at the pin are the
only things telling you why no junction runs down here. The tear's jet scales
with the gauge — a whisper at forty, a plume at eighty, a column at full blast
— so the answer is legible the FIRST time you wander down with a half-empty
main, long before you have the pressure to use it.

**The refusal names the key and not the prize:** *"The split spits and sucks at
you — but the main reads 62. Nothing goes down a pipe that is not screaming."*
You are told exactly what the pipe wants and left to wonder why you would ever
give it that. (Writing it also retired a stale line: every shut Steam rite-door
used to say *"the heart does not open to an empty mould"*, on a planet that no
longer has a mould and now has three different reasons a way on can be closed.)

**The star path never passes it**, and the full run asserts that — a clean
three-star run reaches Boilrog without the egg. That is what "lost" has to
mean.

### A GAUGE CAN BE WRONG WITH EVERY NUMBER RIGHT

Steam's pressure gauge ran off the right-hand edge of a phone. Every value in
it was correct and no test could have caught it, because nothing rendered it.
Two faults, both invisible to arithmetic:

  · The header was painted from a FIXED LEFT ORIGIN, so a longer reading —
    `HEAD 20 · 1 VENTING` rather than `MAIN 40` — simply walked off the
    screen. It is right-ALIGNED to the bar now, and the venting count has its
    own line so the header can never grow.
  · The bleed was drawn as a red segment ON TOP of the amber and cyan ones,
    which read as one broken bar rather than a boiler, its plugs and its leak.

`planet_dungeon_steam_hud_test.dart` renders the HUD at three viewports × three
field states and asserts nothing is painted in the right-hand margin — the
pixels, not the numbers. Confirmed to bite by putting the fixed origin back.

**The general rule: any HUD element whose text length depends on game state
needs to be laid out from the edge it is anchored to, and needs a rendered
test.** A readout that grows is the one that escapes.

### A ROLLED PUZZLE MAKES A TEST THAT PASSES ALONE AND FLAKES IN THE SUITE

Water's moon well flaked about one full-suite run in three and passed every
time its file was run on its own — which reads like test pollution and is
nothing of the kind. Its basins' wanted moons are ROLLED PER RUN, and the
moon does not stand still: settling the well takes time and the sky keeps
turning through it. The test named a basin up front and assumed the moon would
still be wrong for it by the time Ice pressed, which held on most rolls and
failed on any roll where that basin wanted the very next notch.

The fix is the shape of every fix for a rolled puzzle: **read the state at the
moment you act on it, never before.** The test now reads the sky at the press
and picks a basin the sky is genuinely wrong for.

### DOORS — where you come out matters as much as where you go in

A door's `targetSpawn` is where you land in the next room. Three ways that
goes wrong, all of them felt by the player as *"the doors don't lead
anywhere sensible"*, and all three now layout-test invariants across all 17:

  · **THE DOORS ON THE WRONG WALLS.** Lightning's `mirror_gallery` named this.
    The hub lies NORTH of it — you leave the court by its south door to get
    there — so the way home is UP. The gallery's door to the hub sat at the
    BOTTOM, and the door at its top went to `cloud_works` instead. Walk south
    out of the court and every exit led further away, which is exactly what a
    loop feels like. The two were exactly swapped; they are the right way
    round now, with both arrivals beside their own way back.
  · **LANDING IN ANOTHER DOORWAY.** Poison's three wards are laid out alike,
    each with a hatch down to the lazar crypt at (255, 290, 50, 40) — and the
    ambulatory's arrival was (280, 330), exactly on that hatch's bottom edge.
    Walking into any ward from the ambulatory dropped you straight through
    into the crypt.
  · **LANDING IN THE FAR HALF.** If the way back is on a wall, you have to
    arrive in the half of the room nearest that wall, or you appear at the
    opposite end from the opening you just used. Mud's sunken lotus had both
    of its arrivals in the wrong half. (Interior doors are exempt: a door in
    the middle of an arena floor has no near half to land in.)

  · **A WALL LAID ACROSS THE DOORWAY.** The fourth way, and the one that
    reads least like a bug: give a room border iron and lay it straight over
    the door. The walk clamps to 16px inside the bounds and stands 16px off
    any wall, so a door lying inside the sill has NO reachable point anywhere
    in it — you walk into the opening and stop. Lightning's Pylon Hall shipped
    this the day it grew walls, which sealed the player inside the room the
    star is in. Cut the sill at the doorway. A rect-vs-rect check does not
    catch the general case (a pillar parked in front of a door seals it just
    as dead), so the invariant flood-fills each walled room from every point
    you can arrive in it and requires each door to be walkable.

### HUD OCCLUSION — the panels own the screen's corners

Three panels are bolted to the screen and cannot be moved: the **minimap**
(top-left, 126x190), the **joystick** (bottom-left, 150x200) and the **action
pad + swap rail** (bottom-right, 210x230 — the tallest thing on the screen).

A pannable room can put any point under any panel at some camera position;
what the player cannot escape is a panel over a point the camera is CLAMPED
against — and the camera is clamped whenever the object is within half a
viewport of a wall, which is exactly when you are standing on it. So the rule
is about ROOM CORNERS, and two rooms broke it:

  · **Water / ghost_gallery.** The SPRING (the basin that always answers a
    hand, and the reason a lost lantern can never end a run) sat under the
    minimap; the SEA DRAIN — the goal of the whole canal — sat under the
    action pad. Everything is inset by (96, 64) for the minimap, and the room
    is 1096x1000 now. The depth is the load-bearing part: at 784 the room was
    SHORTER than the 915 viewport, so it never panned vertically and the
    drain's screen position was FIXED under the button. Past the viewport it
    pans, and the extra depth is the lower gallery below the drain.
  · **Poison / lazar_crypt.** The vault cache was at (700, 600) — behind the
    button you press to take it, permanently, because a 700-deep room never
    pans against a 915 screen. Lifted to (700, 430).

**A room shorter than the viewport cannot pan its content clear**, so its
corners have to be authored clear. That is the trap worth remembering.

**THE SLUICE-BANK MOVED TO THE COURT (2026-08-31).** The gallery used to keep
its own three wheels on the west wall, so that steering the water was a walk
taken inside the room against the lantern's drift. They are on the drowned
court's east wall now, beside the gallery door. Know what this changed: the
lantern only drifts while the player is IN the gallery (`_updateLantern`'s
guard — the temple holds its breath behind you), so the trip out FREEZES it.
The canal is a pure planning puzzle now — set the stand, come back, watch a
leg, go again. Nothing in it can be lost to a clock, and nothing in it costs
one either. The layout test pins REACH instead of co-location: every stand
settable, one door from the water, both ways.

**AND THE WHEELS WERE INVISIBLE.** `_drawTideWheels` was called from
`_drawTideWorks` alone, while its own doc comment claimed it was "shared by
the tide-works and the gallery's own bank". It was not — the gallery's three
wheels were authored, interactive and never painted, and the bank moved to the
court inherited the same silence. It is drawn from `_renderTemple` now, for
any room carrying a bank, so the rule is structural rather than a call a room
painter has to remember. `dungeon_water_wheels_drawn_test.dart` pins the
single call site and its position ahead of the per-room switch, because the
failure mode is invisible by definition.

`dungeon_hud_occlusion_test.dart` walks every room on every planet — valves,
canal nodes, shrines, vents, anchors, conduits, rune pillars, torches,
braziers, vault caches — against each panel's real box at the camera clamp for
that panel's corner, with a press-radius allowance, because a target is a disc
and not a point.

### ✅ WATER — complete (2026-09-01)

  · ✅ **Star 3 rebuilt as THE MOON WELL.** The moon drives the tide and waxes
    on its own, so the drift is the clock; Spirit wanes it, the Water pip
    plugs the broken main by STANDING in it, Ice locks a basin when the moon
    sits where it asks. All four basins listen, and the ice raises the well —
    two of them drown once two stand, so the ORDER is the question. Breaking
    ice undoes it, which is why the rise is allowed to exist.
  · ✅ **The secret rebuilt as THE STILLED MIRROR**, to the maxim standard:
    Water stands motionless to flatten the pool, the moon breaks into three
    shards showing the wrong phase, Spirit turns each true, Ice takes it.
  · ✅ **The moon is a reveal, not decoration.** You are underground the whole
    temple — the moon reaches you as glow, as a shaft, and as a reflection in
    the water, and the one place you look up and SEE it is the oculus over the
    well. The hub's basin carries the big reflection instead, largest at the
    high stand.
  · ✅ **The sluice-bank moved to the court**, the canal gallery was padded off
    the HUD's corners, and the tide wheels are drawn wherever they stand —
    they had never been painted outside the tide-works at all.
  · ⬜ CARRIED: the moon well's tuning (4.5s per notch of wax) has only been
    reasoned about, never measured against a real walk.

### ✅ EARTH — complete (2026-09-01)

The planet's conceit is the best on the roster — *the dungeon IS a buried
body, rooms are anatomy, the bones are the machinery* — and exactly one room
in nine was drawing it. `sternum_court` is a ribcage vault with a spine and it
reads; `rib_hall` was three lozenges and a black box, `pillar_crypt` was four
stacks of discs in a void, `eye_chamber` is an eye, a plank and four coins.
The rest were diagrams of their own mechanics.

  · ✅ **The ground is strata, not graph paper.** It was a 110px square grid of
    seams — every chamber of a buried body sat on a sheet of graph paper. It
    is seven bands now with wavering boundaries (a straight line is a drawing,
    a wavering one is a deposit), each band its own tone, seeded off the room
    bounds so it never crawls; plus bone chips and root threads in the dirt.
  · ✅ **One bone material.** `_drawBuriedBone` — thick at the root, tapering
    to nothing, lit along the upper edge and shadowed under. Every arch in the
    barrow goes through it, so the anatomy is one substance instead of nine
    curves that happen to be beige.
  · ✅ **`rib_hall` is inside the ribcage.** Ribs down from the vault and up
    from the floor, stopping short of the marrow channel — and the chasm is a
    SPLIT in the bone with wavering lips, not a rounded rectangle. The
    movable ribs are waisted and grained so they stop reading as pills.
  · ✅ **`pillar_crypt` is the spine.** The four sockets are vertebrae, so
    there is now a backbone for them to be vertebrae OF, with transverse
    processes reaching to the walls.
  · ✅ **`palm_hollow` is a hand.** It was an arc and five 5px spokes — a
    sunrise, not a hand — and the maxim's permanent mark was a 20px crystal
    glyph appearing in it, against Fire burning Epicurus into the floor and
    Air's compass ring knitting shut forever. It is a giant's hand now, palm
    up and half-sunk in the strata with the forearm running off the bottom of
    the room: fingers of three phalanges that curl at each joint, small
    knuckles, and a THUMB across the palm, which is the whole difference
    between a hand and a fan. And the crystal has been growing for an age —
    it comes up THROUGH the palm, stains the bone where it met it, runs the
    creases out into the fingers, and stands in five faceted blades with a
    gleam travelling each one.
  · ⬜ `eye_chamber`, `skull_antechamber`, `marrow_vault`, `heart_chamber`,
    `barrow_gate` still owe their anatomy.
  · ⬜ Device playtest.

### EARTH STAR 3 — a fifth stone, and the room that names the system

Three small changes, and the third is the one that matters.

  · **A FIFTH WEIGHT, `w_spine`** — the giant's own centre. Five also breaks
    the even split: four stones can sit 2/2 and read as symmetrical, and a
    balance that looks balanced by default is a worse question than one that
    plainly is not.
  · **ITS MARK IS IN THE HUB.** The other four marks are all in side rooms,
    so it was possible to walk the whole barrow and never suspect the marks
    were a system. The fifth is carved on the sternum court's own spine — the
    one room crossed on every trip.
  · **AND THE HUB SAYS SO, ONCE.** *"The bones are carved all over. Mind the
    symbols: they are what tips the scale."* It names the SYSTEM and never a
    single lean, so the treasure hunt stays a treasure hunt. Without it a
    player could read all five marks as decoration and brute-force the scale,
    which is exactly what this star was built to avoid.

The layout test now pins that every stone has a mark and every mark a real
room, and that no two share one — a stone with no clue carved anywhere is a
coin-flip nobody can reason about.

### EARTH STARS 1 AND 2 — REWORKED 2026-09-01

Both were one verb repeated. Star 3 (the rolled scale, its answer carved as
bone-marks in four other chambers) is genuinely good and was not touched.

**STAR 1 — THE CAGE IS ONE BONE.** Three ribs on three separate tracks that
never touched each other: six identical shoves. They are ARTICULATED now — the
cage hangs, so driving a rib along its groove levers **the rib below it** the
other way, and the lowest rib has nothing under it to lever. Nothing wraps and
nothing clamps: if a coupled rib would be driven off its track the whole shove
is refused, which makes every move exactly reversible (stand on the other side
and shove back) and is therefore the no-strand argument as well. The opening
arrangement is ROLLED, drawn only from boards the solver proves are ≥4 shoves
from true.

> **COUPLING BOTH NEIGHBOURS IS UNBUILDABLE, and it is not obvious.** With
> every rib pulling both its neighbours, the laid-true board is an ISOLATED
> state — from all-in-the-groove, every legal shove drives some neighbour off
> the end of its track, so the goal has no approaches and the star cannot be
> banked from anywhere. Exactly 1 of 27 boards can reach it: itself. The
> one-sided rule reaches all 27, at up to 12 shoves. `ribCageDistance` is
> public and the test sweeps all 27, because this is a mistake that looks
> completely fine until someone tries to finish the room.
>
> The all-zero board is also DEAD, which is what the game shipped with — every
> shove from it drives a neighbour negative. It is seeded in the constructor
> now, beside the other planets' rolls.

**STAR 2 — CRYSTAL GROWS OUT OF CRYSTAL.** Four sockets arced one at a time
was one verb four times, with a defend wave as the only content. Giving them a
leak made it a route; it did not make it a question. Three beats now, one per
element:

  · **EARTH WALKS THE SPINE.** The crypt's column is a stair of five
    vertebrae. Standing on one WARMS it under an Earth creature's feet;
    pressing there SEATS it, and a seated vertebra stays lit while warmth
    alone fades the moment the foot leaves. Seat all five and the giant's
    back takes the weight: the four buried pillars come up out of the floor
    and their sockets open together. This replaced "press Earth on each of
    four sockets", which was the same four-presses problem one beat earlier —
    and it turns the spinal column from scenery running down the middle of
    the room into the thing the room opens with.
  · **LIGHTNING** charges a bared socket over a window it must be defended
    through. It holds, and it LEAKS back into the giant over
    `kPillarLifeSeconds` (26s); a socket holding beside it halves its bleed.
  · **CRYSTAL** seals a socket for good — but ONLY while both of its ring
    neighbours are holding, because crystal grows out of crystal and will not
    start in the dark.

So the seals have an order and the order has to be found. **Three sockets must
be alight at once before the first seal is possible**, which is what the leak
is for; after that each sealed socket is a permanent anchor its neighbours can
grow from, and the rest fall out. The star banks on four SEALS, not four
lights.

**AND THE ROOM SHOWS ALL OF IT**, because a rule about neighbours is useless
if the neighbours are invisible. The RING IS DRAWN — a nerve of bone between
each pair, dead while either end is dark and running with light when both
hold, so "both sides of this socket are dark" names something the player can
see. Each socket now draws its own state instead of one lit/unlit bit: RUBBLE
heaped over a buried mouth · an open dark socket · a burning one wearing its
remaining life as a draining arc that runs warm as it empties · crystal grown
out of a sealed one. And the reading names the rule at tier 2 — *"crystal only
SEALS where crystal already burns on both sides of it"* — the system, never an
order, the same way the sternum court names the scale's marks.

THE RING IS A RING: the four sit on a rectangle and a socket's neighbours are
its nearest TWO, so the diagonal is not one. If it were, every socket would
border every other and the ordering would evaporate — pinned by test. Nothing
can strand: sealing only ever helps and a guttered socket can always be lit
again.

**RIB CURVE, FOR THE NEXT PERSON.** A quadratic control point near the chord
draws a straight bone: the first pass put it at 0.35 of the reach and 0.30 of
the drop and the hall came out full of diagonal spears. The hub's ribs — the
ones that always looked right — use **0.7 of the reach, 0.25 of the drop**, so
the bone leaves the vault almost sideways and turns down late. Use those.

## 7.11 Art direction — GLASS INLAY (chosen 2026-09-23)

Chosen after mockups of eleven directions (illuminated folio, carved diorama,
leaded glass, ember chiaroscuro, three stone-and-glass hybrids, and four
abstract ones). Fire is the pilot; every planet follows it.

**THE RULE: stone is the world, glass is the signal.** A room is a carved
diorama of the planet's own stone. Leaded glass appears ONLY on things the
player acts on, reads, or changes. Learned in one room, it holds on every
planet: *if it's glass, it's part of the puzzle.*

  · **The stone.** Soft three-quarter top-down. The north wall shows its face
    (lit cornice, dark foot); east, west and south walls show only their tops.
    Props stand on the floor with a contact shadow. The floor keeps the
    TRANSLUCENCY RULE (§8): fills at alpha 0.5–0.6, so the shader glows through.
  · **The glass.** Panes held in near-black came with a faint warm highlight
    along the lead. Glass sits IN the stone: inlays in the floor, collars on
    plinths, windows and doors in the walls.
  · **The pane vocabulary** (shared; each planet tints it):
      – *frosted* — inert or waiting. Dull and translucent. Never bright.
      – *clear, with a white streak* — made or active. The brightest glass.
      – *flame* (per element: the lit/live state) — burning, rung, powered.
      – *snow / smoked* — sealed or hidden. Opaque.
      – *bared* — clear but dark, so you see what lies beneath.
      – *silver* — solved or banked.
      – *gold-rimmed rondel* — anything you can act on.
  · **Large surfaces stay mid-tone.** A glass field that covers most of a
    room cannot be its brightest thing (an Ice mock with near-white snow made
    the snow the loudest thing in the room). Only what you can act on, and
    what you have changed, gets bright glass or gold.
  · **Decoration is carved, never glazed.** Arcades, stalls, piers and beams
    are stone and wood. A window that says nothing is not allowed to glow.
  · **Change is animated, never a pop.** Glass lights by spreading (outward
    from a centre, along the lead, pane by pane), and goes dark by smoking
    over. A state change the eye did not watch happen is a state change the
    player missed.
  · **Cost.** Static stone and dormant glass are baked once per room into a
    `ui.Picture` (the Light archive's precedent). Per frame: the live panes,
    flames and baked glow sprites only. No `MaskFilter.blur` anywhere.

The shared kit is `lib/games/planet_dungeon/dungeon_glass.dart`: palettes,
panes, rondels, lancets, carved walls and plinths. A planet brings a palette
and its own compositions.

  · ◐ **FIRE — the pilot, built 2026-09-23, not yet played on device.** All
    ten rooms, in `planet_dungeon_game_fire_art.dart`. Where the glass is,
    and what it does:
      – *Doors* are lancets in the stone: open ones glow and breathe motes
        outward; sealed ones are smoked glass under iron, the chancel gate
        carrying its two stars. A door not yet revealed is bricked wall, and
        the narthex's splits along glowing seams as the hearth catches.
      – *Narthex:* the hearth's fanlight catches from the middle out.
      – *Nave:* the rose before the chancel gate IS the star count — a third
        of it sweeps alight per star banked, the boss goes gold on three.
      – *Scriptorium:* the soot mural is a smoked window. Each corner torch
        warms its own quarter and sends an ember along the lead; the fourth
        runs a light front out from the middle and the stations bloom as it
        passes. Settled it is DEEP amber, so the recorded stations are the
        brightest glass on it.
      – *Choir:* the labyrinth is a glass rose with a petal aimed at every
        brazier; fire runs up the spoke into the petal as each is lit, a wrong
        flame smokes the whole rose over, the won rite burns it from the heart
        out. Soot stains a pale-honey glass collar on each plinth (pale so the
        smoke has something to stain); ash is a soft drift, never a wedge — a
        triangle there read as a play button.
      – *Cloister:* the garth is a leaded bed (soil, vine, seep, spent ash are
        panes; fallen stones stand proud); the burn ring is a ring of panes.
      – *Bell gallery:* each bell hangs before an oculus that floods when it
        rings; the declared stand's glass takes fire.
      – *High altar:* one lancet per bell in the dais face keeps the tally;
        the black flame's vessel wakes violet.
      – *Sanctum:* a shattered rose that smoulders violet under the
        telegraph's warnings — never louder than them.
    `test/planet_dungeon_fire_glass_render_test.dart` renders every room whole
    and every one of those states, and asserts they are different pictures
    (`mkdir -p build/room_audit` for the PNGs). **Found in the renders, worth
    knowing for the next planet:** a lit pane must keep its lead on top or a
    run of them melts into one flat shape; any big stone top (a dais) must be
    dark and jointed or it reads as a UI panel; and the largest glass in a
    room (mural, roost) sits at partial heat so what it holds can outshine it.

  · ◐ **LAVA — built 2026-09-23, not yet played on device.** Shared pieces
    moved to `planet_dungeon_game_glass.dart` (doors, hidden-door stone, the
    live pane) so every planet opts in with a palette; Lava's own art is
    `planet_dungeon_game_lava_art.dart` with `kBasaltGlass`. Machinery, not a
    cathedral (§5.5): square-headed factory glass, basalt walls with iron
    bolted up the face, brass rims. The floor stays a crust, NOT flags (play
    said tiles read as safe) — baked now, with the fissures mostly dead and a
    few breathing, where before 26 plates and 34 forked cracks were rebuilt
    every frame. Glass: levers on glass bases with glass-bead notches (the
    setting lit); mold flasks rimmed in the colour of the metal they take,
    silver with a good casting, smoked when spoiled; the crucible's
    sight-glass, the accumulator's gauge, the cowl's green louvres, the
    chiller's frosted lip, the ward's glass keyhole (burning while you hold
    its key, silver once turned), and the heart heads' lips. The metal was
    reworked too — it read as TUBING (a lit bar with rounded blobs): the
    crust now covers most of every runner in angular plates, the body shows
    only in the seams, and the lip shadows the trench. The Black Glass
    crystallises shard by shard while the rite binds, then stays, with a
    cool glint so it is found walking in. Test:
    `test/planet_dungeon_lava_glass_render_test.dart` (LavaGlass_*.png).

  · ◐ **AIR — built 2026-09-23, not yet played on device.**
    `planet_dungeon_game_air_art.dart`, `kZephyrGlass`. Open sky, so the
    diorama is carved ISLAND: plain rooms are cloud-slate slabs with a front
    face, rock trailing underneath and a balustrade for walls; platforms are
    the same stone. The stone is a THIN tint (flags at 0.3, faint joints) —
    the first pass laid opaque pale flags and every room became the same grey
    slab, which is the author's 2026-09-19 note ("the stages all look too
    similar") all over again. Glass: the hub compass is a rose set in the
    floor, three rings of panes for the three stars (wind sky-blue, loom
    gold, storm lightning-white) filling round from north; the First Wind
    turns it for good. The Four Winds pillars are carved stones with their
    rune in glass, fewer and shorter panes the more the wind has worn them.
    Gust shrines have glass breath-slots, gale vents a glass eye with the
    breath cut in the lead, storm rods count rank in glass beads, the storm
    altar is a rose that lights from the heart as it opens, the rune hall's
    mural is a leaded window, the loom's heart and anchors are glass, the
    conduits a glass channel. Tests: `planet_dungeon_air_glass_render_test`
    (states) and `planet_dungeon_whole_room_audit_test --dart-define=AUDIT=Air`
    (every room whole — reusable for every planet).
    **Second pass (2026-09-24)** — ten of the seventeen rooms were still the
    same flagged slab with one prop in the middle. Each stage now bakes a
    carved feature of its own (`_paintSkyGround`, keyed by room id): the
    entry's landing dais, an anvil sunk in the anvil cloud's floor with its
    blow-lane scored, three rings cut round the ring cloud, a dais under the
    spiral with the vents' ring, troughs under the veils, the loom's wheel
    with a spoke to each anchor, a two-step reliquary, an aisle and column
    bases up to the rune mural, a channel joining the twin conduits, three
    steps and eight storm lanes round the altar, the guardian's scored
    duelling ring, and an octagonal crown terrace on the summit. All carved,
    all in the bake — no per-frame cost.

  · ◐ **LIGHTNING — built 2026-09-23, not yet played on device.**
    `planet_dungeon_game_lightning_art.dart`, `kVoltGlass`. A storm-works:
    bolted iron plate with the cable runs sunk in it, now baked, inside iron-
    stone walls; square-headed doors (machinery, like Lava). Glass where
    high-tension equipment really carries it: every post's insulator stack is
    three discs of glass lit when the line is live, pylons and sinks wear glass
    heads, mirrors silvered-glass vanes, a closed barrier is a smoked leaded
    shutter, sockets and station pads are glass in brass, the dynamo's rotor is
    a turning rose. The Thunderbolt leaves FULGURITE — the glass lightning makes
    in sand — branching out of the rotor across the court as it happens, and
    lying there for good (from `thunderboltWon` alone, so a later descent shows
    it without the ramp). Test: `planet_dungeon_lightning_glass_render_test`.

  · ◐ **EARTH — built 2026-09-23, not yet played on device.**
    `planet_dungeon_game_earth_art.dart`, `kBarrowGlass`. The strata floor is
    baked inside carved barrow walls. The glass is CRYSTAL — Earth + Lightning
    makes it, so it is this planet's own substance — drawn ONE way everywhere
    (`_drawCrystalBlade`: a body pane and a lit facet in lead): the crypt's
    locks and seals, the gaze prism, the Palm's cluster. The crypt's socket
    mouths are glass (frosted buried, smoked bared, lit locked); the giant's
    eye is a leaded rondel waking with the prism; the bone mural is a window.
    The Palm now GROWS as the rite binds — veins up the creases, then the
    blades smallest-first — and stands on every later descent.
    Test: `planet_dungeon_earth_glass_render_test`.

  · ◐ **WATER — built 2026-09-23, not yet played on device.**
    `planet_dungeon_game_water_art.dart`, `kTempleGlass`. The temple's water
    and moon were already carefully drawn and are untouched; the stone is
    sea-marble, baked and arcaded, with BIG flags and faint joints (the
    default courses read as a tiled grid again — `paintCarvedRoomShell` now
    takes `flagCourse` / `jointOpacity`). Sea glass on the working parts: wheel
    hubs lit on their stand with the stand counted in beads, seals as glass
    hatches (smoked, their wanted tide in gold; clear once yielded), canal
    basins as glass bowls, sills counted in beads, dams as panes of ice, the
    offering bowl filling as live glass, the gate's vigil stars, the mural as
    a window. The Frozen Moon now sets inside a rosette of ice glass that
    frosts out from it as the rite binds. Test:
    `planet_dungeon_water_glass_render_test`.

  · ◐ **STEAM — built 2026-09-23, not yet played on device.**
    `planet_dungeon_game_steam_art.dart`, `kVaporGlass`. The boiler house
    kept its 2026-09-02 brickwork; it is now BAKED (it was redrawn every frame)
    inside iron-banded walls, with square-headed doors. Gauge glass on the
    working parts: junction wheels and the entry vent carry glass hubs (lit
    when the main can pay), the firebox is seen through a sight-glass, a
    crucible corner's wanted elements are panes of their own glass,
    silver-capped when sealed. HIDDEN HARMONY used to leave only an empty
    socket ("what you took should leave a hole"); under the maxim rule it now
    sinks into the plinth as the rite binds and stays as a steam-glass inlay
    with condensation running on it. Test: `planet_dungeon_steam_glass_render_test`.

  · ◐ **POISON — built 2026-09-23, not yet played on device.**
    `planet_dungeon_game_poison_art.dart`, `kVenomGlass`. The monastery was
    already a built house (walls, bays, beds, flags) and keeps its stone.
    Apothecary glass on what means something: relic sockets at the cross's
    foot are glass lenses in the brew's colour once full; the lustral font's
    water is a pane, sick until the vial goes in. THE DOSE used to leave
    nothing: it is now scored in a glass rondel at the prior's crossing — a
    pane of each colour as the wisp is walked home in it (the score pips moved
    here from the wisp), the heart blooming white as the rite binds, kept on
    every later descent. Drawn ABOVE the ambulatory's gloom, like the
    cressets: the first render put it under and the gloom ate it.
    Test: `planet_dungeon_poison_glass_render_test`.

  · ◐ **ICE — built 2026-09-23.** `planet_dungeon_game_ice_art.dart`,
    `kFrostGlass`. The observatory ground (2026-09-15) stays; it gains walls,
    the Roof of the Hollow as ONE leaded window (every pane in came), and
    lancet tracery in every gallery mirror. **The Star-Walker left nothing**
    (the audit below was wrong: the telescope and the stranger were both
    REMOVED once found). The telescope now stays, and the stranger is caught in
    its lens as an eight-pointed leaded star that assembles as the rite binds.
    Test: `planet_dungeon_ice_glass_render_test`.
  · ◐ **MUD — built 2026-09-23.** `planet_dungeon_game_mud_art.dart`,
    `kPeatGlass`. An open fen, so its edge is BANKED PEAT (the same shell in
    earth), not a wall; the bog itself is untouched. A moor-altar's offering
    is a pane of still water (the sky in it while it holds, smoked while the
    ground drinks it). The lotus (No Mud, No Lotus) is leaded pink glass,
    opening petal by petal as the rite binds, drawn large enough to find
    across the fane. Doors standing OUT in a room (the wallows) keep their own
    look — the glass doorway is for doors cut through a wall
    (`_doorOnWall`). Test: `planet_dungeon_mud_glass_render_test`.
    **Second pass (2026-09-24)** — the first left Mud with almost no glass
    and grey fog over every knoll. The fog was the GENERIC sky clouds (pale
    grey) showing through the peat floor; Mud now has its own low dark fen
    haze. THE CROSSINGS ARE GLASS: a leaded strip down each crossing's spine
    shows its state — murky and quaking (mire), clear streaked moss-glass
    (sod), sunk, cracked and smoked (drowned) — and a drag runs down it pane
    by pane from the head you worked it at (`_fordGlass`, eased per ford).
    Marker stones carry their slough's mark in a rondel of its glass. Wallows
    (knoll and risen) are a stone collar with a round leaded lid: smoked when
    shut, still water turning when they will take you — never the default
    door frame. The fane's pavement is thinner, carved (shadow + lit lip) and
    under a silt wash, so the things standing on it stay brightest; the
    sink-pit sits in a stone well-head.

  · ✅ **DUST — built 2026-09-24; POLISHED 2026-09-25 (played on device).**
    `planet_dungeon_game_dust_art.dart`, `kSandGlass`. The deck and standing
    fabric were redrawn EVERY FRAME; they are now baked with a sandstone shell
    (low face below the streets, where the cut face is the north wall; no
    arcade — blind arches on a 40px face read as black humps). Lamps stay
    live. Dust got its own low sand haze (the generic grey clouds lay over
    every street as fog) and fainter lee banks. Glass: a mound's survey tag is
    a pane that says its state (frosted buried, lit bared, sanded drifted);
    bare seals show a lit boss; the great glass is leaded; a vane's blade is
    a pane lit while wound; granary plates are glass. NOTHING PERISHES now
    sets a rosette of five panes round the cist, one per mound with its mark,
    lighting in turn as the rite binds and kept on every later descent.
    Test: `planet_dungeon_dust_glass_render_test`.

  · ◐ **CRYSTAL — built 2026-09-24, not polished, never on device.**
    `planet_dungeon_game_crystal_art.dart`, `kPrismGlass`; the chamber glass
    itself is in `planet_dungeon_game_crystal.dart`. Vitrea is already glass,
    so the fault was the GLAZING: five free cuts ran long black lines across
    every chamber and read as cracks. A chamber is now glazed as a window — a
    border of quarries in its colour, a light diamond lattice you see the bed
    through, and a medallion whose petal count is the chamber's own mark
    (`_kChamberPetals`), so colour and shape both say which slab arrived —
    and it is BAKED per chamber (it was ~20 paths ×3 per frame). Doors are
    prism glass in the stone. KNOW THYSELF showed only while the Black Cell
    stood wedged again; now the Black Cell's medallion silvers petal by petal
    as the rite binds and stays a mirror wherever the keep puts it.
    Test: `planet_dungeon_crystal_glass_render_test`.

  · ◐ **PLANT — built 2026-09-24, not polished, never on device.**
    `planet_dungeon_game_plant_art.dart`, `kVerdantGlass`. The crypt already
    had its architecture and a floor built to read at two sizes, so the stone
    stays; the ledger stones (~60 slabs clipped and stroked every frame) are
    BAKED per room per size. Doors are garden glass. A grave-lamp burns in a
    leaded chimney (smoked while dead); the growth altar's bowl is three
    panes — loam, seed, sun — lit as each step is laid, gold heart when the
    bloom wakes. THE UNSEEN SHADE left only a run-state tree (gone next
    descent): what grew in the shade is now a tree of leaded glass — the
    trunk rises, the leaves fan open in turn as the rite binds, a gold fruit
    last — standing in the fern gallery for good.
    Test: `planet_dungeon_plant_glass_render_test`.

  · ◐ **SPIRIT — built 2026-09-24, not polished, never on device.**
    `planet_dungeon_game_spirit_art.dart`, `kWraithGlass`. The field was a
    wash under pale fog with hollow outlines for doors; it now stands inside
    a baked CHURCHYARD WALL (the same in both worlds — no arcade, the arches
    read as black humps) under a low cold mist, with grave glass in the
    doorways. A crossing the other world holds is drawn over its shut glass,
    doubled and cold (`_renderGraveOverDoors`; the old outline pass is off on
    glass). A barrow's sigil stone is a rondel of twelve panes — the living
    half ember to a warm eye, the ring gold once the mark takes. STUFF OF
    DREAMS left three scratches on a run-state stone: the undug grave's blank
    headstone is now a lancet of leaded glass whose three lights (the names
    told — yours) and star light as the rite binds, kept in both worlds.
    Test: `planet_dungeon_spirit_glass_render_test`.

  · ◐ **DARK — built 2026-09-24, not polished, never on device.**
    `planet_dungeon_game_dark_art.dart`, `kUmbraGlass`. The vault keeps its
    inside-out ground (corona stone / umbra edges), now clipped square, and
    gains baked iron-dark WALLS (the old rounded rim strokes are gone), umbra
    glass doorways, and a low violet dust instead of the pale fog over every
    lit quarter. Every gnomon is a finger of BLACK GLASS in two leaded
    facets (`_drawGlassFinger`). THE FOURTH FINGER rises from the well to
    the rim as the rite binds, lit violet from inside, and stands there on
    every later descent. Test: `planet_dungeon_dark_glass_render_test`.

  · ◐ **LIGHT — built 2026-09-24, not polished, never on device.**
    `planet_dungeon_game_light_art.dart`, `kLumenGlass`. The archive fabric
    was already baked; it is clipped square inside baked limestone WALLS,
    with archive glass doorways and a faint warm haze in place of the grey
    fog over the lit bays. The catalogue's ten cells are panes of archive
    glass — gold lit, smoked dark — and still the live map. AFRAID OF THE
    LIGHT left an empty slab: the volume now lies in it, a book of smoked
    night glass on a gold clasp that opens from the rite's first beat (it
    keys on `_ritePendingEgg` too, or the rite would play over nothing) and
    lies open on every later descent.
    Test: `planet_dungeon_light_glass_render_test`.

  · ◐ **BLOOD — built 2026-09-24, not polished, never on device.**
    `planet_dungeon_game_blood_art.dart`, `kSanguineGlass`. A living heart
    is not a building, so the carved edge is PORPHYRY (baked), with garnet
    glass doorways and a low dark-red haze in place of the grey fog; the
    beating tissue floor is untouched but clipped square. A stopcock's stub
    is a garnet glass vessel — lit and flowing while it carries, smoked dead,
    dull untouched. THE BLOOD IS THE LIFE read run state only: once found,
    every cock in the eight wears a leaded garnet heart, lighting in turn as
    the rite binds. Test: `planet_dungeon_blood_glass_render_test`.

**SECOND LOOK, SAME DAY (2026-09-24)** — the author called Dust bad; the
honest read was that Dust, Blood and Plant each put everything at one value.
  · DUST → THE NIGHT DIG. Streets were bleached tan; the sky mood is now
    night (0.3–0.36 on the streets), the ground dark umber, rubble cut ~70%
    (drums 1–3, sherds 3–8, one heap), and the MOUNDS are the heroes: a
    pegged, strung slab (buried), a black pit with lamplit amber strata
    (bared), a moonlit dune with a long shadow (drifted). A dig throws its
    spadeful visibly — grains on an arc to where it lands, a ring of sand
    where it falls (`_sandThrow`, 1.1s; over the wall when the target is in
    another room). A faint survey grid is inked across the streets (baked).
    THEN, STILL "OVERLY LINED" (the author): Dust ran five line systems at
    once — the survey grid, ripples, bank combs, flag joints, chalk on every
    square — plus wind streaks in the sky. The grid and streaks are gone,
    combs and street flag joints are gone, ripples near-invisible, and a
    buried square is ONE slab (a cross joint, four pegs). THE SEAL YARD is a
    board now: a sunken tray, fifteen clean tiles, and sand in exactly two
    shapes — a low mound (1 load), a tall crested dune with a shadow (2) —
    seals under the sand, pillars as standing stumps. The tile gaps are the
    grid; the chalk string, pegs, under-paving and per-cell blobs are gone.
  · BLOOD. The floor is darker and the tissue recedes (×0.78); the beat
    floods a vein round the inside of the porphyry on every thump; passage
    markers stand a pace off the wall (the glass doors hid them) and a
    carrying lumen runs a bright bead.
  · PLANT. At your own size the ledger stones are ONE worn floor (joints
    only); the per-slab mosaic is kept for tiny, where it is terrain. Each
    room gets its own carved floor motif, baked (`_paintCryptMotif`): a
    root-boss, a runner, a jointed court, a gallery's frond kerbs, an
    effigy ledger, a flower, the arena's petal ring.
  · SPIRIT's barrow is a hill (dark foot, turf, lit crown, flank ribs) with
    its kerb stones actually visible.

**POISON, FROM PLAY (2026-09-24).** (1) THE BOIL-OVER. The party holds
exactly the gives the four brews need, and the pot would brew one twice —
the house became unfinishable until a death. Refusing duplicates was tried
and dropped (the author: mistakes should be allowed). Instead, after every
cauldron press, if the gives left (plus what is in the pot) can no longer
make the brews still wanted, the pot BOILS OVER: foam heaves out, the
bench's bottles burst into shards at 0.9s, and every gift not already poured
into a plague comes back (`_applyBoilOver` recounts `given` from the hands
of poured brews only). Woken/slain plagues and the open font stay. Test:
the plagues test brews Bloomvenom twice and finishes from what came back.
(2) THE ENTRANCE POT. The quarantine door no longer opens to one Poison
press: a pot in the middle of the lazar gate takes ONE gift from every hand,
any element (pips light in each giver's colour), brews, and the wax runs off
the door. None of it counts against the brewing gives.

**AIR, THIRD PASS (2026-09-24, the author: "a lot of rooms can be
optimized, visually").** Every room was one slate value — floor, walls and
carving — under an identical dotted balustrade. Now: (1) a dark bed under
the flags so carving reads, carving lips in the zone's light; (2) THREE
ZONES by wing (`_skyZoneOf`): dawn gold up the spire, clear day among the
clouds and the loom, violet in the storm, guardian and relic rooms — a wash
over the stone and the colour of carving and pennants; (3) the balustrade is
a PARAPET: heavy posts ~150px apart, a rail on most spans and a gap where the
wind took one, and pennants on the north posts drawn live (a few triangles a
frame); (4) platforms have a thick dark edge, a dark bed and the zone light;
(5) the wonder clouds carry a cloud of their own shape — anvil, ring, spiral
arm — as ONE unioned path of dense puffs (a string of separate puffs read as
beads), shadow + body + clipped crown, baked.

**EARTH, REVIEWED (2026-09-25).** The rules were good and hidden, and one
star was a race. S1: a bone LEVER is drawn pinned between each rib and the
one below (`_drawRibLevers`), glowing while it drags, and each rib's CRADLE
is cut into the chasm, lit when seated. S2: NO CLOCK — lit sockets hold;
sealing DRINKS the charge of the unsealed neighbours it grows between (you
watch it run along the ring into the crystal), so the puzzle is the order;
the ring is a carved channel. S3: the five clue marks are lit TABLETS (a
small scale with that stone in its true pan); standing by one records it
(`scaleCluesRead`) and the scale's stone base lights that stone's slot with
an arrow to its pan. The scale itself is stone — post, thick beam, bowls,
carved weights. Nothing added that does not carry a rule.

**THE LINE AUDIT (2026-09-24)** — after Dust, the same fault elsewhere:
  · POISON: flags inset 2.6px → 1.0 (the bed showed between every stone as a
    web of joints), splits 16% → 6%, floor alpha 0.72 → 0.84 (the sky's
    bright veins read through). The bell ward's floor carries the bell's
    mouth and the scriptorium's an illuminated border (`_renderWardInlay`)
    — the four wards were one room.
  · LIGHTNING was the opposite — too dark and empty. Cheap light, no blur:
    a STORM FLASH every ~7s (a double blink, and shafts raking in off the
    north wall — `_renderStormFlash`, one rect + three paths while lit);
    live wires carry a halo and throw short crackling arcs (jitter
    re-rolled ~12×/s, deterministic per wire); live posts pool blue light on
    the floor and crackle at the head; the cables sunk in every floor glow
    and carry travelling pulses while the wing is fed.
  · DARK's umbra was wireframe: the architecture is solid shadow now (fill
    0.92, rim 0.3), floor flags nearly gone — the strong violet line is
    kept for what you use.
  · PLANT: the joints at your own size are faint (wide 0.3, hairline 0.14).
  · CRYSTAL: the lattice came lighter still (1.0px, 0.16).

**ALL SEVENTEEN PLANETS ARE IN GLASS (2026-09-24).** Every Lost Maxim now
leaves a permanent piece keyed on the egg id (the table below has no gaps).
The seven unpolished planets were repainted from renders only — none has been
played on a device, and none is in `kPolishedDungeons`.

**ALL TEN POLISHED PLANETS ARE IN GLASS (2026-09-23)** — Fire, Lava, Air,
Lightning, Earth, Water, Steam, Poison, Ice, Mud. The other seven (Dust,
Crystal, Plant, Spirit, Dark, Light, Blood) followed on 2026-09-24 — see
below.

**THE MAXIM LEAVES A MARK (the rule, from 2026-09-23 — part of every
planet's glass pass).** Fire's Ember Epitaph is the model: the solve is
something you WATCH happen in the world, and what it made stays there for
good. Every Lost Maxim, as its planet is repainted, must have:

  1. **A watched final beat, in the world.** Not only the shared Rite of Three
     over the focus: the thing itself transforms on screen — the epitaph's
     burn-front unscrambling the cipher into fire-glass letters is the bar.
  2. **A permanent piece, keyed on the PERSISTED egg id** — never on run
     state. It is standing in its room on every later descent, and it is
     drawn from `discoveredClouds.contains(<egg id>)` alone, so a fresh game
     that only knows the id still shows it.
  3. **Made of the planet's own glass or alchemy.** A maxim's piece is the one
     place a planet may keep a *trophy* — a window, a relic, a lit inscription
     that shows what you did. It follows §7.11 (it is something you CHANGED,
     so it may be bright glass) but it must never be louder than a live
     puzzle signal in the same room.
  4. **Pinned by a render test:** the found and unfound rooms are different
     pictures, and the found shot is taken from a game where the egg id is
     the only thing set (Fire: `epitaph_won` in the glass render test).

Where the seventeen stand (audited 2026-09-23 from what each renderer reads):

| Planet | Permanent piece today | Verdict |
|---|---|---|
| Fire | the epitaph burnt into the mural, the planter's flame kept | ✅ the model |
| Air | the compass settled (`_fourWindsFound` in its render) | ✅ keyed right — repaint in glass |
| Earth | the Palm's crystal cluster, leaded, grown as the rite binds | ✅ built 2026-09-23 |
| Water | the Frozen Moon in its rosette of ice glass, frosted out as the rite binds | ✅ built 2026-09-23 |
| Steam | Hidden Harmony inlaid in the plinth as steam glass (was an empty socket) | ✅ built 2026-09-23 |
| Lava | the Black Glass, set in the slag pit as a leaded obsidian mirror (the audit first misread this: the old glass showed only BETWEEN taking the slag and banking the maxim, then vanished) | ✅ built 2026-09-23 |
| Mud | the lotus in leaded pink glass, opening as the rite binds | ✅ built 2026-09-23 |
| Dust | the tally rosette round the cist, five leaded panes lit in turn as the rite binds | ✅ built 2026-09-24 |
| Crystal | the Black Cell's medallion silvered to a mirror, wherever the cell stands (it used to show only while the cell was wedged again) | ✅ built 2026-09-24 |
| Dark | the fourth finger, black glass lit violet, risen at the well's rim | ✅ built 2026-09-24 |
| Light | the afraid volume, a book of night glass lying open in its slab | ✅ built 2026-09-24 |
| Ice | the stranger caught in the telescope's lens as a leaded star (it used to REMOVE the telescope) | ✅ built 2026-09-23 |
| Lightning | fulgurite branching from the dynamo's rotor, the rose lit, the breakers welded | ✅ built 2026-09-23 |
| Plant | a tree of leaded glass where the shade lay, grown as the rite binds (it used to read run state) | ✅ built 2026-09-24 |
| Spirit | the undug grave's headstone as a lit lancet window, in both worlds (it used to read run state) | ✅ built 2026-09-24 |
| Blood | a leaded garnet heart on every cock in the eight, lit in turn as the rite binds | ✅ built 2026-09-24 |
| Poison | the Dose scored in a glass rondel at the prior's cross, heart lit | ✅ built 2026-09-23 |

The four ⬜ are the real gaps: today a player who found those secrets comes
back to a room with no sign of it.

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
- ✅ Air pilot puzzles wired on the framework; guardian = Roc (calm or
  defeat); cleared-star hiding; onboarding/room hints. **§9.1 REWORKED
  2026-08-11** — Star 1 is now wake-the-winds (permanent gales, order is the
  puzzle, `strandable == 0` proved), Star 3 is storm-rod steering (latching
  conduits; the storm strikes B up a ranked staircase), and Air's logic finally
  lives in its own part file (`planet_dungeon_game_air.dart`) like the other
  five. The quality-graded conduits are gone: A is a hard gate, B answers no
  hand at all.
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
  **AMENDED 2026-09-19** (author: *"the stages are all starting to look too
  similar — more transparent, to show the background"*): the rule was
  being honoured per LAYER and broken in the COMPOSITE. The shared stage
  slab under every planet sat at 0.52–0.60, and each planet's own bed at
  ≈0.5 on top of it, so the floor a player saw was three-quarters opaque
  everywhere and the shader — the whole difference between one planet and
  the next — barely came through on any of them. The shared stage is a
  TINT now (0.26–0.32), not a floor; the planet's bed is the floor and the
  0.50–0.60 budget is the bed's. Dark's umbra bed and Dust's deck came
  down with it. Judge translucency on the composite, never on one fill.
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
  wisp pickups → plain projectiles; mystic environment washes. Kin support
  paths use party-native dungeon equivalents where Survival targets the ship
  or orb. Covered by the `survival-parity abilities` test group.
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
  hub compass carries THE FOUR WINDS (the rune pillars, rolled per run).
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
  basin/ledge water surfaces, drowned-court moon, the canal gallery (sills cut
  in the lip, the drifting moon-lantern, ice dams, the blind sump), moon
  pools that freeze into cracked ice discs, kelp arena. Leviathan wired
  (sheets + raids + enrage copy). Frozen Moon egg built. Tests:
  `planet_dungeon_water_full_run_test.dart` (animated-flood asserts,
  pip-only valve gate, tide-door lock/unlock, false-pool shatter, recipe
  freeze, egg) + layout integrity extended to all tide verbs.
  **§9.1 rework landed 2026-08-11:** S2 became a deduction —
  `GhostEddy` now carries an id (not an order), joined by `GhostMouth`
  (spring/sea) and `GhostChannel` (the carved grooves). The derivation, the
  brute-force `solveGhostCurrent`, the per-run roll and the render all go
  through one spin rule, so the layout test's uniqueness proof can never
  drift from what the game plays. `_templeProgressReadout` moved the sluice
  and wade tallies out of the capsule; the canvas tide gauge stayed. The
  minimap objective marker now points at the course's ENDS, never the next
  eddy (which would have handed the puzzle over for free). Leviathan's
  tide-turn is one `_isTemple`-guarded line in the shared guardian loop.
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
- ✅ **Lightning — Storm Circuit (Voltara) built** (see §6 entry 3): living
  circuit graph (per-frame BFS power, mirrors, powered barriers, decaying
  charge), S1 multi-target beam threading, S2 storm-cell herding + anvil
  heat, S3 element-stationing deduction arena → Raikuma (sheet + raids +
  enrage). Thunderbolt egg + capacitor vault cache. Lightning shader.
  Full-run + circuit-graph layout tests.
- ✅ **Lightning §9.1 rework — the ZERO-SUM DYNAMO built** (2026-08-10, see
  §6 entry 3 REWORK BUILT block): trunk breakers at the hub (one trunk fed
  at a time, run starts on the vault trunk), dark walkable dead segments +
  capped spark-wisp prowl, vault-only-unpowered re-hide behind the eased
  vault bolt, S1 four-mirror threading with fulminate vats (solver-proven
  unique, 1/16; vat detonation trips the dynamo), S3 decoy pair VD+FD
  (solver-proven impossible, 0/32), Raikuma feeds-on-power retrofit with
  the grounding spike, §5.6 prose pass (objectives de-leaked, insight
  tiered, BLOCKED one-clause refusals) + terminal/socket/dynamo progress
  readout. No hard family gate declared. Tests rewritten Steam-style
  (14 focused tests) + 3 new layout/solver tests — 256 dungeon/raid green.
- ✅ **Steam — The Molten Labyrinth built** (see §6 entry 6): first planet
  under the §5.5 mandate — pressure RING-MAIN topology (no hub), global
  pressure economy (40 start / 15 junctions / +4 condense / +20 stoke),
  burst-disc (≥60) vault sacrifice, molten tile grids (Earth+Fire→Lava,
  Steam cools, Earth dams). Boilrog. Hidden Harmony egg. Full-run +
  ring-economy layout tests. 228 dungeon/raid tests green at time of build.
- ✅ **Poison — The Venom Monastery (Toxica) built** (2026-08-24): quarantine
  wards off one ambulatory, joined by inner squints — physic for three of
  four, and the cistern's dregs refill ONLY while a ward can still be saved,
  so a run cures exactly three, never four, never fewer. Strains are read by
  BEHAVIOUR (beat / cling / leap / play-dead), and a wrong draught FEEDS one
  permanently. The oubliette hangs under whichever ward you surrendered.
  Blightfang's lull answers a correct dose, never a clock. Gates: Lava HORN
  breaches the charnel (steers the triage, blocks no star), Mud MANE crosses
  a live squint. Proof brute-forces the whole reachable state space across
  all 24 strain arrangements: never four cures, never fewer than three, any
  ward can be the sacrifice, and no choice strands the run.
  DEVIATION: §5.5 wants the vault INSIDE the surrendered ward; the layout
  test enforces one authored `vaultCache` and the ward is a runtime choice,
  so the cache sits one level down, reachable only through that ward's floor.
- ✅ **Ice — The Frozen Observatory (Glacius) built** (2026-08-24): a vertical
  shaft joined by FLUES, each of which is a drift (ride it, land on its
  shelf), a stair (frozen, two-way, and its shelf is sealed for the run), or
  scoured (ridden once, takes no frost again). Every flue is your ladder home
  or the only way onto its treasure shelf, never both, and you commit at its
  head on the way down. The cache is visible only as a glow in the gallery's
  mirror-pool, and the ride that reaches it scours the drift that caught you.
  Frowyrm eats your stairs as you fight it — and if you left no stairs, the
  rimefall instead (2026-09-15: the roar used to cost a rider nothing, so the
  only player it punished was the one who had built the ladder home).
  NOTE: the spec as literally written is a STRANDING MACHINE — the same
  search with the valve removed reports 120 of 122 reachable states
  strandable. Shipped with the RIMEFALL: Ice freezes it from the sump
  (element-only), and it thaws the whole shaft back to its opening state, a
  full re-descent rather than a shortcut. One-way descent is preserved.
  Proof is two-level: BFS all 122 reachable states, then from EACH of them
  BFS that every room — vault shelf and maxim niche included — is still
  reachable. `strandable == 0`.
- ✅ **Lava — The Molten Reliquary (Magmora) built** (2026-08-24): a foundry
  line with no hub, cut along its whole length by its own plumbing (a channel
  is not a floor — it stops walkers AND gliders). Five crucible charges,
  never refilled; five levers program the line, and what a pour BECOMES is
  decided by where it went. The ordering question is DERIVED, never handed
  over: cold metal is both a road and a plug, so freezing the chiller kills
  the plain arm and laying the sump road too early blocks the mold's own
  feed. Fire's order-memory ledger seat is untouched — the solver proves
  more than one order of the same four pours works.
  CALL: a wasted pour costs a charge, never the run (a Lava heart melts any
  casting back out). Budget 5 against a tightest plan of 4 — one blunder
  survivable, two not.
  DEVIATION: §6.2 wants the chiller to harden into a bypassable bridge;
  shipped as an in-line shroud, because a bypass lets the north arm survive
  its own plug and deletes the ordering question.
- ✅ **Mud — The Sinking Altar (Palusia) built** (2026-08-24): seven knolls on
  one continuous fen, where the ROOMS are constant and the EDGES are not.
  Every ford is MIRE (wadeable, bears no load) → SOD (a dragged causeway that
  bears the sarsen) → DROWNED (final). Dragging a ford squeezes its water
  along its own slough and drowns the crossings up- and downstream, so the
  hardened set is always an independent set per watercourse. Order is
  UNOBSERVABLE — A-then-B lands on the same fen as B-then-A, pinned by a test
  — which is what keeps this out of Air's ordering seat. The choir of moor
  altars demands exactly the four fords that form the long southern road, so
  the puzzle tells you the road; every short road drowns a ford the choir
  needs and kills Star 1 for the run. The vault knoll is cut adrift by a drag
  and founders under you.
  NOTE: like Ice, the raw mechanic is a stranding machine — **1200 of 1284
  reachable states (93%) are dead ends without the valve**. Shipped with the
  WALLOW + SOUGH: pulling the peat plug heaves the whole fen back to opening
  state, every road gone and the sarsen washed back to the gate. Banked stars
  survive; drags stay 100% irreversible. Proven by two independent searches
  (a forward two-level BFS and a reverse BFS) pinned equal so neither is
  trusted alone: 0 strandable with the valve. A Mane-less party is separately
  proven unstrandable (1260 states, 0).
  DEVIATION: the heave means the two stars can be earned in two different fen
  shapes rather than one. The good shape still does both at once, so optimal
  play is rewarded, but a botched fen costs a trek instead of the run. Ice
  shipped the same trade-off — it is the price of the anti-softlock valve.
  NOTE: the fen carries two structurally dead doors (`sunken_lotus →
  lotus_knoll` permanently blocked, `drowned_fane → sunken_lotus` permanently
  hidden), which exist only so the bowl has a legal way out under the
  every-door-has-a-reciprocal layout invariant.
- ✅ **Dust — Sablis, the Ruins of Time (Cindrath) built** (2026-08-24): a
  buried city on two Z-layers — five street rooms above, six excavation rooms
  below — where each of five mounds carries a LOAD, and the load count IS the
  layer swap: 0 bared = the street is a pit and the cellar below opens · 1 =
  a plain street square · 2 drifted = a dune-wall, and a ramp opens instead.
  Conservation is structural rather than asserted: `RuinsOfTime` is the only
  object that can write a load, and every mutator is a PAIRED TRANSFER (one
  mound 1→0 while a chosen neighbour goes +1), so the total cannot leak. A
  bared square has nothing left and a drifted one is packed too hard for a
  spade, so both edits are irreversible for the run, as Ice and Mud kept
  theirs. The vault verb is inverted: the sunken house is the one thing
  digging cannot reach — heap a SECOND load on and the weight cracks the
  party wall in the undercity.
  NOTE: the fourth mutable-world planet in a row to be a stranding machine —
  **319 of 396 reachable states (81%) strandable without the valve, 0 with
  it** (Ice 120/122, Mud 1200/1284). Valve is THE LEVELLING WIND: an Air hand
  winds any iron vane and the sirocco restores every load, costing every
  cellar, ramp and spadeful. Element-only, so no party can be locked out.
  Star 0's survey yard is exhausted over all **45,474 reachable ledgers** —
  11 solvable, shortest 8 verbs, **0 deadlocked**, conservation holding at
  every one — and the shortest solution is replayed through the real engine.
  DEVIATION: §6 puts the Earthhorn gate on Star 0 (the Three Seals), which
  §4's first-descent guarantee forbids. The gate moved to the rite's false
  wall; Star 0 is element-only, and §6's Airwing gate stays on Star 1.
  DEVIATION: `Air+Earth→Dust` is wired as a two-body recipe standing in for a
  downed Dust hand, NOT as §6's "lays spoil remotely" verb — remote laying
  would break the throw geometry the survey yard is built on.
- ✅ **Crystal — Vitrea, the Prism Labyrinth (built 2026-08-25)**: the 8-puzzle
  as architecture. Nine fixed lattice cells in a stone frame; eight glass
  chambers and one hollow permute through them, and whoever stands at the
  boundary rides or hauls with them. THE STATIC LAYOUT INVARIANT IS HONOURED
  RATHER THAN WEAKENED — the twelve arches are constants, every door authored
  reciprocally, nothing created or destroyed at runtime; what a slide changes
  is whether the two chambers meeting at an arch are both CUT on that face.
  (Plant reused this trick; hand it to any future planet whose connectivity
  moves.) Stars 0 and 1 are provably never holdable together — 0 states.
  PARITY, the thing that could have shipped an unsolvable dungeon: reachable
  orbit is **181,440 = 9!/2**, with the other half proven unreachable
  arrangement-by-arrangement across all 362,880 rather than merely unvisited.
  With the hollow home the chamber rearrangements are exactly **A₈** (20,160
  × 9 = 181,440); Wilson's theorem applies because the 3×3 grid graph is
  2-connected, not a cycle, not θ₀, and bipartite — the alternating case.
  Player-aware search over (arrangement × where the body stands) explores
  **1,592,585** states as one strongly-connected component; every required
  configuration is inside it and shares the start's parity class.
  The proof paid for itself twice before passing: draft 1 had **2 of 181,440**
  arrangements reachable (a body could not reach a shove-plate); draft 2's
  valve carried the ringer with their own chamber, so using it in a walled-in
  corner restored the same trap forever. 7,404 of the reachable states are
  jams (0.46%), so the valve is load-bearing. Also caught by hand: a Crystal
  press in the choir shoved instead of striking during the lull, making the
  fight unwinnable WITH THE IDEAL TRIO.
  DEVIATION: §6.10 gates the first star behind Crystalmask; §4 wins, the gate
  moved and Star 0 is element-only + braid.
  NOTE: no `dungeon_minimap.dart` atlas entry (Mud, Ice and Dust have none
  either — it falls back to centre).
- ✅ **Plant — The Verdant Crypt (Verdanthos) built** (2026-08-25): ten rooms,
  one geometry, seventeen passages, each cut for exactly ONE size of body. At
  huge a rill is a stride and a crack is a hairline; at tiny every crack is a
  corridor and every rill a river. Scale belongs to the OBSERVER, never the
  ground — which is what keeps it out of Dust's Z-layer seat. Three seed beds
  carry the world-edit: a seed set by a huge hand goes in shallow and comes up
  a CREEPER (a road only a small body walks); set by a tiny hand it goes in at
  the root and comes up a TRUNK (a road only a giant walks) that fills the
  fissure it grew in. Each product is a road for the size you were not, and
  the route dictates the product. THE TRAP: `b_root`'s creeper is the only
  small road to the islet — Star 1's seeding and the vault both — while its
  trunk is a bough that costs the worm-run.
  Proof: 448 states / 27 arrangements, **strandable 0**, and **142 of 448
  strandable with the withering deleted** — every one of them a b_root trunk,
  so the valve is load-bearing. Valve is THE WITHERING (two turns of any mulch
  pit, element-only Mud, in every room but the arena): every vine to mould,
  out at the gate in your own body.
  BEST RESULT IN THE SET: **size-lock is 0 measured WITHOUT the valve** — the
  named hazard (stuck at the wrong scale) is eliminated by GEOMETRY, not paid
  for, because the three galls are placed so every small component legal play
  can reach contains one. A test is named for it so anyone moving a gall
  breaks it.
  DEVIATION: §6's Plantmane gate moved to the rite (§4 first-descent).
  NOT DONE: the party's rendered radius does not halve at tiny — `_radius` is
  a `static const` on the core class and plumbing it exceeded the one-line
  hook discipline. Scale is expressed by redrawing the room's furniture as
  terrain, a per-door size glyph, and a SIZE tiny/huge readout. **Open
  question for a device playtest: whether that reads as scale without the
  radius change.**
- ✅ **Spirit — Requia, the Echo Grave (built 2026-08-25)**: one grave-field
  read twice. Seven barrows on a corpse round plus two chords; every crossing
  is walkable in exactly one world, and six of them have not yet decided
  which. A crossing is both / living-only (salted) / ghost-only (a road that
  fell) / **a revenant** — somebody still dying there, holding the ghost
  lintel up while the stone that killed them lies across the living way. A
  Spirit hand in the cold world hears them out: the death finishes, the living
  way clears, the ghost way falls in. Irreversible.
  The mere has two dead: stand there ALIVE and you must finish one; stand
  there DEAD and you must leave one restless. Finish both and you own the
  mere forever and the hollow grave behind it never — **544 of 2,276 states
  have lost the vault for good**, which is the strategic question biting, not
  a bug (Mud's precedent).
  **0 strandable of 2,276 states with NO VALVE**, by geometry: the lych road
  and drowned cut can never be told, so a ghost spine survives every state;
  and all six dead are heard out from spine barrows, so a body can never be
  standing in the pendant barrow whose last ghost road it is closing. The
  counterfactual is pinned — move each telling to the pendant side and **54
  of 369** reachable states strand.
  DEVIATION: §6's Spiritmask gate moved from Star 1 to the rite (§4).
  NOT DONE: §6.14 asks for the ghost half of the sigil on the actual minimap
  widget; it renders diegetically instead (a great arc struck over the field
  in the ghost world), because editing `dungeon_minimap.dart` was outside the
  file discipline. Small follow-up if it should be literal.
- ✅ **Dark — Nythralor, the Eclipse Vault (built 2026-08-25)**: a global
  light/dark flip rewrites the whole maze at once, and every flip made for one
  door closes another. The vault room only EXISTS in the dark state — in light
  it is not there at all and its slot is a blank face of stone.
  **0 strandable of 392 states with NO VALVE**, and structurally rather than
  by luck: (1) a turn is its own undo — you turn a gnomon by standing at it
  and are still standing there after, so the walk/turn relation is symmetric;
  (2) a room with no gnomon can never be shut on you; (3) every gnomon stands
  in the UPPER of the two quarters it commands, never behind the door it
  opens. Underneath those sit THE PROMISE RULES, authored one room at a time:
  seven of ten rooms carry a TWINNED crossing (a shadow-way and a light-walk
  through the same quarter, so exactly one is always there), the pall's two
  rooms carry the GNOMON'S PROMISE, the reliquary is a one-door pocket, and
  the arena's rood door is phase-free. The only irreversible edits are
  ADDITIVE — a portal opens and never closes — and an additive edit cannot
  shrink reachability.
  Two counterfactuals pinned so the safety is demonstrably designed: put the
  stair's gnomon in the deep, behind the gulf it opens, and the lower half
  becomes a one-way trip — **124 states strand**. Pull the arena's vane and
  phase-cut the rood door and **22 states strand**.
- ✅ **Light — the Beacon Archive (Solarin) built** (2026-08-25): one great
  round hall, nine bays over five sectors × two bands, and NO WALL between any
  two bays. A "door" is a SILL of one of three kinds — a GLASS LEAF (floor
  while lit, a hole while dark; every rim sill), a MIRROR SHELF (plain floor
  in the dark, impassable glare in the light; every sill into the heart), and
  one stone stair the light has never reached. So the rim is a road you BUILD
  and the heart is a road you must NOT light. This is the most dynamic
  connectivity in the set and it still honours the static layout invariant via
  Crystal's trick: the doors never move, only what they do.
  Three rim beacons, one press cycling DARK → four settings → DARK, each a
  (arc, pitch) pair. Low, the beam breaks on the two great stacks and lights
  the rim band only, at ONE lumen where an empty sector costs two — and that
  shadow is the thing the player is actually placing. Exposure is `lumens`, an
  instantaneous count that moves freely up and down, gating the reading and
  waking moth-wardens above the hush of 2.
  **0 strandable of 963 states with NO VALVE**, by construction: every move
  has an inverse (a press is a five-cycle taken from where you stand), a step
  can never be interrupted because EVERY beacon stands on the rim, the only
  one-way edits are additive, and Solarin is arena-local behind a phase-free
  stone stair. Three counterfactuals pinned: latch the beacons and **8**
  strand; loose Solarin's glare onto the rim and **47** strand; delete the
  great stacks and the hush loses two of its three slips outright.
  Also pinned: no arrangement reads all four effigies (moth and sun are
  mutually exclusive because nothing stands in the door bay to hold a shadow),
  and 600 frames of a live Solarin fight leave the lamp map byte-identical.
  DEVIATION: §6 gates Star 0 on Crystalmask (the beam-split); §4's
  first-descent guarantee wins, so that gate moved to the rite's prism oriel —
  the same move Plant, Dark and Spirit made. That is now SEVEN planets running
  where §6 gates an early star and §4 overrides it; §6's per-planet matrix
  should be read as advisory on gate placement.
  NOTE: Solarin's sheet is wired in `_guardianSheets` (MYS16, verified on disk
  at 2048×512), so it does not fall back to the procedural body as Noctryos
  does. Two touches in `planet_dungeon_game.dart` are therefore not behind the
  `_isArchive` guard; both are inert map literals keyed by mysticId.
  NOTE: Light is the only planet whose ideal trio uses one family twice —
  Lightmask · Crystalmask · Spiritpip. That is §6's own team, not a slip.
- ✅ **Blood — Hemavorn, the Sanguine Orrery (built 2026-08-25)**: THE
  SEVENTEENTH AND LAST. A figure-eight of veins crossing at the sinus with the
  heart inside the crossing. A four-phase pulse — SYSTOLE 7s → BACKWASH 4s →
  DIASTOLE 9s → FLATLINE 5s — runs free, unstoppable and unbranching, and a
  vein is a road only while blood is pushed through it, downstream only. The
  greater lobe reverses on the backwash (the doc's "or against it"); the
  lesser lobe never reverses, so entering the lung is a commitment. On the
  flatline nothing carries and every valve leaflet hangs open.
  THE FIRST PLANET WHOSE STATE THE PLAYER DOES NOT AUTHOR. Every other planet
  changes only when acted on; this one advances on its own, which makes
  stranding-in-time possible in a way no earlier proof had to handle.
  Vault trick, hidden in TIME rather than space: the auricle reliquary sits
  behind a leaflet pressure holds shut FROM EITHER SIDE, so it opens only in
  the pause between beats.
  **3,200 states (chamber × phase × grafts, all ten collateral rolls) · 0
  strandable · no valve**, with the beat as an always-available edge in both
  the forward enumeration AND the escape audit — a heart does not wait for
  anybody. Every chamber must stay reachable, which is stronger than exit +
  unearned stars. Counterfactuals pinned: open the lesser lobe and **272**
  strand (the CLOSED CYCLE is what makes one-way traversal safe here); cut the
  vault leaflet one-way inward and **320**; let the vagal node hold the
  flatline for ever and **264**. The Bloodkin steadying is deliberately not
  modelled — it only adds edges, so every number is a conservative bound.
  **PLANNED, NOT REACTION-BASED** — the question I most wanted answered, since
  a dexterity premise cannot be tuned away after the fact. `worstWaitPhases ==
  3`: from every state a road opens within one full turn of the clock, and
  every phase-locked object asks WHERE TO STAND, never when to press — walk
  in, wait, act. Missing the 5s flatline costs a wait, never a run. The single
  reaction window on the planet is the optional heart-drum egg (±0.85s), and
  no star sits behind it. Waiting is safe everywhere: zero hazards, zero gaps,
  and the only damage source is wisps a VERB wakes — which is what makes the
  periodicity argument load-bearing rather than decorative.
  DEVICE-TUNING TARGET (named by the author as the first thing to look at):
  the longest forced wait is ~20s, sitting in the reliquary for the next
  pause. Shrink lung chambers before lengthening phases.
  DEVIATIONS: §6's Bloodkin gate on Star 0 moved to the rite (§4); what
  survives is a legal-v2 family BONUS — a Blood Kin holds a vein open past the
  turn, which no puzzle requires. §6's corruption-flagging by Lightmask made
  element-only Light, because a family-exclusive PENALTY is never legal in v2.
- ⬜ **§9.0 INTERACTION REFIT v2 + hint/popup cleanup** — convert all six
  built planets to the §4 element-first / hard-family-gate model, implement
  "the seal remembers" descent chips, apply the §5.6 hint standard, rewrite
  the slow-and-loud tests. NEXT UP before any new planet.
- ⬜ Device tuning pending: Air, Fire, Lightning, Steam, **Poison, Ice,
  Lava, Mud, Dust, Crystal, Plant, Spirit, Dark, Light, Blood** (timings/feel — user playtest; Water + Earth already device-tested
  good). NONE of the 2026-08-24 three has ever been run on a device.
- ⬜ More Mystic guardian sprites for future planets (map in
  `_guardianSheets`, enroll in `kRaidGuardianIds`; roster in §6).
- ✅ **ALL 17 PLANETS BUILT** (2026-08-25). Every element has a dungeon, a
  mystic guardian and a derived raid. `kComingSoonDungeons` is empty. (+ their shaders).

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

KNOWN INTENTIONAL GAP:
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
Kin support paths are also closed: Ice charge/release, Steam boiler, Dust
cloud accumulation, Mud trail enchant, Spirit growing wisp, Dark cloak,
Earth wall, Lava reactive plate, Blood pact, and Lightning Tesla all activate
in dungeons. Ship/orb targets are mapped to the controlled creature or party.

## 9. Roadmap

### §9.0 Interaction Refit v2 + hint/popup cleanup

**STATUS 2026-08-10 — steps 1, 2, 5 DONE and step 4's architecture DONE, all
on branches, none merged to master:**
- `feature/v2-interaction-refit` (`642c508`) — ladder retired, all 13 sites
  converted, tests rewritten.
- `feature/dungeon-hint-channels` (`9eec907`) — the 4-channel resolver,
  control feedback on buttons, progress readout.
- `integration/dungeon-v2` (`06b69a7`) — both merged (no conflicts) plus a
  follow-up fix. **`flutter analyze` clean; 248 dungeon/raid tests green**
  (up from 231). NOTE: ~12–16 failures in `cosmic_balance` /
  `economy_balance` / `cosmic_survival_balance` are PRE-EXISTING on master —
  verified independently, unrelated to this work.
- STILL OPEN here: step 3 (seal-remembers chips) and the step-4 PROSE pass
  (36 ambient lines, 9 solution leaks, 3 stat-nag edges, popup chrome).

Original scope, in build order:

1. **`planet_dungeon_verbs.dart` rewrite:** retire `InteractionQuality` /
   `allowWrongFamily`; new requirement shape + result enum per §5. Update
   `evaluateInteraction` call sites in the engine + all six part files
   (~20 `InteractionQuality.` references across 4 files).
2. **Convert all 13 sites** in the §4 verified inventory: 10 → element-only
   (delete the timers, wisp spawns and half-holds), 3 → hard family gates
   (Air conduit A, Earth rib, Water pipe-mouth — the last is already a clean
   check and only needs the stamp). **Do not trust `evaluateInteraction`
   call sites alone** — 5 of the 13 are hardcoded `ability ==` checks that
   bypass the framework (rows 9–13). Preserve every player-agnostic
   consequence (Earth's defend-wave, Fire's burn-ramp) and split Water's
   entangled moon-pool branch (row 5) so the recipe keeps its downside while
   off-family Ice loses its penalty.
3. **"The seal remembers"** — SCOPED 2026-08-10, plumbing verified, no new
   storage needed:
   - Gates ride the existing one-time discovery channel: `_discoverCloud`
     (`planet_dungeon_game.dart:1490`, idempotent `Set<String>.add`) →
     `onCloudDiscovered` → `_onCloudDiscovered`
     (`planet_dungeon_screen.dart:287`) → `PlanetStarState` under the
     `cosmic_planet_stars` prefs key that the overworld already reads.
     Precedent for a silent non-reward id already exists (`rune:entry_door`).
     Id form `gate:<element>_<family>` (e.g. `gate:earth_horn`) — MUST avoid
     `,` `=` `.` `|`, which are `PlanetStarState`'s separators
     (`cosmic_data.dart:1817`). Add a layout test asserting that.
   - Declare gates in data: `DungeonFamilyGate {objectId, element, family,
     hintLine}` + `familyGates` on `DungeonLayout` (beside `riddle`), so the
     UI can name a gate without importing engine internals.
   - Stamp at the refusal: a new `_stampFamilyGate(gate)` beside
     `_discoverCloud` fires the §5.6 BLOCKED line and the one-time discovery.
   - Chip row: `_buildDescentPlacard` (`cosmic_screen.dart:6273`), inserted
     between the riddle card and the action buttons (~line 6469). Renders
     **unconditionally** and does NOT vanish at 3 stars (unlike the riddle) —
     it is permanent by design. No family art exists in the app; use a text
     badge from `FamilyColors` (`lib/utils/color_util.dart:3`) + the element
     dot from `elementColor`, matching the "⚡ HORN" example.
   - Screen adds a third `gate:`-prefix branch in `_onCloudDiscovered`:
     acknowledgement toast, **no gold**.
   - **SAVE-COMPAT RULING (decided 2026-08-10):** auto-stamp a planet's gates
     only when it is **fully cleared (all 3 stars)** at load. Rationale: a
     solved puzzle short-circuits before the interaction check
     (`_tryRib`'s `hasStar(star)` early return, `_earth.dart:449`), so a
     veteran can never re-trigger the stamp in-world and would otherwise
     carry a permanently emptier panel than a new player — and there is
     nothing left to spoil on a planet they have finished. Partial clears do
     NOT auto-stamp: those gates are still live content to discover.
   - First commit = the full vertical slice on ONE planet (Earth's rib:
     smallest blast radius), proving channel + stamp + chip end-to-end.
4. **Hint/popup pass to the §5.6 standard** — AUDITED 2026-08-10; bigger
   than it looked, and it needs an architecture change before any line is
   rewritten:
   - **There is no channel concept in the code at all.** `hintText` /
     `_hintTtl` (`planet_dungeon_game.dart:780`) is ONE flat string that
     `_setHint` (`:945`) overwrites unconditionally — no source, no
     priority, no memory. ~120 of the 265 call sites have zero gating; the
     only cross-source guard in the entire system is
     `_updateEnvironmentalHints`'s self-check (`:1417`). Whichever `_update*`
     runs last in a frame wins the capsule. The render side
     (`planet_dungeon_screen.dart:540`) is equally channel-blind — every
     string gets the same amber pill.
     → **Build the resolver first**: tag every emission with a channel,
     resolve by priority (BLOCKED > insight > OBJECTIVE > AMBIENT), give
     BLOCKED attempt-edged once-per-attempt memory, and protect insight
     output from interruption.
   - **Move state out of the capsule** (~80 calls): progress counters → the
     persistent readout; "Ability cooling down" → the button. Do this
     BEFORE re-channelling prose, since it removes ~30% of the traffic.
   - **Rewrite the 9 solution leaks** in the objective channel (worst:
     `planet_dungeon_game.dart:6356` Air twin-conduit,
     `_lightning.dart:1008` Storm Spire) — goal stays, method moves behind
     Mask insight.
   - **De-mechanize all 36 ambient lines** (`_updateEnvironmentalHints` +
     the 5 per-planet delegates) — flavor only.
   - **Fix the 3 continuous stat nags** (`:1392`, `:1410`, `:1439`) to fire
     on the failure moment.
   - **The 5 family-naming lines** (`game.dart:3786`, `_fire.dart:640`,
     `_lightning.dart:155,805`, `_steam.dart:579`) all sit on
     `InteractionQuality` success branches that step 2 deletes — do step 2
     first and they disappear with it.
   - **Chrome the 3 unchromed popup occasions** + give the guardian intro a
     real one; consider the death overlay too.
5. **Tests** — BLAST RADIUS MAPPED 2026-08-10, and it is small. The bar is
   **231 green** across 14 dungeon/raid files.
   - **Only 10 tests must be rewritten.** Six are the ladder tests
     themselves (`planet_dungeon_verbs_test.dart:47-95`); the other four are
     one "off-family penalty" test each in the Fire (`:312`), Water (`:317`),
     Earth (`:290`) and Lightning (`:274`) full-run files. Note Earth's
     converts in the OPPOSITE direction from the rest — it becomes a hard
     gate, not element-only. Air and Steam have no such test.
   - **~185 tests are invariant guards that must keep passing untouched** —
     all of `planet_dungeon_layout_test.dart` (123), plus gating, scaling,
     reward-popup and both raid files (the guardian model is unchanged in
     v2). **Riskiest to break by accident:** the door-reciprocity /
     no-gap-spawn / star-3-is-guardian checks (`layout_test.dart:341-459`)
     run over every planet via `kPlanetDungeonLayouts.forEach`, so one
     data-shape slip fails six times and reads like an interaction bug when
     it is really a layout regression. Suspect layout first.
   - **~36 full-run/combat tests are incidentally coupled but need NO edits
     to compile** — they drive only the game's public surface. Their risk is
     behavioural drift during the §9.1 redesigns, not §9.0.
   - **Copy this precedent:** Water's pipe-mouth hard-Pip gate is already
     v2-shaped (clean refusal, no middle tier) at
     `planet_dungeon_water_full_run_test.dart:230-234`.
   - **Best template for re-authoring a planet's run test:**
     `planet_dungeon_steam_full_run_test.dart` — no ladder debt, and split
     into 11 focused per-mechanic tests instead of one monolith.
   - **Fixture debt (fix opportunistically):** there is no shared test
     harness — the `_member`/`_companion`/`_step` pattern is copy-pasted in
     8+ files. `planet_dungeon_combat_test.dart:16-97` is the fullest copy
     and the one the raid test mirrors; consolidate there if touching it.
   - ADD per-planet: "hard gate refuses the wrong family and stamps the
     chip" + "element-only object treats every family identically".

Scope note: §9.0 items 1/3/4 are global; the per-planet v2 conversion
(item 2) is done immediately for Steam + Earth (no redesign — conversion
only), while Air/Fire/Water/Lightning bundle their conversion into their
§9.1 rework pass so each planet (and its tests) is touched exactly once.

### §9.1 Puzzle-depth reworks — one pass per planet, after §9.0

The 2026-08-10 design review (benchmarks: Zelda / Baba Is You / Mario 64)
ranked the built six: Earth and Steam stand; Air, Fire, Water-S2 and
Lightning get depth reworks, specced in full in their §6 REWORK blocks.
Each pass = v2 interaction conversion + the redesign + guardian retrofit
(§7 principle) + test rewrite. Order (cheapest big win first):

1. ✅ **Lightning** — zero-sum dynamo, dark dead segments, vault re-hide,
   negative-constraint threading w/ solver-checked uniqueness, Raikuma
   feeds-on-power retrofit (§6.3 REWORK — BUILT 2026-08-10, the template
   for the remaining three passes).
2. ✅ **Water** — S2 spin/flow-graph deduction (12 carved channels, 6 routes,
   every one solver-proved unique from its spins alone and rolled per run),
   re-cut insight tiers, sluice + wade counters into `DungeonProgressReadout`,
   Leviathan tide-turn retrofit (§6.4 REWORK — BUILT 2026-08-11).
3. ✅ **Fire** — S1 forensic rite rolled per run (three partial evidence
   channels, solver-guaranteed unique, Mask-optional), S3 nave/cloister
   censer-route decision, Simurgh brazier-telegraph retrofit (§6.1 REWORK —
   BUILT 2026-08-11).
4. ✅ **Air** — S1 wake-the-winds (four permanent gales, one fall-free wake
   order, `strandable == 0` proved exhaustively), S3 storm-rod steering (the
   leader climbs one rank at a time; 21 of 1024 rankings route, flat and
   plateau fail everywhere), sky rings + `_tryStabilize` + the conduit decay
   timers retired, Roc cell-drag retrofit, Air's logic extracted to
   `planet_dungeon_game_air.dart` (§6.11 REWORK — BUILT 2026-08-11). Biggest
   pass; §9.1 is complete. DEVICE TUNING still owed on Air/Fire/Lightning/Steam.
5. **Kinesthetic verb pass** (any time after §9.0): Pip smallAccess
   becomes real movement — vent rat-run tunnels between rooms (squeeze
   animation, Pip-only shortcuts; retrofittable one per planet); Mane
   terrainTrail becomes an actual dash that lays its trail, not a
   stationary ACT press.

**§9.1 items 1–4 are DONE (2026-08-11).** New-planet building resumes now (the
kinesthetic pass can overlap). Next up: Dust or Mud or Lava — all three §6
entries are current (Lava/Dust re-authored 2026-08-10). The reworked six are
still owed a DEVICE PLAYTEST, Air most of all: it is the only planet whose feel
constants have never been touched on hardware.

### Milestones

1. ✅ **Framework:** `DungeonAbility` (7) + `DungeonInteractionRequirement`
   (+ `min*` stats) + quality eval + recipe table + `GuardianEncounterRequirement`.
   *(v1 — superseded by the §9.0 refit target in §5.)*
2. ✅ **Air polished** on the framework (quality-graded conduits, Airwing
   stabilize, Firemask read, Roc guardian calm/defeat, room hints).
3. ⏳ **Device tuning** — pending for Air, Fire, Lightning, Steam (timers,
   traversal feel, animation feel; Water + Earth device-tested good). Air's
   rework named every knob it depends on — see the §6 entry 11 list.
4. ✅ **Enemy/wisp spawning** — the shared "consequence" layer (storm wisps
   etc.) with floaty hover/dive AI, idle auto-attacks and down handling.
5. ✅ **Genericize the Air-hardcoded engine bits** — done (see §8): layouts
   declare titles, star specs (names/announcements/reveal doors), entrance
   reveal + finale doors, sealed-door copy, mercy shrine; minimap atlas and
   labels are per-element; guardian copy is per-mystic.
6. **Planets one at a time**, reusing the framework; each adds its signature
   mechanic. ✅ **Fire (Cinder Cathedral)** · ✅ **Water (Mirror-Tide
   Temple)** · ✅ **Earth (Buried Giant)** — the Nexus 4-relic gate is
   complete — · ✅ **Lightning (Storm Circuit)** · ✅ **Steam (Molten
   Labyrinth)**. NEXT (after §9.0 + the §9.1 reworks): Dust/Mud/Lava →
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
   strategic question, design a novel vault trick, AND claim fresh mechanic
   archetypes from the §5.5 ledger (a star's core mechanic may not repeat a
   claimed row; give it its own visual grammar). `gate → hub → three
   wings → vault → finale → heart` is retired as a default.**
   **AND (v2): declare the planet's 1–3 HARD FAMILY GATES in its §6 entry
   before building — which star, which object, which element+family;
   everything else is element-only at full power, and hints/popups follow
   §5.6 from day one.**
7. **Combat-core extraction (before the kin specials port / next ability
   batch):** the per-hit resolver layer exists as near-identical copies in
   survival and the dungeon (and open space has its own variant). Extract to
   `lib/games/shared/` like enemy_flight_steering, with per-mode adapters
   (heal target: orb vs creature; arena vs room clamp; particle sink; kill
   rewards). FIRST write characterization tests around survival's hit
   pipeline (it has no headless harness — the dungeon does) so the
   extraction can't silently change live behavior. This is what turns
   "identical today" into "identical by construction".
