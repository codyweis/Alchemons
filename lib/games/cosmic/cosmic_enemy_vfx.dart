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
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/enemy_body_art.dart';
import 'package:alchemons/games/cosmic/horn_vfx.dart';
import 'package:alchemons/games/cosmic/planets/planet_art.dart';
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
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
    this.isPlagueCore = false,
    this.visualColor,
    this.seed = 0,
    this.facing,
    this.turn = 0,
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

  /// The angle the body is drawn at.
  double get bodyAngle =>
      facing ?? (actionPhase == null ? angle : actionAngle);

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

/// Bodies simple enough to go out in the horde atlas once the field is busy.
/// Visual-only; movement, collision and statuses are untouched.
bool canSimplifySurvivalSwarmEnemy(CosmicSurvivalEnemy enemy) =>
    (enemy.tier == EnemyTier.wisp || enemy.tier == EnemyTier.drone) &&
    !enemy.isElite &&
    enemy.trait == null &&
    !enemy.isPlagueCore &&
    enemy.visualColor == null &&
    !enemy.action.isBusy &&
    !(enemy.flightSteering?.showTelegraphRing ?? false) &&
    enemy.hornPlantRootTimer <= 0 &&
    enemy.maneRootTimer <= 0 &&
    !(enemy.slowTimer > 0 && enemy.slowMultiplier <= 0.1);

// ── Batched swarm bodies ───────────────────────────────────────────────────
//
// At horde density the per-body draw calls dominate the frame (device
// profile, 1,000 bodies: ~31% of the UI thread in drawCircle alone, and the
// matching raster cost). So the bodies are baked once into an atlas from the
// same painters the live pass uses — one row per element, a few animation
// frames and a hit-flash cell per tier — and every simplifiable body goes out
// in a single drawRawAtlas, turned to its heading so a wisp's tail trails
// behind it and a sentinel looks where it is going.

const _kSwarmAtlasElements = [
  'Fire', 'Lava', 'Lightning', 'Water', 'Ice', 'Steam', 'Earth', 'Mud', //
  'Dust', 'Crystal', 'Air', 'Plant', 'Poison', 'Spirit', 'Dark', 'Light',
  'Blood',
];
const double _kSwarmCell = 72;

/// Animation frames baked per tier, then one hit-flash cell.
const int _kSwarmFrames = 3;
const int _kSwarmCellsPerTier = _kSwarmFrames + 1;
const double _kSwarmFps = 9;

const _kSwarmTiers = [
  EnemyTier.wisp,
  EnemyTier.drone,
  EnemyTier.sentinel,
  EnemyTier.phantom,
];

/// Body radius in atlas pixels, and how far the body sits forward of the
/// cell's centre (body radii) so a trailing tail has room behind it.
(double, double) _swarmSpec(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => (14, 0.15),
  EnemyTier.drone => (14, 0.1),
  _ => (14, 0),
};

int _swarmColumn(EnemyTier tier, bool flash, int frame) {
  final t = _kSwarmTiers.indexOf(tier);
  if (t < 0) return -1;
  return t * _kSwarmCellsPerTier + (flash ? _kSwarmFrames : frame);
}

/// The time each baked frame shows. Frames are spread through a second so
/// the flicker and twinkle differ from one to the next.
double _swarmFrameTime(int frame) => frame * 0.37;

ui.Image? _swarmAtlas;

ui.Image _buildSwarmAtlas() {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  for (var row = 0; row < _kSwarmAtlasElements.length; row++) {
    final element = _kSwarmAtlasElements[row];
    final pal = enemyPalette(element);
    for (final tier in _kSwarmTiers) {
      final (unit, shift) = _swarmSpec(tier);
      for (var f = 0; f <= _kSwarmFrames; f++) {
        final flash = f == _kSwarmFrames;
        final col = _swarmColumn(tier, flash, f);
        canvas.save();
        canvas.clipRect(
          Rect.fromLTWH(
            col * _kSwarmCell,
            row * _kSwarmCell,
            _kSwarmCell,
            _kSwarmCell,
          ),
        );
        // Baked facing +x: the batch turns each body to its heading.
        canvas.translate(
          col * _kSwarmCell + _kSwarmCell / 2 + shift * unit,
          row * _kSwarmCell + _kSwarmCell / 2,
        );
        canvas.scale(unit);
        final t = _swarmFrameTime(flash ? 0 : f);
        final hit = flash ? 1.0 : 0.0;
        switch (tier) {
          case EnemyTier.wisp:
            paintWispBody(
              canvas,
              pal,
              time: t,
              seed: 0,
              heading: 0,
              flash: hit,
            );
          case EnemyTier.drone:
            // Every frame the same pose: stepping between poses at the
            // atlas's frame rate reads as a stutter.
            paintDroneBody(
              canvas,
              pal,
              time: t,
              seed: 0,
              heading: 0,
              flash: hit,
              rock: false,
            );
          case EnemyTier.sentinel:
            paintSentinelBody(
              canvas,
              pal,
              time: t,
              seed: 0,
              heading: 0,
              flash: hit,
            );
          case EnemyTier.phantom:
            paintPhantomBody(
              canvas,
              pal,
              time: t,
              seed: 0,
              heading: 0,
              flash: hit,
            );
          default:
            break;
        }
        canvas.restore();
      }
    }
  }
  final pic = rec.endRecording();
  final image = pic.toImageSync(
    (_kSwarmCell * _kSwarmTiers.length * _kSwarmCellsPerTier).toInt(),
    (_kSwarmCell * _kSwarmAtlasElements.length).toInt(),
  );
  pic.dispose();
  return image;
}

/// Bodies that may use the baked sentinel/phantom cells, or keep only their
/// attack telegraph drawn live, once the field is dense. Anything that carries
/// information the atlas cannot show (elite, trait, roots, a hard freeze,
/// custom color) still gets the full renderer.
bool canBakeDenseSurvivalEnemy(CosmicSurvivalEnemy enemy) =>
    _swarmColumn(enemy.tier, false, 0) >= 0 &&
    !enemy.isElite &&
    enemy.trait == null &&
    !enemy.isPlagueCore &&
    enemy.visualColor == null &&
    enemy.hornPlantRootTimer <= 0 &&
    enemy.maneRootTimer <= 0 &&
    !(enemy.slowTimer > 0 && enemy.slowMultiplier <= 0.1);

/// Collects swarm bodies during the enemy pass and draws them in one call.
/// Anything it declines (elites, traits, roots, telegraphs, unknown elements)
/// falls back to [drawSurvivalEnemy] at the call site.
///
/// With `dense` set (a very large field) it also takes sentinels, phantoms and
/// bodies mid-attack: the body comes from the atlas and only the telegraph —
/// the part that tells the player what is about to happen — is drawn live.
class SurvivalSwarmBatch {
  Float32List _xforms = Float32List(4 * 256);
  Float32List _rects = Float32List(4 * 256);
  int _count = 0;
  final List<List<double>> _bars = List.generate(
    _kSwarmAtlasElements.length,
    (_) => <double>[],
  );
  final List<CosmicSurvivalEnemy> _telegraphs = [];
  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _barPaint = Paint()
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;

  int get length => _count;

  bool add(CosmicSurvivalEnemy enemy, double time, {bool dense = false}) {
    final busy =
        enemy.action.isBusy ||
        (enemy.flightSteering?.showTelegraphRing ?? false);
    if (dense) {
      if (!canBakeDenseSurvivalEnemy(enemy)) return false;
    } else if (!canSimplifySurvivalSwarmEnemy(enemy)) {
      return false;
    }
    final row = _kSwarmAtlasElements.indexOf(enemy.element);
    if (row < 0) return false;
    final tier = enemy.tier;
    final seed = identityHashCode(enemy) & 1023;
    final frame = (time * _kSwarmFps + seed).floor() % _kSwarmFrames;
    final col = _swarmColumn(tier, enemy.hitFlash > 0.3, frame);
    if (col < 0) return false;
    final (unit, shift) = _swarmSpec(tier);
    final scale = enemy.radius / unit;
    if ((_count + 1) * 4 > _xforms.length) {
      _xforms = Float32List(_xforms.length * 2)..setAll(0, _xforms);
      _rects = Float32List(_rects.length * 2)..setAll(0, _rects);
    }
    // Turned about the body, which sits [shift] forward of the cell centre.
    final facing = enemy.facing.follow(
      enemy.action.isBusy ? enemy.action.aimAngle : enemy.angle,
      time,
    );
    final scos = scale * cos(facing);
    final ssin = scale * sin(facing);
    final ax = _kSwarmCell / 2 + shift * unit;
    const ay = _kSwarmCell / 2;
    final i = _count * 4;
    _xforms[i] = scos;
    _xforms[i + 1] = ssin;
    _xforms[i + 2] = enemy.position.dx - scos * ax + ssin * ay;
    _xforms[i + 3] = enemy.position.dy - ssin * ax - scos * ay;
    _rects[i] = col * _kSwarmCell;
    _rects[i + 1] = row * _kSwarmCell;
    _rects[i + 2] = (col + 1) * _kSwarmCell;
    _rects[i + 3] = (row + 1) * _kSwarmCell;
    _count++;
    if (busy) _telegraphs.add(enemy);
    final hp = enemy.hpFraction;
    if (hp < 0.99) {
      // Only damaged bodies need a health read at horde density.
      final r = enemy.radius;
      final y = enemy.position.dy - r - 3;
      _bars[row].addAll([
        enemy.position.dx - r,
        y,
        enemy.position.dx + r * (2 * hp - 1),
        y,
      ]);
    }
    return true;
  }

  void flush(Canvas canvas, double time) {
    if (_count > 0) {
      final atlas = _swarmAtlas ??= _buildSwarmAtlas();
      canvas.drawRawAtlas(
        atlas,
        Float32List.sublistView(_xforms, 0, _count * 4),
        Float32List.sublistView(_rects, 0, _count * 4),
        null,
        null,
        null,
        _atlasPaint,
      );
      _count = 0;
    }
    for (final enemy in _telegraphs) {
      final visual = EnemyVisual.fromSurvival(enemy, time);
      final color = elementColor(enemy.element);
      final steering = visual.flightSteering;
      if (steering != null && steering.showTelegraphRing) {
        canvas.drawCircle(
          enemy.position,
          enemy.radius + 5 + steering.windupTimer * 42,
          _barPaint
            ..strokeWidth = 1.6
            ..color = Color.lerp(
              color,
              Colors.white,
              0.5,
            )!.withValues(alpha: 0.72),
        );
      }
      canvas.save();
      canvas.translate(enemy.position.dx, enemy.position.dy);
      _drawActionTelegraph(canvas, visual, color, enemy.radius, time);
      canvas.restore();
    }
    _telegraphs.clear();
    _barPaint.strokeWidth = 1;
    for (var row = 0; row < _bars.length; row++) {
      final bars = _bars[row];
      if (bars.isEmpty) continue;
      _barPaint.color = elementColor(
        _kSwarmAtlasElements[row],
      ).withValues(alpha: 0.65);
      canvas.drawRawPoints(
        ui.PointMode.lines,
        Float32List.fromList(bars),
        _barPaint,
      );
      bars.clear();
    }
  }
}

/// Survival's entry point. [simplifySwarm] is kept for the call site; every
/// body now draws through the same cheap unit-space painters, so there is
/// no separate crowd silhouette to fall back to.
void drawSurvivalEnemy({
  required Canvas canvas,
  required CosmicSurvivalEnemy enemy,
  required double time,
  bool reduceLabels = false,
  bool simplifySwarm = false,
}) {
  drawEnemy(
    canvas: canvas,
    enemy: EnemyVisual.fromSurvival(enemy, time),
    time: time,
    reduceLabels: reduceLabels,
  );
}

/// The one enemy silhouette. Both modes map their entity onto [EnemyVisual]
/// and come through here, so there is a single definition to change.
void drawEnemy({
  required Canvas canvas,
  required EnemyVisual enemy,
  required double time,
  bool reduceLabels = false,
}) {
  final eColor = enemy.visualColor ?? elementColor(enemy.element);
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
  final r = enemy.radius;
  final elapsed = time;
  final variantScale = enemy.squash;
  final variantYScale = enemy.stretch;

  canvas.save();
  canvas.translate(enemy.position.dx, enemy.position.dy);
  if (variantScale != 1.0 || variantYScale != 1.0) {
    canvas.rotate(enemy.bodyAngle * 0.08);
    canvas.scale(variantScale, variantYScale);
  }

  final pal = enemyPalette(enemy.element, enemy.visualColor);
  final seed = enemy.seed;
  // Where the body is in its attack, for the bodies that perform it.
  final ap = enemy.actionProgress.clamp(0.0, 1.0);
  final windUp = enemy.actionPhase == EnemyActionPhase.windUp ? ap : 0.0;
  final commit = enemy.actionPhase == EnemyActionPhase.commit ? 1 - ap : 0.0;
  final recover = enemy.actionPhase == EnemyActionPhase.recover ? 1 - ap : 0.0;

  if (enemy.isElite && enemy.eliteAffix != null) {
    // The body stands in a pool of its affix's light — an aura, not a hoop.
    vfxSpill(canvas, Offset.zero, r * 2.6, affixColor, 0.42);
  }

  canvas.save();
  canvas.scale(r);
  switch (enemy.tier) {
    case EnemyTier.wisp:
      paintWispBody(
        canvas,
        pal,
        time: elapsed,
        seed: seed,
        heading: enemy.bodyAngle,
        turn: enemy.turn,
        flash: enemy.hitFlash,
      );
    case EnemyTier.drone:
      paintDroneBody(
        canvas,
        pal,
        time: elapsed,
        seed: seed,
        heading: enemy.bodyAngle,
        turn: enemy.turn,
        charge: windUp,
        dash: commit,
        flash: enemy.hitFlash,
      );
    case EnemyTier.sentinel:
      paintSentinelBody(
        canvas,
        pal,
        time: elapsed,
        seed: seed,
        heading: enemy.bodyAngle,
        charge: windUp,
        release: max(commit, recover * 0.6),
        flash: enemy.hitFlash,
      );
    case EnemyTier.phantom:
      paintPhantomBody(
        canvas,
        pal,
        time: elapsed,
        seed: seed,
        heading: enemy.bodyAngle,
        fade: enemy.actionPhase == EnemyActionPhase.commit ? 1.0 : windUp,
        exposed: recover,
        flash: enemy.hitFlash,
      );
    case EnemyTier.brute:
      if (enemy.isPlagueCore) {
        _drawPlagueCore(canvas, pal, elapsed, seed, enemy.hitFlash);
      } else {
        _drawHeavyBody(canvas, enemy, pal, elapsed, colossus: false);
      }
    case EnemyTier.colossus:
      _drawHeavyBody(canvas, enemy, pal, elapsed, colossus: true);
  }
  canvas.restore();

  if (enemy.tier == EnemyTier.brute || enemy.tier == EnemyTier.colossus) {
    final colossus = enemy.tier == EnemyTier.colossus;
    final hpFrac = enemy.hpFraction;
    if (hpFrac < 1.0 || enemy.isPlagueCore) {
      final barW = r * (colossus ? 3.0 : 2.5);
      final barH = colossus ? 4.0 : 3.0;
      final barY = -r - (colossus ? 10 : 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, barY), width: barW, height: barH),
          Radius.circular(barH / 2),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-barW / 2, barY - barH / 2, barW * hpFrac, barH),
          Radius.circular(barH / 2),
        ),
        Paint()..color = Color.lerp(Colors.red, eColor, hpFrac)!,
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

  // Horn+Plant root: thorned vines climbing over the body (horn_vfx.dart).
  if (enemy.rootTimer > 0) {
    drawHornPlantRootWrap(
      canvas: canvas,
      r: r,
      time: elapsed,
      seed: enemy.angle,
      strength: (enemy.rootTimer / 0.4).clamp(0.0, 1.0),
    );
  }

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

// One curved ribbon, transformed into a small, bounded set of living limbs.
final Path _enemyTendril = Path()
  ..moveTo(0.50, -0.10)
  ..cubicTo(1.04, -0.46, 1.25, 0.64, 2.05, 0.16)
  ..cubicTo(1.30, 1.00, 0.98, -0.10, 0.50, 0.12)
  ..close();

final Map<int, ui.Shader> _tendrilShaders = {};

/// Living limbs, filled — dark flesh at the root going to the color's
/// light at the tips, no outline.
void drawEnemyTendrils(
  Canvas canvas,
  double radius,
  Color color,
  double time, {
  int count = 5,
  double seed = 0,
}) {
  final fill = Paint()
    ..shader = _tendrilShaders.putIfAbsent(
      color.toARGB32(),
      () => ui.Gradient.radial(
        Offset.zero,
        2.1,
        [
          Color.lerp(color, Colors.black, 0.72)!,
          Color.lerp(color, Colors.black, 0.35)!,
          Color.lerp(color, Colors.white, 0.2)!.withValues(alpha: 0.75),
          color.withValues(alpha: 0.0),
        ],
        const [0.2, 0.5, 0.82, 1.0],
      ),
    );
  canvas.save();
  canvas.scale(radius);
  for (var i = 0; i < count; i++) {
    final sway = sin(time * 1.7 + seed + i * 1.8);
    canvas.save();
    canvas.rotate(i * 2 * pi / count + sway * 0.16 + seed * 0.1);
    canvas.scale(0.94 + sway * 0.10, i.isEven ? 1.0 : -1.0);
    canvas.drawPath(_enemyTendril, fill);
    canvas.restore();
  }
  canvas.restore();
}

/// The outbreak core: a beating furnace in a knot of limbs. Unit space.
void _drawPlagueCore(
  Canvas canvas,
  EnemyPalette pal,
  double time,
  double seed,
  double flash,
) {
  drawEnemyTendrils(canvas, 1, pal.essence, time, count: 8, seed: seed);
  final beat = 1.0 + 0.08 * sin(time * 3.2);
  canvas.save();
  canvas.scale(0.78 * beat);
  canvas.drawCircle(Offset.zero, 1, Paint()..shader = pal.orb);
  canvas.restore();
  canvas.save();
  canvas.scale(0.52 * beat);
  canvas.drawCircle(
    Offset.zero,
    1,
    Paint()
      ..shader = pal.spark
      ..color = Colors.white.withValues(alpha: 0.85 + 0.15 * sin(time * 6.4)),
  );
  canvas.restore();
  if (flash > 0.02) {
    canvas.drawCircle(
      Offset.zero,
      0.9,
      Paint()..color = Colors.white.withValues(alpha: 0.6 * flash.clamp(0, 1)),
    );
  }
}

/// Heavy enemies perform through their shell: the brute's plates part and
/// its furnace blazes through the channel; the colossus's crown draws in on
/// the wind-up and blows out on the strike. Unit space.
void _drawHeavyBody(
  Canvas canvas,
  EnemyVisual enemy,
  EnemyPalette pal,
  double time, {
  required bool colossus,
}) {
  final p = enemy.actionProgress.clamp(0.0, 1.0);
  final charge = switch (enemy.actionPhase) {
    EnemyActionPhase.windUp => p,
    EnemyActionPhase.commit => 1.0,
    EnemyActionPhase.recover => 1.0 - p,
    _ => 0.0,
  };
  final recoil = enemy.actionPhase == EnemyActionPhase.commit ? 1 - p : 0.0;
  if (!colossus) {
    paintBruteBody(
      canvas,
      pal,
      time: time,
      seed: enemy.seed,
      facing: enemy.bodyAngle,
      charge: charge,
      recoil: recoil,
      flash: enemy.hitFlash,
    );
  } else {
    final breath = sin(time * 1.3 + enemy.seed);
    paintColossusBody(
      canvas,
      pal,
      time: time,
      seed: enemy.seed,
      turn: enemy.bodyAngle * 0.12 + sin(time * 0.35) * 0.035,
      contraction: enemy.actionPhase == EnemyActionPhase.windUp
          ? -0.15 * charge
          : 0.22 * recoil + 0.03 * breath,
      charge: charge,
      flash: enemy.hitFlash,
    );
  }
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

/// A boss's palette: its own color in its element's material, pushed
/// toward blood-red while it is enraged.
EnemyPalette _bossPalette(String element, Color color, bool enraged) {
  final base = enraged ? Color.lerp(color, const Color(0xFFE53935), 0.35)! : color;
  return base == elementColor(element)
      ? enemyPalette(element)
      : enemyPalette(element, base);
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

  final pal = _bossPalette(boss.template.element, bColor, boss.enraged);
  final form = bossFormFor(boss.type);
  canvas.save();
  canvas.scale(r);
  paintBossForm(
    canvas,
    pal,
    form,
    time: elapsed,
    seed: boss.template.name.length * 0.7,
    heading: boss.charging ? boss.chargeAngle : boss.angle,
    charge: boss.charging ? 1 : 0,
    enraged: boss.enraged,
    shield: boss.shieldUp,
    reduceGlows: reduceGlows,
    flash: boss.hitFlash,
  );
  canvas.restore();

  if (boss.shieldUp && form != BossForm.spire) {
    vfxSoftRing(
      canvas,
      Offset.zero,
      r * 1.32,
      r * 0.16,
      const Color(0xFF7FE8F4),
      0.42 + 0.12 * sin(elapsed * 3),
    );
  }

  final hpFrac = boss.hpFraction;
  final barW = r * 3.0;
  final barY = -r * bossFormReach(form) - 12;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, barY), width: barW, height: 5),
      const Radius.circular(2.5),
    ),
    Paint()..color = Colors.black.withValues(alpha: 0.7),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-barW / 2, barY - 2.5, barW * hpFrac, 5),
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
        Paint()..color = const Color(0xFFFFC078).withValues(alpha: 0.85 * vent),
      );
    }
  }

  final nameTP = _bossNamePainter(boss.template.name, bColor);
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

void drawOpenWorldEnemy({
  required Canvas canvas,
  required CosmicEnemy e,
  required double time,
}) =>
    drawEnemy(
      canvas: canvas,
      enemy: EnemyVisual.fromOpenWorld(e, time),
      time: time,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Open-world boss
//
// The lair boss you fight in roaming space. It shares survival's six boss
// forms (boss_forms.dart) and keeps its own tells: the charger's lance and
// the gunner's shield. It used to carry six MaskFilter.blur sites; it
// carries none.
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
  final pal = _bossPalette(boss.element, bColor, boss.enraged);

  canvas.save();
  canvas.translate(bp.dx, bp.dy);

  final form = bossFormFor(boss.type);

  // Charger: the wake it leaves while it dashes (the comet's own tail
  // streams out long and fast as well).
  if (boss.type == BossType.charger && boss.charging) {
    canvas.save();
    canvas.rotate(boss.angle);
    paintSoftCircle(
      canvas,
      Offset(-r * 1.5, 0),
      r * 0.8,
      pal.essence.withValues(alpha: 0.4),
      12,
    );
    canvas.restore();
  }

  canvas.save();
  canvas.scale(r);
  paintBossForm(
    canvas,
    pal,
    form,
    time: time,
    seed: boss.name.length * 0.7,
    heading: boss.angle,
    charge: boss.charging ? 1 : 0,
    enraged: boss.enraged,
    shield: boss.shieldUp && boss.type == BossType.bulwark,
  );
  canvas.restore();

  // The gunner: a shield of cold light while it holds. (The bulwark's is
  // the glass barrier its spire wears.)
  if (boss.type == BossType.gunner && boss.shieldUp) {
    final shieldAlpha =
        (boss.shieldHealth /
                (boss.type == BossType.bulwark
                    ? CosmicBalance.bossShieldHealth(boss.level) * 1.4
                    : CosmicBalance.bossShieldHealth(boss.level)))
            .clamp(0.0, 1.0);
    vfxSoftRing(
      canvas,
      Offset.zero,
      boss.type == BossType.bulwark ? r * 1.55 : r * 1.4,
      r * 0.2,
      const Color(0xFF7FE8F4),
      0.55 * shieldAlpha,
    );
  }

  // Health bar above boss
  final barWidth = r * 2.5;
  const barHeight = 4.0;
  final barY = -r * bossFormReach(form) - 12.0;
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

  // Boss name + level. The type used to be prefixed as an emoji — a pistol, a
  // crown, a dart board — which read as chat decoration on top of a hand-drawn
  // alchemical game. The archetype is already legible from the boss's own
  // crown and the moons riding its ring; it did not need a sticker.
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

void drawBossLair({
  required Canvas canvas,
  required BossLair lair,
  required double time,
}) {
  final lp = lair.position;

  final lColor = elementColor(lair.template.element);
  final pulse = 0.5 + 0.3 * sin(time * 2.0);

  // Ominous aura
  paintSoftCircle(canvas, Offset(lp.dx, lp.dy), BossLair.activationRadius * 0.4, const Color(0xFFFF1744).withValues(alpha: 0.06 * pulse), 40);

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
  paintSoftCircle(canvas, Offset(lp.dx, lp.dy), 6, const Color(0xFFFF1744).withValues(alpha: 0.5 * pulse), 6);
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
// Bosses no longer wear a mark: each archetype is its own form (see
// boss_forms.dart). Enemies come in dozens and get a mark of a few draws.
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
      // A band of light closing onto the body: starts wide, tightens as the
      // attack approaches. The body itself shows the charge building.
      vfxSoftRing(
        canvas,
        Offset.zero,
        r * (3.2 - 2.0 * p),
        r * (0.12 + 0.1 * p) + 1.5,
        light,
        0.35 + 0.5 * p,
      );
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
      // Vented and open: the window that pays you for reading the tell.
      vfxSoftRing(
        canvas,
        Offset.zero,
        r * 1.25,
        r * 0.14,
        Colors.white,
        0.28 * (1 - p),
      );

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
    _markFill..color = const ui.Color(0xFF05040A).withValues(alpha: 0.62 * alpha),
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
