// lib/models/home_decor.dart
//
// Home decor: what can be bought for the home biome, beside the keepsakes
// that are earned. Three tiers, simple to advanced:
//
//   · Curios — small lit pieces, mostly still. Silver; several of each.
//   · Living Pieces — things that move, which the Alchemons use. Gold; a
//     few of each.
//   · Wonders — centrepieces with behaviours of their own, used by several
//     Alchemons at once. 150 gold; one of each.
//
// Beside them, the decor drawn at the Athanor ([HomeDecor.athanor]): the
// same three tiers, never sold, owned the same way.
//
// What is owned is an inventory count (`home.<id>`), so it travels with the
// save, and it counts per realm: owning four lanterns, each realm can stand
// four. A piece is placed, drawn and lived with exactly as a keepsake is
// (keepsake_art.dart, keepsake_component.dart, home_life.dart).

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/home_biome.dart' show homeDebugOn;

enum DecorTier {
  curio('CURIOS'),
  living('LIVING PIECES'),
  wonder('WONDERS');

  const DecorTier(this.label);
  final String label;
}

class HomeDecor {
  const HomeDecor(
    this.id,
    this.name,
    this.line, {
    required this.tier,
    this.silver = 0,
    this.gold = 0,
    this.max = 1,
    this.aloft = false,
    this.styles = const [],
    this.wide = 1,
    this.athanorOnly = false,
  });

  /// Its kind in the layout and its art (keepsake_art.dart).
  final String id;
  final String name;

  /// One plain line: what it is, and what the Alchemons do with it.
  final String line;
  final DecorTier tier;
  final int silver, gold;

  /// How many of it one realm can stand.
  final int max;

  /// Whether it hangs in the air rather than standing on the ground.
  final bool aloft;

  /// The looks it can be given once placed (STYLE), by name; empty for
  /// one look.
  final List<String> styles;

  /// How much ground it takes against a creature's (a Wonder is wider).
  final double wide;

  /// Drawn at the Athanor and found nowhere else: the shop never makes an
  /// offer for it, so its [silver] and [gold] are left at 0.
  final bool athanorOnly;

  /// The shop offer, and the inventory item that counts how many are owned.
  String get offerId => 'home.$id';
  String get inventoryKey => 'home.$id';

  Map<String, int> get cost => {
    if (silver > 0) 'silver': silver,
    if (gold > 0) 'gold': gold,
  };

  static HomeDecor? byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }

  static HomeDecor? byOffer(String offerId) =>
      offerId.startsWith('home.') ? byId(offerId.substring(5)) : null;

  static Iterable<HomeDecor> ofTier(DecorTier tier) =>
      all.where((d) => d.tier == tier);

  static const all = <HomeDecor>[
    // ── Curios ──
    HomeDecor(
      'lantern_post',
      'Lantern Post',
      'A glass lamp on an obsidian post. It lights itself at dusk.',
      tier: DecorTier.curio,
      silver: 400,
      max: 8,
      styles: ['AMBER', 'FROST', 'VIOLET'],
    ),
    HomeDecor(
      'candles',
      'Candle Cluster',
      'A few candles in the grass, each its own small flame.',
      tier: DecorTier.curio,
      silver: 250,
      max: 8,
    ),
    HomeDecor(
      'geode',
      'Crystal Geode',
      'Crystals breaking out of the ground, catching the light.',
      tier: DecorTier.curio,
      silver: 500,
      max: 8,
      styles: ['TEAL', 'VIOLET', 'ROSE', 'AMBER'],
    ),
    HomeDecor(
      'rune_stone',
      'Rune Stone',
      'A small stone with an alchemical sign lit in it.',
      tier: DecorTier.curio,
      silver: 400,
      max: 8,
      styles: ['FIRE', 'WATER', 'AIR', 'EARTH', 'SUN', 'MOON'],
    ),
    HomeDecor(
      'banner',
      'Faction Banner',
      'A banner in a faction\'s colors, moving with the wind.',
      tier: DecorTier.curio,
      silver: 800,
      max: 8,
      styles: ['VOLCANIC', 'OCEANIC', 'VERDANT', 'EARTHEN'],
    ),
    HomeDecor(
      'planter',
      'Glass Planter',
      'An obsidian planter of flowers that glow.',
      tier: DecorTier.curio,
      silver: 500,
      max: 8,
      styles: ['ROSE', 'GOLD', 'SKY', 'VIOLET'],
    ),
    HomeDecor(
      'sky_lanterns',
      'Sky Lanterns',
      'Lanterns that hang in the air on nothing, drifting.',
      tier: DecorTier.curio,
      silver: 700,
      max: 8,
      aloft: true,
      styles: ['AMBER', 'ROSE', 'FROST'],
    ),
    // Silverlite: liquid metal, as the Quicksilver aura is (user
    // 2026-10-22: "i really like the animation of the quicksilver blobs";
    // "change it to silverlite as the name"). 25 gold where several can be
    // had, a Wonder's 150 where one can.
    HomeDecor(
      'silverlite_drop',
      'Silverlite Drop',
      'A ball of liquid silver over a dark dish. It drips, and the drops rise '
          'back into it.',
      tier: DecorTier.curio,
      gold: 25,
      max: 4,
    ),
    // ── Living Pieces ──
    HomeDecor(
      'wind_chimes',
      'Wind Chimes',
      'Glass rods that swing in the wind, or when an Alchemon brushes them.',
      tier: DecorTier.living,
      gold: 8,
      max: 3,
    ),
    HomeDecor(
      'fountain',
      'Grain Fountain',
      'Water that rises in grains. The Alchemons come to drink.',
      tier: DecorTier.living,
      gold: 15,
      max: 2,
    ),
    HomeDecor(
      'rest_nest',
      'Rest Nest',
      'At night an Alchemon who can reach it sleeps in it.',
      tier: DecorTier.living,
      gold: 10,
      max: 4,
    ),
    HomeDecor(
      'flyer_perch',
      'Flyer\'s Perch',
      'A tall perch. Flyers land on it and rest.',
      tier: DecorTier.living,
      gold: 8,
      max: 3,
    ),
    HomeDecor(
      'swing',
      'Swing',
      'A seat between two posts. An Alchemon climbs on and swings.',
      tier: DecorTier.living,
      gold: 20,
      max: 2,
    ),
    HomeDecor(
      'canopy',
      'Shelter Canopy',
      'In rain, snow or storm, the Alchemons who can reach it shelter under it.',
      tier: DecorTier.living,
      gold: 25,
      max: 2,
      wide: 1.3,
    ),
    HomeDecor(
      'mushroom_ring',
      'Glow Mushroom Ring',
      'Mushrooms whose caps light when an Alchemon hops across them.',
      tier: DecorTier.living,
      gold: 10,
      max: 3,
    ),
    HomeDecor(
      'twin_drops',
      'Twin Drops',
      'Two balls of liquid silver that drift together, become one and part '
          'again. Alchemons look at themselves in them.',
      tier: DecorTier.living,
      gold: 25,
      max: 2,
    ),
    // ── Wonders ──
    HomeDecor(
      'hot_spring',
      'Hot Spring',
      'A steaming pool. Up to three Alchemons bathe in it at once.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.7,
    ),
    HomeDecor(
      'elder_tree',
      'Elder Grain Tree',
      'A great tree of grains. The Alchemons climb into it, sleep in it, '
          'and flyers roost there.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.8,
    ),
    HomeDecor(
      'stage',
      'The Stage',
      'One Alchemon performs on it; the others gather to watch.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.7,
    ),
    HomeDecor(
      'orrery',
      'Grand Orrery',
      'A turning ring of glass and gold that an Alchemon rides round.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.7,
    ),
    HomeDecor(
      'reflecting_pool',
      'Reflecting Pool',
      'Still water. An Alchemon who looks in sees itself.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.6,
    ),
    HomeDecor(
      'silverlite_fountain',
      'Silverlite Fountain',
      'A basin of liquid silver. A column of it rises, swells into a ball and '
          'falls back in drops. Alchemons gather to watch.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.6,
    ),
    ...athanor,
  ];

  /// Decor drawn at the Athanor (docs/crucible/cosmetics_concepts.md), by
  /// batch: never sold. A Curio is drawn three at a time, so three can
  /// stand in a realm; the rest are one of a kind.
  static const athanor = <HomeDecor>[
    // ── The Black Work ──
    HomeDecor(
      'moth_lantern',
      'Moth Lantern',
      'A dim violet lamp on a crooked post. Moths settle on it at night.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'inkcap_cluster',
      'Ink Mushrooms',
      'Tall ink-cap mushrooms that drip ink, most of all at night.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'ash_brazier',
      'Ash Brazier',
      'A low bowl of cold violet flame. Alchemons warm themselves at it and '
          'sleep beside it at night.',
      tier: DecorTier.living,
      athanorOnly: true,
    ),
    HomeDecor(
      'nightbloom_bed',
      'Lily Bed',
      'A bed of dark leaves ringed with black lilies that open at night. An '
          'Alchemon sleeps among them.',
      tier: DecorTier.living,
      wide: 1.3,
      athanorOnly: true,
    ),
    // ── The White Work ──
    HomeDecor(
      'moonstone_cairn',
      'Stone Stack',
      'Pale stones stacked by hand. They glow faintly at night.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'salt_pillar',
      'Salt Pillar',
      'A column of salt crystal that catches the light.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'moon_font',
      'Moon Basin',
      'A silver basin that holds the moon at night. Alchemons come to drink.',
      tier: DecorTier.living,
      athanorOnly: true,
    ),
    HomeDecor(
      'snow_globe',
      'Snow Globe',
      'A great glass globe of snow. An Alchemon sits inside it; tap it and the '
          'snow swirls up.',
      tier: DecorTier.wonder,
      wide: 1.6,
      athanorOnly: true,
    ),
    // ── The Yellow Work ──
    HomeDecor(
      'sundial',
      'Sundial',
      'A brass sundial. Its shadow follows the time of day.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'honey_lamp',
      'Amber Lamp',
      'A lamp of amber glass with pollen drifting inside.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'storm_coil',
      'Spark Coil',
      'A tall brass coil that throws sparks. Alchemons hop beside it, '
          'Lightning ones most of all.',
      tier: DecorTier.living,
      athanorOnly: true,
    ),
    HomeDecor(
      'gilded_throne',
      'Gold Throne',
      'A throne of brass and gold leaf. One Alchemon sits on it; the others '
          'come to bow.',
      tier: DecorTier.wonder,
      wide: 1.7,
      athanorOnly: true,
    ),
    // ── The Red Work ──
    HomeDecor(
      'glass_rose',
      'Glass Rose',
      'Red glass roses that open at dusk and close at dawn.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'ember_bowl',
      'Ember Bowl',
      'A low bowl of embers that slowly glow brighter and dimmer.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'ember_nest',
      'Ember Nest',
      'A nest of dark glass twigs with embers between them. An Alchemon '
          'sleeps in it at night.',
      tier: DecorTier.living,
      athanorOnly: true,
    ),
    HomeDecor(
      'pomegranate_tree',
      'Pomegranate Tree',
      'A small tree of dark glass with glowing fruit. Alchemons climb into '
          'it; flyers rest at its top.',
      tier: DecorTier.living,
      wide: 1.3,
      athanorOnly: true,
    ),
    // ── The Still-Room ──
    HomeDecor(
      'herb_rack',
      'Herb Rack',
      'Bundles of dried herbs hung from a frame.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'retort_shelf',
      'Flask Shelf',
      'A shelf of glass flasks, each lit its own color.',
      tier: DecorTier.curio,
      max: 3,
      athanorOnly: true,
    ),
    HomeDecor(
      'alembic',
      'Glass Still',
      'A glass still over a small flame. Alchemons come to look into it.',
      tier: DecorTier.living,
      athanorOnly: true,
    ),
    HomeDecor(
      'bell_jar',
      'Bell Jar',
      'A tall glass bell jar. An Alchemon sits inside it.',
      tier: DecorTier.living,
      athanorOnly: true,
    ),
    HomeDecor(
      'music_box',
      'Music Box',
      'A brass music box. Alchemons hop to its tune.',
      tier: DecorTier.living,
      athanorOnly: true,
    ),
    HomeDecor(
      'great_alembic',
      'Great Still',
      'A tall glass still. An Alchemon steps in, comes apart into grains, and '
          'forms again at the far end.',
      tier: DecorTier.wonder,
      wide: 2,
      athanorOnly: true,
    ),
  ];
}

/// How many of each piece of decor the player owns.
class DecorLedger {
  const DecorLedger(this.owned);

  /// By decor id.
  final Map<String, int> owned;

  static const empty = DecorLedger({});

  int ownedOf(String id) => owned[id] ?? 0;

  /// How many one realm may stand: what is owned, up to the piece's cap.
  int allowedOf(String id) {
    final d = HomeDecor.byId(id);
    if (d == null) return 0;
    return ownedOf(id).clamp(0, d.max);
  }

  static Future<DecorLedger> load(AlchemonsDatabase db) async {
    // The developer tools open everything, as for the keepsakes.
    if (await homeDebugOn()) {
      return DecorLedger({for (final d in HomeDecor.all) d.id: d.max});
    }
    return DecorLedger({
      for (final d in HomeDecor.all)
        d.id: await db.inventoryDao.getItemQty(d.inventoryKey),
    });
  }
}
