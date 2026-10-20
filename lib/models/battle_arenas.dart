import 'package:alchemons/database/daos/settings_dao.dart';

/// A floor a battle is fought on (games/cosmic/battle_arena_art.dart). Looks
/// only: none changes a rule. The obsidian floor is free; the rest are
/// bought in the shop (user, 2026-10-19), and a battle is fought in the
/// host's.
class BattleArena {
  const BattleArena({
    required this.id,
    required this.title,
    required this.line,
    this.gold = 0,
  });

  /// The floor's id (battleFloorFor).
  final String id;

  /// What it is called everywhere.
  final String title;

  /// One plain line for the shop and the hub.
  final String line;

  /// What it costs; 0 is free.
  final int gold;

  bool get free => gold == 0;

  String get offerId => 'arena.$id';

  /// The Settings row that says it is owned (it travels with the save).
  String get settingKey => 'arena_unlocked_$id';
}

/// Every arena, in the order the hub and the shop show them.
const List<BattleArena> kBattleArenas = [
  BattleArena(
    id: 'obsidian',
    title: 'Obsidian Floor',
    line: 'A slab of dark stone adrift in space.',
  ),
  BattleArena(
    id: 'orrery',
    title: 'Glass Orrery',
    line:
        'A battle arena of dark glass over turning brass rings. The glass '
        'lights where specials land.',
    gold: 300,
  ),
  BattleArena(
    id: 'tidal',
    title: 'Tidal Mirror',
    line:
        'A battle arena of still black water. Alchemons are mirrored in it, '
        'and it ripples where they step.',
    gold: 300,
  ),
  BattleArena(
    id: 'garden',
    title: 'Moonlit Garden',
    line:
        'A battle arena of old flagstones and moss under the moon, with '
        'fireflies that keep clear of the fight.',
    gold: 300,
  ),
];

/// The arena a battle uses when nothing else is chosen.
const String kDefaultBattleArena = 'obsidian';

/// The Settings row with the arena the player has chosen to host in.
const String kBattleArenaKey = 'battle_arena_v1';

BattleArena battleArenaOf(String id) => kBattleArenas.firstWhere(
  (a) => a.id == id,
  orElse: () => kBattleArenas.first,
);

/// The shop's arena sold as [offerId], or null.
BattleArena? battleArenaByOffer(String offerId) {
  for (final a in kBattleArenas) {
    if (!a.free && a.offerId == offerId) return a;
  }
  return null;
}

/// Whether [id] can be fought in: free, or bought.
Future<bool> battleArenaOwned(SettingsDao settings, String id) async {
  final arena = battleArenaOf(id);
  if (arena.free) return true;
  final v = await settings.getSetting(arena.settingKey);
  return v == '1' || v == 'true';
}

/// The ids of every arena that can be fought in.
Future<Set<String>> ownedBattleArenas(SettingsDao settings) async => {
  for (final a in kBattleArenas)
    if (await battleArenaOwned(settings, a.id)) a.id,
};

/// The arena the player hosts in: the one chosen, if it is still owned.
Future<String> chosenBattleArena(SettingsDao settings) async {
  final id = await settings.getSetting(kBattleArenaKey);
  if (id != null && await battleArenaOwned(settings, id)) return id;
  return kDefaultBattleArena;
}

Future<void> chooseBattleArena(SettingsDao settings, String id) =>
    settings.setSetting(kBattleArenaKey, id);
