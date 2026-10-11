part of 'scene_game.dart';

// The Athanor's cosmetics in the home field (docs/athanor_design.md):
//
//  * TRAILS — a resident wearing one leaves it where it walks: a print
//    every ~0.55 of its size of ground walked, alternating feet, painted on
//    its row's ground, under everything standing there (priority 8: the
//    keepsakes stand at 9, the residents at 10). Prints are kept from the
//    resident's own spot, so they stay put on the ground when the field
//    loops round under the camera. Nothing is stepped on a floater, on a
//    resident lifted onto something, asleep, going through a portal or
//    bathing, nor while arranging.
//  * AMBIENCE — one per realm, laid over the field at its hour (over the
//    near row's residents, under its front grass); the mist is laid on the
//    far row too. It never announces itself.
//
// Each is one or two atlas draws a layer, whatever is in it.

/// One resident's trail and how far it has walked since its last print.
class _Walker {
  _Walker(this.prints, this.layer);

  final TrailPrints prints;
  SceneLayer layer;
  double? lastDx;
  double walked = 0;
  int foot = 0;
}

class _HomeTrails {
  _HomeTrails(this.game);

  final SceneGame game;

  /// By spawn id. Kept after a resident leaves until its prints are gone.
  final Map<String, _Walker> _walkers = {};
  final Set<SceneLayer> _mounted = {};

  void update(double dt) {
    final time = game._fieldTime;
    final of = game.trailOf;
    final residents = game._residents;
    _walkers.removeWhere(
      (id, w) => !residents.containsKey(id) && !w.prints.aliveAt(time),
    );
    if (of == null) return;
    for (final e in residents.entries) {
      final id = e.key;
      final comp = e.value;
      final instance = game._residentLooks[id]?.$2;
      final style = instance == null ? null : of(instance.instanceId);
      final sp = game._pointOf(id);
      var w = _walkers[id];
      if (style == null || sp == null || sp.aloft) {
        // Taken off (or flying): what it left fades on its own.
        w?.lastDx = null;
        continue;
      }
      if (w == null || w.prints.style != style) {
        w = _walkers[id] = _Walker(TrailPrints(style), sp.anchor);
      }
      w.layer = sp.anchor;
      _mount(sp.anchor);
      final l = game._life._livers[id];
      final dx = l?.dx ?? 0;
      final last = w.lastDx;
      w.lastDx = dx;
      if (last == null || l == null) continue;
      final size = sp.size.x;
      final moved = (dx - last).abs();
      final onFoot =
          game.lively &&
          !game.arranging &&
          game._held != id &&
          l.act != _Act.asleep &&
          l.trip == null &&
          l.fade > 0.95 &&
          l.lift.abs() < size * 0.06 &&
          !comp.submerged;
      // A jump (a reset, a portal) is not a walk.
      if (!onFoot || moved > size * 0.5) {
        w.walked = 0;
        continue;
      }
      w.walked += moved;
      final stride = size * 0.55;
      if (w.walked < stride) continue;
      w.walked -= stride;
      final near = w.foot.isEven;
      w.foot++;
      final drop = game._standDrop[id] ?? size * 0.46;
      w.prints.step(
        dx + (near ? -1 : 1) * size * 0.05,
        game._life._groundShift(sp, dx) + drop + (near ? 1 : -1) * size * 0.025,
        time,
        size: size * 0.2,
      );
    }
  }

  void _mount(SceneLayer layer) {
    if (_mounted.contains(layer)) return;
    final container = game._layers[layer]?.container;
    if (container == null) return;
    _mounted.add(layer);
    container.add(_TrailLayer(this, layer)..priority = 8);
  }
}

/// A row's trails, on its ground.
class _TrailLayer extends Component with HasGameReference<SceneGame> {
  _TrailLayer(this.trails, this.layer);

  final _HomeTrails trails;
  final SceneLayer layer;

  final CosmeticAtlas _ground = CosmeticAtlas(
    12 * 14 * TrailPrints.entriesPerPrint,
  );
  final CosmeticAtlas _light = CosmeticAtlas(12 * 14 * 4);

  @override
  void render(Canvas canvas) {
    final time = game._fieldTime;
    for (final e in trails._walkers.entries) {
      final w = e.value;
      if (w.layer != layer || w.prints.isEmpty) continue;
      final anchor = game._spawnPointComps[e.key];
      if (anchor == null) continue;
      // The resident's own spot, wherever the loop has put it.
      final o = game._life.offsetOf(e.key) ?? Offset.zero;
      w.prints.paint(
        _ground,
        _light,
        time,
        ox: anchor.position.x - o.dx,
        oy: anchor.position.y - o.dy,
      );
    }
    _ground.draw(canvas);
    _light.draw(canvas, blend: BlendMode.plus);
  }
}

class _HomeAmbience {
  _HomeAmbience(this.game);

  final SceneGame game;
  final Set<SceneLayer> _mounted = {};

  /// How far in the worn ambience is (it eases in and out on a change).
  double fade = 0;
  HomeAmbience? showing;

  void update(double dt) {
    final want = game.ambience;
    if (want != showing) {
      // The old one thins out before the new one comes in.
      fade = math.max(0, fade - dt / 1.2);
      if (fade <= 0) showing = want;
    } else if (want != null) {
      fade = math.min(1, fade + dt / 1.6);
    }
    if (showing == null) return;
    for (final layer in const [SceneLayer.layer3, SceneLayer.layer4]) {
      if (_mounted.contains(layer)) continue;
      final container = game._layers[layer]?.container;
      if (container == null) continue;
      _mounted.add(layer);
      container.add(
        _AmbienceLayer(this, layer, near: layer == SceneLayer.layer4)
          ..priority = 65,
      );
    }
  }
}

/// An ambience over one row: the whole view from the near row, only the
/// mist on its ground from the far one.
class _AmbienceLayer extends Component with HasGameReference<SceneGame> {
  _AmbienceLayer(this.ambience, this.layer, {required this.near});

  final _HomeAmbience ambience;
  final SceneLayer layer;
  final bool near;

  final CosmeticAtlas _over = CosmeticAtlas(640);
  final CosmeticAtlas _light = CosmeticAtlas(1100);

  // The ground across the view, sampled once a frame.
  static const int _columns = 40;
  final List<double?> _groundY = List.filled(_columns + 1, null);
  double _gx0 = 0, _gStep = 1;

  final List<Offset> _feet = [];

  double? _groundAt(double x) {
    final f = (x - _gx0) / _gStep;
    final i = f.floor();
    if (i < 0 || i >= _columns) return null;
    final a = _groundY[i], b = _groundY[i + 1];
    if (a == null || b == null) return a ?? b;
    return a + (b - a) * (f - i);
  }

  @override
  void render(Canvas canvas) {
    final a = ambience.showing;
    if (a == null || ambience.fade <= 0) return;
    final container = parent;
    if (container is! PositionComponent) return;
    final view = game._fieldViewFor(container.position.x);
    final shown =
        ambience.fade *
        ambienceShows(a, view.hour, clear: game.fieldWeather == null);
    if (shown <= 0.004) return;
    if (!near && a != HomeAmbience.peatMist) return;
    final art = game._art;
    // The ground: the field's, or for a field that has none to give (a
    // realm drawn from images), a line low in the view.
    final pad = (view.right - view.left) * 0.15;
    _gx0 = view.left - pad;
    _gStep = (view.right - view.left + pad * 2) / _columns;
    var any = false;
    for (var i = 0; i <= _columns; i++) {
      // Where a creature stands (a bank's top may be unbounded).
      final g = art?.groundAt(layer, _gx0 + i * _gStep)?.rest;
      _groundY[i] = g != null && g.isFinite ? g : null;
      if (_groundY[i] != null) any = true;
    }
    if (!any) {
      final fallback = view.top + (view.bottom - view.top) * 0.86;
      for (var i = 0; i <= _columns; i++) {
        _groundY[i] = fallback;
      }
    }
    _feet.clear();
    var rowSize = 100.0;
    for (final id in game._residents.keys) {
      final sp = game._pointOf(id);
      final anchor = game._spawnPointComps[id];
      if (sp == null || anchor == null || sp.anchor != layer) continue;
      rowSize = sp.size.x;
      _feet.add(
        Offset(
          anchor.position.x,
          anchor.position.y + (game._standDrop[id] ?? sp.size.x * 0.46),
        ),
      );
    }
    paintHomeAmbience(
      a,
      AmbienceView(
        left: view.left,
        right: view.right,
        top: view.top,
        bottom: view.bottom,
        height: view.height,
        time: view.time,
        ground: _groundAt,
        feet: _feet,
        rowSize: rowSize,
      ),
      shown,
      _over,
      _light,
      grounded: !near,
    );
    _over.draw(canvas);
    _light.draw(canvas, blend: BlendMode.plus);
  }
}
