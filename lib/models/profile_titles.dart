// lib/models/profile_titles.dart
//
// Profile titles: a few words worn under the name at the top of the
// profile. A player wears one, or none, of three kinds:
//
//   made         a colour and a word ("Red Fuser"), every one open to every
//                player from the start: [TitleColour] x [TitleWord]
//   achievement  given by collecting an achievement ("Let Lover" for the
//                Let family's): [kAchievementTitles]
//   Athanor      drawn from the Furnace: a piece of kind title grants its
//                grantRef as the title id, and the piece's name is the
//                title's words, so there is one list of them, not two
//
// What is kept is one settings row, `profile_titles_v1` (JSON), so it
// travels with the save:
//
//     {"owned": ["<titleId>"], "worn": "<titleId>" | null}
//
// "owned" holds the Athanor's only. An achievement's title is read off the
// achievement's collected flag rather than written down, so a save that
// collected one before titles existed has it, and nothing can disagree.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/services/campaign_journal_service.dart';

/// The first word of a made title.
enum TitleColour {
  red('Red'),
  blue('Blue'),
  green('Green'),
  brown('Brown'),
  yellow('Yellow');

  const TitleColour(this.word);
  final String word;
}

/// The second word of a made title.
enum TitleWord {
  alchemy('Alchemy'),
  fuser('Fuser'),
  survival('Survival'),
  cosmic('Cosmic'),
  mystery('Mystery');

  const TitleWord(this.word);
  final String word;
}

/// A colour and a word, worn as one title. Every one is open to everyone.
class MadeTitle {
  const MadeTitle(this.colour, this.word);

  final TitleColour colour;
  final TitleWord word;

  static const String _prefix = 'made.';

  /// `made.<colour>.<word>`, e.g. `made.red.fuser`.
  String get id => '$_prefix${colour.name}.${word.name}';

  String get words => '${colour.word} ${word.word}';

  /// Null for anything that is not a made title's id.
  static MadeTitle? fromId(String? id) {
    if (id == null || !id.startsWith(_prefix)) return null;
    final parts = id.substring(_prefix.length).split('.');
    if (parts.length != 2) return null;
    final colour = TitleColour.values.asNameMap()[parts[0]];
    final word = TitleWord.values.asNameMap()[parts[1]];
    if (colour == null || word == null) return null;
    return MadeTitle(colour, word);
  }

  @override
  bool operator ==(Object other) =>
      other is MadeTitle && other.colour == colour && other.word == word;

  @override
  int get hashCode => Object.hash(colour, word);
}

/// Titles given by collecting an achievement, by title id: the
/// achievement's id and the title's words. One for each family's "A
/// lineage of ..." (cultivate five of the family).
const kAchievementTitles = <String, (String, String)>{
  'family.let': ('fuse_let_5', 'Let Lover'),
  'family.pip': ('fuse_pip_5', 'Pip Person'),
  'family.horn': ('fuse_horn_5', 'Horn Hoarder'),
  'family.mask': ('fuse_mask_5', 'Mask Maniac'),
  'family.wing': ('fuse_wing_5', 'Winger'),
  'family.kin': ('fuse_kin_5', 'The Kin'),
  'family.mane': ('fuse_mane_5', 'Mane Main'),
};

class ProfileTitleState {
  const ProfileTitleState({
    this.owned = const {},
    this.earned = const {},
    this.worn,
  });

  static const ProfileTitleState empty = ProfileTitleState();

  /// The Athanor's titles, as kept in the row.
  final Set<String> owned;

  /// The achievements' titles whose achievement has been collected. Never
  /// written to the row.
  final Set<String> earned;

  /// The title worn, always one [canWear]; null for none.
  final String? worn;

  /// Owned, earned, or made.
  bool canWear(String id) =>
      owned.contains(id) || earned.contains(id) || MadeTitle.fromId(id) != null;

  /// The made title worn, if it is one.
  MadeTitle? get wornMade => MadeTitle.fromId(worn);

  /// Never throws: a row it cannot read is no titles, and a worn title that
  /// cannot be worn is taken off.
  factory ProfileTitleState.decode(
    String? raw, {
    Set<String> earned = const {},
  }) {
    if (raw == null || raw.isEmpty) {
      return ProfileTitleState(earned: earned);
    }
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return ProfileTitleState(earned: earned);
    }
    if (json is! Map) return ProfileTitleState(earned: earned);
    final list = json['owned'];
    final owned = <String>{
      if (list is List)
        for (final v in list)
          if (v is String && v.isNotEmpty) v,
    };
    final worn = json['worn'];
    final state = ProfileTitleState(owned: owned, earned: earned);
    return ProfileTitleState(
      owned: owned,
      earned: earned,
      worn: worn is String && state.canWear(worn) ? worn : null,
    );
  }

  String encode() =>
      jsonEncode({'owned': owned.toList()..sort(), 'worn': worn});
}

abstract final class ProfileTitles {
  static const String settingKey = 'profile_titles_v1';

  static Future<ProfileTitleState> load(AlchemonsDatabase db) async =>
      ProfileTitleState.decode(
        await db.settingsDao.getSetting(settingKey),
        earned: await _earned(db),
      );

  /// The achievements' titles whose achievement has been collected.
  static Future<Set<String>> _earned(AlchemonsDatabase db) async => {
    for (final e in kAchievementTitles.entries)
      if (await db.settingsDao.getSetting(
            CampaignJournalService.claimKey(e.value.$1),
          ) ==
          '1')
        e.key,
  };

  /// Adds [id] to the owned titles. Safe inside the caller's transaction (a
  /// pour grants through here); owning it already changes nothing.
  static Future<void> grant(AlchemonsDatabase db, String id) async {
    if (id.isEmpty) return;
    final state = await load(db);
    if (state.owned.contains(id)) return;
    await db.settingsDao.setSetting(
      settingKey,
      ProfileTitleState(owned: {...state.owned, id}, worn: state.worn).encode(),
    );
  }

  /// Wears [id], or takes the title off for null. False, and nothing
  /// changes, for a title that cannot be worn ([ProfileTitleState.canWear]).
  static Future<bool> wear(AlchemonsDatabase db, String? id) =>
      db.transaction(() async {
        final state = await load(db);
        if (id != null && !state.canWear(id)) return false;
        await db.settingsDao.setSetting(
          settingKey,
          ProfileTitleState(owned: state.owned, worn: id).encode(),
        );
        return true;
      });

  /// The title an achievement gives, by the achievement's id: its title id
  /// and words. Null for one that gives none.
  static (String, String)? forAchievement(String achievementId) {
    for (final e in kAchievementTitles.entries) {
      if (e.value.$1 == achievementId) return (e.key, e.value.$2);
    }
    return null;
  }

  /// Every title a player can earn, in the order the profile lists them:
  /// the achievements', then the Athanor's in batch order.
  static List<String> earnable({
    List<AthanorBatch> batches = kAthanorBatches,
  }) => [
    ...kAchievementTitles.keys,
    for (final batch in batches)
      for (final piece in [...batch.pieces, batch.capstone])
        if (piece.kind == AthanorPieceKind.title) piece.grantRef,
  ];

  /// The words of title [id]: a made title's colour and word, an
  /// achievement title's words, or the name of the Athanor piece that
  /// grants it. Null for an id none of them knows (a title since taken out
  /// of a batch).
  static String? nameOf(
    String id, {
    List<AthanorBatch> batches = kAthanorBatches,
  }) {
    if (MadeTitle.fromId(id) case final made?) return made.words;
    if (kAchievementTitles[id] case (_, final words)) return words;
    for (final batch in batches) {
      for (final piece in [...batch.pieces, batch.capstone]) {
        if (piece.kind == AthanorPieceKind.title && piece.grantRef == id) {
          return piece.name;
        }
      }
    }
    return null;
  }
}
