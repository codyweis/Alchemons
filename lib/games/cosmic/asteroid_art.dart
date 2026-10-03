// lib/games/cosmic/asteroid_art.dart
//
// The asteroid belt: chunks of near-black stone lit only by the key light,
// in the language of the stations (obsidian_kit.dart), and a thin dust of
// grains through the belt so it reads as a place, not scattered pebbles.
//
// Every rock is one sprite out of a single atlas — three cuts of stone,
// each baked at twelve turns so its light stays put in the world as it
// spins — and the whole belt is one drawAtlas call.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'cosmic_data.dart';
import 'obsidian_kit.dart';

/// The stone: a warm grey that keeps near black until the light finds it.
final StoneLight _rock = StoneLight(const Color(0xFFE6CFAE), warm: 0.07);

const int _cuts = 3;
const int _turns = 12;

/// Each cell holds a rock of this radius (in world units), with room.
const double _unit = 18;
const double _cell = 44;
const double _ppu = 4;

/// The three cuts of stone: irregular outlines, fixed per cut.
List<Offset> _outline(int cut) {
  final verts = 7 + cut;
  return [
    for (var i = 0; i < verts; i++)
      polar(
        _unit * (0.72 + 0.28 * hash01(i + cut * 17, 41)),
        i * 2 * pi / verts + (hash01(i + cut * 17, 42) - 0.5) * 0.5,
      ),
  ];
}

ui.Image? _atlas;

ui.Image _bake() {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.scale(_ppu);
  for (var cut = 0; cut < _cuts; cut++) {
    final gem = CutStone.gem(
      _rock,
      _outline(cut),
      Offset(-_unit * 0.22, -_unit * 0.18),
    );
    for (var k = 0; k < _turns; k++) {
      c.save();
      c.translate(k * _cell + _cell / 2, cut * _cell + _cell / 2);
      gem.paint(c, k * 2 * pi / _turns, glow: 0);
      c.restore();
    }
  }
  final pic = rec.endRecording();
  final img = pic.toImageSync(
    (_turns * _cell * _ppu).ceil(),
    (_cuts * _cell * _ppu).ceil(),
  );
  pic.dispose();
  return img;
}

final Paint _atlasPaint = Paint()
  ..filterQuality = FilterQuality.medium
  ..isAntiAlias = true;
Float32List _xforms = Float32List(0);
Float32List _rects = Float32List(0);
Int32List _colors = Int32List(0);

final PointBatch _dust = PointBatch(700);
final PointBatch _dustLit = PointBatch(160);

/// The belt's rocks and dust inside [view] (world units), at [elapsed].
void paintAsteroidBelt(
  Canvas c,
  AsteroidBelt belt, {
  required Rect view,
  required double elapsed,
}) {
  _paintDust(c, belt, view, elapsed);

  final img = _atlas ??= _bake();
  final rocks = belt.asteroids;
  if (_xforms.length < rocks.length * 4) {
    _xforms = Float32List(rocks.length * 4);
    _rects = Float32List(rocks.length * 4);
    _colors = Int32List(rocks.length);
  }
  final margin = view.inflate(24);
  var n = 0;
  const px = _cell * _ppu;
  for (final rock in rocks) {
    if (rock.destroyed || !margin.contains(rock.position)) continue;
    final spin = rock.rotation + elapsed * rock.rotSpeed;
    final k = ((spin / (2 * pi) * _turns).round() % _turns + _turns) % _turns;
    final cut = rock.shape % _cuts;
    // The sprite turns with the rock; the bake chosen for its turn keeps the
    // light where it belongs.
    final scale = rock.radius / _unit / _ppu;
    final cosA = cos(spin) * scale, sinA = sin(spin) * scale;
    const anchor = px / 2;
    _xforms[n * 4] = cosA;
    _xforms[n * 4 + 1] = sinA;
    _xforms[n * 4 + 2] = rock.position.dx - cosA * anchor + sinA * anchor;
    _xforms[n * 4 + 3] = rock.position.dy - sinA * anchor - cosA * anchor;
    _rects[n * 4] = k * px;
    _rects[n * 4 + 1] = cut * px;
    _rects[n * 4 + 2] = k * px + px;
    _rects[n * 4 + 3] = cut * px + px;
    // A battered rock loses its light.
    final lit = (110 + 145 * rock.health.clamp(0.0, 1.0)).round();
    _colors[n] = 0xFF000000 | (lit << 16) | (lit << 8) | lit;
    n++;
  }
  if (n == 0) return;
  c.drawRawAtlas(
    img,
    Float32List.sublistView(_xforms, 0, n * 4),
    Float32List.sublistView(_rects, 0, n * 4),
    Int32List.sublistView(_colors, 0, n),
    BlendMode.modulate,
    null,
    _atlasPaint,
  );
}

/// Dust through the belt: a few grains to each 220-unit cell of the
/// annulus, hashed from the cell so they stay put, drifting slowly.
void _paintDust(Canvas c, AsteroidBelt belt, Rect view, double elapsed) {
  const cell = 220.0;
  _dust.clear();
  _dustLit.clear();
  final x0 = (view.left / cell).floor(), x1 = (view.right / cell).ceil();
  final y0 = (view.top / cell).floor(), y1 = (view.bottom / cell).ceil();
  final inner = belt.innerRadius - 200, outer = belt.outerRadius + 200;
  final mid = (inner + outer) / 2, half = (outer - inner) / 2;
  for (var gx = x0; gx < x1; gx++) {
    for (var gy = y0; gy < y1; gy++) {
      final centre = Offset((gx + 0.5) * cell, (gy + 0.5) * cell);
      final d = (centre - belt.center).distance;
      if (d < inner || d > outer) continue;
      // Thickest along the middle of the belt.
      final density = 1 - pow((d - mid).abs() / half, 2).toDouble();
      final count = (14 * density).round();
      final seed = gx * 7919 + gy * 104729;
      for (var i = 0; i < count; i++) {
        final s = seed + i * 31;
        final drift = elapsed * (2 + 3 * hash01(s, 3));
        final x = (gx + hash01(s, 1)) * cell + drift;
        final y = (gy + hash01(s, 2)) * cell + drift * 0.4;
        (hash01(s, 4) < 0.12 ? _dustLit : _dust).add(x, y);
      }
    }
  }
  _dust.draw(c, 1.8, _rock.grainDim.withValues(alpha: 0.5));
  _dustLit.draw(c, 2.4, _rock.grainHot.withValues(alpha: 0.7));
}
