// lib/games/cosmic/cosmic_enemy_vfx.dart
//
// How an enemy is drawn — in survival, in open space and in the planet
// dungeons. The bodies themselves are painted by enemy_body_art.dart; this
// file maps each mode's entity onto them and adds the tells, marks, bars and
// the horde atlas.
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
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/ability_grains.dart'
    show abilityMaterialTint;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/enemy_body_art.dart';
import 'package:alchemons/games/cosmic/horn_vfx.dart';
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:alchemons/games/cosmic_survival/boss_roster_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:flutter/material.dart';

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
    this.isPlagueCore = false,
    this.visualColor,
    this.seed = 0,
    this.facing,
    this.turn = 0,
    this.droneForm = 0,
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
  final bool isPlagueCore;
  final Color? visualColor;

  /// Stable per body, so a crowd does not flicker and turn in lockstep.
  final double seed;

  /// Where the body points — its heading eased (see EnemyFacing) — and how
  /// fast it is turning. Null facing draws at the raw heading.
  final double? facing;
  final double turn;

  /// Which of the drone's forms this body wears (enemy_body_art.dart);
  /// read only for drones.
  final int droneForm;

  /// The angle the body is drawn at.
  double get bodyAngle => facing ?? (actionPhase == null ? angle : actionAngle);

  /// Survival's body at the render clock [time]: advances its eased facing.
  factory EnemyVisual.fromSurvival(CosmicSurvivalEnemy e, double time) {
    final facing = e.facing.follow(
      e.action.isBusy ? e.action.aimAngle : e.angle,
      time,
    );
    return EnemyVisual._survival(e, facing, e.facing.turn);
  }

  factory EnemyVisual._survival(
    CosmicSurvivalEnemy e,
    double facing,
    double turn,
  ) => EnemyVisual(
    facing: facing,
    turn: turn,
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
    actionProgress: e.action.progress(switch (e.action.phase) {
      EnemyActionPhase.windUp => kEnemyActions[e.tier]?.windUp ?? 0,
      EnemyActionPhase.commit => kEnemyActions[e.tier]?.commit ?? 0,
      EnemyActionPhase.recover => kEnemyActions[e.tier]?.recover ?? 0,
      EnemyActionPhase.idle => 0,
    }),
    actionAngle: e.action.aimAngle,
    isElite: e.isElite,
    eliteAffix: e.eliteAffix,
    flightSteering: e.flightSteering,
    rootTimer: e.hornPlantRootTimer,
    isPlagueCore: e.isPlagueCore,
    visualColor: e.visualColor,
    seed: _seedOf(e),
    droneForm: e.droneForm >= 0 ? e.droneForm : droneFormForSeed(_seedOf(e)),
  );

  /// The open world's body at the render clock [time].
  factory EnemyVisual.fromOpenWorld(CosmicEnemy e, double time) => EnemyVisual(
    facing: e.facing.follow(e.angle, time),
    turn: e.facing.turn,
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
    rootTimer: e.hornPlantRootTimer,
    seed: _seedOf(e),
    // A pack shares one form; a loner wears its own.
    droneForm: e.packId >= 0
        ? (e.packId * 7 + 1) % kDroneForms
        : droneFormForSeed(_seedOf(e)),
  );
}

double _seedOf(Object o) => (identityHashCode(o) & 1023) / 1023 * 2 * pi;

bool _heavy(EnemyTier t) => t == EnemyTier.brute || t == EnemyTier.colossus;

double _squashFor(EnemyConduct c, EnemyTrait? t, EnemyTier tier) {
  if (t == EnemyTrait.breaker) return 1.12;
  if (t == EnemyTrait.summoner) return 1.08;
  if (t == EnemyTrait.splitter) return 1.04;
  if (c == EnemyConduct.charge && _heavy(tier)) return 1.20;
  if (c == EnemyConduct.stalk) return 0.90;
  if (c == EnemyConduct.standoff) return 0.94;
  if (c == EnemyConduct.siege) return 1.16; // squat, planted
  return 1.0;
}

double _stretchFor(EnemyConduct c, EnemyTrait? t, EnemyTier tier) {
  if (t == EnemyTrait.breaker) return 0.93;
  if (t == EnemyTrait.summoner) return 1.08;
  if (t == EnemyTrait.splitter) return 0.96;
  if (c == EnemyConduct.charge && _heavy(tier)) return 0.88;
  if (c == EnemyConduct.stalk) return 1.16;
  if (c == EnemyConduct.standoff) return 1.10;
  if (c == EnemyConduct.siege) return 0.86;
  return 1.0;
}

/// Open-world variants mapped onto the same mark vocabulary as survival's, so
/// a crusher reads the same in both modes.
/// Same one-shape rule as [traitSigilPoints] — a 5- or 6-pointed star at
/// enemy scale reads as clutter rather than as a variant tell.
int openWorldVariantSigilPoints(CosmicEnemyVariant v) =>
    v == CosmicEnemyVariant.standard ? 0 : 3;

/// What a survival body drawn in grains (roster_art.dart) still needs from
/// here: its dive and attack tells, and the roots holding it.
void drawSurvivalEnemyMarks({
  required Canvas canvas,
  required CosmicSurvivalEnemy enemy,
  required double time,
}) => drawEnemyMarks(
  canvas: canvas,
  visual: EnemyVisual.fromSurvival(enemy, time),
  time: time,
);

/// Open space's marks over a body drawn in grains: its tells and roots, and
/// its variant's sigil (a crusher or a pouncer is told apart by it).
void drawOpenWorldEnemyMarks({
  required Canvas canvas,
  required CosmicEnemy e,
  required double time,
}) => drawEnemyMarks(
  canvas: canvas,
  visual: EnemyVisual.fromOpenWorld(e, time),
  time: time,
  sigil: true,
);

/// Whether an open-space body has anything to draw over its grains.
bool openWorldEnemyHasMarks(CosmicEnemy e) =>
    e.variant != CosmicEnemyVariant.standard ||
    e.hornPlantRootTimer > 0 ||
    (e.flightSteering?.showTelegraphRing ?? false);

/// What is drawn over a body drawn in grains (roster_art.dart): the dive
/// ring, the attack's wind-up, roots, and with [sigil] its sigil.
void drawEnemyMarks({
  required Canvas canvas,
  required EnemyVisual visual,
  required double time,
  bool sigil = false,
}) {
  final color = visual.visualColor ?? elementColor(visual.element);
  final steering = visual.flightSteering;
  if (steering != null && steering.showTelegraphRing) {
    _drawDiveTelegraph(canvas, visual.position, visual.radius, steering, color);
  }
  canvas.save();
  canvas.translate(visual.position.dx, visual.position.dy);
  _drawActionTelegraph(canvas, visual, color, visual.radius, time);
  if (sigil) {
    drawEnemyArchetypeMark(
      canvas: canvas,
      centre: Offset.zero,
      radius: visual.radius,
      color: Color.lerp(color, const Color(0xFFFFFFFF), 0.55)!,
      points: visual.sigilPoints,
      time: time,
      alpha: 0.8,
    );
  }
  if (visual.rootTimer > 0) {
    drawHornPlantRootWrap(
      canvas: canvas,
      r: visual.radius,
      time: time,
      seed: visual.angle,
      strength: (visual.rootTimer / 0.4).clamp(0.0, 1.0),
    );
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

/// Where a boss is about to stand: the floor under it goes dark, its light
/// gathers there, and grains are drawn in to the spot from four body-widths
/// out, more of them and faster as it comes ([t] 0..1). It was a pulsing
/// hoop with spokes and a set of stroked marks per discipline.
void _drawBossArrival(
  Canvas canvas,
  Offset at,
  double r,
  double t,
  Color color,
  double time,
) {
  final e = t.clamp(0.0, 1.0);
  final ease = e * e * (3 - 2 * e);
  vfxSpill(
    canvas,
    at,
    r * (1.6 + 1.2 * ease),
    const Color(0xFF030208),
    0.7 * ease,
  );
  final light = abilityMaterialTint(color);
  vfxSpill(canvas, at, r * (2.6 - 1.2 * ease), light, 0.08 + 0.24 * ease);
  const n = 30;
  final shown = (8 + (n - 8) * ease).round();
  for (var pass = 0; pass < 2; pass++) {
    for (var i = pass; i < shown; i += 2) {
      final h = vfxHash(i * 3.71 + 1.3);
      // Each on its own lap: out at four widths, in to the spot, again.
      final f = (h + time * (0.35 + 0.5 * ease) * (0.7 + 0.6 * h)) % 1.0;
      final rho = r * (0.25 + 3.9 * (1 - f) * (1 - f));
      // Curling in as it comes.
      final a = i * 2.39996 + f * 1.4;
      vfxGrain(at.dx + cos(a) * rho, at.dy + sin(a) * rho);
    }
    vfxGrainsFlush(
      canvas,
      max(2.6, r * (pass == 0 ? 0.045 : 0.06)),
      pass == 0 ? light : Color.lerp(light, const Color(0xFFFFFFFF), 0.45)!,
      0.3 + 0.55 * ease,
    );
  }
}

/// A boss venting: planted, overheated and open. Heat lies on the floor
/// round it ([_drawBossVentHeat], under the body) and embers stream off it
/// ([_drawBossVentEmbers], over it), thick while the window is fresh
/// ([vent] 1) and thinning as it closes. It was a hoop with six dots
/// circling it.
void _drawBossVentHeat(Canvas canvas, double r, double vent, double time) {
  vfxSpill(
    canvas,
    Offset.zero,
    r * (2.3 + 0.1 * sin(time * 2.4)),
    const Color(0xFFFF7043),
    0.3 * vent,
  );
}

void _drawBossVentEmbers(Canvas canvas, double r, double vent, double time) {
  const n = 26;
  for (var pass = 0; pass < 2; pass++) {
    for (var i = pass; i < n; i += 2) {
      final h = vfxHash(i * 5.19 + 0.7);
      final f = (h + time * (0.45 + 0.35 * h)) % 1.0;
      // Shown only while young enough to still be hot.
      if (f > 0.35 + 0.65 * vent) continue;
      final rho = r * (0.7 + 1.5 * f);
      final a = i * 2.39996 + f * 0.9 * (i.isEven ? 1 : -1);
      // Rising a little as they leave it.
      vfxGrain(cos(a) * rho, sin(a) * rho - r * 0.35 * f);
    }
    vfxGrainsFlush(
      canvas,
      max(3.0, r * (pass == 0 ? 0.05 : 0.07)),
      pass == 0 ? const Color(0xFFFF7043) : const Color(0xFFFFC078),
      0.85 * vent,
    );
  }
}

Float32List _ringLit = Float32List(2 * 128);
Float32List _ringOut = Float32List(2 * 128);
final Float32List _ringEdge = Float32List(2);
final Paint _ringPaint = Paint()
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

/// A boss's health: grains set round it at [radius], lit clockwise from
/// the top for the share it has left, the spent ones left as dim specks.
/// The last lit grain glints, so the edge is easy to find.
void _drawBossHealthGrains(
  Canvas canvas,
  double radius,
  double hp,
  Color color,
  double time, {
  // The phase lines still ahead, as shares of its health: a short gap in
  // the ring at each, so you can see where the next phase begins.
  List<double> gates = const [],
}) {
  final n = (2 * pi * radius / 5.5).round().clamp(60, 320);
  if (_ringLit.length < n * 2) {
    _ringLit = Float32List(n * 2);
    _ringOut = Float32List(n * 2);
  }
  final lit = (n * hp.clamp(0.0, 1.0)).ceil();
  var li = 0, oi = 0;
  for (var i = 0; i < n; i++) {
    final f = (i + 0.5) / n;
    var atGate = false;
    for (final g in gates) {
      if ((f - g).abs() * n < 1.6) atGate = true;
    }
    if (atGate) continue;
    final a = -pi / 2 + f * 2 * pi;
    // Two courses, the grains a little off their marks: a band of sand,
    // not a ruled circle.
    final rr =
        radius +
        (i.isEven ? 0.0 : -5.0) +
        1.6 * sin(time * 2 + i * 0.9) +
        2.2 * sin(i * 12.9898);
    final x = rr * cos(a), y = rr * sin(a);
    if (i < lit) {
      _ringLit[li++] = x;
      _ringLit[li++] = y;
      if (i == lit - 1) {
        _ringEdge[0] = x;
        _ringEdge[1] = y;
      }
    } else {
      _ringOut[oi++] = x;
      _ringOut[oi++] = y;
    }
  }
  if (oi > 0) {
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_ringOut, 0, oi),
      _ringPaint
        ..strokeWidth = 1.8
        ..color = Color.lerp(color, const Color(0xFF07060B), 0.7)!,
    );
  }
  if (li > 0) {
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_ringLit, 0, li),
      _ringPaint
        ..strokeWidth = 3.0
        ..color = Color.lerp(color, const Color(0xFFFFF6E4), 0.25)!,
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      _ringEdge,
      _ringPaint
        ..strokeWidth = 5
        ..color = const Color(0xFFFFF6E4),
    );
  }
}

Float32List _shieldPts = Float32List(2 * 128);

/// A boss's shield: plates of pale grains turning round it, two rows deep.
void _drawBossShieldGrains(Canvas canvas, double radius, double time) {
  final n = (2 * pi * radius / 5).round().clamp(60, 320);
  if (_shieldPts.length < n * 4) _shieldPts = Float32List(n * 4);
  var k = 0;
  for (var row = 0; row < 2; row++) {
    final turn = time * (row == 0 ? 0.5 : -0.35);
    final rr = radius + row * 4.5;
    for (var i = 0; i < n; i++) {
      // Plates with gaps between them.
      if ((i + row * 4) % 11 >= 8) continue;
      final a = i / n * 2 * pi + turn;
      _shieldPts[k++] = rr * cos(a);
      _shieldPts[k++] = rr * sin(a);
    }
  }
  canvas.drawRawPoints(
    ui.PointMode.points,
    Float32List.sublistView(_shieldPts, 0, k),
    _ringPaint
      ..strokeWidth = 3
      ..color = const Color(0xFF7FE8F4).withValues(
        alpha: 0.62 + 0.14 * sin(time * 3),
      ),
  );
}

void drawSurvivalBoss({
  required Canvas canvas,
  required SurvivalBoss boss,
  required double time,
  bool reduceGlows = false,
  // The core: a boss drawn in grains (boss_roster_art.dart) may lean on it.
  Offset core = Offset.zero,
  // The player's party read as grains, for a boss that shows them.
  List<BossShadow> shadows = const [],
}) {
  final bColor = boss.color;
  // Every boss is drawn in grains in the world (boss_roster_art.dart).
  final kind = survivalBossKindOf(boss);
  final r = boss.radius;
  final elapsed = time;
  final spawnTarget = boss.spawnTargetPosition;
  if (boss.isSpawning && spawnTarget != null) {
    _drawBossArrival(
      canvas,
      spawnTarget,
      r,
      1.0 - (boss.spawnIntroTimer / boss.spawnIntroDuration),
      bColor,
      elapsed,
    );
  }

  paintSurvivalBossKind(
    canvas,
    boss,
    kind,
    time: elapsed,
    core: core,
    shadows: shadows,
  );

  canvas.save();
  canvas.translate(boss.position.dx, boss.position.dy);

  if (boss.isVenting) {
    _drawBossVentHeat(
      canvas,
      r,
      (boss.overheatTimer / 1.9).clamp(0.0, 1.0),
      elapsed,
    );
  }
  final hpFrac = boss.hpFraction;
  // Its health is read off a ring of grains round it, lit clockwise from
  // the top for what it has left; its shield is a second band of grains
  // turning inside that.
  final ringR =
      max(
        r *
            (kind == SurvivalBossKind.form
                ? grainFormReach(survivalBossForm(boss))
                : survivalBossReach(kind)),
        r * 1.32,
      ) +
      10;
  // The shield band shows its shield and its ward between phases alike.
  if (boss.shielded) _drawBossShieldGrains(canvas, r * 1.32, elapsed);
  _drawBossHealthGrains(
    canvas,
    ringR,
    hpFrac,
    gates: [
      for (var i = boss.phasesPassed; i < SurvivalBoss.phaseGates.length; i++)
        SurvivalBoss.phaseGates[i],
    ],
    boss.enraged
        ? Color.lerp(Colors.red, Colors.orange, sin(elapsed * 4) * 0.5 + 0.5)!
        : Color.lerp(Colors.red, bColor, hpFrac)!,
    elapsed,
  );
  final barY = -ringR - 4;

  // Venting: planted, overheated and open. This is the window that pays you
  // for closing the distance, so it has to be unmistakable.
  if (boss.isVenting) {
    _drawBossVentEmbers(
      canvas,
      r,
      (boss.overheatTimer / 1.9).clamp(0.0, 1.0),
      elapsed,
    );
  }

  final nameTP = _bossNamePainter(survivalBossName(boss), bColor);
  nameTP.paint(canvas, Offset(-nameTP.width / 2, barY - 12));

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

void drawOpenWorldBoss({
  required Canvas canvas,
  required CosmicBoss boss,
  required double time,
}) {
  final bp = boss.position;
  // Culling stays with the caller, which owns the camera.
  final bColor = elementColor(boss.element);
  final r = boss.radius;
  final form = bossFormFor(boss.type);

  // Its archetype's form in grains, as survival draws its own
  // (boss_roster_art.dart).
  paintGrainFormOf(
    canvas,
    form: form,
    position: bp,
    radius: r,
    color: bColor,
    time: time,
    enraged: boss.enraged,
    charging: boss.charging,
    heading: boss.charging ? boss.chargeAngle : boss.angle,
    shieldUp: boss.shieldUp,
  );

  canvas.save();
  canvas.translate(bp.dx, bp.dy);

  // A gunner's or a bulwark's shield of cold light while it holds.
  if (boss.shieldUp &&
      (boss.type == BossType.gunner || boss.type == BossType.bulwark)) {
    final shieldAlpha =
        (boss.shieldHealth /
                (boss.type == BossType.bulwark
                    ? CosmicBalance.bossShieldHealth(boss.level) * 1.4
                    : CosmicBalance.bossShieldHealth(boss.level)))
            .clamp(0.0, 1.0);
    vfxSoftRing(
      canvas,
      Offset.zero,
      boss.type == BossType.bulwark ? r * 1.65 : r * 1.4,
      r * 0.2,
      const Color(0xFF7FE8F4),
      0.55 * shieldAlpha,
    );
  }

  // Health bar above boss
  final barWidth = r * 2.5;
  const barHeight = 4.0;
  final barY = -r * grainFormReach(form) - 12.0;
  final hpFrac = (boss.health / boss.maxHealth).clamp(0.0, 1.0);
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
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        -barWidth / 2,
        barY - barHeight / 2,
        barWidth * hpFrac,
        barHeight,
      ),
      const Radius.circular(2),
    ),
    Paint()..color = Color.lerp(Colors.red, bColor, hpFrac)!,
  );

  final namePainter = _bossLabelPainter('Lv${boss.level} ${boss.name}');
  namePainter.paint(
    canvas,
    Offset(-namePainter.width / 2, barY - barHeight - 14),
  );

  canvas.restore();
}

final Map<String, TextPainter> _bossLabels = {};

TextPainter _bossLabelPainter(String text) => _bossLabels.putIfAbsent(
  text,
  () => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(),
);

// ─────────────────────────────────────────────────────────────────────────────
// Boss lair marker
//
// Not a boss — the waiting spawn trigger you fly into. Its rotating alchemical
// diamond is the strongest read in the open world, so if the blur ever comes
// out of this pass the shape itself should survive untouched.
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
  final light = Color.lerp(eColor, Colors.white, 0.45)!;

  switch (phase) {
    case EnemyActionPhase.windUp:
      // Light gathering onto the body: a wide faint pool that tightens and
      // brightens, and grains drawn in to it on a lopsided curl, as the
      // attack approaches. It was a band of light closing like a hoop — on
      // a horde front, dozens of rings at once, which read as UI pulses and
      // made the field look busier than it played.
      vfxSpill(canvas, Offset.zero, r * (2.4 - 1.1 * p), light, 0.1 + 0.36 * p);
      final seed = enemy.seed;
      for (var i = 0; i < 6; i++) {
        // Each grain starts at its own point in the gather, so they arrive
        // in turn rather than as one shrinking circle.
        final g = (p + i / 6) % 1.0;
        final a = seed * 0.37 + i * 2.1 + (i.isEven ? 1 : -1) * g * 1.4;
        final d = r * (1.0 + 2.2 * (1 - g) * (1 - g));
        vfxGrain(cos(a) * d, sin(a) * d);
      }
      vfxGrainsFlush(canvas, 1.6 + r * 0.06, light, 0.35 + 0.45 * p);
      // Shockwaves are radial; a directional tell would promise a safe side.
      if (enemy.tier != EnemyTier.colossus) {
        // A lance of light laid out where it is going to land.
        final len = 10 + 46 * p;
        canvas.save();
        canvas.rotate(enemy.actionAngle);
        canvas.translate(r * 1.1, 0);
        vfxCrossLit(
          canvas,
          vfxLens(len, 3.0 + 3.0 * p, len * 0.15, len * 0.6),
          1.5 + 1.5 * p,
          eColor,
          light,
          0.35 + 0.55 * p,
        );
        canvas.restore();
      }

    case EnemyActionPhase.commit:
      // The burst: light thrown off the body, spent as it goes.
      vfxSpill(canvas, Offset.zero, r * (1.4 + 0.5 * p), light, 0.4 * (1 - p));

    case EnemyActionPhase.recover:
      // Vented and open: the window that pays you for reading the tell. A
      // pale light spent around the body, thinning as it closes again.
      vfxSpill(canvas, Offset.zero, r * 1.7, light, 0.26 * (1 - p));

    case EnemyActionPhase.idle:
      break;
  }
}

final ui.Paint _markPaint = ui.Paint()
  ..style = ui.PaintingStyle.stroke
  ..strokeCap = ui.StrokeCap.round
  ..strokeJoin = ui.StrokeJoin.round;

/// Whether a trait carries a mark, and how many points it has.
///
/// One shape for every trait. This used to vary — 3 points for breaker, 7 for
/// summoner, 8 for splitter — on the theory that the point count would teach
/// you which behaviour you were facing. At enemy scale a spinning 7- or
/// 8-pointed star is not read as information; it just looks busy, especially
/// on the phantom, whose body is already broken arcs. A single clean triangle
/// says "this one is special" and leaves the telling to behaviour.
int traitSigilPoints(EnemyTrait? t) => t == null ? 0 : 3;

/// A cheap archetype mark for ordinary enemies: a sigil burned into the
/// body — a dark filled star against its light, with a spark at each point.
/// Filled, not a stroked outline, so it reads as something the body carries
/// rather than a sticker on it; dark against bright cores, sparks against
/// dark shells. Two draw calls, no blur — affordable on every enemy
/// on screen, which is the constraint that rules out the full sigil.
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
  final r = radius * 0.6;
  final inner = r * 0.4;
  final spin = time * 0.55;
  final path = ui.Path();
  final tips = Float32List(points * 2);
  for (var i = 0; i < points * 2; i++) {
    final a = spin + i * pi / points;
    final rr = i.isEven ? r : inner;
    final p = centre + ui.Offset(cos(a), sin(a)) * rr;
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
    if (i.isEven) {
      tips[i] = p.dx;
      tips[i + 1] = p.dy;
    }
  }
  path.close();
  canvas.drawPath(
    path,
    _markFill
      ..color = const ui.Color(0xFF05040A).withValues(alpha: 0.62 * alpha),
  );
  canvas.drawRawPoints(
    ui.PointMode.points,
    tips,
    _markPaint
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = max(2.2, radius * 0.22),
  );
}

final ui.Paint _markFill = ui.Paint();

/// The dive warning: the body's light gathering in round it — wide and
/// faint at first, tightening and brightening as the dive comes. It was a
/// stroked hoop, which read as UI rather than as the body winding up.
void _drawDiveTelegraph(
  Canvas canvas,
  Offset at,
  double r,
  FlightSteeringState steering,
  Color color,
) {
  final reach = r + 5 + steering.windupTimer * 42;
  final close = (1 - steering.windupTimer / 0.35).clamp(0.0, 1.0);
  vfxSpill(canvas, at, reach * 1.25, color, 0.22 + 0.38 * close);
  vfxSpill(
    canvas,
    at,
    r * 1.6,
    Color.lerp(color, const Color(0xFFFFFFFF), 0.4)!,
    0.25 + 0.45 * close,
  );
}
