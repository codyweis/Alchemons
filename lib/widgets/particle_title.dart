// ─────────────────────────────────────────────────────────────────────────────
//  THE TITLE, IN PARTICLES
//
//  The "Alchemons" logo on the home screen, built from a few thousand grains
//  sampled out of the logo image itself — each sits where a piece of the
//  lettering was and takes that piece's color. At launch they stream in and
//  settle letter by letter. Once settled they hold still and twinkle.
//
//  Touch it:
//    · drag through it and the grains stir round your finger and glint, then
//      spring back — the way Cindrath's ring stirs round the ship;
//    · tap it and a shockwave runs out through the letters;
//    · hold it to choose what it is made of. Choose Void and it is black
//      matter with a violet glow, and your finger becomes a small black hole:
//      grains are pulled into orbit round it, and a tap implodes and rebounds.
//
//  Cheap by construction: positions in typed arrays, every grain drawn by a
//  handful of batched point draws, no blur, and when nothing is moving the
//  resting letters are drawn from cached batches with only the twinkles
//  worked out per frame. The ticker stops when the home tab is not showing.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the title can be made of. [original] keeps the logo's own colors;
/// [isVoid] is black matter and changes what touch does.
class TitleHue {
  const TitleHue(this.id, this.label, this.swatch, this.dark, this.light);

  final String id;
  final String label;
  final Color swatch;

  /// The shades the logo's tones are mapped onto, darkest to lightest.
  final Color dark, light;

  bool get original => id == 'original';
  bool get isVoid => id == 'void';
}

/// The logo's own colors.
const TitleHue kGoldTitleHue = TitleHue(
  'original',
  'Gold',
  Color(0xFFF2C75C),
  Color(0xFFB8762A),
  Color(0xFFFFF4C8),
);

const List<TitleHue> kTitleHues = [
  kGoldTitleHue,
  TitleHue(
    'ember',
    'Ember',
    Color(0xFFFF7A2E),
    Color(0xFF8A2A08),
    Color(0xFFFFD27A),
  ),
  TitleHue(
    'crimson',
    'Crimson',
    Color(0xFFE0343E),
    Color(0xFF5A0816),
    Color(0xFFFFA0A0),
  ),
  TitleHue(
    'violet',
    'Violet',
    Color(0xFF9A5AF0),
    Color(0xFF3A1470),
    Color(0xFFE8C8FF),
  ),
  TitleHue(
    'azure',
    'Azure',
    Color(0xFF3C88F0),
    Color(0xFF14286E),
    Color(0xFFCDEBFF),
  ),
  TitleHue(
    'verdigris',
    'Verdigris',
    Color(0xFF2EC8B8),
    Color(0xFF0A4A4A),
    Color(0xFFC8FFF4),
  ),
  TitleHue(
    'emerald',
    'Emerald',
    Color(0xFF2EC88C),
    Color(0xFF0A4A34),
    Color(0xFFD0FFE4),
  ),
  TitleHue(
    'pearl',
    'Pearl',
    Color(0xFFEDEDF5),
    Color(0xFF7A7A8C),
    Color(0xFFFFFFFF),
  ),
  TitleHue(
    'void',
    'Void',
    Color(0xFF0A0014),
    Color(0xFF030008),
    Color(0xFF1A0B2E),
  ),
];

TitleHue titleHue(String? id) =>
    kTitleHues.firstWhere((h) => h.id == id, orElse: () => kTitleHues.first);

// ── the samples ─────────────────────────────────────────────────────────────

/// The lettering the title's grains are read from (the dock's home emblem
/// reads its A from it too).
const String kTitleAsset = 'assets/images/ui/alchemonstitle.png';

/// The logo, read into grains: where each sits (in the 300×60 box the logo
/// always occupied), its color tone, and which letter it belongs to.
class TitleSamples {
  TitleSamples._(
    this.hx,
    this.hy,
    this.tone,
    this.tones,
    this.letter,
    this.edge,
  );

  /// The box the title is laid out in, as the image used to be shown.
  static const Size box = Size(300, 60);

  /// Number of color tones the logo is sorted into, darkest first.
  static const int toneCount = 10;

  final Float32List hx, hy;
  final Uint8List tone;
  final List<Color> tones;
  final Uint8List letter;

  /// 1 for grains on the outline of the lettering, 0 inside it.
  final Uint8List edge;

  int get length => hx.length;

  static final Map<String, Future<TitleSamples>> _cache = {};

  /// The samples for [asset], decoded and read once per run.
  static Future<TitleSamples> of(String asset) =>
      _cache.putIfAbsent(asset, () async {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final image = (await codec.getNextFrame()).image;
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        final samples = fromRgba(
          bytes!.buffer.asUint8List(),
          image.width,
          image.height,
        );
        image.dispose();
        return samples;
      });

  // Where the letters fall, in the 1024-pixel source (measured off it).
  static const _letterEdges = [232.0, 312, 410, 500, 590, 685, 758, 840];

  /// Reads the lettering out of straight-alpha RGBA pixels of the logo.
  static TitleSamples fromRgba(Uint8List rgba, int w, int h) {
    final k = w / 1024;
    // The image was shown 300 wide; its middle 60 rows made the band.
    final scale = box.width / w;
    final top = 409.6 * k;
    const step = 4.0;
    final rng = Random(7);
    final xs = <double>[], ys = <double>[];
    final rs = <double>[], gs = <double>[], bs = <double>[];
    final letters = <int>[];
    for (var sy = 396.0 * k; sy < 640 * k; sy += step * k) {
      for (var sx = 56.0 * k; sx < 966 * k; sx += step * k) {
        final px = (sx + (rng.nextDouble() - 0.5) * 2.4 * k)
            .clamp(0, w - 1)
            .toInt();
        final py = (sy + (rng.nextDouble() - 0.5) * 2.4 * k)
            .clamp(0, h - 1)
            .toInt();
        final o = (py * w + px) * 4;
        if (rgba[o + 3] < 140) continue;
        xs.add(px * scale);
        ys.add((py - top) * scale);
        rs.add(rgba[o].toDouble());
        gs.add(rgba[o + 1].toDouble());
        bs.add(rgba[o + 2].toDouble());
        var l = 0;
        while (l < _letterEdges.length && px / k > _letterEdges[l]) {
          l++;
        }
        letters.add(l);
      }
    }
    final n = xs.length;

    // Sort the colors into tones: a few rounds of k-means, seeded across
    // the range of brightness, then numbered dark to light.
    double lum(int i) => 0.3 * rs[i] + 0.59 * gs[i] + 0.11 * bs[i];
    final order = List.generate(n, (i) => i)
      ..sort((a, b) => lum(a).compareTo(lum(b)));
    final cr = List<double>.generate(
      toneCount,
      (c) => rs[order[((c + 0.5) / toneCount * n).floor().clamp(0, n - 1)]],
    );
    final cg = List<double>.generate(
      toneCount,
      (c) => gs[order[((c + 0.5) / toneCount * n).floor().clamp(0, n - 1)]],
    );
    final cb = List<double>.generate(
      toneCount,
      (c) => bs[order[((c + 0.5) / toneCount * n).floor().clamp(0, n - 1)]],
    );
    final assign = Uint8List(n);
    for (var round = 0; round < 6; round++) {
      final sr = List.filled(toneCount, 0.0), sg = List.filled(toneCount, 0.0);
      final sb = List.filled(toneCount, 0.0), sn = List.filled(toneCount, 0);
      for (var i = 0; i < n; i++) {
        var best = 0;
        var bestD = double.infinity;
        for (var c = 0; c < toneCount; c++) {
          final dr = rs[i] - cr[c], dg = gs[i] - cg[c], db = bs[i] - cb[c];
          final d = dr * dr + dg * dg + db * db;
          if (d < bestD) {
            bestD = d;
            best = c;
          }
        }
        assign[i] = best;
        sr[best] += rs[i];
        sg[best] += gs[i];
        sb[best] += bs[i];
        sn[best]++;
      }
      for (var c = 0; c < toneCount; c++) {
        if (sn[c] == 0) continue;
        cr[c] = sr[c] / sn[c];
        cg[c] = sg[c] / sn[c];
        cb[c] = sb[c] / sn[c];
      }
    }
    final byLum = List.generate(toneCount, (c) => c)
      ..sort(
        (a, b) => (0.3 * cr[a] + 0.59 * cg[a] + 0.11 * cb[a]).compareTo(
          0.3 * cr[b] + 0.59 * cg[b] + 0.11 * cb[b],
        ),
      );
    final rank = List.filled(toneCount, 0);
    for (var r = 0; r < toneCount; r++) {
      rank[byLum[r]] = r;
    }
    final tone = Uint8List(n);
    for (var i = 0; i < n; i++) {
      tone[i] = rank[assign[i]];
    }
    final tones = [
      for (final c in byLum)
        Color.fromARGB(
          255,
          cr[c].round().clamp(0, 255),
          cg[c].round().clamp(0, 255),
          cb[c].round().clamp(0, 255),
        ),
    ];
    return TitleSamples._(
      Float32List.fromList(xs),
      Float32List.fromList(ys),
      tone,
      tones,
      Uint8List.fromList(letters),
      _edges(xs, ys),
    );
  }

  /// Which grains lie on the outline: those with markedly fewer neighbours
  /// than a grain inside a stroke has.
  static Uint8List _edges(List<double> xs, List<double> ys) {
    final n = xs.length;
    const cell = 2.4, reach2 = 2.4 * 2.4;
    final grid = <int, List<int>>{};
    int key(int cx, int cy) => cx * 100003 + cy;
    for (var i = 0; i < n; i++) {
      grid
          .putIfAbsent(
            key((xs[i] / cell).floor(), (ys[i] / cell).floor()),
            () => [],
          )
          .add(i);
    }
    final count = Int32List(n);
    for (var i = 0; i < n; i++) {
      final cx = (xs[i] / cell).floor(), cy = (ys[i] / cell).floor();
      var c = 0;
      for (var gx = cx - 1; gx <= cx + 1; gx++) {
        for (var gy = cy - 1; gy <= cy + 1; gy++) {
          for (final j in grid[key(gx, gy)] ?? const <int>[]) {
            final dx = xs[j] - xs[i], dy = ys[j] - ys[i];
            if (dx * dx + dy * dy <= reach2) c++;
          }
        }
      }
      count[i] = c;
    }
    final sorted = List<int>.from(count)..sort();
    final full = sorted[(n * 0.8).floor().clamp(0, n - 1)];
    return Uint8List.fromList([
      for (var i = 0; i < n; i++) count[i] < full * 0.7 ? 1 : 0,
    ]);
  }
}

// ── the field ───────────────────────────────────────────────────────────────

/// A wave set off by a tap: where, when, and whether it pulls (Void) or
/// pushes.
class _Wave {
  _Wave(this.x, this.y, this.t0, this.implode);
  final double x, y, t0;
  final bool implode;
}

/// The grains and their motion. Plain Dart: the widget drives it, and a
/// test can too.
class TitleParticleField {
  TitleParticleField(this.samples, {TitleHue hue = kGoldTitleHue})
    : n = samples.length,
      x = Float32List.fromList(samples.hx),
      y = Float32List.fromList(samples.hy),
      vx = Float32List(samples.length),
      vy = Float32List(samples.length),
      heat = Float32List(samples.length),
      release = Float32List(samples.length),
      _arrived = Uint8List(samples.length),
      phase = Float32List(samples.length),
      _hue = hue,
      _oldHue = hue {
    final rng = Random(11);
    for (var i = 0; i < n; i++) {
      phase[i] = rng.nextDouble();
    }
  }

  final TitleSamples samples;
  final int n;
  final Float32List x, y, vx, vy, heat, release, phase;

  /// Whether a grain has reached its place since the intro started (it
  /// lights up as it lands).
  final Uint8List _arrived;

  /// How hot a grain must be to show as a glint.
  static const double _glintHeat = 0.6;

  TitleHue _hue, _oldHue;
  TitleHue get hue => _hue;

  // The recoloring ripple.
  double _hueX = 0, _hueY = 0, _hueT0 = -100;
  static const double _hueSpeed = 340;

  bool _settled = true;
  bool _introRunning = false;
  double _introEnd = 0;

  /// Where a finger is on it (local px), and how fast it is moving.
  Offset? pointer;
  Offset pointerVel = Offset.zero;

  final List<_Wave> _waves = [];

  /// Whether the letters are at rest, so a frame can use cached batches.
  bool get settled => _settled;

  // ── what happens ────────────────────────────────────────────────────────

  /// The grains stream in and settle, letter by letter, starting at [now].
  void startIntro(double now) {
    final rng = Random(23);
    for (var i = 0; i < n; i++) {
      final l = samples.letter[i];
      release[i] = now + l * 0.17 + phase[i] * 0.28;
      final a = rng.nextDouble() * 2 * pi;
      final d = 28 + rng.nextDouble() * 44;
      x[i] = samples.hx[i] + cos(a) * d;
      y[i] = samples.hy[i] + sin(a) * d * 0.7;
      // Swept in on a curve, not a straight line.
      vx[i] = -sin(a) * 60;
      vy[i] = cos(a) * 42;
      heat[i] = 0;
      _arrived[i] = 0;
    }
    _introRunning = true;
    _introEnd = now + 8 * 0.17 + 0.28 + 1.6;
    _settled = false;
  }

  /// Nothing showing yet: every grain waits for [startIntro].
  void hideForIntro() {
    for (var i = 0; i < n; i++) {
      release[i] = double.infinity;
    }
    _settled = false;
  }

  /// The title fully formed and still, as if the intro had long finished.
  void settleNow() {
    for (var i = 0; i < n; i++) {
      x[i] = samples.hx[i];
      y[i] = samples.hy[i];
      vx[i] = 0;
      vy[i] = 0;
      heat[i] = 0;
      release[i] = -1;
      _arrived[i] = 1;
    }
    _introRunning = false;
    _settled = true;
  }

  /// A tap at ([tx], [ty]).
  void tap(double tx, double ty, double now) {
    if (_waves.length >= 4) _waves.removeAt(0);
    _waves.add(_Wave(tx, ty, now, _hue.isVoid));
    _settled = false;
  }

  /// Turns the title to [next], rippling out from ([ox], [oy]).
  void setHue(TitleHue next, double ox, double oy, double now) {
    if (next.id == _hue.id) return;
    _oldHue = _hue;
    _hue = next;
    _hueX = ox;
    _hueY = oy;
    _hueT0 = now;
    _settled = false;
  }

  /// Sets the color at once, with no ripple.
  void setHueNow(TitleHue next) {
    _hue = next;
    _oldHue = next;
    _hueT0 = -100;
    _cache = null;
  }

  bool _inNewHue(int i, double now) {
    final r = (now - _hueT0) * _hueSpeed;
    final dx = samples.hx[i] - _hueX, dy = samples.hy[i] - _hueY;
    return dx * dx + dy * dy <= r * r;
  }

  // ── the motion ──────────────────────────────────────────────────────────

  static const double _k = 60, _damp = 10.8;

  void step(double dt, double now) {
    final waves = _waves..removeWhere((w) => now - w.t0 > 1.4);
    final recoloring = now - _hueT0 < 1.2;
    if (_settled && pointer == null && waves.isEmpty && !recoloring) return;

    final p = pointer;
    final isVoid = _hue.isVoid;
    final cool = exp(-dt * 3.4);
    var moving = false;
    for (var i = 0; i < n; i++) {
      if (now < release[i]) continue;
      final hx = samples.hx[i], hy = samples.hy[i];
      var px = x[i], py = y[i];
      var spring = _k;
      var ax = 0.0, ay = 0.0;

      if (p != null) {
        final dx = px - p.dx, dy = py - p.dy;
        final d2 = dx * dx + dy * dy;
        if (isVoid) {
          // A small black hole: grains within reach are pulled into orbit
          // round the finger and heat up as they go round.
          const reach = 30.0;
          if (d2 < reach * reach) {
            final d = sqrt(d2) + 0.001;
            final k = 1 - d / reach;
            final ux = dx / d, uy = dy / d;
            final orbit = 6 + 11 * phase[i];
            final pull = d > orbit ? 1300 * k : -900 * (1 - d / orbit);
            ax -= ux * pull;
            ay -= uy * pull;
            // Round, anticlockwise, faster nearer in.
            final vt = 170 + 260 * k;
            final tx = -uy, ty = ux;
            final along = vx[i] * tx + vy[i] * ty;
            ax += tx * (vt - along) * 7 * k;
            ay += ty * (vt - along) * 7 * k;
            spring *= 1 - k;
            // Hot only close in: a bright ring round the dark.
            final h = k * k * 1.15;
            if (h > heat[i]) heat[i] = h;
          }
        } else {
          // A stir: grains near the finger are carried round it and along
          // with it, eddy, and glint.
          const reach = 30.0;
          if (d2 < reach * reach) {
            final d = sqrt(d2) + 0.001;
            final k = 1 - d / reach;
            final k2 = k * k;
            final ux = dx / d, uy = dy / d;
            ax += (ux * 700 - uy * 1100) * k2 + pointerVel.dx * 4 * k2;
            ay += (uy * 700 + ux * 1100) * k2 + pointerVel.dy * 4 * k2;
            // Only the grains right under the finger glint, and not all.
            final h = (k - 0.45) * 1.6;
            if (h > heat[i] && sin(now * 9 + phase[i] * 40) > 0.2) {
              heat[i] = h;
            }
          }
        }
      }

      for (final w in waves) {
        final dx = hx - w.x, dy = hy - w.y;
        final d = sqrt(dx * dx + dy * dy) + 0.001;
        final age = now - w.t0;
        if (w.implode) {
          // Pulled in, then thrown back out.
          const reach = 50.0;
          if (d < reach) {
            final k = 1 - d / reach;
            final f = age < 0.2 ? -2600.0 : (age < 0.34 ? 2400.0 : 0.0);
            final cx = px - w.x, cy = py - w.y;
            final cd = sqrt(cx * cx + cy * cy) + 0.001;
            ax += cx / cd * f * k;
            ay += cy / cd * f * k;
            final h = k * 0.85;
            if (age < 0.34 && h > heat[i]) heat[i] = h;
          }
        } else {
          // A ring of force running outward through the letters.
          final front = age * 230;
          final g = (d - front) / 9;
          if (g.abs() < 2.5) {
            final e = exp(-g * g) * (1 - age / 1.4);
            ax += dx / d * 1900 * e;
            ay += dy / d * 1900 * e;
            // Only a thin line along the crest glints.
            final h = e * e * e * 0.75;
            if (h > heat[i]) heat[i] = h;
          }
        }
      }

      if (recoloring) {
        // A glint runs with the recoloring front.
        final r = (now - _hueT0) * _hueSpeed;
        final dx = hx - _hueX, dy = hy - _hueY;
        final g = (sqrt(dx * dx + dy * dy) - r) / 8;
        if (g.abs() < 1.5) {
          final e = exp(-g * g) * 0.75;
          if (e > heat[i]) heat[i] = e;
        }
      }

      ax += (hx - px) * spring - vx[i] * _damp;
      ay += (hy - py) * spring - vy[i] * _damp;
      vx[i] += ax * dt;
      vy[i] += ay * dt;
      px += vx[i] * dt;
      py += vy[i] * dt;
      x[i] = px;
      y[i] = py;
      heat[i] *= cool;
      // Lit as it lands.
      if (_arrived[i] == 0 && (px - hx).abs() < 1.2 && (py - hy).abs() < 1.2) {
        _arrived[i] = 1;
        heat[i] = 0.95;
      }
      if (!moving &&
          ((px - hx).abs() + (py - hy).abs() > 0.05 ||
              vx[i].abs() + vy[i].abs() > 0.1 ||
              heat[i] > 0.03)) {
        moving = true;
      }
    }
    if (_introRunning && now > _introEnd) _introRunning = false;
    _settled = !moving && !_introRunning && p == null && waves.isEmpty;
    if (_settled) {
      for (var i = 0; i < n; i++) {
        x[i] = samples.hx[i];
        y[i] = samples.hy[i];
        vx[i] = 0;
        vy[i] = 0;
        heat[i] = 0;
      }
    }
  }

  // ── the look ────────────────────────────────────────────────────────────

  // Buckets: tones of the old color, tones of the new, glints, and one for
  // the glow under everything.
  static const int _tones = TitleSamples.toneCount;
  static const int _glint = 2 * _tones;
  static const int _glow = 2 * _tones + 1;
  final _Batch _batch = _Batch(2 * _tones + 2);

  // The resting letters, batched once per color.
  _Batch? _cache;
  String? _cacheHue;

  Color _toneColor(TitleHue h, int tone) {
    if (h.original) return samples.tones[tone];
    // Void: black inside the strokes, violet light round their edges.
    if (h.isVoid) {
      return tone == _tones - 1
          ? const Color(0xFFA27AE8)
          : const Color(0xFF05010C);
    }
    return Color.lerp(h.dark, h.light, tone / (_tones - 1))!;
  }

  /// Which tone bucket grain [i] is drawn in under [h].
  int _bucket(TitleHue h, int i) =>
      h.isVoid ? (samples.edge[i] == 1 ? _tones - 1 : 0) : samples.tone[i];

  Color _glowColor(TitleHue h) => switch (h.id) {
    'original' => const Color(0xFFFFD27A),
    'void' => const Color(0xFF7A3AD0),
    _ => h.swatch,
  };

  Color _glintColor(TitleHue h) => switch (h.id) {
    'void' => const Color(0xFFE8C8FF),
    'original' => const Color(0xFFFFFBEA),
    _ => Color.lerp(h.light, const Color(0xFFFFFFFF), 0.5)!,
  };

  /// Paints the title at [origin] (the top-left of its box). [darkBackdrop]
  /// is whether it sits on a dark screen, where it glows.
  void paint(Canvas c, Offset origin, double now, {bool darkBackdrop = true}) {
    c.save();
    c.translate(origin.dx, origin.dy);
    final hue = _hue;
    final glowAlpha = hue.isVoid ? 0.2 : (darkBackdrop ? 0.07 : 0.035);

    if (_settled) {
      // At rest: the letters from cache, and only the twinkles worked out.
      if (_cache == null || _cacheHue != hue.id) {
        final b = _cache ??= _Batch(_tones + 1);
        b.clear();
        for (var i = 0; i < n; i++) {
          b.add(_bucket(hue, i), samples.hx[i], samples.hy[i]);
          b.add(_tones, samples.hx[i], samples.hy[i]);
        }
        _cacheHue = hue.id;
      }
      final b = _cache!;
      b.draw(c, _tones, 4.4, _glowColor(hue).withValues(alpha: glowAlpha));
      for (var t = 0; t < _tones; t++) {
        b.draw(c, t, 1.45, _toneColor(hue, t));
      }
      _batch.clear();
      for (var i = 0; i < n; i++) {
        final f = (now * 0.21 + phase[i] * 7.3) % 1.0;
        if (f < 0.018) _batch.add(_glint, samples.hx[i], samples.hy[i]);
      }
      _drawGlints(c, hue);
      c.restore();
      return;
    }

    _batch.clear();
    final recoloring = now - _hueT0 < 1.2;
    for (var i = 0; i < n; i++) {
      if (now < release[i]) continue;
      final px = x[i], py = y[i];
      _batch.add(_glow, px, py);
      final twinkle = (now * 0.21 + phase[i] * 7.3) % 1.0 < 0.018;
      if (heat[i] > _glintHeat || twinkle) {
        _batch.add(_glint, px, py);
        continue;
      }
      final newer = !recoloring || _inNewHue(i, now);
      _batch.add(
        newer ? _tones + _bucket(hue, i) : _bucket(_oldHue, i),
        px,
        py,
      );
    }
    _batch.draw(c, _glow, 4.4, _glowColor(hue).withValues(alpha: glowAlpha));
    for (var t = 0; t < _tones; t++) {
      _batch.draw(c, t, 1.45, _toneColor(_oldHue, t));
      _batch.draw(c, _tones + t, 1.45, _toneColor(hue, t));
    }
    _drawGlints(c, hue);

    // A tap leaves a brief light where it landed — or, in Void, a brief
    // dark with light bent round it.
    for (final w in _waves) {
      final age = now - w.t0;
      if (age > 0.45) continue;
      final f = 1 - age / 0.45;
      final at = Offset(w.x, w.y);
      if (w.implode) {
        final r = 6 + 6 * sin(min(1, age / 0.34) * pi);
        c.drawCircle(
          at,
          r * 2.2,
          Paint()
            ..shader = ui.Gradient.radial(
              at,
              r * 2.2,
              [
                const Color(0xFF000000).withValues(alpha: 0.9 * f),
                const Color(0xFF000000).withValues(alpha: 0.9 * f),
                const Color(0xFF9A6AE0).withValues(alpha: 0.5 * f),
                const Color(0xFF9A6AE0).withValues(alpha: 0),
              ],
              const [0.0, 0.42, 0.5, 1.0],
            ),
        );
      } else {
        final r = 10 + 26 * age;
        final col = _glintColor(hue);
        c.drawCircle(
          at,
          r,
          Paint()
            ..shader = ui.Gradient.radial(at, r, [
              col.withValues(alpha: 0.35 * f),
              col.withValues(alpha: 0),
            ]),
        );
      }
    }
    c.restore();
  }

  void _drawGlints(Canvas c, TitleHue hue) {
    final col = _glintColor(hue);
    _batch.draw(c, _glint, 3.6, col.withValues(alpha: 0.22));
    _batch.draw(c, _glint, 1.8, col.withValues(alpha: 0.95));
  }
}

/// Points in buckets, each bucket one round-capped point draw.
class _Batch {
  _Batch(int buckets)
    : _pts = List.generate(buckets, (_) => Float32List(256)),
      _n = List.filled(buckets, 0);

  final List<Float32List> _pts;
  final List<int> _n;

  static final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void clear() => _n.fillRange(0, _n.length, 0);

  void add(int b, double x, double y) {
    var buf = _pts[b];
    final i = _n[b] * 2;
    if (i + 2 > buf.length) {
      _pts[b] = buf = Float32List(buf.length * 2)..setAll(0, buf);
    }
    buf[i] = x;
    buf[i + 1] = y;
    _n[b]++;
  }

  void draw(Canvas c, int b, double diameter, Color color) {
    final n = _n[b];
    if (n == 0 || color.a <= 0) return;
    _paint
      ..strokeWidth = diameter
      ..color = color;
    c.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_pts[b], 0, n * 2),
      _paint,
    );
  }
}

// ── the widget ──────────────────────────────────────────────────────────────

/// The home screen's title, in particles. Lays out in the same 300×60 box
/// the logo image did; grains thrown about may stray outside it.
class ParticleTitle extends StatefulWidget {
  const ParticleTitle({
    super.key,
    required this.darkBackdrop,
    this.active = true,
  });

  /// Whether it sits on a dark screen (it glows there, and reads the gold
  /// logo; on a light one it reads the dark-inked logo).
  final bool darkBackdrop;

  /// Whether it is on screen and should move at all.
  final bool active;

  @override
  State<ParticleTitle> createState() => _ParticleTitleState();
}

class _ParticleTitleState extends State<ParticleTitle>
    with SingleTickerProviderStateMixin {
  /// The letters stream in once a run, the first time home is shown.
  static bool _introPlayed = false;

  static const _prefKey = 'title_particle_hue';

  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final LayerLink _link = LayerLink();
  TitleParticleField? _field;
  Duration _last = Duration.zero;
  double _now = 0;
  bool _introPending = false;
  OverlayEntry? _picker;

  String get _asset => widget.darkBackdrop
      ? kTitleAsset
      : 'assets/images/ui/alchemonstitledark.png';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _load();
  }

  Future<void> _load() async {
    final samples = await TitleSamples.of(_asset);
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(_prefKey);
    } catch (_) {}
    if (!mounted) return;
    final field = TitleParticleField(samples)..setHueNow(titleHue(saved));
    if (_introPlayed) {
      field.settleNow();
    } else {
      _introPlayed = true;
      _introPending = true;
      field.hideForIntro();
    }
    setState(() => _field = field);
    _syncTicker();
  }

  void _syncTicker() {
    final field = _field;
    final run = widget.active && field != null;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && field != null) {
      if (_ticker.isActive) _ticker.stop();
      // Never left half-built, or hidden waiting for an intro that cannot
      // play: paused, it is simply the finished title.
      if (_introPending || !field.settled) {
        _introPending = false;
        field
          ..pointer = null
          ..settleNow();
        _frame.value++;
      }
    }
  }

  void _tick(Duration elapsed) {
    final field = _field;
    if (field == null) return;
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    _now += dt;
    // Let the screen finish arriving before the letters do.
    if (_introPending && _now > 0.35) {
      _introPending = false;
      field.startIntro(_now);
    }
    field.step(dt, _now);
    _frame.value++;
  }

  @override
  void didUpdateWidget(ParticleTitle old) {
    super.didUpdateWidget(old);
    if (old.darkBackdrop != widget.darkBackdrop) {
      TitleSamples.of(_asset).then((s) {
        if (!mounted) return;
        final hue = _field?.hue ?? kTitleHues.first;
        setState(
          () => _field = TitleParticleField(s)
            ..setHueNow(hue)
            ..settleNow(),
        );
      });
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _closePicker();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ── touch ─────────────────────────────────────────────────────────────

  void _onTap(TapUpDetails d) {
    HapticFeedback.lightImpact();
    _field?.tap(d.localPosition.dx, d.localPosition.dy, _now);
  }

  void _onPanStart(DragStartDetails d) {
    _field?.pointer = d.localPosition;
    _field?.pointerVel = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final f = _field;
    if (f == null) return;
    f.pointer = d.localPosition;
    // Smoothed, in px per second.
    f.pointerVel = f.pointerVel * 0.6 + d.delta * 60 * 0.4;
  }

  void _onPanEnd([Object? _]) {
    _field?.pointer = null;
    _field?.pointerVel = Offset.zero;
  }

  void _onLongPress(LongPressStartDetails d) {
    HapticFeedback.selectionClick();
    _openPicker(d.localPosition);
  }

  // ── the color picker ─────────────────────────────────────────────────

  void _openPicker(Offset from) {
    _closePicker();
    final overlay = Overlay.of(context);
    _picker = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closePicker,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 6),
            child: _TitleHuePicker(
              current: _field?.hue.id ?? 'original',
              onPick: (hue) {
                _field?.setHue(hue, from.dx, from.dy, _now);
                SharedPreferences.getInstance().then(
                  (p) => p.setString(_prefKey, hue.id),
                );
                HapticFeedback.lightImpact();
                _closePicker();
              },
            ),
          ),
        ],
      ),
    );
    overlay.insert(_picker!);
  }

  void _closePicker() {
    _picker?.remove();
    _picker = null;
  }

  @override
  Widget build(BuildContext context) {
    final field = _field;
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: _onTap,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanEnd,
        onLongPressStart: _onLongPress,
        child: RepaintBoundary(
          child: CustomPaint(
            size: TitleSamples.box,
            painter: field == null
                ? null
                : _TitlePainter(
                    field,
                    () => _now,
                    widget.darkBackdrop,
                    repaint: _frame,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TitlePainter extends CustomPainter {
  _TitlePainter(this.field, this.now, this.dark, {super.repaint});

  final TitleParticleField field;
  final double Function() now;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) =>
      field.paint(canvas, Offset.zero, now(), darkBackdrop: dark);

  @override
  bool shouldRepaint(_TitlePainter old) =>
      old.field != field || old.dark != dark;
}

/// The row of colors a long press brings up.
class _TitleHuePicker extends StatelessWidget {
  const _TitleHuePicker({required this.current, required this.onPick});

  final String current;
  final ValueChanged<TitleHue> onPick;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, -6 * (1 - v)),
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xEE0C0A14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x44F2C75C)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final h in kTitleHues)
                GestureDetector(
                  onTap: () => onPick(h),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: h.isVoid
                              ? const [Color(0xFF000000), Color(0xFF1A0B2E)]
                              : [h.light, h.swatch],
                        ),
                        border: Border.all(
                          color: h.id == current
                              ? const Color(0xFFFFFFFF)
                              : h.isVoid
                              ? const Color(0xFF9A6AE0)
                              : const Color(0x33FFFFFF),
                          width: h.id == current ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
