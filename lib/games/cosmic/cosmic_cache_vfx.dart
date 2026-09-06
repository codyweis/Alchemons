// lib/games/cosmic/cosmic_cache_vfx.dart
//
// The artwork for sealed elemental caches: the dormant seal, and the
// three-second unsealing every element performs its own way — fire burns
// through it, ice shatters it, dark swallows it.
//
// Plain paint functions on purpose: the open-world game calls them from its
// render loop, and they can be exercised on any canvas without a game.

import 'dart:math';
import 'package:flutter/material.dart';

import 'cosmic_cache_data.dart';
import 'cosmic_data.dart';

/// The dormant construct: a slowly turning alchemical seal with an
/// element-flavoured core. Deliberately cheap — up to 17 of these exist.
void paintSealedCache(Canvas canvas, Offset p, String element, double life) {
  final c = elementColor(element);
  final t = life;
  const r = ElementalCache.visualRadius;
  final breathe = 0.5 + 0.5 * sin(t * 1.4);

  // Soft aura.
  canvas.drawCircle(
    p,
    r * 1.5,
    Paint()
      ..color = c.withValues(alpha: 0.10 + 0.05 * breathe)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
  );

  // Outer ring.
  canvas.drawCircle(
    p,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = c.withValues(alpha: 0.55),
  );

  // Counter-rotating inner ring with tick marks.
  canvas.save();
  canvas.translate(p.dx, p.dy);
  canvas.rotate(t * 0.35);
  final tickPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = c.withValues(alpha: 0.7);
  for (var i = 0; i < 8; i++) {
    final a = i * pi / 4;
    canvas.drawLine(
      Offset(cos(a) * (r * 0.72), sin(a) * (r * 0.72)),
      Offset(cos(a) * (r * 0.9), sin(a) * (r * 0.9)),
      tickPaint,
    );
  }
  canvas.restore();

  // Hexagram — the "sealed" glyph.
  canvas.save();
  canvas.translate(p.dx, p.dy);
  canvas.rotate(-t * 0.22);
  final glyph = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = c.withValues(alpha: 0.45);
  for (var tri = 0; tri < 2; tri++) {
    final path = Path();
    for (var i = 0; i < 3; i++) {
      final a = tri * pi / 3 + i * (pi * 2 / 3) - pi / 2;
      final v = Offset(cos(a) * r * 0.6, sin(a) * r * 0.6);
      if (i == 0) {
        path.moveTo(v.dx, v.dy);
      } else {
        path.lineTo(v.dx, v.dy);
      }
    }
    path.close();
    canvas.drawPath(path, glyph);
  }
  canvas.restore();

  // Element core.
  canvas.drawCircle(
    p,
    r * (0.20 + 0.05 * breathe),
    Paint()..color = c.withValues(alpha: 0.85),
  );
  canvas.drawCircle(
    p,
    r * 0.34,
    Paint()
      ..color = c.withValues(alpha: 0.30 * breathe)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
  );
}

/// Paint the unsealing of an [element] cache centred on [p].
///
/// [life] is the cache's free-running clock (drives idle wobble); [t] is the
/// 0 → 1 progress through the three-second ritual.
void paintCacheUnseal(
  Canvas canvas,
  Offset p,
  String element,
  double life,
  double t,
) {
  final c = elementColor(element);
  // Overlapping phases: the seal is already cracking while the element is
  // still pouring in, and the bloom starts before the crack finishes.
  final charge = (t / 0.35).clamp(0.0, 1.0);
  final crack = ((t - 0.30) / 0.45).clamp(0.0, 1.0);
  final bloom = ((t - 0.70) / 0.30).clamp(0.0, 1.0);

  _unsealAura(canvas, p, c, charge, bloom);
  _unsealSeal(canvas, p, c, life, crack);

  switch (element) {
    case 'Fire':
      _motifFire(canvas, p, c, t, charge, crack);
    case 'Lava':
      _motifLava(canvas, p, c, t, charge, crack);
    case 'Lightning':
      _motifLightning(canvas, p, c, t, charge, crack);
    case 'Water':
      _motifWater(canvas, p, c, t, charge, crack);
    case 'Ice':
      _motifIce(canvas, p, c, t, charge, crack);
    case 'Steam':
      _motifSteam(canvas, p, c, t, charge, crack);
    case 'Earth':
      _motifEarth(canvas, p, c, t, charge, crack);
    case 'Mud':
      _motifMud(canvas, p, c, t, charge, crack);
    case 'Dust':
      _motifDust(canvas, p, c, t, charge, crack);
    case 'Crystal':
      _motifCrystal(canvas, p, c, t, charge, crack);
    case 'Air':
      _motifAir(canvas, p, c, t, charge, crack);
    case 'Plant':
      _motifPlant(canvas, p, c, t, charge, crack);
    case 'Poison':
      _motifPoison(canvas, p, c, t, charge, crack);
    case 'Spirit':
      _motifSpirit(canvas, p, c, t, charge, crack);
    case 'Dark':
      _motifDark(canvas, p, c, t, charge, crack);
    case 'Light':
      _motifLight(canvas, p, c, t, charge, crack);
    case 'Blood':
      _motifBlood(canvas, p, c, t, charge, crack);
    default:
      _motifLight(canvas, p, c, t, charge, crack);
  }

  if (bloom > 0) _unsealBloom(canvas, p, c, bloom);
}

// ── shared scaffolding ────────────────────────────────

const double _r = ElementalCache.visualRadius;

/// Element light swelling under the seal, then flaring as it opens.
void _unsealAura(
  Canvas canvas,
  Offset p,
  Color c,
  double charge,
  double bloom,
) {
  final radius = _r * (1.3 + charge * 0.5 + bloom * 1.1);
  canvas.drawCircle(
    p,
    radius,
    Paint()
      ..color = c.withValues(alpha: 0.10 + charge * 0.15 + bloom * 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + bloom * 22),
  );
}

/// The seal itself: six arcs that spin up, then tear loose and drift away.
void _unsealSeal(Canvas canvas, Offset p, Color c, double life, double crack) {
  if (crack >= 1.0) return;
  final spin = life * (0.4 + crack * 8.0);
  final drift = crack * crack * 90.0;
  final alpha = (1.0 - crack).clamp(0.0, 1.0);

  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..color = c.withValues(alpha: 0.75 * alpha);

  for (var i = 0; i < 6; i++) {
    final a = spin + i * (pi / 3);
    final cx = p.dx + cos(a) * drift;
    final cy = p.dy + sin(a) * drift;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: _r),
      a - 0.32,
      0.52,
      false,
      paint,
    );
  }
}

/// Light pouring out of the opened cache — a widening throat plus rays.
void _unsealBloom(Canvas canvas, Offset p, Color c, double bloom) {
  final e = Curves.easeOutCubic.transform(bloom);

  // The throat opens white-hot, then cools back toward the element so the
  // motif is never buried under a featureless disc.
  final core = Color.lerp(Colors.white, c, e * 0.75)!;
  canvas.drawCircle(
    p,
    _r * 0.34 * (1 - e * 0.45),
    Paint()..color = core.withValues(alpha: 0.9 * (1 - e * 0.8)),
  );

  final rayPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 12; i++) {
    final a = i * (pi / 6) + e * 0.6;
    final inner = _r * 0.4;
    final outer = _r * (0.6 + e * 2.6) * (i.isEven ? 1.0 : 0.7);
    rayPaint.color = (i.isEven ? c : const Color(0xFFFFE082)).withValues(
      alpha: 0.75 * (1 - e * e),
    );
    canvas.drawLine(
      Offset(p.dx + cos(a) * inner, p.dy + sin(a) * inner),
      Offset(p.dx + cos(a) * outer, p.dy + sin(a) * outer),
      rayPaint,
    );
  }
}

Paint _fill(Color c, double a) => Paint()..color = c.withValues(alpha: a);

Paint _stroke(Color c, double a, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..color = c.withValues(alpha: a);

// ── FIRE — tongues of flame lick up and char the seal through ──
void _motifFire(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  for (var i = 0; i < 12; i++) {
    final a = i * (pi * 2 / 12) - pi / 2;
    final h = _r * (0.7 + charge * 1.5) * (0.6 + 0.4 * sin(t * 9 + i));
    final sway = sin(t * 7 + i * 1.3) * 8;
    final path = Path()
      ..moveTo(p.dx + cos(a) * _r * 0.3 - 7, p.dy + sin(a) * _r * 0.3)
      ..quadraticBezierTo(
        p.dx + cos(a) * h * 0.6 + sway,
        p.dy + sin(a) * h * 0.6,
        p.dx + cos(a) * h + sway,
        p.dy + sin(a) * h,
      )
      ..quadraticBezierTo(
        p.dx + cos(a) * h * 0.6 + sway + 6,
        p.dy + sin(a) * h * 0.6,
        p.dx + cos(a) * _r * 0.3 + 7,
        p.dy + sin(a) * _r * 0.3,
      )
      ..close();
    canvas.drawPath(path, _fill(i.isEven ? c : const Color(0xFFFFC107), 0.55));
  }
  // Embers riding the updraft rather than a flat hot disc.
  for (var i = 0; i < 8; i++) {
    final a = t * 1.3 + i * (pi * 2 / 8);
    final rr = _r * (0.5 + ((t * 0.7 + i * 0.12) % 1.0) * (1.2 + crack));
    canvas.drawCircle(
      Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr),
      1.6 + charge * 1.8,
      _fill(const Color(0xFFFFE0B2), 0.75 * charge),
    );
  }
}

// ── LAVA — the seal melts, molten strands sag and drip away ──
void _motifLava(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  for (var i = 0; i < 7; i++) {
    final a = i * (pi * 2 / 7) + t * 0.4;
    final drip = crack * (30 + i * 9) + sin(t * 3 + i) * 4;
    final x = p.dx + cos(a) * _r * 0.85;
    final y = p.dy + sin(a) * _r * 0.85;
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + drip),
      _stroke(c, 0.8 * (1 - crack * 0.4), 4),
    );
    canvas.drawCircle(
      Offset(x, y + drip),
      3.0 + charge * 2,
      _fill(const Color(0xFFFFAB40), 0.9),
    );
  }
  // Glowing fissures across the face of the seal.
  for (var i = 0; i < 4; i++) {
    final a = i * (pi / 4) + t * 0.2;
    canvas.drawLine(
      Offset(p.dx - cos(a) * _r * crack, p.dy - sin(a) * _r * crack),
      Offset(p.dx + cos(a) * _r * crack, p.dy + sin(a) * _r * crack),
      _stroke(const Color(0xFFFFD180), 0.85 * crack, 2.2),
    );
  }
}

// ── LIGHTNING — arcs crawl the rim, then one bolt splits it ──
void _motifLightning(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final rng = Random((t * 26).floor() * 7919);
  final paint = _stroke(c, 0.9, 2.0);
  for (var arc = 0; arc < 4; arc++) {
    final path = Path();
    final a0 = rng.nextDouble() * pi * 2;
    var x = p.dx + cos(a0) * _r;
    var y = p.dy + sin(a0) * _r;
    path.moveTo(x, y);
    for (var seg = 0; seg < 5; seg++) {
      x += (rng.nextDouble() - 0.5) * 34;
      y += (rng.nextDouble() - 0.5) * 34;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }
  if (crack > 0) {
    // The killing bolt, straight down through the middle.
    final path = Path()..moveTo(p.dx, p.dy - _r * 2.4);
    for (var seg = 1; seg <= 6; seg++) {
      path.lineTo(
        p.dx + (rng.nextDouble() - 0.5) * 26,
        p.dy - _r * 2.4 + seg * (_r * 4.8 / 6),
      );
    }
    canvas.drawPath(path, _stroke(const Color(0xFFFFFDE7), 0.95 * crack, 3.4));
  }
  // Charged core: a tight ring that jitters rather than a solid white disc.
  canvas.drawCircle(
    p,
    _r * (0.22 + 0.10 * sin(t * 30)) * charge,
    _stroke(Colors.white, 0.75 * charge, 2.4),
  );
}

// ── WATER — a vortex winds up and washes the seal away in rings ──
void _motifWater(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  for (var arm = 0; arm < 3; arm++) {
    final path = Path();
    for (var i = 0; i <= 16; i++) {
      final f = i / 16;
      final a = arm * (pi * 2 / 3) + t * 3.2 + f * pi * 1.8;
      final rr = _r * (1.5 - f * 1.2) * (0.6 + charge * 0.6);
      final pt = Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, _stroke(c, 0.65, 3));
  }
  for (var i = 0; i < 3; i++) {
    final rr = _r * (0.4 + ((crack * 2.2) + i * 0.35) % 2.2);
    canvas.drawCircle(p, rr, _stroke(const Color(0xFF80D8FF), 0.5 * crack, 2));
  }
}

// ── ICE — frost crystals creep over the seal, then it shatters ──
void _motifIce(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final grow = charge;
  final spike = _stroke(c, 0.8, 2.2);
  for (var i = 0; i < 6; i++) {
    final a = i * (pi / 3) + t * 0.15;
    final tip = Offset(
      p.dx + cos(a) * _r * 1.5 * grow,
      p.dy + sin(a) * _r * 1.5 * grow,
    );
    canvas.drawLine(p, tip, spike);
    // Barbs.
    for (final s in [-1.0, 1.0]) {
      final ba = a + s * 0.6;
      final base = Offset(
        p.dx + cos(a) * _r * 0.9 * grow,
        p.dy + sin(a) * _r * 0.9 * grow,
      );
      canvas.drawLine(
        base,
        Offset(base.dx + cos(ba) * 16 * grow, base.dy + sin(ba) * 16 * grow),
        spike,
      );
    }
  }
  if (crack > 0) {
    final rng = Random(4242);
    for (var i = 0; i < 12; i++) {
      final a = rng.nextDouble() * pi * 2;
      final d = crack * (40 + rng.nextDouble() * 90);
      final sp = Offset(p.dx + cos(a) * d, p.dy + sin(a) * d);
      final path = Path()
        ..moveTo(sp.dx, sp.dy)
        ..lineTo(sp.dx + 7, sp.dy + 3)
        ..lineTo(sp.dx + 2, sp.dy + 10)
        ..close();
      canvas.drawPath(path, _fill(const Color(0xFFB3E5FC), 0.8 * (1 - crack)));
    }
  }
}

// ── STEAM — pressure jets vent from the seams, then a whiteout ──
void _motifSteam(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  for (var i = 0; i < 8; i++) {
    final a = i * (pi / 4);
    final len = _r * (0.6 + charge * 1.6) * (0.5 + 0.5 * sin(t * 8 + i * 2));
    canvas.drawLine(
      Offset(p.dx + cos(a) * _r * 0.7, p.dy + sin(a) * _r * 0.7),
      Offset(
        p.dx + cos(a) * (_r * 0.7 + len),
        p.dy + sin(a) * (_r * 0.7 + len),
      ),
      _stroke(const Color(0xFFECEFF1), 0.55, 6),
    );
  }
  for (var i = 0; i < 6; i++) {
    final a = t * 1.4 + i * (pi / 3);
    final rr = _r * (0.8 + crack * 1.4);
    canvas.drawCircle(
      Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr),
      10 + crack * 16,
      Paint()
        ..color = c.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
  if (crack > 0.5) {
    canvas.drawCircle(
      p,
      _r * 2.2 * crack,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * crack)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }
}

// ── EARTH — stone plates grind apart, dust puffing from the gap ──
void _motifEarth(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final open = Curves.easeInOutCubic.transform(crack) * _r * 1.1;
  for (var i = 0; i < 4; i++) {
    final a = i * (pi / 2) + pi / 4;
    final cx = p.dx + cos(a) * open;
    final cy = p.dy + sin(a) * open;
    final path = Path()
      ..moveTo(cx, cy - _r * 0.55)
      ..lineTo(cx + _r * 0.5, cy - _r * 0.15)
      ..lineTo(cx + _r * 0.32, cy + _r * 0.5)
      ..lineTo(cx - _r * 0.34, cy + _r * 0.46)
      ..lineTo(cx - _r * 0.52, cy - _r * 0.12)
      ..close();
    canvas.drawPath(path, _fill(c, 0.72));
    canvas.drawPath(path, _stroke(const Color(0xFFD7CCC8), 0.5, 1.4));
  }
  canvas.drawCircle(
    p,
    _r * 0.5 * charge,
    Paint()
      ..color = const Color(0xFFFFCC80).withValues(alpha: 0.3 * charge)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
  );
}

// ── MUD — the seal sinks into a churning, bubbling mire ──
void _motifMud(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final pool = _r * (0.8 + charge * 0.8);
  canvas.drawOval(
    Rect.fromCenter(center: p, width: pool * 2.4, height: pool * 1.3),
    _fill(c, 0.6),
  );
  for (var i = 0; i < 9; i++) {
    final phase = (t * 1.6 + i * 0.7) % 1.0;
    final a = i * (pi * 2 / 9);
    final bx = p.dx + cos(a) * pool * 0.8;
    final by = p.dy + sin(a) * pool * 0.4 - phase * 16;
    canvas.drawCircle(
      Offset(bx, by),
      (1 - phase) * (4 + charge * 4),
      _fill(const Color(0xFF8D6E63), 0.7 * (1 - phase)),
    );
  }
  // The seal going under: it tips, shrinks, and the mire closes over it.
  final sink = Curves.easeInCubic.transform(crack);
  canvas.save();
  canvas.translate(p.dx, p.dy + sink * 30);
  canvas.scale(1.0, (1 - sink * 0.8).clamp(0.15, 1.0));
  canvas.drawCircle(
    Offset.zero,
    _r * 0.62 * (1 - sink * 0.4),
    _stroke(const Color(0xFFD7CCC8), 0.75 * (1 - sink), 2.6),
  );
  canvas.restore();

  // Rings spreading from where it went down.
  for (var i = 0; i < 3; i++) {
    final f = ((sink * 1.6 + i * 0.33) % 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx, p.dy + sink * 30),
        width: _r * 2.2 * f,
        height: _r * 1.1 * f,
      ),
      _stroke(const Color(0xFFA1887F), 0.45 * (1 - f) * sink, 2),
    );
  }
}

// ── DUST — the seal erodes grain by grain into a spiralling drift ──
void _motifDust(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final rng = Random(9001);
  for (var i = 0; i < 40; i++) {
    final base = rng.nextDouble() * pi * 2;
    final a = base + t * (0.8 + rng.nextDouble());
    final rr = _r * (0.3 + rng.nextDouble() * 1.2) * (1 + crack * 1.4);
    canvas.drawCircle(
      Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr * 0.75),
      1.0 + rng.nextDouble() * 1.8,
      _fill(c, 0.35 + 0.4 * charge),
    );
  }
  canvas.drawCircle(
    p,
    _r * 0.7 * (1 - crack),
    _stroke(c, 0.5 * (1 - crack), 2),
  );
}

// ── CRYSTAL — a lattice grows, resonates, then the facets fly apart ──
void _motifCrystal(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final facet = _stroke(c, 0.85, 1.8);
  for (var i = 0; i < 6; i++) {
    final a = i * (pi / 3) + t * 0.3;
    final d = crack * 70;
    final cx = p.dx + cos(a) * (_r * 0.55 + d);
    final cy = p.dy + sin(a) * (_r * 0.55 + d);
    final s = _r * 0.34 * (0.5 + charge * 0.5);
    final path = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + s * 0.7, cy)
      ..lineTo(cx, cy + s)
      ..lineTo(cx - s * 0.7, cy)
      ..close();
    canvas.drawPath(path, _fill(c, 0.28));
    canvas.drawPath(path, facet);
  }
  // Resonance rings.
  for (var i = 0; i < 2; i++) {
    final rr = _r * (0.6 + ((t * 1.3 + i * 0.5) % 1.0) * 1.8);
    canvas.drawCircle(
      p,
      rr,
      _stroke(const Color(0xFFA7FFEB), 0.4 * charge, 1.4),
    );
  }
}

// ── AIR — spiral streaks unwind the seal like a ribbon ──
void _motifAir(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  // Four gusts sweep left-to-right across the seal, each a long shallow arc
  // with a chevron riding its leading edge.
  for (var g = 0; g < 4; g++) {
    final travel = ((t * 0.55 + g * 0.25) % 1.0);
    final y = p.dy + (g - 1.5) * _r * 0.52;
    final x0 = p.dx - _r * 2.2 + travel * _r * 2.6;
    final len = _r * (1.1 + charge * 1.1);
    final bow = sin(travel * pi) * _r * 0.22 * (g.isEven ? 1 : -1);

    final path = Path()
      ..moveTo(x0, y)
      ..quadraticBezierTo(x0 + len * 0.5, y + bow, x0 + len, y);
    canvas.drawPath(
      path,
      _stroke(c, (0.30 + 0.5 * charge) * sin(travel * pi), 2.6),
    );

    // Chevron at the leading edge.
    final tip = Offset(x0 + len, y);
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - 9, tip.dy - 7)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - 9, tip.dy + 7),
      _stroke(Colors.white, 0.5 * sin(travel * pi), 2),
    );
  }

  // The seal itself gets blown apart into tumbling fragments.
  for (var i = 0; i < 6; i++) {
    final a = i * (pi / 3) + t * 0.8;
    final d = crack * (30 + i * 12);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(p.dx + cos(a) * d, p.dy + sin(a) * d - crack * 18),
        radius: _r * 0.42,
      ),
      a,
      0.7,
      false,
      _stroke(c, 0.6 * (1 - crack), 2),
    );
  }
}

// ── PLANT — vines coil around the seal and pry it open into a bloom ──
void _motifPlant(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  for (var v = 0; v < 5; v++) {
    final path = Path();
    final base = v * (pi * 2 / 5);
    final grow = charge;
    for (var i = 0; i <= 14; i++) {
      final f = i / 14;
      final a = base + f * 3.4 * grow;
      final rr = _r * (0.3 + f * 1.5 * grow);
      final pt = Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, _stroke(c, 0.8, 2.6));
  }
  // Petals opening as the seal gives.
  final petals = _fill(const Color(0xFF9CCC65), 0.6 * crack);
  for (var i = 0; i < 8; i++) {
    final a = i * (pi / 4) + t * 0.3;
    final d = _r * (0.35 + crack * 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(p.dx + cos(a) * d, p.dy + sin(a) * d),
        width: 16 * crack + 4,
        height: 9 * crack + 3,
      ),
      petals,
    );
  }
}

// ── POISON — corrosive bubbles eat through the seal ──
void _motifPoison(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final rng = Random(1337);
  for (var i = 0; i < 16; i++) {
    final a = rng.nextDouble() * pi * 2;
    final phase = ((t * 0.8) + rng.nextDouble()) % 1.0;
    final rr = _r * (0.3 + phase * 1.5);
    final bubble = (4 + rng.nextDouble() * 7) * (1 - phase * 0.6);
    canvas.drawCircle(
      Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr),
      bubble,
      _fill(c, 0.5 * (1 - phase) + 0.2 * charge),
    );
    canvas.drawCircle(
      Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr),
      bubble,
      _stroke(const Color(0xFFCE93D8), 0.45 * (1 - phase), 1.2),
    );
  }
  // Holes burnt through.
  canvas.drawCircle(p, _r * 0.6 * crack, _fill(Colors.black, 0.5 * crack));
}

// ── SPIRIT — wisps orbit, phase the seal out of the world ──
void _motifSpirit(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  const pale = Color(0xFFC5CAE9);

  // Seven wisps on a slow elliptical orbit, each dragging a comet tail.
  for (var i = 0; i < 7; i++) {
    final a = t * 1.6 + i * (pi * 2 / 7);
    final rr = _r * (1.0 + 0.35 * sin(t * 2 + i)) * (1 + crack * 0.6);
    final wp = Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr * 0.72);

    final tail = Path()..moveTo(wp.dx, wp.dy);
    for (var seg = 1; seg <= 4; seg++) {
      final ta = a - seg * 0.26;
      final tr = rr * (1 - seg * 0.03);
      tail.lineTo(p.dx + cos(ta) * tr, p.dy + sin(ta) * tr * 0.72);
    }
    canvas.drawPath(tail, _stroke(pale, 0.45 + 0.3 * charge, 2.4));

    canvas.drawCircle(
      wp,
      6 + charge * 5,
      Paint()
        ..color = c.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(wp, 3.0, _fill(Colors.white, 0.95));
  }

  // The seal loses its grip on one reality and slides toward another.
  for (var g = 1; g <= 3; g++) {
    canvas.drawCircle(
      Offset(p.dx + g * 11 * crack, p.dy - g * 6 * crack),
      _r * (1 - crack * 0.35),
      _stroke(pale, 0.5 * (1 - crack) / g, 2.0),
    );
  }

  // A veil pulling off the front.
  if (crack > 0) {
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: _r * (1 + crack * 0.7)),
      -pi * 0.75 + crack,
      pi * 1.1,
      false,
      _stroke(Colors.white, 0.6 * (1 - crack), 3.0),
    );
  }
}

// ── DARK — a void swallows the seal, then collapses inward ──
void _motifDark(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  final void_ = _r * (0.4 + charge * 1.1) * (1 - crack * 0.7);
  canvas.drawCircle(p, void_, _fill(Colors.black, 0.88));
  canvas.drawCircle(p, void_, _stroke(const Color(0xFFB388FF), 0.7, 2.2));
  // Matter falling in.
  for (var i = 0; i < 10; i++) {
    final a = t * 2.4 + i * (pi * 2 / 10);
    final f = ((t * 0.9 + i * 0.1) % 1.0);
    final rr = _r * 2.0 * (1 - f);
    canvas.drawCircle(
      Offset(p.dx + cos(a) * rr, p.dy + sin(a) * rr),
      2 + f * 2,
      _fill(c, 0.6 * f + 0.2),
    );
  }
  if (crack > 0.6) {
    canvas.drawCircle(
      p,
      _r * 2.4 * (crack - 0.6) / 0.4,
      _stroke(const Color(0xFFEDE7F6), 0.5 * (1 - crack), 2),
    );
  }
}

// ── LIGHT — a prism splits a beam, dawn breaks the seal ──
void _motifLight(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  const spectrum = [
    Color(0xFFFF5252),
    Color(0xFFFFD740),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFB388FF),
  ];
  for (var i = 0; i < spectrum.length; i++) {
    final a = -0.5 + i * 0.25 + sin(t * 1.2) * 0.1;
    final len = _r * (1.2 + crack * 2.4);
    canvas.drawLine(
      p,
      Offset(p.dx + cos(a) * len, p.dy + sin(a) * len),
      _stroke(spectrum[i], 0.6 * charge, 3.2),
    );
  }
  // Rotating halo.
  canvas.drawCircle(
    p,
    _r * (0.8 + charge * 0.5),
    _stroke(c, 0.7, 2.4 + crack * 3),
  );
  canvas.drawCircle(p, _r * 0.3, _fill(Colors.white, 0.5 + 0.4 * charge));
}

// ── BLOOD — heartbeat rings, then the seal splits along a vein ──
void _motifBlood(
  Canvas canvas,
  Offset p,
  Color c,
  double t,
  double charge,
  double crack,
) {
  // Two-thump cardiac rhythm.
  final beat = (t * 2.4) % 1.0;
  final thump = beat < 0.12
      ? beat / 0.12
      : (beat < 0.3 ? 1 - (beat - 0.12) / 0.18 : 0.0);
  canvas.drawCircle(
    p,
    _r * (0.7 + thump * 0.5 + charge * 0.3),
    _stroke(c, 0.8, 3),
  );
  canvas.drawCircle(
    p,
    _r * (0.4 + thump * 0.25),
    _fill(const Color(0xFFB71C1C), 0.6),
  );
  // Veins spreading out and tearing the seal.
  for (var i = 0; i < 6; i++) {
    final a = i * (pi / 3) + 0.3;
    final path = Path()..moveTo(p.dx, p.dy);
    var x = p.dx;
    var y = p.dy;
    for (var seg = 1; seg <= 3; seg++) {
      x += cos(a + sin(seg * 2.0) * 0.4) * _r * 0.45 * charge;
      y += sin(a + sin(seg * 2.0) * 0.4) * _r * 0.45 * charge;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, _stroke(const Color(0xFFEF9A9A), 0.65, 2));
  }
  if (crack > 0) {
    canvas.drawLine(
      Offset(p.dx, p.dy - _r * 1.6 * crack),
      Offset(p.dx, p.dy + _r * 1.6 * crack),
      _stroke(const Color(0xFFFFCDD2), 0.8 * crack, 3),
    );
  }
}
