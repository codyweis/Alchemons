// OWNED COSMETICS — the store for cosmetic kinds that have no store of their
// own: specimen-case styles, trails, fusion styles and home ambiences. Each
// system keeps what is worn (per creature, per realm or for the whole game)
// itself; this only remembers what is owned.
//
// One settings row, `cosmetics_owned_v1` (JSON), so it travels with the save:
//
//     {"caseStyle": ["gilt"], "trail": ["hoarfrost"], ...}

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/athanor.dart';

abstract final class OwnedCosmetics {
  static const String key = 'cosmetics_owned_v1';

  /// What [raw] owns, by kind. Never throws: anything unreadable is left out.
  static Map<AthanorPieceKind, Set<String>> decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    Object? json;
    try {
      json = jsonDecode(raw);
    } catch (_) {
      return {};
    }
    if (json is! Map) return {};
    final owned = <AthanorPieceKind, Set<String>>{};
    for (final kind in AthanorPieceKind.values) {
      if (!kind.ownedAsCosmetic) continue;
      final list = json[kind.name];
      if (list is! List) continue;
      final ids = {
        for (final v in list)
          if (v is String && v.isNotEmpty) v,
      };
      if (ids.isNotEmpty) owned[kind] = ids;
    }
    return owned;
  }

  static String encode(Map<AthanorPieceKind, Set<String>> owned) => jsonEncode({
    for (final e in owned.entries)
      if (e.value.isNotEmpty) e.key.name: e.value.toList()..sort(),
  });

  /// The ids of [kind] owned on [db].
  static Future<Set<String>> owned(
    AlchemonsDatabase db,
    AthanorPieceKind kind,
  ) async =>
      decode(await db.settingsDao.getSetting(key))[kind] ?? const {};

  /// Owns [id] of [kind]. Safe to call inside a transaction.
  static Future<void> grant(
    AlchemonsDatabase db,
    AthanorPieceKind kind,
    String id,
  ) async {
    assert(kind.ownedAsCosmetic, '$kind has its own store');
    final owned = decode(await db.settingsDao.getSetting(key));
    owned[kind] = {...?owned[kind], id};
    await db.settingsDao.setSetting(key, encode(owned));
  }
}
