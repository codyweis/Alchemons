# Sealed Elemental Caches & The First Crossing

Two cosmic-space features. This file is canonical for both.

---

## 1. Sealed Elemental Caches

Abstract alchemical constructs drifting in open space. Each is bound to one
element, sits inert until a companion of that element stands beside it, and
pays out when the seal gives.

### Layout

* **One cache per element — 17 live at once** (`kElementColors` keys).
* Generated in `ElementalCacheField.generate` from a seed derived from the
  world's first planet position, so the layout is stable for a given cosmos.
* Placement keeps ≥ 1600 units clear of every planet and ≥ 2600 units clear of
  every other cache.
* The field is built lazily (`late final` on `CosmicGame`) so the screen can
  restore saved state without racing `onLoad`.

### Visibility

| Surface | Rule |
| --- | --- |
| World render | Drawn whenever on screen. |
| Radar (`CosmicMiniMapCircle`) | Shown whenever in radar range — no discovery needed. |
| Full chart (`CosmicMiniMapOverlay`) | Only after `discovered`, then pinned for good. **Not** a travel destination — you fly back yourself. |

`discovered` flips once the ship comes within `discoverRadius` (260) and is
persisted.

### The seal

Each cache renders a dormant alchemical seal: an outer ring, a counter-rotating
tick ring, a hexagram, and an element-tinted core. The name and riddle
(`FIRE CACHE` / `needs a burning flame`) are drawn only for the cache the ship
is actually parked at, so text layout costs at most one `TextPainter` per frame.

Riddles live in `kCacheHints` — one per element, e.g. Fire *a burning flame*,
Crystal *a singing lattice*, Dark *an unlit hour*.

### Opening one

1. Fly within `interactRadius` (300). The prompt appears, reading
   `<ELEMENT> CACHE — SEALED / It needs <hint>`. The riddle is all the player
   gets — never spell out the mechanic ("summon a Fire Alchemon"); the hint has
   to carry it.
2. Summon a party Alchemon whose **primary type** matches the cache element.
   The prompt polls `cacheAttunementReady` ~5×/sec and arms itself
   (`BREAK THE <ELEMENT> SEAL`) once the companion is within `attuneRadius`
   (460).
3. Tap again. A **three-second** element-specific unsealing plays: the
   companion orbits the seal feeding it, element energy streams inward, the
   seal's six arcs tear loose, and the cache blooms open.
4. The payout card appears (engine paused while it is up).

No stamina cost. Only one cache can be unsealing at a time. Proximity is
ignored entirely while the ship is in the nexus pocket or a ring battle.

### Payout (`ElementalCacheReward.roll`)

| Reward | Amount |
| --- | --- |
| Gold | 1–5 |
| Alchemical powerup orbs | 1–5 total, spread across Velocity / Insight / Forge / Radiance |
| Stamina Elixirs | 1–5 |
| Stabilized Harvester | 1 (always) |
| Instant Fusion Extractor | 20% chance of 1 |

### Respawn

Cracking a cache sets `respawnTimer = 600s` (10 minutes). When it fires, that
element's cache re-rolls to a fresh position and forgets it was ever seen.

### Persistence

`cosmic_elemental_caches_v1` in `SharedPreferences`, written on discovery, on
respawn, on open, and in the periodic save. Malformed or unknown entries are
skipped rather than fatal, and restore never leaves a cache mid-unseal.

### The 17 unsealings

Each element breaks its seal its own way. All live in
`lib/games/cosmic/cosmic_cache_vfx.dart` as plain paint functions — no game
state — so they can be rendered to a contact sheet for review:

```bash
CACHE_VFX_OUT=/tmp flutter test test/cache_vfx_contact_sheet_test.dart
```

(The test skips unless `CACHE_VFX_OUT` is set.)

| Element | Motif |
| --- | --- |
| Fire | Twelve flame tongues engulf the seal; embers ride the updraft |
| Lava | The seal melts — molten strands sag and drip, fissures glow through |
| Lightning | Arcs crawl the rim, then one bolt splits it top to bottom |
| Water | A vortex winds up and washes the seal away in rings |
| Ice | Frost crystals with barbs grow over it, then it shatters into shards |
| Steam | Pressure jets vent from the seams into a whiteout |
| Earth | Four stone plates grind apart, dust puffing from the gap |
| Mud | The seal tips, sinks into a bubbling mire, rings spread over it |
| Dust | It erodes grain by grain into a spiralling drift |
| Crystal | A lattice grows and resonates, then the facets fly apart |
| Air | Gusts sweep across on chevrons; the seal is blown into tumbling arcs |
| Plant | Vines coil around and pry it open into a bloom |
| Poison | Corrosive bubbles eat holes through it |
| Spirit | Comet-tailed wisps orbit and pull it out of phase |
| Dark | A void swallows it, then collapses inward |
| Light | A prism splits a beam; dawn breaks the seal |
| Blood | A two-thump cardiac rhythm; veins spread and tear it open |

---

## 2. The First Crossing (cosmic prologue)

A one-time cinematic, played the first time a player ever enters cosmic space,
**before** the existing exploration tutorial (`_maybeRunCosmicIntro`).

### Flow

1. **Drifting** — space blooms open. A **Stabilized Harvester**
   (`assets/images/ui/universalharvest.png`) hangs bobbing in the middle inside
   three nested alchemical rings. Tap to retrieve it (`+1` to inventory).
2. **Warping** — a two-second **hyperspace jump** carries you to the gates.
   Stars smear into radial streaks away from centre, speed builds on an
   ease-in-quart, light gathers at the tunnel mouth, then it drops back out. The
   instrument layer and the particle drift both wash out for the duration.
   Envelope lives in `_warpAmount`; the smear itself is `TrippyCosmosPainter`'s
   `warp` parameter.
3. **Choosing** — four **portals** tear open on a staggered reveal: Fire, Water,
   Earth, Air. Each is three logarithmic-spiral accretion arms winding into a
   dark event horizon, with doppler brightening on the arm sweeping toward the
   viewer, a hot rim arc travelling the edge, rings falling down the throat, and
   matter falling in on tailed arcs. Element-tinted and lifted 22% toward white
   so muddy elements still read against near-black. They spin fast while tearing
   open and settle into a lazy turn.

   **No names, no icons — the colour is the whole label**, and there is no
   instruction line. Do not add one back.

   Each arm is stroked with a `SweepGradient` keyed to its own angular span so
   it fades up from nothing and back into nothing; a flat alpha reads as a hard
   line switching on. Note the gradient uses `startAngle: 0, endAngle: span`
   with `GradientRotation(phase)` — setting `startAngle` to `phase` *as well*
   rotates it twice and slides the ramp clean off the path.
4. **Entering** — the tapped gate rushes up and swallows the screen
   (`_PortalTakeoverPainter`). It grows from that portal's real on-screen
   position (captured per-gate `GlobalKey`), drifts toward centre, spins up
   hard, and closes to black from progress 0.45 so you fall into the event
   horizon rather than into a flat wash of the element colour. The creature is
   built during this, so the encounter is ready on arrival.
5. **Encounter** — the chosen element calls a **prismatic Let** of that element
   out of the dark: `mutationFamily == 'let'`, falling back to any non-Mystic
   creature of the element if that element has no Let. Caught with the harvester
   just found.

   `shapeCrossingLet` stamps the authored identity on top of whatever the wild
   generator rolled:

   | | |
   | --- | --- |
   | Stats | **2.5** speed / intelligence / strength / beauty |
   | Potentials | **3.8** on all four |
   | Pigment | `tinting` forced to `normal` |
   | Skin | prismatic |

   The pigment override matters: fresh genetics can land on pale, vibrant, warm,
   cool or albino, and the prismatic sheen should sit on true colours rather
   than on a washed-out or hue-shifted body. Only the `tinting` track is
   touched — size and everything else stay as rolled.

   Both survive the catch: `createWildCapturePayload` carries `genetics`
   verbatim and honours fixed stats through its `hasFixedStats` branch, so what
   hatches is what `shapeCrossingLet` set. Locked by
   `test/cosmic_prologue_let_test.dart`.
6. Pops back; the normal cosmic tutorial takes over.

### The sky

Three layers, bottom to top:

1. **`TrippyCosmosPainter`** — the open-world cosmic sky first: same
   `0xFF020010` ground, same dense field of small white twinkling stars on the
   same size and brightness distribution. Over it an abstract layer, deliberately
   faint: orrery rings, a slowly turning bearing scale of tick marks, hairline
   chords between star pairs that surface and vanish, and a low-alpha colour
   drift. A minority of stars surface into a **desaturated** tint and sink back.
2. **`AlchemicalParticleBackground`** — the shop's own particle system, reused
   as-is with a colder palette (`_cosmosParticleColors`) at 1.35 density. This
   is what makes the field read as mystical and particley rather than as a flat
   star chart; keep the two vibes aligned.
3. The phase content (harvester / portals / encounter).

The rule for this screen: colour is a tint on a white star, never a coloured
dot; the abstract layer should read as instrument-grade and slightly unreal.
Anything that reads as a rainbow is wrong.

The encounter shares all of it — and because `surge` is 1.0 by then, the whole
field carries a wash in the element the player chose.

### Two things that must not regress

**The clock must be monotonic.** `_cosmos` is a `Ticker`-driven
`ValueNotifier<double>` holding elapsed seconds × 0.5. It was a repeating
`AnimationController`, whose value snapped from 1 back to 0 every cycle — every
rotation and phase derived from it jumped with it, which is what "the animations
aren't fluid" was. Never drive these painters from anything that wraps.

**No `MaskFilter.blur` in a per-frame painter here.** Every glow in
`TrippyCosmosPainter` and `ElementPortalPainter` is a `RadialGradient` shader
(`_falloff` / `_glow`). Blurs at these radii, full-screen and four-up at 60fps,
were the other half of the judder.

### No exit

The crossing is mandatory. `PopScope(canPop: false)` blocks system back,
`fullscreenDialog: true` kills the iOS swipe, and the encounter is given
`showMapAction: false` — that Map button *is* the run action in
`EncounterOverlay`, so hiding it removes the only way out.

The encounter also passes `showRarityBadge: false` — the Let's rarity is an
authored detail, not news to announce over the creature.

**The one escape hatch**: the exit is only hidden when the Stabilized Harvester
grant actually succeeded (`_harvesterGranted`). Without a capture device there
is no way to finish the encounter, so a failed grant hands the exit back rather
than trapping the player. Do not simplify this to a constant `false`.

### Gating

`cosmic_prologue_completed_v1`. Existing saves are **not** retro-fitted: if
`cosmic_intro_prompted_v1`, `cosmic_intro_completed_v1`, or a home planet
already exists, the prologue is marked spent without playing.

The harvester grant is wrapped so a failed write costs an item, never the
crossing — the four lights unfurl either way.

### Replaying it (developer tool)

With developer tools on (`DebugSettingsService.toolsVisible` — the persisted
switch, or any debug build), the cosmic **ship settings** overlay grows a
DEVELOPER section with **REPLAY: THE FIRST CROSSING**. It runs the real flow
regardless of whether this save already spent it, so each replay genuinely
grants another Stabilized Harvester and another catchable prismatic Let.

### Files

* `lib/screens/cosmic/cosmic_prologue_screen.dart` — the screen
* `lib/screens/cosmic/widgets/trippy_cosmos_painter.dart` — the deep field
* `lib/screens/cosmic/widgets/element_portal_painter.dart` — the four gateways

Both painters are plain `CustomPainter`s taking no app state, so either can be
rendered to a PNG on a bare canvas for review.


---

## 3. Cosmic HUD layout rules

A layout review turned up four real occlusions. These are the rules that keep
them fixed.

### The top HUD is a constant height

94 for the recipe strip, 120 for the side rails — plain constants, no
conditional offsets.

That is only true because the raid moved **out** of the HUD. It used to band a
full-width strip in above the meter, which made the card ~40pt taller whenever a
raid was live, and every fixed offset below it (planet column, map rail,
companion rail) was wrong by exactly that much — the raid strip landed
underneath them. It is now `_raidBadge()`, a 116pt badge parked under the
mini-map radar at `mapColumnTop + (radar height) + 10`, where it costs the
layout nothing.

The badge clears whichever map affordance is showing — the 44pt button or the
84pt pinned radar — and hides with `_topHudCollapsed` along with the rest of the
HUD chrome.

**Do not put the raid back in the HUD card.** Anything that changes the HUD's
height reintroduces a class of layout bug that took a render sweep to find.

### One meter, always the same size

The alchemical meter lives in the top HUD and **never moves or resizes**.

It used to be hidden from the HUD whenever the planet column was up
(`showMeter: !recipeHudVisible`) and re-drawn as a second, separately animated
bar inside that column. Approaching a planet therefore read as the meter
jumping and shrinking. The duplicate is gone, along with its `_planetMeterCtrl`
animation; `showMeter` is now unconditionally `true`.

Consequence to remember: the HUD is ~88pt tall at all times now (128 with the
raid band), not the ~54pt it used to be when the meter was hidden. That is why
the planet column starts at 96, not 76.

Measured clearances (880×420 landscape):

| | HUD bottom | column top | map rail top |
| --- | --- | --- | --- |
| plain | 88 | — | 120 |
| raid | 128 | — | 160 |
| planet | 88 | 96 | 120 |
| planet + raid | 128 | 136 | 160 |

### The side rails only ever clear the top HUD

An older layout pushed the map and companion rails *down* by a hard-coded 240
to clear a full-width recipe card. That number was already wrong, and on a
landscape phone it threw the map rail clean off the bottom of the screen. With
the card gone there is nothing to clear but the HUD itself. Do not reintroduce a
"push the rails below the recipe" offset.

### The recipe lives on the meter, not in a card

There is no unseal card. There was a 218pt centred one; it sat over the play
area the entire time the ship was at a gate. It is gone, and
`planet_recipe_hud.dart` was deleted with it.

What replaced it:

1. **The meter carries the targets.** `_RecipeTargetPainter` in `top_hud.dart`
   draws the recipe's target percentages as notches on the meter fill — a
   hairline at each cumulative boundary with an element-tinted cap. A segment
   stopping short of its notch is under-filled; one running past is over.
   Matching the recipe is now "line your colours up with the marks".
2. **`PlanetRecipeStrip`** — a single 26pt band under the HUD carrying what the
   notches cannot say: planet name, targets in words, match %, pin, and the
   UNSEAL button (which only exists once the gate can actually be opened).
3. **Full detail** is the meter-tap breakdown sheet, which already existed.

**218pt → 26pt.** Do not grow the strip back into a card.

#### The alignment invariant

The notches are only meaningful if they are drawn in the same order as the fill.
Both go through one pair of functions —`meterSegmentsInDrawOrder` and
`recipeTargetsInDrawOrder`, both descending by amount — and
`test/cosmic_meter_recipe_alignment_test.dart` pins them together for every
generated recipe. Change one ordering and that test fails.

#### The bar is composition, not capacity

The meter fill is drawn as fractions of what you are *carrying*, so it always
spans the full bar. The notches are absolute composition targets
(`cumulative / 100`). Consequences, all deliberate and covered by tests:

* Right proportions but a quarter-full meter still lands on the notches.
* A perfect match is the named targets **plus** the recipe's `randomPct`
  allowance. Carrying only the named components leaves you short of 100, which
  shifts every boundary — that is honest feedback ("you are over on Fire"), not
  a drawing bug. This one bit me: the first version of the alignment test
  asserted the wrong thing.

### `bottom: 100` is a contended slot

Seven prompts share it: market POI, rift portal, contest arena, blood ring,
battle ring, elemental nexus, and the sealed cache. They are mutually excluded
by hand. **Any new prompt in this slot must exclude the others**, and the cache
— the newest arrival — yields to all of them.

Belt and braces: `ElementalCacheField.generate` also takes a `landmarks` list
(nexus, rings, prismatic field, rift portals, contest arenas) and keeps caches
2000 units clear of them, so the two prompts rarely co-occur in the first place.

### Raid surfaces

Two, and they should read as one feature:

* **Space view** — `_raidBadge()` under the radar.
* **In-dungeon** — `_raidChip()` in `planet_dungeon_screen.dart`.

Both use the same chrome (hard edges, `DungeonBracketPainter` corners, a 3pt
ember rail, `RAID · <PLANET>` and the countdown, ember when under an hour
remains) and both name the **planet**, never the element. Raid copy elsewhere —
the beacon quote, the debug summon quote, the victory popup header — goes
through `planetName()` too.

### The home base panel

`HomePlanetMenuOverlay` fills the screen in three bands:

* **Top dock** — identity only: planet orb, `HOME BASE`, size class. Bottom edge
  tinted with the planet's colour.
* **Middle** — the only scrolling part, grouped by **where the thing actually
  lives**:

  | Section | Holds |
  | --- | --- |
  | `SHIP HOLD` | Astral shards carried (n/cap, ember when full), fuel, cargo tier. Everything here is at risk if the ship dies — that is why it is separate. |
  | `BASE VAULT` | Astral banked, garrison stationed/slots, and the element store (all of it, not the first twelve). |
  | `STAR DUST` | Its own hunt — n/50 with a progress bar. Neither carried nor banked. |
  | `WALLET` | Account-wide gold / silver / shards. |
* **Bottom dock** — CUSTOMIZE / GARRISON side by side, CLOSE stacked
  underneath so leaving never competes with doing.

It used to be a 360pt centred card that scrolled identity, mix, storage,
actions and close as one column, so on a landscape phone the actions were
usually below the fold. What the player came to look at and what they came to
press are now both always on screen.

**The deposit readout is gone on purpose.** The panel used to report an
"N ELEMENTS DEPOSITED" total and a colour-mix bar built from
`HomePlanet.colorMix`. That mix no longer drives anything — `blendedColor`
returns `kElementColors[activeColor]` or a default grey and never reads
`colorMix` — so the panel was reporting a number with no consequences. Don't
put it back without making the mix mean something again.

**The two kinds of "shards" are labelled apart.** `wallet_soft` is the
game-wide currency the shop calls *Shards* and it sits in `WALLET`;
`ShipWallet.shards` and `HomePlanet.astralBank` are *astral* shards and sit in
`SHIP HOLD` / `BASE VAULT` as ASTRAL and ASTRAL BANKED. The grouping now carries
most of that distinction, but SHARDS and ASTRAL still share the diamond icon —
worth splitting if it reads ambiguously in play.

**Two layout traps this hit**, both in the colour-mix bar, both worth knowing
because the bar renders as *nothing* rather than as something wrong:

1. A `Row` of `Expanded` children has no intrinsic width. Inside a `Column`
   handing out loose horizontal constraints it collapses — the bar needs an
   explicit `width: double.infinity`.
2. A `Row` centres on its cross axis by default, so a childless `ColoredBox`
   gets **zero height**. The segments size correctly and paint nothing. It
   needs `crossAxisAlignment: CrossAxisAlignment.stretch` — the same fix the
   top HUD meter already carries.

### The ship console

`ShipMenuOverlay` uses the same shape as the home base panel: full-screen, the
console header docked at the top, SYSTEMS / EQUIPMENT / SUPPLIES scrolling in
the middle, and the actions docked at the bottom.

It was a 360×680 centred plate that scrolled the sections *and* the actions
together, so on a landscape phone the actions sat below the fold — the same
problem the base panel had.

The bottom dock lays actions out in **rows**, not one stacked column:
BUILD HOME gets its own full-width primary row while no base exists, then
PARTY / INVENTORY / MOVE HOME share a row, with CLOSE beneath. Four full-width
buttons stacked ate half the screen and squeezed the systems readout.

Inventory items render with their real art via
`InventoryImageHelper.getVisualWidget` (powered by `ShopService` asset names);
the generic category glyph is only a fallback now.

### Moving the home planet asks first

`_handleMoveHomePlanet` spends 50 carried shards and lifts the base off the spot
the player chose, so it confirms through `LandscapeDialog` before doing either.
It re-checks the shard balance after the dialog closes — the dialog is open long
enough for the number to change.

### Element colours are not UI ink

`kElementColors` is tuned for planets against a starfield. Against the panel
chrome (`bg1`, near-black) several elements are unreadable:

| Element | Raw contrast | After `elementInk` |
| --- | --- | --- |
| Dark | **1.59:1** | 3.83:1 |
| Mud | **2.03:1** | 4.86:1 |
| Spirit | 2.75:1 | 5.67:1 |
| Earth | 2.88:1 | 5.95:1 |
| Poison | 2.99:1 | 5.51:1 |

Use `elementInk(element)` — not `elementColor` — for element-tinted text,
borders and chips on panel chrome. It lifts 32% toward white, which clears 3:1
for every element while staying recognisably the element's colour.
`test/cosmic_element_ink_test.dart` pins both halves of that: the contrast
floor, and a drift ceiling so a future "fix" can't just wash everything to
near-white and call it legible.

The in-world painters keep using raw `elementColor` — they sit on space, not on
chrome. (`ElementPortalPainter` does its own lift for the same reason.)

### Stale element keys in saves

Saves carry element keys from older builds — a real one in the wild is `Metal`.
`elementColor` renders anything unknown as flat grey, so it shows up looking
like a genuine resource. **Filter every storage listing through
`isKnownElement`.** Done in the customization lab's resources popup and the home
base vault. The source of `Metal` is not in current code, so this is defensive
rather than a root-cause fix.

### The customization lab remembers where you were

There are **two different teardowns** here, and they need different fixes.
Getting only one of them looks like a fix and is not.

**Teardown A — the recipe detail view.** The lab swaps its own body out
(`if (_detailRecipeId != null) return _buildDetailView(...)`). The State
survives; the PageView does not. A reattached `PageController` restores to its
`initialPage`, firing `onPageChanged(0)` and throwing the player back to SHIP.
Fixed by disposing the controller on the way back and rebuilding it with
`initialPage: _activeTab`.

**Teardown B — PREVIEW.** `_showCustomizationMenu = false` unmounts the whole
overlay, so the **State itself is destroyed** and any State-local tab memory
goes with it. Fixed by hoisting ownership: the cosmic screen holds `_labTab` and
passes it as `initialTab`, and the lab reports changes back through
`onTabChanged`.

**The scroll offset** survives both, because both tab `ListView`s carry a
`PageStorageKey` (`cosmic.lab.ship` / `cosmic.lab.home`) and the route's storage
bucket outlives the widget.

`test/cosmic_lab_tab_persistence_test.dart` drives the real widget through a
full PREVIEW → END PREVIEW round trip and asserts the rebuilt overlay comes back
on the tab it left on.

### Preview on planet

Once the lab changes something visible on the home planet — size tier, colour —
`_homePreviewDirty` flips and a **PREVIEW ON PLANET** button appears at the top
of the panel, above the tabs. It hides the lab (`_previewingHome`) so the planet
is actually visible, and an **END PREVIEW** button in the world brings the lab
back — on the same tab, at the same scroll offset, thanks to the two fixes
above.

`_previewingHome` counts toward `_anyOverlayOpen`, which is what clears the HUD
for a clean look at the planet; the END PREVIEW button opts itself back in
explicitly.

### Back is always docked

Every full-screen cosmic panel puts its exit in the same place: a bottom dock.
Home base, ship console, customization lab, and the party/garrison picker all
carry one. In the picker, BACK means "up one level" — it steps out of slot
assignment before it closes the panel.

### Checking layout changes

The honest way to check occlusion is to render it. Build a throwaway
`testWidgets` harness that mounts the real `TopHud` and `PlanetRecipeHud` in a
`Stack` at the same offsets the screen uses, capture it through a
`RepaintBoundary.toImage`, and look at the PNG for each combination
(plain / raid / planet / planet+raid). Text renders as Ahem boxes — that is
fine, the point is the geometry. Keep the harness out of the repo; it mirrors
layout constants and would rot.
