import 'dart:convert';
import 'package:alchemons/database/daos/settings_dao.dart';
import 'story_page.dart'; // for StoryEvent

/// Versioned key so you can change format later without clobbering old saves.
const _kStorySeenKey = 'story_seen_v1';

class StoryPersistence {
  final SettingsDao settings;

  StoryPersistence(this.settings);

  Future<Set<StoryEvent>> loadSeen() async {
    final raw = await settings.getSetting(_kStorySeenKey);
    if (raw == null || raw.isEmpty) return <StoryEvent>{};

    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      final set = <StoryEvent>{};
      for (final s in list) {
        final match = StoryEvent.values.where((e) => e.name == s);
        if (match.isNotEmpty) set.add(match.first);
      }
      return set;
    } catch (_) {
      // If old/corrupt format, fail soft and start fresh.
      return <StoryEvent>{};
    }
  }

  Future<void> saveSeen(Set<StoryEvent> seen) async {
    final encoded = jsonEncode(seen.map((e) => e.name).toList());
    await settings.setSetting(_kStorySeenKey, encoded);
  }

  /// Optional: stream if you want live updates when another system toggles it.
  Stream<Set<StoryEvent>> watchSeen() {
    return settings.watchSetting(_kStorySeenKey).map((raw) {
      if (raw == null || raw.isEmpty) return <StoryEvent>{};
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        return list.fold<Set<StoryEvent>>({}, (acc, s) {
          final match = StoryEvent.values.where((e) => e.name == s);
          if (match.isNotEmpty) acc.add(match.first);
          return acc;
        });
      } catch (_) {
        return <StoryEvent>{};
      }
    });
  }
}
