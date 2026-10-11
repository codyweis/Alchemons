# The Athanor: cosmetics catalog (concepts)

Content design for **the Athanor**, the alchemist's furnace. A player pours
**tincture** (earned) or gold into it and draws a random cosmetic from a
themed batch. Each batch has 10 pieces, drawn without replacement, so every
pour gives something new and the rarer pieces tend to come later. Finishing
a batch grants its **capstone**, which is found nowhere else. The odds for
the next pour are shown before every pour.

Everything here is **cosmetic only**. Nothing changes power, odds, drops or
the economy, because gold pours make this a paid draw. For the same reason
this catalog has **no survival orb skins** (each changes orb HP and has
passives) and **no ship hulls** (no grant API, and the cosmic screen
overwrites that state).

Status: concepts plus **10 working prototypes**, drawn in the game's
material. They live in `lib/widgets/fx/crucible/` and nothing is wired in:
none are in a live catalog, in `ShopService`, or ownable. Their concept
sheets are in `docs/crucible/concepts/` (see the end of this doc for how to
re-render them).

---

## How a batch is built

The five batches follow the four stages of the alchemists' **Great Work**,
plus the workshop itself:

| # | Batch | Look | Elements it leans on |
|---|---|---|---|
| 1 | **Nigredo**: the Black Work | black glass, ink, violet night light, oil-slick sheen | Dark, Poison, Mud, Spirit |
| 2 | **Albedo**: the White Work | quicksilver, pearl, frost, moonlight | Ice, Water, Spirit |
| 3 | **Citrinitas**: the Yellow Work | gold leaf, pale brass, honey glass, sunlight | Light, Lightning, Dust |
| 4 | **Rubedo**: the Red Work | garnet, cinnabar, ember, vermilion | Blood, Fire, Lava |
| 5 | **The Still-Room** | ink and brass, clear glass: the alchemist's workshop | (none; the workshop) |

Every batch has the same shape, so players learn what a batch holds and can
see how close they are to its capstone:

| Slot | Count | What fills it |
|---|---|---|
| Common | 5 | a profile title, a specimen-case style, a sigil finish, two Curios (small home decor) |
| Rare | 3 | an alchemy effect (aura), a Living decor piece residents use, a dock set |
| Epic | 2 | a showpiece: a bed or tree residents use, a trail, a costume or a home ambience |
| Capstone | 1 | the batch's biggest piece, granted when all 10 are drawn |

That gives **50 drawn pieces and 5 capstones**. Only **2 costumes** are in
the whole catalog (one capstone, one epic), and neither needs new fit data:
see the costumes under "Prototypes".

**Odds** (a suggestion for the system side): weight each piece by rarity
(common 6, rare 3, epic 1) and draw without replacement. The first pour of a
batch is then about 73% common, 22% rare and 5% epic, and the epics drift
later naturally. No pity rule is needed, because 10 pours always finish a
batch.

**Effort** key: **S** means an entry plus art in a kind that already exists
(under half a day). **M** means a day or two, or a small new system. **L**
means new behaviour, or several systems at once.

"New:" in the Kind column means the piece needs a system that doesn't exist
yet. Those systems are listed further down.

---

## 1 · Nigredo, the Black Work

| Piece | Kind → plugs into | What it is (card line) | Drawn as | Alchemons | Rarity | Effort | Why chase it |
|---|---|---|---|---|---|---|---|
| Nigredo | New: profile title | A title for your profile: "Nigredo". | text | none | common | S | the batch's mark |
| **Obsidian Case** ★ | New: case style | A black glass case with a sheen of oil-slick colors across it. | dark arch, one faint diagonal band in five oil colors | shows your specimen | common | S | dresses your collection |
| Ink Sigil | New: sigil finish | The fusion and cultivation sign drawn in black ink with a violet edge. | the octagram {8/3} in ink, lit edge | seen at every fusion | common | S–M | seen constantly |
| Moth Lantern | Home decor, Curio | A dim violet lamp on a crooked post. Moths settle on it at night. | obsidian post, glass lamp, moth grains landing and lifting (not orbiting) | look only | common | S | makes night at home alive |
| Inkcap Cluster | Home decor, Curio | Tall ink-cap mushrooms that drip ink at night. | dark glass caps, ink grains dripping into small pools that fade | look only | common | S | a Nigredo corner of the home |
| Ink Bloom | Alchemy effect | Ink rises off the ground at its feet and curls up in slow plumes. | filled tapering plumes (`vfxRibbon`) with violet-lit edges, a few grains; never a dark blob | aura | rare | S–M | a dark creature's aura |
| Ash Brazier | Home decor, Living | A low obsidian bowl of cold violet flame. Residents warm themselves and sleep beside it. | the torch kit's `_flame` in ink-violet with a lilac rim | `warm` verb, Dark/Poison stir it | rare | S | creatures sleep by it |
| Darklet Dock | Dock set | The dock drawn with Darklet. | `DockSet` → LET15 (art exists) | Darklet | rare | S | a dock outside your faction |
| **Nightbloom Bed** ★ | Home decor, Living (bed) | A bed of dark leaves ringed with black lilies. At night they open, and a resident sleeps among them. | dark glass leaves; lily cups on one drawVertices, violet hearts, pollen grains | `climb` + `bed`, by night | epic | M | your creature asleep in flowers |
| Peat Mist | New: home ambience | Low violet mist drifts across any home realm at night. | soft ground-hugging puffs (radial pools), parted where residents walk | residents part it | epic | M | changes the whole home at night |
| **The Peacock's Tail** ★ | Alchemy effect (**capstone**) | Its creature stands in a pool of black whose surface shows every color, slowly marbling. | one mesh, colored per vertex from a marbling field; bright bands on black; beads of color rising | aura | capstone | S | the rare flex; between the black work and the white |

## 2 · Albedo, the White Work

| Piece | Kind → plugs into | What it is (card line) | Drawn as | Alchemons | Rarity | Effort | Why chase it |
|---|---|---|---|---|---|---|---|
| Albedo | New: profile title | A title for your profile: "Albedo". | text | none | common | S | the batch's mark |
| **Frost Case** ★ | New: case style | A case with frost grown in from its corners and cold light above. | rime grains densest in the corners, short crystal feathers, a cold top light | shows your specimen | common | S | dresses your collection |
| Silver Sigil | New: sigil finish | The fusion and cultivation sign in polished silver. | octagram in a silver gradient | at every fusion | common | S–M | seen constantly |
| Moonstone Cairn | Home decor, Curio | Pale stones stacked by hand. They glow faintly at night. | stacked rounded stones, inner light pooling at night | look only | common | S | a quiet night piece |
| Salt Pillar | Home decor, Curio | A column of salt crystal that catches the light. | geode-style `CutStone` facets in pale rose-white | look only | common | S | glints by day |
| **Quicksilver** ★ | Alchemy effect | It stands in a pool of liquid silver, beads of it rolling all around. | lobed mirror puddles (sky above a hard horizon), metal beads rolling in and merging, drops lifting and falling back | aura | rare | S | the material reads at once |
| Moon Font | Home decor, Living | A silver basin that holds the moon at night. Residents come to drink. | stone basin, mirrored water showing the moon's glint at night | `bow` verb, Water/Ice | rare | S | a night ritual at home |
| Spiritlet Dock | Dock set | The dock drawn with Spiritlet. | `DockSet` → LET14 | Spiritlet | rare | S | a dock outside your faction |
| **Hoarfrost Steps** ★ | New: trail | Frost blooms on the ground where it walks, then melts. | rime patch, fine grains and lopsided fern fronds per footfall; grows, holds, melts | follows its own steps at home | epic | M | everyone sees it walking around |
| Moonlit Snowfall | New: home ambience | Fine snow falls on clear nights in any home realm. | sparse soft grains, slow fall; no weather message | none | epic | M | winter in any realm |
| **Snow Globe** ★ | Home decor, Wonder (**capstone**) | A great glass globe of snow. A resident sits inside it; tap it and the snow swirls up and settles. | baked plinth and back glass; snow grains split behind and in front of the sitter; near glass in `front()` | `climb` + `bed`; a tap (stir) shakes it | capstone | M | your favourite creature in a snow globe |

## 3 · Citrinitas, the Yellow Work

| Piece | Kind → plugs into | What it is (card line) | Drawn as | Alchemons | Rarity | Effort | Why chase it |
|---|---|---|---|---|---|---|---|
| Citrinitas | New: profile title | A title for your profile: "Citrinitas". | text | none | common | S | the batch's mark |
| **Gilt Case** ★ | New: case style | A case backed with gold leaf, lit by a lamp above. | one continuous gold sheet, leaves faintly told apart, creases catching the lamp | shows your specimen | common | S | dresses your best specimen |
| Gilt Sigil | New: sigil finish | The fusion and cultivation sign in gold leaf. | octagram in gold, with a moving glint | at every fusion | common | S–M | seen constantly |
| Sundial | Home decor, Curio | A brass sundial whose shadow follows the time of day. | brass gnomon on a stone dial; its shadow is a filled wedge that moves with the phone's clock | look only | common | S (+ `hour` in KeepsakeTime) | it really tells the time |
| Honey Lamp | Home decor, Curio | A lamp of amber glass with pollen drifting slowly inside. | glass lamp, warm grains drifting | look only | common | S | warm light at home |
| **Gold Leaf** ★ | Alchemy effect | Flakes of gold leaf drift down around it, flashing as they turn, and settle at its feet. | creased two-tone foil quads on one drawVertices; flash grains; a warm pool where they land | aura | rare | S | bright and expensive-looking |
| Storm Coil | Home decor, Living | A tall brass coil that gathers sparks. Lightning residents hop as it arcs. | brass coil; arcs drawn as lightning (lit core over faint glow, the one place lines are allowed) | `hop` verb with a beat, Lightning | rare | S–M | Lightning creatures play with it |
| Lightlet Dock | Dock set | The dock drawn with Lightlet. | `DockSet` → LET16 | Lightlet | rare | S | a dock outside your faction |
| Gilt Steps | New: trail | Gold dust lifts where it walks and settles in small glints. | the trail system again: kicked grains plus glints that fade | follows its steps | epic | S (once the trail system exists) | a golden walk |
| Sun Motes | New: home ambience | Warm dust drifts in the daylight in any home realm. | sparse warm grains with short trails; no rays | none | epic | M | golden-hour home |
| **The Gilded Throne** | Home decor, Wonder (**capstone**) | A throne of brass and gold leaf. One resident holds court on it and the others come to bow. | stepped dais and a tall gilt back; gold leaf lit from above | reuses `perform` (the sitter) and `watch` (the others; a bow pose) | capstone | M | crown your best creature at home |

## 4 · Rubedo, the Red Work

| Piece | Kind → plugs into | What it is (card line) | Drawn as | Alchemons | Rarity | Effort | Why chase it |
|---|---|---|---|---|---|---|---|
| Rubedo | New: profile title | A title for your profile: "Rubedo". | text | none | common | S | the batch's mark |
| **Garnet Case** ★ | New: case style | A case of deep garnet glass, lit from below. | dark red arch, three broad facets catching a red light from below | shows your specimen | common | S | dresses your collection |
| Garnet Sigil | New: sigil finish | The fusion and cultivation sign in garnet glass. | octagram in red glass | at every fusion | common | S–M | seen constantly |
| Glass Rose | Home decor, Curio | Red glass roses that open at dusk and close at dawn. | glass petals opening with `night` | look only | common | S | changes with the hour |
| Ember Bowl | Home decor, Curio | A low bowl of embers that slowly glow brighter and dimmer. | obsidian bowl, ember grains breathing | look only | common | S | warm light at home |
| Cinnabar | Alchemy effect | Vermilion smoke curls up from the ground around it. | filled smoke ribbons and cinnabar grains rising, lit warm at their edges | aura | rare | S–M | a red creature's aura |
| Ember Nest | Home decor, Living (bed) | A nest of dark glass twigs with embers between them. Fire residents sleep in it. | the nest kit in obsidian; embers that brighten with the sleeper's breath | `climb` + `bed`, Fire/Lava | rare | S | creatures sleep in it |
| Bloodlet Dock | Dock set | The dock drawn with Bloodlet. | `DockSet` → LET17 | Bloodlet | rare | S | a dock outside your faction |
| Pomegranate Tree | Home decor, Living | A small tree of dark glass with glowing garnet fruit. Residents climb into it. | bark kit, glass leaves, garnet orbs as fruit | `climb`, Plant/Blood | epic | M | creatures in a tree |
| Ember Fall | New: home ambience | Embers drift up from the ground at dusk in any home realm. | sparse rising grains with trails, dying out as they climb | none | epic | M | dusk at home turns red |
| **Crown of the Red King** ★ | Costume (**capstone**) | A crown of dark gold and garnets over a cap of garnet velvet. | gold band and garnet-tipped spikes lit from the upper left, a velvet dome, glinting grains | worn; rides the party hat's fits | capstone | M | the biggest flex, worn everywhere |

## 5 · The Still-Room

| Piece | Kind → plugs into | What it is (card line) | Drawn as | Alchemons | Rarity | Effort | Why chase it |
|---|---|---|---|---|---|---|---|
| Distiller | New: profile title | A title for your profile: "Distiller". | text | none | common | S | the batch's mark |
| **Brass Case** ★ | New: case style | A case with a brass instrument plate behind it and a lamp above. | brushed brass plate, four rivet domes, a lamp pool | shows your specimen | common | S | dresses your collection |
| Brass Sigil | New: sigil finish | The fusion and cultivation sign in engraved brass. | octagram in brass | at every fusion | common | S–M | seen constantly |
| Herb Rack | Home decor, Curio | Bundles of dried herbs hung from a frame, swaying a little. | obsidian frame, bundles as filled shapes, gentle sway | look only | common | S | a workshop corner |
| Retort Shelf | Home decor, Curio | A shelf of glass flasks, each lit its own color and bubbling slowly. | the alembic's glass on a stone shelf | look only | common | S | colorful glass by night |
| **Alembic** ★ | Home decor, Living | A glass still over a small flame. It simmers, and its drops fill a flask. | glass vessels holding light; vapour grains climbing the neck; drops running down the beak | `bow` verb; Water/Steam/Fire stir it to a hard boil | rare | S | proper alchemy in your home |
| Bell Jar | Home decor, Living | A tall glass bell jar. A resident sits inside it. | glass from the alembic kit, sitter in `front()` | `climb` | rare | S–M | a specimen-under-glass look |
| Crystalet Dock | Dock set | The dock drawn with Crystalet. | `DockSet` → LET11 | Crystalet | rare | S | a dock outside your faction |
| **Brass Monocle** ★ | Costume | A round brass monocle on a chain of brass beads. | filled brass rim, faintly warm glass, a sheen gliding across, a bead chain | worn; rides the sunglasses' fits | epic | S–M | dapper on any creature |
| Music Box | Home decor, Living | A brass music box. Residents hop to its tune. | brass drum and comb; the drum turns; one new sound cue | `hop` verb with a beat | epic | M (with the sound) | a home with a tune |
| **The Great Alembic** | Home decor, Wonder (**capstone**) | A tall glass still. A resident steps into it, comes apart into its own grains, rises through the coil and gathers again at the far end. | the alembic, much larger; the resident read into grains with `FieldEssence` / `readGrains`, carried through the coil, and re-formed | new visit: dissolve, carry, re-form | capstone | L | the wow piece: alchemy on your own creature |

★ = prototyped (see "Prototypes").

---

## What players chase

1. **Things worn on the creature, everywhere it goes.** Auras and costumes
   show in the specimen grid, party, wild, home and space. One purchase is
   visible a hundred times. These carry the batch, so every batch has an
   aura, and two capstones are worn pieces (the Peacock's Tail, the Crown).
2. **A creature doing something.** Players screenshot their creature asleep
   in flowers, sitting in a snow globe, on a throne, or turned into grains
   by the Great Alembic. Pieces that residents *use* (through the existing
   `_visits` verbs) beat pieces that only stand there. That is why Living
   and Wonder pieces fill the rare, epic and capstone slots, and Curios stay
   common.
3. **Seen constantly.** The fusion sigil, the specimen cases and the dock
   are on screen every session, so a finish there keeps reminding a player
   what they own, even at common rarity.
4. **A set that looks like a set.** Each batch has one palette and material,
   so pieces worn and placed together look deliberate: a creature in the
   Crown and Cinnabar, beside an Ember Nest, in a Garnet Case. Set
   completion is the stated goal, and the capstone rewards it.
5. **Rarity you can show.** Capstones come from nowhere else. They are big
   and obvious: an aura, a crown, a Wonder.
6. **What players don't chase.** Text-only titles and small still props are
   low-want on their own. Here they are cheap commons that fill a batch, so
   pours always land on something, but nothing important rests on them.

## Build first (best want per effort)

| # | Piece | Batch | Kind | Effort | Why first |
|---|---|---|---|---|---|
| 1 | **Gold Leaf** ★ | Citrinitas | aura | S | high want; a painter part plus an item |
| 2 | **Quicksilver** ★ | Albedo | aura | S | same, and the material reads at once |
| 3 | **The Peacock's Tail** ★ | Nigredo (capstone) | aura | S | a capstone that costs no more than an aura |
| 4 | **Snow Globe** ★ | Albedo (capstone) | Wonder | M | the most screenshot-able; reuses `climb` + `bed` |
| 5 | **Crown of the Red King** ★ | Rubedo (capstone) | costume | M | the archetypal flex; no new fit data |
| 6 | **Alembic** ★ | Still-Room | Living | S | alchemy at home; reuses `bow` |
| 7 | **Nightbloom Bed** ★ | Nigredo | Living | S–M | sleeping creature; reuses `climb` + `bed` |
| 8 | Dock sets ×5 | all | dock | S | near free: the five unused Lets |
| 9 | **Brass Monocle** ★ | Still-Room | costume | S–M | cute on every family; no new fit data |
| 10 | **Case styles ×5** ★ | all | case | M (system) + S each | one small system fills five common slots |
| 11 | **Hoarfrost Steps** ★ | Albedo | trail | M (system) | new, very visible; Gilt Steps then comes cheap |
| 12 | Profile titles ×5 | all | title | S (system) | trivial, and fills five common slots |
| 13 | The Gilded Throne | Citrinitas (capstone) | Wonder | M | reuses `perform` and `watch` |

With 1–13 plus the Curios (S each), all five batches are fillable without
the ambience, sigil-finish or Great Alembic work. Those can come in a later
version and be swapped into the matching common and epic slots.

---

## New systems the catalog needs

| System | What it needs | Storage | Effort |
|---|---|---|---|
| **Profile titles** | a list of titles; an owned set; one worn title shown under the name on the profile (and wherever else the name appears) | Settings `titles_owned_v1` (JSON list), `title_worn_v1` | S |
| **Specimen-case styles** | which case each specimen stands in; `SpecimenCase` picks `AthanorCasePainter` when one is set; a picker in the details screen beside the effect | Settings `case_styles_v1` JSON {instanceId: style} (no schema bump) | M |
| **Trails** | a per-creature trail; home life steps it every ~0.55 sizes walked, alternating feet; painted on the ground layer under residents (home first, then the wild field) | Settings `trails_v1` JSON {instanceId: trailId} | M |
| **Sigil finishes** | one global finish read where the octagram is painted (`fusion_burst.dart` `fusionSigilLines`, the cultivation sphere, the harvest binding); it re-tints the lines' material only | Settings `sigil_finish_v1` | S–M |
| **Home ambience** | one ambience per home layout; drawn as a layer over the field in showcase mode; one-tenth of a field's draw budget; never announces itself | a field in `HomeBiomeLayout` JSON (no schema bump) | M |
| **Athanor-only decor** | `HomeDecor` entries with no price and a flag. `ShopService` builds offers with `offersForDecor(HomeDecor.all)`, so an unflagged entry goes on sale; filter on the flag there. Owned = the same `home.<id>` inventory count | inventory `home.<id>` | S |
| **Faction-free dock sets** | `DockSet.faction` nullable (or an `athanor` flag). `ShopService` generates a 150g offer for every non-free set in `kDockSets`, so it must skip these. `companions` for an Athanor set = the other Athanor Lets owned | Settings `dock_set_owned_<id>` (exists) | S |

Left out on purpose: **orb looks** (survival only, and a look-only overlay
would need its own system: not worth it for v1), **hulls** (no grant API),
**more costumes** (per-species fit tables are the most expensive kind), and
anything that touches genetics, variants or stats.

---

## Prototypes

All in `lib/widgets/fx/crucible/`, one library (`athanor_art.dart`) with
parts. `athanor_kit.dart` holds copies of the keepsake kit's private helpers
(`_plinth`, `_shaft`, `_block`, `_glass`, `_flame`, `_groundPool`) and the
effects' soft-light kit (`_pool`, an `_Atlas` of soft grains, and `_Tris`
for many coloured triangles in one `drawVertices`). They are copies, so no
live file was touched.

Measured cost per frame (desktop JIT, recording only, printed by the
preview test): every piece runs **12–75 µs**. There are
**no blurs** (no `MaskFilter`, no `blurRadius`), no hoops and no outline
strokes. Still parts are baked once by `KeepsakeArt`.

| Prototype | File · API | How to wire it |
|---|---|---|
| Gold Leaf, Quicksilver, The Peacock's Tail | `athanor_aura_art.dart` · `AthanorAuraPaint.paint(canvas, key, center, r, t, {element, opacity, dark, front})` (same as `AlchemyEffectPaint.paint`); keys `gold_leaf`, `quicksilver`, `peacock_tail`; all `hasFront` | Move each class into `alchemy_effects/` as a `part` (swap my `_Atlas` for the effects' one; note theirs takes `additive:`). Add the key to `AlchemyEffectPaint.keys`, `hasFront` and the `paint` switch, and an `InvKeys.alchemy*` item. Grant it from the Athanor; never add a shop offer. |
| Snow Globe, Alembic, Nightbloom Bed | `athanor_decor_art.dart` · `AthanorDecorArt.of(id)` returns `KeepsakeArt` subclasses (`SnowGlobeArt`, `AlembicArt`, `NightbloomBedArt`) with `box`, `body`, `under`, `live`, `seats`, `front` | In `KeepsakeArt.of`, try `_decorArt(id, style) ?? AthanorDecorArt.of(id, style) ?? _keepsakeArt(...)`. Add an Athanor-only `HomeDecor` entry (see above) and a `_visits` entry. The visit for each is in its doc comment: globe `climb` + `bed`, alembic `bow`, bed `climb` + `bed`. Globe and bed have a `front()`. |
| Crown of the Red King | `athanor_costume_art.dart` · `RedKingCrown.paint(canvas, base, width, t, {opacity, tilt, color})` (the party hat's signature), `paintPreview`, `presets` | Add a `FamilyCostume` value whose `placements`, `frameFits` and `tilts` return `partyHat`'s tables (no new fit data). Paint it in `CostumePaint.paintWorn`/`paintPreview`. Decide whether it replaces the hat: they share the head, so wearing both should be exclusive. |
| Brass Monocle | same file · `BrassMonocle.paint(canvas, eyes, eyeToEye, t, {opacity, tilt, view})` (the sunglasses' signature) | A `FamilyCostume` value borrowing `sunglasses`' tables and `GlassesView.of(species)`. Make it exclusive with the sunglasses (both sit on the eyes). |
| Hoarfrost Steps | `athanor_trail_art.dart` · `FrostSteps()..step(x, y, time, size:)` then `paint(canvas, time)` | The trails system above. One `FrostSteps` per resident wearing one, in home life. |
| Case styles ×5 | `athanor_case_art.dart` · `AthanorCasePainter(style: AthanorCase.gilt, color: caseElementLight(species))`, a `CustomPainter` in `CaseLightPainter`'s place (static, so it repaints only on change) | The case-styles system above. In `SpecimenCase`, choose this painter when the specimen has a style. |

One tidy-up when a piece moves into its live library: a few prototypes
still build small paths each frame (Quicksilver's puddles, the Nightbloom's
stems, the crown's band). They are cheap at these counts, but the effects
kit aims for no per-frame allocation, so cache them as unit paths there.

### Concept sheets (`docs/crucible/concepts/`)

- `auras.png`: the three auras at four moments at details size, then four
  at party-HUD size (48 px).
- `costumes.png`: the crown and the monocle on Firewing, Waterpip,
  Earthhorn and Icelet, frames 0–2 plus a close look.
- `decor.png`: Snow Globe, Alembic and Nightbloom Bed by day, by night and
  stirred, each with a real resident at its seat or beside it, at field
  scale.
- `globe_shake.png`: the Snow Globe tapped, then settling over 6.5 s.
- `trail.png`: Icehorn walking with Hoarfrost Steps, at four moments.
- `cases.png`: the five case styles beside today's plain case, at
  Creatures-tab size.

Re-render with (one test process; it writes nothing without the env var):

```
CRUCIBLE_CONCEPTS_OUT=docs/crucible/concepts flutter test -j 1 \
  test/crucible_cosmetics_preview_test.dart --tags preview
```

### Notes from iterating on the renders

- Gold Leaf, first pass: matte square chips that read as brown confetti, and
  over a yellow creature as stains. Fixed with creased two-tone foil, a
  floor of old gold so a leaf turned away is still metal, a faint glow on
  every leaf, and the leaves kept to the flanks (the sprite covers the
  middle).
- Quicksilver, first pass: one flat dark disc read as a hockey puck or
  hoverboard. Mercury is recognised by its *beads*, so the beads now lead:
  a smaller lobed mirror (sky above a hard horizon), satellite puddles and
  sixteen rolling beads.
- The Peacock's Tail: a free hue wheel read as a rainbow. It now runs
  through five oil colors (violet, blue, teal, old gold, rose; no pure red
  or green) with black between the bands.
- Nightbloom Bed: open lilies as full radial fans read as star badges. They
  are now side-view cups of curved petals, near-black violet with lilac
  edges, each leaning its own way.
- Snow Globe: a shake that swept the flakes round one orbit drew a ring.
  Each flake now loops on its own through the whole globe.
- Frost Case: long thin fronds read as cobwebs. It now uses rime grains and
  short feathers. Gilt Case: separate leaves on dark read as cracked stone,
  so it is one gold sheet with the leaves only faintly told apart.

## For the author to decide

1. **Costume exclusivity**: the Crown shares the head with the party hat,
   and the Monocle shares the eyes with the sunglasses. Exclusive pairs (my
   suggestion), or allowed together?
2. **The Monocle as epic or capstone**: it needs no new fit data, so it is
   cheap enough for epic. Making it the Still-Room capstone (instead of the
   L-effort Great Alembic) would keep both costumes as capstones.
3. **Darklet Dock**: dark creatures vanish on the dark dock. Check it with
   `NAV_EMBLEMS_OUT`. If it disappears, give Nigredo a different rare
   (Ink Bloom stays, swap the dock for the Moth Lantern at rare, or similar).
4. **Per creature or global** for case styles and trails: I'd say per
   creature (dress your best specimen), stored as Settings JSON maps.
5. **How many of a Curio a draw gives**: each piece is drawn once, but the
   bought Curios stand up to 8 per realm. Should one draw grant 3, or just 1?
6. **Batch names on screen**: "Nigredo · The Black Work" (Latin, then plain
   English), or the English alone?
