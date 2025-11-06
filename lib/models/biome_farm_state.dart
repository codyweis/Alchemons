// lib/models/biome_farm_state.dart
import 'package:alchemons/models/harvest_biome.dart';
import 'package:flutter/material.dart';

class BiomeFarmState {
  final Biome biome;
  final bool unlocked;
  final int level;
  final String? activeElementId; // Which element is currently being extracted
  final HarvestJob? activeJob;

  BiomeFarmState({
    required this.biome,
    required this.unlocked,
    required this.level,
    this.activeElementId,
    this.activeJob,
  });

  bool get hasActive => activeJob != null;

  bool get completed {
    if (activeJob == null) return false;
    final now = DateTime.now().toUtc();
    final end = DateTime.fromMillisecondsSinceEpoch(
      activeJob!.startUtcMs + activeJob!.durationMs,
      isUtc: true,
    );
    return now.isAfter(end);
  }

  Duration? get remaining {
    if (activeJob == null) return null;
    final now = DateTime.now().toUtc();
    final end = DateTime.fromMillisecondsSinceEpoch(
      activeJob!.startUtcMs + activeJob!.durationMs,
      isUtc: true,
    );
    final rem = end.difference(now);
    return rem.isNegative ? Duration.zero : rem;
  }

  Color get currentColor {
    if (activeElementId == null) return biome.primaryColor;
    return biome.resourceColor;
  }
}

class HarvestJob {
  final String jobId;
  final String creatureInstanceId;
  final int startUtcMs;
  final int durationMs;
  final int ratePerMinute;

  HarvestJob({
    required this.jobId,
    required this.creatureInstanceId,
    required this.startUtcMs,
    required this.durationMs,
    required this.ratePerMinute,
  });

  factory HarvestJob.fromMap(Map<String, dynamic> map) {
    return HarvestJob(
      jobId: map['jobId'] as String,
      creatureInstanceId: map['creatureInstanceId'] as String,
      startUtcMs: map['startUtcMs'] as int,
      durationMs: map['durationMs'] as int,
      ratePerMinute: map['ratePerMinute'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'jobId': jobId,
      'creatureInstanceId': creatureInstanceId,
      'startUtcMs': startUtcMs,
      'durationMs': durationMs,
      'ratePerMinute': ratePerMinute,
    };
  }
}
