// ---- Models / Service (lightweight stub you can back with your DB) ----

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:flutter/material.dart';

enum FarmElement { fire, water, air, earth }

extension FarmElementX on FarmElement {
  String get label => switch (this) {
    FarmElement.fire => 'Fire Farm',
    FarmElement.water => 'Water Farm',
    FarmElement.air => 'Air Farm',
    FarmElement.earth => 'Earth Farm',
  };

  IconData get icon => switch (this) {
    FarmElement.fire => Icons.local_fire_department_rounded,
    FarmElement.water => Icons.water_drop_rounded,
    FarmElement.air => Icons.air_rounded,
    FarmElement.earth => Icons.terrain_rounded,
  };

  // Primary color tint for UI & test tube liquid
  Color get color => switch (this) {
    FarmElement.fire => const Color(0xFFFF6A3D),
    FarmElement.water => const Color(0xFF21C1FF),
    FarmElement.air => const Color(0xFFA3E1FF),
    FarmElement.earth => const Color(0xFFD1BFA3),
  };

  // Use DB keys here
  Map<String, int> get unlockCostDb => switch (this) {
    FarmElement.water => {'res_embers': 100},
    FarmElement.fire => {},
    FarmElement.air => {'res_embers': 40, 'res_droplets': 40},
    FarmElement.earth => {'res_embers': 25, 'res_droplets': 10},
  };
}

class HarvestJob {
  final String creatureInstanceId;
  final DateTime startUtc;
  final Duration duration;
  final int ratePerMinute; // computed once at start for display & payout

  HarvestJob({
    required this.creatureInstanceId,
    required this.startUtc,
    required this.duration,
    required this.ratePerMinute,
  });

  DateTime get endUtc => startUtc.add(duration);
  Duration get remaining => endUtc.difference(DateTime.now().toUtc()).isNegative
      ? Duration.zero
      : endUtc.difference(DateTime.now().toUtc());
  bool get completed => remaining == Duration.zero;
}

class HarvestFarmState {
  final FarmElement element;
  bool unlocked;
  int level;
  db.HarvestJob? active; // null when idle

  HarvestFarmState({
    required this.element,
    this.unlocked = false,
    this.level = 1,
    this.active,
  });

  bool get hasActive => active != null;

  bool get completed {
    final j = active;
    if (j == null) return false;
    final endMs = j.startUtcMs + j.durationMs;
    return DateTime.now().toUtc().millisecondsSinceEpoch >= endMs;
  }

  Duration? get remaining {
    final j = active;
    if (j == null) return null;
    final endMs = j.startUtcMs + j.durationMs;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final left = endMs - now;
    return Duration(milliseconds: left.clamp(0, j.durationMs));
  }
}
