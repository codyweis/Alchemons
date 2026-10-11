// THE ATHANOR'S BATCHES — the five sets a pour draws from (2026-10-10).
//
// Each batch is ten drawn pieces (four common, three rare, three epic) and a
// capstone that comes with the last of them. The catalog behind them, and
// why each piece is what it is, is docs/crucible/cosmetics_concepts.md; the
// pieces' systems are listed in docs/athanor/pieces_*.md. Names on screen are
// English only (author's call).
//
// A capstone carries a rarity because every piece does; nothing reads it,
// since a capstone is never drawn.

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/models/inventory.dart';

const List<AthanorBatch> kAthanorBatches = [
  AthanorBatch(
    id: 'black',
    name: 'The Black Work',
    description: 'Black glass, ink and violet night light.',
    pieces: [
      AthanorPiece(
        id: 'black.inkmaker',
        name: 'Inkmaker',
        description: 'A title, shown on your profile.',
        kind: AthanorPieceKind.title,
        rarity: AthanorRarity.common,
        grantRef: 'inkmaker',
      ),
      AthanorPiece(
        id: 'black.obsidian_case',
        name: 'Obsidian Case',
        description:
            'A specimen case of black glass with a faint oil-slick sheen across it.',
        kind: AthanorPieceKind.caseStyle,
        rarity: AthanorRarity.common,
        grantRef: 'obsidian',
      ),
      AthanorPiece(
        id: 'black.ink_fusion',
        name: 'Ink Fusion',
        description:
            'Fusing runs the two together like ink in water, into a dark spiral that blooms.',
        kind: AthanorPieceKind.fusionStyle,
        rarity: AthanorRarity.epic,
        grantRef: 'ink',
      ),
      AthanorPiece(
        id: 'black.moth_lantern',
        name: 'Moth Lantern',
        description:
            'A dim violet lamp on a crooked post. Moths settle on it at night.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'moth_lantern',
      ),
      AthanorPiece(
        id: 'black.inkcap_cluster',
        name: 'Ink Mushrooms',
        description:
            'Tall ink-cap mushrooms that drip ink, most of all at night.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'inkcap_cluster',
      ),
      AthanorPiece(
        id: 'black.ink_bloom',
        name: 'Ink Plume',
        description:
            'Ink rises from the ground around an Alchemon and curls up in slow plumes.',
        kind: AthanorPieceKind.alchemyEffect,
        rarity: AthanorRarity.rare,
        grantRef: InvKeys.alchemyInkBloom,
      ),
      AthanorPiece(
        id: 'black.ash_brazier',
        name: 'Ash Brazier',
        description:
            'A low bowl of cold violet flame. Residents warm themselves at it and sleep beside it at night.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.rare,
        grantRef: 'ash_brazier',
      ),
      AthanorPiece(
        id: 'black.darklet_dock',
        name: 'Darklet Dock',
        description:
            'The dock\'s icons, drawn with the Darklet, whatever your division.',
        kind: AthanorPieceKind.dockSet,
        rarity: AthanorRarity.rare,
        grantRef: 'darklet',
      ),
      AthanorPiece(
        id: 'black.nightbloom_bed',
        name: 'Lily Bed',
        description:
            'A bed of dark leaves ringed with black lilies that open at night. A resident sleeps among them.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.epic,
        grantRef: 'nightbloom_bed',
      ),
      AthanorPiece(
        id: 'black.peat_mist',
        name: 'Night Mist',
        description:
            'Low violet mist drifts along the ground of a home realm at night.',
        kind: AthanorPieceKind.ambience,
        rarity: AthanorRarity.epic,
        grantRef: 'peat_mist',
      ),
    ],
    capstone: AthanorPiece(
      id: 'black.peacock_tail',
      name: 'Oil Slick',
      description:
          'An Alchemon stands in a pool of black that shows every color, slowly marbling.',
      kind: AthanorPieceKind.alchemyEffect,
      rarity: AthanorRarity.epic,
      grantRef: InvKeys.alchemyPeacockTail,
    ),
  ),
  AthanorBatch(
    id: 'white',
    name: 'The White Work',
    description: 'Quicksilver, frost and moonlight.',
    pieces: [
      AthanorPiece(
        id: 'white.silversmith',
        name: 'Silversmith',
        description: 'A title, shown on your profile.',
        kind: AthanorPieceKind.title,
        rarity: AthanorRarity.common,
        grantRef: 'silversmith',
      ),
      AthanorPiece(
        id: 'white.frost_case',
        name: 'Frost Case',
        description:
            'A specimen case with frost grown in from its corners and cold light above.',
        kind: AthanorPieceKind.caseStyle,
        rarity: AthanorRarity.common,
        grantRef: 'frost',
      ),
      AthanorPiece(
        id: 'white.frost_fusion',
        name: 'Frost Fusion',
        description:
            'Fusing turns the two to frost, grows them into one crystal, and lets it fall away as snow.',
        kind: AthanorPieceKind.fusionStyle,
        rarity: AthanorRarity.epic,
        grantRef: 'frost',
      ),
      AthanorPiece(
        id: 'white.moonstone_cairn',
        name: 'Stone Stack',
        description: 'Pale stones stacked by hand. They glow faintly at night.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'moonstone_cairn',
      ),
      AthanorPiece(
        id: 'white.salt_pillar',
        name: 'Salt Pillar',
        description: 'A column of salt crystal that catches the light.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'salt_pillar',
      ),
      AthanorPiece(
        id: 'white.quicksilver',
        name: 'Quicksilver',
        description:
            'An Alchemon stands in a pool of liquid silver, with beads of it rolling around.',
        kind: AthanorPieceKind.alchemyEffect,
        rarity: AthanorRarity.rare,
        grantRef: InvKeys.alchemyQuicksilver,
      ),
      AthanorPiece(
        id: 'white.moon_font',
        name: 'Moon Basin',
        description:
            'A silver basin that holds the moon at night. Residents come to drink.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.rare,
        grantRef: 'moon_font',
      ),
      AthanorPiece(
        id: 'white.spiritlet_dock',
        name: 'Spiritlet Dock',
        description:
            'The dock\'s icons, drawn with the Spiritlet, whatever your division.',
        kind: AthanorPieceKind.dockSet,
        rarity: AthanorRarity.rare,
        grantRef: 'spiritlet',
      ),
      AthanorPiece(
        id: 'white.hoarfrost_steps',
        name: 'Frost Steps',
        description:
            'Frost blooms on the ground where it walks at home, then melts.',
        kind: AthanorPieceKind.trail,
        rarity: AthanorRarity.epic,
        grantRef: 'hoarfrost_steps',
      ),
      AthanorPiece(
        id: 'white.moonlit_snowfall',
        name: 'Snowfall',
        description: 'Fine snow falls on clear nights in a home realm.',
        kind: AthanorPieceKind.ambience,
        rarity: AthanorRarity.epic,
        grantRef: 'moonlit_snowfall',
      ),
    ],
    capstone: AthanorPiece(
      id: 'white.snow_globe',
      name: 'Snow Globe',
      description:
          'A great glass globe of snow. A resident sits inside it; tap it and the snow swirls up.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.epic,
      grantRef: 'snow_globe',
    ),
  ),
  AthanorBatch(
    id: 'yellow',
    name: 'The Yellow Work',
    description: 'Gold leaf, brass and honey glass.',
    pieces: [
      AthanorPiece(
        id: 'yellow.gilder',
        name: 'Gilder',
        description: 'A title, shown on your profile.',
        kind: AthanorPieceKind.title,
        rarity: AthanorRarity.common,
        grantRef: 'gilder',
      ),
      AthanorPiece(
        id: 'yellow.gilt_case',
        name: 'Gold Case',
        description:
            'A specimen case backed with gold leaf, lit by a lamp above.',
        kind: AthanorPieceKind.caseStyle,
        rarity: AthanorRarity.common,
        grantRef: 'gilt',
      ),
      AthanorPiece(
        id: 'yellow.gilt_fusion',
        name: 'Gold Fusion',
        description:
            'Fusing turns the two to gold leaf that swirls in a double helix and folds into one.',
        kind: AthanorPieceKind.fusionStyle,
        rarity: AthanorRarity.epic,
        grantRef: 'gilt',
      ),
      AthanorPiece(
        id: 'yellow.sundial',
        name: 'Sundial',
        description: 'A brass sundial. Its shadow follows the time of day.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'sundial',
      ),
      AthanorPiece(
        id: 'yellow.honey_lamp',
        name: 'Amber Lamp',
        description: 'A lamp of amber glass with pollen drifting inside.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'honey_lamp',
      ),
      AthanorPiece(
        id: 'yellow.gold_leaf',
        name: 'Gold Leaf',
        description:
            'Flakes of gold leaf drift down around an Alchemon and settle at its feet.',
        kind: AthanorPieceKind.alchemyEffect,
        rarity: AthanorRarity.rare,
        grantRef: InvKeys.alchemyGoldLeaf,
      ),
      AthanorPiece(
        id: 'yellow.storm_coil',
        name: 'Spark Coil',
        description:
            'A tall brass coil that throws sparks. Residents hop beside it, Lightning ones most of all.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.rare,
        grantRef: 'storm_coil',
      ),
      AthanorPiece(
        id: 'yellow.lightlet_dock',
        name: 'Lightlet Dock',
        description:
            'The dock\'s icons, drawn with the Lightlet, whatever your division.',
        kind: AthanorPieceKind.dockSet,
        rarity: AthanorRarity.rare,
        grantRef: 'lightlet',
      ),
      AthanorPiece(
        id: 'yellow.gilt_steps',
        name: 'Gold Steps',
        description:
            'Gold dust lifts where it walks at home and settles in small glints.',
        kind: AthanorPieceKind.trail,
        rarity: AthanorRarity.epic,
        grantRef: 'gilt_steps',
      ),
      AthanorPiece(
        id: 'yellow.sun_motes',
        name: 'Dust Motes',
        description: 'Warm dust drifts in the daylight in a home realm.',
        kind: AthanorPieceKind.ambience,
        rarity: AthanorRarity.epic,
        grantRef: 'sun_motes',
      ),
    ],
    capstone: AthanorPiece(
      id: 'yellow.gilded_throne',
      name: 'Gold Throne',
      description:
          'A throne of brass and gold leaf. One resident sits on it; the others come to bow.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.epic,
      grantRef: 'gilded_throne',
    ),
  ),
  AthanorBatch(
    id: 'red',
    name: 'The Red Work',
    description: 'Garnet, cinnabar and embers.',
    pieces: [
      AthanorPiece(
        id: 'red.ember_keeper',
        name: 'Ember Keeper',
        description: 'A title, shown on your profile.',
        kind: AthanorPieceKind.title,
        rarity: AthanorRarity.common,
        grantRef: 'ember_keeper',
      ),
      AthanorPiece(
        id: 'red.garnet_case',
        name: 'Garnet Case',
        description: 'A specimen case of deep garnet glass, lit from below.',
        kind: AthanorPieceKind.caseStyle,
        rarity: AthanorRarity.common,
        grantRef: 'garnet',
      ),
      AthanorPiece(
        id: 'red.ember_fusion',
        name: 'Ember Fusion',
        description:
            'Fusing heats the two into embers that rise as two flames and burn down to one core.',
        kind: AthanorPieceKind.fusionStyle,
        rarity: AthanorRarity.epic,
        grantRef: 'ember',
      ),
      AthanorPiece(
        id: 'red.glass_rose',
        name: 'Glass Rose',
        description: 'Red glass roses that open at dusk and close at dawn.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'glass_rose',
      ),
      AthanorPiece(
        id: 'red.ember_bowl',
        name: 'Ember Bowl',
        description:
            'A low bowl of embers that slowly glow brighter and dimmer.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'ember_bowl',
      ),
      AthanorPiece(
        id: 'red.cinnabar',
        name: 'Red Smoke',
        description:
            'Red smoke and grains of cinnabar rise from the ground around an Alchemon.',
        kind: AthanorPieceKind.alchemyEffect,
        rarity: AthanorRarity.rare,
        grantRef: InvKeys.alchemyCinnabar,
      ),
      AthanorPiece(
        id: 'red.ember_nest',
        name: 'Ember Nest',
        description:
            'A nest of dark glass twigs with embers between them. A resident sleeps in it at night.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.rare,
        grantRef: 'ember_nest',
      ),
      AthanorPiece(
        id: 'red.bloodlet_dock',
        name: 'Bloodlet Dock',
        description:
            'The dock\'s icons, drawn with the Bloodlet, whatever your division.',
        kind: AthanorPieceKind.dockSet,
        rarity: AthanorRarity.rare,
        grantRef: 'bloodlet',
      ),
      AthanorPiece(
        id: 'red.pomegranate_tree',
        name: 'Pomegranate Tree',
        description:
            'A small tree of dark glass with glowing fruit. Residents climb into it; flyers rest at its top.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.epic,
        grantRef: 'pomegranate_tree',
      ),
      AthanorPiece(
        id: 'red.ember_fall',
        name: 'Rising Embers',
        description: 'Embers drift up from the ground at dusk in a home realm.',
        kind: AthanorPieceKind.ambience,
        rarity: AthanorRarity.epic,
        grantRef: 'ember_fall',
      ),
    ],
    capstone: AthanorPiece(
      id: 'red.red_king_crown',
      name: 'Garnet Crown',
      description:
          'A crown of dark gold and garnets over a velvet cap. Worn in place of the party hat.',
      kind: AthanorPieceKind.costume,
      rarity: AthanorRarity.epic,
      grantRef: InvKeys.alchemyRedKingCrown,
    ),
  ),
  AthanorBatch(
    id: 'still',
    name: 'The Still-Room',
    description: 'The alchemist\'s workshop: glass, brass and herbs.',
    pieces: [
      AthanorPiece(
        id: 'still.distiller',
        name: 'Distiller',
        description: 'A title, shown on your profile.',
        kind: AthanorPieceKind.title,
        rarity: AthanorRarity.common,
        grantRef: 'distiller',
      ),
      AthanorPiece(
        id: 'still.brass_case',
        name: 'Brass Case',
        description:
            'A specimen case with a brass instrument plate behind it and a lamp above.',
        kind: AthanorPieceKind.caseStyle,
        rarity: AthanorRarity.common,
        grantRef: 'brass',
      ),
      AthanorPiece(
        id: 'still.distilled_fusion',
        name: 'Steam Fusion',
        description:
            'Fusing lifts the two as vapour that condenses and drips into one pool.',
        kind: AthanorPieceKind.fusionStyle,
        rarity: AthanorRarity.epic,
        grantRef: 'distillation',
      ),
      AthanorPiece(
        id: 'still.herb_rack',
        name: 'Herb Rack',
        description: 'Bundles of dried herbs hung from a frame.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'herb_rack',
      ),
      AthanorPiece(
        id: 'still.retort_shelf',
        name: 'Flask Shelf',
        description: 'A shelf of glass flasks, each lit its own color.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.common,
        grantRef: 'retort_shelf',
      ),
      AthanorPiece(
        id: 'still.alembic',
        name: 'Glass Still',
        description:
            'A glass still over a small flame. Residents come to look into it.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.rare,
        grantRef: 'alembic',
      ),
      AthanorPiece(
        id: 'still.bell_jar',
        name: 'Bell Jar',
        description: 'A tall glass bell jar. A resident sits inside it.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.rare,
        grantRef: 'bell_jar',
      ),
      AthanorPiece(
        id: 'still.crystalet_dock',
        name: 'Crystalet Dock',
        description:
            'The dock\'s icons, drawn with the Crystalet, whatever your division.',
        kind: AthanorPieceKind.dockSet,
        rarity: AthanorRarity.rare,
        grantRef: 'crystalet',
      ),
      AthanorPiece(
        id: 'still.brass_monocle',
        name: 'Brass Monocle',
        description:
            'A brass monocle on a chain of brass beads. Worn in place of the sunglasses.',
        kind: AthanorPieceKind.costume,
        rarity: AthanorRarity.epic,
        grantRef: InvKeys.alchemyBrassMonocle,
      ),
      AthanorPiece(
        id: 'still.music_box',
        name: 'Music Box',
        description: 'A brass music box. Residents hop to its tune.',
        kind: AthanorPieceKind.homeDecor,
        rarity: AthanorRarity.epic,
        grantRef: 'music_box',
      ),
    ],
    capstone: AthanorPiece(
      id: 'still.great_alembic',
      name: 'Great Still',
      description:
          'A tall glass still. A resident steps in, comes apart into grains, and forms again at the far end.',
      kind: AthanorPieceKind.homeDecor,
      rarity: AthanorRarity.epic,
      grantRef: 'great_alembic',
    ),
  ),
];
