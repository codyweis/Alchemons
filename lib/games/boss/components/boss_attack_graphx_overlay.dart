import 'dart:math';

import 'package:flutter/material.dart';
import 'package:graphx/graphx.dart';

class BossAttackGraphxEvent {
  final String element;
  final Offset origin;
  final Offset target;
  final bool isCritical;
  final int damage;

  const BossAttackGraphxEvent({
    required this.element,
    required this.origin,
    required this.target,
    required this.isCritical,
    required this.damage,
  });
}

class BossAttackGraphxOverlayController {
  _BossAttackGraphxScene? _scene;

  void _attach(_BossAttackGraphxScene scene) {
    _scene = scene;
  }

  void _detach(_BossAttackGraphxScene scene) {
    if (identical(_scene, scene)) {
      _scene = null;
    }
  }

  void spawn(BossAttackGraphxEvent event) {
    _scene?.spawn(event);
  }

  void clear() {
    _scene?.clearEffects();
  }

  void dispose() {
    _scene = null;
  }
}

class BossAttackGraphxOverlay extends StatefulWidget {
  final BossAttackGraphxOverlayController controller;

  const BossAttackGraphxOverlay({super.key, required this.controller});

  @override
  State<BossAttackGraphxOverlay> createState() =>
      _BossAttackGraphxOverlayState();
}

class _BossAttackGraphxOverlayState extends State<BossAttackGraphxOverlay> {
  late final _BossAttackGraphxScene _scene;

  @override
  void initState() {
    super.initState();
    _scene = _BossAttackGraphxScene();
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

class _BossAttackGraphxScene extends GSprite {
  static const int _maxEffects = 40;
  final Random _rng = Random();

  void clearEffects() {
    removeChildren(0, -1, true);
  }

  void spawn(BossAttackGraphxEvent e) {
    while (numChildren > _maxEffects) {
      removeChildAt(0, true);
    }

    final palette = _paletteFor(e.element);
    final ox = e.origin.dx;
    final oy = e.origin.dy;
    final tx = e.target.dx;
    final ty = e.target.dy;

    switch (e.element) {
      case 'Dark':
        _castDarkAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Water':
        _castWaterAttack(
          ox,
          oy,
          tx,
          ty,
          palette,
          critical: e.isCritical,
          power: e.damage,
        );
      case 'Earth':
        _castEarthAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Air':
        _castAirAttack(
          ox,
          oy,
          tx,
          ty,
          palette,
          critical: e.isCritical,
          power: e.damage,
        );
      case 'Plant':
        _castPlantAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Ice':
        _castIceAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Lightning':
        _castLightningAttack(
          ox,
          oy,
          tx,
          ty,
          palette,
          critical: e.isCritical,
          power: e.damage,
        );
      case 'Poison':
        _castPoisonAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Steam':
        _castSteamAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Lava':
        _castLavaAttack(
          ox,
          oy,
          tx,
          ty,
          palette,
          critical: e.isCritical,
          power: e.damage,
        );
      case 'Mud':
        _castMudAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Dust':
        _castDustAttack(
          ox,
          oy,
          tx,
          ty,
          palette,
          critical: e.isCritical,
          power: e.damage,
        );
      case 'Blood':
        _castBloodAttack(
          ox,
          oy,
          tx,
          ty,
          palette,
          critical: e.isCritical,
          power: e.damage,
        );
      case 'Spirit':
        _castSpiritAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Crystal':
        _castCrystalAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Light':
        _castLightAttack(ox, oy, tx, ty, palette, critical: e.isCritical);
      case 'Fire':
        _castFireAttack(
          ox,
          oy,
          tx,
          ty,
          palette,
          critical: e.isCritical,
          power: e.damage,
        );
    }
  }

  void _castWaterAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
    required int power,
  }) {
    _castShockPulse(ox, oy, p, critical: critical);
    _castTravelBeam(ox, oy, tx, ty, p, power: power);
    final drops = critical ? 14 : 10;
    for (var i = 0; i < drops; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final radius = (critical ? 40 : 28) + _rng.nextDouble() * 20;
      final drop = addChild(GShape())..setPosition(tx, ty);
      drop.graphics
        ..beginFill(p.secondary.withValues(alpha: 0.86))
        ..drawCircle(0, 0, 1.6 + _rng.nextDouble() * 2.2)
        ..endFill();
      GTween.to(
        drop,
        0.28 + _rng.nextDouble() * 0.14,
        {
          'x': tx + cos(angle) * radius,
          'y': ty + sin(angle) * radius,
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => drop.removeFromParent(true),
        ),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castEarthAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 18 : 12);
    final chunks = critical ? 9 : 6;
    for (var i = 0; i < chunks; i++) {
      final angle = pi + (_rng.nextDouble() - 0.5) * 1.25;
      final chunk = addChild(GShape())..setPosition(tx, ty);
      final w = 5 + _rng.nextDouble() * 6;
      final h = 5 + _rng.nextDouble() * 8;
      chunk.graphics
        ..beginFill((i.isEven ? p.primary : p.accent).withValues(alpha: 0.9))
        ..drawRect(-w / 2, -h / 2, w, h)
        ..endFill();
      GTween.to(
        chunk,
        0.32 + _rng.nextDouble() * 0.14,
        {
          'x': tx + cos(angle) * (26 + _rng.nextDouble() * 36),
          'y': ty + sin(angle) * (14 + _rng.nextDouble() * 18),
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => chunk.removeFromParent(true),
        ),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castAirAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
    required int power,
  }) {
    // Blade fan at target: radial rects bursting outward
    final blades = critical ? 9 : 6;
    for (var i = 0; i < blades; i++) {
      final angle = (pi * 2 * i) / blades + (_rng.nextDouble() - 0.5) * 0.3;
      final blade = addChild(GShape())..setPosition(tx, ty)..rotation = angle;
      final len = (critical ? 20.0 : 14.0) + _rng.nextDouble() * 8;
      blade.graphics
        ..beginFill(p.secondary.withValues(alpha: 0.88))
        ..drawRect(-1.4, -len, 2.8, len)
        ..endFill();
      GTween.to(
        blade,
        0.28 + _rng.nextDouble() * 0.10,
        {
          'x': tx + cos(angle) * (critical ? 50 : 38),
          'y': ty + sin(angle) * (critical ? 50 : 38),
          'alpha': 0.0,
        },
        GVars(ease: GEase.easeOut, onComplete: () => blade.removeFromParent(true)),
      );
    }
    // Wind vortex ring expanding at target
    final vring = addChild(GShape())..setPosition(tx, ty);
    vring.graphics
      ..lineStyle(critical ? 2.6 : 1.8, p.primary.withValues(alpha: 0.72))
      ..drawCircle(0, 0, critical ? 14 : 10)
      ..endFill();
    GTween.to(
      vring,
      0.34,
      {'scaleX': critical ? 3.8 : 3.2, 'scaleY': critical ? 3.8 : 3.2, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => vring.removeFromParent(true)),
    );
    _castTravelBeam(ox, oy, tx, ty, p, power: power);
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castPlantAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 16 : 10);
    // Root spikes growing from impact point
    final spikes = critical ? 10 : 7;
    for (var i = 0; i < spikes; i++) {
      final angle = (pi * 2 * i) / spikes + (_rng.nextDouble() - 0.5) * 0.4;
      final len = (critical ? 28.0 : 20.0) + _rng.nextDouble() * 14;
      final spike = addChild(GShape())..setPosition(tx, ty)..rotation = angle;
      spike.graphics
        ..beginFill(p.primary.withValues(alpha: 0.92))
        ..drawRect(-1.8, -len, 3.6, len)
        ..endFill();
      GTween.to(
        spike,
        0.28 + _rng.nextDouble() * 0.12,
        {
          'x': tx + cos(angle) * len * 0.65,
          'y': ty + sin(angle) * len * 0.65,
          'alpha': 0.0,
        },
        GVars(ease: GEase.easeOut, onComplete: () => spike.removeFromParent(true)),
      );
    }
    // Pollen burst: orbs scattering outward
    final pollen = critical ? 11 : 7;
    for (var i = 0; i < pollen; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final dist = (critical ? 34.0 : 24.0) + _rng.nextDouble() * 20;
      final dot = addChild(GShape())..setPosition(tx, ty);
      dot.graphics
        ..beginFill(p.secondary.withValues(alpha: 0.84))
        ..drawCircle(0, 0, 2.4 + _rng.nextDouble() * 2.0)
        ..endFill();
      GTween.to(
        dot,
        0.32 + _rng.nextDouble() * 0.14,
        {'x': tx + cos(angle) * dist, 'y': ty + sin(angle) * dist, 'alpha': 0.0},
        GVars(ease: GEase.easeOut, onComplete: () => dot.removeFromParent(true)),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castIceAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 20 : 12);
    final spears = critical ? 8 : 6;
    for (var i = 0; i < spears; i++) {
      final spear = addChild(GShape())
        ..setPosition(
          tx + (i - (spears - 1) / 2) * 10,
          ty - 86 - _rng.nextDouble() * 36,
        )
        ..rotation = pi;
      spear.graphics
        ..beginFill(p.secondary.withValues(alpha: 0.9))
        ..drawRect(-1.6, -10, 3.2, 20)
        ..endFill();
      GTween.to(
        spear,
        0.24 + _rng.nextDouble() * 0.1,
        {'y': ty + _rng.nextDouble() * 8, 'alpha': 0.0},
        GVars(
          ease: GEase.easeIn,
          onComplete: () => spear.removeFromParent(true),
        ),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castLightningAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
    required int power,
  }) {
    final bolts = critical ? 3 : 2;
    for (var i = 0; i < bolts; i++) {
      final jitter = (i - (bolts - 1) / 2) * (critical ? 18.0 : 12.0);
      final s1x = ox + (tx - ox) * 0.32 + jitter + (_rng.nextDouble() - 0.5) * 22;
      final s1y = oy + (ty - oy) * 0.32 + (_rng.nextDouble() - 0.5) * 30;
      final s2x = ox + (tx - ox) * 0.68 + jitter + (_rng.nextDouble() - 0.5) * 22;
      final s2y = oy + (ty - oy) * 0.68 + (_rng.nextDouble() - 0.5) * 30;
      // Outer glow bolt
      final bGlow = addChild(GShape());
      bGlow.graphics
        ..lineStyle(critical ? 8.0 : 6.0, p.secondary.withValues(alpha: 0.22))
        ..moveTo(ox, oy)
        ..lineTo(s1x, s1y)
        ..lineTo(s2x, s2y)
        ..lineTo(tx, ty)
        ..endFill();
      GTween.to(
        bGlow, 0.15, {'alpha': 0.0},
        GVars(ease: GEase.easeOut, onComplete: () => bGlow.removeFromParent(true)),
      );
      // Main bolt
      final bolt = addChild(GShape());
      bolt.graphics
        ..lineStyle(critical ? 3.0 : 2.4, p.primary.withValues(alpha: 0.95))
        ..moveTo(ox, oy)
        ..lineTo(s1x, s1y)
        ..lineTo(s2x, s2y)
        ..lineTo(tx, ty)
        ..endFill();
      GTween.to(
        bolt, 0.17, {'alpha': 0.0},
        GVars(ease: GEase.easeOut, onComplete: () => bolt.removeFromParent(true)),
      );
      // Bright white core
      final bCore = addChild(GShape());
      bCore.graphics
        ..lineStyle(critical ? 1.4 : 1.0, const Color(0xFFFFFFFF).withValues(alpha: 0.82))
        ..moveTo(ox, oy)
        ..lineTo(s1x, s1y)
        ..lineTo(s2x, s2y)
        ..lineTo(tx, ty)
        ..endFill();
      GTween.to(
        bCore, 0.11, {'alpha': 0.0},
        GVars(ease: GEase.easeOut, onComplete: () => bCore.removeFromParent(true)),
      );
    }
    _castTravelBeam(ox, oy, tx, ty, p, power: power + 6);
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castPoisonAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 16 : 10);
    final globules = critical ? 13 : 9;
    for (var i = 0; i < globules; i++) {
      final cloud = addChild(GShape())
        ..setPosition(
          tx + (_rng.nextDouble() - 0.5) * 52,
          ty + (_rng.nextDouble() - 0.5) * 28,
        );
      cloud.graphics
        ..beginFill(
          (i.isEven ? p.primary : p.secondary).withValues(alpha: 0.75),
        )
        ..drawCircle(0, 0, 4 + _rng.nextDouble() * 5)
        ..endFill();
      GTween.to(
        cloud,
        0.5 + _rng.nextDouble() * 0.2,
        {'y': cloud.y - (12 + _rng.nextDouble() * 18), 'alpha': 0.0},
        GVars(
          ease: GEase.easeOut,
          onComplete: () => cloud.removeFromParent(true),
        ),
      );
    }
  }

  void _castSteamAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 18 : 12);
    final puffs = critical ? 16 : 12;
    for (var i = 0; i < puffs; i++) {
      final puff = addChild(GShape())
        ..setPosition(
          tx + (_rng.nextDouble() - 0.5) * 44,
          ty + (_rng.nextDouble() - 0.5) * 24,
        );
      puff.graphics
        ..beginFill(p.secondary.withValues(alpha: 0.52))
        ..drawCircle(0, 0, 3.2 + _rng.nextDouble() * 4.2)
        ..endFill();
      GTween.to(
        puff,
        0.42 + _rng.nextDouble() * 0.2,
        {
          'x': puff.x + (_rng.nextDouble() - 0.5) * 22,
          'y': puff.y - (18 + _rng.nextDouble() * 24),
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => puff.removeFromParent(true),
        ),
      );
    }
  }

  void _castLavaAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
    required int power,
  }) {
    _castShockPulse(ox, oy, p, critical: critical);
    _castTravelBeam(ox, oy, tx, ty, p, power: power + (critical ? 6 : 0));
    final globs = critical ? 12 : 8;
    for (var i = 0; i < globs; i++) {
      final glob = addChild(GShape())..setPosition(tx, ty);
      glob.graphics
        ..beginFill((i.isEven ? p.accent : p.primary).withValues(alpha: 0.88))
        ..drawCircle(0, 0, 2.4 + _rng.nextDouble() * 3.0)
        ..endFill();
      final angle = (_rng.nextDouble() - 0.5) * pi;
      GTween.to(
        glob,
        0.26 + _rng.nextDouble() * 0.16,
        {
          'x': tx + cos(angle) * (18 + _rng.nextDouble() * 26),
          'y': ty - sin(angle) * (8 + _rng.nextDouble() * 14),
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => glob.removeFromParent(true),
        ),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castMudAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 15 : 9);
    final clumps = critical ? 10 : 7;
    for (var i = 0; i < clumps; i++) {
      final clump = addChild(GShape())
        ..setPosition(
          tx + (_rng.nextDouble() - 0.5) * 34,
          ty - (20 + _rng.nextDouble() * 30),
        );
      final size = 3.5 + _rng.nextDouble() * 4.5;
      clump.graphics
        ..beginFill(p.primary.withValues(alpha: 0.86))
        ..drawCircle(0, 0, size)
        ..endFill();
      GTween.to(
        clump,
        0.24 + _rng.nextDouble() * 0.16,
        {'y': ty + 6 + _rng.nextDouble() * 16, 'alpha': 0.0},
        GVars(
          ease: GEase.easeIn,
          onComplete: () => clump.removeFromParent(true),
        ),
      );
    }
  }

  void _castDustAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
    required int power,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: power);
    final particles = critical ? 22 : 14;
    for (var i = 0; i < particles; i++) {
      final dust = addChild(GShape())..setPosition(tx, ty);
      dust.graphics
        ..beginFill(
          (i.isEven ? p.secondary : p.primary).withValues(alpha: 0.68),
        )
        ..drawCircle(0, 0, 1.2 + _rng.nextDouble() * 2.0)
        ..endFill();
      final dir = (_rng.nextDouble() - 0.5) * (critical ? 1.4 : 1.0);
      GTween.to(
        dust,
        0.36 + _rng.nextDouble() * 0.16,
        {
          'x': tx + cos(dir) * (26 + _rng.nextDouble() * 52),
          'y': ty + sin(dir) * (8 + _rng.nextDouble() * 20),
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => dust.removeFromParent(true),
        ),
      );
    }
  }

  void _castSpiritAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castShockPulse(ox, oy, p, critical: critical);
    final wisps = critical ? 8 : 5;
    for (var i = 0; i < wisps; i++) {
      final angle = (pi * 2 * i) / wisps;
      final wisp = addChild(GShape())
        ..setPosition(ox + cos(angle) * 18, oy + sin(angle) * 18);
      wisp.graphics
        ..beginFill(p.secondary.withValues(alpha: 0.82))
        ..drawCircle(0, 0, 2.2 + _rng.nextDouble() * 1.8)
        ..endFill();
      GTween.to(
        wisp,
        0.34 + _rng.nextDouble() * 0.12,
        {
          'x': tx + (_rng.nextDouble() - 0.5) * 18,
          'y': ty + (_rng.nextDouble() - 0.5) * 18,
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => wisp.removeFromParent(true),
        ),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castDarkAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    final eclipse = addChild(GShape())..setPosition(tx, ty);
    eclipse.graphics
      ..lineStyle(critical ? 4.0 : 3.0, p.primary.withValues(alpha: 0.9))
      ..drawCircle(0, 0, critical ? 24 : 18)
      ..endFill();
    GTween.to(
      eclipse,
      0.36,
      {
        'scaleX': critical ? 2.6 : 2.2,
        'scaleY': critical ? 2.6 : 2.2,
        'alpha': 0.0,
      },
      GVars(
        ease: GEase.easeOut,
        onComplete: () => eclipse.removeFromParent(true),
      ),
    );

    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 20 : 12);
    final shardCount = critical ? 10 : 7;
    for (var i = 0; i < shardCount; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final distance = 28 + _rng.nextDouble() * 38;
      final shard = addChild(GShape())
        ..setPosition(tx + cos(angle) * 8, ty + sin(angle) * 8)
        ..rotation = angle;
      shard.graphics
        ..beginFill(p.accent.withValues(alpha: 0.92))
        ..drawRect(-2.5, -7, 5, 14)
        ..endFill();
      GTween.to(
        shard,
        0.34 + _rng.nextDouble() * 0.16,
        {
          'x': tx + cos(angle) * distance,
          'y': ty + sin(angle) * distance,
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => shard.removeFromParent(true),
        ),
      );
    }
  }

  void _castBloodAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
    required int power,
  }) {
    _castShockPulse(ox, oy, p, critical: critical);
    // Blood orb stream: orbs arc from origin to target
    final streamCount = critical ? 5 : 3;
    for (var i = 0; i < streamCount; i++) {
      final wobble = (i - (streamCount - 1) / 2.0) * (critical ? 15.0 : 10.0);
      final orbR = (critical ? 5.5 : 4.2) - i * 0.3;
      final orb = addChild(GShape())..setPosition(ox + wobble * 0.3, oy);
      orb.graphics
        ..beginFill(p.primary.withValues(alpha: 0.92))
        ..drawCircle(0, 0, orbR)
        ..endFill();
      // Outer glow
      final orbGlow = addChild(GShape())..setPosition(ox + wobble * 0.3, oy);
      orbGlow.graphics
        ..beginFill(p.secondary.withValues(alpha: 0.30))
        ..drawCircle(0, 0, orbR * 2.0)
        ..endFill();
      GTween.to(
        orb,
        0.22 + i * 0.03,
        {'x': tx + wobble, 'y': ty, 'alpha': 0.0},
        GVars(ease: GEase.easeIn, onComplete: () => orb.removeFromParent(true)),
      );
      GTween.to(
        orbGlow,
        0.22 + i * 0.03,
        {'x': tx + wobble, 'y': ty, 'alpha': 0.0},
        GVars(ease: GEase.easeIn, onComplete: () => orbGlow.removeFromParent(true)),
      );
    }

    final droplets = max(7, min(18, (power / 7).round()));
    for (var i = 0; i < droplets; i++) {
      final t = _rng.nextDouble();
      final px = ox + (tx - ox) * t + (_rng.nextDouble() - 0.5) * 16;
      final py = oy + (ty - oy) * t + (_rng.nextDouble() - 0.5) * 10;
      final drop = addChild(GShape())..setPosition(px, py);
      drop.graphics
        ..beginFill(p.accent.withValues(alpha: 0.9))
        ..drawCircle(0, 0, 2.0 + _rng.nextDouble() * 2.0)
        ..endFill();
      GTween.to(
        drop,
        0.22 + _rng.nextDouble() * 0.16,
        {'y': py + 18 + _rng.nextDouble() * 18, 'alpha': 0.0},
        GVars(
          ease: GEase.easeIn,
          onComplete: () => drop.removeFromParent(true),
        ),
      );
    }

    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castCrystalAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castTravelBeam(ox, oy, tx, ty, p, power: critical ? 24 : 14);
    final facets = critical ? 8 : 6;
    for (var i = 0; i < facets; i++) {
      final angle = (pi * 2 * i) / facets;
      final shard = addChild(GShape())
        ..setPosition(tx, ty)
        ..rotation = angle;
      shard.graphics
        ..beginFill(
          (i.isEven ? p.primary : p.secondary).withValues(alpha: 0.88),
        )
        ..drawRect(-2.0, -11, 4.0, 22)
        ..endFill();
      GTween.to(
        shard,
        0.34,
        {
          'x': tx + cos(angle) * (critical ? 64 : 48),
          'y': ty + sin(angle) * (critical ? 64 : 48),
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => shard.removeFromParent(true),
        ),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castLightAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
  }) {
    _castShockPulse(ox, oy, p, critical: critical);
    // Lens flare expanding ring at impact
    final flare = addChild(GShape())..setPosition(tx, ty);
    flare.graphics
      ..lineStyle(critical ? 3.0 : 2.2, p.secondary.withValues(alpha: 0.90))
      ..drawCircle(0, 0, critical ? 16 : 12)
      ..endFill();
    GTween.to(
      flare,
      0.32,
      {'scaleX': critical ? 3.8 : 3.2, 'scaleY': critical ? 3.8 : 3.2, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => flare.removeFromParent(true)),
    );
    // Streak particles descending into target
    final streaks = critical ? 8 : 5;
    for (var i = 0; i < streaks; i++) {
      final spreadX = (i - (streaks - 1) / 2.0) * (critical ? 18.0 : 14.0);
      final startY = ty - (80 + _rng.nextDouble() * 60);
      final streak = addChild(GShape())..setPosition(tx + spreadX, startY);
      streak.graphics
        ..beginFill(p.primary.withValues(alpha: 0.92))
        ..drawRect(-1.8, 0, 3.6, critical ? 16 : 11)
        ..endFill();
      GTween.to(
        streak,
        0.20 + _rng.nextDouble() * 0.08,
        {'y': ty, 'alpha': 0.0},
        GVars(ease: GEase.easeIn, onComplete: () => streak.removeFromParent(true)),
      );
    }
    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castFireAttack(
    double ox,
    double oy,
    double tx,
    double ty,
    _BossPalette p, {
    required bool critical,
    required int power,
  }) {
    _castShockPulse(ox, oy, p, critical: critical);
    _castTravelBeam(ox, oy, tx, ty, p, power: power + (critical ? 8 : 0));

    final embers = max(8, min(20, (power / 6).round()));
    for (var i = 0; i < embers; i++) {
      final t = _rng.nextDouble();
      final px = ox + (tx - ox) * t + (_rng.nextDouble() - 0.5) * 20;
      final py = oy + (ty - oy) * t + (_rng.nextDouble() - 0.5) * 20;
      final ember = addChild(GShape())..setPosition(px, py);
      ember.graphics
        ..beginFill((i.isEven ? p.primary : p.accent).withValues(alpha: 0.9))
        ..drawCircle(0, 0, 1.8 + _rng.nextDouble() * 2.2)
        ..endFill();
      GTween.to(
        ember,
        0.24 + _rng.nextDouble() * 0.18,
        {
          'x': px + (_rng.nextDouble() - 0.5) * 20,
          'y': py - (16 + _rng.nextDouble() * 28),
          'alpha': 0.0,
        },
        GVars(
          ease: GEase.easeOut,
          onComplete: () => ember.removeFromParent(true),
        ),
      );
    }

    _castImpactBurst(tx, ty, p, critical: critical);
  }

  void _castShockPulse(
    double x,
    double y,
    _BossPalette p, {
    required bool critical,
  }) {
    // Outer soft halo ring
    final outer = addChild(GShape())..setPosition(x, y);
    outer.graphics
      ..lineStyle(critical ? 2.0 : 1.6, p.secondary.withValues(alpha: 0.42))
      ..drawCircle(0, 0, critical ? 28 : 20)
      ..endFill();
    GTween.to(
      outer,
      critical ? 0.52 : 0.42,
      {'scaleX': critical ? 4.8 : 4.0, 'scaleY': critical ? 4.8 : 4.0, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => outer.removeFromParent(true)),
    );
    // Inner bright ring
    final ring = addChild(GShape())..setPosition(x, y);
    ring.graphics
      ..lineStyle(critical ? 3.6 : 2.6, p.primary.withValues(alpha: 0.90))
      ..drawCircle(0, 0, critical ? 22 : 16)
      ..endFill();
    GTween.to(
      ring,
      critical ? 0.34 : 0.28,
      {'scaleX': critical ? 3.9 : 3.1, 'scaleY': critical ? 3.9 : 3.1, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => ring.removeFromParent(true)),
    );
    // Core flash dot
    final dot = addChild(GShape())..setPosition(x, y);
    dot.graphics
      ..beginFill(p.accent.withValues(alpha: 0.92))
      ..drawCircle(0, 0, critical ? 9 : 6)
      ..endFill();
    GTween.to(
      dot,
      0.15,
      {'scaleX': 2.6, 'scaleY': 2.6, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => dot.removeFromParent(true)),
    );
  }

  void _castTravelBeam(
    double x1,
    double y1,
    double x2,
    double y2,
    _BossPalette p, {
    required int power,
  }) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = sqrt(dx * dx + dy * dy).clamp(1.0, 1e9);
    final travelTime = (0.16 + dist / 1100).clamp(0.13, 0.30);
    final headR = 5.0 + (power / 22).clamp(0.0, 5.5);

    // Outer glow halo that travels with the projectile
    final halo = addChild(GShape())..setPosition(x1, y1);
    halo.graphics
      ..beginFill(p.secondary.withValues(alpha: 0.28))
      ..drawCircle(0, 0, headR * 2.4)
      ..endFill();
    GTween.to(
      halo,
      travelTime,
      {'x': x2, 'y': y2, 'alpha': 0.0},
      GVars(ease: GEase.linear, onComplete: () => halo.removeFromParent(true)),
    );

    // Bright core projectile
    final head = addChild(GShape())..setPosition(x1, y1);
    head.graphics
      ..beginFill(p.accent.withValues(alpha: 0.96))
      ..drawCircle(0, 0, headR)
      ..endFill();
    GTween.to(
      head,
      travelTime,
      {'x': x2, 'y': y2},
      GVars(ease: GEase.easeIn, onComplete: () => head.removeFromParent(true)),
    );

    // Trail afterimage blobs placed along path — fade over varying durations
    final trailCount = max(4, min(10, (power / 9).round()));
    for (var i = 0; i < trailCount; i++) {
      final t = (i + 1) / (trailCount + 1);
      final px = x1 + dx * t;
      final py = y1 + dy * t;
      final r = headR * (0.85 - t * 0.48);
      final trail = addChild(GShape())..setPosition(px, py);
      trail.graphics
        ..beginFill(p.primary.withValues(alpha: 0.70))
        ..drawCircle(0, 0, r)
        ..endFill();
      final fadeDur = travelTime * (1.0 - t * 0.5) + 0.08;
      GTween.to(
        trail,
        fadeDur,
        {'alpha': 0.0},
        GVars(ease: GEase.easeOut, onComplete: () => trail.removeFromParent(true)),
      );
    }
  }

  void _castImpactBurst(
    double x,
    double y,
    _BossPalette p, {
    required bool critical,
  }) {
    // Fast bright ring
    final ring1 = addChild(GShape())..setPosition(x, y);
    ring1.graphics
      ..lineStyle(critical ? 3.2 : 2.4, p.accent.withValues(alpha: 0.96))
      ..drawCircle(0, 0, critical ? 10 : 7)
      ..endFill();
    GTween.to(
      ring1,
      critical ? 0.26 : 0.20,
      {'scaleX': critical ? 5.0 : 4.2, 'scaleY': critical ? 5.0 : 4.2, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => ring1.removeFromParent(true)),
    );
    // Slower soft outer ring
    final ring2 = addChild(GShape())..setPosition(x, y);
    ring2.graphics
      ..lineStyle(critical ? 1.8 : 1.4, p.secondary.withValues(alpha: 0.50))
      ..drawCircle(0, 0, critical ? 5 : 4)
      ..endFill();
    GTween.to(
      ring2,
      critical ? 0.48 : 0.38,
      {'scaleX': critical ? 8.5 : 7.0, 'scaleY': critical ? 8.5 : 7.0, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => ring2.removeFromParent(true)),
    );
    // Core flash
    final core = addChild(GShape())..setPosition(x, y);
    core.graphics
      ..beginFill(p.primary.withValues(alpha: critical ? 0.95 : 0.85))
      ..drawCircle(0, 0, critical ? 14 : 10)
      ..endFill();
    GTween.to(
      core,
      critical ? 0.20 : 0.16,
      {'scaleX': critical ? 1.9 : 1.7, 'scaleY': critical ? 1.9 : 1.7, 'alpha': 0.0},
      GVars(ease: GEase.easeOut, onComplete: () => core.removeFromParent(true)),
    );
  }

  _BossPalette _paletteFor(String element) {
    switch (element) {
      case 'Fire':
        return const _BossPalette(
          Color(0xFFFF7043),
          Color(0xFFFFAB91),
          Color(0xFFFF3D00),
        );
      case 'Water':
        return const _BossPalette(
          Color(0xFF42A5F5),
          Color(0xFF80D8FF),
          Color(0xFF2962FF),
        );
      case 'Earth':
        return const _BossPalette(
          Color(0xFF8D6E63),
          Color(0xFFBCAAA4),
          Color(0xFF4E342E),
        );
      case 'Air':
        return const _BossPalette(
          Color(0xFF90CAF9),
          Color(0xFFE1F5FE),
          Color(0xFF4FC3F7),
        );
      case 'Plant':
        return const _BossPalette(
          Color(0xFF66BB6A),
          Color(0xFFA5D6A7),
          Color(0xFF2E7D32),
        );
      case 'Ice':
        return const _BossPalette(
          Color(0xFF80DEEA),
          Color(0xFFE0F7FA),
          Color(0xFF26C6DA),
        );
      case 'Lightning':
        return const _BossPalette(
          Color(0xFFFFEB3B),
          Color(0xFFFFFF8D),
          Color(0xFF40C4FF),
        );
      case 'Poison':
        return const _BossPalette(
          Color(0xFFAB47BC),
          Color(0xFFCE93D8),
          Color(0xFF6A1B9A),
        );
      case 'Steam':
        return const _BossPalette(
          Color(0xFFB0BEC5),
          Color(0xFFECEFF1),
          Color(0xFF78909C),
        );
      case 'Lava':
        return const _BossPalette(
          Color(0xFFFF7043),
          Color(0xFFFFAB91),
          Color(0xFFD84315),
        );
      case 'Mud':
        return const _BossPalette(
          Color(0xFF8D6E63),
          Color(0xFFA1887F),
          Color(0xFF4E342E),
        );
      case 'Dust':
        return const _BossPalette(
          Color(0xFFD7CCC8),
          Color(0xFFEFEBE9),
          Color(0xFFA1887F),
        );
      case 'Crystal':
        return const _BossPalette(
          Color(0xFF7C4DFF),
          Color(0xFFB388FF),
          Color(0xFF00BFA5),
        );
      case 'Spirit':
        return const _BossPalette(
          Color(0xFFB39DDB),
          Color(0xFFE1BEE7),
          Color(0xFF7E57C2),
        );
      case 'Dark':
        return const _BossPalette(
          Color(0xFF7E57C2),
          Color(0xFFB39DDB),
          Color(0xFF311B92),
        );
      case 'Light':
        return const _BossPalette(
          Color(0xFFFFF176),
          Color(0xFFFFFFCC),
          Color(0xFFFFD54F),
        );
      case 'Blood':
        return const _BossPalette(
          Color(0xFFEF5350),
          Color(0xFFFFCDD2),
          Color(0xFFB71C1C),
        );
      default:
        return const _BossPalette(
          Color(0xFF90A4AE),
          Color(0xFFECEFF1),
          Color(0xFF607D8B),
        );
    }
  }
}

class _BossPalette {
  final Color primary;
  final Color secondary;
  final Color accent;

  const _BossPalette(this.primary, this.secondary, this.accent);
}
