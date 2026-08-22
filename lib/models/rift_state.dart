// lib/models/rift_state.dart
//
// Pure-Dart model for a pending wilderness rift portal.
//
// Rifts used to live only in the Flame game instance: a 5% roll on entering a
// scene, gone the moment you left. Since entering one needs a faction-specific
// portal key you may not be holding, the loop was a trap — you saw the rare
// thing, left to go buy the key it demanded, and the act of leaving destroyed
// it. The next roll would likely be a different faction, so buying the key was
// often wasted too.
//
// A rift now persists for [kRiftWindow] real time, so the key can be fetched
// and the rift returned to. Only one is pending at a time across all scenes,
// so this stays a rare focused event rather than a portal backlog.
//
// No Flutter/DB imports — persistence lives in the scene layer and these
// rules are exercised headlessly. Mirrors raid_state.dart.

/// How long a rift stays open once it spawns.
///
/// Deliberately a fixed window from spawn rather than "until end of day": a
/// midnight cutoff gives a rift that appeared at 11:50pm ten usable minutes,
/// which feels identical to the bug this replaces.
const Duration kRiftWindow = Duration(hours: 8);

/// Chance of a rift appearing when a scene is entered and none is pending.
const double kRiftSpawnChance = 0.05;

class PendingRift {
  const PendingRift({
    required this.factionName,
    required this.sceneId,
    required this.spawnedUtc,
    this.window = kRiftWindow,
  });

  /// [RiftFaction.name] — kept as a string so this file stays free of the
  /// component layer that owns the enum.
  final String factionName;

  /// Where it appeared. The player has to return to this scene to enter it.
  final String sceneId;

  final DateTime spawnedUtc;
  final Duration window;

  DateTime get expiresUtc => spawnedUtc.add(window);

  bool isOpen(DateTime nowUtc) => nowUtc.isBefore(expiresUtc);

  Duration remaining(DateTime nowUtc) {
    final left = expiresUtc.difference(nowUtc);
    return left.isNegative ? Duration.zero : left;
  }

  /// "3h 20m" / "12m" / "expired" — for the map marker.
  String remainingLabel(DateTime nowUtc) {
    final left = remaining(nowUtc);
    if (left == Duration.zero) return 'expired';
    final h = left.inHours;
    final m = left.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '<1m';
  }

  String serialise() => [
    factionName,
    sceneId,
    spawnedUtc.millisecondsSinceEpoch,
    window.inSeconds,
  ].join('|');

  static PendingRift? deserialise(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('|');
    if (parts.length != 4) return null;
    final ms = int.tryParse(parts[2]);
    final sec = int.tryParse(parts[3]);
    if (ms == null || sec == null) return null;
    if (parts[0].isEmpty || parts[1].isEmpty) return null;
    return PendingRift(
      factionName: parts[0],
      sceneId: parts[1],
      spawnedUtc: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      window: Duration(seconds: sec),
    );
  }
}

/// What entering [sceneId] should do about rifts.
enum RiftSceneAction {
  /// Nothing — a rift is pending, but in a different scene.
  none,

  /// Re-show the rift already pending here.
  restore,

  /// No rift pending anywhere: roll for a new one.
  roll,
}

/// Pure decision: given the persisted rift and the scene being entered, say
/// what should happen. Expiry is handled here so callers never have to.
///
/// Returns [RiftSceneAction.roll] when nothing is pending, which includes the
/// case where the stored rift has run out — an expired rift frees the slot.
RiftSceneAction riftActionForScene({
  required PendingRift? pending,
  required String sceneId,
  required DateTime nowUtc,
}) {
  if (pending == null || !pending.isOpen(nowUtc)) return RiftSceneAction.roll;
  if (pending.sceneId == sceneId) return RiftSceneAction.restore;
  // Pending elsewhere: one rift at a time, so no roll here.
  return RiftSceneAction.none;
}
