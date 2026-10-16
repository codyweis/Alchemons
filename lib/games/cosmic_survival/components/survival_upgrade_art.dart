// lib/games/cosmic_survival/components/survival_upgrade_art.dart
//
// Each survival upgrade drawn as grains in its own light, in the game's
// grain-glass language (grain_glass.dart): points in batches and radial
// pools, no strokes, no blur. One formation per kind of thing an upgrade
// does — a heap for Strength, streaks for Speed, a turning lattice for
// Intelligence, a bloom for Beauty, a fan for Spread Shot, a comet for the
// rockets, a shell for the pulse, grains rising for healing, a burst for the
// nova, a chain for Chain Lightning, violet grains drawn in to one point for
// the Surge Magnet, the ship's loop out through violet grains and home for
// Autopilot, two ember currents braided into one surge for Warpath —
// so three cards never look alike. Keyed by id.
//
// A SURGE FUSION is drawn as its two parents' formations made one, in both
// parents' lights: the spread's streams turning onto their marks (Homing
// Spread), rockets coming down the comet's path at the gun's pace (Rapid
// Rockets), the overdrive's streaks poured into the missile's tail (Heavy
// Missiles), the ship's and the orb's turret shots meeting on one body
// (Linked Turrets), the pulse's shell breathing out the nova's grains (Nova
// Pulse), and the regeneration's and the tempering's grains rising as one
// braid (Tempered Field).
//
// Live on the draft cards through GrainGlyph (one shared clock for all of
// them); still in the TAKEN strip (painted once). A card's art is about
// 60–250 points in at most ten batched draws plus a few cached radial
// gradients a frame, only while the draft is open and the run is paused.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart' show elementColor;
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum UpgradeMotif {
  heap,
  streak,
  lattice,
  bloom,
  bolts,
  fan,
  comet,
  core,
  shell,
  rise,
  burst,
  orbit,
  chain,
  twin,
  gather,
  drip,
  hourglass,
  spiral,
  braid,
  world,
  magnet,
  sweep,
  // Surge fusions.
  seekingFan,
  rocketTrain,
  heavyComet,
  linkedBolts,
  pulseNova,
  risingBraid,
}

class UpgradeArtSpec {
  const UpgradeArtSpec(
    this.motif,
    this.color, {
    this.team = false,
    this.second,
    this.salt = 0,
  });

  final UpgradeMotif motif;
  final Color color;

  /// A team-wide pick: the formation three times over, smaller.
  final bool team;

  /// A second color, where the formation has two (Double Cast's echo).
  final Color? second;
  final int salt;
}

// The stats' own lights.
const _strength = Color(0xFFE07A48);
const _intelligence = Color(0xFF6FA2E8);
const _beauty = Color(0xFFE48AC0);
const _speed = Color(0xFF62D2B6);
const _shot = Color(0xFFF09A5A);
const _steel = Color(0xFF8FC9D6);
const _orb = Color(0xFFE8C77A);
const _ward = Color(0xFF86B6F0);
const _heal = Color(0xFF7FD6A0);
const _blood = Color(0xFFD9485A);
const _volt = Color(0xFFB9A8FF);
const _brass = Color(0xFFCDB07A);
// The surge's violet (SurvivalInk.surge), the grains Autopilot fetches.
const _surge = Color(0xFF9A7CEB);
// The ship's embers in Warpath's braid, a gold beside Strength's red.
const _ember = Color(0xFFF2B25C);

UpgradeArtSpec upgradeArtFor(PowerUpDef def) {
  final world = def.mysticElement;
  if (world != null) {
    return UpgradeArtSpec(UpgradeMotif.world, elementColor(world));
  }
  return switch (def.id) {
    'strength_up' => const UpgradeArtSpec(UpgradeMotif.heap, _strength),
    'intelligence_up' => const UpgradeArtSpec(
      UpgradeMotif.lattice,
      _intelligence,
    ),
    'beauty_up' => const UpgradeArtSpec(UpgradeMotif.bloom, _beauty),
    'speed_up' => const UpgradeArtSpec(UpgradeMotif.streak, _speed),
    'command_strength' => const UpgradeArtSpec(
      UpgradeMotif.heap,
      _strength,
      team: true,
    ),
    'command_intelligence' => const UpgradeArtSpec(
      UpgradeMotif.lattice,
      _intelligence,
      team: true,
    ),
    'command_beauty' => const UpgradeArtSpec(
      UpgradeMotif.bloom,
      _beauty,
      team: true,
    ),
    'command_speed' => const UpgradeArtSpec(
      UpgradeMotif.streak,
      _speed,
      team: true,
    ),
    'orb_vitality' => const UpgradeArtSpec(UpgradeMotif.rise, _orb),
    'fire_rate' => const UpgradeArtSpec(UpgradeMotif.bolts, _shot),
    'spread_shot' => const UpgradeArtSpec(UpgradeMotif.fan, _shot),
    'rocket_barrage' => const UpgradeArtSpec(UpgradeMotif.comet, _shot),
    'ship_damage' => const UpgradeArtSpec(UpgradeMotif.core, _shot),
    'ship_hull' => const UpgradeArtSpec(
      UpgradeMotif.shell,
      _shot,
      salt: 5,
    ),
    'homing_missiles' => const UpgradeArtSpec(
      UpgradeMotif.comet,
      _steel,
      salt: 1,
    ),
    'missile_launcher' => const UpgradeArtSpec(
      UpgradeMotif.comet,
      _shot,
      salt: 2,
    ),
    'rapid_turret' => const UpgradeArtSpec(UpgradeMotif.bolts, _steel),
    'kinetic_overdrive' => const UpgradeArtSpec(UpgradeMotif.streak, _steel),
    'shield_pulse' => const UpgradeArtSpec(UpgradeMotif.shell, _ward),
    'auto_turret' => const UpgradeArtSpec(UpgradeMotif.orbit, _ward),
    'regen_field' => const UpgradeArtSpec(UpgradeMotif.rise, _heal),
    'nova_detonation' => const UpgradeArtSpec(UpgradeMotif.burst, _orb),
    'revive_half' => const UpgradeArtSpec(UpgradeMotif.gather, _heal),
    'pack_leader' => const UpgradeArtSpec(UpgradeMotif.orbit, _brass, salt: 5),
    'lifesteal' => const UpgradeArtSpec(UpgradeMotif.drip, _blood),
    'time_dilation' => const UpgradeArtSpec(UpgradeMotif.hourglass, _volt),
    'double_cast' => const UpgradeArtSpec(
      UpgradeMotif.twin,
      _beauty,
      second: _volt,
    ),
    'chain_lightning' => const UpgradeArtSpec(UpgradeMotif.chain, _volt),
    'mirror_shield' => const UpgradeArtSpec(
      UpgradeMotif.shell,
      _steel,
      salt: 3,
    ),
    'berserker' => const UpgradeArtSpec(UpgradeMotif.core, _blood, salt: 1),
    'elemental_fury' => const UpgradeArtSpec(
      UpgradeMotif.burst,
      _volt,
      second: _shot,
    ),
    'phoenix_rebirth' => const UpgradeArtSpec(UpgradeMotif.gather, _orb),
    'keystone_bastion_heart' => const UpgradeArtSpec(
      UpgradeMotif.shell,
      _brass,
      salt: 7,
    ),
    'keystone_chrono_surge' => const UpgradeArtSpec(
      UpgradeMotif.spiral,
      _speed,
    ),
    'keystone_spellbloom' => const UpgradeArtSpec(
      UpgradeMotif.bloom,
      _beauty,
      second: _volt,
    ),
    'keystone_warpath' => const UpgradeArtSpec(
      UpgradeMotif.braid,
      _strength,
      second: _ember,
    ),
    'surge_magnet' => const UpgradeArtSpec(UpgradeMotif.magnet, _surge),
    'autopilot' => const UpgradeArtSpec(
      UpgradeMotif.sweep,
      _surge,
      second: _steel,
    ),
    'fusion_homing_spread' => const UpgradeArtSpec(
      UpgradeMotif.seekingFan,
      _shot,
      second: _steel,
    ),
    'fusion_rapid_rockets' => const UpgradeArtSpec(
      UpgradeMotif.rocketTrain,
      _shot,
      second: _ember,
    ),
    'fusion_heavy_missiles' => const UpgradeArtSpec(
      UpgradeMotif.heavyComet,
      _shot,
      second: _steel,
    ),
    'fusion_linked_turrets' => const UpgradeArtSpec(
      UpgradeMotif.linkedBolts,
      _steel,
      second: _ward,
    ),
    'fusion_nova_pulse' => const UpgradeArtSpec(
      UpgradeMotif.pulseNova,
      _ward,
      second: _orb,
    ),
    'fusion_tempered_field' => const UpgradeArtSpec(
      UpgradeMotif.risingBraid,
      _heal,
      second: _orb,
    ),
    _ => const UpgradeArtSpec(UpgradeMotif.core, _brass),
  };
}

/// An upgrade's art at [size]. [animate] runs it on the shared glyph clock.
class UpgradeArt extends StatelessWidget {
  const UpgradeArt({
    super.key,
    required this.def,
    required this.size,
    this.animate = true,
  });

  final PowerUpDef def;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: GrainGlyph(
      size: size,
      animate: animate,
      painter: (clock) =>
          UpgradeArtPainter(spec: upgradeArtFor(def), clock: clock),
    ),
  );
}

class UpgradeArtPainter extends CustomPainter {
  UpgradeArtPainter({required this.spec, this.clock}) : super(repaint: clock);

  final UpgradeArtSpec spec;
  final ValueListenable<double>? clock;

  /// The frame a still glyph is caught on.
  static const double stillTime = 2.15;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (clock?.value ?? 0) + stillTime;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    UpgradeArtPaint.paint(canvas, c, r, t, spec);
  }

  @override
  bool shouldRepaint(covariant UpgradeArtPainter old) =>
      old.clock != clock ||
      old.spec.motif != spec.motif ||
      old.spec.color != spec.color;
}

abstract final class UpgradeArtPaint {
  // Buckets: deep, body, lit, hot, glint — then the same for a second color.
  static final GrainBatch _b = GrainBatch(10);
  static const _deep = 0, _body = 1, _lit = 2, _hot = 3, _glint = 4;

  static double _h(int i, int s) => GrainGlass.h(i, s);
  static double _ease(double x) => GrainGlass.smooth(x);

  static List<Color> _tones(Color c) => [
    Color.lerp(c, const Color(0xFF07060B), 0.45)!,
    c,
    Color.lerp(c, Colors.white, 0.35)!,
    Color.lerp(c, Colors.white, 0.72)!,
    Colors.white,
  ];

  /// Adds a grain at unit position (x, y) of tone [k] (0 deep .. 3 hot).
  static void _add(int k, double x, double y, {bool second = false}) =>
      _b.add(k + (second ? 5 : 0), x, y);

  static void paint(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    UpgradeArtSpec spec,
  ) {
    // Its own light, under everything.
    GrainGlass.pool(canvas, c, r * 0.98, spec.color, alpha: 0.5);
    if (spec.team) {
      // Three of it: the whole team.
      const at = [Offset(-0.44, 0.3), Offset(0.44, 0.3), Offset(0, -0.36)];
      for (var i = 0; i < 3; i++) {
        _one(canvas, c + at[i] * r, r * 0.5, t + i * 0.7, spec, i + 1);
      }
      return;
    }
    _one(canvas, c, r, t, spec, 0);
  }

  static void _one(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    UpgradeArtSpec spec,
    int salt,
  ) {
    _b.clear();
    final s = spec.salt + salt * 11;
    switch (spec.motif) {
      case UpgradeMotif.heap:
        _heap(t, s);
      case UpgradeMotif.streak:
        _streak(t, s);
      case UpgradeMotif.lattice:
        _lattice(t);
      case UpgradeMotif.bloom:
        _bloom(t, spec.second != null);
      case UpgradeMotif.bolts:
        _bolts(t, s);
      case UpgradeMotif.fan:
        _fan(t, s);
      case UpgradeMotif.comet:
        _comet(t, s);
        if (spec.salt == 2) {
          final q = _cometAt(_cometHead(t), 1);
          GrainGlass.sphere(
            canvas,
            c + q * r,
            r * 0.13,
            t,
            a: spec.color,
            heat: 0.7,
            heatColor: Color.lerp(spec.color, Colors.white, 0.5)!,
            glow: 0.8,
            density: 0.5,
          );
        }
      case UpgradeMotif.core:
        _sphere(canvas, c, r, t, spec, heat: 0.65, rad: 0.46);
        _infall(t, s);
      case UpgradeMotif.shell:
        _sphere(canvas, c, r, t, spec, heat: 0.15, rad: 0.3);
        _shell(t, s);
      case UpgradeMotif.rise:
        GrainGlass.pool(
          canvas,
          c + Offset(0, r * 0.5),
          r * 0.55,
          spec.color,
          alpha: 0.8,
        );
        _rise(t, s);
      case UpgradeMotif.burst:
        GrainGlass.pool(canvas, c, r * 0.5, spec.color, alpha: 0.9);
        _burst(t, s, spec.second != null);
      case UpgradeMotif.orbit:
        _orbit(canvas, c, r, t, spec);
      case UpgradeMotif.chain:
        _chain(canvas, c, r, t, spec, s);
      case UpgradeMotif.twin:
        GrainGlass.sphere(
          canvas,
          c + Offset(r * 0.2, -r * 0.08),
          r * 0.4,
          t,
          a: spec.second ?? spec.color,
          fade: 0.55,
          spin: -0.4,
          glow: 0.5,
        );
        GrainGlass.sphere(
          canvas,
          c + Offset(-r * 0.18, r * 0.1),
          r * 0.44,
          t,
          a: spec.color,
          spin: 0.5,
          glow: 0.6,
        );
      case UpgradeMotif.gather:
        // Caught part-formed: grains still on their way in.
        final g = 0.5 + 0.38 * _ease(0.5 + 0.5 * math.sin(t * 0.7 + 2.6));
        GrainGlass.sphere(
          canvas,
          c,
          r * 0.48,
          t,
          a: spec.color,
          gather: g,
          heat: spec.color == _orb ? 0.5 * g : 0,
          glow: 0.7,
        );
      case UpgradeMotif.drip:
        GrainGlass.pool(
          canvas,
          c + Offset(0, r * 0.56),
          r * 0.5,
          spec.color,
          alpha: 0.9,
        );
        _drip(t, s);
      case UpgradeMotif.hourglass:
        _hourglass(t, s);
      case UpgradeMotif.spiral:
        GrainGlass.pool(canvas, c, r * 0.36, spec.color, alpha: 0.9);
        _spiral(t);
      case UpgradeMotif.braid:
        GrainGlass.pool(
          canvas,
          c + _braidAt(1.0) * r,
          r * 0.42,
          spec.second ?? spec.color,
          alpha: 0.85,
        );
        _braid(t, s);
      case UpgradeMotif.magnet:
        GrainGlass.pool(
          canvas,
          c + _magnetPoint * r,
          r * 0.36,
          spec.color,
          alpha: 0.95,
        );
        _magnet(t, s);
      case UpgradeMotif.sweep:
        GrainGlass.sphere(
          canvas,
          c + _sweepHome * r,
          r * 0.21,
          t,
          a: spec.color,
          glow: 0.6,
        );
        _sweep(t, s);
      case UpgradeMotif.world:
        GrainGlass.sphere(
          canvas,
          c + Offset(0, r * 0.08),
          r * 0.5,
          t,
          a: spec.color,
          spin: 0.35,
          glow: 0.6,
        );
        _rise(t, s, from: 0.0, spread: 0.55, n: 26);
      case UpgradeMotif.seekingFan:
        _seekingFan(t, s);
      case UpgradeMotif.rocketTrain:
        _rocketTrain(t, s);
      case UpgradeMotif.heavyComet:
        _heavyComet(canvas, c, r, t, spec, s);
      case UpgradeMotif.linkedBolts:
        _linkedBolts(canvas, c, r, t, spec, s);
      case UpgradeMotif.pulseNova:
        GrainGlass.sphere(
          canvas,
          c,
          r * 0.24,
          t,
          a: spec.color,
          heat: 0.6,
          heatColor: spec.second ?? spec.color,
          glow: 0.7,
        );
        _pulseNova(t, s);
      case UpgradeMotif.risingBraid:
        GrainGlass.pool(
          canvas,
          c + Offset(-r * 0.14, r * 0.54),
          r * 0.46,
          spec.color,
          alpha: 0.8,
        );
        GrainGlass.pool(
          canvas,
          c + Offset(r * 0.16, r * 0.56),
          r * 0.42,
          spec.second ?? spec.color,
          alpha: 0.7,
        );
        _risingBraid(t, s);
    }
    _flush(canvas, c, r, spec);
  }

  static void _flush(Canvas canvas, Offset c, double r, UpgradeArtSpec spec) {
    final d = (r * 0.066).clamp(0.9, 2.2);
    final ta = _tones(spec.color);
    final tb = _tones(spec.second ?? spec.color);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(r);
    final u = d / r;
    _b.draw(canvas, _deep, u * 0.9, ta[0].withValues(alpha: 0.75));
    _b.draw(canvas, _body, u, ta[1].withValues(alpha: 0.9));
    _b.draw(canvas, _lit, u, ta[2]);
    _b.draw(canvas, _hot, u * 1.1, ta[3]);
    _b.draw(canvas, 5 + _deep, u * 0.9, tb[0].withValues(alpha: 0.75));
    _b.draw(canvas, 5 + _body, u, tb[1].withValues(alpha: 0.9));
    _b.draw(canvas, 5 + _lit, u, tb[2]);
    _b.draw(canvas, 5 + _hot, u * 1.1, tb[3]);
    _b.draw(canvas, _glint, u * 2.2, const Color(0x40FFFFFF));
    _b.draw(canvas, _glint, u * 1.2, Colors.white);
    canvas.restore();
  }

  static void _sphere(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    UpgradeArtSpec spec, {
    required double heat,
    required double rad,
  }) => GrainGlass.sphere(
    canvas,
    c,
    r * rad,
    t,
    a: spec.color,
    heat: heat,
    heatColor: Color.lerp(spec.color, Colors.white, 0.4)!,
    glow: 0.6,
    salt: spec.salt,
  );

  // ── Strength: grains settled into a heap, a few still falling onto it. ──
  static void _heap(double t, int s) {
    const n = 120;
    for (var i = 0; i < n; i++) {
      final u = _h(i, 1 + s) * 2 - 1;
      final top = 0.5 - 0.62 * math.pow(1 - u * u, 1.3);
      final y = 0.56 - (0.56 - top) * math.pow(_h(i, 2 + s), 0.7);
      final x = u * 0.78;
      final height = (0.56 - y) / 0.62;
      final k = y - top < 0.06 ? _hot : (height > 0.45 ? _lit : _body);
      _add(height < 0.12 ? _deep : k, x, y);
    }
    for (var i = 0; i < 6; i++) {
      final p = (t * 0.32 + _h(i, 9 + s)) % 1.0;
      final x = (_h(i, 10 + s) - 0.5) * 0.36;
      final y = -0.78 + p * 0.74;
      _add(p > 0.85 ? _hot : _lit, x, y);
    }
  }

  // ── Speed: streaks of grains running right, heads hot. ──
  static void _streak(double t, int s) {
    for (var row = 0; row < 6; row++) {
      final y = -0.55 + row * 0.22 + (_h(row, 3 + s) - 0.5) * 0.08;
      final speed = 0.42 + 0.2 * _h(row, 4 + s);
      final head = ((t * speed + _h(row, 5 + s)) % 1.0) * 1.9 - 0.85;
      for (var j = 0; j < 15; j++) {
        final x = head - j * 0.05;
        if (x * x + y * y > 0.8) continue;
        _add(
          j == 0
              ? _hot
              : j < 3
              ? _lit
              : j < 7
              ? _body
              : _deep,
          x,
          y,
        );
      }
    }
  }

  // ── Intelligence: a lattice of grains turning, ordered. ──
  static void _lattice(double t) {
    final a = t * 0.35;
    final ca = math.cos(a), sa = math.sin(a);
    const tilt = 0.5;
    final ct = math.cos(tilt), st = math.sin(tilt);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        for (var k = 0; k < 4; k++) {
          final x0 = (i - 1.5) * 0.3,
              y0 = (j - 1.5) * 0.3,
              z0 = (k - 1.5) * 0.3;
          final x1 = x0 * ca + z0 * sa;
          final z1 = -x0 * sa + z0 * ca;
          final y = y0 * ct - z1 * st;
          final z = y0 * st + z1 * ct;
          final tone = z > 0.25
              ? _hot
              : z > 0
              ? _lit
              : z > -0.25
              ? _body
              : _deep;
          _add(tone, x1 * 1.05, y * 1.05);
        }
      }
    }
  }

  // ── Beauty: grains in a bloom, turning slowly. ──
  static void _bloom(double t, bool two) {
    const n = 130;
    for (var i = 0; i < n; i++) {
      final f = math.sqrt((i + 0.5) / n);
      final ang = i * 2.39996 + t * 0.18;
      final petal = 1 + 0.16 * math.cos(5 * ang - t * 0.1);
      final rr = 0.8 * f * petal;
      final x = rr * math.cos(ang), y = rr * math.sin(ang);
      final tone = f < 0.25
          ? _hot
          : f < 0.55
          ? _lit
          : f < 0.85
          ? _body
          : _deep;
      _add(tone, x, y, second: two && i.isOdd);
    }
  }

  // ── Fire rate: three lanes of shots, up and to the right. ──
  static void _bolts(double t, int s) {
    const dir = Offset(0.8, -0.6);
    const nrm = Offset(0.6, 0.8);
    for (var lane = -1; lane <= 1; lane++) {
      final base = nrm * (lane * 0.28);
      for (var b = 0; b < 3; b++) {
        final p = ((t * 0.55 + b / 3 + _h(lane + 2, 6 + s) * 0.3) % 1.0);
        final head = base + dir * (p * 1.8 - 0.9);
        for (var j = 0; j < 5; j++) {
          final q = head - dir * (j * 0.05);
          if (q.distanceSquared > 0.72) continue;
          _add(
            j == 0
                ? _hot
                : j < 2
                ? _lit
                : _body,
            q.dx,
            q.dy,
          );
        }
      }
    }
  }

  // ── Spread shot: three streams fanning out of one point. ──
  static void _fan(double t, int s) {
    const src = Offset(-0.52, 0.5);
    for (var lane = 0; lane < 3; lane++) {
      final ang = -math.pi / 2 + (lane - 1) * 0.5 + 0.55;
      final dir = Offset(math.cos(ang), math.sin(ang));
      for (var g = 0; g < 14; g++) {
        final p = ((t * 0.4 + g / 14) % 1.0);
        final q = src + dir * (p * 1.2);
        if (q.distanceSquared > 0.8) continue;
        final jitter = (_h(g + lane * 20, 7 + s) - 0.5) * 0.05 * p;
        _add(
          p > 0.8
              ? _deep
              : p > 0.5
              ? _body
              : p > 0.2
              ? _lit
              : _hot,
          q.dx + dir.dy * jitter,
          q.dy - dir.dx * jitter,
        );
      }
    }
    _add(_hot, src.dx, src.dy);
    _add(_glint, src.dx, src.dy);
  }

  // ── Rockets / missiles: a hot head on a long curving tail. ──
  // Rocket Barrage's is plain; Hunter Salvo's turns the other way, toward
  // its mark; the Missile Launcher's is heavier, a lit glass head.
  static Offset _cometAt(double p, double flip) {
    const a = Offset(-0.72, 0.6), b = Offset(-0.42, -0.62);
    const c = Offset(0.66, -0.3);
    final q = a * ((1 - p) * (1 - p)) + b * (2 * p * (1 - p)) + c * (p * p);
    // Nudged so the lit part of the trail, not the whole curve, is centred.
    return Offset(q.dx * flip + 0.08 * flip, q.dy + 0.14);
  }

  static double _cometHead(double t) => 0.6 + 0.2 * _ease((t * 0.2) % 1.0);

  static void _comet(double t, int s) {
    final flip = s == 1 ? -1.0 : 1.0;
    final heavy = s == 2;
    final head = _cometHead(t);
    // A dense tail that thins and loosens as it falls behind.
    final n = heavy ? 56 : 50;
    for (var j = 0; j < n; j++) {
      final p = head - j * 0.011;
      if (p < 0) break;
      final q = _cometAt(p, flip);
      final spread = j * (heavy ? 0.0016 : 0.0012);
      final jx = (_h(j, 9 + s) - 0.5) * spread * 6;
      final jy = (_h(j, 10 + s) - 0.5) * spread * 6;
      _add(
        j < 3
            ? _hot
            : j < 16
            ? _lit
            : j < 40
            ? _body
            : _deep,
        q.dx + jx,
        q.dy + jy,
      );
      if (j > 6 && j % 3 == 0) {
        _add(j < 24 ? _body : _deep, q.dx - jy * 2.2, q.dy + jx * 2.2);
      }
    }
    final q = _cometAt(head, flip);
    _add(_glint, q.dx, q.dy);
    _add(_hot, q.dx + 0.025, q.dy - 0.01);
    _add(_hot, q.dx - 0.01, q.dy + 0.02);
  }

  // Grains drawn in to a hot core.
  static void _infall(double t, int s) {
    for (var i = 0; i < 40; i++) {
      final a = _h(i, 11 + s) * math.pi * 2 + t * 0.3;
      final p = (t * 0.3 + _h(i, 12 + s)) % 1.0;
      final rr = 0.92 - p * 0.42;
      _add(
        p > 0.75
            ? _hot
            : p > 0.4
            ? _lit
            : _body,
        math.cos(a) * rr,
        math.sin(a) * rr,
      );
    }
  }

  // ── Pulse / ward: a shell of grains round a small core, breathing. ──
  static void _shell(double t, int s) {
    final breathe = 0.7 + 0.05 * math.sin(t * 1.1);
    const n = 110;
    final spin = t * 0.25;
    for (var i = 0; i < n; i++) {
      final lat = math.asin(2 * _h(i, 13 + s) - 1);
      final lon = _h(i, 14 + s) * math.pi * 2 + spin;
      final rr = breathe * (0.96 + 0.08 * _h(i, 15 + s));
      final x = rr * math.cos(lat) * math.cos(lon);
      final y = rr * math.sin(lat);
      final z = rr * math.cos(lat) * math.sin(lon);
      final light = (-0.5 * x - 0.55 * y + 0.65 * z) / rr;
      final tone = z < 0
          ? _deep
          : light > 0.55
          ? _hot
          : light > 0.1
          ? _lit
          : _body;
      _add(tone, x, y);
    }
  }

  // ── Healing / vitality: grains rising off a pool. ──
  static void _rise(
    double t,
    int s, {
    double from = 0.5,
    double spread = 0.6,
    int n = 44,
  }) {
    for (var i = 0; i < n; i++) {
      final p = (t * 0.22 + _h(i, 16 + s)) % 1.0;
      final sway = math.sin(t * 0.8 + i) * 0.04;
      final x = (_h(i, 17 + s) - 0.5) * spread * (1 - p * 0.4) + sway;
      final y = from - p * (from + 0.72);
      _add(
        p < 0.2
            ? _hot
            : p < 0.5
            ? _lit
            : p < 0.8
            ? _body
            : _deep,
        x,
        y,
      );
    }
    if (from > 0.2) {
      for (var i = 0; i < 26; i++) {
        final u = _h(i, 18 + s) * 2 - 1;
        _add(_lit, u * 0.5, from + 0.04 + _h(i, 19 + s) * 0.08 * (1 - u * u));
      }
    }
  }

  // ── Nova / fury: grains flung out from a hot centre. ──
  static void _burst(double t, int s, bool many) {
    const n = 56;
    for (var i = 0; i < n; i++) {
      final a = _h(i, 20 + s) * math.pi * 2;
      final p = (t * 0.3 + _h(i, 21 + s)) % 1.0;
      final rr = 0.14 + _ease(p) * 0.72;
      final second = many && i % 3 == 0;
      for (var j = 0; j < 2; j++) {
        final q = rr - j * 0.05;
        if (q < 0.1) continue;
        _add(
          j == 1
              ? _deep
              : p < 0.3
              ? _hot
              : p < 0.65
              ? _lit
              : _body,
          math.cos(a) * q,
          math.sin(a) * q,
          second: second,
        );
      }
    }
    _add(_glint, 0, 0);
  }

  // ── Turret / pack: a core with smaller spheres round it. ──
  static void _orbit(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    UpgradeArtSpec spec,
  ) {
    final pack = spec.salt == 5;
    final count = pack ? 5 : 2;
    final spheres = <(double z, Offset at, double rad)>[];
    for (var i = 0; i < count; i++) {
      final a = t * 0.35 + i * math.pi * 2 / count;
      spheres.add((
        math.sin(a),
        Offset(math.cos(a) * 0.62, math.sin(a) * 0.24),
        pack ? 0.15 : 0.12,
      ));
    }
    spheres.sort((x, y) => x.$1.compareTo(y.$1));
    void satellite((double, Offset, double) s) => GrainGlass.sphere(
      canvas,
      c + s.$2 * r,
      r * s.$3 * (0.85 + 0.15 * s.$1),
      t,
      a: spec.color,
      glow: 0.3,
      fade: 0.65 + 0.35 * (s.$1 * 0.5 + 0.5),
      density: 0.6,
    );
    for (final s in spheres.where((s) => s.$1 < 0)) {
      satellite(s);
    }
    GrainGlass.sphere(
      canvas,
      c,
      r * (pack ? 0.3 : 0.36),
      t,
      a: spec.color,
      glow: 0.6,
      heat: pack ? 0.3 : 0,
    );
    for (final s in spheres.where((s) => s.$1 >= 0)) {
      satellite(s);
    }
    if (!pack) {
      // The turret's shot, leaving the near satellite.
      final front = spheres.last.$2;
      final dir = front / front.distance.clamp(0.01, 9);
      for (var j = 0; j < 7; j++) {
        final p = ((t * 0.9) % 1.0) * 0.4 + j * 0.035;
        final q = front + dir * (0.14 + p);
        if (q.distanceSquared > 0.85) continue;
        _add(j < 2 ? _hot : _lit, q.dx, q.dy);
      }
    }
  }

  // ── Chain lightning: grains jumping between three points. ──
  static void _chain(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    UpgradeArtSpec spec,
    int s,
  ) {
    const nodes = [Offset(-0.58, 0.4), Offset(0.0, -0.52), Offset(0.6, 0.32)];
    for (final n in nodes) {
      GrainGlass.pool(canvas, c + n * r, r * 0.3, spec.color, alpha: 1);
    }
    // The jag eases from one shape to the next; it never flickers.
    final seed = (t * 0.5).floor();
    final blend = _ease((t * 0.5) % 1.0);
    for (var e = 0; e < 2; e++) {
      final a = nodes[e], b = nodes[e + 1];
      final dir = b - a;
      final nrm = Offset(-dir.dy, dir.dx) / dir.distance;
      // Five corners along the edge, alternating sides.
      Offset corner(int k) {
        if (k == 0) return a;
        if (k == 6) return b;
        double off(int sd) =>
            (k.isOdd ? 1 : -1) *
            (0.07 + 0.09 * _h(k + e * 9 + sd * 31, 22 + s));
        final o = off(seed) * (1 - blend) + off(seed + 1) * blend;
        return a + dir * (k / 6) + nrm * o;
      }

      for (var k = 0; k < 6; k++) {
        final p0 = corner(k), p1 = corner(k + 1);
        for (var j = 0; j < 4; j++) {
          final q = Offset.lerp(p0, p1, j / 4)!;
          _add(j == 0 ? _hot : _lit, q.dx, q.dy);
        }
      }
    }
    for (final n in nodes) {
      for (var i = 0; i < 12; i++) {
        final a = _h(i, 23 + s) * math.pi * 2;
        final rr = 0.03 + _h(i, 24 + s) * 0.09;
        _add(
          i < 4 ? _hot : _lit,
          n.dx + math.cos(a) * rr,
          n.dy + math.sin(a) * rr,
        );
      }
      _add(_glint, n.dx, n.dy);
    }
  }

  // ── Blood Pact: drops of grains falling into a pool. ──
  static void _drip(double t, int s) {
    for (var d = 0; d < 3; d++) {
      final p = (t * 0.3 + d / 3) % 1.0;
      final x = (d - 1) * 0.3;
      final y = -0.7 + _ease(p) * 1.15;
      if (y > 0.5) continue;
      for (var j = 0; j < 6; j++) {
        _add(
          j == 0 ? _hot : _lit,
          x + (_h(j + d * 9, 25 + s) - 0.5) * 0.07,
          y - j * 0.035,
        );
      }
    }
    for (var i = 0; i < 40; i++) {
      final u = _h(i, 26 + s) * 2 - 1;
      _add(
        i % 4 == 0 ? _lit : _body,
        u * 0.6,
        0.56 + _h(i, 27 + s) * 0.1 * (1 - u * u),
      );
    }
  }

  // ── Time Dilation: sand above running down into a heap below. ──
  static void _hourglass(double t, int s) {
    final fill = 0.5 + 0.1 * math.sin(t * 0.3);
    for (var i = 0; i < 70; i++) {
      // Upper: a cone narrowing to the neck, its top sinking.
      final v = _h(i, 28 + s);
      final y = -0.06 - v * 0.6 * (1.25 - fill);
      final half = 0.05 + (-0.06 - y) * 0.85;
      final u = _h(i, 29 + s) * 2 - 1;
      _add(v > 0.85 ? _deep : (v < 0.25 ? _lit : _body), u * half, y);
      // Lower: a heap rising from the floor.
      final w = _h(i, 30 + s) * 2 - 1;
      final top = 0.62 - (0.4 * fill + 0.12) * (1 - w.abs());
      final yy = 0.62 - (0.62 - top) * _h(i, 31 + s);
      _add(yy - top < 0.05 ? _hot : _lit, w * 0.5, yy);
    }
    for (var j = 0; j < 12; j++) {
      final p = (t * 0.25 + j / 12) % 1.0;
      _add(j.isEven ? _hot : _lit, 0, -0.04 + p * 0.5);
    }
  }

  // ── Chrono Surge: two arms of grains wound round a hot centre. ──
  static void _spiral(double t) {
    for (var arm = 0; arm < 2; arm++) {
      for (var i = 0; i < 46; i++) {
        final f = i / 46;
        final a = arm * math.pi + f * 4.2 - t * 0.6;
        final rr = 0.1 + f * 0.72;
        _add(
          f < 0.2
              ? _hot
              : f < 0.5
              ? _lit
              : f < 0.8
              ? _body
              : _deep,
          math.cos(a) * rr,
          math.sin(a) * rr * 0.92,
        );
      }
    }
    _add(_glint, 0, 0);
  }

  // ── Surge Magnet: grains left on the field, drawn in to one point. ──
  // Streams curl in from the far side and quicken as they near, hotter the
  // closer they come; a few still wait where they fell.
  static const Offset _magnetPoint = Offset(0.22, -0.24);

  static void _magnet(double t, int s) {
    const p0 = _magnetPoint;
    for (var k = 0; k < 6; k++) {
      // Where the stream starts: round the far side of the point.
      final a = 2.35 + (k - 2.5) * 0.36 + (_h(k, 40 + s) - 0.5) * 0.14;
      final reach = 0.82 + 0.16 * _h(k, 41 + s);
      final start = p0 + Offset(math.cos(a), math.sin(a)) * reach;
      // All curling the same way, so the streams read as one pull.
      final curl = 0.85 + 0.3 * _h(k, 42 + s);
      for (var j = 0; j < 9; j++) {
        final p = (t * 0.24 + j / 9 + _h(k, 43 + s) * 0.5) % 1.0;
        // Drawn in steadily, bunching as they arrive.
        final e = GrainGlass.smooth(p * 0.92 + 0.04);
        final rel = (start - p0) * (1 - e);
        final th = curl * (1 - e);
        final q =
            p0 +
            Offset(
              rel.dx * math.cos(th) - rel.dy * math.sin(th),
              rel.dx * math.sin(th) + rel.dy * math.cos(th),
            );
        if ((q - Offset.zero).distanceSquared > 0.86) continue;
        _add(
          p > 0.85
              ? _hot
              : p > 0.55
              ? _lit
              : p > 0.25
              ? _body
              : _deep,
          q.dx,
          q.dy,
        );
      }
    }
    // The ones still waiting where they fell.
    for (var i = 0; i < 8; i++) {
      final x = -0.6 + _h(i, 44 + s) * 0.62;
      final y = 0.12 + _h(i, 45 + s) * 0.5;
      if (x * x + y * y > 0.8) continue;
      _add(i % 3 == 0 ? _body : _deep, x, y);
    }
    // The point itself: a tight knot of hot grains.
    for (var i = 0; i < 12; i++) {
      final a = _h(i, 46 + s) * math.pi * 2 + t * 0.4;
      final rr = 0.02 + _h(i, 47 + s) * 0.07;
      _add(
        i < 5 ? _hot : _lit,
        p0.dx + math.cos(a) * rr,
        p0.dy + math.sin(a) * rr,
      );
    }
    _add(_glint, p0.dx, p0.dy);
  }

  // ── Autopilot: the ship's loop out from the orb and home again. ──
  // The ship (a knot of steel grains, its wake behind it) leaves the orb,
  // swings out along a petal through heaps of violet grains lying where
  // bodies fell, and each heap it passes curls into it and rides its wake;
  // then it comes home and goes again, the heaps settling back behind it.
  static const Offset _sweepHome = Offset(-0.34, 0.32);

  static Offset _sweepAt(double u) {
    final a = -0.62 + (u - 0.5) * 1.5;
    final rho = 0.98 * math.pow(math.sin(math.pi * u), 0.8).toDouble();
    return _sweepHome + Offset(math.cos(a), math.sin(a)) * rho;
  }

  static void _sweep(double t, int s) {
    final u = (t * 0.18) % 1.0;
    final head = _sweepAt(u);
    // The grains along its way, in small heaps where bodies fell: lying
    // until it comes, then drawn into it. Taken ones settle back in, deep
    // first, once it has gone by, so the loop always has some to fetch.
    for (var i = 0; i < 8; i++) {
      final ui = 0.14 + 0.72 * (i + 0.5 * _h(i, 60 + s)) / 8;
      final at = _sweepAt(ui);
      final next = _sweepAt(ui + 0.01);
      final along = next - at;
      final side = Offset(-along.dy, along.dx) / along.distance.clamp(1e-4, 9);
      final heap = at + side * ((_h(i, 61 + s) - 0.5) * 0.16);
      final come = (u - (ui - 0.06)) / 0.08;
      // How far round since it was taken, for the settling back in.
      final since = (u - ui + 1) % 1.0;
      for (var g = 0; g < 3; g++) {
        final spot =
            heap +
            Offset(
              (_h(i * 3 + g, 64 + s) - 0.5) * 0.09,
              (_h(i * 3 + g, 65 + s) - 0.5) * 0.09,
            );
        if (come > 0 && come < 1) {
          final e = GrainGlass.smooth((come + g * 0.12).clamp(0.0, 1.0));
          final q = Offset.lerp(spot, head, e)!;
          _add(e > 0.6 ? _hot : _lit, q.dx, q.dy);
        } else if (come >= 1 && since < 0.3) {
          continue; // taken, not back yet
        } else if (come >= 1 && since < 0.45) {
          _add(_deep, spot.dx, spot.dy);
        } else {
          _add(g == 0 ? _lit : _body, spot.dx, spot.dy);
        }
      }
    }
    // Its wake, two lanes; the fetched grains ride the near part of it.
    final along = _sweepAt(u + 0.01) - head;
    final side =
        Offset(-along.dy, along.dx) / along.distance.clamp(1e-4, 9) * 0.018;
    for (var j = 1; j <= 18; j++) {
      final w = u - j * 0.011;
      if (w <= 0) break;
      final q = _sweepAt(w);
      final k = j < 4
          ? _lit
          : j < 10
          ? _body
          : _deep;
      _add(k, q.dx + side.dx, q.dy + side.dy, second: true);
      if (j < 12) _add(k, q.dx - side.dx, q.dy - side.dy, second: true);
      if (j < 6 && j.isOdd) _add(_lit, q.dx, q.dy);
    }
    // The ship: a knot of hot steel grains.
    for (var i = 0; i < 11; i++) {
      final a = _h(i, 62 + s) * math.pi * 2 + t * 1.1;
      final rr = 0.02 + _h(i, 63 + s) * 0.045;
      _add(
        i < 4 ? _hot : _lit,
        head.dx + math.cos(a) * rr,
        head.dy + math.sin(a) * rr,
        second: true,
      );
    }
    _add(_glint, head.dx, head.dy);
  }

  // ── Warpath: two currents braided into one surge. ──
  // The team's embers (red) and the ship's (gold) come in from behind as two
  // currents, one high and one low, twist round each other and pour together
  // into one swell at the front that leans on, its upper side ahead of its
  // lower like a wave about to break. A rope, not an arrowhead: the currents
  // cross and recross instead of meeting at a point, and the front is a
  // rounded crest, never a tip. The twist rolls forward with the grains.
  static const Offset _braidFrom = Offset(-0.74, 0.16);
  static const Offset _braidBend = Offset(-0.12, 0.14);
  static const Offset _braidTo = Offset(0.3, -0.06);

  static Offset _braidAt(double u) {
    final v = 1 - u;
    return _braidFrom * (v * v) + _braidBend * (2 * u * v) + _braidTo * (u * u);
  }

  /// The braid's sideways direction at [u], toward the top of the card.
  static Offset _braidNormal(double u) {
    final d =
        (_braidBend - _braidFrom) * (2 * (1 - u)) +
        (_braidTo - _braidBend) * (2 * u);
    return Offset(d.dy, -d.dx) / d.distance;
  }

  static void _braid(double t, int s) {
    // The two currents, half a turn apart: where one passes over the other
    // it is lit, where it passes under it sinks to its dark.
    for (var strand = 0; strand < 2; strand++) {
      final ship = strand == 1;
      for (var i = 0; i < 62; i++) {
        final k = i + strand * 64;
        // Running forward, quickening toward the front.
        final p = (t * 0.2 + i / 62 + _h(k, 50 + s) * 0.02) % 1.0;
        final u = p * (0.8 + 0.2 * p);
        // Wide apart behind, drawn tight where they pour together.
        final amp = 0.33 * (1 - 0.8 * u);
        final phase =
            math.pi / 2 + u * math.pi * 1.9 - t * 0.8 + strand * math.pi;
        final over = math.cos(phase);
        // A current, not a thread: grains spread across it, thinning on.
        final across = (_h(k, 51 + s) - 0.5) * 0.15 * (1 - 0.45 * u);
        final q =
            _braidAt(u) + _braidNormal(u) * (amp * math.sin(phase) + across);
        if (q.distanceSquared > 0.84) continue;
        _add(
          u < 0.1
              ? _deep
              : over > 0.4
              ? (u > 0.62 ? _hot : _lit)
              : over > -0.35
              ? _body
              : _deep,
          q.dx,
          q.dy,
          second: ship,
        );
      }
    }
    // The surge: one swell where they have joined, its upper side further
    // on than its lower, breathing forward a little.
    final head = _braidAt(1.0);
    const fwd = Offset(0.96, -0.28);
    const up = Offset(-0.28, -0.96);
    final lean = 0.02 * math.sin(t * 1.2);
    for (var i = 0; i < 56; i++) {
      final a = _h(i, 52 + s) * math.pi * 2;
      final rr = math.sqrt(_h(i, 53 + s));
      final x = math.cos(a) * rr, y = math.sin(a) * rr;
      // Lopsided: the higher a grain sits, the further on it rides.
      final ahead = 0.1 + x * 0.19 + y * 0.09 + lean;
      final q = head + fwd * ahead + up * (y * 0.21 + 0.02);
      _add(
        rr < 0.45 ? _hot : (rr < 0.8 ? _lit : _body),
        q.dx,
        q.dy,
        second: i.isOdd,
      );
    }
    final crest = head + fwd * 0.24 + up * 0.12;
    _add(_glint, crest.dx, crest.dy);
    // A few grains thrown on ahead of the crest, thinning as they go.
    for (var i = 0; i < 8; i++) {
      final l = (t * 0.45 + _h(i, 56 + s)) % 1.0;
      final q =
          head +
          fwd * (0.24 + 0.3 * GrainGlass.smooth(l)) +
          up * ((_h(i, 57 + s) - 0.35) * 0.3);
      if (q.distanceSquared > 0.84) continue;
      _add(
        l < 0.35 ? _lit : (l < 0.7 ? _body : _deep),
        q.dx,
        q.dy,
        second: i.isEven,
      );
    }
    // And a few shed off the rope, drifting back and out as they fade.
    for (var i = 0; i < 8; i++) {
      final l = (t * 0.32 + _h(i, 54 + s)) % 1.0;
      final u0 = 0.3 + 0.5 * _h(i, 55 + s);
      final out = (i.isEven ? 1 : -1) * (0.12 + 0.18 * GrainGlass.smooth(l));
      final q = _braidAt(u0 - 0.12 * l) + _braidNormal(u0) * out;
      if (q.distanceSquared > 0.84) continue;
      _add(l < 0.3 ? _body : _deep, q.dx, q.dy, second: i % 3 == 0);
    }
  }

  // ══ Surge fusions: two parents' formations made one. ══

  // ── Homing Spread: the spread's three streams, each turning onto a mark
  // of its own the way Hunter Salvo's comet turns onto its. A stream leaves
  // the spread's source in the shot's ember and takes the hunter's steel as
  // it turns; it is hottest where it arrives.
  static const Offset _seekSrc = Offset(-0.52, 0.5);
  static const List<Offset> _seekMarks = [
    Offset(0.04, -0.62),
    Offset(0.36, -0.46),
    Offset(0.62, -0.06),
  ];

  static Offset _seekAt(int lane, double p) {
    final ang = -math.pi / 2 + (lane - 1) * 0.5 + 0.55;
    final bend = _seekSrc + Offset(math.cos(ang), math.sin(ang)) * 0.95;
    final v = 1 - p;
    return _seekSrc * (v * v) + bend * (2 * p * v) + _seekMarks[lane] * (p * p);
  }

  static void _seekingFan(double t, int s) {
    for (var lane = 0; lane < 3; lane++) {
      for (var g = 0; g < 18; g++) {
        final p = (t * 0.34 + g / 18 + lane * 0.11) % 1.0;
        final q = _seekAt(lane, p);
        final ahead = _seekAt(lane, math.min(1.0, p + 0.02));
        final d = ahead - q;
        final len = d.distance;
        final nrm = len > 0 ? Offset(-d.dy, d.dx) / len : Offset.zero;
        // A current a few grains wide, drawn tight as it closes in.
        for (var w = 0; w < 2; w++) {
          final across = (_h(g * 2 + w + lane * 40, 60 + s) - 0.5) * 0.07;
          final at = q + nrm * (across * (1 - 0.6 * p));
          if (at.distanceSquared > 0.84) continue;
          final steel = p > 0.48;
          _add(
            p > 0.86
                ? _hot
                : p > 0.62
                ? _lit
                : p > 0.3
                ? _body
                : (p < 0.08 ? _lit : _deep),
            at.dx,
            at.dy,
            second: steel,
          );
        }
      }
      // Where it arrives: a small knot of the hunter's steel.
      final m = _seekMarks[lane];
      for (var i = 0; i < 6; i++) {
        final a = _h(i + lane * 9, 61 + s) * math.pi * 2 + t * 0.4;
        final rr = 0.02 + _h(i + lane * 9, 62 + s) * 0.05;
        _add(
          i < 2 ? _hot : _lit,
          m.dx + math.cos(a) * rr,
          m.dy + math.sin(a) * rr,
          second: true,
        );
      }
    }
    _add(_hot, _seekSrc.dx, _seekSrc.dy);
    _add(_glint, _seekSrc.dx, _seekSrc.dy);
    _add(_glint, _seekMarks[1].dx, _seekMarks[1].dy);
  }

  // ── Rapid Rockets: the rocket's comet path with rockets coming down it as
  // close as the gun's shots, each a hot head on a short ember tail. They
  // come in at one edge and leave at the other, so none pops in or out.
  static void _rocketTrain(double t, int s) {
    for (var k = 0; k < 3; k++) {
      final head = -0.12 + ((t * 0.22 + k / 3) % 1.0) * 1.4;
      for (var j = 0; j < 24; j++) {
        final p = head - j * 0.011;
        final q = _cometAt(p, 1);
        final spread = j * 0.0019;
        final jx = (_h(j + k * 30, 63 + s) - 0.5) * spread * 6;
        final jy = (_h(j + k * 30, 64 + s) - 0.5) * spread * 6;
        final at = Offset(q.dx + jx, q.dy + jy);
        if (at.distanceSquared > 0.86) continue;
        _add(
          j < 2
              ? _hot
              : j < 6
              ? _lit
              : j < 14
              ? _body
              : _deep,
          at.dx,
          at.dy,
          second: j >= 4,
        );
        // The tail loosens behind the head, a grain either side.
        if (j > 4 && j.isEven) {
          final side = Offset(q.dx - jy * 2.4, q.dy + jx * 2.4);
          if (side.distanceSquared < 0.86) {
            _add(j < 14 ? _body : _deep, side.dx, side.dy, second: true);
          }
        }
      }
      final q = _cometAt(head, 1);
      if (q.distanceSquared < 0.8) _add(_glint, q.dx, q.dy);
    }
    // The path they all take: loose smoke along it, the long comet's tail.
    for (var j = 0; j < 34; j++) {
      final p = 0.04 + j / 34 * 0.92;
      final q = _cometAt(p, 1);
      final jx = (_h(j, 65 + s) - 0.5) * 0.06;
      final jy = (_h(j, 66 + s) - 0.5) * 0.06;
      _add(_deep, q.dx + jx, q.dy + jy, second: j.isOdd);
    }
  }

  // ── Heavy Missiles: the launcher's heavy comet with its glass head, and
  // the overdrive's steel streaks running in beside its tail and pouring
  // into it, wide behind and drawn in toward the head.
  static Offset _cometNormal(double p) {
    const a = Offset(-0.72, 0.6), b = Offset(-0.42, -0.62);
    const c = Offset(0.66, -0.3);
    final d = (b - a) * (2 * (1 - p)) + (c - b) * (2 * p);
    return Offset(-d.dy, d.dx) / d.distance;
  }

  static void _heavyComet(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    UpgradeArtSpec spec,
    int s,
  ) {
    _comet(t, 2);
    final head = _cometHead(t);
    for (var row = 0; row < 4; row++) {
      final side = (row - 1.5) * 0.12;
      for (var k = 0; k < 2; k++) {
        final f0 = (t * 0.42 + k / 2 + _h(row, 67 + s) * 0.5) % 1.0;
        for (var j = 0; j < 7; j++) {
          final f = f0 - j * 0.035;
          if (f < 0) continue;
          final p = head - 0.6 + f * 0.52;
          if (p < 0) continue;
          final at = _cometAt(p, 1) + _cometNormal(p) * (side * (1 - f) * 0.95);
          if (at.distanceSquared > 0.86) continue;
          _add(
            j == 0
                ? _hot
                : j < 3
                ? _lit
                : f > 0.3
                ? _body
                : _deep,
            at.dx,
            at.dy,
            second: true,
          );
        }
      }
    }
    final q = _cometAt(head, 1);
    GrainGlass.sphere(
      canvas,
      c + q * r,
      r * 0.14,
      t,
      a: spec.color,
      heat: 0.7,
      heatColor: Color.lerp(spec.color, Colors.white, 0.5)!,
      glow: 0.8,
      density: 0.5,
    );
  }

  // ── Linked Turrets: the orb, a glass core in the ward light, and two
  // lanes of shots — the ship turret's steel from above, the orb turret's
  // ward light from the core — meeting on one body.
  static const Offset _linkHit = Offset(0.46, -0.34);
  static const Offset _linkCore = Offset(-0.24, 0.3);
  static const Offset _linkShip = Offset(-0.62, -0.46);

  static void _linkedBolts(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    UpgradeArtSpec spec,
    int s,
  ) {
    GrainGlass.sphere(
      canvas,
      c + _linkCore * r,
      r * 0.27,
      t,
      a: spec.second ?? spec.color,
      glow: 0.6,
      spin: 0.4,
    );
    for (var lane = 0; lane < 2; lane++) {
      final fromOrb = lane == 1;
      final toward = _linkHit - (fromOrb ? _linkCore : _linkShip);
      final len = toward.distance;
      final dir = toward / len;
      final from = fromOrb ? _linkCore + dir * 0.3 : _linkShip;
      final run = fromOrb ? len - 0.3 : len;
      for (var b = 0; b < 3; b++) {
        final p = (t * 0.55 + b / 3 + lane * 0.17) % 1.0;
        final head = from + dir * (p * run);
        for (var j = 0; j < 6; j++) {
          final back = j * 0.045;
          if (back > p * run) break;
          final q = head - dir * back;
          _add(
            j == 0
                ? _hot
                : j < 2
                ? _lit
                : j < 4
                ? _body
                : _deep,
            q.dx,
            q.dy,
            second: fromOrb,
          );
        }
      }
    }
    // The ship's turret: a few steel grains where its lane starts.
    for (var i = 0; i < 6; i++) {
      final a = _h(i, 68 + s) * math.pi * 2;
      final rr = 0.02 + _h(i, 69 + s) * 0.05;
      _add(
        i < 2 ? _lit : _body,
        _linkShip.dx + math.cos(a) * rr,
        _linkShip.dy + math.sin(a) * rr,
      );
    }
    // The body both lanes land on: one knot in both lights.
    for (var i = 0; i < 16; i++) {
      final a = _h(i, 70 + s) * math.pi * 2 + t * 0.5;
      final rr = 0.02 + _h(i, 71 + s) * 0.08;
      _add(
        i < 6 ? _hot : _lit,
        _linkHit.dx + math.cos(a) * rr,
        _linkHit.dy + math.sin(a) * rr,
        second: i.isOdd,
      );
    }
    _add(_glint, _linkHit.dx, _linkHit.dy);
  }

  // ── Nova Pulse: the pulse's shell of grains round its core, breathing,
  // and the nova's gold breathed out through it in three uneven plumes that
  // curl as they drift and dim.
  static void _pulseNova(double t, int s) {
    final breathe = 0.5 + 0.035 * math.sin(t * 1.1);
    final spin = t * 0.25;
    for (var i = 0; i < 90; i++) {
      final lat = math.asin(2 * _h(i, 72 + s) - 1);
      final lon = _h(i, 73 + s) * math.pi * 2 + spin;
      final rr = breathe * (0.96 + 0.08 * _h(i, 74 + s));
      final x = rr * math.cos(lat) * math.cos(lon);
      final y = rr * math.sin(lat);
      final z = rr * math.cos(lat) * math.sin(lon);
      final light = (-0.5 * x - 0.55 * y + 0.65 * z) / rr;
      _add(
        z < 0
            ? _deep
            : light > 0.55
            ? _hot
            : light > 0.1
            ? _lit
            : _body,
        x,
        y,
      );
    }
    const plumes = [(-2.3, 24), (-0.5, 19), (1.3, 14)];
    for (var k = 0; k < plumes.length; k++) {
      final (angle, n) = plumes[k];
      for (var i = 0; i < n; i++) {
        final p = (t * 0.2 + i / n + _h(i + k * 40, 75 + s) * 0.35) % 1.0;
        final e = GrainGlass.smooth(p);
        final rr = breathe * 0.94 + e * 0.36;
        final a =
            angle +
            (_h(i + k * 40, 76 + s) - 0.5) * (0.3 + 0.45 * p) +
            0.45 * e;
        final x = math.cos(a) * rr, y = math.sin(a) * rr;
        if (x * x + y * y > 0.86) continue;
        _add(
          p < 0.22
              ? _hot
              : p < 0.5
              ? _lit
              : p < 0.78
              ? _body
              : _deep,
          x,
          y,
          second: true,
        );
      }
    }
  }

  // ── Tempered Field: the regeneration's green and the tempering's gold
  // rising off one pool as two strands that twist round each other and draw
  // together into one column, dimming as they rise.
  static void _risingBraid(double t, int s) {
    for (var strand = 0; strand < 2; strand++) {
      final gold = strand == 1;
      for (var i = 0; i < 56; i++) {
        final k = i + strand * 60;
        final p = (t * 0.16 + i / 56 + _h(k, 77 + s) * 0.015) % 1.0;
        final y = 0.5 - p * 1.24;
        final amp = 0.27 * (1 - 0.72 * p);
        final phase = p * math.pi * 2.3 - t * 0.7 + strand * math.pi;
        final over = math.cos(phase);
        final across = (_h(k, 78 + s) - 0.5) * 0.1 * (1 - 0.5 * p);
        final sway = math.sin(t * 0.5 + p * 2.2) * 0.04 * p;
        final x = amp * math.sin(phase) + across + sway;
        if (x * x + y * y > 0.84) continue;
        _add(
          p > 0.84
              ? _deep
              : over > 0.4
              ? (p < 0.4 ? _hot : _lit)
              : over > -0.35
              ? _body
              : _deep,
          x,
          y,
          second: gold,
        );
      }
    }
    // A few loose ones rising beside it, as off either parent's pool.
    for (var i = 0; i < 18; i++) {
      final p = (t * 0.2 + _h(i, 81 + s)) % 1.0;
      final side = i.isEven ? -1.0 : 1.0;
      final x =
          side * (0.3 + 0.14 * _h(i, 82 + s)) * (1 - 0.5 * p) +
          math.sin(t * 0.8 + i) * 0.03;
      final y = 0.46 - p * 1.0;
      if (x * x + y * y > 0.84) continue;
      _add(
        p < 0.25
            ? _lit
            : p < 0.6
            ? _body
            : _deep,
        x,
        y,
        second: i % 4 < 2,
      );
    }
    // The pool both rise from.
    for (var i = 0; i < 32; i++) {
      final u = _h(i, 79 + s) * 2 - 1;
      _add(
        i % 4 == 0 ? _lit : _body,
        u * 0.5,
        0.55 + _h(i, 80 + s) * 0.09 * (1 - u * u),
        second: i.isOdd,
      );
    }
  }
}
