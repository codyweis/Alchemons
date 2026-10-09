// lib/models/home_decor.dart
//
// Home decor: what can be bought for the home biome, beside the keepsakes
// that are earned. Three tiers, simple to advanced:
//
//   · Curios — small lit pieces, mostly still. Silver; several of each.
//   · Living Pieces — things that move, which the residents use. Gold; a
//     few of each.
//   · Wonders — centrepieces with behaviours of their own, used by several
//     residents at once. 150 gold; one of each.
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
  });

  /// Its kind in the layout and its art (keepsake_art.dart).
  final String id;
  final String name;

  /// One plain line: what it is, and what the residents do with it.
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
    // ── Living Pieces ──
    HomeDecor(
      'wind_chimes',
      'Wind Chimes',
      'Glass rods that swing in the wind, or when a resident brushes them.',
      tier: DecorTier.living,
      gold: 8,
      max: 3,
    ),
    HomeDecor(
      'fountain',
      'Grain Fountain',
      'Water that rises in grains. The residents come to drink.',
      tier: DecorTier.living,
      gold: 15,
      max: 2,
    ),
    HomeDecor(
      'rest_nest',
      'Rest Nest',
      'At night a resident who can reach it sleeps in it.',
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
      'A seat between two posts. A resident climbs on and swings.',
      tier: DecorTier.living,
      gold: 20,
      max: 2,
    ),
    HomeDecor(
      'canopy',
      'Shelter Canopy',
      'In rain, snow or storm, the residents who can reach it shelter under it.',
      tier: DecorTier.living,
      gold: 25,
      max: 2,
      wide: 1.3,
    ),
    HomeDecor(
      'mushroom_ring',
      'Glow Mushroom Ring',
      'Mushrooms whose caps light when a resident hops across them.',
      tier: DecorTier.living,
      gold: 10,
      max: 3,
    ),
    // ── Wonders ──
    HomeDecor(
      'hot_spring',
      'Hot Spring',
      'A steaming pool. Up to three residents bathe in it at once.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.7,
    ),
    HomeDecor(
      'elder_tree',
      'Elder Grain Tree',
      'A great tree of grains. The residents climb into it, sleep in it, '
          'and flyers roost there.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.8,
    ),
    HomeDecor(
      'stage',
      'The Stage',
      'One resident performs on it; the others gather to watch.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.7,
    ),
    HomeDecor(
      'orrery',
      'Grand Orrery',
      'A turning ring of glass and gold that a resident rides round.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.7,
    ),
    HomeDecor(
      'reflecting_pool',
      'Reflecting Pool',
      'Still water. A resident who looks in sees itself.',
      tier: DecorTier.wonder,
      gold: 150,
      wide: 1.6,
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
