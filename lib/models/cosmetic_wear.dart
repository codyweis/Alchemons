// COSMETIC WEAR — what is worn of the four cosmetic kinds the Athanor gives
// that have no store of their own (docs/athanor_design.md):
//
//   case styles     per creature  the Creatures tab's specimen case
//   trails          per creature  left where it walks at home
//   fusion styles   one, global   how every fusion plays
//   home ambiences  per realm     a light layer over a home realm's field
//
// What is OWNED lives in `OwnedCosmetics` (`cosmetics_owned_v1`); what is
// WORN lives here, one settings row each, so it travels with the save:
//
//   case_style_worn_v1  {"<instanceId>": "gilt"}
//   trail_worn_v1       {"<instanceId>": "hoarfrost_steps"}
//   fusion_style_v1     "frost"
//   ambience_worn_v1    {"<realm name>": "peat_mist"}
//
// Decoding never throws: anything unreadable or unknown is left out. A worn
// id that is not owned is never shown ([CosmeticWear.owned] filters), so a
// restored save that lost an item simply shows the plain look.

import 'dart:convert';

import 'package:alchemons/models/athanor.dart';
import 'package:flutter/foundation.dart';

/// A specimen-case style: what a specimen stands in on the Creatures tab.
enum CaseStyle {
  /// The Black Work: black glass with an oil-slick sheen.
  obsidian('obsidian', 'Obsidian Case'),

  /// The White Work: frost grown in from the corners, cold light above.
  frost('frost', 'Frost Case'),

  /// The Yellow Work: a back of gold leaf, lamp-lit from above.
  gilt('gilt', 'Gold Case'),

  /// The Red Work: deep garnet glass, lit from below.
  garnet('garnet', 'Garnet Case'),

  /// The Still-Room: a brass instrument plate, a lamp over it.
  brass('brass', 'Brass Case');

  const CaseStyle(this.id, this.title);
  final String id;
  final String title;

  static CaseStyle? byId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// A trail a creature leaves where it walks at home.
enum TrailStyle {
  /// The White Work: frost blooms where each foot comes down, then melts.
  hoarfrost('hoarfrost_steps', 'Frost Steps'),

  /// The Yellow Work: gold dust lifts at each step and settles in glints.
  gilt('gilt_steps', 'Gold Steps');

  const TrailStyle(this.id, this.title);
  final String id;
  final String title;

  static TrailStyle? byId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// How two Alchemons fuse: the whole of it, from the pair turning to grains
/// to the cultivation they become. One for the whole game; none is the
/// fusion as it has always been (the two pour into a sphere and erupt, and
/// the sigil is drawn in it). A styled fusion draws no sigil.
enum FusionStyle {
  /// The Black Work: both run together as two inks in water, curl into one
  /// dark spiral, and bloom.
  ink('ink', 'Ink Fusion'),

  /// The White Work: both crystallize, the crystals grow together, and the
  /// crystal falls away as snow.
  frost('frost', 'Frost Fusion'),

  /// The Yellow Work: both turn to gold leaf, swirl in a double helix and
  /// fold together, and a burnish sweeps across.
  gilt('gilt', 'Gold Fusion'),

  /// The Red Work: both heat into embers, rise as two flames that twist
  /// together, and burn down to one core that cools.
  ember('ember', 'Ember Fusion'),

  /// The Still-Room: both rise as vapour, condense, and drip into one pool
  /// that forms the result.
  distillation('distillation', 'Steam Fusion');

  const FusionStyle(this.id, this.title);
  final String id;
  final String title;

  static FusionStyle? byId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The style worn now, for the fusion's fields, which are made with no
  /// context (the breed tab, the cinematic, the space ram, the wild). Kept
  /// by `CosmeticWearService`; null is the plain fusion.
  static final ValueNotifier<FusionStyle?> worn = ValueNotifier(null);
}

/// A light layer over a home realm's field, at its own hour. It never
/// announces itself: it is only seen.
enum HomeAmbience {
  /// The Black Work: low violet mist at night, parted where residents walk.
  peatMist('peat_mist', 'Night Mist'),

  /// The White Work: fine snow on clear nights.
  moonlitSnowfall('moonlit_snowfall', 'Snowfall'),

  /// The Yellow Work: warm dust drifting in the daylight.
  sunMotes('sun_motes', 'Dust Motes'),

  /// The Red Work: embers drifting up from the ground at dusk.
  emberFall('ember_fall', 'Rising Embers');

  const HomeAmbience(this.id, this.title);
  final String id;
  final String title;

  static HomeAmbience? byId(Object? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// What is worn, as saved. Use [owned] before showing any of it.
@immutable
class CosmeticWear {
  const CosmeticWear({
    this.cases = const {},
    this.trails = const {},
    this.fusion,
    this.ambience = const {},
  });

  static const String caseKey = 'case_style_worn_v1';
  static const String trailKey = 'trail_worn_v1';
  static const String fusionKey = 'fusion_style_v1';
  static const String ambienceKey = 'ambience_worn_v1';

  static const CosmeticWear empty = CosmeticWear();

  /// By creature instance id.
  final Map<String, CaseStyle> cases;

  /// By creature instance id.
  final Map<String, TrailStyle> trails;

  final FusionStyle? fusion;

  /// By home realm (`HomeRealm.name`).
  final Map<String, HomeAmbience> ambience;

  /// A JSON object of string → id, each value read by [byId]; anything
  /// else is left out.
  static Map<String, T> decodeMap<T>(String? raw, T? Function(Object?) byId) {
    if (raw == null || raw.isEmpty) return {};
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return {};
    }
    if (json is! Map) return {};
    final out = <String, T>{};
    for (final e in json.entries) {
      final k = e.key;
      final v = byId(e.value);
      if (k is String && k.isNotEmpty && v != null) out[k] = v;
    }
    return out;
  }

  static String encodeMap<T>(Map<String, T> map, String Function(T) idOf) {
    final keys = map.keys.toList()..sort();
    return jsonEncode({for (final k in keys) k: idOf(map[k] as T)});
  }

  /// The fusion style row: a bare id, or a JSON string holding one.
  static FusionStyle? decodeFusion(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final bare = FusionStyle.byId(raw);
    if (bare != null) return bare;
    try {
      return FusionStyle.byId(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  factory CosmeticWear.decode({
    String? cases,
    String? trails,
    String? fusion,
    String? ambience,
  }) => CosmeticWear(
    cases: decodeMap(cases, CaseStyle.byId),
    trails: decodeMap(trails, TrailStyle.byId),
    fusion: decodeFusion(fusion),
    ambience: decodeMap(ambience, HomeAmbience.byId),
  );

  /// Only what [owned] (by kind, as `OwnedCosmetics.decode` gives it) holds.
  CosmeticWear owned(Map<AthanorPieceKind, Set<String>> owned) {
    final c = owned[AthanorPieceKind.caseStyle] ?? const {};
    final t = owned[AthanorPieceKind.trail] ?? const {};
    final f = owned[AthanorPieceKind.fusionStyle] ?? const {};
    final a = owned[AthanorPieceKind.ambience] ?? const {};
    return CosmeticWear(
      cases: {
        for (final e in cases.entries)
          if (c.contains(e.value.id)) e.key: e.value,
      },
      trails: {
        for (final e in trails.entries)
          if (t.contains(e.value.id)) e.key: e.value,
      },
      fusion: fusion != null && f.contains(fusion!.id) ? fusion : null,
      ambience: {
        for (final e in ambience.entries)
          if (a.contains(e.value.id)) e.key: e.value,
      },
    );
  }
}
