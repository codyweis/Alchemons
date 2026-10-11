@Tags(['preview'])
library;

// THE ABILITY VFX AUDIT. Every family x element special, mid-cast, in the
// real Survival renderer, at three stat bands side by side, so a reader can
// see (a) whether the art is current and (b) whether it grows with the
// creature the way the hits do.
//
//   AUDIT_OUT=docs/ability_vfx_audit \
//     flutter test test/ability_vfx_audit_preview_test.dart --tags preview
//
// Without AUDIT_OUT both tests return at once, so a full-suite run never
// rewrites the sheets. Optional:
//   AUDIT_FAMILIES=horn,wing,basics    only these families (basics = the
//                                      auto-attack sheet)
//   AUDIT_QUALITY=cinematic            render at another SurvivalVisualQuality
//                                      (default balanced, what players get);
//                                      files gain a _cinematic suffix
//   AUDIT_SCALE=1                      sheet pixels per world unit (default
//                                      0.64); 1 shows the art at full detail
//
// The committed sheets were palette-quantized afterwards (256 colours) to
// keep the repo small; a fresh run writes full-colour PNGs.
//
// What it writes:
//   <family>_specials.png  17 rows x (3 moments x 3 bands). Each moment
//                          shows low | decent | perfect next to each other.
//   <family>_hitarea.png   the middle moment again with the hit areas the
//                          game actually uses drawn over it (legend on top).
//   basics.png             each family's auto attack, two elements, 3 bands.
//   data.json              per ability and band: the numbers the cast
//                          carries, the drawn extent of its main piece, and
//                          a draw census of the middle frame.
//
// The scene: the real CosmicSurvivalGame at the default player quality
// (balanced), one level-10 creature with all four stats set to the band, a
// cluster of seven practice bodies ~300 units off the core that never die
// for long, waves held back, ship parked and hidden. Basic attacks are held
// so the special reads alone (Kin's charged laser is not cooldown-gated and
// still fires).

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

// ── Bands ────────────────────────────────────────────────────────────────

typedef _Band = ({String name, double stat, double pot});

const List<_Band> _bands = [
  (name: 'low', stat: 3.0, pot: 35),
  (name: 'decent', stat: 4.65, pot: 55),
  (name: 'perfect', stat: 11.0, pot: 100),
];

const _families = [
  'Horn',
  'Wing',
  'Let',
  'Pip',
  'Mane',
  'Mask',
  'Kin',
  'Mystic',
];

const _elements = [
  'Fire',
  'Lava',
  'Lightning',
  'Water',
  'Ice',
  'Steam',
  'Earth',
  'Mud',
  'Dust',
  'Crystal',
  'Air',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

/// Moments after the cast at which a frame is taken, per family. Chosen so
/// the first shows the launch, the second the ability at full reach and the
/// third what it leaves behind.
const Map<String, List<double>> _moments = {
  'Horn': [0.35, 1.0, 2.2],
  'Wing': [0.25, 0.8, 1.8],
  'Let': [0.35, 0.65, 1.6],
  'Pip': [0.05, 0.15, 0.6],
  'Mane': [0.3, 1.0, 2.2],
  'Mask': [0.3, 1.3, 3.0],
  'Kin': [0.3, 1.3, 3.0],
  'Mystic': [1.0, 4.0, 9.0],
};

/// Camera zoom per family. A Mystic's world spreads over the arena, so it is
/// framed twice as wide; everything else is at 1.0.
const Map<String, double> _zoom = {'Mystic': 0.5};

// World window per frame, and how much it is shrunk on the sheet
// (AUDIT_SCALE=1 draws a world unit per sheet pixel, for close review).
const double _viewW = 560, _viewH = 420;
final double _outScale =
    double.tryParse(Platform.environment['AUDIT_SCALE'] ?? '') ?? 0.64;
final int _cellW = (_viewW * _outScale).round();
final int _cellH = (_viewH * _outScale).round();
const double _dt = 1 / 60;

/// The quality the sheets are drawn at. Players get `balanced` by default
/// (CinematicQuality.cinematic maps to it in cosmic_survival_screen.dart).
final SurvivalVisualQuality _quality = SurvivalVisualQuality.values.firstWhere(
  (q) => q.name == Platform.environment['AUDIT_QUALITY'],
  orElse: () => SurvivalVisualQuality.balanced,
);
final String _suffix = _quality == SurvivalVisualQuality.balanced
    ? ''
    : '_${_quality.name}';

// ── Draw census ──────────────────────────────────────────────────────────

/// Records what a frame asks the GPU to do (mirrors survival_orb_budget_test).
class _Census implements Canvas {
  final Map<String, int> counts = {};
  int blurred = 0;
  int stroked = 0;
  int saveLayers = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    if (key == 'saveLayer') saveLayers++;
    for (final a in i.positionalArguments) {
      if (a is Paint) {
        if (a.maskFilter != null || a.imageFilter != null) blurred++;
        if (key.startsWith('draw') && a.style == PaintingStyle.stroke) {
          stroked++;
        }
      }
    }
    switch (key) {
      case 'getSaveCount':
        return 1;
      case 'getTransform':
        return Float64List.fromList([
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]);
      case 'getLocalClipBounds':
      case 'getDestinationClipBounds':
        return Rect.largest;
    }
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);

  Map<String, Object> toJson() => {
    'draws': draws,
    'blurred': blurred,
    'stroked': stroked,
    'saveLayers': saveLayers,
    'byKind': {
      for (final e in counts.entries)
        if (e.key.startsWith('draw') || e.key == 'saveLayer') e.key: e.value,
    },
  };
}

// ── The scene ────────────────────────────────────────────────────────────

/// The real Survival game with the waves held back: one companion, one
/// cluster of practice bodies that hold their posts and come back when they
/// fall. Modelled on AbilityPreviewGame (lib/screens/ability_preview_screen
/// .dart), which this cannot reuse because it owns its practice ring.
class _AuditGame extends CosmicSurvivalGame {
  _AuditGame(CosmicPartyMember member)
    : super(
        party: [member],
        random: Random(7),
        onGameOver: () {},
        visualQuality: _quality,
      );

  static const _shipInvolvedKin = {
    'Light', 'Water', 'Crystal', 'Air', 'Mud', 'Lava', //
    'Dark', 'Lightning', 'Steam', 'Blood',
  };
  late final bool shipInvolved =
      party.first.family.toLowerCase() == 'kin' &&
      _shipInvolvedKin.contains(party.first.element);
  late final Offset shipSeat = shipInvolved
      ? const Offset(0, 130)
      : Offset.zero;

  final Set<CosmicSurvivalEnemy> _mine = Set.identity();
  final Map<int, CosmicSurvivalEnemy?> _slots = {};
  final Map<int, double> _respawn = {};
  final Map<CosmicSurvivalEnemy, Offset> _posts = Map.identity();
  late Offset clusterCentre;
  Offset? frameCentre;

  static const _cluster = <(Offset, EnemyTier)>[
    (Offset.zero, EnemyTier.sentinel),
    (Offset(42, 0), EnemyTier.drone),
    (Offset(21, 36), EnemyTier.drone),
    (Offset(-21, 36), EnemyTier.drone),
    (Offset(-42, 0), EnemyTier.drone),
    (Offset(-21, -36), EnemyTier.drone),
    (Offset(21, -36), EnemyTier.drone),
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    startGame();
    renderShip = shipInvolved;
    setCameraZoom(viewZoom);
    summonCompanion(0);
    clearCompanionTether();
    ship.position = orb.position + shipSeat;
    clusterCentre = orb.position + const Offset(290, -90);
    for (var i = 0; i < _cluster.length; i++) {
      _spawn(i);
    }
  }

  void _spawn(int slot) {
    final (offset, tier) = _cluster[slot];
    const hp = 5e6;
    final body = CosmicSurvivalEnemy(
      position: clusterCentre + offset,
      hp: hp,
      maxHp: hp,
      speed: 0,
      damage: 0,
      radius: tierRadius(tier),
      tier: tier,
      element: const ['Earth', 'Water', 'Fire', 'Ice'][slot % 4],
      conduct: EnemyConduct.charge,
      target: CosmicEnemyTarget.orb,
      retargetTimer: 99999,
    );
    enemies.add(body);
    _mine.add(body);
    _posts[body] = body.position;
    _slots[slot] = body;
    _respawn.remove(slot);
  }

  double viewZoom = 1.0;

  /// Puts the caster in reach of the cluster and frames the pair. A Kin
  /// works on the core and the ship, so it starts beside them and the frame
  /// takes in core, ship and cluster.
  void placeCaster(CosmicSurvivalCompanion comp) {
    comp.steeringVelocity = Offset.zero;
    if (party.first.family.toLowerCase() == 'kin') {
      comp.position = orb.position + const Offset(90, 30);
      frameOn(orb.position + const Offset(110, 20));
      return;
    }
    comp.position = clusterCentre + const Offset(-170, 40);
    frameOn(clusterCentre + const Offset(-85, 20));
  }

  void frameOn(Offset centre) {
    frameCentre = centre;
    setCameraZoom(viewZoom);
    cameraPanOffset = centre - ship.position;
  }

  @override
  void update(double dt) {
    if (isLoaded) {
      alchemicalMeter = 0;
      showingPowerUpSelection = false;
      gamePaused = false;
      isGameOver = false;
      orb.currentHp = orb.maxHp;
      ship.currentHp = ship.maxHp;
      ship.isDead = false;
      ship.position = orb.position + shipSeat;
      ship.fireTimer = double.negativeInfinity;
      final comp = activeCompanions[0];
      if (comp != null) comp.currentHp = comp.maxHp;
    }
    super.update(dt);
    if (!isLoaded) return;
    enemies.removeWhere((e) => !_mine.contains(e));
    activeBoss = null;
    extraBosses.clear();
    final settle = (dt * 6).clamp(0.0, 1.0);
    for (final e in enemies) {
      final post = _posts[e];
      if (post == null || e.isDead) continue;
      e.position = Offset.lerp(e.position, post, settle)!;
    }
    for (final entry in _slots.entries.toList()) {
      final body = entry.value;
      if (body == null || !body.isDead) continue;
      _mine.remove(body);
      _posts.remove(body);
      _slots[entry.key] = null;
      _respawn[entry.key] = 0.8;
    }
    for (final slot in _respawn.keys.toList()) {
      final t = _respawn[slot]! - dt;
      if (t <= 0) {
        _spawn(slot);
      } else {
        _respawn[slot] = t;
      }
    }
    if (frameCentre != null) cameraPanOffset = frameCentre! - ship.position;
  }
}

// ── Species, sprites, fonts ──────────────────────────────────────────────

final Map<String, Map<String, dynamic>> _species = {};
final Map<String, ui.Image> _sheets = {};

void _loadSpecies() {
  final rows =
      (jsonDecode(
                File('assets/data/alchemons_creatures.json').readAsStringSync(),
              )
              as Map<String, dynamic>)['creatures']
          as List;
  for (final r in rows.cast<Map<String, dynamic>>()) {
    final fam = r['mutationFamily'] as String?;
    final types = (r['types'] as List?)?.cast<String>() ?? const [];
    if (fam == null || types.isEmpty) continue;
    _species.putIfAbsent('$fam/${types.first}', () => r);
  }
}

String? _sheetPath(Map<String, dynamic> row) {
  final image = row['image'] as String?;
  if (image == null) return null;
  return image.replaceFirst('.png', '_spritesheet.png');
}

Future<ui.Image?> _sheetImage(String path) async {
  if (_sheets.containsKey(path)) return _sheets[path];
  final f = File('assets/images/$path');
  if (!f.existsSync()) return null;
  final codec = await ui.instantiateImageCodec(f.readAsBytesSync());
  final frame = await codec.getNextFrame();
  _sheets[path] = frame.image;
  return frame.image;
}

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  await (FontLoader(
    family,
  )..addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)))).load();
}

Future<CosmicPartyMember> _member(
  String family,
  String element,
  _Band band,
) async {
  final row = _species['$family/$element'];
  SpriteSheetDef? sheet;
  if (row != null) {
    final sd = row['spriteData'] as Map<String, dynamic>?;
    final path = _sheetPath(row);
    if (sd != null && path != null && await _sheetImage(path) != null) {
      sheet = SpriteSheetDef(
        path: path,
        totalFrames: (sd['totalFrames'] as int?) ?? 4,
        rows: (sd['rows'] as int?) ?? 1,
        frameSize: Vector2(
          ((sd['frameWidth'] as int?) ?? 512).toDouble(),
          ((sd['frameHeight'] as int?) ?? 512).toDouble(),
        ),
        stepTime: ((sd['frameDurationMs'] as int?) ?? 120) / 1000,
      );
    }
  }
  return CosmicPartyMember(
    instanceId: 'audit-$family-$element-${band.name}',
    baseId: (row?['id'] as String?) ?? 'AUD01',
    displayName: (row?['name'] as String?) ?? '$element$family',
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: band.stat,
    statIntelligence: band.stat,
    statStrength: band.stat,
    statBeauty: band.stat,
    statSpeedPotential: band.pot,
    statIntelligencePotential: band.pot,
    statStrengthPotential: band.pot,
    statBeautyPotential: band.pot,
    staminaBars: 3,
    staminaMax: 3,
    spriteSheet: sheet,
  );
}

Future<_AuditGame> _game(String family, String element, _Band band) async {
  final member = await _member(family, element, band);
  final g = _AuditGame(member)..viewZoom = _zoom[family] ?? 1.0;
  g.onGameResize(Vector2(_viewW, _viewH));
  final sheet = member.spriteSheet;
  if (sheet != null) {
    final img = _sheets[sheet.path];
    if (img != null) g.images.add(sheet.path, img.clone());
  }
  await g.onLoad();
  // Let the sprite load (it is cached, so this is a microtask or two).
  await Future<void>.delayed(const Duration(milliseconds: 5));
  return g;
}

// ── Rendering ────────────────────────────────────────────────────────────

Future<ui.Image> _shot(
  _AuditGame g, {
  void Function(Canvas)? overlay,
}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
    Rect.fromLTWH(0, 0, _cellW.toDouble(), _cellH.toDouble()),
    Paint()..color = const Color(0xFF040508),
  );
  c.save();
  c.scale(_outScale);
  g.render(c);
  c.restore();
  if (overlay != null) {
    c.save();
    c.scale(_outScale);
    c.scale(g.cameraZoom);
    c.translate(-g.camX, -g.camY);
    overlay(c);
    c.restore();
  }
  final pic = rec.endRecording();
  final img = await pic.toImage(_cellW, _cellH);
  pic.dispose();
  return img;
}

/// The hit areas the game will actually use, drawn over a frame.
///   cyan    contact radius  (Projectile.radius x radiusMultiplier)
///   yellow  effectRadius    (zone tick / burst / aura)
///   green   snareRadius     (slow / pull)
///   orange  tauntRadius
///   blue    interceptRadius (eats hostile shots)
///   red     Let skyfall blast / crater radius
///   white   Horn charge sweep radius (on the creature)
void _hitOverlay(Canvas c, _AuditGame g) {
  Paint ring(Color color) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6 / _outScale
    ..color = color;
  final cyan = ring(const Color(0xE600E5FF));
  final yellow = ring(const Color(0xE6FFE14D));
  final green = ring(const Color(0xE64DFF6A));
  final orange = ring(const Color(0xE6FF9A3D));
  final blue = ring(const Color(0xE64D7CFF));
  final red = ring(const Color(0xE6FF3B3B));
  for (final p in g.companionProjectiles) {
    if (p.life <= 0 || p.sourceSlotIndex != 0) continue;
    if (p.isDescending) {
      c.drawCircle(p.skyfallImpact, letSkyfallBlastRadius(p), red);
      continue;
    }
    c.drawCircle(p.position, Projectile.radius * p.radiusMultiplier, cyan);
    if (p.effectRadius > 0) c.drawCircle(p.position, p.effectRadius, yellow);
    if (p.snareRadius > 0) c.drawCircle(p.position, p.snareRadius, green);
    if (p.tauntRadius > 0) c.drawCircle(p.position, p.tauntRadius, orange);
    if (p.interceptRadius > 0) {
      c.drawCircle(p.position, p.interceptRadius, blue);
    }
    if (p.letCraterRadius > 0) {
      c.drawCircle(p.position, p.letCraterRadius, red);
    }
  }
  final comp = g.activeCompanions[0];
  if (comp != null && comp.chargeSweepRadius > 0 && comp.chargeTimer > 0) {
    c.drawCircle(
      comp.position,
      comp.chargeSweepRadius,
      ring(const Color(0xE6FFFFFF)),
    );
  }
}

Map<String, Object> _liveNumbers(_AuditGame g) {
  final mine = g.companionProjectiles
      .where((p) => p.life > 0 && p.sourceSlotIndex == 0)
      .toList();
  double mx(double Function(Projectile) f) =>
      mine.isEmpty ? 0 : mine.map(f).reduce(max);
  final comp = g.activeCompanions[0];
  return {
    'projectiles': mine.length,
    'maxHitR': _r(mx((p) => Projectile.radius * p.radiusMultiplier)),
    'maxVisualScale': _r(mx((p) => p.visualScale)),
    'maxEffectR': _r(mx((p) => p.effectRadius)),
    'maxSnareR': _r(mx((p) => p.snareRadius)),
    'maxTauntR': _r(mx((p) => p.tauntRadius)),
    'maxInterceptR': _r(mx((p) => p.interceptRadius)),
    'maxSkyfallBlastR': _r(
      mx((p) => p.isDescending ? letSkyfallBlastRadius(p) : 0),
    ),
    'maxCraterR': _r(mx((p) => p.letCraterRadius)),
    'chargeSweepR': _r(comp?.chargeSweepRadius ?? 0),
    'vfxParticles': g.vfxParticleCount,
  };
}

double _r(double v) => (v * 10).roundToDouble() / 10;

// ── Pure numbers + isolated drawn extent ─────────────────────────────────

/// The survival projectile painter chain (_renderCompanionProjectile), with
/// the survival-only inline Kin+Spirit painter left out. Balanced quality:
/// mask reduceAmbient is true there, the rest false.
bool _paintProjectile(Canvas c, Projectile p, double time) {
  final col = elementColor(p.element ?? 'Fire');
  final at = p.position;
  if (drawKinSpiritWispVisual(
    canvas: c,
    projectile: p,
    position: at,
    color: col,
    time: time,
  )) {
    return true;
  }
  if (drawMysticOrbitalProjectileVisual(
    canvas: c,
    projectile: p,
    position: at,
    color: col,
    time: time,
  )) {
    return true;
  }
  if (drawMysticOrbitalFixtureVisual(
    canvas: c,
    projectile: p,
    position: at,
    color: col,
    time: time,
  )) {
    return true;
  }
  if (drawMaskElementalProjectileVisual(
    canvas: c,
    projectile: p,
    position: at,
    color: col,
    time: time,
    reduceAmbient: true,
  )) {
    return true;
  }
  var drawn =
      drawLetElementalProjectileVisual(
        canvas: c,
        projectile: p,
        position: at,
        color: col,
        time: time,
      ) ||
      drawPipElementalProjectileVisual(
        canvas: c,
        projectile: p,
        position: at,
        color: col,
        time: time,
      ) ||
      drawManeElementalProjectileVisual(
        canvas: c,
        projectile: p,
        position: at,
        color: col,
        time: time,
      ) ||
      drawHornElementalProjectileVisual(
        canvas: c,
        projectile: p,
        position: at,
        color: col,
        time: time,
      );
  if (!drawn) {
    drawGenericProjectileVisual(
      canvas: c,
      projectile: p,
      position: at,
      color: col,
      time: time,
    );
    drawn = true;
  }
  drawProjectileRoleOverlay(
    canvas: c,
    projectile: p,
    position: at,
    color: col,
    time: time,
  );
  return drawn;
}

/// Renders [p] alone on transparent black and measures how far its pixels
/// reach: r80 holds 80% of the drawn alpha, rMax is the farthest pixel at
/// 8% alpha or more.
Future<({double r80, double rMax, int draws, int blurred, int stroked})>
_extent(Projectile p) async {
  const size = 1024;
  const centre = Offset(size / 2, size / 2);
  final saved = p.position;
  p.position = centre;
  final census = _Census();
  _paintProjectile(census as Canvas, p, 1.3);
  final rec = ui.PictureRecorder();
  _paintProjectile(Canvas(rec), p, 1.3);
  p.position = saved;
  final pic = rec.endRecording();
  final img = await pic.toImage(size, size);
  pic.dispose();
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  img.dispose();
  final bytes = data.buffer.asUint8List();
  final hist = List<double>.filled(size, 0);
  var total = 0.0;
  var rMax = 0.0;
  for (var y = 0; y < size; y += 2) {
    for (var x = 0; x < size; x += 2) {
      final a = bytes[(y * size + x) * 4 + 3];
      if (a == 0) continue;
      final d = sqrt(pow(x - centre.dx, 2) + pow(y - centre.dy, 2));
      hist[min(size - 1, d.floor())] += a;
      total += a;
      if (a >= 20 && d > rMax) rMax = d;
    }
  }
  var acc = 0.0;
  var r80 = 0.0;
  for (var i = 0; i < size; i++) {
    acc += hist[i];
    if (acc >= total * 0.8) {
      r80 = i.toDouble();
      break;
    }
  }
  return (
    r80: r80,
    rMax: rMax,
    draws: census.draws,
    blurred: census.blurred,
    stroked: census.stroked,
  );
}

Future<Map<String, Object>> _pureNumbers(
  String family,
  String element,
  _Band band,
) async {
  final result = createCosmicSpecialAbility(
    origin: Offset.zero,
    baseAngle: 0,
    family: family,
    element: element,
    damage: 100,
    maxHp: 400,
    casterPower: band.stat,
    casterBeauty: band.stat,
    casterIntelligence: band.stat,
    casterStrength: band.stat,
    casterBeautyPotential: band.pot,
    targetPos: const Offset(160, 0),
  );
  final ps = result.projectiles;
  double mx(double Function(Projectile) f) =>
      ps.isEmpty ? 0 : ps.map(f).reduce(max);
  final out = <String, Object>{
    'projectiles': ps.length,
    'maxHitR': _r(mx((p) => Projectile.radius * p.radiusMultiplier)),
    'maxVisualScale': _r(mx((p) => p.visualScale)),
    'maxEffectR': _r(mx((p) => p.effectRadius)),
    'maxSnareR': _r(mx((p) => p.snareRadius)),
    'maxTauntR': _r(mx((p) => p.tauntRadius)),
    'maxInterceptR': _r(mx((p) => p.interceptRadius)),
    'maxOrbitR': _r(mx((p) => p.orbitRadius)),
    'maxLife': _r(mx((p) => p.life.isFinite ? p.life : -1)),
    'skyfallBlastR': _r(
      mx((p) => p.skyfallDuration > 0 ? letSkyfallBlastRadius(p) : 0),
    ),
    'beams': result.beams.length,
    if (result.beams.isNotEmpty) ...{
      'beamWidth': _r(result.beams.map((b) => b.width).reduce(max)),
      'beamRange': _r(result.beams.map((b) => b.range).reduce(max)),
      'beamRadius': _r(result.beams.map((b) => b.radius).reduce(max)),
      'beamDuration': _r(result.beams.map((b) => b.duration).reduce(max)),
    },
    'chargeSweepR': _r(result.chargeSweepRadius),
    'chargeFinalSweepR': _r(result.chargeFinalSweepRadius),
    'shieldHp': result.shieldHp,
  };
  // The piece with the biggest hit area, drawn alone.
  if (ps.isNotEmpty) {
    final main = ps.reduce(
      (a, b) =>
          max(a.radiusMultiplier * 3, a.effectRadius) >=
              max(b.radiusMultiplier * 3, b.effectRadius)
          ? a
          : b,
    );
    final e = await _extent(main);
    out['main'] = {
      'style': main.visualStyle.name,
      'stationary': main.stationary,
      'hitR': _r(Projectile.radius * main.radiusMultiplier),
      'effectR': _r(main.effectRadius),
      'visualScale': _r(main.visualScale),
      'drawnR80': e.r80,
      'drawnRMax': e.rMax,
      'draws': e.draws,
      'blurred': e.blurred,
      'stroked': e.stroked,
    };
  }
  return out;
}

/// A Wing beam drawn alone, horizontally: how wide does it read against the
/// width it hits with?
Future<({double fullWidth, int draws, int stroked})> _beamExtent(
  String element,
  double width,
) async {
  const w = 1024, h = 400;
  void paint(Canvas c) => drawAdvancedAbilityBeam(
    canvas: c,
    start: const Offset(100, h / 2),
    end: const Offset(900, h / 2),
    color: elementColor(element),
    wingElement: element,
    width: width,
    alpha: 1,
    time: 1.3,
  );
  final census = _Census();
  paint(census as Canvas);
  final rec = ui.PictureRecorder();
  paint(Canvas(rec));
  final pic = rec.endRecording();
  final img = await pic.toImage(w, h);
  pic.dispose();
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  img.dispose();
  final bytes = data.buffer.asUint8List();
  // Widest lit band over several columns along the beam.
  var full = 0.0;
  for (final x in [300, 450, 600, 750]) {
    int? top, bottom;
    for (var y = 0; y < h; y++) {
      if (bytes[(y * w + x) * 4 + 3] >= 20) {
        top ??= y;
        bottom = y;
      }
    }
    if (top != null) full = max(full, (bottom! - top + 1).toDouble());
  }
  return (fullWidth: full, draws: census.draws, stroked: census.stroked);
}

// ── Sheets ───────────────────────────────────────────────────────────────

const _ink = Color(0xFF07080B);
const _brass = Color(0xFFCDB98A);
const _dim = Color(0xFF8A8170);

void _text(
  Canvas c,
  String s,
  Offset at, {
  double size = 13,
  Color color = _brass,
  double maxWidth = 900,
  FontWeight weight = FontWeight.w400,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: 'AuditSans',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: 1.25,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  tp.paint(c, at);
}

const double _labelW = 190;
const double _gap = 4;
const double _groupGap = 16;
const double _headerH = 92;

Future<void> _writeSheet({
  required String path,
  required String title,
  required List<String> groupTitles,
  required List<String> rowLabels,
  required List<String> rowNotes,
  required List<List<ui.Image?>> cells, // [row][group*3 + band]
  String? legend,
}) async {
  final groups = groupTitles.length;
  final groupW = 3 * _cellW + 2 * _gap;
  final width = _labelW + groups * groupW + (groups - 1) * _groupGap + 8;
  final rowH = _cellH + _gap;
  final height = _headerH + rowLabels.length * rowH + 8;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = _ink);
  _text(c, title, const Offset(10, 8), size: 17, weight: FontWeight.w600);
  if (legend != null) {
    _text(c, legend, const Offset(10, 32), size: 12, color: _dim);
  }
  for (var gi = 0; gi < groups; gi++) {
    final gx = _labelW + gi * (groupW + _groupGap);
    _text(c, groupTitles[gi], Offset(gx, 52), size: 13);
    for (var b = 0; b < 3; b++) {
      final band = _bands[b];
      _text(
        c,
        '${band.name}  ${band.stat}',
        Offset(gx + b * (_cellW + _gap) + 4, 72),
        size: 12,
        color: _dim,
      );
    }
  }
  final src = Paint()..filterQuality = FilterQuality.medium;
  for (var r = 0; r < rowLabels.length; r++) {
    final y = _headerH + r * rowH;
    _text(
      c,
      rowLabels[r],
      Offset(10, y + 6),
      size: 15,
      weight: FontWeight.w600,
    );
    _text(
      c,
      rowNotes[r],
      Offset(10, y + 28),
      size: 11,
      color: _dim,
      maxWidth: _labelW - 16,
    );
    for (var i = 0; i < cells[r].length; i++) {
      final img = cells[r][i];
      final gi = i ~/ 3, b = i % 3;
      final x = _labelW + gi * (groupW + _groupGap) + b * (_cellW + _gap);
      if (img == null) {
        _text(c, 'no cast', Offset(x + 8, y + 8), color: _dim);
        continue;
      }
      c.drawImage(img, Offset(x, y), src);
    }
  }
  final pic = rec.endRecording();
  final out = await pic.toImage(width.round(), height.round());
  pic.dispose();
  final png = await out.toByteData(format: ui.ImageByteFormat.png);
  out.dispose();
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

// ── One cast ─────────────────────────────────────────────────────────────

class _CastRun {
  final List<ui.Image?> frames = [];
  ui.Image? overlay;
  Map<String, Object>? census;
  Map<String, Object>? baseline;
  Map<String, Object>? live;
  double castAt = -1;
  bool cast = false;
}

Future<_CastRun> _runSpecial(
  String family,
  String element,
  _Band band,
  List<double> moments,
) async {
  final g = await _game(family, element, band);
  final run = _CastRun();
  final comp = g.activeCompanions[0]!;
  var t = 0.0;
  void step() {
    comp.basicCooldown = 1e9;
    g.update(_dt);
    t += _dt;
  }

  // Settle in with nothing fired.
  for (var i = 0; i < 90; i++) {
    comp.specialCooldown = 1e9;
    step();
  }
  // Every subject starts its cast from the same spot, in reach of the
  // cluster: fast flyers otherwise wander out of special range and never
  // cast, and the frames would not line up across bands.
  g.placeCaster(comp);
  g.frameOn(g.frameCentre!);
  final base = _Census();
  g.render(base as Canvas);
  run.baseline = base.toJson();

  final passive = isPassiveOnlyCosmicAbility(family, element);
  if (!passive) {
    comp.specialCooldown = 0;
    final limit = t + 5;
    while (t < limit) {
      step();
      if (comp.specialCooldown > 0.3) {
        run.cast = true;
        break;
      }
    }
    // No second cast inside the window being photographed.
    if (run.cast) comp.specialCooldown = max(comp.specialCooldown, 1e9);
  } else {
    run.cast = true;
  }
  run.castAt = t;
  for (var m = 0; m < moments.length; m++) {
    while (t < run.castAt + moments[m]) {
      step();
    }
    run.frames.add(await _shot(g));
    if (m == 1) {
      final census = _Census();
      g.render(census as Canvas);
      run.census = census.toJson();
      run.live = _liveNumbers(g);
      run.overlay = await _shot(g, overlay: (c) => _hitOverlay(c, g));
    }
  }
  return run;
}

Future<List<ui.Image?>> _runBasic(
  String family,
  String element,
  _Band band,
  List<Map<String, Object>> census,
) async {
  final g = await _game(family, element, band);
  final comp = g.activeCompanions[0]!;
  final frames = <ui.Image?>[];
  var t = 0.0;
  void step() {
    comp.specialCooldown = 1e9;
    g.update(_dt);
    t += _dt;
  }

  for (var i = 0; i < 60; i++) {
    step();
  }
  g.placeCaster(comp);
  // Wait for a basic in flight (Kin's laser has no projectile: time-based).
  final isKin = family == 'Kin';
  final limit = t + 4;
  while (t < limit) {
    step();
    if (!isKin &&
        g.companionProjectiles.any(
          (p) => p.sourceSlotIndex == 0 && p.abilityFamily.isEmpty,
        )) {
      break;
    }
  }
  if (isKin) {
    while (t < limit) {
      step();
    }
  }
  for (final dtAfter in [0.08, 0.3]) {
    final until = t + dtAfter;
    while (t < until) {
      step();
    }
    frames.add(await _shot(g));
    if (dtAfter == 0.08) {
      final c = _Census();
      g.render(c as Canvas);
      census.add({
        'family': family,
        'element': element,
        'band': band.name,
        ...c.toJson(),
        'basicProjectiles': g.companionProjectiles
            .where((p) => p.sourceSlotIndex == 0 && p.abilityFamily.isEmpty)
            .length,
      });
    }
  }
  return frames;
}

// ── The test ─────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final outDir = Platform.environment['AUDIT_OUT'];
  final only = Platform.environment['AUDIT_FAMILIES']
      ?.split(',')
      .map((s) => s.trim().toLowerCase())
      .toSet();

  setUpAll(() async {
    // The ability particle grain is built at load, off the frame; wait for
    // it so every frame shows grains rather than the fallback discs.
    await AbilityGrainSprite.ensureLoaded();
    _loadSpecies();
    await _loadFont('AuditSans', '/System/Library/Fonts/Supplemental/Arial.ttf');
    await _loadFont('Roboto', '/System/Library/Fonts/Supplemental/Arial.ttf');
  });

  test('ability vfx audit: every special at three stat bands', () async {
    if (outDir == null) return;
    final data = <String, Object>{};
    final dataFile = File('$outDir/data$_suffix.json');
    if (dataFile.existsSync()) {
      final prior = jsonDecode(dataFile.readAsStringSync());
      if (prior is Map<String, dynamic>) data.addAll(prior.cast());
    }
    final specials = (data['specials'] as Map?)?.cast<String, Object>() ?? {};
    for (final family in _families) {
      if (only != null && !only.contains(family.toLowerCase())) continue;
      final moments = _moments[family]!;
      final cells = <List<ui.Image?>>[];
      final overlays = <List<ui.Image?>>[];
      final labels = <String>[];
      final notes = <String>[];
      for (final element in _elements) {
        final rowCells = List<ui.Image?>.filled(9, null);
        final rowOverlay = List<ui.Image?>.filled(3, null);
        final entry = <String, Object>{};
        final pure = <Map<String, Object>>[];
        final deltas = <int>[];
        for (var b = 0; b < 3; b++) {
          final band = _bands[b];
          final run = await _runSpecial(family, element, band, moments);
          for (var m = 0; m < run.frames.length; m++) {
            rowCells[m * 3 + b] = run.cast ? run.frames[m] : null;
          }
          rowOverlay[b] = run.cast ? run.overlay : null;
          final p = await _pureNumbers(family, element, band);
          if (p['beams'] != 0) {
            final be = await _beamExtent(element, p['beamWidth']! as double);
            p['beamDrawnWidth'] = be.fullWidth;
            p['beamDraws'] = be.draws;
            p['beamStroked'] = be.stroked;
          }
          pure.add(p);
          final drawsNow = (run.census?['draws'] as int?) ?? 0;
          final drawsBase = (run.baseline?['draws'] as int?) ?? 0;
          deltas.add(drawsNow - drawsBase);
          entry[band.name] = {
            'cast': run.cast,
            'passiveOnly': isPassiveOnlyCosmicAbility(family, element),
            'pure': p,
            'live': run.live ?? {},
            'census': run.census ?? {},
            'baseline': run.baseline ?? {},
            'deltaDraws': drawsNow - drawsBase,
          };
        }
        specials['$family/$element'] = entry;
        cells.add(rowCells);
        overlays.add(rowOverlay);
        String trio(String key) =>
            pure.map((p) => '${p[key] ?? 0}').join('/');
        final blur = [
          for (final b in _bands)
            ((entry[b.name]! as Map)['census'] as Map)['blurred'] ?? 0,
        ].join('/');
        labels.add(element);
        notes.add(
          [
            'proj ${trio('projectiles')}',
            'hit r ${trio('maxHitR')}',
            if (pure.any((p) => (p['maxEffectR'] as double) > 0))
              'fx r ${trio('maxEffectR')}',
            if (pure.any((p) => (p['beams'] as int) > 0))
              'beam w ${trio('beamWidth')} (drawn ${trio('beamDrawnWidth')})',
            // Every result carries a default sweep; only a Horn charges.
            if (family == 'Horn')
              'sweep r ${trio('chargeSweepR')}',
            if (pure.any((p) => (p['skyfallBlastR'] as double) > 0))
              'blast r ${trio('skyfallBlastR')}',
            'vis ${trio('maxVisualScale')}',
            '+draws ${deltas.join('/')}',
            'blur $blur',
            if (isPassiveOnlyCosmicAbility(family, element)) 'PASSIVE',
          ].join('\n'),
        );
        // ignore: avoid_print
        print('$family/$element  draws+ ${deltas.join('/')}');
      }
      await _writeSheet(
        path: '$outDir/${family.toLowerCase()}_specials$_suffix.png',
        title:
            '${family.toUpperCase()} specials  ·  survival renderer, ${_quality.name} '
            'quality, level 10, all four stats = band'
            '${(_zoom[family] ?? 1.0) == 1.0 ? '' : '  ·  camera zoom ${_zoom[family]}'}',
        legend:
            'Each moment shows low | decent | perfect side by side. '
            'Left column: low/decent/perfect numbers from the cast.',
        groupTitles: [for (final m in moments) 't + ${m}s after cast'],
        rowLabels: labels,
        rowNotes: notes,
        cells: cells,
      );
      await _writeSheet(
        path: '$outDir/${family.toLowerCase()}_hitarea$_suffix.png',
        title: '${family.toUpperCase()} hit areas at t + ${moments[1]}s',
        legend:
            'cyan contact  yellow effect  green snare  orange taunt  '
            'blue intercept  red skyfall/crater  white horn sweep',
        groupTitles: ['t + ${moments[1]}s'],
        rowLabels: labels,
        rowNotes: notes,
        cells: overlays,
      );
      for (final row in [...cells, ...overlays]) {
        for (final img in row) {
          img?.dispose();
        }
      }
    }
    data['specials'] = specials;
    data['bands'] = [
      for (final b in _bands) {'name': b.name, 'stat': b.stat, 'pot': b.pot},
    ];
    File(dataFile.path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(data));
  }, timeout: const Timeout(Duration(minutes: 90)));

  test('ability vfx audit: basic attacks at three stat bands', () async {
    if (outDir == null) return;
    if (only != null && !only.contains('basics')) return;
    const picks = {
      'Horn': ['Fire', 'Ice'],
      'Wing': ['Air', 'Lightning'],
      'Let': ['Earth', 'Lava'],
      'Pip': ['Lightning', 'Plant'],
      'Mane': ['Fire', 'Dark'],
      'Mask': ['Poison', 'Spirit'],
      'Kin': ['Water', 'Light'],
      'Mystic': ['Spirit', 'Crystal'],
    };
    final cells = <List<ui.Image?>>[];
    final labels = <String>[];
    final notes = <String>[];
    final census = <Map<String, Object>>[];
    for (final e in picks.entries) {
      for (final element in e.value) {
        final row = List<ui.Image?>.filled(6, null);
        for (var b = 0; b < 3; b++) {
          final frames = await _runBasic(e.key, element, _bands[b], census);
          row[b] = frames[0];
          row[3 + b] = frames[1];
        }
        cells.add(row);
        labels.add('${e.key} $element');
        final mine = census
            .where((c) => c['family'] == e.key && c['element'] == element)
            .toList();
        notes.add(
          'draws ${mine.map((c) => c['draws']).join('/')}\n'
          'blur ${mine.map((c) => c['blurred']).join('/')}\n'
          'stroked ${mine.map((c) => c['stroked']).join('/')}',
        );
      }
    }
    await _writeSheet(
      path: '$outDir/basics$_suffix.png',
      title:
          'Basic attacks  ·  survival renderer, ${_quality.name} quality, '
          'level 10',
      legend: 'Each moment shows low | decent | perfect side by side.',
      groupTitles: const ['t + 0.08s after a shot', 't + 0.38s'],
      rowLabels: labels,
      rowNotes: notes,
      cells: cells,
    );
    final dataFile = File('$outDir/basics$_suffix.json');
    dataFile
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(census));
  }, timeout: const Timeout(Duration(minutes: 30)));
}
