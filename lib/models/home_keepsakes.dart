// lib/models/home_keepsakes.dart
//
// Keepsakes: things the player has earned elsewhere in the game that can be
// stood in their home biome. Each is drawn in code (keepsake_art.dart) in
// the game's obsidian-and-glass, and each is a trophy of one thing done:
//
//   · a Lost Maxim found in a planet's dungeon — one per planet, its look
//     taken from the piece the maxim already leaves in its room;
//   · a contest arena mastered in open space (all five levels won);
//   · a species bred a hundred times — its effigy, in its own grains.
//
// Nothing here is stored: what is owned is read from where the game already
// keeps it (the planets' discovered ids, the contest progress, the breeding
// statistics), so a keepsake can never be owned without the deed, and a
// restored save brings its keepsakes with it.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/home_biome.dart' show homeDebugOn;
import 'package:shared_preferences/shared_preferences.dart';

/// Where the planets' discovered ids are kept (the dungeon screen's key).
const String kPlanetStarsPrefsKey = 'cosmic_planet_stars';

/// Where the contest progress is kept (the cosmic screen's key).
const String kContestProgressPrefsKey = 'cosmic_trait_contests_v1';

/// How many of a species must have been bred for its effigy.
const int kEffigyBredCount = 100;

enum KeepsakeSource { maxim, contest, effigy }

class Keepsake {
  const Keepsake(
    this.id,
    this.title,
    this.line, {
    required this.source,
    this.element,
    this.eggId,
    this.trait,
    this.copies = 1,
    this.speciesId,
  });

  /// What a piece of it is called in the layout (`ember_torch`), and for an
  /// effigy `effigy:<species id>`.
  final String id;
  final String title;

  /// One plain line: what it is and what earned it.
  final String line;
  final KeepsakeSource source;

  /// The planet's element, for a maxim's keepsake.
  final String? element;

  /// The discovered id that earns it, for a maxim's.
  final String? eggId;
  final CosmicContestTrait? trait;

  /// How many of it the player gets: a pair of torches, a pair of portals.
  final int copies;

  /// The species, for an effigy.
  final String? speciesId;

  bool get isEffigy => source == KeepsakeSource.effigy;

  static Keepsake effigy(String speciesId, String speciesName) => Keepsake(
    'effigy:$speciesId',
    '$speciesName Effigy',
    'A hundred $speciesName bred. Its likeness, in its own grains.',
    source: KeepsakeSource.effigy,
    speciesId: speciesId,
  );

  /// The keepsake a piece of [kind] is, or null if there is none such.
  static Keepsake? byId(String kind, {String Function(String)? speciesName}) {
    if (kind.startsWith('effigy:')) {
      final sp = kind.substring(7);
      return effigy(sp, speciesName?.call(sp) ?? sp);
    }
    for (final k in all) {
      if (k.id == kind) return k;
    }
    return null;
  }

  /// Every keepsake there is but the effigies, in the order the shelf shows
  /// them: the planets as the star chart lists them, then the arenas.
  static const all = <Keepsake>[
    Keepsake(
      'ember_torch',
      'Ember Torches',
      'Ember Epitaph, Fire. Two torches that keep the planter\'s flame.',
      source: KeepsakeSource.maxim,
      element: 'Fire',
      eggId: 'egg:fire_epitaph',
      copies: 2,
    ),
    Keepsake(
      'four_winds',
      'Four Winds Vane',
      'The Four Winds, Air. Its vanes turn to whatever blows.',
      source: KeepsakeSource.maxim,
      element: 'Air',
      eggId: 'egg:air_first_wind',
    ),
    Keepsake(
      'frozen_moon',
      'Frozen Moon',
      'The Stilled Mirror, Water. A moon held in a rosette of ice.',
      source: KeepsakeSource.maxim,
      element: 'Water',
      eggId: 'egg:water_frozen_moon',
    ),
    Keepsake(
      'giants_palm',
      'The Giant\'s Palm',
      'The Giant\'s Palm, Earth. A stone hand holding its crystal.',
      source: KeepsakeSource.maxim,
      element: 'Earth',
      eggId: 'egg:earth_giants_palm',
    ),
    Keepsake(
      'fulgurite',
      'Fulgurite',
      'Thunderbolt, Lightning. Glass a bolt made, still carrying a spark.',
      source: KeepsakeSource.maxim,
      element: 'Lightning',
      eggId: 'egg:lightning_thunderbolt',
    ),
    Keepsake(
      'harmony_pipes',
      'Harmony Pipes',
      'Hidden Harmony, Steam. Three pipes that breathe in time.',
      source: KeepsakeSource.maxim,
      element: 'Steam',
      eggId: 'egg:steam_hidden_harmony',
    ),
    Keepsake(
      'black_glass',
      'Black Glass',
      'Black Glass, Lava. The pour you threw away, standing as a mirror.',
      source: KeepsakeSource.maxim,
      element: 'Lava',
      eggId: 'egg:lava_black_glass',
    ),
    Keepsake(
      'the_dose',
      'The Dose',
      'The Dose, Poison. An alembic that never stops working.',
      source: KeepsakeSource.maxim,
      element: 'Poison',
      eggId: 'egg:poison_the_dose',
    ),
    Keepsake(
      'mud_lotus',
      'The Lotus',
      'No Mud No Lotus, Mud. It opens by day and closes at night.',
      source: KeepsakeSource.maxim,
      element: 'Mud',
      eggId: 'egg:mud_no_lotus',
    ),
    Keepsake(
      'star_walker',
      'Star-Walker\'s Glass',
      'The Star Walker, Ice. The stranger caught in its lens.',
      source: KeepsakeSource.maxim,
      element: 'Ice',
      eggId: 'egg:ice_star_walker',
    ),
    Keepsake(
      'hourglass',
      'Nothing Perishes',
      'Nothing Perishes, Dust. An hourglass that turns itself.',
      source: KeepsakeSource.maxim,
      element: 'Dust',
      eggId: 'egg:dust_nothing_perishes',
    ),
    Keepsake(
      'know_thyself',
      'Know Thyself',
      'Know Thyself, Crystal. A geode round a silvered eye.',
      source: KeepsakeSource.maxim,
      element: 'Crystal',
      eggId: 'egg:crystal_know_thyself',
    ),
    Keepsake(
      'opposite_flower',
      'The Opposite Flower',
      'The Seed That Wanted the Opposite, Plant. Its leaves fall upward.',
      source: KeepsakeSource.maxim,
      element: 'Plant',
      eggId: 'egg:plant_opposite_seed',
    ),
    Keepsake(
      'lancet_stone',
      'The Undug Grave',
      'Stuff of Dreams, Spirit. A headstone with a window lit inside.',
      source: KeepsakeSource.maxim,
      element: 'Spirit',
      eggId: 'egg:spirit_empty_urn',
    ),
    Keepsake(
      'twin_portals',
      'The Black Sun Portals',
      'The Abyss, Dark. A pair: what walks into one walks out of the other.',
      source: KeepsakeSource.maxim,
      element: 'Dark',
      eggId: 'egg:dark_ouroboros',
      copies: 2,
    ),
    Keepsake(
      'night_book',
      'The Afraid Volume',
      'Afraid of the Light, Light. A book of night glass, lying open.',
      source: KeepsakeSource.maxim,
      element: 'Light',
      eggId: 'egg:light_walks_on_light',
    ),
    Keepsake(
      'garnet_heart',
      'The Garnet Heart',
      'The Blood Is the Life, Blood. It beats.',
      source: KeepsakeSource.maxim,
      element: 'Blood',
      eggId: 'egg:blood_drum',
    ),
    Keepsake(
      'crown_mirror',
      'Crown Mirror',
      'Every level of the Beauty Contest won.',
      source: KeepsakeSource.contest,
      trait: CosmicContestTrait.beauty,
    ),
    Keepsake(
      'victory_arch',
      'Circuit Arch',
      'Every level of the Speed Contest won.',
      source: KeepsakeSource.contest,
      trait: CosmicContestTrait.speed,
    ),
    Keepsake(
      'titan_anvil',
      'Titan\'s Anvil',
      'Every level of the Strength Contest won.',
      source: KeepsakeSource.contest,
      trait: CosmicContestTrait.strength,
    ),
    Keepsake(
      'prism_orrery',
      'Prism Orrery',
      'Every level of the Intelligence Contest won.',
      source: KeepsakeSource.contest,
      trait: CosmicContestTrait.intelligence,
    ),
  ];
}

/// What the player owns, read from the game.
class KeepsakeLedger {
  const KeepsakeLedger(this.owned);

  /// Every keepsake the player has earned, effigies included, in shelf
  /// order.
  final List<Keepsake> owned;

  static const empty = KeepsakeLedger([]);

  bool owns(String id) => owned.any((k) => k.id == id);

  Keepsake? byId(String id) => owned.where((k) => k.id == id).firstOrNull;

  /// What is owned, from the discovered ids ([starsRaw]), the contest
  /// progress ([contestsRaw]) and how many of each species have been bred
  /// ([bred], species id → count; names from [speciesName]).
  static KeepsakeLedger from({
    required String starsRaw,
    required String contestsRaw,
    required Map<String, int> bred,
    required String Function(String speciesId) speciesName,
  }) {
    final stars = PlanetStarState.deserialise(starsRaw);
    final contests = contestsRaw.isEmpty
        ? CosmicContestProgress.fresh()
        : CosmicContestProgress.deserialise(contestsRaw);
    final owned = <Keepsake>[
      for (final k in Keepsake.all)
        if (switch (k.source) {
          KeepsakeSource.maxim => stars
              .discoveredCloudsFor(k.element!)
              .contains(k.eggId),
          KeepsakeSource.contest => contests.isMastered(k.trait!),
          KeepsakeSource.effigy => false,
        })
          k,
      for (final e in (bred.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))))
        if (e.value >= kEffigyBredCount)
          Keepsake.effigy(e.key, speciesName(e.key)),
    ];
    return KeepsakeLedger(owned);
  }

  /// What the player owns now.
  static Future<KeepsakeLedger> load(
    AlchemonsDatabase db,
    String Function(String speciesId) speciesName,
  ) async {
    var stars = '', contests = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      stars = prefs.getString(kPlanetStarsPrefsKey) ?? '';
      contests = prefs.getString(kContestProgressPrefsKey) ?? '';
    } catch (_) {
      // No preferences to read (a test harness): nothing earned there.
    }
    final stats = await db.constellationDao.getAllBreedingStats();
    // The developer tools open everything: every keepsake, and an effigy
    // of each species the player has.
    if (await homeDebugOn()) {
      final species = {
        for (final i in await db.creatureDao.getAllInstances()) i.baseId,
      }.toList()..sort();
      return KeepsakeLedger([
        ...Keepsake.all,
        for (final id in species) Keepsake.effigy(id, speciesName(id)),
      ]);
    }
    try {
      return from(
        starsRaw: stars,
        contestsRaw: contests,
        bred: {for (final s in stats) s.speciesId: s.totalBred},
        speciesName: speciesName,
      );
    } catch (_) {
      // A progress string from some other version: the effigies still
      // stand.
      return from(
        starsRaw: '',
        contestsRaw: '',
        bred: {for (final s in stats) s.speciesId: s.totalBred},
        speciesName: speciesName,
      );
    }
  }
}
