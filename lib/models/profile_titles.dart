// lib/models/profile_titles.dart
//
// Profile titles: a few words worn under the name at the top of the
// profile. A player owns any number and wears one, or none.
//
// Both live in one settings row, `profile_titles_v1` (JSON), so they travel
// with the save:
//
//     {"owned": ["<titleId>"], "worn": "<titleId>" | null}
//
// Titles come from the Athanor: a piece of kind title grants its grantRef
// as the title id, and the piece's name is the title's words ([nameOf]), so
// there is one list of titles, not two that can disagree.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';

class ProfileTitleState {
  const ProfileTitleState({this.owned = const {}, this.worn});

  static const ProfileTitleState empty = ProfileTitleState();

  final Set<String> owned;

  /// The title worn, always one of [owned]; null for none.
  final String? worn;

  /// Never throws: a row it cannot read is no titles, and a worn title that
  /// is not owned is taken off.
  factory ProfileTitleState.decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return empty;
    }
    if (json is! Map) return empty;
    final list = json['owned'];
    final owned = <String>{
      if (list is List)
        for (final v in list)
          if (v is String && v.isNotEmpty) v,
    };
    final worn = json['worn'];
    return ProfileTitleState(
      owned: owned,
      worn: worn is String && owned.contains(worn) ? worn : null,
    );
  }

  String encode() =>
      jsonEncode({'owned': owned.toList()..sort(), 'worn': worn});
}

abstract final class ProfileTitles {
  static const String settingKey = 'profile_titles_v1';

  static Future<ProfileTitleState> load(AlchemonsDatabase db) async =>
      ProfileTitleState.decode(await db.settingsDao.getSetting(settingKey));

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
  /// changes, for a title not owned.
  static Future<bool> wear(AlchemonsDatabase db, String? id) =>
      db.transaction(() async {
        final state = await load(db);
        if (id != null && !state.owned.contains(id)) return false;
        await db.settingsDao.setSetting(
          settingKey,
          ProfileTitleState(owned: state.owned, worn: id).encode(),
        );
        return true;
      });

  /// The words of title [id]: the name of the Athanor piece that grants it.
  /// Null for an id no piece grants (a title since taken out of a batch).
  static String? nameOf(
    String id, {
    List<AthanorBatch> batches = kAthanorBatches,
  }) {
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
