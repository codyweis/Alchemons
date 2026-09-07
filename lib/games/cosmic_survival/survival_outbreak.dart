import 'dart:math';
import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'cosmic_survival_balance.dart';
import 'cosmic_survival_spawner.dart';

enum SurvivalOutbreakKind {
  verdigris,
  sanguine,
  quicksilver,
  nigredo,
  crystal,
  cinder,
  frost,
  voltaic,
  calcified,
  mirror,
}

/// A fixed milestone encounter, with finite, attackable sources.
class SurvivalOutbreak {
  SurvivalOutbreak._(this.kind, this.cores, this.anchors);

  static bool isOutbreakWave(int wave) => const [20, 30, 40, 50].contains(wave);

  static SurvivalOutbreak? forWave(
    int wave,
    Offset center,
    double arenaRadius, {
    required Random random,
    SurvivalOutbreakKind? previous,
  }) {
    if (!isOutbreakWave(wave)) return null;
    final choices = SurvivalOutbreakKind.values
        .where((kind) => kind != previous)
        .toList();
    final kind = choices[random.nextInt(choices.length)];
    final count = switch (kind) {
      SurvivalOutbreakKind.verdigris || SurvivalOutbreakKind.sanguine => 3,
      SurvivalOutbreakKind.quicksilver => 2,
      SurvivalOutbreakKind.nigredo || SurvivalOutbreakKind.calcified => 1,
      _ => 3,
    };
    final element = switch (kind) {
      SurvivalOutbreakKind.verdigris => 'Poison',
      SurvivalOutbreakKind.sanguine => 'Blood',
      SurvivalOutbreakKind.quicksilver => 'Spirit',
      SurvivalOutbreakKind.nigredo => 'Dark',
      SurvivalOutbreakKind.crystal => 'Crystal',
      SurvivalOutbreakKind.cinder => 'Fire',
      SurvivalOutbreakKind.frost => 'Ice',
      SurvivalOutbreakKind.voltaic => 'Lightning',
      SurvivalOutbreakKind.calcified => 'Earth',
      SurvivalOutbreakKind.mirror => 'Light',
    };
    final hp =
        tierBaseHp(EnemyTier.brute) *
        CosmicSurvivalBalance.enemyWaveHpScale(wave) *
        (count == 1 ? 3.0 : 1.25);
    final ring = min(420.0, arenaRadius * 0.42);
    final anchors = List<Offset>.generate(count, (i) {
      final angle = -pi / 2 + i * 2 * pi / count;
      return center + Offset(cos(angle), sin(angle)) * ring;
    });
    final cores = [
      for (final anchor in anchors)
        CosmicSurvivalEnemy(
          position: anchor,
          hp: hp,
          maxHp: hp,
          speed: 0,
          damage: 0,
          radius: count == 1 ? 40 : 28,
          tier: EnemyTier.brute,
          element: element,
          conduct: EnemyConduct.drift,
          target: CosmicEnemyTarget.ship,
          isPlagueCore: true,
          visualColor: colorFor(kind),
        ),
    ];
    return SurvivalOutbreak._(kind, cores, anchors);
  }

  final SurvivalOutbreakKind kind;
  final List<CosmicSurvivalEnemy> cores;
  final List<Offset> anchors;
  double elapsed = 0;
  final List<CosmicSurvivalEnemy> brood = [];
  static const grace = 4.0;
  static const period = 6.0;
  static const warningDuration = 1.5;
  int get remaining => cores.where((core) => !core.isDead).length;
  bool get cleared => remaining == 0;
  double get cycle => max(0.0, elapsed - grace) % period;
  bool get warning =>
      !cleared && elapsed >= grace && cycle >= period - warningDuration;
  bool get surging => !cleared && elapsed >= grace + period && cycle < 1.5;
  double get warningProgress =>
      warning ? (cycle - period + warningDuration) / warningDuration : 0;
  double get fieldRadius => switch (kind) {
    SurvivalOutbreakKind.verdigris => 170,
    SurvivalOutbreakKind.sanguine => 230,
    SurvivalOutbreakKind.quicksilver => 240,
    SurvivalOutbreakKind.nigredo => 180,
    _ => 200,
  };
  Color get color => colorFor(kind);
  static Color colorFor(SurvivalOutbreakKind kind) => switch (kind) {
    SurvivalOutbreakKind.verdigris => const Color(0xFFA8EF67),
    SurvivalOutbreakKind.sanguine => const Color(0xFFFF597A),
    SurvivalOutbreakKind.quicksilver => const Color(0xFF9BE8F5),
    SurvivalOutbreakKind.nigredo => const Color(0xFFC392FF),
    SurvivalOutbreakKind.crystal => const Color(0xFFE49CFF),
    SurvivalOutbreakKind.cinder => const Color(0xFFFFA45E),
    SurvivalOutbreakKind.frost => const Color(0xFF88BDFF),
    SurvivalOutbreakKind.voltaic => const Color(0xFFFFE872),
    SurvivalOutbreakKind.calcified => const Color(0xFFD9CCAB),
    SurvivalOutbreakKind.mirror => const Color(0xFFF6F0CB),
  };
  String get name => switch (kind) {
    SurvivalOutbreakKind.verdigris => 'VERDIGRIS BLOOM',
    SurvivalOutbreakKind.sanguine => 'SANGUINE MOLD',
    SurvivalOutbreakKind.quicksilver => 'QUICKSILVER BLIGHT',
    SurvivalOutbreakKind.nigredo => 'NIGREDO HEART',
    SurvivalOutbreakKind.crystal => 'VITRIFICATION',
    SurvivalOutbreakKind.cinder => 'CINDER BROOD',
    SurvivalOutbreakKind.frost => 'RIME FEVER',
    SurvivalOutbreakKind.voltaic => 'GALVANIC WEB',
    SurvivalOutbreakKind.calcified => 'CALCIFIED ROT',
    SurvivalOutbreakKind.mirror => 'MIRROR SPORES',
  };
  String get instruction => switch (kind) {
    SurvivalOutbreakKind.verdigris =>
      'Destroy the cysts. Leave the circles before they pulse.',
    SurvivalOutbreakKind.sanguine =>
      'Destroy the growths to stop nearby enemies healing.',
    SurvivalOutbreakKind.quicksilver =>
      'Destroy the wells. Escape their pull when they flare.',
    SurvivalOutbreakKind.nigredo =>
      'Destroy the heart before its tether drains the orb.',
    SurvivalOutbreakKind.crystal =>
      'Destroy the prisms. Their fields protect nearby enemies.',
    SurvivalOutbreakKind.cinder =>
      'Destroy the nests to stop new broods hatching.',
    SurvivalOutbreakKind.frost =>
      'Destroy the roots. Their frost surges slow your ship.',
    SurvivalOutbreakKind.voltaic =>
      'Destroy the anchors. Leave the links before they spark.',
    SurvivalOutbreakKind.calcified =>
      'Dodge the pulse, then attack while its shell is open.',
    SurvivalOutbreakKind.mirror =>
      'Destroy the pods. Sidestep their aimed spore volleys.',
  };

  /// At most one pulse per update: a stalled frame never queues burst damage.
  /// The host owns pause handling and damage; this clock owns the warning.
  bool advance(double dt) {
    if (cleared || dt <= 0) return false;
    final previous = max(0.0, elapsed - grace) ~/ period;
    elapsed += dt;
    return (max(0.0, elapsed - grace) ~/ period) > previous;
  }

  /// Roots stay attached to the arena despite knockback or teleport abilities.
  void anchorCores() {
    for (var i = 0; i < cores.length; i++) {
      cores[i].position = anchors[i];
      cores[i].knockbackVelocity = Offset.zero;
    }
  }

  double damageMultiplier(CosmicSurvivalEnemy enemy) {
    if (cleared) return 1;
    if (kind == SurvivalOutbreakKind.calcified &&
        enemy.isPlagueCore &&
        !surging) {
      return 0.3;
    }
    if (kind == SurvivalOutbreakKind.crystal &&
        !enemy.isPlagueCore &&
        cores.any((core) => contains(core, enemy.position))) {
      return 0.65;
    }
    return 1;
  }

  double movementMultiplier(Offset point) =>
      kind == SurvivalOutbreakKind.frost &&
          surging &&
          cores.any((core) => contains(core, point))
      ? 0.65
      : 1;

  Iterable<(Offset, Offset)> get links sync* {
    if (kind != SurvivalOutbreakKind.voltaic) return;
    for (var i = 0; i < cores.length; i++) {
      final a = cores[i];
      final b = cores[(i + 1) % cores.length];
      if (!a.isDead && !b.isDead) yield (a.position, b.position);
    }
  }

  static bool touchesLink(Offset point, Offset a, Offset b, double width) {
    final delta = b - a;
    final t = delta.distanceSquared == 0
        ? 0.0
        : (((point - a).dx * delta.dx + (point - a).dy * delta.dy) /
                  delta.distanceSquared)
              .clamp(0.0, 1.0);
    return (point - (a + delta * t)).distanceSquared <= width * width;
  }

  bool contains(CosmicSurvivalEnemy core, Offset point) =>
      !core.isDead &&
      (point - core.position).distanceSquared <= fieldRadius * fieldRadius;
}
