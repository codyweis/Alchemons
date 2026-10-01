import 'dart:math';
import 'dart:typed_data';
import 'alchemy_simulation.dart';
export 'alchemy_simulation.dart' show AlchemyElement, MatterPhase;

typedef FluidMaterial = AlchemyElement;

/// Bounded, dense material transport. Cost is O(vessel area), never O(pairs).
/// Coordinates retain the chamber's x=0..1, y=0..1.5 convention.
class FluidScene {
  FluidScene({required Map<String, dynamic> recipeJson}) {
    final canonical = AlchemySimulation(recipeJson: recipeJson);
    for (final r in canonical.recipes.values) {
      _products[r.a.id * 32 + r.b.id] = r.product.id;
      _products[r.b.id * 32 + r.a.id] = r.product.id;
      _labels[r.a.id * 32 + r.b.id] = r.description;
      _labels[r.b.id * 32 + r.a.id] = r.description;
    }
  }
  static const renderW = 160, renderH = 240, atlasW = renderW * 4;
  static const capacity = (renderW - 4) * (renderH - 5);
  static const count = renderW * renderH;
  final cells = Uint8List(count);
  final _age = Uint16List(count), _moved = Uint32List(count);
  final _vx = Int8List(count), _vy = Int8List(count);
  final _products = Uint8List(32 * 32);
  final _labels = <int, String>{};
  final pixels = Uint8List(atlasW * renderH * 4);
  final _raw = Uint8List(count * 12), _horizontal = Uint8List(count * 12);
  int particleCount = 0, transformations = 0, _tick = 0;
  double time = 0, _accumulator = 0;
  bool feeding = false;
  String lastReaction = 'Choose an element. Hold inside the vessel to pour.';
  bool _inside(int x, int y) =>
      x >= 2 && x < renderW - 2 && y >= 2 && y < renderH - 3;
  void reset() => clear();
  void clear() {
    for (final a in [cells, _age, _moved, _vx, _vy]) {
      a.fillRange(0, a.length, 0);
    }
    particleCount = transformations = _tick = 0;
    time = _accumulator = 0;
    feeding = false;
    lastReaction = 'Choose an element. Hold inside the vessel to pour.';
  }

  bool put(int x, int y, FluidMaterial material) {
    if (!_inside(x, y)) return false;
    final i = y * renderW + x;
    if (cells[i] != 0) return false;
    cells[i] = material.id;
    _age[i] = 0;
    particleCount++;
    return true;
  }

  void pour(
    double x,
    double y, {
    int amount = 48,
    FluidMaterial material = FluidMaterial.water,
  }) {
    final cx = (x * renderW).round(), cy = (y * renderW).round();
    var added = 0;
    // Fill from the center outward. No probability roll or hidden global cap.
    for (var r = 0; r <= 9 && added < amount; r++) {
      for (var dy = -r; dy <= r && added < amount; dy++) {
        for (var dx = -r; dx <= r && added < amount; dx++) {
          if (max(dx.abs(), dy.abs()) != r || dx * dx + dy * dy > 81) continue;
          if (put(cx + dx, cy + dy, material)) added++;
        }
      }
    }
  }

  void ignite(double x, double y, double dt) => pour(
    x,
    y,
    amount: max(1, (dt * 2880).round()),
    material: FluidMaterial.fire,
  );
  void erase(double x, double y) {
    final cx = (x * renderW).round(), cy = (y * renderW).round();
    for (var dy = -10; dy <= 10; dy++) {
      for (var dx = -10; dx <= 10; dx++) {
        if (dx * dx + dy * dy > 100 || !_inside(cx + dx, cy + dy)) continue;
        final i = (cy + dy) * renderW + cx + dx;
        if (cells[i] != 0) {
          cells[i] = 0;
          _age[i] = 0;
          _vx[i] = _vy[i] = 0;
          particleCount--;
        }
      }
    }
  }

  void stir(double x, double y, double dx, double dy) {
    final cx = (x * renderW).round(), cy = (y * renderW).round();
    for (var oy = -16; oy <= 16; oy++) {
      for (var ox = -16; ox <= 16; ox++) {
        if (ox * ox + oy * oy > 256 || !_inside(cx + ox, cy + oy)) continue;
        final i = (cy + oy) * renderW + cx + ox;
        if (cells[i] == 0) continue;
        final falloff = 1 - sqrt((ox * ox + oy * oy) / 256);
        _vx[i] = (dx * renderW * 3 * falloff).round().clamp(-6, 6);
        _vy[i] = (dy * renderW * 3 * falloff).round().clamp(-6, 6);
      }
    }
  }

  bool react(int i, int j) {
    if (i < 0 || j < 0 || i >= count || j >= count || i == j) return false;
    final a = cells[i], b = cells[j];
    if (a == 0 || b == 0 || a == b) return false;
    final key = a * 32 + b, product = _products[key];
    if (product == 0) return false;
    // Both contact cells transform: recipes are deterministic and retain bulk.
    cells[i] = cells[j] = product;
    _age[i] = _age[j] = 0;
    _moved[i] = _moved[j] = _tick;
    transformations++;
    lastReaction = _labels[key]!;
    return true;
  }

  void _swap(int i, int j) {
    final id = cells[i], age = _age[i], vx = _vx[i], vy = _vy[i];
    cells[i] = cells[j];
    cells[j] = id;
    _age[i] = _age[j];
    _age[j] = age;
    _vx[i] = _vx[j];
    _vx[j] = vx;
    _vy[i] = _vy[j];
    _vy[j] = vy;
    _moved[i] = _moved[j] = _tick;
  }

  bool _move(int i, int x, int y, {bool impulse = false}) {
    if (!_inside(x, y)) return false;
    final j = y * renderW + x, other = cells[j];
    if (other != 0) {
      if (_moved[j] == _tick) return false;
      final a = FluidMaterial.values[cells[i] - 1],
          b = FluidMaterial.values[other - 1];
      if (a == b || b.phase == MatterPhase.solid) return false;
      if (!impulse && (y <= i ~/ renderW || a.density <= b.density + .1)) {
        return false;
      }
    }
    _swap(i, j);
    return true;
  }

  void step(double dt) {
    _accumulator += dt.clamp(0, .05);
    while (_accumulator + 1e-9 >= 1 / 60) {
      _advance();
      _accumulator -= 1 / 60;
      time += 1 / 60;
    }
  }

  void _advance() {
    _tick++;
    if (feeding) {
      pour(.4 + sin(time * .8) * .18, .18, amount: 24);
      pour(.57, 1.2, amount: 12, material: FluidMaterial.fire);
    }
    for (var y = renderH - 4; y >= 2; y--) {
      final wind = (sin(y * .065 + time * 1.8) + sin(y * .029 - time * .9))
          .round()
          .clamp(-1, 1);
      for (var c = 2; c < renderW - 2; c++) {
        final x = _tick.isEven ? c : renderW - 1 - c,
            i = y * renderW + x,
            id = cells[i];
        if (id == 0 || _moved[i] == _tick) continue;
        _age[i] = min(65000, _age[i] + 1);
        var hash = (i * 374761393 + _tick * 668265263) & 0x7fffffff;
        hash = ((hash ^ (hash >> 13)) * 1274126177) & 0x7fffffff;
        final d = (hash & 1) == 0 ? 1 : -1;
        if (react(i, i + d) ||
            react(i, i - d) ||
            react(i, i + renderW) ||
            react(i, i - renderW)) {
          continue;
        }
        final e = FluidMaterial.values[id - 1];
        if (_vx[i] != 0 || _vy[i] != 0) {
          final vx = _vx[i], vy = _vy[i];
          _vx[i] -= vx.sign;
          _vy[i] -= vy.sign;
          // Adjacent swaps keep impulses from teleporting through solid walls.
          if (_move(i, x + vx.sign, y + vy.sign, impulse: true)) continue;
        }
        if (e.phase == MatterPhase.solid) continue;
        if (e.phase == MatterPhase.gas) {
          if (y <= 3 ||
              _age[i] >
                  (e == FluidMaterial.fire || e == FluidMaterial.lightning
                      ? 120
                      : 900)) {
            cells[i] = 0;
            _vx[i] = _vy[i] = 0;
            particleCount--;
            continue;
          }
          if (_move(i, x + wind, y - 1) ||
              _move(i, x, y - 1) ||
              _move(i, x + d, y - 1) ||
              _move(i, x - d, y - 1) ||
              _move(i, x + d, y)) {
            continue;
          }
        } else {
          final viscous = e == FluidMaterial.mud || e == FluidMaterial.lava;
          if (viscous && (_tick + x + y) % 3 != 0) continue;
          if (_move(i, x, y + 1) ||
              _move(i, x + d, y + 1) ||
              _move(i, x - d, y + 1)) {
            continue;
          }
          if (e.phase == MatterPhase.liquid) {
            // A bounded horizontal search levels a pool without pair searches.
            final reach = viscous ? 1 : 5;
            var moved = false;
            for (var side = 0; side < 2; side++) {
              final direction = side == 0 ? d : -d;
              for (var n = 1; n <= reach; n++) {
                final nx = x + n * direction;
                if (!_inside(nx, y)) break;
                if (cells[y * renderW + nx] != 0) break;
                if (n == reach || cells[(y + 1) * renderW + nx] == 0) {
                  moved = _move(i, nx, y);
                  break;
                }
              }
              if (moved) break;
            }
          }
        }
        _moved[i] = _tick;
      }
    }
  }

  /// Deterministic dense workload; used only by diagnostics and benchmarks.
  void seedBenchmark() {
    clear();
    const choices = [
      FluidMaterial.water,
      FluidMaterial.mud,
      FluidMaterial.lava,
      FluidMaterial.earth,
      FluidMaterial.poison,
      FluidMaterial.blood,
    ];
    for (var y = 40; y < renderH - 3; y++) {
      for (var x = 2; x < renderW - 2; x++) {
        put(x, y, choices[(x ~/ 26) % choices.length]);
      }
    }
  }

  // Linear optical coefficients, indexed by canonical element ID. Dense RGB,
  // roughness, gas RGB, emission RGB. All atlas alpha bytes stay opaque.
  static const _colors = <List<int>>[
    [0, 0, 0],
    [255, 85, 15],
    [20, 83, 109],
    [95, 67, 34],
    [93, 162, 179],
    [138, 177, 191],
    [94, 34, 18],
    [132, 170, 255],
    [66, 69, 43],
    [117, 192, 218],
    [142, 119, 88],
    [138, 120, 208],
    [40, 120, 73],
    [94, 138, 37],
    [120, 178, 202],
    [33, 22, 59],
    [241, 219, 158],
    [119, 20, 35],
  ];
  static const _emission = <List<int>>[
    [0, 0, 0],
    [255, 95, 18],
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0],
    [255, 70, 8],
    [100, 151, 255],
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0],
    [15, 10, 35],
    [0, 0, 0],
    [12, 25, 1],
    [25, 78, 100],
    [5, 0, 16],
    [255, 216, 132],
    [0, 0, 0],
  ];
  Uint8List encode() {
    _raw.fillRange(0, _raw.length, 0);
    for (var i = 0; i < count; i++) {
      final id = cells[i];
      if (id == 0) continue;
      final e = FluidMaterial.values[id - 1],
          gas = e.phase == MatterPhase.gas,
          b = i * 12;
      final color = _colors[id], emission = _emission[id];
      final fade = gas
          ? (e == FluidMaterial.fire || e == FluidMaterial.lightning
                ? (1 - _age[i] / 120).clamp(0.0, 1.0)
                : 1.0)
          : 1.0;
      for (var k = 0; k < 3; k++) {
        _raw[b + (gas ? 6 : 0) + k] = (color[k] * fade).round();
        _raw[b + 9 + k] = (emission[k] * fade).round();
      }
      _raw[b + 3] = gas ? 0 : 255;
      _raw[b + 4] = gas ? (255 * fade).round() : 0;
      _raw[b + 5] = gas
          ? 0
          : (e.phase == MatterPhase.powder ||
                    e == FluidMaterial.mud ||
                    e == FluidMaterial.plant
                ? 230
                : 40);
    }
    // Separable binomial filtering before cubic GPU reconstruction. This
    // smooths occupancy, colors and optical normals together, not just edges.
    for (var y = 0; y < renderH; y++) {
      for (var x = 0; x < renderW; x++) {
        final b = (y * renderW + x) * 12,
            l = x == 0 ? b : b - 12,
            r = x == renderW - 1 ? b : b + 12;
        for (var k = 0; k < 12; k++) {
          if (k == 4 || k >= 6) {
            const weights = [1, 6, 15, 20, 15, 6, 1];
            var sum = 0;
            for (var tap = -3; tap <= 3; tap++) {
              final sample =
                  (y * renderW + (x + tap).clamp(0, renderW - 1)) * 12 + k;
              sum += _raw[sample] * weights[tap + 3];
            }
            _horizontal[b + k] = (sum + 32) >> 6;
            continue;
          }
          _horizontal[b + k] =
              (_raw[l + k] + 2 * _raw[b + k] + _raw[r + k] + 2) >> 2;
        }
      }
    }
    for (var y = 0; y < renderH; y++) {
      for (var x = 0; x < renderW; x++) {
        final b = (y * renderW + x) * 12,
            t = y == 0 ? b : b - renderW * 12,
            d = y == renderH - 1 ? b : b + renderW * 12;
        for (var layer = 0; layer < 4; layer++) {
          final out = (y * atlasW + x + layer * renderW) * 4;
          for (var k = 0; k < 3; k++) {
            final c = layer * 3 + k;
            if (c == 4 || c >= 6) {
              const weights = [1, 6, 15, 20, 15, 6, 1];
              var sum = 0;
              for (var tap = -3; tap <= 3; tap++) {
                final sample =
                    ((y + tap).clamp(0, renderH - 1) * renderW + x) * 12 + c;
                sum += _horizontal[sample] * weights[tap + 3];
              }
              pixels[out + k] = (sum + 32) >> 6;
              continue;
            }
            pixels[out + k] =
                (_horizontal[t + c] +
                    2 * _horizontal[b + c] +
                    _horizontal[d + c] +
                    2) >>
                2;
          }
          pixels[out + 3] = 255;
        }
      }
    }
    return pixels;
  }
}
