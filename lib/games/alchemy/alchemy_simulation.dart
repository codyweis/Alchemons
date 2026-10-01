import 'dart:math';
import 'dart:typed_data';

/// Rendering-independent material rules. IDs are stable and zero means empty.
enum MatterPhase { gas, liquid, powder, solid }

enum AlchemyElement {
  fire('Fire', MatterPhase.gas, .12),
  water('Water', MatterPhase.liquid, 1),
  earth('Earth', MatterPhase.powder, 2),
  air('Air', MatterPhase.gas, .02),
  steam('Steam', MatterPhase.gas, .05),
  lava('Lava', MatterPhase.liquid, 1.7),
  lightning('Lightning', MatterPhase.gas, .04),
  mud('Mud', MatterPhase.liquid, 1.8),
  ice('Ice', MatterPhase.solid, 2),
  dust('Dust', MatterPhase.powder, 1.4),
  crystal('Crystal', MatterPhase.solid, 3),
  plant('Plant', MatterPhase.solid, 1.4),
  poison('Poison', MatterPhase.liquid, 1.2),
  spirit('Spirit', MatterPhase.gas, .01),
  dark('Dark', MatterPhase.liquid, 1.1),
  light('Light', MatterPhase.gas, .03),
  blood('Blood', MatterPhase.liquid, 1.5);

  const AlchemyElement(this.label, this.phase, this.density);
  final String label;
  final MatterPhase phase;
  final double density;
  int get id => index + 1;
  static AlchemyElement named(String name) =>
      values.firstWhere((e) => e.label.toLowerCase() == name.toLowerCase());
}

enum AlchemyTool { pour, stir, erase }

enum AlchemyStudy { vapor, mineral, eclipse }

class AlchemyRecipe {
  const AlchemyRecipe(this.a, this.b, this.product);
  final AlchemyElement a, b, product;
  String get description => '${a.label} + ${b.label} → ${product.label}';
}

class AlchemyFlash {
  AlchemyFlash(this.x, this.y, this.product);
  final int x, y;
  final AlchemyElement product;
  double life = 1;
}

class AlchemySimulation {
  AlchemySimulation({required Map<String, dynamic> recipeJson, int seed = 19})
    : random = Random(seed) {
    final source = recipeJson['recipes'] as Map<String, dynamic>;
    for (final entry in source.entries) {
      final names = entry.key.split('+');
      if (names.length != 2) continue;
      final a = AlchemyElement.named(names[0]);
      final b = AlchemyElement.named(names[1]);
      final outcomes = (entry.value as Map<String, dynamic>).entries.toList();
      if (outcomes.isEmpty) throw FormatException('Empty recipe: ${entry.key}');
      // Only the main product is used. Never roll the original probabilities.
      final main = outcomes.reduce(
        (a, b) => (a.value as num) >= (b.value as num) ? a : b,
      );
      recipes[_key(a.id, b.id)] = AlchemyRecipe(
        a,
        b,
        AlchemyElement.named(main.key),
      );
    }
  }

  static const width = 128, height = 160;
  final Random random;
  final cells = Uint8List(width * height);
  final _moved = Uint32List(width * height);
  final _ages = Uint16List(width * height);
  final Map<int, AlchemyRecipe> recipes = {};
  final List<AlchemyFlash> flashes = [];
  final List<AlchemyRecipe> journal = [];
  int tick = 0, reactionCount = 0;
  bool feeding = true;
  AlchemyStudy study = AlchemyStudy.vapor;
  int get particleCount => cells.where((id) => id != 0).length;
  static int _key(int a, int b) => min(a, b) * 32 + max(a, b);
  AlchemyRecipe? recipeFor(AlchemyElement a, AlchemyElement b) =>
      recipes[_key(a.id, b.id)];

  bool _inside(int x, int y) =>
      x > 1 && x < width - 2 && y > 1 && y < height - 3;
  void put(int x, int y, AlchemyElement e) {
    if (!_inside(x, y)) return;
    final i = y * width + x;
    if (cells[i] != 0) return;
    cells[i] = e.id;
    _ages[i] = 0;
    _moved[i] = tick;
  }

  void brush(
    double x,
    double y,
    AlchemyElement e,
    AlchemyTool tool,
    double radius,
  ) {
    final cx = x.round(), cy = y.round(), r = radius.ceil();
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy > radius * radius || !_inside(cx + dx, cy + dy)) {
          continue;
        }
        final i = (cy + dy) * width + cx + dx;
        switch (tool) {
          case AlchemyTool.erase:
            cells[i] = 0;
          case AlchemyTool.stir:
            final nx = cx + dx + (-dy * .45).round();
            final ny = cy + dy + (dx * .45).round() - 1;
            if (_inside(nx, ny) && random.nextDouble() < .4) {
              _swap(i, ny * width + nx);
            }
          case AlchemyTool.pour:
            if (random.nextDouble() < .28) put(cx + dx, cy + dy, e);
        }
      }
    }
  }

  void clear() {
    cells.fillRange(0, cells.length, 0);
    _ages.fillRange(0, _ages.length, 0);
    _moved.fillRange(0, _moved.length, 0);
    flashes.clear();
    journal.clear();
    reactionCount = 0;
    feeding = false;
  }

  void reset([AlchemyStudy next = AlchemyStudy.vapor]) {
    clear();
    study = next;
    feeding = true;
    final base = switch (next) {
      AlchemyStudy.vapor => AlchemyElement.water,
      AlchemyStudy.mineral => AlchemyElement.earth,
      AlchemyStudy.eclipse => AlchemyElement.dark,
    };
    for (var y = 140; y < height - 3; y++) {
      for (var x = 12; x < width - 12; x++) {
        if (y > 139 + pow((x - 64) / 22, 2)) put(x, y, base);
      }
    }
  }

  /// Returns true only for a known pair; every known contact yields its product.
  bool react(int i, int j) {
    if (i < 0 ||
        j < 0 ||
        i >= cells.length ||
        j >= cells.length ||
        cells[i] == 0 ||
        cells[j] == 0) {
      return false;
    }
    final recipe = recipes[_key(cells[i], cells[j])];
    if (recipe == null) return false;
    cells[i] = recipe.product.id;
    cells[j] = 0;
    _ages[i] = 0;
    _moved[i] = _moved[j] = tick;
    reactionCount++;
    if (flashes.length < 60) {
      flashes.add(AlchemyFlash(i % width, i ~/ width, recipe.product));
    }
    if (journal.isEmpty || journal.first != recipe) {
      journal.insert(0, recipe);
      if (journal.length > 4) journal.removeLast();
    }
    return true;
  }

  void _swap(int i, int j) {
    final id = cells[i], age = _ages[i];
    cells[i] = cells[j];
    cells[j] = id;
    _ages[i] = _ages[j];
    _ages[j] = age;
    _moved[i] = _moved[j] = tick;
  }

  bool _move(int i, int j) {
    if (j < 0 || j >= cells.length || !_inside(j % width, j ~/ width)) {
      return false;
    }
    if (cells[j] != 0) {
      final a = AlchemyElement.values[cells[i] - 1],
          b = AlchemyElement.values[cells[j] - 1];
      if (b.phase == MatterPhase.solid ||
          j <= i ||
          a.density <= b.density + .1 ||
          random.nextDouble() > .3) {
        return false;
      }
    }
    _swap(i, j);
    return true;
  }

  void step() {
    tick++;
    if (feeding && tick % 2 == 0) {
      final a = switch (study) {
        AlchemyStudy.vapor => AlchemyElement.water,
        AlchemyStudy.mineral => AlchemyElement.earth,
        AlchemyStudy.eclipse => AlchemyElement.dark,
      };
      final b = switch (study) {
        AlchemyStudy.vapor => AlchemyElement.fire,
        AlchemyStudy.mineral => AlchemyElement.lightning,
        AlchemyStudy.eclipse => AlchemyElement.light,
      };
      brush(58 + sin(tick * .025) * 9, 25, a, AlchemyTool.pour, 3);
      brush(69 + sin(tick * .02) * 5, 135, b, AlchemyTool.pour, 5);
    }
    for (var y = height - 4; y >= 2; y--) {
      for (var c = 2; c < width - 2; c++) {
        final x = tick.isEven ? c : width - 1 - c, i = y * width + x;
        final id = cells[i];
        if (id == 0 || _moved[i] == tick) continue;
        _ages[i] = min(65000, _ages[i] + 1);
        final d = random.nextBool() ? 1 : -1;
        if (react(i, i + d) ||
            react(i, i - d) ||
            react(i, i + width) ||
            react(i, i - width)) {
          continue;
        }
        final e = AlchemyElement.values[id - 1];
        if (e.phase == MatterPhase.solid) continue;
        if (e.phase == MatterPhase.gas) {
          if ((y < 8 || _ages[i] > 650) && random.nextDouble() < .06) {
            cells[i] = 0;
            continue;
          }
          final wind = (sin(y * .08 + tick * .016) + cos(x * .06 - tick * .013))
              .sign
              .toInt();
          if (random.nextDouble() < .8 &&
              (_move(i, i - width + wind) || _move(i, i + wind))) {
            continue;
          }
        } else {
          if ((e == AlchemyElement.lava || e == AlchemyElement.mud) &&
              random.nextBool()) {
            continue;
          }
          if (_move(i, i + width) ||
              _move(i, i + width + d) ||
              _move(i, i + width - d)) {
            continue;
          }
          if (e.phase == MatterPhase.liquid &&
              (_move(i, i + d) || _move(i, i - d))) {
            continue;
          }
        }
        _moved[i] = tick;
      }
    }
    for (final f in flashes) {
      f.life -= .045;
    }
    flashes.removeWhere((f) => f.life <= 0);
  }
}
