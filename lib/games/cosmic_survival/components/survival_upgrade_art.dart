// lib/games/cosmic_survival/components/survival_upgrade_art.dart
//
// Each survival upgrade drawn as grains in its own light, in the game's
// grain-glass language (grain_glass.dart): points in batches and radial
// pools, no strokes, no blur. One formation per kind of thing an upgrade
// does — a heap for Strength, streaks for Speed, a turning lattice for
// Intelligence, a bloom for Beauty, a fan for Spread Shot, a comet for the
// rockets, a shell for the pulse, grains rising for healing, a burst for the
// nova, a chain for Chain Lightning, brass grains drawn in to one point for
// the Surge Magnet, two ember currents braided into one surge for Warpath —
// so three cards never look alike. Keyed by id.
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
    'surge_magnet' => const UpgradeArtSpec(UpgradeMotif.magnet, _brass),
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
}
