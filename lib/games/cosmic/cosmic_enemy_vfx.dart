// lib/games/cosmic/cosmic_enemy_vfx.dart
//
// How a survival enemy is drawn.
//
// Lifted out of cosmic_survival_game so the silhouette has one definition that
// the game, and the preview harness that renders the enemy contact sheets, can
// both reach. Nothing else could call it while it was a private method on the
// game class, which meant the only way to look at the roster was to play it.
//
// The three things it used to take from the game are gone or explicit:
//   * _enemyBlur() always returned null (blur is deliberately avoided in the
//     enemy pass), so it is inlined.
//   * _reduceMinorLabels is now the `reduceLabels` argument.
//   * the elite-affix TextPainter cache is module-level below.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:flutter/material.dart';

/// Cached label painters — laying these out per frame was never acceptable.
final Map<String, TextPainter> _eliteAffixPainters = {};

TextPainter _eliteAffixPainter(String label, Color color) {
  final key = 'elite:$label:${color.toARGB32()}';
  return _eliteAffixPainters.putIfAbsent(
    key,
    () => TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color.withValues(alpha: 0.95),
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EnemyVisual — the one thing the enemy renderer draws
//
// Both modes keep their own gameplay entity (their fields genuinely differ),
// but neither is handed to the renderer. Each maps onto this view struct, so
// there is exactly one silhouette definition instead of one per mode.
//
// Deliberately taxonomy-agnostic: the archetype mark is an int point count,
// not a variant enum, so the taxonomy in docs/enemy_taxonomy.md can change
// without the renderer knowing.
// ─────────────────────────────────────────────────────────────────────────────

class EnemyVisual {
  const EnemyVisual({
    required this.position,
    required this.angle,
    required this.radius,
    required this.element,
    required this.tier,
    required this.hpFraction,
    this.sigilPoints = 0,
    this.squash = 1.0,
    this.stretch = 1.0,
    this.hitFlash = 0,
    this.actionPhase,
    this.actionProgress = 0,
    this.actionAngle = 0,
    this.isElite = false,
    this.eliteAffix,
    this.flightSteering,
    this.rootTimer = 0,
  });

  final ui.Offset position;
  final double angle;
  final double radius;
  final String element;
  final EnemyTier tier;
  final double hpFraction;

  /// Points on the inscribed archetype mark; 0 draws none.
  final int sigilPoints;

  /// Body scaling, for bodies that read as squat or elongated.
  final double squash;
  final double stretch;

  final double hitFlash;

  /// The body's signature action, for the telegraph. Null when idle or when
  /// the body has no action (wisps fight by contact).
  final EnemyActionPhase? actionPhase;

  /// 0 → 1 through the current phase.
  final double actionProgress;

  /// Facing the action was locked to at wind-up.
  final double actionAngle;

  final bool isElite;
  final EliteAffix? eliteAffix;
  final FlightSteeringState? flightSteering;
  final double rootTimer;

  factory EnemyVisual.fromSurvival(CosmicSurvivalEnemy e) => EnemyVisual(
    position: e.position,
    angle: e.angle,
    radius: e.radius,
    element: e.element,
    tier: e.tier,
    hpFraction: e.hpFraction,
    sigilPoints: traitSigilPoints(e.trait),
    // Squash derived from the two real axes rather than a variant table.
    // A heavy charger reads squat, a stalker reads elongated, a standoff
    // shooter reads tall and thin.
    squash: _squashFor(e.conduct, e.trait, e.tier),
    stretch: _stretchFor(e.conduct, e.trait, e.tier),
    hitFlash: e.hitFlash,
    actionPhase: e.action.isBusy ? e.action.phase : null,
    actionProgress: e.action.progress(
      switch (e.action.phase) {
        EnemyActionPhase.windUp => kEnemyActions[e.tier]?.windUp ?? 0,
        EnemyActionPhase.commit => kEnemyActions[e.tier]?.commit ?? 0,
        EnemyActionPhase.recover => kEnemyActions[e.tier]?.recover ?? 0,
        EnemyActionPhase.idle => 0,
      },
    ),
    actionAngle: e.action.aimAngle,
    isElite: e.isElite,
    eliteAffix: e.eliteAffix,
    flightSteering: e.flightSteering,
    rootTimer: e.hornPlantRootTimer,
  );

  factory EnemyVisual.fromOpenWorld(CosmicEnemy e) => EnemyVisual(
    position: e.position,
    angle: e.angle,
    radius: e.radius,
    element: e.element,
    tier: e.tier,
    hpFraction: (e.health / e.maxHealth).clamp(0.0, 1.0),
    sigilPoints: openWorldVariantSigilPoints(e.variant),
    // The open world's one good idea the survival body lacked: crushers read
    // squat, pouncers read elongated. Carried across rather than dropped.
    squash: switch (e.variant) {
      CosmicEnemyVariant.crusher => 1.12,
      CosmicEnemyVariant.pouncer => 0.92,
      CosmicEnemyVariant.standard => 1.0,
    },
    stretch: switch (e.variant) {
      CosmicEnemyVariant.crusher => 0.92,
      CosmicEnemyVariant.pouncer => 1.12,
      CosmicEnemyVariant.standard => 1.0,
    },
    flightSteering: e.flightSteering,
  );
}

bool _heavy(EnemyTier t) =>
    t == EnemyTier.brute || t == EnemyTier.colossus;

double _squashFor(EnemyConduct c, EnemyTrait? t, EnemyTier tier) {
  if (t == EnemyTrait.breaker) return 1.12;
  if (t == EnemyTrait.summoner) return 1.08;
  if (t == EnemyTrait.splitter) return 1.04;
  if (c == EnemyConduct.charge && _heavy(tier)) return 1.20;
  if (c == EnemyConduct.stalk) return 0.90;
  if (c == EnemyConduct.standoff) return 0.94;
  return 1.0;
}

double _stretchFor(EnemyConduct c, EnemyTrait? t, EnemyTier tier) {
  if (t == EnemyTrait.breaker) return 0.93;
  if (t == EnemyTrait.summoner) return 1.08;
  if (t == EnemyTrait.splitter) return 0.96;
  if (c == EnemyConduct.charge && _heavy(tier)) return 0.88;
  if (c == EnemyConduct.stalk) return 1.16;
  if (c == EnemyConduct.standoff) return 1.10;
  return 1.0;
}

/// Open-world variants mapped onto the same mark vocabulary as survival's, so
/// a crusher reads the same in both modes.
int openWorldVariantSigilPoints(CosmicEnemyVariant v) => switch (v) {
  CosmicEnemyVariant.standard => 0,
  CosmicEnemyVariant.crusher => 6,
  CosmicEnemyVariant.pouncer => 5,
};

/// Survival's entry point.
void drawSurvivalEnemy({
  required Canvas canvas,
  required CosmicSurvivalEnemy enemy,
  required double time,
  bool reduceLabels = false,
}) => drawEnemy(
  canvas: canvas,
  enemy: EnemyVisual.fromSurvival(enemy),
  time: time,
  reduceLabels: reduceLabels,
);

/// The one enemy silhouette. Both modes map their entity onto [EnemyVisual]
/// and come through here, so there is a single definition to change.
void drawEnemy({
  required Canvas canvas,
  required EnemyVisual enemy,
  required double time,
  bool reduceLabels = false,
}) {
  final eColor = elementColor(enemy.element);
  // Dive telegraph: a tightening ring while the enemy rears back, so the
  // hover/dive swoop is readable and dodgeable (shared steering state).
  final steering = enemy.flightSteering;
  if (steering != null && steering.showTelegraphRing) {
    canvas.drawCircle(
      enemy.position,
      enemy.radius + 5 + steering.windupTimer * 42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Color.lerp(
          eColor,
          Colors.white,
          0.5,
        )!.withValues(alpha: 0.72),
    );
  }
  final affixColor = switch (enemy.eliteAffix) {
    EliteAffix.bulwarked => const Color(0xFF7DD3FC),
    EliteAffix.volatile => const Color(0xFFFFA34A),
    EliteAffix.vampiric => const Color(0xFFFB7185),
    EliteAffix.overclocked => const Color(0xFFFDE047),
    EliteAffix.relentless => const Color(0xFFA78BFA),
    null => eColor,
  };
  final flashColor = enemy.hitFlash > 0
      ? Color.lerp(eColor, Colors.white, enemy.hitFlash)!
      : eColor;
  final r = enemy.radius;
  final elapsed = time;
  final variantScale = enemy.squash;
  final variantYScale = enemy.stretch;

  canvas.save();
  canvas.translate(enemy.position.dx, enemy.position.dy);
  if (variantScale != 1.0 || variantYScale != 1.0) {
    canvas.rotate(enemy.angle * 0.08);
    canvas.scale(variantScale, variantYScale);
  }

  // Outer elemental aura (all tiers)
  canvas.drawCircle(
    Offset.zero,
    r * 2.0,
    Paint()
      ..color = eColor.withValues(alpha: 0.10)
      ..maskFilter = null,
  );

  // Horn+Plant root visual: green vines wrap the enemy. Layered
  // soft green halo + 4 curved vine arcs spiraling around the
  // perimeter. Pulses while rooted.
  if (enemy.rootTimer > 0) {
    final rootPulse = 0.78 + 0.22 * sin(elapsed * 3.0 + enemy.angle);
    const plantColor = Color(0xFF6BBE52);
    const darkPlant = Color(0xFF2F6E22);
    // Soft green halo at the wrap radius.
    canvas.drawCircle(
      Offset.zero,
      r * 1.55,
      Paint()
        ..color = plantColor.withValues(alpha: 0.22 * rootPulse)
        ..maskFilter = null,
    );
    // 4 curved vine arcs around the enemy.
    final vinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = darkPlant.withValues(alpha: 0.75 * rootPulse);
    for (var i = 0; i < 4; i++) {
      final base = i * pi / 2 + elapsed * 0.6;
      final start = Offset(cos(base), sin(base)) * r * 0.5;
      final mid = Offset(cos(base + 0.55), sin(base + 0.55)) * r * 1.25;
      final end = Offset(cos(base + 1.1), sin(base + 1.1)) * r * 0.7;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
      canvas.drawPath(path, vinePaint);
    }
    // Small leaf pips on each vine tip.
    final leafPaint = Paint()
      ..color = plantColor.withValues(alpha: 0.85 * rootPulse)
      ..maskFilter = null;
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2 + elapsed * 0.6 + 1.1;
      canvas.drawCircle(Offset(cos(a), sin(a)) * r * 0.7, 2.3, leafPaint);
    }
  }

  if (enemy.isElite && enemy.eliteAffix != null) {
    canvas.drawCircle(
      Offset.zero,
      r * 2.3,
      Paint()
        ..color = affixColor.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  switch (enemy.tier) {
    case EnemyTier.wisp:
      final flicker = 0.7 + 0.3 * sin(elapsed * 6 + enemy.angle * 5);
      final wobble = r * flicker;
      canvas.drawCircle(
        Offset.zero,
        wobble,
        Paint()
          ..shader = ui.Gradient.radial(
            const Offset(-1, -1),
            wobble,
            [
              Colors.white.withValues(alpha: 0.7 * flicker),
              flashColor.withValues(alpha: 0.5 * flicker),
              flashColor.withValues(alpha: 0.0),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
      canvas.drawCircle(
        Offset.zero,
        r * 0.15,
        Paint()
          ..color = Colors.red.withValues(alpha: 0.9 * flicker)
          ..maskFilter = null,
      );

    case EnemyTier.sentinel:
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(-r * 0.25, -r * 0.25),
            r * 1.2,
            [
              Color.lerp(
                flashColor,
                Colors.white,
                0.35,
              )!.withValues(alpha: 0.9),
              flashColor.withValues(alpha: 0.8),
              Color.lerp(flashColor, Colors.black, 0.5)!.withValues(alpha: 0.7),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
      canvas.drawCircle(
        Offset(-r * 0.2, -r * 0.25),
        r * 0.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..maskFilter = null,
      );
      canvas.save();
      canvas.rotate(elapsed * 0.3 + enemy.angle);
      final ringR = r * 1.8;
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..color = eColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      for (var i = 0; i < 3; i++) {
        final orbitAngle = elapsed * (1.2 + i * 0.4) + i * pi * 2 / 3;
        final ox = cos(orbitAngle) * ringR;
        final oy = sin(orbitAngle) * ringR;
        final satR = r * (0.18 + i * 0.04);
        canvas.drawCircle(
          Offset(ox, oy),
          satR * 2,
          Paint()
            ..color = eColor.withValues(alpha: 0.2)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          Offset(ox, oy),
          satR,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(ox - satR * 0.3, oy - satR * 0.3),
              satR,
              [
                Colors.white.withValues(alpha: 0.7),
                eColor.withValues(alpha: 0.8),
              ],
            ),
        );
      }
      canvas.restore();
      canvas.drawCircle(
        Offset.zero,
        r * 0.25,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..maskFilter = null,
      );

    case EnemyTier.drone:
      final twitch = sin(elapsed * 12 + enemy.angle * 7) * r * 0.08;
      final hexPath = Path();
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3 - pi / 6;
        final hr = r * (1.0 + (i.isEven ? twitch / r : -twitch / r));
        final hx = cos(a) * hr;
        final hy = sin(a) * hr;
        if (i == 0) {
          hexPath.moveTo(hx, hy);
        } else {
          hexPath.lineTo(hx, hy);
        }
      }
      hexPath.close();
      canvas.drawPath(
        hexPath,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, -r),
            Offset(0, r),
            [
              Color.lerp(flashColor, Colors.white, 0.4)!.withValues(alpha: 0.9),
              flashColor.withValues(alpha: 0.85),
              Color.lerp(flashColor, Colors.black, 0.3)!.withValues(alpha: 0.7),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
      canvas.drawPath(
        hexPath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      final eyePulse = 0.6 + 0.4 * sin(elapsed * 8 + enemy.angle * 3);
      canvas.drawCircle(
        Offset.zero,
        r * 0.2,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9 * eyePulse)
          ..maskFilter = null,
      );
      for (var s = 0; s < 2; s++) {
        final sparkAngle = enemy.angle + pi + (s - 0.5) * 0.4;
        final sparkDist = r * (1.2 + 0.3 * sin(elapsed * 10 + s * 3));
        canvas.drawCircle(
          Offset(cos(sparkAngle) * sparkDist, sin(sparkAngle) * sparkDist),
          r * 0.12,
          Paint()
            ..color = eColor.withValues(alpha: 0.5 * eyePulse)
            ..maskFilter = null,
        );
      }

    case EnemyTier.phantom:
      // Hollow: you see space through it. The old phantom was a dimmed brute —
      // same silhouette, lower alpha — which made it both the least visible
      // enemy in the game and indistinguishable from the tier above it.
      final ghostPhase = elapsed * 1.5 + enemy.angle * 2;
      final breathe = 1.0 + 0.10 * sin(ghostPhase);
      final gap = 0.55 + 0.25 * sin(ghostPhase * 0.7);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.30
        ..color = eColor.withValues(alpha: 0.72);
      // Two broken arcs leave the body open at the seams.
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * breathe),
        ghostPhase * 0.4,
        pi * 2 - gap,
        false,
        ringPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * 0.58 * breathe),
        -ghostPhase * 0.6,
        pi * 1.1,
        false,
        ringPaint
          ..strokeWidth = r * 0.16
          ..color = Color.lerp(eColor, Colors.white, 0.5)!.withValues(
            alpha: 0.55,
          ),
      );
      // A single bright pip marks where the mass actually is.
      canvas.drawCircle(
        Offset.zero,
        r * 0.17,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * breathe),
      );

    case EnemyTier.brute:
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(-r * 0.2, -r * 0.2),
            r * 1.3,
            [
              Color.lerp(flashColor, Colors.black, 0.3)!.withValues(alpha: 0.9),
              Color.lerp(flashColor, Colors.black, 0.6)!.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.7),
            ],
            [0.0, 0.5, 1.0],
          ),
      );
      for (var crack = 0; crack < 5; crack++) {
        final ca = crack * pi * 2 / 5 + elapsed * 0.2;
        final crackPath = Path()
          ..moveTo(0, 0)
          ..lineTo(cos(ca) * r * 0.9, sin(ca) * r * 0.9);
        canvas.drawPath(
          crackPath,
          Paint()
            ..color = eColor.withValues(
              alpha: 0.6 + 0.2 * sin(elapsed * 2 + crack),
            )
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke
            ..maskFilter = null,
        );
      }
      canvas.drawCircle(
        Offset.zero,
        r * 1.3,
        Paint()
          ..color = eColor.withValues(alpha: 0.08)
          ..maskFilter = null,
      );
      final bruteHpFrac = enemy.hpFraction;
      if (bruteHpFrac < 1.0) {
        final barW = r * 2.5;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(0, -r - 8), width: barW, height: 3),
            const Radius.circular(1.5),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-barW / 2, -r - 8 - 1.5, barW * bruteHpFrac, 3),
            const Radius.circular(1.5),
          ),
          Paint()..color = Color.lerp(Colors.red, eColor, bruteHpFrac)!,
        );
      }

    case EnemyTier.colossus:
      final pulse = 0.95 + 0.05 * sin(elapsed * 1.2 + enemy.angle);
      canvas.drawCircle(
        Offset.zero,
        r * pulse,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(-r * 0.3, -r * 0.3),
            r * 1.5,
            [
              Color.lerp(
                flashColor,
                Colors.white,
                0.15,
              )!.withValues(alpha: 0.85),
              Color.lerp(flashColor, Colors.black, 0.3)!.withValues(alpha: 0.8),
              Colors.black.withValues(alpha: 0.7),
            ],
            [0.0, 0.4, 1.0],
          ),
      );
      for (var t = 0; t < 6; t++) {
        final baseAngle = t * pi / 3 + elapsed * 0.08;
        final wave = sin(elapsed * 1.5 + t * 1.2) * 0.3;
        final tentacle = Path()
          ..moveTo(cos(baseAngle) * r * 0.8, sin(baseAngle) * r * 0.8);
        final midDist = r * 1.6;
        final tipDist = r * (2.2 + 0.3 * sin(elapsed * 0.8 + t));
        final ctrlAngle = baseAngle + wave;
        tentacle.quadraticBezierTo(
          cos(ctrlAngle) * midDist,
          sin(ctrlAngle) * midDist,
          cos(baseAngle + wave * 0.5) * tipDist,
          sin(baseAngle + wave * 0.5) * tipDist,
        );
        canvas.drawPath(
          tentacle,
          Paint()
            ..color = eColor.withValues(alpha: 0.35 + 0.15 * sin(elapsed + t))
            ..strokeWidth = 2.5 - t * 0.2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = null,
        );
      }
      canvas.drawCircle(
        Offset.zero,
        r * 0.35,
        Paint()
          ..color = eColor.withValues(alpha: 0.4 + 0.2 * sin(elapsed * 2))
          ..maskFilter = null,
      );
      canvas.drawCircle(
        Offset.zero,
        r * 0.15,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
      canvas.drawCircle(
        Offset.zero,
        r * 1.5,
        Paint()
          ..color = eColor.withValues(alpha: 0.05)
          ..maskFilter = null,
      );
      final colHpFrac = enemy.hpFraction;
      if (colHpFrac < 1.0) {
        final barW = r * 3.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(0, -r - 10), width: barW, height: 4),
            const Radius.circular(2),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.6),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-barW / 2, -r - 10 - 2, barW * colHpFrac, 4),
            const Radius.circular(2),
          ),
          Paint()..color = Color.lerp(Colors.red, eColor, colHpFrac)!,
        );
      }
  }

  // Variant mark. This is the only thing on an ordinary enemy that says which
  // of the eight behaviours it is — a splitter that will burst into drones and
  // a plain sentinel were pixel-identical before this.
  _drawActionTelegraph(canvas, enemy, eColor, r, elapsed);

  drawEnemyArchetypeMark(
    canvas: canvas,
    centre: Offset.zero,
    radius: r,
    color: Color.lerp(eColor, const Color(0xFFFFFFFF), 0.55)!,
    points: enemy.sigilPoints,
    time: elapsed,
    alpha: 0.8,
  );

  if (!reduceLabels && enemy.isElite && enemy.eliteAffix != null) {
    final label = switch (enemy.eliteAffix!) {
      EliteAffix.bulwarked => 'BULWARK',
      EliteAffix.volatile => 'VOLATILE',
      EliteAffix.vampiric => 'VAMPIRIC',
      EliteAffix.overclocked => 'OVERCLOCK',
      EliteAffix.relentless => 'RELENTLESS',
    };
    final tp = _eliteAffixPainter(label, affixColor);
    tp.paint(canvas, Offset(-tp.width / 2, -r - 18));
  }

  canvas.restore();
}

/// Cached boss-name painters, module-level for the same reason the affix ones
/// are: laying out text per frame is not acceptable in a render pass.
final Map<String, TextPainter> _bossNamePainters = {};

TextPainter _bossNamePainter(String name, Color color) {
  final key = 'boss:$name:${color.toARGB32()}';
  return _bossNamePainters.putIfAbsent(
    key,
    () => TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: color.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(),
  );
}

void drawSurvivalBoss({
  required Canvas canvas,
  required SurvivalBoss boss,
  required double time,
  bool reduceGlows = false,
}) {
  final bColor = boss.color;
  final r = boss.radius;
  final elapsed = time;
  final pulse = 0.8 + 0.2 * sin(elapsed * 2.5);
  final spawnTarget = boss.spawnTargetPosition;
  if (boss.isSpawning && spawnTarget != null) {
    final introT = 1.0 - (boss.spawnIntroTimer / boss.spawnIntroDuration);
    final portalPulse = 0.7 + 0.3 * sin(elapsed * 8.0);
    final portalRadius = r * (1.7 + 0.25 * portalPulse);
    canvas.drawCircle(
      spawnTarget,
      portalRadius,
      Paint()
        ..color = bColor.withValues(alpha: 0.14 + 0.08 * (1.0 - introT))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = null,
    );
    canvas.drawCircle(
      spawnTarget,
      r * (1.05 + 0.12 * portalPulse),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18 + 0.10 * portalPulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    for (var i = 0; i < 6; i++) {
      final a = elapsed * 1.7 + i * pi / 3;
      final inner = spawnTarget + Offset(cos(a), sin(a)) * (r * 0.8);
      final outer = spawnTarget + Offset(cos(a), sin(a)) * (r * 1.45);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = bColor.withValues(alpha: 0.32)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }
    switch (boss.discipline) {
      case SurvivalBossDiscipline.riftcaller:
        for (var i = 0; i < 4; i++) {
          final phase = elapsed * 0.95 + i * pi / 2;
          final node =
              spawnTarget +
              Offset(cos(phase), sin(phase)) * (portalRadius * 1.12);
          canvas.drawCircle(
            node,
            r * 0.15,
            Paint()
              ..color = bColor.withValues(alpha: 0.28)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
          canvas.drawLine(
            spawnTarget,
            node,
            Paint()
              ..color = bColor.withValues(alpha: 0.20)
              ..strokeWidth = 1.4,
          );
        }
      case SurvivalBossDiscipline.siegebreaker:
        for (var i = 0; i < 3; i++) {
          final ring = portalRadius * (0.68 + i * 0.24);
          canvas.drawCircle(
            spawnTarget,
            ring,
            Paint()
              ..color = bColor.withValues(alpha: 0.26 - i * 0.06)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          );
        }
      case SurvivalBossDiscipline.conductor:
        canvas.drawCircle(
          spawnTarget,
          portalRadius * 1.22,
          Paint()
            ..color = bColor.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
        for (var i = 0; i < 8; i++) {
          final a = elapsed * 0.8 + i * pi / 4;
          final node =
              spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 1.1);
          canvas.drawCircle(
            node,
            r * 0.1,
            Paint()..color = Colors.white.withValues(alpha: 0.45),
          );
        }
      case SurvivalBossDiscipline.duelist:
        for (final offset in const [-0.22, 0.22]) {
          final a = elapsed * 1.4 + offset;
          final inner =
              spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 0.35);
          final outer =
              spawnTarget +
              Offset(cos(a + 0.04), sin(a + 0.04)) * (portalRadius * 1.3);
          canvas.drawLine(
            inner,
            outer,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.58)
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round,
          );
        }
      case SurvivalBossDiscipline.artillery:
        for (var i = 0; i < 3; i++) {
          final arcRadius = portalRadius * (0.7 + i * 0.22);
          canvas.drawArc(
            Rect.fromCircle(center: spawnTarget, radius: arcRadius),
            -pi / 2 + i * 0.38 + elapsed * 0.18,
            pi * 0.9,
            false,
            Paint()
              ..color = bColor.withValues(alpha: 0.34 - i * 0.08)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0,
          );
        }
      case SurvivalBossDiscipline.trickster:
        for (var i = 0; i < 3; i++) {
          final phase = elapsed * 2.6 + i * 2.1;
          final echo =
              spawnTarget +
              Offset(cos(phase), sin(phase * 1.2)) * (portalRadius * 0.32);
          canvas.drawCircle(
            echo,
            r * (0.24 - i * 0.03),
            Paint()
              ..color = bColor.withValues(alpha: 0.22 - i * 0.05)
              ..maskFilter = null,
          );
        }
      case SurvivalBossDiscipline.standard:
        switch (boss.type) {
          case BossType.charger:
          case BossType.skirmisher:
            final a = elapsed * 1.7;
            final inner =
                spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 0.25);
            final outer =
                spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 1.28);
            canvas.drawLine(
              inner,
              outer,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.5)
                ..strokeWidth = 3
                ..strokeCap = StrokeCap.round,
            );
          case BossType.gunner:
          case BossType.carrier:
            canvas.drawArc(
              Rect.fromCircle(center: spawnTarget, radius: portalRadius * 1.08),
              -pi / 2 + elapsed * 0.15,
              pi * 1.2,
              false,
              Paint()
                ..color = bColor.withValues(alpha: 0.28)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.2,
            );
          case BossType.bulwark:
          case BossType.warden:
            canvas.drawCircle(
              spawnTarget,
              portalRadius * 0.78,
              Paint()
                ..color = bColor.withValues(alpha: 0.18)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.6,
            );
        }
    }
  }

  canvas.save();
  canvas.translate(boss.position.dx, boss.position.dy);

  final auraColor = boss.enraged
      ? Colors.red.withValues(alpha: 0.15 * pulse)
      : bColor.withValues(alpha: 0.12 * pulse);
  if (!reduceGlows) {
    canvas.drawCircle(
      Offset.zero,
      r * 2.5,
      Paint()
        ..color = auraColor
        ..maskFilter = null,
    );
  }

  canvas.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(-r * 0.3, -r * 0.3),
        r * 1.5,
        [
          Color.lerp(bColor, Colors.white, 0.2)!.withValues(alpha: 0.85),
          bColor.withValues(alpha: 0.8),
          Color.lerp(bColor, Colors.black, 0.5)!.withValues(alpha: 0.7),
        ],
        [0.0, 0.4, 1.0],
      ),
  );

  if (boss.shieldUp) {
    canvas.drawCircle(
      Offset.zero,
      r * 1.3,
      Paint()
        ..color = Colors.cyan.withValues(alpha: 0.2 + 0.1 * sin(elapsed * 3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = null,
    );
  }

  for (var i = 0; i < 6; i++) {
    final orbitAngle = elapsed * 0.8 + i * pi / 3;
    final orbitR = r * 1.4;
    final mx = cos(orbitAngle) * orbitR;
    final my = sin(orbitAngle) * orbitR;
    canvas.drawCircle(
      Offset(mx, my),
      3,
      Paint()
        ..color = bColor.withValues(alpha: 0.6 + 0.2 * sin(elapsed * 2 + i)),
    );
  }

  canvas.drawCircle(
    Offset.zero,
    r * 0.3,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.4 * pulse)
      ..maskFilter = null,
  );

  final hpFrac = boss.hpFraction;
  final barW = r * 3.0;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -r - 14), width: barW, height: 5),
      const Radius.circular(2.5),
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.7),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-barW / 2, -r - 14 - 2.5, barW * hpFrac, 5),
      const Radius.circular(2.5),
    ),
    Paint()
      ..color = boss.enraged
          ? Color.lerp(Colors.red, Colors.orange, sin(elapsed * 4) * 0.5 + 0.5)!
          : Color.lerp(Colors.red, bColor, hpFrac)!,
  );

  // Venting: planted, overheated and open. This is the window that pays you
  // for closing the distance, so it has to be unmistakable.
  if (boss.isVenting) {
    final vent = (boss.overheatTimer / 1.9).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      r * (1.25 + 0.15 * sin(elapsed * 9)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = const Color(0xFFFF7043).withValues(alpha: 0.75 * vent),
    );
    for (var i = 0; i < 6; i++) {
      final a = elapsed * 2.2 + i * pi / 3;
      canvas.drawCircle(
        Offset(cos(a), sin(a)) * r * 1.05,
        3.0,
        Paint()
          ..color = const Color(0xFFFFC078).withValues(alpha: 0.85 * vent),
      );
    }
  }

  // Discipline sigil — the lair boss's treatment, brought to survival. Seven
  // disciplines rendered as the same sphere before this, so an artillery boss
  // that snipes from the rim looked exactly like a duelist that closes.
  drawBossSigil(
    canvas: canvas,
    centre: Offset.zero,
    radius: r,
    color: Color.lerp(bColor, const Color(0xFFFFFFFF), 0.35)!,
    points: disciplineSigilPoints(boss.discipline),
    motes: bossTypeMotes(boss.type),
    time: elapsed,
    alpha: reduceGlows ? 0.75 : 1.0,
  );

  final nameTP = _bossNamePainter(boss.template.name, bColor);
  nameTP.paint(canvas, Offset(-nameTP.width / 2, -r - 24));

  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// Open-world enemy
//
// Was a second, independent 484-line renderer using MaskFilter.blur in fifteen
// places. It is now the same silhouette survival draws: the open world maps its
// CosmicEnemy onto EnemyVisual and calls drawEnemy. The crusher/pouncer squash
// that only the open world had is preserved through the view struct.
// ─────────────────────────────────────────────────────────────────────────────

void drawOpenWorldEnemy({
  required Canvas canvas,
  required CosmicEnemy e,
  required double time,
}) => drawEnemy(
  canvas: canvas,
  enemy: EnemyVisual.fromOpenWorld(e),
  time: time,
);

// ─────────────────────────────────────────────────────────────────────────────
// Open-world boss
//
// The lair boss you fight in roaming space — a third enemy renderer, distinct
// again from survival's drawSurvivalBoss. Six MaskFilter.blur sites here.
// ─────────────────────────────────────────────────────────────────────────────

void drawOpenWorldBoss({
  required Canvas canvas,
  required CosmicBoss boss,
  required double time,
}) {
  final bp = boss.position;
  // Culling stays with the caller, which owns the camera.
  final bColor = elementColor(boss.element);

  canvas.save();
  canvas.translate(bp.dx, bp.dy);

  // Outer aura — breathing glow (warden enrage turns it red)
  final pulse = 0.8 + 0.2 * sin(time * 2.5);
  final auraColor = (boss.enraged)
      ? Color.lerp(bColor, Colors.red, 0.6)!
      : bColor;
  canvas.drawCircle(
    Offset.zero,
    boss.radius * 3.0 * pulse,
    Paint()
      ..color = auraColor.withValues(alpha: boss.enraged ? 0.12 : 0.06)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, boss.radius * 1.5),
  );
  // Secondary aura ring
  canvas.drawCircle(
    Offset.zero,
    boss.radius * 2.0 * pulse,
    Paint()
      ..color = auraColor.withValues(alpha: boss.enraged ? 0.15 : 0.08)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, boss.radius * 0.8),
  );

  // ── Charger: directional wedge indicator + charge trail ──
  if (boss.type == BossType.charger) {
    canvas.save();
    canvas.rotate(boss.angle);
    // Pointed wedge in front
    final wedge = Path()
      ..moveTo(boss.radius * 1.5, 0)
      ..lineTo(boss.radius * 0.4, -boss.radius * 0.5)
      ..lineTo(boss.radius * 0.4, boss.radius * 0.5)
      ..close();
    canvas.drawPath(
      wedge,
      Paint()
        ..color = bColor.withValues(alpha: boss.charging ? 0.8 : 0.3)
        ..maskFilter = boss.charging
            ? const MaskFilter.blur(BlurStyle.normal, 4)
            : null,
    );
    // Charge trail glow behind boss when dashing
    if (boss.charging) {
      canvas.drawCircle(
        Offset(-boss.radius * 1.5, 0),
        boss.radius * 0.8,
        Paint()
          ..color = bColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }
    canvas.restore();
  }

  // ── Gunner: shield ring ──
  if ((boss.type == BossType.gunner || boss.type == BossType.bulwark) &&
      boss.shieldUp) {
    final shieldAlpha =
        (boss.shieldHealth /
                (boss.type == BossType.bulwark
                    ? CosmicBalance.bossShieldHealth(boss.level) * 1.4
                    : CosmicBalance.bossShieldHealth(boss.level)))
            .clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      boss.type == BossType.bulwark ? boss.radius * 1.85 : boss.radius * 1.6,
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.2 * shieldAlpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      Offset.zero,
      boss.type == BossType.bulwark ? boss.radius * 1.55 : boss.radius * 1.4,
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.5 * shieldAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  // Orbiting rune motes
  final moteCount = switch (boss.type) {
    BossType.charger => 4,
    BossType.gunner => 6,
    BossType.skirmisher => 5,
    BossType.bulwark => 6,
    BossType.carrier => 7,
    BossType.warden => 8,
  };
  for (var i = 0; i < moteCount; i++) {
    final moteA = time * 1.2 + i * pi * 2 / moteCount;
    final moteR = boss.radius * (1.3 + 0.15 * sin(time * 3 + i));
    final mp = Offset(cos(moteA) * moteR, sin(moteA) * moteR);
    canvas.drawCircle(
      mp,
      2.5,
      Paint()
        ..color = (boss.enraged ? Colors.red : bColor).withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  // Core body — radial gradient orb
  canvas.drawCircle(
    Offset.zero,
    boss.radius,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(-boss.radius * 0.2, -boss.radius * 0.2),
        boss.radius * 1.1,
        [
          Colors.white.withValues(alpha: 0.5 * pulse),
          Color.lerp(bColor, Colors.white, 0.2)!.withValues(alpha: 0.8 * pulse),
          bColor.withValues(alpha: 0.6 * pulse),
          bColor.withValues(alpha: 0.0),
        ],
        [0.0, 0.25, 0.6, 1.0],
      ),
  );

  // Inner sigil — type determines complexity
  canvas.save();
  canvas.rotate(time * 0.6);
  final sigR = boss.radius * 0.55;
  canvas.drawCircle(
    Offset.zero,
    sigR,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
  );
  // Star points scale with type
  final starPoints = switch (boss.type) {
    BossType.charger => 5,
    BossType.gunner => 7,
    BossType.skirmisher => 8,
    BossType.bulwark => 4,
    BossType.carrier => 6,
    BossType.warden => 9,
  };
  final sigPath = Path();
  for (var i = 0; i < starPoints; i++) {
    final a1 = i * pi * 2 / starPoints - pi / 2;
    final a2 = a1 + pi * 2 / starPoints * 3;
    final p1 = Offset(cos(a1) * sigR, sin(a1) * sigR);
    final p2 = Offset(cos(a2) * sigR, sin(a2) * sigR);
    sigPath.moveTo(p1.dx, p1.dy);
    sigPath.lineTo(p2.dx, p2.dy);
  }
  canvas.drawPath(
    sigPath,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8,
  );
  // Warden: second inner inscribed ring when enraged
  if (boss.type == BossType.warden && boss.enraged) {
    canvas.drawCircle(
      Offset.zero,
      sigR * 0.6,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
  canvas.restore();

  // Health bar above boss
  final barWidth = boss.radius * 2.5;
  final barHeight = 4.0;
  final barY = -boss.radius - 14.0;
  final hpFrac = (boss.health / boss.maxHealth).clamp(0.0, 1.0);

  // Background
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, barY),
        width: barWidth,
        height: barHeight,
      ),
      const Radius.circular(2),
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.6),
  );
  // Fill
  final fillW = barWidth * hpFrac;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-barWidth / 2, barY - barHeight / 2, fillW, barHeight),
      const Radius.circular(2),
    ),
    Paint()..color = Color.lerp(Colors.red, bColor, hpFrac)!,
  );

  // Boss name + level + type
  final typeTag = switch (boss.type) {
    BossType.charger => '⚡',
    BossType.gunner => '🔫',
    BossType.skirmisher => '🎯',
    BossType.bulwark => '🛡️',
    BossType.carrier => '🛸',
    BossType.warden => '👑',
  };
  final namePainter = TextPainter(
    text: TextSpan(
      text: '$typeTag Lv${boss.level} ${boss.name}',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  namePainter.paint(
    canvas,
    Offset(-namePainter.width / 2, barY - barHeight - 14),
  );

  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
// Boss lair marker
//
// Not a boss — the waiting spawn trigger you fly into. Its rotating alchemical
// diamond is the strongest read in the open world, so if the blur ever comes
// out of this pass the shape itself should survive untouched.
// ─────────────────────────────────────────────────────────────────────────────

void drawBossLair({
  required Canvas canvas,
  required BossLair lair,
  required double time,
}) {
  final lp = lair.position;

  final lColor = elementColor(lair.template.element);
  final pulse = 0.5 + 0.3 * sin(time * 2.0);

  // Ominous aura
  canvas.drawCircle(
    Offset(lp.dx, lp.dy),
    BossLair.activationRadius * 0.4,
    Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.06 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
  );

  // Rotating diamond shape
  canvas.save();
  canvas.translate(lp.dx, lp.dy);
  canvas.rotate(time * 0.5);
  final diamondPath = Path()
    ..moveTo(0, -18)
    ..lineTo(14, 0)
    ..lineTo(0, 18)
    ..lineTo(-14, 0)
    ..close();
  canvas.drawPath(
    diamondPath,
    Paint()..color = lColor.withValues(alpha: 0.25 * pulse),
  );
  canvas.drawPath(
    diamondPath,
    Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.4 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  canvas.restore();

  // Inner glow dot
  canvas.drawCircle(
    Offset(lp.dx, lp.dy),
    6,
    Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.5 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawCircle(
    Offset(lp.dx, lp.dy),
    3,
    Paint()..color = lColor.withValues(alpha: 0.7),
  );

  // Level label
  final lairLabel = TextPainter(
    text: TextSpan(
      text: 'Lv${lair.level} ${lair.template.name}',
      style: TextStyle(
        color: const Color(0xFFFF5252).withValues(alpha: 0.7 * pulse),
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  lairLabel.paint(canvas, Offset(lp.dx - lairLabel.width / 2, lp.dy + 22));
}

// ─────────────────────────────────────────────────────────────────────────────
// Archetype marks
//
// The lair boss was the only enemy in the game whose archetype changed its
// silhouette — an inscribed alchemical sigil whose point count varies by type.
// Everything else (8 survival variants, 7 boss disciplines, 4 roles) rendered
// identically, so the player could not tell a splitter from a summoner until it
// went off in their face.
//
// These two primitives generalise the lair boss's language. They are separated
// by budget, not by style: a boss is one entity on screen and can afford the
// full sigil, while enemies come in dozens and get a mark of a few strokes.
// ─────────────────────────────────────────────────────────────────────────────


/// The wind-up tell, drawn in the enemy's local space.
///
/// A charging ring that closes as the attack approaches, plus an aim line so
/// you know WHERE it lands, not just that something is coming. Recover vents
/// the body instead, marking the punish window.
void _drawActionTelegraph(
  Canvas canvas,
  EnemyVisual enemy,
  Color eColor,
  double r,
  double elapsed,
) {
  final phase = enemy.actionPhase;
  if (phase == null) return;
  final p = enemy.actionProgress;

  switch (phase) {
    case EnemyActionPhase.windUp:
      // Closing ring: starts wide, tightens onto the body as it completes.
      final ringR = r * (3.2 - 2.0 * p);
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 + 2.4 * p
          ..color = Color.lerp(eColor, Colors.white, 0.45)!.withValues(
            alpha: 0.35 + 0.5 * p,
          ),
      );
      // The core charges — the circle building in the middle.
      canvas.drawCircle(
        Offset.zero,
        r * 0.55 * p,
        Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.5 * p),
      );
      // Aim line: where it is going to land.
      final d = Offset(cos(enemy.actionAngle), sin(enemy.actionAngle));
      canvas.drawLine(
        d * r * 1.1,
        d * (r * 1.1 + 46 * p),
        Paint()
          ..strokeWidth = 1.0 + 1.4 * p
          ..strokeCap = StrokeCap.round
          ..color = eColor.withValues(alpha: 0.25 + 0.55 * p),
      );

    case EnemyActionPhase.commit:
      canvas.drawCircle(
        Offset.zero,
        r * 1.35,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * (1 - p)),
      );

    case EnemyActionPhase.recover:
      // Vented and open: the window that pays you for reading the tell.
      canvas.drawCircle(
        Offset.zero,
        r * 1.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.30 * (1 - p)),
      );

    case EnemyActionPhase.idle:
      break;
  }
}

final ui.Paint _markPaint = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

/// Star points per trait — the archetype's signature under the converged
/// taxonomy. Traits are body-independent, so this mark now means the same
/// thing on a wisp as on a colossus.
int traitSigilPoints(EnemyTrait? t) => switch (t) {
  null => 0,
  EnemyTrait.breaker => 3,
  EnemyTrait.summoner => 7,
  EnemyTrait.splitter => 8,
};

/// Orbiting mote count per boss archetype. Kept independent of the sigil
/// points so the two axes read separately: points tell you the discipline
/// (how it fights), motes tell you the archetype (what it is).
int bossTypeMotes(BossType t) => switch (t) {
  BossType.charger => 3,
  BossType.gunner => 5,
  BossType.skirmisher => 4,
  BossType.bulwark => 6,
  BossType.carrier => 7,
  BossType.warden => 8,
};

/// Star points per boss discipline.
int disciplineSigilPoints(SurvivalBossDiscipline d) => switch (d) {
  SurvivalBossDiscipline.standard => 5,
  SurvivalBossDiscipline.artillery => 4,
  SurvivalBossDiscipline.trickster => 8,
  SurvivalBossDiscipline.duelist => 3,
  SurvivalBossDiscipline.conductor => 6,
  SurvivalBossDiscipline.siegebreaker => 7,
  SurvivalBossDiscipline.riftcaller => 9,
};

/// A cheap archetype mark for ordinary enemies: one inscribed star path plus
/// an optional pip. Two draw calls, one Path, no blur — affordable on every
/// enemy on screen, which is the constraint that rules out the full sigil.
void drawEnemyArchetypeMark({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required ui.Color color,
  required int points,
  required double time,
  double alpha = 0.85,
}) {
  if (points <= 0) return;
  final r = radius * 0.62;
  final inner = r * 0.46;
  final spin = time * 0.55;
  final path = ui.Path();
  for (var i = 0; i < points * 2; i++) {
    final a = spin + i * pi / points;
    final rr = i.isEven ? r : inner;
    final p = centre + ui.Offset(cos(a), sin(a)) * rr;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  _markPaint
    ..color = color.withValues(alpha: alpha)
    ..strokeWidth = 1.15;
  canvas.drawPath(path, _markPaint);
}

/// The full sigil, for bosses: inscribed ring, star, and orbiting rune motes.
/// This is the lair boss's treatment, made reusable.
void drawBossSigil({
  required ui.Canvas canvas,
  required ui.Offset centre,
  required double radius,
  required ui.Color color,
  required int points,
  required int motes,
  required double time,
  double alpha = 1.0,
}) {
  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.rotate(time * 0.6);
  final sigR = radius * 0.55;
  _markPaint
    ..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.22 * alpha)
    ..strokeWidth = 1.0;
  canvas.drawCircle(ui.Offset.zero, sigR, _markPaint);

  final path = ui.Path();
  for (var i = 0; i < points; i++) {
    final a = i * pi * 2 / points - pi / 2;
    final p = ui.Offset(cos(a), sin(a)) * sigR;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
    // Chord across the circle gives the woven look the lair boss has.
    final b = ((i + points ~/ 2) % points) * pi * 2 / points - pi / 2;
    final q = ui.Offset(cos(b), sin(b)) * sigR;
    path.lineTo(q.dx, q.dy);
  }
  path.close();
  _markPaint
    ..color = color.withValues(alpha: 0.55 * alpha)
    ..strokeWidth = 1.1;
  canvas.drawPath(path, _markPaint);
  canvas.restore();

  for (var i = 0; i < motes; i++) {
    final a = time * 1.2 + i * pi * 2 / motes;
    final rr = radius * (1.28 + 0.12 * sin(time * 3 + i));
    canvas.drawCircle(
      centre + ui.Offset(cos(a), sin(a)) * rr,
      2.2,
      ui.Paint()..color = color.withValues(alpha: 0.7 * alpha),
    );
  }
}
