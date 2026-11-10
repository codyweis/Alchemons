// lib/games/cosmic_survival/dust_sea.dart
//
// A wave whose arena is a sea of dust. While a Drift lives
// (boss_roster_art.dart), fine sand settles over the whole field in a few
// seconds. Everything that moves through it parts it: bodies push it aside,
// a Hollow opens a true gap in it, the ship and your Alchemons wade through
// it, the core keeps a clearing, and the Drift's stream cuts a channel
// through it, so the boss is seen flowing through the arena it filled. When
// the last Drift falls the sand settles out. Look only: nothing here touches
// a body, a shot or the run's Random.
//
// Budget: the sand is a world-anchored tiling of fixed grains, with no state
// per grain, drifting slowly as one. The parting is a coarse push field laid
// over the view each frame from at most [DustSea.maxSources] places (each
// touching only the field's nodes it reaches) and sampled bilinearly per
// grain, so a grain costs a few multiplies however many bodies there are.
// Three point batches. No blur.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

const _ash = Color(0xFF8F8574);
const _ashPale = Color(0xFFC9BFA8);
const _white = Color(0xFFFFF6E4);

class DustSea {
  static const int maxSources = 72;
  static const double _tile = 640;
  static const int _perTile = 5200;
  static const double _cell = 22;

  /// How much of the sea is down, 0..1. Eased: it settles in and out.
  double amount = 0;
  double _clock = 0;

  bool get visible => amount > 0.01;

  void update(double dt, {required bool active}) {
    _clock += dt;
    final target = active ? 1.0 : 0.0;
    amount += (target - amount) * min(1.0, dt * (active ? 0.9 : 0.6));
    if (!active && amount < 0.005) amount = 0;
  }

  final Float32List _src = Float32List(maxSources * 3);
  int _ns = 0;

  /// Places the sand is pushed out of this frame.
  int get sources => _ns;

  void clearSources() => _ns = 0;

  /// The sand within [reach] of ([x], [y]) is pushed out to its edge.
  void addSource(double x, double y, double reach) {
    if (_ns >= maxSources || reach < 4) return;
    final i = _ns * 3;
    _src[i] = x;
    _src[i + 1] = y;
    _src[i + 2] = reach;
    _ns++;
  }

  Float32List _fx = Float32List(0), _fy = Float32List(0);

  /// Grains handed to the canvas by the last [paint].
  int lastGrains = 0;

  final List<Float32List> _out = List.generate(3, (_) => Float32List(4096));
  final List<int> _n = [0, 0, 0];

  void _add(int b, double x, double y) {
    var d = _out[b];
    final n = _n[b];
    if (n + 2 > d.length) d = _out[b] = Float32List(d.length * 2)..setAll(0, d);
    d[n] = x;
    d[n + 1] = y;
    _n[b] = n + 2;
  }

  static final Paint _pt = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  /// The sea inside [view], tinted toward [tint]. Over the floor, under
  /// every body.
  void paint(Canvas c, Rect view, Color tint) {
    lastGrains = 0;
    if (!visible) return;

    // The push field: nodes every [_cell] units over the view.
    final ox = view.left - _cell, oy = view.top - _cell;
    final cols = (view.width / _cell).ceil() + 3;
    final rows = (view.height / _cell).ceil() + 3;
    final nodes = cols * rows;
    if (_fx.length < nodes) {
      _fx = Float32List(nodes);
      _fy = Float32List(nodes);
    } else {
      _fx.fillRange(0, nodes, 0);
      _fy.fillRange(0, nodes, 0);
    }
    for (var s = 0; s < _ns; s++) {
      final sx = _src[s * 3], sy = _src[s * 3 + 1], reach = _src[s * 3 + 2];
      final i0 = max(0, ((sx - reach - ox) / _cell).floor());
      final i1 = min(cols - 1, ((sx + reach - ox) / _cell).ceil());
      final j0 = max(0, ((sy - reach - oy) / _cell).floor());
      final j1 = min(rows - 1, ((sy + reach - oy) / _cell).ceil());
      for (var j = j0; j <= j1; j++) {
        final ny = oy + j * _cell, dy = ny - sy;
        for (var i = i0; i <= i1; i++) {
          final dx = ox + i * _cell - sx;
          final d2 = dx * dx + dy * dy;
          if (d2 >= reach * reach) continue;
          final d = max(1.0, sqrt(d2));
          final push = (reach - d) * 0.92 / d;
          final k = j * cols + i;
          _fx[k] += dx * push;
          _fy[k] += dy * push;
        }
      }
    }

    // The sand: a fixed tiling, drifting slowly as one.
    final shown = (_perTile * min(1.0, amount * 1.4)).round();
    final driftX = _clock * 5.0, driftY = _clock * 2.4;
    final tx0 = ((view.left - driftX) / _tile).floor();
    final tx1 = ((view.right - driftX) / _tile).floor();
    final ty0 = ((view.top - driftY) / _tile).floor();
    final ty1 = ((view.bottom - driftY) / _tile).floor();
    for (var tx = tx0; tx <= tx1; tx++) {
      for (var ty = ty0; ty <= ty1; ty++) {
        final bx = tx * _tile + driftX, by = ty * _tile + driftY;
        for (var i = 0; i < shown; i++) {
          var x = bx + _table[(i * 2) & _mask] * _tile;
          var y = by + _table[(i * 2 + 1) & _mask] * _tile;
          if (x < view.left ||
              x > view.right ||
              y < view.top ||
              y > view.bottom) {
            continue;
          }
          final gx = (x - ox) / _cell, gy = (y - oy) / _cell;
          final ix = gx.floor(), iy = gy.floor();
          final u = gx - ix, v = gy - iy;
          final k = iy * cols + ix;
          final px =
              (_fx[k] * (1 - u) + _fx[k + 1] * u) * (1 - v) +
              (_fx[k + cols] * (1 - u) + _fx[k + cols + 1] * u) * v;
          final py =
              (_fy[k] * (1 - u) + _fy[k + 1] * u) * (1 - v) +
              (_fy[k + cols] * (1 - u) + _fy[k + cols + 1] * u) * v;
          x += px;
          y += py;
          // Sand piled at the edge of what parted it catches the light.
          final b = px * px + py * py > 36
              ? 2
              : (_table[(i * 3 + 1) & _mask] < 0.66 ? 0 : 1);
          _add(b, x, y);
        }
      }
    }

    final a = min(1.0, amount * 1.2);
    final looks = <(Color, double, double)>[
      (Color.lerp(_ash, tint, 0.25)!, 1.3, 0.55),
      (Color.lerp(_ashPale, tint, 0.25)!, 1.3, 0.7),
      (Color.lerp(tint, _white, 0.4)!, 1.7, 0.85),
    ];
    for (var b = 0; b < 3; b++) {
      final n = _n[b];
      if (n == 0) continue;
      final (col, w, alpha) = looks[b];
      c.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(_out[b], 0, n),
        _pt
          ..strokeWidth = w
          ..color = col.withValues(alpha: alpha * a),
      );
      lastGrains += n ~/ 2;
      _n[b] = 0;
    }
  }
}

const int _mask = 8191;
final Float32List _table = () {
  final r = Random(9127);
  return Float32List.fromList([
    for (var i = 0; i <= _mask; i++) r.nextDouble(),
  ]);
}();
