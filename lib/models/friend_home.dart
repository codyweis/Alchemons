// lib/models/friend_home.dart
//
// What a friend sees of another player: their home planet as it hangs in
// space, and the home biome under it as they last left it. Both are taken
// from the player's own save and published to their account (FriendService)
// for friends to read; nothing here is ever written back into a save.
//
// Only how things LOOK travels. A resident is its species, its genes (which
// set its size and colors), its skin, mutation, alchemy effect, costumes,
// lineage tint and the trail it wears: no stats, no level, no nickname. The
// visiting field rebuilds each one as a creature instance with plain stats,
// which the field never reads.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/survival_best_run.dart';
import 'package:alchemons/models/home_biome.dart';
import 'package:alchemons/models/scenes/spawn_point.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A home planet as it looks: its color, its size, what it wears.
class PlanetLook {
  const PlanetLook({
    this.color,
    this.size = 0,
    this.wearing = const {},
    this.options = const {},
  });

  /// The element or premium color it is drawn in (see [homeColorSwatch]);
  /// null for the plain grey of a planet never colored.
  final String? color;

  /// Its size tier, 0 (Tiny) … 4 (Huge).
  final int size;

  /// The customization recipes it wears, and their options
  /// ('recipeId.paramKey' → value).
  final Set<String> wearing;
  final Map<String, String> options;

  /// The radius it has in space at its size (see [HomePlanet.visualRadius]).
  double get worldRadius => switch (size.clamp(0, 4)) {
    0 => 40.0,
    1 => 80.0,
    2 => 130.0,
    3 => 185.0,
    _ => 250.0,
  };

  String get sizeName => HomePlanet.tierNames[size.clamp(0, 4)];

  Map<String, dynamic> toJson() => {
    if (color != null) 'color': color,
    'size': size,
    if (wearing.isNotEmpty) 'wearing': wearing.toList()..sort(),
    if (options.isNotEmpty) 'options': options,
  };

  static PlanetLook fromJson(Object? json) {
    if (json is! Map) return const PlanetLook();
    final size = json['size'];
    final wearing = json['wearing'];
    final options = json['options'];
    return PlanetLook(
      color: json['color'] is String ? json['color'] as String : null,
      size: size is num ? size.toInt().clamp(0, 4) : 0,
      wearing: wearing is List ? {...wearing.whereType<String>()} : const {},
      options: options is Map
          ? {
              for (final e in options.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
    );
  }

  /// The player's own planet as their cosmic save has it, or null when they
  /// have not built one yet. Only what it wears now, of all it has unlocked.
  static PlanetLook? read(SharedPreferences prefs) {
    final raw = prefs.getString(kCosmicHomePlanetPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    final planet = HomePlanet.deserialise(raw);
    final customRaw = prefs.getString(kCosmicCustomizationPrefsKey);
    final custom = customRaw == null
        ? HomeCustomizationState()
        : HomeCustomizationState.deserialise(customRaw);
    final wearing = {...custom.activeIds};
    return PlanetLook(
      color: planet.activeColor,
      size: planet.activeSizeTier.clamp(0, 4),
      wearing: wearing,
      options: {
        for (final e in custom.options.entries)
          if (wearing.contains(e.key.split('.').first)) e.key: e.value,
      },
    );
  }
}

/// One resident as it looks, without anything about how strong it is.
class ResidentLook {
  const ResidentLook({
    required this.baseId,
    this.genetics,
    this.prismatic = false,
    this.mutation,
    this.effect,
    this.costumes,
    this.variant,
    this.trail,
  });

  final String baseId;
  final String? genetics;
  final bool prismatic;
  final String? mutation;
  final String? effect;
  final String? costumes;
  final String? variant;

  /// The Athanor trail it leaves where it walks (TrailStyle id).
  final String? trail;

  factory ResidentLook.of(CreatureInstance inst, {String? trail}) =>
      ResidentLook(
        baseId: inst.baseId,
        genetics: inst.geneticsJson,
        prismatic: inst.isPrismaticSkin,
        mutation: inst.mutation,
        effect: inst.alchemyEffect,
        costumes: inst.costumes,
        variant: inst.variantFaction,
        trail: trail,
      );

  /// A creature instance that looks like this one, at [instanceId], with
  /// plain stats: the field only reads its looks.
  CreatureInstance instance(String instanceId) => CreatureInstance(
    instanceId: instanceId,
    baseId: baseId,
    level: 1,
    xp: 0,
    locked: false,
    isPrismaticSkin: prismatic,
    source: 'friend',
    geneticsJson: genetics,
    staminaMax: 3,
    staminaBars: 3,
    staminaLastUtcMs: 0,
    createdAtUtcMs: 0,
    alchemyEffect: effect,
    costumes: costumes,
    mutation: mutation,
    statSpeed: 3,
    statIntelligence: 3,
    statStrength: 3,
    statBeauty: 3,
    statSpeedPotential: 3,
    statIntelligencePotential: 3,
    statStrengthPotential: 3,
    statBeautyPotential: 3,
    statSpeedEnhancement: 0,
    statIntelligenceEnhancement: 0,
    statStrengthEnhancement: 0,
    statBeautyEnhancement: 0,
    generationDepth: 0,
    variantFaction: variant,
    isPure: false,
    isFavorite: false,
  );

  Map<String, dynamic> toJson() => {
    'b': baseId,
    if (genetics != null) 'g': genetics,
    if (prismatic) 'p': true,
    if (mutation != null) 'm': mutation,
    if (effect != null && effect!.isNotEmpty) 'fx': effect,
    if (costumes != null && costumes!.isNotEmpty) 'c': costumes,
    if (variant != null && variant!.isNotEmpty) 'vf': variant,
    if (trail != null) 't': trail,
  };

  static ResidentLook? fromJson(Object? json) {
    if (json is! Map) return null;
    final base = json['b'];
    if (base is! String || base.isEmpty) return null;
    String? s(String k) => json[k] is String ? json[k] as String : null;
    return ResidentLook(
      baseId: base,
      genetics: s('g'),
      prismatic: json['p'] == true,
      mutation: s('m'),
      effect: s('fx'),
      costumes: s('c'),
      variant: s('vf'),
      trail: s('t'),
    );
  }
}

/// A player's home biome as a friend visits it: the realm they last left it
/// in, with its residents' looks and the ambience worn there.
class FriendHome {
  const FriendHome({
    required this.layout,
    this.looks = const {},
    this.ambience,
    this.planet,
    this.constellations = const {},
  });

  /// Format of what is published; a newer one is still read as far as it
  /// goes (unknown realms, keepsakes and species are left out).
  static const int version = 1;

  /// The one realm, as it was left: its residents and what stands in it.
  final HomeBiomeLayout layout;

  /// Each resident's look, by its instance id in the owner's save.
  final Map<String, ResidentLook> looks;

  /// The Athanor ambience worn in this realm (HomeAmbience id).
  final String? ambience;

  /// What their sky is made of: their planet as it looks, and the
  /// constellation stones they own (by skill id). The layout's own sky
  /// settings say what of it shows.
  final PlanetLook? planet;
  final Set<String> constellations;

  /// The layout cut down to its own realm: the other realms' households,
  /// moods and scenery stay with their owner.
  static HomeBiomeLayout trim(HomeBiomeLayout layout) {
    final realm = layout.realm;
    return HomeBiomeLayout(
      realm: realm,
      sandStyle: layout.sandStyle,
      moods: {if (layout.moods[realm.name] case final mood?) realm.name: mood},
      hour: layout.hour,
      residents: layout.residents,
      households: {
        if (layout.residents.isNotEmpty) realm.name: layout.residents,
      },
      pieces: {
        if (layout.pieces.containsKey(realm.name))
          realm.name: [
            for (final p in layout.placed)
              if (!p.trial) p,
          ],
      },
      sky: layout.sky,
      marks: [...layout.marksHere],
      frames: {if (layout.frame case final f?) realm.name: f},
    );
  }

  String encode() => jsonEncode({
    'v': version,
    'layout': trim(layout).toJson(),
    'looks': {for (final e in looks.entries) e.key: e.value.toJson()},
    if (ambience != null) 'ambience': ambience,
    if (planet != null) 'planet': planet!.toJson(),
    if (constellations.isNotEmpty)
      'constellations': constellations.toList()..sort(),
  });

  static FriendHome? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final looksRaw = json['looks'];
      final looks = <String, ResidentLook>{
        if (looksRaw is Map)
          for (final e in looksRaw.entries)
            if (e.key is String)
              if (ResidentLook.fromJson(e.value) case final look?)
                e.key as String: look,
      };
      final layout = HomeBiomeLayout.fromJson(json['layout']);
      return FriendHome(
        // Only residents whose look came with them.
        layout: layout.copyWith(
          residents: [
            for (final r in layout.residents)
              if (looks.containsKey(r.instanceId)) r,
          ],
        ),
        looks: looks,
        ambience: json['ambience'] is String
            ? json['ambience'] as String
            : null,
        planet: json['planet'] is Map
            ? PlanetLook.fromJson(json['planet'])
            : null,
        constellations: json['constellations'] is List
            ? {...(json['constellations'] as List).whereType<String>()}
            : const {},
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether the resident [instanceId] can be held in the air.
  bool floats(String instanceId) =>
      speciesCanFloat(looks[instanceId]?.baseId ?? '');

  /// The player's own home biome as it stands in their save, for friends.
  /// Read only: unlike the home biome's own load, nothing missing is trimmed
  /// from the save (the catalog may not have loaded yet), it is only left
  /// out of what is shown.
  static Future<FriendHome> capture(
    AlchemonsDatabase db, {
    String? Function(String instanceId)? trailOf,
    String? Function(String realm)? ambienceIn,
  }) async {
    final SettingsDao settings = db.settingsDao;
    final layout = await HomeBiomeLayout.loadOpen(settings);
    PlanetLook? planet;
    try {
      planet = PlanetLook.read(await SharedPreferences.getInstance());
    } catch (_) {}
    var constellations = const <String>{};
    try {
      constellations = await db.constellationDao.getUnlockedSkillIds();
    } catch (_) {}
    final looks = <String, ResidentLook>{};
    for (final r in layout.residents) {
      final inst = await db.creatureDao.getInstance(r.instanceId);
      if (inst == null) continue;
      looks[r.instanceId] = ResidentLook.of(
        inst,
        trail: trailOf?.call(r.instanceId),
      );
    }
    return FriendHome(
      layout: layout.copyWith(
        residents: [
          for (final r in layout.residents)
            if (looks.containsKey(r.instanceId)) r,
        ],
      ),
      looks: looks,
      ambience: ambienceIn?.call(layout.realm.name),
      planet: planet,
      constellations: constellations,
    );
  }
}

/// What a player has done in the Trials, as their friends see it: races
/// and bouts won in each cup (cup id → count), and their records (event id
/// → milliseconds, or stars for the night sky; trials_records.dart).
class TrialsCard {
  const TrialsCard({this.won = const {}, this.best = const {}});

  /// The most of each a card carries, as published and as read.
  static const int maxCups = 16, maxRecords = 48;

  final Map<String, int> won;
  final Map<String, int> best;

  bool get isEmpty => won.isEmpty && best.isEmpty;

  Map<String, dynamic> toJson() => {'won': won, 'best': best};

  static Map<String, int> _counts(Object? j, int most, int ceiling) {
    if (j is! Map) return const {};
    final out = <String, int>{};
    for (final e in j.entries) {
      if (out.length >= most) break;
      final v = e.value;
      if (e.key is String && v is num && v >= 0 && v <= ceiling) {
        out[e.key as String] = v.round();
      }
    }
    return out;
  }

  /// Null for nothing, or anything malformed.
  static TrialsCard? fromJson(Object? j) {
    if (j is! Map) return null;
    final card = TrialsCard(
      won: _counts(j['won'], maxCups, 99),
      best: _counts(j['best'], maxRecords, 100000000),
    );
    return card.isEmpty ? null : card;
  }
}

/// A friend as their friends see them: a name, a division, the title they
/// wear, their featured Alchemon, a planet, the Trials, and their best
/// Survival run.
class FriendCard {
  const FriendCard({
    required this.uid,
    required this.name,
    this.faction,
    this.title,
    this.featured,
    this.planet,
    this.trials,
    this.survival,
  });

  /// The most a title's words can run, as published and as read.
  static const int maxTitleLength = 40;

  final String uid;
  final String name;

  /// Their division (FactionId name), whose realm their page is drawn in.
  final String? faction;

  /// The words of the title they wear (ProfileTitles.nameOf); null for none.
  final String? title;

  /// How the Alchemon their home features looks; null before they have one,
  /// or from a game that published none.
  final ResidentLook? featured;

  /// Null until they have built a home planet.
  final PlanetLook? planet;

  /// Their cups and records; null before they have raced (or from a game
  /// that published none).
  final TrialsCard? trials;

  /// Their best Survival run, read from its own document (survival_best);
  /// null before they have one, from a game that published none, or where
  /// it could not be read.
  final SurvivalBestRun? survival;

  static FriendCard fromJson(
    String uid,
    Map<String, dynamic>? json, {
    SurvivalBestRun? survival,
  }) {
    final name = json?['name'];
    final title = json?['title'];
    return FriendCard(
      uid: uid,
      name: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Alchemist',
      faction: json?['faction'] is String ? json!['faction'] as String : null,
      title:
          title is String &&
              title.trim().isNotEmpty &&
              title.trim().length <= maxTitleLength
          ? title.trim()
          : null,
      featured: ResidentLook.fromJson(json?['featured']),
      planet: json?['planet'] is Map
          ? PlanetLook.fromJson(json!['planet'])
          : null,
      trials: TrialsCard.fromJson(json?['trials']),
      survival: survival,
    );
  }
}
