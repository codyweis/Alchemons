import 'dart:math';
import 'dart:ui';

import '../cosmic/cosmic_data.dart';

/// Repositions an authored cast without changing its count, power or lifetime.
/// Allies arrive in healing-priority order. Dust attaches through its own
/// runtime and does not use ground placement.
void placeSurvivalMaskTraps({
  required List<Projectile> traps,
  required Offset caster,
  required Offset ship,
  required List<Offset> allies,
  required Offset target,
  required Offset arenaCenter,
  required double arenaRadius,
}) {
  if (traps.isEmpty || traps.first.abilityFamily != 'mask') return;
  final element = traps.first.element;
  if (element == 'Dust') return;

  double footprint(Projectile p) => max(
    max(p.effectRadius, p.snareRadius),
    Projectile.radius * p.radiusMultiplier,
  );
  final margin = traps.map(footprint).reduce(max) + 12;
  Offset inside(Offset position, [double extra = 0]) {
    final limit = max(0.0, arenaRadius - margin - extra);
    final delta = position - arenaCenter;
    return delta.distance <= limit || delta.distance == 0
        ? position
        : arenaCenter + delta / delta.distance * limit;
  }

  if (element == 'Earth') {
    // Cover injured allies first, without spending every pool on a cluster
    // that a single pool can already heal. Spare pools make nearby refuges.
    final centers = <Offset>[];
    final radius = max(24.0, traps.first.effectRadius);
    for (final ally in allies.isEmpty ? [ship, caster] : allies) {
      final candidate = inside(ally);
      if (centers.any((p) => (candidate - p).distance < radius * 0.8)) continue;
      centers.add(candidate);
      if (centers.length == traps.length) break;
    }
    final refugeCenter = inside(ship, radius * 0.85);
    for (var i = 0; i < traps.length; i++) {
      if (i < centers.length) {
        traps[i].position = centers[i];
      } else {
        final angle = (i - centers.length) * 2.399963229728653;
        traps[i].position = inside(
          refugeCenter + Offset(cos(angle), sin(angle)) * radius * 0.85,
        );
      }
    }
    return;
  }

  if (element == 'Ice') {
    final positions = allies.isEmpty ? [ship, caster] : allies;
    final candidates = <Offset>[...positions];
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        candidates.add((positions[i] + positions[j]) / 2);
      }
    }
    final radius = traps.first.effectRadius;
    var best = inside(caster);
    var bestScore = -1.0;
    for (final candidate in candidates.map(inside)) {
      final covered = positions
          .where((p) => (p - candidate).distance <= radius)
          .length;
      // Prefer covering the ship when two locations cover the same number.
      final score =
          covered + ((ship - candidate).distance <= radius ? 0.25 : 0.0);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    for (final p in traps) {
      p.position = best;
    }
    return;
  }

  if (element == 'Spirit') {
    // A short collection route around the ship, within the pickup magnet's
    // reach. Keep the whole ring inside instead of flattening it at the wall.
    const reach = 130.0;
    final center = inside(ship, reach);
    for (var i = 0; i < traps.length; i++) {
      final angle = i * pi * 2 / traps.length;
      final radius = 85.0 + (i.isEven ? 0 : 45);
      traps[i].position = center + Offset(cos(angle), sin(angle)) * radius;
    }
    return;
  }

  final aim = inside(target);
  if (traps.length == 1) {
    traps.single.position = aim;
    return;
  }

  // One trap always covers the selected enemy. The rest form a compact
  // field on its approach toward the nearest defended body. Count increases
  // density; it does not multiply the scatter radius and waste upgraded casts.
  final defended = [ship, ...allies, arenaCenter]
    ..sort(
      (a, b) => (a - aim).distanceSquared.compareTo((b - aim).distanceSquared),
    );
  final delta = defended.first - aim;
  final direction = delta.distance > 0.01
      ? delta / delta.distance
      : const Offset(1, 0);
  final side = Offset(-direction.dy, direction.dx);
  final spread = (80.0 + footprint(traps.first) * 0.45).clamp(90.0, 155.0);
  final center = inside(aim + direction * (spread * 0.65), spread);
  traps.first.position = aim;
  for (var i = 1; i < traps.length; i++) {
    final fraction = (i - 0.5) / (traps.length - 1);
    final angle = i * 2.399963229728653;
    final radius = sqrt(fraction) * spread;
    traps[i].position =
        center +
        direction * (cos(angle) * radius) +
        side * (sin(angle) * radius * 0.75);
  }
}
