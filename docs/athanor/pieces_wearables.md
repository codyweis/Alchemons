# Athanor pieces: wearables, dock sets and titles

The auras, the two costumes, the five dock sets and the five titles from
`docs/crucible/cosmetics_concepts.md`, wired into their live systems. Every
one is granted by `grantAthanorPiece` as it stands, and none is sold in the
shop. Batch ids are suggested as `black`, `white`, `yellow`, `red`, `still`
(the piece ids' prefixes); the on-screen names are English only.

| Batch | Piece id | Name | Kind | Rarity | grantRef | Description |
|---|---|---|---|---|---|---|
| The Black Work | `black.inkmaker` | Dark Fuser | `title` | common | `inkmaker` | A title for your profile: Dark Fuser. |
| The Black Work | `black.ink_bloom` | Ink Plume | `alchemyEffect` | rare | `alchemy.ink_bloom` | An alchemy effect: ink rises from the ground around an Alchemon and curls up in slow plumes. |
| The Black Work | `black.darklet_dock` | Darklet Dock | `dockSet` | rare | `darklet` | The dock's icons, drawn with the Darklet, whatever your division. |
| The Black Work | `black.peacock_tail` | Oil Slick | `alchemyEffect` | **capstone** | `alchemy.peacock_tail` | An alchemy effect: an Alchemon stands in a pool of black that shows every color, slowly marbling. |
| The White Work | `white.silversmith` | Light Fuser | `title` | common | `silversmith` | A title for your profile: Light Fuser. |
| The White Work | `white.quicksilver` | Quicksilver | `alchemyEffect` | rare | `alchemy.quicksilver` | An alchemy effect: an Alchemon stands in a pool of liquid silver, with beads of it rolling around. |
| The White Work | `white.spiritlet_dock` | Spiritlet Dock | `dockSet` | rare | `spiritlet` | The dock's icons, drawn with the Spiritlet, whatever your division. |
| The Yellow Work | `yellow.gilder` | The Collector | `title` | common | `gilder` | A title for your profile: The Collector. |
| The Yellow Work | `yellow.gold_leaf` | Gold Leaf | `alchemyEffect` | rare | `alchemy.gold_leaf` | An alchemy effect: flakes of gold leaf drift down around an Alchemon and settle at its feet. |
| The Yellow Work | `yellow.lightlet_dock` | Lightlet Dock | `dockSet` | rare | `lightlet` | The dock's icons, drawn with the Lightlet, whatever your division. |
| The Red Work | `red.ember_keeper` | The Unknown | `title` | common | `ember_keeper` | A title for your profile: The Unknown. |
| The Red Work | `red.cinnabar` | Cinnabar | `alchemyEffect` | rare | `alchemy.cinnabar` | An alchemy effect: red smoke and grains of cinnabar rise from the ground around an Alchemon. |
| The Red Work | `red.bloodlet_dock` | Bloodlet Dock | `dockSet` | rare | `bloodlet` | The dock's icons, drawn with the Bloodlet, whatever your division. |
| The Red Work | `red.red_king_crown` | Garnet Crown | `costume` | **capstone** | `alchemy.red_king_crown` | A costume: a crown of dark gold and garnets over a velvet cap. Worn in place of the party hat. |
| The Still-Room | `still.distiller` | The Alchemist | `title` | common | `distiller` | A title for your profile: The Alchemist. |
| The Still-Room | `still.crystalet_dock` | Crystalet Dock | `dockSet` | rare | `crystalet` | The dock's icons, drawn with the Crystalet, whatever your division. |
| The Still-Room | `still.brass_monocle` | Brass Monocle | `costume` | epic | `alchemy.brass_monocle` | A costume: a brass monocle on a chain of brass beads. Worn in place of the sunglasses. |

The two capstones (the Peacock's Tail, the Crown) are each batch's
`capstone`, never drawn; `AthanorRarity` has no capstone value, so the
snippet below gives them `epic`, which nothing reads. The other capstones
(Snow Globe, the Gilded Throne, the Great Alembic) are home decor, not here.

## Titles: the words chosen

The catalog's titles were the stage names in Latin, then plain trade words
(Inkmaker, Silversmith, Gilder, Ember Keeper, Distiller). The author picked
the names now in place (2026-10-11), each a name for the player:

- **The Black Work → Dark Fuser** (a fuser of the Dark element).
- **The White Work → Light Fuser** (a fuser of the Light element).
- **The Yellow Work → The Collector** (the gold batch: the case, the steps, the throne).
- **The Red Work → The Unknown**.
- **The Still-Room → The Alchemist** (the workshop's own).

The piece ids and grantRefs keep the first words (`black.inkmaker` /
`inkmaker` and so on): they are save keys, so a title already owned shows
its new name. "Black Worker", "White Worker", "Yellow Worker" and
"Red Worker" were passed over on purpose: a color word before a word for a
person reads as race ("Yellow" worst) or politics ("Red Worker"). Titles are
worn under the player's name, so they must not.

## Where each lives

- **Auras** (`alchemyEffect`): `InvKeys.alchemy*` items, `InvKeys.alchemyEffectFor`
  / `alchemyItemFor`, registry entries in `buildInventoryRegistry`, painter
  keys in `AlchemyEffectPaint` (`athanorKeys`, all with a front layer), one
  part each in `lib/widgets/fx/alchemy_effects/` (`ink_bloom.dart`,
  `peacock_tail.dart`, `quicksilver.dart`, `gold_leaf.dart`,
  `cinnabar.dart`). Applied, swapped and taken off with
  `applyAlchemyEffect` / `removeAlchemyEffect` like the shop's.
- **Costumes**: `FamilyCostume.crown` (tag `crown`) and `FamilyCostume.monocle`
  (tag `monocle`), `athanorOnly`, riding the party hat's and the
  sunglasses' fit tables. `FamilyCostume.exclusiveWith` pairs crown/hat and
  monocle/sunglasses: `WornCostumes.wear` takes the other off, and
  `wearCostume` returns it to the inventory. Painted by
  `lib/widgets/fx/red_king_crown.dart` and `brass_monocle.dart` through
  `CostumePaint.paintWorn` / `paintPreview`.
- **Dock sets**: five `DockSet`s with no faction (`athanorOnly`) in
  `kDockSets`; `DockSet.athanorSets`; owned by their `dock_set_owned_<id>`
  row like the rest. The profile's DOCK picker re-reads the rows
  (`FactionService.reloadDockSets`) so a drawn set shows and can be worn
  whatever the division. The Darklet stands in a faint violet light on the
  dock's closed tabs so it does not sink into the ink.
- **Titles**: `ProfileTitles` (`profile_titles_v1`); the words are the
  piece's name (`ProfileTitles.nameOf`).
- **Never sold**: `InvKeys.athanorOnlyItems` (checked in `ShopService.sells`),
  `athanorOnly` offers for the two costumes (name and art only), no dock
  offer for an Athanor set (`DockSet.byOffer` skips them).

## Snippet for `kAthanorBatches`

```dart
// The Black Work
AthanorPiece(id: 'black.inkmaker', name: 'Dark Fuser', description: 'A title for your profile: Dark Fuser.', kind: AthanorPieceKind.title, rarity: AthanorRarity.common, grantRef: 'inkmaker'),
AthanorPiece(id: 'black.ink_bloom', name: 'Ink Plume', description: 'An alchemy effect: ink rises from the ground around an Alchemon and curls up in slow plumes.', kind: AthanorPieceKind.alchemyEffect, rarity: AthanorRarity.rare, grantRef: InvKeys.alchemyInkBloom),
AthanorPiece(id: 'black.darklet_dock', name: 'Darklet Dock', description: "The dock's icons, drawn with the Darklet, whatever your division.", kind: AthanorPieceKind.dockSet, rarity: AthanorRarity.rare, grantRef: 'darklet'),
// capstone:
AthanorPiece(id: 'black.peacock_tail', name: "Oil Slick", description: 'An alchemy effect: an Alchemon stands in a pool of black that shows every color, slowly marbling.', kind: AthanorPieceKind.alchemyEffect, rarity: AthanorRarity.epic, grantRef: InvKeys.alchemyPeacockTail),

// The White Work
AthanorPiece(id: 'white.silversmith', name: 'Light Fuser', description: 'A title for your profile: Light Fuser.', kind: AthanorPieceKind.title, rarity: AthanorRarity.common, grantRef: 'silversmith'),
AthanorPiece(id: 'white.quicksilver', name: 'Quicksilver', description: 'An alchemy effect: an Alchemon stands in a pool of liquid silver, with beads of it rolling around.', kind: AthanorPieceKind.alchemyEffect, rarity: AthanorRarity.rare, grantRef: InvKeys.alchemyQuicksilver),
AthanorPiece(id: 'white.spiritlet_dock', name: 'Spiritlet Dock', description: "The dock's icons, drawn with the Spiritlet, whatever your division.", kind: AthanorPieceKind.dockSet, rarity: AthanorRarity.rare, grantRef: 'spiritlet'),

// The Yellow Work
AthanorPiece(id: 'yellow.gilder', name: 'The Collector', description: 'A title for your profile: The Collector.', kind: AthanorPieceKind.title, rarity: AthanorRarity.common, grantRef: 'gilder'),
AthanorPiece(id: 'yellow.gold_leaf', name: 'Gold Leaf', description: 'An alchemy effect: flakes of gold leaf drift down around an Alchemon and settle at its feet.', kind: AthanorPieceKind.alchemyEffect, rarity: AthanorRarity.rare, grantRef: InvKeys.alchemyGoldLeaf),
AthanorPiece(id: 'yellow.lightlet_dock', name: 'Lightlet Dock', description: "The dock's icons, drawn with the Lightlet, whatever your division.", kind: AthanorPieceKind.dockSet, rarity: AthanorRarity.rare, grantRef: 'lightlet'),

// The Red Work
AthanorPiece(id: 'red.ember_keeper', name: 'The Unknown', description: 'A title for your profile: The Unknown.', kind: AthanorPieceKind.title, rarity: AthanorRarity.common, grantRef: 'ember_keeper'),
AthanorPiece(id: 'red.cinnabar', name: 'Cinnabar', description: 'An alchemy effect: red smoke and grains of cinnabar rise from the ground around an Alchemon.', kind: AthanorPieceKind.alchemyEffect, rarity: AthanorRarity.rare, grantRef: InvKeys.alchemyCinnabar),
AthanorPiece(id: 'red.bloodlet_dock', name: 'Bloodlet Dock', description: "The dock's icons, drawn with the Bloodlet, whatever your division.", kind: AthanorPieceKind.dockSet, rarity: AthanorRarity.rare, grantRef: 'bloodlet'),
// capstone:
AthanorPiece(id: 'red.red_king_crown', name: 'Garnet Crown', description: 'A costume: a crown of dark gold and garnets over a velvet cap. Worn in place of the party hat.', kind: AthanorPieceKind.costume, rarity: AthanorRarity.epic, grantRef: InvKeys.alchemyRedKingCrown),

// The Still-Room
AthanorPiece(id: 'still.distiller', name: 'The Alchemist', description: 'A title for your profile: The Alchemist.', kind: AthanorPieceKind.title, rarity: AthanorRarity.common, grantRef: 'distiller'),
AthanorPiece(id: 'still.crystalet_dock', name: 'Crystalet Dock', description: "The dock's icons, drawn with the Crystalet, whatever your division.", kind: AthanorPieceKind.dockSet, rarity: AthanorRarity.rare, grantRef: 'crystalet'),
AthanorPiece(id: 'still.brass_monocle', name: 'Brass Monocle', description: 'A costume: a brass monocle on a chain of brass beads. Worn in place of the sunglasses.', kind: AthanorPieceKind.costume, rarity: AthanorRarity.epic, grantRef: InvKeys.alchemyBrassMonocle),
```

## Renders

In `docs/athanor/content/wearables/`:

- `aura_ink_bloom.png`, `aura_peacock_tail.png`, `aura_quicksilver.png`,
  `aura_gold_leaf.png`, `aura_cinnabar.png`: each aura on three or four
  species (dark, pale, its own colors) at four moments and at the party
  HUD's 48 px, then 16 frames at 1/30 s.
- `costumes.png`: the crown and the monocle worn on a Wing, a Pip, a Horn
  and a Let, frames 0–2, a close look, and in another color.
- `pieces.png`: every piece as the Athanor's tiles draw it.
- `dock_athanor.png`, `dock_athanor_big.png`: the five dock sets on the
  dock, one strip per open tab, then large.

```
ATHANOR_WEARABLES_OUT=docs/athanor/content/wearables flutter test -j 1 \
  test/athanor_wearables_preview_test.dart --tags preview
NAV_EMBLEMS_FACTIONS=athanor NAV_EMBLEMS_OUT=docs/athanor/content/wearables/dock_athanor.png \
  flutter test -j 1 test/nav_emblems_preview_test.dart --tags preview
```

Cost per frame (desktop JIT, recording only, both layers): Quicksilver 12
µs, Gold Leaf 16, Ink Plume 54, Cinnabar 57, the Peacock's Tail 75; the
crown 18 and the monocle 12 worn; a costume or dock tile 6–19. No blur, no
layer, at most 16 draws an effect layer (test/athanor_wearables_test.dart,
test/alchemy_effects_census_test.dart).

Ink Plume, Cinnabar and the Peacock's Tail move on a divergence-free curl
flow (`_Flow` in alchemy_effect_paint.dart, after `InkFlow`). Ink and smoke
lie along its streamlines from their sources (`_Spine`) and ride up them by
age, as soft overlapping puffs, so each plume or wisp is continuous; the
pool's film is marbled by it. Everything is a smooth function of the clock,
with nothing random from frame to frame.
