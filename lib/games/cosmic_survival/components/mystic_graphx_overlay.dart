import 'dart:math';

import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:flutter/material.dart';
import 'package:graphx/graphx.dart';

class MysticGraphxOverlayController {
  _MysticGraphxScene? _scene;

  void _attach(_MysticGraphxScene scene) {
    _scene = scene;
  }

  void _detach(_MysticGraphxScene scene) {
    if (identical(_scene, scene)) {
      _scene = null;
    }
  }

  void spawn(MysticSpecialCastEvent event) {
    _scene?.spawn(event);
  }

  void clear() {
    _scene?.clearEffects();
  }

  void dispose() {
    _scene = null;
  }
}

class MysticGraphxOverlay extends StatefulWidget {
  final MysticGraphxOverlayController controller;

  const MysticGraphxOverlay({super.key, required this.controller});

  @override
  State<MysticGraphxOverlay> createState() => _MysticGraphxOverlayState();
}

class _MysticGraphxOverlayState extends State<MysticGraphxOverlay> {
  late final _MysticGraphxScene _scene;

  @override
  void initState() {
    super.initState();
    _scene = _MysticGraphxScene();
    widget.controller._attach(_scene);
  }

  @override
  void dispose() {
    widget.controller._detach(_scene);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SceneBuilderWidget(
        autoSize: true,
        builder: () =>
            SceneController(front: _scene, config: SceneConfig.autoRender),
      ),
    );
  }
}

class _MysticGraphxScene extends GSprite {
  static const int _maxTopLevelEffects = 34;
  static const int _spawnWindowMs = 700;

  final Random _rng = Random();
  final List<int> _recentSpawnMs = <int>[];
  int _qualityTier = 3;

  void clearEffects() {
    _recentSpawnMs.clear();
    removeChildren(0, -1, true);
  }

  void spawn(MysticSpecialCastEvent e) {
    _qualityTier = _captureQualityTier(e.isEcho);
    _trimTopLevelEffects();

    final x = e.originScreen.dx;
    final y = e.originScreen.dy;
    final tx = e.targetScreen?.dx;
    final ty = e.targetScreen?.dy;
    final echo = e.isEcho;

    if (_qualityTier <= 0) {
      _castQuickPulse(x, y, e.element, echo: echo);
      return;
    }

    if (_qualityTier >= 2) {
      _castAlchemySeal(x, y, e.element, tx: tx, ty: ty, echo: echo);
    } else if (!echo) {
      _castQuickPulse(x, y, e.element, echo: false);
    }

    switch (e.element) {
      case 'Fire':
        _castFire(x, y, echo: echo);
      case 'Lava':
        _castLava(x, y, echo: echo);
      case 'Lightning':
        _castLightning(x, y, tx: tx, ty: ty, echo: echo);
      case 'Water':
        _castWater(x, y, tx: tx, ty: ty, echo: echo);
      case 'Ice':
        _castIce(x, y, echo: echo);
      case 'Steam':
        _castSteam(x, y, echo: echo);
      case 'Earth':
        _castEarth(x, y, echo: echo);
      case 'Mud':
        _castMud(x, y, echo: echo);
      case 'Dust':
        _castDust(x, y, echo: echo);
      case 'Crystal':
        _castCrystal(x, y, echo: echo);
      case 'Air':
        _castAir(x, y, echo: echo);
      case 'Plant':
        _castPlant(x, y, tx: tx, ty: ty, echo: echo);
      case 'Poison':
        _castPoison(x, y, echo: echo);
      case 'Spirit':
        _castSpirit(x, y, tx: tx, ty: ty, echo: echo);
      case 'Dark':
        _castDark(x, y, echo: echo);
      case 'Light':
        _castLight(x, y, echo: echo);
      case 'Blood':
        _castBlood(x, y, echo: echo);
      default:
        _castDefault(x, y, echo: echo);
    }

    _trimTopLevelEffects();
  }

  int _captureQualityTier(bool echo) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _recentSpawnMs.removeWhere((t) => now - t > _spawnWindowMs);
    _recentSpawnMs.add(now);

    final pressure = numChildren + (_recentSpawnMs.length * (echo ? 2 : 3));
    if (echo && pressure > 36) return 0;
    if (pressure > 30) return 1;
    if (pressure > 18) return 2;
    return 3;
  }

  void _trimTopLevelEffects() {
    while (numChildren > _maxTopLevelEffects) {
      removeChildAt(0, true);
    }
  }

  int _count(int normal, int echo, bool isEcho) {
    final base = isEcho ? echo : normal;
    final scale = switch (_qualityTier) {
      >= 3 => 1.0,
      2 => 0.72,
      1 => 0.46,
      _ => 0.25,
    };
    return max(1, (base * scale).round());
  }

  // ─── shape helpers ────────────────────────────────────────────────────────

  GShape _circle(GSprite parent, double r, Color c) {
    final s = parent.addChild(GShape());
    s.graphics
      ..beginFill(c)
      ..drawCircle(0, 0, r)
      ..endFill();
    return s;
  }

  GShape _rect(GSprite parent, double w, double h, Color c) {
    final s = parent.addChild(GShape());
    s.graphics
      ..beginFill(c)
      ..drawRect(-w / 2, -h / 2, w, h)
      ..endFill();
    return s;
  }

  GShape _ring(GSprite parent, double r, double stroke, Color c) {
    final s = parent.addChild(GShape());
    s.graphics
      ..lineStyle(stroke, c)
      ..drawCircle(0, 0, r)
      ..endFill();
    return s;
  }

  GShape _line(
    GSprite parent,
    double x1,
    double y1,
    double x2,
    double y2,
    double stroke,
    Color c,
  ) {
    final s = parent.addChild(GShape());
    s.graphics
      ..lineStyle(stroke, c)
      ..moveTo(x1, y1)
      ..lineTo(x2, y2)
      ..endFill();
    return s;
  }

  GShape _polygon(
    GSprite parent,
    int sides,
    double r,
    double stroke,
    Color c, {
    double rotation = 0,
  }) {
    final s = parent.addChild(GShape());
    s.graphics
      ..lineStyle(stroke, c)
      ..drawPolygonFaces(0, 0, r, sides, rotation)
      ..endFill();
    return s;
  }

  void _autoDispose(GDisplayObject obj, double lifetime) {
    GTween.to(
      obj,
      lifetime,
      {'alpha': 0.0},
      GVars(ease: GEase.easeIn, onComplete: () => obj.removeFromParent(true)),
    );
  }

  _MysticPalette _paletteFor(String element) {
    switch (element) {
      case 'Fire':
        return const _MysticPalette(
          Color(0xFFFF7043),
          Color(0xFFFFCC80),
          Color(0xFFFF3D00),
        );
      case 'Lava':
        return const _MysticPalette(
          Color(0xFFFF6D00),
          Color(0xFFFFD180),
          Color(0xFFBF360C),
        );
      case 'Lightning':
        return const _MysticPalette(
          Color(0xFFFFEB3B),
          Color(0xFFFFFFFF),
          Color(0xFF40C4FF),
        );
      case 'Water':
        return const _MysticPalette(
          Color(0xFF448AFF),
          Color(0xFF80D8FF),
          Color(0xFF01579B),
        );
      case 'Ice':
        return const _MysticPalette(
          Color(0xFF00E5FF),
          Color(0xFFE0F7FA),
          Color(0xFF80DEEA),
        );
      case 'Steam':
        return const _MysticPalette(
          Color(0xFFB0BEC5),
          Color(0xFFECEFF1),
          Color(0xFF78909C),
        );
      case 'Earth':
        return const _MysticPalette(
          Color(0xFF8D6E63),
          Color(0xFFD7CCC8),
          Color(0xFF4E342E),
        );
      case 'Mud':
        return const _MysticPalette(
          Color(0xFF5D4037),
          Color(0xFF8D6E63),
          Color(0xFF3E2723),
        );
      case 'Dust':
        return const _MysticPalette(
          Color(0xFFFFCC80),
          Color(0xFFFFE0B2),
          Color(0xFF8D6E63),
        );
      case 'Crystal':
        return const _MysticPalette(
          Color(0xFF1DE9B6),
          Color(0xFF448AFF),
          Color(0xFFE0F2F1),
        );
      case 'Air':
        return const _MysticPalette(
          Color(0xFF81D4FA),
          Color(0xFFE1F5FE),
          Color(0xFF26C6DA),
        );
      case 'Plant':
        return const _MysticPalette(
          Color(0xFF4CAF50),
          Color(0xFF8BC34A),
          Color(0xFF33691E),
        );
      case 'Poison':
        return const _MysticPalette(
          Color(0xFF9C27B0),
          Color(0xFFC8E6C9),
          Color(0xFF4A148C),
        );
      case 'Spirit':
        return const _MysticPalette(
          Color(0xFFBBDEFB),
          Color(0xFF3F51B5),
          Color(0xFF7E57C2),
        );
      case 'Dark':
        return const _MysticPalette(
          Color(0xFF4A148C),
          Color(0xFFB39DDB),
          Color(0xFF12001F),
        );
      case 'Light':
        return const _MysticPalette(
          Color(0xFFFFE082),
          Color(0xFFFFFFFF),
          Color(0xFFFFC107),
        );
      case 'Blood':
        return const _MysticPalette(
          Color(0xFFD32F2F),
          Color(0xFFFFCDD2),
          Color(0xFFFF1744),
        );
      default:
        return const _MysticPalette(
          Color(0xFF7E57C2),
          Color(0xFFCE93D8),
          Color(0xFF4527A0),
        );
    }
  }

  void _castQuickPulse(
    double x,
    double y,
    String element, {
    required bool echo,
  }) {
    final p = _paletteFor(element);
    final root = addChild(GSprite())
      ..x = x
      ..y = y
      ..alpha = echo ? 0.7 : 1.0;

    final pulse = _ring(root, echo ? 10.0 : 14.0, 1.8, p.primary);
    GTween.to(
      pulse,
      0.24,
      {'scaleX': 2.3, 'scaleY': 2.3, 'alpha': 0.0},
      GVars(
        ease: GEase.easeOut,
        onComplete: () => pulse.removeFromParent(true),
      ),
    );

    final spark = _circle(
      root,
      echo ? 3.0 : 4.5,
      p.accent.withValues(alpha: 0.75),
    );
    GTween.to(
      spark,
      0.18,
      {'scale': 0.25, 'alpha': 0.0},
      GVars(ease: GEase.easeIn, onComplete: () => spark.removeFromParent(true)),
    );

    _autoDispose(root, 0.30);
  }

  void _castAlchemySeal(
    double x,
    double y,
    String element, {
    double? tx,
    double? ty,
    required bool echo,
  }) {
    final p = _paletteFor(element);
    final root = addChild(GSprite())
      ..x = x
      ..y = y
      ..alpha = echo ? 0.62 : 0.9;

    final base = echo ? 18.0 : 24.0;
    final outer = _ring(root, base, 1.0, p.primary.withValues(alpha: 0.58));
    final inner = _ring(
      root,
      base * 0.58,
      0.9,
      p.accent.withValues(alpha: 0.42),
    );
    final triA = _polygon(
      root,
      3,
      base * 0.88,
      1.1,
      p.accent.withValues(alpha: 0.62),
      rotation: -pi / 2,
    );
    final triB = _polygon(
      root,
      3,
      base * 0.76,
      0.9,
      p.primary.withValues(alpha: 0.46),
      rotation: pi / 2,
    );
    final hex = _polygon(
      root,
      6,
      base * 1.12,
      0.8,
      p.shadow.withValues(alpha: 0.50),
      rotation: pi / 6,
    );

    outer.scale = 0.55;
    inner.scale = 0.45;
    triA.scale = 0.60;
    triB.scale = 0.55;
    hex.scale = 0.66;

    final runes = _count(12, 7, echo);
    for (var i = 0; i < runes; i++) {
      final a = i * (pi * 2 / runes);
      final mark = i.isEven
          ? _rect(root, 1.2, 4.2, p.accent.withValues(alpha: 0.56))
          : _circle(root, 1.35, p.primary.withValues(alpha: 0.52));
      mark
        ..x = cos(a) * base * 1.18
        ..y = sin(a) * base * 1.18
        ..rotation = a + pi / 2
        ..scale = 0.4;
      GTween.to(mark, 0.16, {
        'scale': 1.0,
      }, GVars(ease: GEase.easeOut, delay: i * 0.012));
    }

    if (tx != null && ty != null) {
      if (_qualityTier >= 3) {
        _leyLine(x, y, tx, ty, p, echo: echo);
      }
      if (_qualityTier >= 2) {
        _castTargetSeal(tx, ty, p, echo: echo);
      }
    }

    if (_qualityTier >= 3) {
      _castReagentOrbit(root, base, p, echo: echo);
    }

    GTween.to(
      root,
      echo ? 0.42 : 0.52,
      {
        'scaleX': echo ? 1.45 : 1.7,
        'scaleY': echo ? 1.45 : 1.7,
        'rotation': echo ? -0.45 : 0.62,
        'alpha': 0.0,
      },
      GVars(ease: GEase.easeOut, onComplete: () => root.removeFromParent(true)),
    );
  }

  void _castReagentOrbit(
    GSprite root,
    double base,
    _MysticPalette p, {
    required bool echo,
  }) {
    final reagents = _count(6, 3, echo);
    for (var i = 0; i < reagents; i++) {
      final a = i * (pi * 2 / reagents) + 0.18;
      final mote = i.isEven
          ? _polygon(
              root,
              4,
              echo ? 2.0 : 2.6,
              0.7,
              p.accent.withValues(alpha: 0.62),
              rotation: pi / 4,
            )
          : _circle(root, echo ? 1.5 : 2.0, p.primary.withValues(alpha: 0.58));
      mote
        ..x = cos(a) * base * 0.92
        ..y = sin(a) * base * 0.92
        ..rotation = a
        ..scale = 0.45;
      GTween.to(mote, echo ? 0.30 : 0.40, {
        'x': cos(a + 0.45) * base * 1.52,
        'y': sin(a + 0.45) * base * 1.52,
        'rotation': a + 1.4,
        'scale': 1.0,
        'alpha': 0.0,
      }, GVars(ease: GEase.easeOut, delay: i * 0.018));
    }
  }

  void _castTargetSeal(
    double x,
    double y,
    _MysticPalette p, {
    required bool echo,
  }) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y
      ..scale = 0.62
      ..alpha = echo ? 0.52 : 0.82;
    final base = echo ? 13.0 : 18.0;

    _ring(root, base * 1.12, 0.9, p.accent.withValues(alpha: 0.52));
    _ring(root, base * 0.58, 0.75, p.primary.withValues(alpha: 0.42));
    _polygon(
      root,
      4,
      base * 0.62,
      1.0,
      p.shadow.withValues(alpha: 0.48),
      rotation: pi / 4,
    );

    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2 + pi / 4;
      _line(
        root,
        cos(a) * base * 0.34,
        sin(a) * base * 0.34,
        cos(a) * base * 1.25,
        sin(a) * base * 1.25,
        0.8,
        p.primary.withValues(alpha: 0.36),
      );
    }

    final motes = _count(8, 4, echo);
    for (var i = 0; i < motes; i++) {
      final a = i * (pi * 2 / motes);
      final mote = _circle(
        root,
        echo ? 1.0 : 1.25,
        i.isEven
            ? p.accent.withValues(alpha: 0.58)
            : p.primary.withValues(alpha: 0.48),
      );
      mote
        ..x = cos(a) * base * 1.38
        ..y = sin(a) * base * 1.38;
      GTween.to(mote, echo ? 0.24 : 0.32, {
        'x': cos(a) * base * 0.54,
        'y': sin(a) * base * 0.54,
        'scale': 0.35,
        'alpha': 0.0,
      }, GVars(ease: GEase.easeIn, delay: i * 0.012));
    }

    GTween.to(
      root,
      echo ? 0.34 : 0.44,
      {
        'scaleX': echo ? 1.12 : 1.28,
        'scaleY': echo ? 1.12 : 1.28,
        'rotation': echo ? 0.35 : -0.55,
        'alpha': 0.0,
      },
      GVars(ease: GEase.easeOut, onComplete: () => root.removeFromParent(true)),
    );
  }

  void _leyLine(
    double x1,
    double y1,
    double x2,
    double y2,
    _MysticPalette p, {
    required bool echo,
  }) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 24) return;

    final root = addChild(GSprite());
    final segments = _count(7, 4, echo);
    for (var i = 0; i < segments; i++) {
      final startT = i / segments;
      final endT = min(1.0, startT + 0.5 / segments);
      final bend = sin(startT * pi) * (echo ? 8.0 : 14.0);
      final nx = -dy / len;
      final ny = dx / len;
      _line(
        root,
        x1 + dx * startT + nx * bend,
        y1 + dy * startT + ny * bend,
        x1 + dx * endT + nx * bend,
        y1 + dy * endT + ny * bend,
        echo ? 1.0 : 1.35,
        i.isEven
            ? p.primary.withValues(alpha: 0.42)
            : p.accent.withValues(alpha: 0.52),
      );
    }

    final nodes = _count(4, 2, echo);
    for (var i = 0; i < nodes; i++) {
      final t = (i + 1) / (nodes + 1);
      final node = _circle(
        root,
        echo ? 1.3 : 1.7,
        p.accent.withValues(alpha: 0.58),
      );
      node
        ..x = x1 + dx * t
        ..y = y1 + dy * t;
    }

    GTween.to(
      root,
      echo ? 0.26 : 0.34,
      {'alpha': 0.0},
      GVars(ease: GEase.easeIn, onComplete: () => root.removeFromParent(true)),
    );
  }

  // ─── FIRE — Supernova Collapse ────────────────────────────────────────────
  // Ring expands outward then embers collapse inward.
  void _castFire(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int count = _count(10, 6, echo);
    final double r0 = echo ? 12.0 : 16.0;

    final ring1 = _ring(root, r0, 2.0, const Color(0xFFFF7043));
    GTween.to(
      ring1,
      0.30,
      {'scaleX': 4.2, 'scaleY': 4.2, 'alpha': 0.0},
      GVars(
        ease: GEase.easeOut,
        onComplete: () => ring1.removeFromParent(true),
      ),
    );

    for (var i = 0; i < count; i++) {
      final a = i * (pi * 2 / count);
      final ember = _circle(
        root,
        2.5 + _rng.nextDouble() * 1.5,
        const Color(0xFFFFCC80),
      );
      final dist = 36.0 + _rng.nextDouble() * 20;
      final ex = cos(a) * dist;
      final ey = sin(a) * dist;
      GTween.to(
        ember,
        0.22,
        {'x': ex, 'y': ey},
        GVars(
          ease: GEase.easeOut,
          onComplete: () {
            GTween.to(
              ember,
              0.28,
              {'x': 0.0, 'y': 0.0, 'alpha': 0.0, 'scale': 0.4},
              GVars(
                ease: GEase.easeIn,
                onComplete: () => ember.removeFromParent(true),
              ),
            );
          },
        ),
      );
    }

    final core = _circle(
      root,
      r0 * 1.5,
      const Color(0xFFFFA726).withValues(alpha: 0.75),
    );
    GTween.to(
      core,
      0.38,
      {'scale': 0.1, 'alpha': 0.0},
      GVars(ease: GEase.easeIn, onComplete: () => core.removeFromParent(true)),
    );

    _autoDispose(root, 0.55);
  }

  // ─── LAVA — Cataclysm Moons ───────────────────────────────────────────────
  // Crater pulse; molten blobs drip downward.
  void _castLava(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int blobs = _count(6, 4, echo);

    final crater = _ring(
      root,
      echo ? 18.0 : 24.0,
      3.5,
      const Color(0xFFEF6C00),
    );
    GTween.to(
      crater,
      0.45,
      {'scaleX': 2.8, 'scaleY': 2.8, 'alpha': 0.0},
      GVars(
        ease: GEase.easeOut,
        onComplete: () => crater.removeFromParent(true),
      ),
    );

    final core = _circle(
      root,
      10.0,
      const Color(0xFFFF3D00).withValues(alpha: 0.9),
    );
    GTween.to(
      core,
      0.18,
      {'scale': 1.6},
      GVars(
        ease: GEase.easeOut,
        onComplete: () {
          GTween.to(
            core,
            0.35,
            {'scale': 0.3, 'alpha': 0.0},
            GVars(
              ease: GEase.easeIn,
              onComplete: () => core.removeFromParent(true),
            ),
          );
        },
      ),
    );

    for (var i = 0; i < blobs; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final blob = _circle(
        root,
        2.0 + _rng.nextDouble() * 2.5,
        i.isEven ? const Color(0xFFFF6D00) : const Color(0xFFFFCC80),
      );
      blob.x = cos(angle) * (4 + _rng.nextDouble() * 8);
      blob.y = sin(angle) * (4 + _rng.nextDouble() * 8);
      final dropY = 24.0 + _rng.nextDouble() * 30;
      GTween.to(
        blob,
        0.42 + _rng.nextDouble() * 0.28,
        {'y': blob.y + dropY, 'alpha': 0.0, 'scale': 0.5},
        GVars(
          ease: GEase.easeIn,
          onComplete: () => blob.removeFromParent(true),
        ),
      );
    }

    _autoDispose(root, 0.55);
  }

  // ─── LIGHTNING — Storm Lattice ────────────────────────────────────────────
  // Instant zigzag arcs burst outward.
  void _castLightning(
    double x,
    double y, {
    double? tx,
    double? ty,
    required bool echo,
  }) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int bolts = _count(9, 5, echo);
    const Color cYellow = Color(0xFFFFEB3B);
    const Color cWhite = Color(0xFFFFFFFF);

    for (var i = 0; i < bolts; i++) {
      final a = i * (pi * 2 / bolts) + _rng.nextDouble() * 0.3;
      final len = 28.0 + _rng.nextDouble() * 24;
      final bolt = addChild(GSprite())
        ..x = x
        ..y = y;

      final shape = bolt.addChild(GShape());
      final g = shape.graphics;
      g.lineStyle(1.8, cWhite);
      var cx2 = 0.0;
      var cy2 = 0.0;
      const segs = 4;
      for (var s = 0; s < segs; s++) {
        final t = (s + 1) / segs;
        final nx = cos(a) * len * t + (_rng.nextDouble() - 0.5) * 12;
        final ny = sin(a) * len * t + (_rng.nextDouble() - 0.5) * 12;
        if (s == 0) g.moveTo(cx2, cy2);
        g.lineTo(nx, ny);
        cx2 = nx;
        cy2 = ny;
      }
      g.endFill();

      final glow = bolt.addChild(GShape());
      glow.graphics
        ..lineStyle(4.0, cYellow.withValues(alpha: 0.3))
        ..moveTo(0, 0)
        ..lineTo(cos(a) * len, sin(a) * len)
        ..endFill();

      GTween.to(
        bolt,
        0.18,
        {'alpha': 0.0},
        GVars(
          ease: GEase.easeIn,
          onComplete: () => bolt.removeFromParent(true),
        ),
      );
    }

    final flash = _circle(
      root,
      echo ? 8.0 : 12.0,
      cWhite.withValues(alpha: 0.9),
    );
    GTween.to(
      flash,
      0.14,
      {'scale': 2.2, 'alpha': 0.0},
      GVars(
        ease: GEase.easeOut,
        onComplete: () => flash.removeFromParent(true),
      ),
    );

    if (tx != null && ty != null) {
      _arcTrail(
        x,
        y,
        tx,
        ty,
        color: cYellow,
        accentColor: cWhite,
        lifetime: 0.16,
      );
    }

    _autoDispose(root, 0.22);
  }

  // ─── WATER — Tidal Crescent ───────────────────────────────────────────────
  // Two arc sweeps converge; droplets spray.
  void _castWater(
    double x,
    double y, {
    double? tx,
    double? ty,
    required bool echo,
  }) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final double r = echo ? 20.0 : 28.0;
    const Color cBlue = Color(0xFF448AFF);
    const Color cCyan = Color(0xFF80D8FF);

    for (var side = -1; side <= 1; side += 2) {
      final arc = root.addChild(GSprite());
      final shape = arc.addChild(GShape());
      shape.graphics
        ..lineStyle(2.4, cBlue.withValues(alpha: 0.85))
        ..moveTo(r * cos(-0.6 * side), r * sin(-0.6 * side))
        ..lineTo(r * cos(0.0), r * sin(0.0))
        ..lineTo(r * cos(0.6 * side), r * sin(0.6 * side))
        ..endFill();
      arc.rotation = side * 0.6;
      GTween.to(
        arc,
        0.38,
        {'rotation': side * (-0.4), 'scaleX': 1.4, 'scaleY': 1.4, 'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          onComplete: () => arc.removeFromParent(true),
        ),
      );
    }

    final int drops = _count(9, 5, echo);
    for (var i = 0; i < drops; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final drop = _circle(
        root,
        1.4 + _rng.nextDouble() * 2.0,
        i.isEven ? cBlue.withValues(alpha: 0.9) : cCyan.withValues(alpha: 0.85),
      );
      final dist = 14 + _rng.nextDouble() * 22;
      GTween.to(
        drop,
        0.34 + _rng.nextDouble() * 0.18,
        {'x': cos(a) * dist, 'y': sin(a) * dist, 'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          onComplete: () => drop.removeFromParent(true),
        ),
      );
    }

    if (tx != null && ty != null) {
      _arcTrail(x, y, tx, ty, color: cBlue, accentColor: cCyan, lifetime: 0.30);
    }

    _autoDispose(root, 0.46);
  }

  // ─── ICE — Glacier Crown ──────────────────────────────────────────────────
  // Hex geometry forms, then lance shards eject outward.
  void _castIce(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int points = _count(6, 4, echo);
    final double r = echo ? 16.0 : 22.0;
    const Color cIce = Color(0xFF00E5FF);
    const Color cWhite = Color(0xFFE0F7FA);

    for (var i = 0; i < points; i++) {
      final a1 = i * (pi * 2 / points);
      final a2 = (i + 1) * (pi * 2 / points);
      final seg = _line(
        root,
        r * cos(a1),
        r * sin(a1),
        r * cos(a2),
        r * sin(a2),
        1.8,
        cIce.withValues(alpha: 0.0),
      );
      GTween.to(
        seg,
        0.20,
        {'alpha': 0.9},
        GVars(
          ease: GEase.easeOut,
          delay: i * 0.04,
          onComplete: () {
            GTween.to(
              seg,
              0.30,
              {'alpha': 0.0},
              GVars(
                ease: GEase.easeIn,
                delay: 0.18,
                onComplete: () => seg.removeFromParent(true),
              ),
            );
          },
        ),
      );
    }

    final int shards = _count(8, 5, echo);
    for (var i = 0; i < shards; i++) {
      final a = i * (pi * 2 / shards) + _rng.nextDouble() * 0.2;
      final shard = _rect(root, 2.2, 8.0, i.isEven ? cIce : cWhite);
      shard.rotation = a + pi / 2;
      shard.x = cos(a) * r * 0.6;
      shard.y = sin(a) * r * 0.6;
      GTween.to(
        shard,
        0.10,
        {'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          delay: 0.22,
          onComplete: () {
            shard.alpha = 0.9;
            GTween.to(
              shard,
              0.28,
              {
                'x': cos(a) * (r + 36),
                'y': sin(a) * (r + 36),
                'alpha': 0.0,
                'scaleY': 0.3,
              },
              GVars(
                ease: GEase.easeIn,
                onComplete: () => shard.removeFromParent(true),
              ),
            );
          },
        ),
      );
    }

    _autoDispose(root, 0.72);
  }

  // ─── STEAM — Whiteout Veil ────────────────────────────────────────────────
  // Cloud puffs drift upward; fog ring expands.
  void _castSteam(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int puffs = _count(9, 5, echo);
    const Color cSteam = Color(0xFFB0BEC5);
    const Color cWhite = Color(0xFFECEFF1);

    for (var i = 0; i < puffs; i++) {
      final puff = _circle(
        root,
        6.0 + _rng.nextDouble() * 5.0,
        i.isEven
            ? cSteam.withValues(alpha: 0.62)
            : cWhite.withValues(alpha: 0.48),
      );
      puff.x = (_rng.nextDouble() - 0.5) * 16;
      puff.y = (_rng.nextDouble() - 0.5) * 10;
      final driftX = (_rng.nextDouble() - 0.5) * 18;
      final driftY = -18 - _rng.nextDouble() * 24;
      GTween.to(
        puff,
        0.55 + _rng.nextDouble() * 0.35,
        {
          'x': puff.x + driftX,
          'y': puff.y + driftY,
          'alpha': 0.0,
          'scale': 1.9,
        },
        GVars(
          ease: GEase.easeOut,
          delay: i * 0.04,
          onComplete: () => puff.removeFromParent(true),
        ),
      );
    }

    final ring = _ring(
      root,
      echo ? 14.0 : 18.0,
      2.0,
      cSteam.withValues(alpha: 0.7),
    );
    GTween.to(
      ring,
      0.40,
      {'scaleX': 2.8, 'scaleY': 2.8, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => ring.removeFromParent(true)),
    );

    _autoDispose(root, 0.90);
  }

  // ─── EARTH — Monolith Constellation ──────────────────────────────────────
  // Stone shards eject; crater ring pulses.
  void _castEarth(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int shards = _count(8, 5, echo);
    const Color cBrown = Color(0xFF795548);
    const Color cDust = Color(0xFFD7CCC8);

    final crater = _ring(root, echo ? 14.0 : 20.0, 3.0, cBrown);
    GTween.to(
      crater,
      0.38,
      {'scaleX': 2.5, 'scaleY': 2.5, 'alpha': 0.0},
      GVars(
        ease: GEase.easeOut,
        onComplete: () => crater.removeFromParent(true),
      ),
    );

    for (var i = 0; i < shards; i++) {
      final a = i * (pi * 2 / shards) + _rng.nextDouble() * 0.3;
      final shard = _rect(
        root,
        3.0 + _rng.nextDouble() * 2.5,
        5.0 + _rng.nextDouble() * 4.0,
        i.isEven ? cBrown : cDust.withValues(alpha: 0.9),
      );
      shard.rotation = a;
      final dist = 20 + _rng.nextDouble() * 18;
      GTween.to(
        shard,
        0.34 + _rng.nextDouble() * 0.18,
        {
          'x': cos(a) * dist,
          'y': sin(a) * dist + 12,
          'alpha': 0.0,
          'rotation': shard.rotation + (_rng.nextDouble() - 0.5) * 1.2,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => shard.removeFromParent(true),
        ),
      );
    }

    final dust = _circle(root, 12.0, cDust.withValues(alpha: 0.45))..y = 4;
    GTween.to(
      dust,
      0.42,
      {'scaleX': 2.6, 'scaleY': 1.2, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => dust.removeFromParent(true)),
    );

    _autoDispose(root, 0.55);
  }

  // ─── MUD — Mire Eclipse ───────────────────────────────────────────────────
  // Thick splat; drops arc up then drip.
  void _castMud(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int drops = _count(9, 5, echo);
    const Color cMud = Color(0xFF5D4037);
    const Color cBrown = Color(0xFF8D6E63);

    final splat = _circle(
      root,
      echo ? 12.0 : 16.0,
      cMud.withValues(alpha: 0.82),
    );
    GTween.to(
      splat,
      0.16,
      {'scaleX': 1.7, 'scaleY': 0.8},
      GVars(
        ease: GEase.easeOut,
        onComplete: () {
          GTween.to(
            splat,
            0.40,
            {'alpha': 0.0},
            GVars(
              ease: GEase.easeIn,
              onComplete: () => splat.removeFromParent(true),
            ),
          );
        },
      ),
    );

    for (var i = 0; i < drops; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final drop = _circle(
        root,
        1.8 + _rng.nextDouble() * 2.5,
        i.isEven ? cMud : cBrown,
      );
      final dist = 12 + _rng.nextDouble() * 16;
      GTween.to(
        drop,
        0.18,
        {'x': cos(a) * dist * 0.7, 'y': sin(a) * dist * 0.7 - 8},
        GVars(
          ease: GEase.easeOut,
          onComplete: () {
            GTween.to(
              drop,
              0.26,
              {'y': drop.y + 14.0, 'alpha': 0.0, 'scaleX': 1.4, 'scaleY': 0.5},
              GVars(
                ease: GEase.easeIn,
                onComplete: () => drop.removeFromParent(true),
              ),
            );
          },
        ),
      );
    }

    _autoDispose(root, 0.58);
  }

  // ─── DUST — Sirocco Halo ──────────────────────────────────────────────────
  // Golden Fibonacci spiral of tiny motes fans outward.
  void _castDust(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int count = _count(18, 10, echo);
    const double phi = 1.6180339887;
    const Color cGold = Color(0xFFFFCC80);
    const Color cDust = Color(0xFFFFE0B2);

    for (var i = 0; i < count; i++) {
      final a = i * phi * pi * 2;
      final r0 = 4.0 + i * 2.2;
      final mote = _circle(
        root,
        1.2 + _rng.nextDouble() * 1.0,
        i.isEven ? cGold.withValues(alpha: 0.9) : cDust.withValues(alpha: 0.85),
      );
      mote.x = cos(a) * r0;
      mote.y = sin(a) * r0;
      final travelR = r0 + 20 + _rng.nextDouble() * 18;
      GTween.to(
        mote,
        0.30 + i * 0.012,
        {
          'x': cos(a) * travelR,
          'y': sin(a) * travelR,
          'alpha': 0.0,
          'scale': 0.4,
        },
        GVars(
          ease: GEase.easeOut,
          delay: i * 0.010,
          onComplete: () => mote.removeFromParent(true),
        ),
      );
    }

    _autoDispose(root, 0.70);
  }

  // ─── CRYSTAL — Prism Cathedral ────────────────────────────────────────────
  // Star fracture lines + multi-color facets.
  void _castCrystal(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int spikes = _count(8, 5, echo);
    const Color cCyan = Color(0xFF1DE9B6);
    const Color cBlue = Color(0xFF448AFF);
    const Color cWhite = Color(0xFFE0F2F1);

    for (var i = 0; i < spikes; i++) {
      final a = i * (pi * 2 / spikes);
      final len = 22 + _rng.nextDouble() * 14;
      final spike = _line(
        root,
        0,
        0,
        cos(a) * len,
        sin(a) * len,
        2.2,
        i % 3 == 0 ? cWhite : (i.isEven ? cCyan : cBlue),
      );
      spike.alpha = 0.9;
      GTween.to(
        spike,
        0.28,
        {'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          delay: 0.05,
          onComplete: () => spike.removeFromParent(true),
        ),
      );
    }

    final int facets = _count(7, 4, echo);
    for (var i = 0; i < facets; i++) {
      final a = i * (pi * 2 / facets) + 0.3;
      final facet = _rect(
        root,
        2.5,
        6.0,
        [cCyan, cBlue, cWhite][i % 3].withValues(alpha: 0.85),
      );
      facet.rotation = a + pi / 2;
      final dist = 10 + _rng.nextDouble() * 14;
      GTween.to(
        facet,
        0.26 + _rng.nextDouble() * 0.18,
        {'x': cos(a) * dist, 'y': sin(a) * dist, 'alpha': 0.0, 'scale': 0.3},
        GVars(
          ease: GEase.easeOut,
          onComplete: () => facet.removeFromParent(true),
        ),
      );
    }

    final ring = _ring(
      root,
      echo ? 12.0 : 16.0,
      1.6,
      cCyan.withValues(alpha: 0.8),
    );
    GTween.to(
      ring,
      0.34,
      {'scaleX': 2.4, 'scaleY': 2.4, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => ring.removeFromParent(true)),
    );

    _autoDispose(root, 0.48);
  }

  // ─── AIR — Cyclone Halo ───────────────────────────────────────────────────
  // Spinning orbit ring + velocity arcs.
  void _castAir(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int arcs = _count(7, 4, echo);
    final double r = echo ? 18.0 : 26.0;
    const Color cAir = Color(0xFF81D4FA);
    const Color cWhite = Color(0xFFE1F5FE);

    final outerRing = _ring(root, r, 1.8, cAir.withValues(alpha: 0.6));
    GTween.to(
      outerRing,
      0.45,
      {'scaleX': 1.6, 'scaleY': 1.6, 'alpha': 0.0, 'rotation': 1.4},
      GVars(
        ease: GEase.easeOut,
        onComplete: () => outerRing.removeFromParent(true),
      ),
    );

    for (var i = 0; i < arcs; i++) {
      final a = i * (pi * 2 / arcs);
      final arc = root.addChild(GSprite())
        ..x = cos(a) * r
        ..y = sin(a) * r;
      _line(
        arc,
        0,
        0,
        cos(a + pi / 2) * 14,
        sin(a + pi / 2) * 14,
        2.0,
        i.isEven ? cAir : cWhite,
      );
      GTween.to(
        arc,
        0.30,
        {'scaleX': 0.3, 'alpha': 0.0},
        GVars(
          ease: GEase.easeIn,
          delay: i * 0.04,
          onComplete: () => arc.removeFromParent(true),
        ),
      );
    }

    final swirl = _ring(root, r * 0.45, 2.2, cWhite.withValues(alpha: 0.7));
    GTween.to(
      swirl,
      0.38,
      {'scaleX': 0.2, 'scaleY': 0.2, 'rotation': 2.0, 'alpha': 0.0},
      GVars(ease: GEase.easeIn, onComplete: () => swirl.removeFromParent(true)),
    );

    _autoDispose(root, 0.52);
  }

  // ─── PLANT — Verdant Procession ───────────────────────────────────────────
  // Vine extends toward target; thorn nodes burst at intervals.
  void _castPlant(
    double x,
    double y, {
    double? tx,
    double? ty,
    required bool echo,
  }) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    const Color cGreen = Color(0xFF4CAF50);
    const Color cLeaf = Color(0xFF8BC34A);
    const Color cThorn = Color(0xFF33691E);

    final double angle = (tx != null && ty != null)
        ? atan2(ty - y, tx - x)
        : 0.0;
    final int nodes = _count(5, 3, echo);
    const double spacing = 26.0;

    final vine = _line(
      root,
      0,
      0,
      cos(angle) * nodes * spacing,
      sin(angle) * nodes * spacing,
      1.5,
      cGreen.withValues(alpha: 0.0),
    );
    GTween.to(
      vine,
      0.22,
      {'alpha': 0.7},
      GVars(
        ease: GEase.easeOut,
        onComplete: () {
          GTween.to(
            vine,
            0.42,
            {'alpha': 0.0},
            GVars(
              ease: GEase.easeIn,
              delay: 0.30,
              onComplete: () => vine.removeFromParent(true),
            ),
          );
        },
      ),
    );

    for (var i = 0; i < nodes; i++) {
      final dist = (i + 1) * spacing;
      final nx = cos(angle) * dist;
      final ny = sin(angle) * dist;
      final delay = i * 0.07;

      final bud = _circle(
        root,
        3.5 + _rng.nextDouble() * 2.0,
        i.isEven ? cGreen : cLeaf,
      );
      bud
        ..x = nx
        ..y = ny
        ..scale = 0.0
        ..alpha = 0.0;
      GTween.to(
        bud,
        0.18,
        {'scale': 1.2, 'alpha': 0.9},
        GVars(
          ease: GEase.easeOut,
          delay: delay,
          onComplete: () {
            GTween.to(
              bud,
              0.30,
              {'scale': 0.2, 'alpha': 0.0},
              GVars(
                ease: GEase.easeIn,
                delay: 0.20,
                onComplete: () => bud.removeFromParent(true),
              ),
            );
          },
        ),
      );

      for (var side = -1; side <= 1; side += 2) {
        final ta = angle + side * pi / 3;
        final thorn = _line(
          root,
          nx,
          ny,
          nx + cos(ta) * 8,
          ny + sin(ta) * 8,
          1.5,
          cThorn.withValues(alpha: 0.0),
        );
        GTween.to(
          thorn,
          0.14,
          {'alpha': 0.85},
          GVars(
            ease: GEase.easeOut,
            delay: delay + 0.06,
            onComplete: () {
              GTween.to(
                thorn,
                0.24,
                {'alpha': 0.0},
                GVars(
                  ease: GEase.easeIn,
                  delay: 0.18,
                  onComplete: () => thorn.removeFromParent(true),
                ),
              );
            },
          ),
        );
      }
    }

    _autoDispose(root, 0.88);
  }

  // ─── POISON — Venom Halo ──────────────────────────────────────────────────
  // Toxic rings expand; bubbles rise.
  void _castPoison(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int bubbles = _count(10, 6, echo);
    const Color cPurple = Color(0xFF9C27B0);
    const Color cLime = Color(0xFFC8E6C9);

    for (var ri = 0; ri < 2; ri++) {
      final ring = _ring(
        root,
        (echo ? 12.0 : 16.0) + ri * 8,
        2.0,
        ri == 0 ? cPurple.withValues(alpha: 0.8) : cLime.withValues(alpha: 0.6),
      );
      GTween.to(
        ring,
        0.48 + ri * 0.14,
        {'scaleX': 2.6, 'scaleY': 2.6, 'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          delay: ri * 0.08,
          onComplete: () => ring.removeFromParent(true),
        ),
      );
    }

    for (var i = 0; i < bubbles; i++) {
      final bubble = _circle(
        root,
        1.5 + _rng.nextDouble() * 2.0,
        i.isEven
            ? cPurple.withValues(alpha: 0.75)
            : cLime.withValues(alpha: 0.65),
      );
      bubble.x = (_rng.nextDouble() - 0.5) * 20;
      bubble.y = (_rng.nextDouble() - 0.5) * 10;
      GTween.to(
        bubble,
        0.50 + _rng.nextDouble() * 0.30,
        {
          'x': bubble.x + (_rng.nextDouble() - 0.5) * 14,
          'y': bubble.y - 20 - _rng.nextDouble() * 18,
          'alpha': 0.0,
          'scale': 1.5,
        },
        GVars(
          ease: GEase.easeOut,
          delay: i * 0.04,
          onComplete: () => bubble.removeFromParent(true),
        ),
      );
    }

    _autoDispose(root, 0.78);
  }

  // ─── SPIRIT — Wraith Chorus ───────────────────────────────────────────────
  // Ghost wisps phase in then dissolve forward.
  void _castSpirit(
    double x,
    double y, {
    double? tx,
    double? ty,
    required bool echo,
  }) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int wisps = _count(6, 3, echo);
    const Color cBlue = Color(0xFF3F51B5);
    const Color cGhost = Color(0xFFBBDEFB);

    for (var i = 0; i < wisps; i++) {
      final a = i * (pi * 2 / wisps);
      final body = _circle(
        root,
        4.0 + _rng.nextDouble() * 2.0,
        cGhost.withValues(alpha: 0.0),
      );
      body.x = cos(a) * 12;
      body.y = sin(a) * 12;
      GTween.to(
        body,
        0.14,
        {'alpha': 0.72},
        GVars(
          ease: GEase.easeOut,
          delay: i * 0.05,
          onComplete: () {
            GTween.to(
              body,
              0.38,
              {
                'x': cos(a) * 28.0,
                'y': sin(a) * 28.0,
                'alpha': 0.0,
                'scale': 0.5,
              },
              GVars(
                ease: GEase.easeIn,
                onComplete: () => body.removeFromParent(true),
              ),
            );
          },
        ),
      );
    }

    final ring = _ring(
      root,
      echo ? 10.0 : 14.0,
      1.4,
      cBlue.withValues(alpha: 0.5),
    );
    GTween.to(
      ring,
      0.42,
      {'scaleX': 2.2, 'scaleY': 2.2, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => ring.removeFromParent(true)),
    );

    if (tx != null && ty != null) {
      _arcTrail(
        x,
        y,
        tx,
        ty,
        color: cGhost,
        accentColor: cBlue,
        lifetime: 0.35,
      );
    }

    _autoDispose(root, 0.60);
  }

  // ─── DARK — Eclipse Procession ────────────────────────────────────────────
  // Outer ring COLLAPSES inward; particles sucked to center.
  void _castDark(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int particles = echo ? 7 : 12;
    const Color cVoid = Color(0xFF4A148C);
    const Color cPurple = Color(0xFFB39DDB);

    final outerRing = _ring(
      root,
      echo ? 36.0 : 48.0,
      2.0,
      cPurple.withValues(alpha: 0.6),
    );
    GTween.to(
      outerRing,
      0.38,
      {'scaleX': 0.15, 'scaleY': 0.15, 'alpha': 0.0},
      GVars(
        ease: GEase.easeIn,
        onComplete: () => outerRing.removeFromParent(true),
      ),
    );

    final core = _circle(root, echo ? 6.0 : 9.0, cVoid.withValues(alpha: 0.9));
    GTween.to(
      core,
      0.22,
      {'scale': 1.8},
      GVars(
        ease: GEase.easeOut,
        onComplete: () {
          GTween.to(
            core,
            0.28,
            {'scale': 0.0, 'alpha': 0.0},
            GVars(
              ease: GEase.easeIn,
              onComplete: () => core.removeFromParent(true),
            ),
          );
        },
      ),
    );

    for (var i = 0; i < particles; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final r0 = 24 + _rng.nextDouble() * 20;
      final p = _circle(
        root,
        1.5 + _rng.nextDouble() * 1.5,
        i.isEven
            ? cPurple.withValues(alpha: 0.8)
            : cVoid.withValues(alpha: 0.7),
      );
      p.x = cos(a) * r0;
      p.y = sin(a) * r0;
      GTween.to(
        p,
        0.28 + _rng.nextDouble() * 0.18,
        {'x': 0.0, 'y': 0.0, 'alpha': 0.0, 'scale': 0.2},
        GVars(
          ease: GEase.easeIn,
          delay: i * 0.016,
          onComplete: () => p.removeFromParent(true),
        ),
      );
    }

    _autoDispose(root, 0.52);
  }

  // ─── LIGHT — Radiant Crown ────────────────────────────────────────────────
  // Star burst with evenly-spaced radial beams + gold halo.
  void _castLight(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int beams = _count(9, 5, echo);
    const Color cGold = Color(0xFFFFE082);
    const Color cWhite = Color(0xFFFFFFFF);

    final flash = _circle(
      root,
      echo ? 14.0 : 20.0,
      cWhite.withValues(alpha: 0.9),
    );
    GTween.to(
      flash,
      0.26,
      {'scale': 1.4, 'alpha': 0.0},
      GVars(
        ease: GEase.easeOut,
        onComplete: () => flash.removeFromParent(true),
      ),
    );

    for (var i = 0; i < beams; i++) {
      final a = i * (pi * 2 / beams);
      final len = 28 + _rng.nextDouble() * 18;
      final beam = _line(
        root,
        0,
        0,
        cos(a) * len,
        sin(a) * len,
        i.isEven ? 2.4 : 1.4,
        i % 3 == 0 ? cWhite : cGold.withValues(alpha: 0.9),
      );
      GTween.to(
        beam,
        0.30,
        {'alpha': 0.0, 'scaleX': 1.3},
        GVars(
          ease: GEase.easeOut,
          delay: 0.02,
          onComplete: () => beam.removeFromParent(true),
        ),
      );
    }

    final halo = _ring(
      root,
      echo ? 18.0 : 26.0,
      2.0,
      cGold.withValues(alpha: 0.75),
    );
    GTween.to(
      halo,
      0.40,
      {'scaleX': 2.0, 'scaleY': 2.0, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => halo.removeFromParent(true)),
    );

    final int sparks = _count(7, 4, echo);
    for (var i = 0; i < sparks; i++) {
      final a = i * (pi * 2 / sparks) + 0.25;
      final spark = _circle(
        root,
        1.8,
        i.isEven ? cGold : cWhite.withValues(alpha: 0.9),
      );
      GTween.to(
        spark,
        0.28,
        {'x': cos(a) * 34, 'y': sin(a) * 34, 'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          delay: 0.06 + i * 0.02,
          onComplete: () => spark.removeFromParent(true),
        ),
      );
    }

    _autoDispose(root, 0.46);
  }

  // ─── BLOOD — Crimson Coronation ───────────────────────────────────────────
  // Heartbeat double-pulse; drops spray outward then drip.
  void _castBlood(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int drops = _count(12, 7, echo);
    const Color cRed = Color(0xFFD32F2F);
    const Color cCrimson = Color(0xFFFF1744);
    const Color cPink = Color(0xFFFFCDD2);

    for (var p = 0; p < 2; p++) {
      final pulse = _ring(
        root,
        echo ? 10.0 : 14.0,
        p == 0 ? 2.4 : 3.2,
        p == 0 ? cRed.withValues(alpha: 0.9) : cCrimson.withValues(alpha: 0.75),
      );
      final targetScale = p == 0 ? 2.0 : 3.2;
      GTween.to(
        pulse,
        p == 0 ? 0.22 : 0.30,
        {'scaleX': targetScale, 'scaleY': targetScale, 'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          delay: p * 0.16,
          onComplete: () => pulse.removeFromParent(true),
        ),
      );
    }

    for (var i = 0; i < drops; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final drop = _circle(
        root,
        1.6 + _rng.nextDouble() * 2.4,
        i % 3 == 0
            ? cPink.withValues(alpha: 0.85)
            : cRed.withValues(alpha: 0.92),
      );
      final dist = 10 + _rng.nextDouble() * 20;
      final ox = cos(a) * dist;
      final oy = sin(a) * dist;
      GTween.to(
        drop,
        0.20,
        {'x': ox, 'y': oy - 4},
        GVars(
          ease: GEase.easeOut,
          onComplete: () {
            GTween.to(
              drop,
              0.30,
              {'y': drop.y + 18, 'alpha': 0.0, 'scaleX': 0.6, 'scaleY': 1.4},
              GVars(
                ease: GEase.easeIn,
                onComplete: () => drop.removeFromParent(true),
              ),
            );
          },
        ),
      );
    }

    final core = _circle(root, echo ? 8.0 : 11.0, cRed.withValues(alpha: 0.85));
    GTween.to(
      core,
      0.18,
      {'scale': 1.4, 'alpha': 0.0},
      GVars(ease: GEase.easeIn, onComplete: () => core.removeFromParent(true)),
    );

    _autoDispose(root, 0.62);
  }

  // ─── DEFAULT ──────────────────────────────────────────────────────────────
  void _castDefault(double x, double y, {required bool echo}) {
    final root = addChild(GSprite())
      ..x = x
      ..y = y;
    final int count = _count(12, 7, echo);
    const Color cBase = Color(0xFF7E57C2);
    const Color cAccent = Color(0xFFCE93D8);

    final ring = _ring(
      root,
      echo ? 12.0 : 16.0,
      2.0,
      cBase.withValues(alpha: 0.7),
    );
    GTween.to(
      ring,
      0.38,
      {'scaleX': 2.6, 'scaleY': 2.6, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => ring.removeFromParent(true)),
    );

    for (var i = 0; i < count; i++) {
      final a = i * (pi * 2 / count) + _rng.nextDouble() * 0.3;
      final p = _circle(
        root,
        1.6 + _rng.nextDouble() * 1.8,
        i.isEven ? cBase : cAccent,
      );
      final dist = 18 + _rng.nextDouble() * 20;
      GTween.to(
        p,
        0.30 + _rng.nextDouble() * 0.24,
        {'x': cos(a) * dist, 'y': sin(a) * dist, 'alpha': 0.0},
        GVars(ease: GEase.easeOut, onComplete: () => p.removeFromParent(true)),
      );
    }

    _autoDispose(root, 0.55);
  }

  // ─── ARC TRAIL ────────────────────────────────────────────────────────────
  void _arcTrail(
    double x1,
    double y1,
    double x2,
    double y2, {
    required Color color,
    required Color accentColor,
    required double lifetime,
    int segments = 8,
  }) {
    final trail = addChild(GSprite());
    final dx = x2 - x1;
    final dy = y2 - y1;
    final len = sqrt(dx * dx + dy * dy);
    if (len < 4) {
      trail.removeFromParent(true);
      return;
    }

    final rawCount = (len / 28).clamp(4, segments).round();
    final int count = max(
      2,
      (rawCount *
              switch (_qualityTier) {
                >= 3 => 1.0,
                2 => 0.72,
                1 => 0.50,
                _ => 0.25,
              })
          .round(),
    );
    for (var i = 0; i < count; i++) {
      final t = (i + 1) / (count + 1);
      final jx = (_rng.nextDouble() - 0.5) * 10;
      final jy = (_rng.nextDouble() - 0.5) * 10;
      final dot = trail.addChild(GShape());
      dot.graphics
        ..beginFill(i.isEven ? color : accentColor)
        ..drawCircle(0, 0, 1.4 + _rng.nextDouble() * 1.2)
        ..endFill();
      dot.x = x1 + dx * t + jx;
      dot.y = y1 + dy * t + jy;
      dot.alpha = 0.8;
    }

    GTween.to(
      trail,
      lifetime,
      {'alpha': 0.0},
      GVars(ease: GEase.easeIn, onComplete: () => trail.removeFromParent(true)),
    );
  }
}

class _MysticPalette {
  final Color primary;
  final Color accent;
  final Color shadow;

  const _MysticPalette(this.primary, this.accent, this.shadow);
}
