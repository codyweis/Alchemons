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
| 8 | **Fire** S3 vesper gust — `_fire.dart:621` | Wing push 120–190; other Air 70–110 | element-only, use the Wing formula |
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
| **Ice** (built) | Vertical shaft: descending is one-way slides; ascending must be engineered | plan the descent so you can climb back — refrozen slides are your only ladder | visible only in a mirror; enterable only from a slide you can't repeat |
| **Dust** (built) | Buried city, two Z-layers: streets above, excavation below; digging swaps layers | conservation of dust — uncovering one thing buries another | a fully buried building visible only as a roof bump on the streets |
| Crystal | Rearranging 3×3 sliding grid — sliding moves rooms AND you | every slide solves one adjacency and breaks another | a room that only ENTERS the grid in one configuration |
| Plant | Nested scales: the same map at tiny and huge, overlaid | which scale to be, where — passages exist at one scale only | visible at huge scale, enterable only at tiny |
| **Poison** (built) | Quarantine wards: sealed wards; opening one lets the contagion in | you cannot cure every ward — choose what to sacrifice | inside the ward you chose NOT to save |
| Spirit | Two overlaid worlds: living/ghost layers, same geometry, different doors | which layer to cross each junction in — deaths in one open doors in the other | exists only in the ghost layer, marked only in the living one |
| Dark | Inverting maze: light/dark flips swap walls and doors | every flip you make for a door closes one elsewhere | the vault room only EXISTS in the dark state |
| Light | One great hall: no corridors — light beams partition the space into moving "rooms" | aiming light builds paths AND exposes you — illuminate as little as possible | stands in plain sight; reachable only through un-lit ground |
| Blood | Systole loop: a figure-eight of veins around the heart; surges circle it on the beat | move WITH the pulse or against it — timing is the map | reachable only in the flatline window between beats |

### Mechanic ledger — core star mechanics, claimed

Topology diversity (above) isn't enough on its own: the star PUZZLES must
also draw from different mechanic archetypes. A new star's CORE mechanic may
not repeat a ledger row — family/stat/consequence dressing does not count as
new. The ledger grows with every build:

| Claimed by | Core mechanics owned |
|---|---|
| **Air** | flow traversal (currents/updrafts) · set-collection constellation matching · **irreversible wind-authoring** (BUILT: gust shrines wake permanent gales that help AND hinder; the waking ORDER is the puzzle — CLAIMED: no other planet may hand the player a permanent world-edit whose ordering is the whole question) · **storm-steering by height-ranking** (BUILT: the bolt climbs one rank at a time, so the rod field must be a staircase) · **coherence composition** (BUILT 2026-08-14, the Gale Eye: a SET of irreversible edits that must agree with one another — no order, no sequence, just whether the four winds turn the same way) |
| **Fire** | sequence-execution / order-memory ritual under attack (CLAIMED — no other planet may hand a sequence to execute) · flame-relay escort between checkpoints · *(rework)* forensic-evidence deduction at the object itself (rolled per run) · **reagent transport / deposition planning** (BUILT 2026-08-14: a burn's PRODUCT travels downwind onto other beds, so the question is where a reaction lands, not what order you were told; distinct from Fire's own sequence row — nothing hands you an order, you author one from the wind and the cuts) |
| **Water** | global state machine (tide) that regates SPACE itself · **piloting a drifting object by editing the world state that carries it** (BUILT 2026-08-14: the lantern is never touched — you move the TIDE it floats on, and a dam only ever removes a destination; CLAIMED: no other planet may steer a thing it cannot touch) ~~flow-graph ordering deduced from spin~~ (RETIRED with the ghost gallery — it played as arbitrary, and the seat is free again for a later planet) |
| **Earth** | track-notch sokoban shoves · clue-hunt logic deduction (answers carved into REMOTE architecture, rolled per run — the treasure-hunt variant; Fire's forensic variant reads the object itself) |
| **Lightning** | beam routing/reflection via rotatable mirrors (+ *(rework)* negative constraints, provably unique) · element STATIONING pads · decoy-pad deduction · *(rework)* zero-sum power routing (power here = dark there) |
| **Steam** | global resource economy (spend/condense/stoke one shared budget) · sacrifice-the-whole-budget vault |
| **Poison** (BUILT 2026-08-24) | **diagnosis-by-behaviour** (a strain is identified by how it MOVES, not by a label or a clue — CLAIMED: no other planet may make observation-of-motion the read) · **forced partial sacrifice** (a budget that provably covers all but one target, so the question is which one you abandon — CLAIMED, and distinct from Steam's spend-it-all: here the shortfall is structural and the choice is named) |
| **Ice** (BUILT 2026-08-24) | **one-way descent with an engineered return** (traversal that consumes the route behind you; the ladder home is something you must have built on the way down — CLAIMED) · **treasure-or-ladder exclusivity** (each edit serves one of two purposes and you commit before you know which you need) · costly full-state reset valve as the anti-softlock (a pattern, not a claim — reusable) |
| **Lava** (BUILT 2026-08-24) | **production-line re-routing** (program a path, then spend a limited fungible charge down it; what the charge BECOMES is decided by where it went — CLAIMED) · **the dual-purpose product** (the thing you cast is both a road and a plug, so ordering falls out of physics rather than instruction — this is how Lava stays out of Fire's order-memory seat; any planet reusing it must derive the order, never hand it over) |
| **Mud** (BUILT 2026-08-24) | **terraforming-as-map-authoring** (the player authors the EDGES, not the rooms; the question is the SHAPE left behind — CLAIMED, and deliberately ORDER-INDEPENDENT: A-then-B lands on the same fen as B-then-A, pinned by a test, which is what keeps it out of Air's ordering seat) · **drainage as the cost function** (hardening a crossing drowns its neighbours up- and downstream, so you choose what to KEEP and the physics decides what dies — distinct from Poison's triage, where you choose what to abandon) |
| **Dust** (BUILT 2026-08-24) | **conservation as the cost function** (one object owns every write, and every mutator is a PAIRED TRANSFER — dig here, heap there, atomically, so the total cannot leak; CLAIMED: no other planet may make a conserved quantity the puzzle) · **Z-layer swap driven by load count** (0 bared = the street is a pit and the cellar opens · 1 = plain street · 2 drifted = a dune-wall, and a ramp opens instead — the layer you are on is a CONSEQUENCE of the ledger, not a toggle; Spirit's living/ghost layer swap is a different reading and stays free) · **the inverted vault verb** (the buried house is the one thing digging cannot reach — you bury it HARDER until the weight cracks the wall) |
| **Nexus** (reserved) | RULE MANIPULATION — transmutation circles rewriting element bindings (the Baba Is You seat; no planet may touch it) |

**Open archetype pool for the remaining 6** (match against the §6 matrix;
each planet claims patterns no ledger row owns): rhythm/timing windows
(Blood) · light-cone occlusion + exposure management (Light) · state-flip
maze inversion (Dark) · two-overlaid-worlds layer swap (Spirit — the
LIVING/GHOST reading only; Dust has taken the Z-layer/excavation reading) ·
scale shift tiny/huge (Plant) · self-rearranging map / sliding rooms
(Crystal).

~~one-way-descent route planning~~ (CLAIMED by Ice) ·
~~irreversible sacrifice choice~~ (CLAIMED by Poison — Mud must claim
terraforming-as-map-authoring instead, and must also differ from Air's
irreversible wind-authoring, whose ORDER is the question; Mud's question is
the resulting SHAPE) · ~~production-line re-routing + mold casting~~
(CLAIMED by Lava) · ~~terraforming as map-authoring~~ (CLAIMED by Mud — Dust
must claim CONSERVATION, the invariant that dust moved from here arrives
there, not shape-authoring; excavation and terraforming are close enough
neighbours that a cold author will reach for the wrong one) ·
~~conservation~~ (CLAIMED by Dust).

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

**THE POOL.** Coverage is the win: an ember pool at the garth's edge fills as
cells burn, and the star releases when it reaches the top. A short greedy
chain does not fill it — only a route that covers the room does. This is the
progress display, diegetic and analogue (§5.6 STATE, and the playtest
verdict on badges: "the beds should really glow… not number counter badges").

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
   wide gaps no single gust can clear, a fuse at 0.55× (~1.4s per feeding),
   3 unstable wisps per ignition. LONG — the calm cloister: 4 censers (two
   extra to keep alight), every gap crossed by ONE comfortable gust so the
   flame never has to survive a wait, full 2.6s fuse, 2 stable wisps. Both
   ring all three bells at brisk AND harried tending (test-proven both ways);
   the unlit run is sketched on the floor so the choice can be weighed before
   it is made. Simurgh §7 retrofit: it RE-LIGHTS the rite braziers as its
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
   Horn-clean channel — refit per §4 inventory). S1 (pylon_hall): thread ONE
   beam through all three terminals by rotating conductor mirrors
   (multi-target routing). S2 (cloud_works): storm-cells bared in the
   mirror_gallery, herded onto sockets; the anvil socket needs Fire heat
   (**Air+Fire→Lightning**) → Thundercloud. S3 Storm Spire: open arena,
   element STATIONING — park Air + Fire creatures on the right pads among
   decoy pads (deduction), flip the conductor mirrors, the converted beam
   renders as a jagged bolt and lights the Storm Tower → Raikuma (calm or
   defeat). Egg: Thunderbolt. Vault cache: capacitor_vault. Tests:
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
   verbs are load-bearing by proof, not by assertion. S3 (Deep Star), behind the mirror gate: at
   settled MID tide freeze the two TRUE moon-pools (Spirit insight names
   them) — Ice direct (Mane cleanest) or **Spirit+Water→Ice** (recipe rouses
   brine); false pools SHATTER + fury wisps; both bridged → Leviathan (calm
   or defeat). **LEVIATHAN TURNS THE TIDE** (§7 retrofit, 2026-08-11): the
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

### Mystic guardian roster (Star-3 boss + raid boss per planet)
Verified against `assets/data/alchemons_creatures.json`; spritesheets in
`assets/images/creatures/mystic/MYSxx_*_spritesheet.png` (verify each sheet's
frame count/size before adding to `_guardianSheets` + `kRaidGuardianIds`).

MYS01 Simurgh=Fire (built: 6×512² frames, 1 row) ·
MYS02 Leviathan=Water (built: 4×512² frames, 1 row) ·
MYS03 Terradon=Earth (built: 4×512² frames, 1 row) ·
MYS04 Roc=Air (built) · MYS05 Boilrog=Steam · MYS06 Magmara=Lava (built) ·
MYS07 Raikuma=Lightning · MYS08 Bogdrya=Mud (built) · MYS09 Frowyrm=Ice (built) ·
MYS10 Ashdjinn=Dust (built) · MYS11 Prismalith=Crystal · MYS12 Botanica=Plant ·
MYS13 Blightfang=Poison (built) · MYS14 Wraithord=Spirit · MYS15 Noctryos=Dark ·
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
5. **Lightning — Thunderbolt (BUILT):** light the Storm Tower with a
   Lightning HORN standing among the conductors (`egg:lightning_thunderbolt`,
   permanent tower glow). *"The thunderbolt steers all things."*
   (Heraclitus)
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
  Frowyrm eats your stairs as you fight it.
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
- ⬜ **§9.0 INTERACTION REFIT v2 + hint/popup cleanup** — convert all six
  built planets to the §4 element-first / hard-family-gate model, implement
  "the seal remembers" descent chips, apply the §5.6 hint standard, rewrite
  the slow-and-loud tests. NEXT UP before any new planet.
- ⬜ Device tuning pending: Air, Fire, Lightning, Steam, **Poison, Ice,
  Lava, Mud, Dust** (timings/feel — user playtest; Water + Earth already device-tested
  good). NONE of the 2026-08-24 three has ever been run on a device.
- ⬜ More Mystic guardian sprites for future planets (map in
  `_guardianSheets`, enroll in `kRaidGuardianIds`; roster in §6).
- ⬜ The other 6 planets' signature mechanics (+ their shaders).

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
