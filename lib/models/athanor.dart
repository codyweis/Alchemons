// THE ATHANOR — the furnace on home where a pour draws a cosmetic.
//
// Tincture (earned in play) or gold is poured into a batch: a themed set of
// cosmetics. Each pour draws one piece the player does not own yet, so a
// batch is finished in at most as many pours as it has pieces, and the last
// piece brings the batch's capstone, which comes from nowhere else.
//
// The draw is weighted by rarity. [athanorNextPourOdds] is both what the odds
// sheet shows and what [athanorDraw] rolls on, so the two cannot disagree.
// Everything in a batch is cosmetic: nothing here changes power, odds or the
// economy, because a gold pour is a paid draw.

import 'dart:convert';
import 'dart:math';

// The batches on offer live in their own file.
export 'athanor_batches.dart' show kAthanorBatches;

/// How rare a piece is. Rarer pieces weigh less, so they tend to come later
/// in a batch; every piece still comes before the batch is done.
enum AthanorRarity {
  common(10, 'COMMON'),
  rare(5, 'RARE'),
  epic(2, 'EPIC');

  const AthanorRarity(this.weight, this.label);

  /// The piece's share of a pour against the others left in its batch.
  final int weight;
  final String label;
}

/// Which system a piece is granted through.
enum AthanorPieceKind {
  /// A creature aura: an inventory item ([AthanorPiece.grantRef] is its
  /// InvKeys key), worn through the alchemy effect slot.
  alchemyEffect,

  /// Home decor: [AthanorPiece.grantRef] is the HomeDecor id, owned as
  /// inventory `home.<id>`.
  homeDecor,

  /// A profile title: [AthanorPiece.grantRef] is the title id.
  title,

  /// A costume piece: an inventory item ([AthanorPiece.grantRef] is its
  /// InvKeys key), worn through the costume slots.
  costume,

  /// A dock set: [AthanorPiece.grantRef] is the DockSet id, owned through
  /// its settings row.
  dockSet,

  /// A specimen-case style for the Creatures tab, worn per creature.
  caseStyle,

  /// A trail left where a creature walks at home, worn per creature.
  trail,

  /// How every fusion plays, one for the whole game.
  fusionStyle,

  /// An ambience laid over a home realm.
  ambience,
}

extension AthanorPieceKindOwnership on AthanorPieceKind {
  /// The kinds owned through [OwnedCosmetics] rather than their own store.
  bool get ownedAsCosmetic => switch (this) {
    AthanorPieceKind.caseStyle ||
    AthanorPieceKind.trail ||
    AthanorPieceKind.fusionStyle ||
    AthanorPieceKind.ambience => true,
    _ => false,
  };
}

class AthanorPiece {
  const AthanorPiece({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.rarity,
    required this.grantRef,
  });

  /// Unique across every batch, e.g. 'ember.lantern'.
  final String id;
  final String name;

  /// One plain sentence: what it is.
  final String description;
  final AthanorPieceKind kind;
  final AthanorRarity rarity;

  /// What the kind's system knows the piece by (see [AthanorPieceKind]).
  final String grantRef;
}

class AthanorBatch {
  const AthanorBatch({
    required this.id,
    required this.name,
    required this.description,
    required this.pieces,
    required this.capstone,
  });

  final String id;
  final String name;
  final String description;

  /// The pieces a pour can draw.
  final List<AthanorPiece> pieces;

  /// Given with the batch's last piece; never drawn.
  final AthanorPiece capstone;
}

/// What one pour costs: 25 tincture, or 50 gold (author, 2026-10-11). At 10
/// tincture the one-time sources alone covered most of the five batches,
/// and a gold pour had no use.
const int kAthanorTincturePerPour = 25;
const int kAthanorGoldPerPour = 50;

/// How many of a Curio (small home decor) one draw gives.
const int kAthanorCurioCopies = 3;

/// Tincture given once, the first time the Athanor is opened, before its
/// back-pay ([athanorFirstFireTincture]).
const int kAthanorFirstFireTincture = 30;

/// The most first fire pays back for achievements and dungeon stars claimed
/// before the Athanor existed.
const int kAthanorFirstFireBackPayCap = 90;


/// The chance of each piece still left in [batch] on the next pour, given
/// the ids already [drawn]. In the batch's order; sums to 1 while anything
/// is left, and is empty once the batch is done.
List<(AthanorPiece, double)> athanorNextPourOdds(
  AthanorBatch batch,
  Set<String> drawn,
) {
  final left = [
    for (final p in batch.pieces)
      if (!drawn.contains(p.id)) p,
  ];
  final total = left.fold<int>(0, (sum, p) => sum + p.rarity.weight);
  if (total == 0) return const [];
  return [for (final p in left) (p, p.rarity.weight / total)];
}

/// One pour's piece from [batch], rolled on [athanorNextPourOdds]; null once
/// the batch is done.
AthanorPiece? athanorDraw(AthanorBatch batch, Set<String> drawn, Random rng) {
  final odds = athanorNextPourOdds(batch, drawn);
  if (odds.isEmpty) return null;
  final u = rng.nextDouble();
  var acc = 0.0;
  for (final (piece, chance) in odds) {
    acc += chance;
    if (u < acc) return piece;
  }
  return odds.last.$1;
}

// ── Earning tincture (docs/athanor_design.md) ──────────────────────────────
// Each is granted inside the flow that already pays that reward.

/// Survival, at run end: one for every five waves cleared.
int athanorSurvivalTincture(int wavesCleared) =>
    wavesCleared <= 0 ? 0 : wavesCleared ~/ 5;

/// A raid victory, by raid level (1–3).
int athanorRaidTincture(int raidLevel) => switch (raidLevel.clamp(1, 3)) {
  1 => 3,
  2 => 5,
  _ => 8,
};

/// Each dungeon star, the first time it is claimed.
const int kAthanorStarTincture = 3;

/// Each achievement claimed: one, since achievements already pay gold and
/// silver (author, 2026-10-11).
const int kAthanorAchievementTincture = 1;

/// The pureblood rite: finishing its last stage, and each weekly rite.
const int kAthanorRiteCompletionTincture = 5;
const int kAthanorRiteWeeklyTincture = 3;

/// A space contest won, once per level.
int athanorContestTincture(int level) => 2 * (level < 1 ? 1 : level);

/// Settings rows counting the achievement claims and dungeon stars that have
/// paid their tincture, so first fire pays back only the ones claimed
/// before the Athanor existed.
const String kAthanorPaidAchievementsKey = 'athanor_paid_achievements_v1';
const String kAthanorPaidStarsKey = 'athanor_paid_stars_v1';

/// What first fire gives: [kAthanorFirstFireTincture], plus what the
/// achievements and dungeon stars claimed before the Athanor would have
/// paid, up to [kAthanorFirstFireBackPayCap].
int athanorFirstFireTincture({
  required int unpaidAchievements,
  required int unpaidStars,
}) {
  final owed =
      max(0, unpaidAchievements) * kAthanorAchievementTincture +
      max(0, unpaidStars) * kAthanorStarTincture;
  return kAthanorFirstFireTincture + min(kAthanorFirstFireBackPayCap, owed);
}

/// The UTC day a daily pour belongs to, e.g. '2026-10-10' (the same key the
/// home chest used).
String athanorDayKey(DateTime time) =>
    time.toUtc().toIso8601String().split('T').first;

/// The inventory item a piece is granted as, or null for a kind that is
/// not an inventory item (a title).
String? athanorInventoryKeyFor(AthanorPiece piece) => switch (piece.kind) {
  AthanorPieceKind.alchemyEffect || AthanorPieceKind.costume => piece.grantRef,
  AthanorPieceKind.homeDecor => 'home.${piece.grantRef}',
  _ => null,
};

/// Every inventory item a piece or capstone in [batches] is granted as. The
/// shop never sells these.
Set<String> athanorInventoryKeys(List<AthanorBatch> batches) => {
  for (final batch in batches)
    for (final piece in [...batch.pieces, batch.capstone])
      ?athanorInventoryKeyFor(piece),
};

/// What the Athanor remembers, saved as the settings row [key] (JSON):
///
///     {"drawn": {"<batchId>": ["<pieceId>"]}, "capstones": ["<batchId>"],
///      "dailyKey": "2026-10-10", "firstFire": true}
///
/// It travels with the save. Decoding never throws: anything it cannot read
/// is left out, and a row it cannot read at all is a fresh state.
class AthanorState {
  const AthanorState({
    this.drawn = const {},
    this.capstones = const {},
    this.dailyKey,
    this.firstFire = false,
  });

  static const String key = 'athanor_v1';
  static const AthanorState empty = AthanorState();

  /// The pieces drawn so far, by batch id.
  final Map<String, Set<String>> drawn;

  /// The batches whose capstone has been given.
  final Set<String> capstones;

  /// The UTC day ([athanorDayKey]) of the last daily pour.
  final String? dailyKey;

  /// Whether the first-fire tincture has been given.
  final bool firstFire;

  Set<String> drawnIn(String batchId) => drawn[batchId] ?? const {};

  factory AthanorState.decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return empty;
    }
    if (json is! Map) return empty;

    Set<String> strings(Object? list) => {
      if (list is List)
        for (final v in list)
          if (v is String && v.isNotEmpty) v,
    };

    final drawn = <String, Set<String>>{};
    final rawDrawn = json['drawn'];
    if (rawDrawn is Map) {
      for (final e in rawDrawn.entries) {
        final ids = strings(e.value);
        if (e.key is String && ids.isNotEmpty) drawn[e.key as String] = ids;
      }
    }
    final day = json['dailyKey'];
    return AthanorState(
      drawn: drawn,
      capstones: strings(json['capstones']),
      dailyKey: day is String && day.isNotEmpty ? day : null,
      firstFire: json['firstFire'] == true,
    );
  }

  String encode() => jsonEncode({
    'drawn': {
      for (final e in drawn.entries)
        if (e.value.isNotEmpty) e.key: e.value.toList()..sort(),
    },
    'capstones': capstones.toList()..sort(),
    'dailyKey': dailyKey,
    'firstFire': firstFire,
  });

  AthanorState copyWith({
    Map<String, Set<String>>? drawn,
    Set<String>? capstones,
    String? dailyKey,
    bool? firstFire,
  }) => AthanorState(
    drawn: drawn ?? this.drawn,
    capstones: capstones ?? this.capstones,
    dailyKey: dailyKey ?? this.dailyKey,
    firstFire: firstFire ?? this.firstFire,
  );

  /// With [pieceId] drawn in [batchId].
  AthanorState withDrawn(String batchId, String pieceId) => copyWith(
    drawn: {
      ...drawn,
      batchId: {...drawnIn(batchId), pieceId},
    },
  );
}
