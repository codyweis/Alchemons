// lib/services/wild_rotation.dart
//
// Which four realms the wild map shows today. The map always has four
// circles round the Arcane. With only the first four realms there is nothing
// to choose; once realms have been bought in the shop (models/shop_scenes.dart)
// the four are drawn at random from all the realms owned, once a day, and held
// for the day so the map does not change under the player between visits.
//
// A realm bought today is always among today's four — it was bought to be
// played. The opening keeps the first four until it is over (the ship hunt
// sends the player round them), and the Arcane is not part of this: it is the
// centre circle.
//
// Only today's four spawn (see WildernessSpawnService._isSceneEligible), so a
// realm that is not out today has nothing waiting in it, and nothing the home
// screen counts.

import 'dart:math';

import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/models/shop_scenes.dart';

/// The first four realms, in the map's slot order: top left, top right,
/// bottom left, bottom right.
const List<String> kCoreRealms = ['valley', 'sky', 'volcano', 'swamp'];

abstract final class WildRotation {
  /// Where today's pick is kept: `yyyymmdd|four,ids|bought,ids known then`.
  static const String settingKey = 'wild_rotation_v1';

  /// Today's four realms, in slot order.
  static Future<List<String>> today(
    SettingsDao settings, {
    DateTime? now,
  }) async {
    final bought = await ownedShopScenes(settings);
    if (bought.isEmpty) return kCoreRealms;
    // The opening (and its ship hunt) is played on the first four.
    if (await settings.getSetting('cosmic_ship_unlocked') != '1') {
      return kCoreRealms;
    }
    final all = [
      ...kCoreRealms,
      for (final s in kShopScenes)
        if (bought.contains(s.sceneId)) s.sceneId,
    ];
    final day = _day(now ?? DateTime.now());

    final raw = await settings.getSetting(settingKey);
    final saved = _parse(raw);
    List<String> four;
    Set<String> known;
    if (saved != null && saved.day == day && saved.four.every(all.contains)) {
      four = saved.four;
      known = saved.known;
    } else {
      final r = Random(int.parse(day));
      four = ([...all]..shuffle(r)).take(4).toList();
      known = saved?.known ?? const {};
    }

    // Bought since the pick (or since the last one): it comes in today, in
    // place of one of the others at random — never another just bought.
    final fresh = [
      for (final id in all)
        if (bought.contains(id) && !known.contains(id)) id,
    ];
    final r = Random(int.parse(day) * 31 + four.length);
    for (final id in fresh) {
      if (four.contains(id)) continue;
      final swappable = [
        for (var i = 0; i < four.length; i++)
          if (!fresh.contains(four[i])) i,
      ];
      if (swappable.isEmpty) break;
      four[swappable[r.nextInt(swappable.length)]] = id;
    }

    // In the map's slot order: each of the first four keeps its own corner
    // when it is out, and the bought realms take the corners left over.
    final slots = List<String?>.filled(4, null);
    for (final id in four) {
      final home = kCoreRealms.indexOf(id);
      if (home >= 0) slots[home] = id;
    }
    final rest = [
      for (final id in all)
        if (four.contains(id) && !kCoreRealms.contains(id)) id,
    ];
    for (var i = 0; i < 4; i++) {
      slots[i] ??= rest.removeAt(0);
    }
    four = [for (final id in slots) id!];
    final next = '$day|${four.join(',')}|${bought.join(',')}';
    if (next != raw) await settings.setSetting(settingKey, next);
    return four;
  }

  /// Whether [sceneId] is one of today's four.
  static Future<bool> isOut(SettingsDao settings, String sceneId) async =>
      (await today(settings)).contains(sceneId);

  static String _day(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}'
      '${t.month.toString().padLeft(2, '0')}'
      '${t.day.toString().padLeft(2, '0')}';

  static ({String day, List<String> four, Set<String> known})? _parse(
    String? raw,
  ) {
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length != 3 || parts[0].length != 8) return null;
    final four = parts[1].split(',').where((s) => s.isNotEmpty).toList();
    if (four.length != 4) return null;
    return (
      day: parts[0],
      four: four,
      known: parts[2].split(',').where((s) => s.isNotEmpty).toSet(),
    );
  }
}
