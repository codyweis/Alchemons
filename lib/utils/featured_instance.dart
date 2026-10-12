// lib/utils/featured_instance.dart
//
// The Alchemon a player features: on their home screen, and on their page
// as their friends see it (FriendService). One rule for both, so a friend
// sees the one the player's own home shows.

import 'package:alchemons/database/alchemons_db.dart';

/// The settings row the chosen one is kept in (SettingsDao's
/// getFeaturedInstanceId / setFeaturedInstanceId).
const String kFeaturedInstanceSettingKey = 'featured_instance_id';

/// The featured Alchemon: the one chosen ('featured_instance_id'), else the
/// first prismatic one, else the one with the most Potential. Null with
/// none.
Future<CreatureInstance?> loadFeaturedInstance(AlchemonsDatabase db) async {
  final savedId = await db.settingsDao.getFeaturedInstanceId();
  if (savedId != null && savedId.isNotEmpty) {
    final chosen = await db.creatureDao.getInstance(savedId);
    if (chosen != null) return chosen;
  }

  final all = await db.creatureDao.listAllInstances();
  if (all.isEmpty) return null;

  final prismatic = all.where((ci) => ci.isPrismaticSkin).firstOrNull;
  if (prismatic != null) return prismatic;

  double potential(CreatureInstance c) =>
      (c.statSpeedPotential +
              c.statIntelligencePotential +
              c.statStrengthPotential +
              c.statBeautyPotential)
          .toDouble();
  all.sort((a, b) => potential(b).compareTo(potential(a)));
  return all.first;
}
