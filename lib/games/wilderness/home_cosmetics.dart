part of 'scene_game.dart';

// The Athanor's cosmetics in the home field (docs/athanor_design.md):
//
//  * TRAILS — a resident wearing one leaves it where it walks: a print
//    every ~0.32 of its size of ground walked, alternating feet, painted on
//    its row's ground, under everything standing there (priority 8: the
//    keepsakes stand at 9, the residents at 10). Standing still (asleep
//    too), the ground under it takes the trail in a patch that spreads and
//    stays while it stands. Where the field's grass grows over the feet,
//    the trail is laid on the grass tops too (priority 71, just over the
//    front grass at 70). Prints are kept from the resident's own spot, so
//    they stay put on the ground when the field loops round under the
//    camera. Nothing is laid by a floater, a resident lifted onto
//    something, going through a portal or bathing, nor while arranging;
//    nothing is stepped while asleep.
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

  /// Seconds it has stood still.
  double still = 0;
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
    // One gone from the field walked off whatever it stood on.
    for (final e in _walkers.entries) {
      if (!residents.containsKey(e.key)) e.value.prints.leave(time);
    }
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
        w?.prints.leave(time);
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
      final grounded =
          game.lively &&
          !game.arranging &&
          game._held != id &&
          l.trip == null &&
          l.fade > 0.95 &&
          l.lift.abs() < size * 0.06 &&
          !comp.submerged;
      // A jump (a reset, a portal) is not a walk.
      if (!grounded || moved > size * 0.5) {
        w.walked = 0;
        w.still = 0;
        w.prints.leave(time);
        continue;
      }
      final drop = game._standDrop[id] ?? size * 0.46;
      // Still (a walk is a third of its width a second): after a moment,
      // the ground under it takes the trail. Moving, it walks off it.
      if (dt > 0 && moved / dt < size * 0.05) {
        w.still += dt;
        if (w.still > 0.6) {
          w.prints.stand(
            dx,
            game._life._groundShift(sp, dx) + drop,
            time,
            size: size * 0.2,
          );
        }
      } else if (dt > 0) {
        w.still = 0;
        w.prints.leave(time);
      }
      if (l.act == _Act.asleep) continue;
      w.walked += moved;
      final stride = size * 0.32;
      if (w.walked < stride) continue;
      w.walked -= stride;
      final near = w.foot.isEven;
      w.foot++;
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
    final art = game._layers[layer];
    final container = art?.container;
    if (container == null) return;
    _mounted.add(layer);
    container.add(_TrailLayer(this, layer)..priority = 8);
    if (art is _ArtLayer && art.art.grassOverFeet(layer)) {
      container.add(_TrailLayer(this, layer, onGrass: true)..priority = 71);
    }
  }
}

/// A row's trails, on its ground — or, [onGrass], on the tops of the grass
/// that grows over the feet there.
class _TrailLayer extends Component with HasGameReference<SceneGame> {
  _TrailLayer(this.trails, this.layer, {this.onGrass = false})
    : _ground = CosmeticAtlas(
        _residents *
            (onGrass ? TrailPrints.grassEntries : TrailPrints.groundEntries),
      ),
      _light = CosmeticAtlas(
        _residents *
            (onGrass
                ? TrailPrints.grassLightEntries
                : TrailPrints.lightEntries),
      );

  /// Residents on a row, at most, for sizing the atlases.
  static const int _residents = 12;

  final _HomeTrails trails;
  final SceneLayer layer;
  final bool onGrass;

  final CosmeticAtlas _ground;
  final CosmeticAtlas _light;

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
      if (onGrass) {
        w.prints.paintSurface(
          _ground,
          _light,
          time,
          ox: anchor.position.x - o.dx,
          oy: anchor.position.y - o.dy,
        );
        continue;
      }
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

/// What the season sheds into the air over a home with trees: leaves in
/// autumn, petals in spring, over the near row's residents.
class _SeasonDrift {
  _SeasonDrift(this.game);

  final SceneGame game;
  bool _mounted = false;

  void update() {
    if (_mounted) return;
    final art = game._art;
    if (art == null || !art.shedsInSeason) return;
    final container = game._layers[SceneLayer.layer4]?.container;
    if (container == null) return;
    _mounted = true;
    container.add(_SeasonDriftLayer()..priority = 64);
  }
}

class _SeasonDriftLayer extends Component with HasGameReference<SceneGame> {
  final CosmeticAtlas _over = CosmeticAtlas(220);

  @override
  void render(Canvas canvas) {
    final art = game._art;
    final season = art?.season;
    if (art == null || !seasonSheds(season)) return;
    final shown = art.seasonAmount;
    if (shown <= 0.004) return;
    final container = parent;
    if (container is! PositionComponent) return;
    final view = game._fieldViewFor(container.position.x);
    double? ground(double x) {
      final g = art.groundAt(SceneLayer.layer4, x)?.rest;
      return g != null && g.isFinite ? g : null;
    }

    paintSeasonDrift(
      season!,
      AmbienceView(
        left: view.left,
        right: view.right,
        top: view.top,
        bottom: view.bottom,
        height: view.height,
        time: view.time,
        ground: ground,
      ),
      shown,
      _over,
    );
    _over.draw(canvas);
  }
}

/// The ground where residents live, taking on their elements over days
/// (ground_mark_art.dart), and what those who moved or left left behind,
/// fading: on each row's ground, under the trails.
class _HomeMarks {
  _HomeMarks(this.game);

  final SceneGame game;
  final Set<SceneLayer> _mounted = {};

  void update() {
    if (game.markOf == null &&
        game.fadingMarks.isEmpty &&
        game.harmonies.isEmpty &&
        game.buried == null) {
      return;
    }
    final layers = <SceneLayer>{
      if (game.buried case final b?) b.layer,
      for (final id in game._residents.keys)
        if (game._pointOf(id) case final sp?) sp.anchor,
      for (final m in game.fadingMarks) m.layer,
    };
    for (final layer in layers) {
      if (_mounted.contains(layer)) continue;
      final container = game._layers[layer]?.container;
      if (container == null) continue;
      _mounted.add(layer);
      container
        ..add(_MarkLayer(layer)..priority = 7)
        ..add(_HarmonyLayer(layer)..priority = 60);
    }
  }
}

class _MarkLayer extends Component with HasGameReference<SceneGame> {
  _MarkLayer(this.layer);

  final SceneLayer layer;
  final CosmeticAtlas _over = CosmeticAtlas(12 * 30 + 24 * 30);
  final CosmeticAtlas _light = CosmeticAtlas(12 * 30 + 24 * 30);

  @override
  void render(Canvas canvas) {
    final time = game._fieldTime;
    final of = game.markOf;
    if (of != null) {
      for (final e in game._residents.entries) {
        final id = e.key;
        final sp = game._pointOf(id);
        final anchor = game._spawnPointComps[id];
        if (sp == null || anchor == null || sp.anchor != layer) continue;
        if (sp.aloft) continue;
        final element = game._residentLooks[id]?.$1.types.firstOrNull;
        if (!elementMarks(element)) continue;
        final strength = of(id);
        if (strength <= 0.01) continue;
        // Its own spot: the anchor goes where it walks.
        final o = game._life.offsetOf(id) ?? Offset.zero;
        paintGroundMark(
          element!,
          strength,
          anchor.position.x - o.dx,
          anchor.position.y - o.dy + (game._standDrop[id] ?? sp.size.x * 0.46),
          sp.size.x,
          time,
          id.hashCode & 0xFFFF,
          _over,
          _light,
        );
      }
    }
    // Where something lies buried, while the place shows it.
    if (game.buried case final cue? when cue.layer == layer) {
      final p = game._buriedAt(cue);
      if (p != null) {
        paintBuriedCue(
          p.dx,
          p.dy,
          cue.size,
          cue.color,
          time,
          game._buriedRise,
          _over,
          _light,
        );
      }
    }
    // What a pair in harmony makes, lying on the ground between them.
    for (final (a, b, makes) in game.harmonies) {
      final ends = game._harmonyEnds(a, b, layer, chest: false);
      if (ends == null) continue;
      final (pa, pb, size) = ends;
      final mid = Offset.lerp(pa, pb, 0.5)!;
      paintGroundMark(
        makes,
        0.9,
        mid.dx,
        mid.dy,
        size * 0.8,
        time,
        (a.hashCode ^ b.hashCode) & 0xFFFF,
        _over,
        _light,
      );
    }
    final fading = game.fadingMarks;
    if (fading.isNotEmpty) {
      final container = parent;
      if (container is PositionComponent) {
        final view = game._fieldViewFor(container.position.x);
        final mid = (view.left + view.right) / 2;
        for (final m in fading) {
          if (m.layer != layer || m.strength <= 0.01) continue;
          final x = m.period > 0
              ? m.x + m.period * ((mid - m.x) / m.period).roundToDouble()
              : m.x;
          if (x < view.left - m.size * 2 || x > view.right + m.size * 2) {
            continue;
          }
          final feet = m.feet * view.height;
          final g = game._art?.groundAt(layer, x, toward: feet)?.rest;
          paintGroundMark(
            m.element,
            m.strength,
            x,
            g != null && g.isFinite ? g : feet,
            m.size,
            time,
            m.seed,
            _over,
            _light,
          );
        }
      }
    }
    _over.draw(canvas);
    _light.draw(canvas, blend: BlendMode.plus);
  }
}

/// The home left alone: after [SceneGame.idleTourAfter] seconds with no
/// finger on it, the camera drifts in a little and goes from one resident
/// to another — to whoever is doing something, if anyone is — staying with
/// each a while. A touch ends it, and the camera eases back out.
class _IdleTour {
  _IdleTour(this.game);

  final SceneGame game;

  double _untouched = 0;
  bool _touring = false;
  double _fromZoom = 1;
  double _stay = 0;
  int _turn = 0;
  String? _with;

  /// How long it stays with each, and how close it comes.
  static const _staySeconds = 9.0, _closer = 1.3;

  void touched() {
    _untouched = 0;
    if (_touring) _end();
  }

  void update(double dt) {
    final after = game.idleTourAfter;
    final ids = game._residents.keys.toList();
    if (after <= 0 ||
        game.arranging ||
        game.viewLocked ||
        game._held != null ||
        ids.isEmpty) {
      _untouched = 0;
      if (_touring) _end();
      return;
    }
    _untouched += dt;
    if (!_touring) {
      if (_untouched < after) return;
      _touring = true;
      _fromZoom = game.cam.viewfinder.zoom;
      _stay = 0;
    }
    _stay -= dt;
    if (_stay <= 0 || _with == null || !ids.contains(_with)) {
      _stay = _staySeconds;
      _with = _next(ids);
      game.zoomTo(_fromZoom * _closer);
    }
    final id = _with;
    if (id != null) game.lookAt(id);
  }

  /// Whoever is doing something — walking, on a visit, going through a
  /// portal — before whoever is not; each in its turn.
  String? _next(List<String> ids) {
    _turn++;
    final busy = [
      for (final id in ids)
        if (game._life._livers[id] case final l?
            when l.call != null || l.trip != null || l.act == _Act.stroll)
          id,
    ];
    final from = busy.isNotEmpty ? busy : ids;
    final pick = from[_turn % from.length];
    // Not the same one twice running, if there is anyone else.
    if (pick == _with && ids.length > 1) {
      return ids[(ids.indexOf(pick) + 1) % ids.length];
    }
    return pick;
  }

  void _end() {
    _touring = false;
    _with = null;
    game.zoomTo(_fromZoom);
  }
}

/// The threads between residents in harmony, over them.
class _HarmonyLayer extends Component with HasGameReference<SceneGame> {
  _HarmonyLayer(this.layer);

  final SceneLayer layer;
  final CosmeticAtlas _light = CosmeticAtlas(12 * 64);

  @override
  void render(Canvas canvas) {
    if (game.harmonies.isEmpty) return;
    final night = nightAt(game.fieldHour);
    for (final (a, b, makes) in game.harmonies) {
      final ends = game._harmonyEnds(a, b, layer, chest: true);
      if (ends == null) continue;
      final ea = game._residentLooks[a]?.$1.types.firstOrNull;
      final eb = game._residentLooks[b]?.$1.types.firstOrNull;
      if (ea == null || eb == null) continue;
      final (pa, pb, size) = ends;
      paintHarmonyThread(
        pa,
        pb,
        ea,
        eb,
        makes,
        size,
        game._fieldTime,
        night,
        _light,
      );
    }
    _light.draw(canvas, blend: BlendMode.plus);
  }
}

/// The land's form showing itself (form_feature_art.dart): its site on the
/// near row's ground and what happens there, under the residents and over
/// them; its clock running, its reveal playing.
class _FormFeatures {
  _FormFeatures(this.game);

  final SceneGame game;
  SceneLayer? _mountedOn;
  bool _frontMounted = false;

  void update(double dt) {
    final site = game.formSite;
    if (site == null || game.formFeatures <= 0) return;
    game._formClock += dt;
    if (game._formRevealing) {
      game._formReveal = math.min(1, game._formReveal + dt / 6);
      if (game._formReveal >= 1) game._formRevealing = false;
    }
    if (_mountedOn != site.layer) {
      final container = game._layers[site.layer]?.container;
      if (container != null) {
        _mountedOn = site.layer;
        container.add(_FormLayer(front: false)..priority = 8);
      }
    }
    if (!_frontMounted) {
      final container = game._layers[site.layer]?.container;
      if (container != null) {
        _frontMounted = true;
        container.add(_FormLayer(front: true)..priority = 66);
      }
    }
  }
}

class _FormLayer extends Component with HasGameReference<SceneGame> {
  _FormLayer({required this.front});

  final bool front;
  final CosmeticAtlas _over = CosmeticAtlas(2000);
  final CosmeticAtlas _light = CosmeticAtlas(1600);

  @override
  void render(Canvas canvas) {
    final site = game.formSite;
    final art = game._art;
    final amount = game.formFeatures;
    final form = art?.form;
    if (site == null || art == null || form == null || amount <= 0) return;
    final container = parent;
    if (container is! PositionComponent) return;
    final layer = site.layer;
    final view = game._fieldViewFor(container.position.x);
    final mid = (view.left + view.right) / 2;
    final x = site.period > 0
        ? site.x + site.period * ((mid - site.x) / site.period).roundToDouble()
        : site.x;
    final feet = site.feet * view.height;
    double? ground(double gx) {
      final g = art.groundAt(layer, gx, toward: feet)?.rest;
      if (g != null && g.isFinite) return g;
      // A field with no ground to give (Living Sands, the Core) lays it
      // on the row's own feet.
      return art is HomeSandField || art is HomeCoreField ? feet : null;
    }

    final residents = [
      for (final e in game._residents.entries)
        if (game._pointOf(e.key) case final sp?
            when sp.anchor == layer && !sp.aloft)
          if (game._spawnPointComps[e.key] case final a?)
            FormFoot(
              a.position.x,
              a.position.y + (game._standDrop[e.key] ?? sp.size.x * 0.46),
              sp.size.x,
              e.key.hashCode & 0xFFFF,
            ),
    ];
    final p = lunarPhase(DateTime.now());
    final v = FormView(
      form: form,
      left: view.left,
      right: view.right,
      top: view.top,
      bottom: view.bottom,
      height: view.height,
      time: game._formClock,
      ground: ground,
      siteX: x,
      siteY: ground(x) ?? feet,
      size: site.size,
      reveal: game._formReveal,
      amount: amount,
      night: nightAt(game.fieldHour),
      feet: residents,
      fullMoon: (p - 0.5).abs() < 0.04,
    );
    if (front) {
      paintFormFront(v, canvas, _over, _light);
    } else {
      paintFormBack(v, canvas, _over, _light);
    }
    _over.draw(canvas);
    _light.draw(canvas, blend: BlendMode.plus);
  }
}
