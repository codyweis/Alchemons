# Athanor pieces: home decor

Every home decor piece from `docs/crucible/cosmetics_concepts.md`, all five
batches, wired into the live decor system. Each is a `HomeDecor` entry in
`HomeDecor.athanor` (`lib/models/home_decor.dart`) with `athanorOnly: true`,
so the shop never makes an offer for it; it is owned as inventory
`home.<id>` like bought decor, and `grantAthanorPiece` gives 3 of a Curio
(`kAthanorCurioCopies`) and 1 of anything else. Batch ids follow
`pieces_wearables.md`: `black`, `white`, `yellow`, `red`, `still`.

| Batch | Piece id | Name | Kind | Rarity | grantRef | Description |
|---|---|---|---|---|---|---|
| The Black Work | `black.moth_lantern` | Moth Lantern | `homeDecor` | common | `moth_lantern` | A dim violet lamp on a crooked post. Moths settle on it at night. |
| The Black Work | `black.inkcap_cluster` | Ink Mushrooms | `homeDecor` | common | `inkcap_cluster` | Tall ink-cap mushrooms that drip ink, most of all at night. |
| The Black Work | `black.ash_brazier` | Ash Brazier | `homeDecor` | rare | `ash_brazier` | A low bowl of cold violet flame. Residents warm themselves at it and sleep beside it at night. |
| The Black Work | `black.nightbloom_bed` | Lily Bed | `homeDecor` | epic | `nightbloom_bed` | A bed of dark leaves ringed with black lilies that open at night. A resident sleeps among them. |
| The White Work | `white.moonstone_cairn` | Stone Stack | `homeDecor` | common | `moonstone_cairn` | Pale stones stacked by hand. They glow faintly at night. |
| The White Work | `white.salt_pillar` | Salt Pillar | `homeDecor` | common | `salt_pillar` | A column of salt crystal that catches the light. |
| The White Work | `white.moon_font` | Moon Basin | `homeDecor` | rare | `moon_font` | A silver basin that holds the moon at night. Residents come to drink. |
| The White Work | `white.snow_globe` | Snow Globe | `homeDecor` | **capstone** | `snow_globe` | A great glass globe of snow. A resident sits inside it; tap it and the snow swirls up. |
| The Yellow Work | `yellow.sundial` | Sundial | `homeDecor` | common | `sundial` | A brass sundial. Its shadow follows the time of day. |
| The Yellow Work | `yellow.honey_lamp` | Amber Lamp | `homeDecor` | common | `honey_lamp` | A lamp of amber glass with pollen drifting inside. |
| The Yellow Work | `yellow.storm_coil` | Spark Coil | `homeDecor` | rare | `storm_coil` | A tall brass coil that throws sparks. Residents hop beside it, Lightning ones most of all. |
| The Yellow Work | `yellow.gilded_throne` | Gold Throne | `homeDecor` | **capstone** | `gilded_throne` | A throne of brass and gold leaf. One resident sits on it; the others come to bow. |
| The Red Work | `red.glass_rose` | Glass Rose | `homeDecor` | common | `glass_rose` | Red glass roses that open at dusk and close at dawn. |
| The Red Work | `red.ember_bowl` | Ember Bowl | `homeDecor` | common | `ember_bowl` | A low bowl of embers that slowly glow brighter and dimmer. |
| The Red Work | `red.ember_nest` | Ember Nest | `homeDecor` | rare | `ember_nest` | A nest of dark glass twigs with embers between them. A resident sleeps in it at night. |
| The Red Work | `red.pomegranate_tree` | Pomegranate Tree | `homeDecor` | epic | `pomegranate_tree` | A small tree of dark glass with glowing fruit. Residents climb into it; flyers rest at its top. |
| The Still-Room | `still.herb_rack` | Herb Rack | `homeDecor` | common | `herb_rack` | Bundles of dried herbs hung from a frame. |
| The Still-Room | `still.retort_shelf` | Flask Shelf | `homeDecor` | common | `retort_shelf` | A shelf of glass flasks, each lit its own color. |
| The Still-Room | `still.alembic` | Alembic | `homeDecor` | rare | `alembic` | A glass still over a small flame. Residents come to look into it. |
| The Still-Room | `still.bell_jar` | Bell Jar | `homeDecor` | rare | `bell_jar` | A tall glass bell jar. A resident sits inside it. |
| The Still-Room | `still.music_box` | Music Box | `homeDecor` | epic | `music_box` | A brass music box. Residents hop to its tune. |
| The Still-Room | `still.great_alembic` | Great Still | `homeDecor` | **capstone** | `great_alembic` | A tall glass still. A resident steps in, comes apart into grains, and forms again at the far end. |

22 pieces: 10 Curios (common, 2 a batch), 9 Living pieces (rare and epic)
and 3 Wonders (the White, Yellow and Still-Room capstones). The capstones
go in each batch's `capstone`, never drawn; `AthanorRarity` has no
capstone value, so give them `epic` in the `AthanorPiece` (nothing reads
it). The Black Work's and the Red Work's capstones are worn pieces
(`pieces_wearables.md`).

| Tier | Ids | Stands per realm |
|---|---|---|
| Curio | moth_lantern, inkcap_cluster, moonstone_cairn, salt_pillar, sundial, honey_lamp, glass_rose, ember_bowl, herb_rack, retort_shelf | 3 (a draw gives 3) |
| Living | ash_brazier, nightbloom_bed, moon_font, storm_coil, ember_nest, pomegranate_tree, alembic, bell_jar, music_box | 1 |
| Wonder | snow_globe, gilded_throne, great_alembic | 1 |

## What the residents do with them (`home_life.dart` `_visits`)

| Piece | Visit | Stirred hardest by |
|---|---|---|
| Curios | none: only to look at (tapped, they stir and sound) | — |
| Ash Brazier | `warm`: stands by it; by night sleeps beside it | Dark, Poison |
| Lily Bed | `climb` + `bed`: by night sleeps in the hollow among the lilies | Dark, Poison, Spirit |
| Moon Basin | `bow`: drinks | Water, Ice |
| Snow Globe | `climb` + `bed`: sits on the drift inside; by night sleeps there; a tap shakes the snow up | Ice, Water, Spirit |
| Spark Coil | `hop` on a 0.9 s beat; arcs to the ground when stirred | Lightning |
| Gold Throne | `perform` with `court`: the first sits on it still, turning to each side; the others take the places either side of the dais and bow to it again and again | Light |
| Ember Nest | `climb` + `bed`: by night sleeps in it, the near wall over its feet | Fire, Lava |
| Pomegranate Tree | `climb` onto one of two branches; flyers also perch at its top (`_perchFlight`) | Plant, Blood |
| Alembic | `bow`, standing beyond the stove or the flask | Water, Steam, Fire |
| Bell Jar | `climb`: sits on the cushion under the glass | Crystal |
| Music Box | `hop` on a 0.6 s beat, standing clear of the box; the drum turns faster and plucks the comb | — |
| Great Still | `distil` (new): steps up to its mouth, comes apart into its own grains (read from its sprite on the way there), they pour in, rise up the neck, run down the copper coil and spill out at the far end, where it gathers again and walks home. 11.6 s. Arranging mid-way brings it back whole. | Water, Steam, Fire |

## Sound

Mapped onto the existing home cues in `SoundCue.forHomeThing` by material:
flame (brazier, ember bowl, ember nest), reeds (nightbloom, pomegranate,
herbs), spores (inkcaps), water (moon font), spark (storm coil), steam (both
alembics), stone (cairn, sundial, throne), glass (the rest). The Music Box
uses the glass chimes for now; it has no cue of its own (see the report).

## Renders

`ATHANOR_DECOR_OUT=docs/athanor/content/decor flutter test -j 1 test/athanor_decor_preview_test.dart --tags preview`
writes one sheet per piece (day, night, in use), `great_alembic_passage.png`
(a resident carried through, progress 0 → 1), `tray_tiles.png` (as the
Arrange tray shows them) and prints a frame's cost of each.
