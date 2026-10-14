part of 'scene_game.dart';

// The wild's life: what the player finds in a field is not posed. Each wild
// Alchemon strolls the ground it stands on — never off its rock, its isle or
// its pool — turns to look at its neighbours and at a finger in the grass,
// and goes back to its place now and then. What can fly (wings, Air, Steam,
// Lightning, Spirit; see [speciesCanFloat]) hangs and drifts where it is in
// the air, and where it stands on the ground it takes off now and then,
// flies a while over its ground and comes down again.
//
// Tapped, it goes back to its place and down out of the air, and the
// encounter is met there: the partner's ground is built beside that place.
//
// It is the home biome's life (home_life.dart) without the keepsakes, the
// portals or the night's sleep: wild things are about at night too.

/// A flight off the ground: how high it means to go, how high it is, and
/// how much longer it stays up.
class _Flight {
  _Flight({required this.alt, required this.time});

  final double alt;
  double height = 0;
  double time;
}

class _WildLife extends _HomeLife {
  _WildLife(super.game);

  /// Flights under way, by point.
  final Map<String, _Flight> _flights = {};

  /// The creature each lifted flyer was lifted as: what is raised off its
  /// anchor is put down again, and nothing else is touched (a harvest drives
  /// the creature it plays on itself).
  final Map<String, WildMonComponent> _raised = {};

  /// Which creatures the walks were worked out among: when the batch
  /// changes, every walk is worked out again.
  int _among = 0;

  @override
  void update(double dt) {
    final wilds = game._wildBySpawnId;
    _livers.removeWhere(
      (id, _) =>
          !wilds.containsKey(id) && !game._hiddenWildBySpawnId.containsKey(id),
    );
    _flights.removeWhere((id, _) => !_livers.containsKey(id));
    _raised.removeWhere((id, _) => !_livers.containsKey(id));
    final among = Object.hashAllUnordered(wilds.keys);
    if (among != _among) {
      _among = among;
      for (final l in _livers.values) {
        l.range = null;
      }
    }
    final still =
        game._mode != SceneMode.exploration ||
        game.isTutorialMode ||
        !game.wildLively;
    for (final e in wilds.entries) {
      final comp = e.value;
      final sp = game._pointOf(e.key);
      if (sp == null || !comp.isLoaded) continue;
      final l = _livers.putIfAbsent(
        e.key,
        () =>
            _Liver(e.key, e.key.hashCode & 0xFFFF)
              ..wait = 0.5 + _rng.nextDouble() * 3,
      );
      if (still) {
        _goHome(l, comp, sp, dt);
      } else if (sp.aloft) {
        _hover(l, comp, sp, dt);
      } else {
        _roam(l, comp, sp, dt);
      }
      _lift(l, comp);
    }
  }

  /// How far it is from its place (layer units); the height it has flown
  /// up is on the creature itself, so its image in the glass stays on the
  /// glass.
  @override
  Offset? offsetOf(String spawnId) {
    final l = _livers[spawnId];
    if (l == null || (l.dx == 0 && l.dy == 0)) return null;
    return Offset(l.dx, l.dy);
  }

  @override
  List<double> _residentsOn(SpawnPoint sp) => [
    for (final id in game._wildBySpawnId.keys)
      if (id != sp.id)
        if (game._pointOf(id) case final o?
            when o.anchor == sp.anchor && !o.aloft)
          game._loopDelta(id, sp.id),
  ];

  /// What wades stays in its pool.
  @override
  (double, double) _rangeOf(SpawnPoint sp) =>
      sp.perch == SpawnPerch.wade ? (0, 0) : super._rangeOf(sp);

  /// On the ground: a finger, a flight, or what it chose last.
  void _roam(_Liver l, WildMonComponent comp, SpawnPoint sp, double dt) {
    final size = sp.size.x;
    final flight = _flights[l.id];
    if (flight != null) {
      _fly(l, comp, sp, flight, dt);
      return;
    }
    if (_heed(l, comp, dt)) {
      _walk(l, comp, sp, dt, size);
      return;
    }
    l.wait -= dt;
    if (l.wait <= 0 && (l.target - l.dx).abs() < 0.5) _pick(l, comp, sp);
    _walk(l, comp, sp, dt, size);
  }

  /// What it does next: take off, look at a neighbour, wander, or go back
  /// to its place.
  void _pick(_Liver l, WildMonComponent comp, SpawnPoint sp) {
    final size = sp.size.x;
    final range = l.range ??= _rangeOf(sp);
    final roll = _rng.nextDouble();
    final room = range.$2 - range.$1 > size * 0.12;
    l
      ..act = _Act.idle
      ..wait = 2 + _rng.nextDouble() * 4;
    if (speciesCanFloat(comp.speciesId) && roll < 0.32) {
      _flights[l.id] = _Flight(
        alt: size * (0.45 + _rng.nextDouble() * 0.4),
        time: 2.5 + _rng.nextDouble() * 4,
      );
      l.target = room
          ? range.$1 + _rng.nextDouble() * (range.$2 - range.$1)
          : l.dx;
      return;
    }
    if (roll < 0.45) {
      final n = _nearestNeighbour(sp, size * 3.2);
      if (n != null) {
        l.act = _Act.look;
        comp.face(n - l.dx > 0 ? -1 : 1);
        return;
      }
    }
    if (roll < 0.85 && room) {
      l
        ..act = _Act.stroll
        ..target = range.$1 + _rng.nextDouble() * (range.$2 - range.$1);
      return;
    }
    // Back to its place; on a rock or in a pool, it looks the other way.
    l.target = 0;
    if (!room) comp.face(-comp.facing);
  }

  /// Up off the ground, along over it, and down again where its ground
  /// is.
  void _fly(
    _Liver l,
    WildMonComponent comp,
    SpawnPoint sp,
    _Flight f,
    double dt,
  ) {
    final size = sp.size.x;
    f.time -= dt;
    final up = f.time > 0 ? f.alt : 0.0;
    f.height += (up - f.height) * (1 - math.exp(-dt * 1.7));
    final k = (f.height / f.alt).clamp(0.0, 1.0);
    final bob = math.sin(game._fieldTime * 2.3 + l.seed) * 4 * _u * k;
    l.lift = math.max(0.0, f.height + bob);
    final d = l.target - l.dx;
    if (d.abs() > 0.5) {
      l.dx += d.sign * math.min(d.abs(), size * 0.5 * dt * (0.3 + 0.7 * k));
      comp.face(d > 0 ? -1 : 1);
    }
    l.dy = _groundShift(sp, l.dx);
    if (f.time <= 0 && f.height < 0.5) {
      l
        ..lift = 0
        ..target = l.dx
        ..wait = 1.5 + _rng.nextDouble() * 3;
      _flights.remove(l.id);
    }
  }

  /// Back to its place, briskly, and down out of the air, facing as it
  /// was put: an encounter is met there.
  void _goHome(_Liver l, WildMonComponent comp, SpawnPoint sp, double dt) {
    _flights.remove(l.id);
    l.heedFor = 0;
    if (l.dx == 0 && l.dy == 0 && l.lift == 0) {
      if (!l.settled) {
        l
          ..settled = true
          ..target = 0
          ..act = _Act.idle
          ..wait = 1 + _rng.nextDouble() * 2;
        comp.face(1);
      }
      return;
    }
    l.settled = false;
    final size = sp.size.x;
    final step = size * 1.1 * dt;
    if (l.dx.abs() <= step) {
      l.dx = 0;
    } else {
      l.dx -= l.dx.sign * step;
      comp.face(l.dx < 0 ? -1 : 1);
    }
    l.target = l.dx;
    l.dy = sp.aloft
        ? (l.dy.abs() <= step ? 0 : l.dy - l.dy.sign * step)
        : _groundShift(sp, l.dx);
    l.lift = l.lift <= step ? 0 : l.lift - step;
  }

  /// Holds the creature up off its anchor by the height it has flown.
  void _lift(_Liver l, WildMonComponent comp) {
    if (l.lift == 0 && !identical(_raised[l.id], comp)) return;
    comp.position.y = -l.lift;
    if (l.lift == 0) {
      _raised.remove(l.id);
    } else {
      _raised[l.id] = comp;
    }
  }
}
