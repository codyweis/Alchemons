part of 'scene_game.dart';

// The home biome's life: the player's own creatures, left alone in their
// field, live in it. Each strolls the ground it stands on — never off its
// isle, bank or shelf — turns to look at its neighbours and at a finger in
// the grass, and goes to the keepsakes it can reach, each of which it does
// something with (see [_visits]): it warms itself at a torch and sleeps
// beside it, climbs into the Giant's Palm, hops in time with the pipes and
// the beating heart, dashes through the arch, reads the book and looks
// through the telescope at night, bows at the headstone and the effigy.
// One of the keepsake's own element stirs it hardest. Where a pair of
// portals stands, it walks into one and out of the other. Floaters hang and
// drift, and ride the wind round the vane. At night what stands falls
// asleep: still, its frames held, breathing — after the night's keepsakes
// have had their visitors.
//
// Tapping a keepsake (not arranging) calls the nearest resident that can
// reach it.
//
// Nothing here is saved: a resident's place is where the player put it,
// and it always comes back there. Arranging, everyone stands still at their
// own spots so they can be taken hold of.

/// Something a showcase field holds that is not a creature: a keepsake.
/// What lives in the field visits it.
abstract interface class FieldThing {
  /// What it is (the keepsake's id).
  String get thingKind;

  /// Something has come to it, or gone through it — harder for one of its
  /// own element ([strength] over 1).
  void stir([double strength = 1]);

  /// Where something can sit on it, how far above its feet (layer units);
  /// null for nowhere.
  double? get seat;

  /// Every place visitors sit or stand on it now: along from its feet and
  /// how far up (negative, down into water), layer units.
  List<Offset> get seats;

  /// Stood in only to be tried: nobody visits it.
  bool get ghost;
}

/// The two-portal keepsake's kind: what walks into one walks out of the
/// other.
const String kPortalThing = 'twin_portals';

/// What a resident does at a keepsake.
enum _Do {
  /// Stands by it and looks at it.
  look,

  /// Stands close, warming itself; at night it sleeps there.
  warm,

  /// Hops in time with it.
  hop,

  /// Bows its head to it, slowly.
  bow,

  /// Climbs up onto it and sits there a while.
  climb,

  /// Runs through it and back.
  dash,

  /// Turns this way and that before it, as before a mirror.
  preen,

  /// Stands under it while the weather lasts (rain, snow, storm).
  shelter,

  /// Gets up on it and performs; others gather to watch ([watch]).
  perform,

  /// Stands at one side of it watching whoever performs there.
  watch,
}

/// A keepsake's visit: what is done there, for how long, whether it is a
/// keepsake of the night (visited before sleeping, and stayed awake for),
/// and whose element stirs it hardest.
class _Visit {
  const _Visit(
    this.act, {
    this.seconds = 6,
    this.night = false,
    this.elements = const {},
    this.beat,
    this.bed = false,
  });

  final _Do act;
  final double seconds;
  final bool night;
  final Set<String> elements;

  /// Somewhere to sleep: by night a visitor that gets up on it stays there
  /// asleep until morning.
  final bool bed;

  /// Whether it is done at one of the keepsake's seats (see
  /// [FieldThing.seats]), each taken by one visitor at a time.
  bool get seated =>
      act == _Do.climb ||
      act == _Do.shelter ||
      act == _Do.perform ||
      act == _Do.watch;

  /// The keepsake's beat for hopping, seconds per hop.
  final double? beat;
}

const _visits = <String, _Visit>{
  'ember_torch': _Visit(_Do.warm, seconds: 9, night: true, elements: {'Fire', 'Lava'}),
  'four_winds': _Visit(_Do.look, elements: {'Air', 'Steam'}),
  'frozen_moon': _Visit(_Do.bow, seconds: 7, elements: {'Water', 'Ice'}),
  'giants_palm': _Visit(_Do.climb, seconds: 8, elements: {'Earth', 'Crystal'}),
  'fulgurite': _Visit(_Do.look, seconds: 5, elements: {'Lightning'}),
  'harmony_pipes': _Visit(_Do.hop, seconds: 6.4, beat: 0.8, elements: {'Steam', 'Air'}),
  'black_glass': _Visit(_Do.preen, seconds: 6, elements: {'Lava', 'Dark'}),
  'the_dose': _Visit(_Do.bow, seconds: 5, elements: {'Poison'}),
  'mud_lotus': _Visit(_Do.look, seconds: 8, elements: {'Mud', 'Plant', 'Water'}),
  'star_walker': _Visit(_Do.look, seconds: 12, night: true, elements: {'Ice', 'Light'}),
  'hourglass': _Visit(_Do.look, seconds: 7, elements: {'Dust', 'Earth'}),
  'know_thyself': _Visit(_Do.preen, seconds: 6, elements: {'Crystal'}),
  'opposite_flower': _Visit(_Do.look, seconds: 7, elements: {'Plant'}),
  'lancet_stone': _Visit(_Do.bow, seconds: 8, night: true, elements: {'Spirit'}),
  'night_book': _Visit(_Do.look, seconds: 12, night: true, elements: {'Light', 'Spirit'}),
  'garnet_heart': _Visit(_Do.hop, seconds: 6, beat: 0.75, elements: {'Blood'}),
  'crown_mirror': _Visit(_Do.preen, seconds: 6),
  'victory_arch': _Visit(_Do.dash, seconds: 5, elements: {'Lightning', 'Air'}),
  'titan_anvil': _Visit(_Do.climb, seconds: 5, elements: {'Fire', 'Earth'}),
  'prism_orrery': _Visit(_Do.look, seconds: 7, elements: {'Crystal', 'Light'}),
  // Bought decor (models/home_decor.dart). The Curios are only to look at.
  'wind_chimes': _Visit(_Do.look, seconds: 5, elements: {'Air', 'Steam'}),
  'fountain': _Visit(_Do.bow, seconds: 6, elements: {'Water', 'Ice'}),
  'rest_nest': _Visit(_Do.climb, seconds: 6, night: true, bed: true),
  'swing': _Visit(_Do.climb, seconds: 10, elements: {'Air'}),
  'canopy': _Visit(_Do.shelter, seconds: 6),
  'mushroom_ring': _Visit(_Do.hop, seconds: 6, beat: 0.6, elements: {'Plant', 'Mud', 'Poison'}),
  'hot_spring': _Visit(_Do.climb, seconds: 14, night: true, elements: {'Water', 'Steam', 'Lava', 'Fire'}),
  'elder_tree': _Visit(_Do.climb, seconds: 9, night: true, bed: true, elements: {'Plant', 'Earth'}),
  'stage': _Visit(_Do.perform, seconds: 9, beat: 0.7),
  'orrery': _Visit(_Do.climb, seconds: 13, elements: {'Crystal', 'Light'}),
  'reflecting_pool': _Visit(_Do.preen, seconds: 7, elements: {'Water', 'Dark'}),
};

/// Decor that is only to look at, never visited.
const _stillDecor = {
  'lantern_post',
  'candles',
  'geode',
  'rune_stone',
  'banner',
  'planter',
  'sky_lanterns',
  'flyer_perch',
};

_Visit? _visitOf(String kind) {
  if (kind.startsWith('effigy:')) return const _Visit(_Do.bow, seconds: 6);
  if (_stillDecor.contains(kind)) return null;
  return _visits[kind] ?? const _Visit(_Do.look);
}

/// A resident's life, while it is left alone.
class _Liver {
  _Liver(this.id, this.seed);

  final String id;
  final int seed;

  /// How far it is from its own spot (layer units), and how far it means
  /// to go.
  double dx = 0, dy = 0, target = 0;

  /// Lifted off its ground (sitting on a keepsake, mid-hop), layer units.
  double lift = 0;

  /// What it is doing, and for how much longer before it chooses again.
  _Act act = _Act.idle;
  double wait = 0;

  /// How far along its stride, for the bob of its steps.
  double stride = 0;

  /// The ground it can walk without leaving it, either side of its spot
  /// (layer units); null until worked out.
  (double, double)? range;

  /// What it last turned to look at: a finger, for this long.
  double heedFor = 0;

  /// A walk through the portals, under way.
  _Trip? trip;

  /// A visit to a keepsake, under way.
  _Call? call;

  /// How solid it is drawn (going into a portal, it thins out).
  double fade = 1;

  /// Stood back at its spot for arranging, and left there.
  bool settled = false;

  /// Has had its night's visit (or found none), and may sleep.
  bool bedded = false;

  /// Asleep where it lay down, by a torch.
  bool sleepsThere = false;

  /// When next to look for shelter from the weather (field seconds).
  double lookForShelter = 0;

  /// A flyer resting on a perch: which, and for how much longer, and
  /// whether it has landed on it yet.
  String? perch;
  double perchFor = 0;
  bool landed = false;
}

enum _Act { idle, stroll, look, asleep }

/// A visit to a keepsake: which, from which side, and how far along it is.
class _Call {
  _Call(
    this.thing,
    this.visit, {
    required this.side,
    this.strength = 1,
    this.seat = 0,
  });

  final String thing;
  final _Visit visit;

  /// Which of the keepsake's seats it has taken (a seated visit).
  final int seat;

  /// Which side of it the visitor stands: -1 left, 1 right.
  final double side;

  /// How hard it stirs the keepsake (its own element, harder).
  final double strength;

  /// 0 walking there, 1 there and doing it, 2 done.
  int stage = 0;
  double time = 0;
  double stirAt = 0;
}

/// A walk through the portals: from [from] to [to] and home again.
class _Trip {
  _Trip(this.from, this.to, {required this.walkIn});

  /// The portals' points.
  final String from, to;

  /// Whether it walked to the first portal; if not it thinned out at home
  /// and came out of it.
  final bool walkIn;

  /// Where in the trip it is: 0 to the first portal, 1 out of it and
  /// looking, 2 through to the second and looking, 3 home.
  int leg = 0;
  double time = 0;
}

class _HomeLife {
  _HomeLife(this.game);

  final SceneGame game;
  final Map<String, _Liver> _livers = {};
  final math.Random _rng = math.Random();

  /// What has been laid out has changed: every walk is worked out again.
  void reset() {
    for (final l in _livers.values) {
      l
        ..range = null
        ..trip = null
        ..call = null
        ..sleepsThere = false
        ..target = 0;
    }
  }

  bool debugTrip(String spawnId) {
    final sp = game._pointOf(spawnId);
    final l = _livers[spawnId];
    if (sp == null || l == null) return false;
    final trip = _tripFor(l, sp, l.range ??= _rangeOf(sp));
    l.trip = trip;
    return trip != null;
  }

  /// Sends [spawnId] to the keepsake at [thingId], if it can reach it.
  bool debugVisit(String spawnId, String thingId) {
    final sp = game._pointOf(spawnId);
    final l = _livers[spawnId];
    if (sp == null || l == null) return false;
    return _visit(l, sp, thingId);
  }

  /// The keepsake at [thingId] was tapped: the nearest resident that can
  /// reach it comes to it. Whether anyone could.
  bool callTo(String thingId) {
    final at = game._pointOf(thingId);
    if (at == null || !game.lively || game.arranging) return false;
    final candidates = [
      for (final e in _livers.entries)
        if (e.value.trip == null && e.value.act != _Act.asleep)
          if (game._pointOf(e.key) case final sp?
              when sp.anchor == at.anchor && !sp.aloft)
            (e.value, sp),
    ]..sort(
        (a, b) => game
            ._loopDelta(thingId, a.$2.id)
            .abs()
            .compareTo(game._loopDelta(thingId, b.$2.id).abs()),
      );
    for (final (l, sp) in candidates) {
      if (_visit(l, sp, thingId)) return true;
    }
    return false;
  }

  /// Where [spawnId] is held from its spot this frame, if anywhere.
  Offset? offsetOf(String spawnId) {
    final l = _livers[spawnId];
    if (l == null || (l.dx == 0 && l.dy == 0 && l.lift == 0)) return null;
    return Offset(l.dx, l.dy - l.lift);
  }

  bool get _night {
    final h = game.fieldHour;
    return h >= 21.5 || h < 5.5;
  }

  double get _u => game._viewportH / 475;

  void update(double dt) {
    final residents = game._residents;
    _livers.removeWhere((id, _) => !residents.containsKey(id));
    final still = !game.lively || game.arranging || game._held != null;
    for (final e in residents.entries) {
      final comp = e.value;
      final l = _livers.putIfAbsent(
        e.key,
        () => _Liver(e.key, e.key.hashCode & 0xFFFF)
          ..wait = 1.5 + _rng.nextDouble() * 4,
      );
      final sp = game._pointOf(e.key);
      final anchor = game._spawnPointComps[e.key];
      if (sp == null || anchor == null || !comp.isLoaded) continue;
      final base = game._residentLooks[e.key]?.$3 == true ? -1.0 : 1.0;
      if (still) {
        _settle(l, comp, base);
        continue;
      }
      l.settled = false;
      if (sp.aloft) {
        _hover(l, comp, sp, dt);
        continue;
      }
      _live(l, comp, sp, base, dt);
    }
  }

  /// Back at its own spot, as it was put there, awake.
  void _settle(_Liver l, WildMonComponent comp, double base) {
    comp.submerged = false;
    if (l.act == _Act.asleep || comp.angle != 0) {
      comp
        ..scale.setValues(1, 1)
        ..angle = 0;
    }
    if (l.settled) return;
    l
      ..settled = true
      ..dx = 0
      ..dy = 0
      ..lift = 0
      ..target = 0
      ..trip = null
      ..call = null
      ..bedded = false
      ..sleepsThere = false
      ..perch = null
      ..act = _Act.idle
      ..wait = 1 + _rng.nextDouble() * 3;
    if (l.fade != 1) {
      l.fade = 1;
      comp.sprite?.spriteOpacity = 1;
    }
    comp.sprite?.animating = true;
    comp.face(base);
  }

  /// A floater hangs in the air, rising and falling, drifting a little —
  /// and near the four winds' vane it rides the wind round it.
  void _hover(_Liver l, WildMonComponent comp, SpawnPoint sp, double dt) {
    final t = game._fieldTime;
    final size = sp.size.x;
    final slow = _night ? 0.55 : 1.0;
    final vane = _thingsOfKind('four_winds', sp.anchor)
        .map((id) => game._loopDelta(id, sp.id))
        .where((d) => d.abs() < size * 2.2)
        .firstOrNull;
    if (_perchFlight(l, comp, sp, dt)) return;
    if (vane != null && !_night) {
      // Round and round the vane's head, on the wind.
      final a = t * 0.9 + l.seed;
      final to = vane + math.cos(a) * size * 0.6;
      final d = to - l.dx;
      l.dx += d * math.min(1, dt * 2);
      comp.face(-math.sin(a) > 0 ? -1 : 1);
      l.dy = math.sin(a) * 10 * _u - 6 * _u;
      return;
    }
    l.wait -= dt;
    if (l.wait <= 0) {
      l
        ..target = (_rng.nextDouble() * 2 - 1) * size * 0.32
        ..wait = 4 + _rng.nextDouble() * 6;
    }
    final d = l.target - l.dx;
    if (d.abs() > 0.5) {
      l.dx += d.sign * math.min(d.abs(), size * 0.16 * slow * dt);
      comp.face(d > 0 ? -1 : 1);
    }
    l.dy = math.sin(t * 0.9 * slow + l.seed) * 6 * _u * slow +
        math.sin(t * 0.37 + l.seed * 0.3) * 3 * _u;
  }

  /// A flyer to a perch near it (a Flyer's Perch, the Elder Tree's top),
  /// to land and rest a while, folded; and back. Whether it is doing so.
  bool _perchFlight(_Liver l, WildMonComponent comp, SpawnPoint sp, double dt) {
    final size = sp.size.x;
    var id = l.perch;
    if (id == null) {
      l.perchFor -= dt;
      if (l.perchFor > 0) return false;
      l.perchFor = 6 + _rng.nextDouble() * 8;
      if (_rng.nextDouble() > 0.45) return false;
      for (final kind in const ['flyer_perch', 'elder_tree']) {
        for (final t in _thingsOfKind(kind, sp.anchor)) {
          final taken = _livers.values.any((o) => o != l && o.perch == t);
          if (taken || game._loopDelta(t, sp.id).abs() > size * 3.2) continue;
          id = t;
          break;
        }
        if (id != null) break;
      }
      if (id == null) return false;
      l
        ..perch = id
        ..perchFor = 9 + _rng.nextDouble() * 6;
    }
    final at = game._spawnPointComps[id];
    final seats = _seatsOf(id);
    if (at == null || seats.isEmpty) {
      l.perch = null;
      return false;
    }
    final top = seats.last;
    final home = sp.normalizedPos.dy * game._viewportH;
    final drop = game._standDrop[sp.id] ?? size * 0.46;
    final toX = game._loopDelta(id, sp.id) + top.dx;
    final toY = at.position.y - top.dy - drop - home;
    l.perchFor -= dt;
    final leaving = l.perchFor <= 0;
    final gx = (leaving ? 0 : toX) - l.dx, gy = (leaving ? 0 : toY) - l.dy;
    final dist = math.sqrt(gx * gx + gy * gy);
    final step = size * 0.9 * dt;
    if (dist > 1) {
      final k = math.min(1.0, step / dist);
      l
        ..dx += gx * k
        ..dy += gy * k;
      if (gx.abs() > 1) comp.face(gx > 0 ? -1 : 1);
    } else if (leaving) {
      l
        ..perch = null
        ..perchFor = 8 + _rng.nextDouble() * 8;
    } else if (!l.landed) {
      // Down on it: the last wingbeats, the grip.
      l.landed = true;
      if (game.isOnScreen(at)) game.onSound?.call(SoundCue.homePerch);
    }
    if (dist > 1 && !leaving) l.landed = false;
    // Landed: still, but for breathing.
    comp.sprite?.animating = dist > 1 || leaving;
    return true;
  }

  void _live(
    _Liver l,
    WildMonComponent comp,
    SpawnPoint sp,
    double base,
    double dt,
  ) {
    final size = sp.size.x;
    final trip = l.trip;
    if (trip != null) {
      _travel(l, comp, sp, trip, dt);
      return;
    }

    // Rain, snow or storm: under the canopy, if it can reach one.
    if (_wet && l.call == null && game._fieldTime > l.lookForShelter) {
      l.lookForShelter = game._fieldTime + 4;
      final cover = _reachable(l, sp, (v) => v.act == _Do.shelter);
      if (cover != null) _visit(l, sp, cover);
    }

    // Night: first the night's keepsakes (a torch to sleep by, a book, a
    // telescope), then sleep.
    if (_night) {
      if (!l.bedded && l.call == null) {
        l.bedded = true;
        final night = _reachable(l, sp, (v) => v.night);
        if (night != null) _visit(l, sp, night);
      }
      final call = l.call;
      if (call != null) {
        _attend(l, comp, sp, call, dt);
        return;
      }
      _sleep(l, comp, sp, dt, size);
      return;
    }
    if (l.act == _Act.asleep || l.bedded) {
      l
        ..act = _Act.idle
        ..bedded = false
        ..sleepsThere = false
        ..wait = 1 + _rng.nextDouble() * 3;
      comp.sprite?.animating = true;
      comp.scale.setValues(1, 1);
    }

    final call = l.call;
    if (call != null) {
      _attend(l, comp, sp, call, dt);
      return;
    }

    // A finger close by: it turns to look.
    final touch = game._touches.isEmpty ? null : game._touches.last;
    if (touch != null && game._fieldTime - touch.time < 0.35) {
      final sx = game.screenXOf(l.id);
      if (sx != null && (touch.x - sx).abs() < 150) {
        comp.face(touch.x > sx ? -1 : 1);
        l
          ..heedFor = 1.6
          ..target = l.dx;
      }
    }
    if (l.heedFor > 0) {
      l.heedFor -= dt;
      _walk(l, comp, sp, dt, size);
      return;
    }

    l.wait -= dt;
    if (l.wait <= 0 && (l.target - l.dx).abs() < 0.5) _choose(l, comp, sp, base);
    _walk(l, comp, sp, dt, size);
  }

  /// Asleep: still, its frames held, breathing.
  void _sleep(_Liver l, WildMonComponent comp, SpawnPoint sp, double dt, double size) {
    if (l.act != _Act.asleep) {
      l
        ..act = _Act.asleep
        ..target = l.dx
        ..lift = 0;
      comp.angle = 0;
    }
    comp.sprite?.animating = false;
    final b = 1 + 0.018 * math.sin(game._fieldTime * 1.2 + l.seed);
    comp.scale.setValues(1, b);
    _walk(l, comp, sp, dt, size);
  }

  /// What it does next: wander, look at a neighbour, go to a keepsake, go
  /// through the portals, or stand as it was put.
  void _choose(_Liver l, WildMonComponent comp, SpawnPoint sp, double base) {
    final size = sp.size.x;
    final range = l.range ??= _rangeOf(sp);
    final roll = _rng.nextDouble();
    l.act = _Act.idle;
    l.wait = 2.5 + _rng.nextDouble() * 5;

    // Through the portals, now and then.
    if (roll < 0.12) {
      final trip = _tripFor(l, sp, range);
      if (trip != null) {
        l.trip = trip;
        return;
      }
    }
    // To a keepsake it can reach.
    if (roll < 0.4) {
      final thing = _reachable(l, sp, (_) => true);
      if (thing != null && _visit(l, sp, thing)) return;
    }
    // A neighbour: it turns to look at them.
    if (roll < 0.55) {
      final n = _nearestNeighbour(sp, size * 3.2);
      if (n != null) {
        l.act = _Act.look;
        comp.face(n > 0 ? -1 : 1);
        return;
      }
    }
    // A stroll.
    if (roll < 0.88 && range.$2 - range.$1 > size * 0.12) {
      l
        ..act = _Act.stroll
        ..target = range.$1 + _rng.nextDouble() * (range.$2 - range.$1);
      return;
    }
    // Back as it was put, facing as it was put.
    l.target = 0;
    comp.face(base);
  }

  /// A keepsake [l] can walk to that [wants] would visit, nearest first.
  String? _reachable(_Liver l, SpawnPoint sp, bool Function(_Visit) wants) {
    final range = l.range ??= _rangeOf(sp);
    final size = sp.size.x;
    String? best;
    var bestD = double.infinity;
    for (final id in game._things.keys) {
      final kind = game._thingKind(id);
      if (kind == null || kind == kPortalThing || _ghost(id)) continue;
      final p = game._pointOf(id);
      if (p == null || p.anchor != sp.anchor || p.aloft) continue;
      final v = _visitOf(kind);
      if (v == null || !wants(v)) continue;
      if (v.seated && _seatFor(l, id, v) == null) continue;
      final d = game._loopDelta(id, sp.id);
      if (_standFor(d, size, range) == null) continue;
      if (d.abs() < bestD) {
        bestD = d.abs();
        best = id;
      }
    }
    return best;
  }

  /// Where to stand beside a keepsake [d] along from home, within
  /// [range]: the near side if it can, else the far one; null if neither.
  double? _standFor(double d, double size, (double, double) range) {
    for (final side in [-d.sign, d.sign]) {
      final at = d + side * size * 0.62;
      if (at >= range.$1 - 1 && at <= range.$2 + 1) return at;
    }
    return null;
  }

  /// Starts [l] on a visit to the keepsake at [thing]. Whether it can.
  bool _visit(_Liver l, SpawnPoint sp, String thing) {
    final kind = game._thingKind(thing);
    if (kind == null) return false;
    final size = sp.size.x;
    final range = l.range ??= _rangeOf(sp);
    final d = game._loopDelta(thing, sp.id);
    final at = _standFor(d, size, range);
    if (at == null) return false;
    var visit = _visitOf(kind);
    if (visit == null || _ghost(thing)) return false;
    var seat = 0;
    if (visit.seated) {
      // Standing places (to watch, to shelter) only where it can walk.
      bool reachable(int i, Offset s) =>
          d + s.dx >= range.$1 - 1 && d + s.dx <= range.$2 + 1;
      var free = _seatFor(
        l,
        thing,
        visit,
        where: visit.act == _Do.shelter ? reachable : null,
      );
      if (free == null) return false;
      // Someone is already performing: this one watches, from a side it
      // can reach.
      if (visit.act == _Do.perform && free > 0) {
        visit = _Visit(_Do.watch, seconds: visit.seconds);
        free = _seatFor(l, thing, visit, where: (i, s) => i > 0 && reachable(i, s));
        if (free == null) return false;
      }
      seat = free;
    }
    // Watching and sheltering are done standing at the seat itself — and
    // so is looking at anything that marks where to stand (the pool's
    // rim): the nearer of its places that can be walked to.
    var stand = at;
    final seats = _seatsOf(thing);
    if (visit.act == _Do.watch || visit.act == _Do.shelter) {
      if (seat >= seats.length) return false;
      stand = d + seats[seat].dx;
      if (stand < range.$1 - 1 || stand > range.$2 + 1) return false;
    } else if (!visit.seated && seats.isNotEmpty) {
      final places = [
        for (final o in seats)
          if (d + o.dx >= range.$1 - 1 && d + o.dx <= range.$2 + 1) d + o.dx,
      ]..sort((a, b) => a.abs().compareTo(b.abs()));
      if (places.isEmpty) return false;
      stand = places.first;
    }
    final element = game._residentLooks[l.id]?.$1.types.firstOrNull;
    final species = game._residentLooks[l.id]?.$1.id;
    final own =
        visit.elements.contains(element) ||
        (kind.startsWith('effigy:') && kind.substring(7) == species);
    l
      ..call = _Call(
        thing,
        visit,
        side: (at - d).sign,
        strength: own ? 1.6 : 1,
        seat: seat,
      )
      ..target = stand
      ..act = _Act.stroll
      ..heedFor = 0;
    return true;
  }

  bool _ghost(String id) => switch (game._things[id]) {
    final FieldThing t => t.ghost,
    _ => false,
  };

  List<Offset> _seatsOf(String id) => switch (game._things[id]) {
    final FieldThing t => t.seats,
    _ => const [],
  };

  /// A seat of [thing] free for [l] under [visit] — for a stage, the
  /// performer's first and then the watchers' — or null if all are taken.
  int? _seatFor(
    _Liver l,
    String thing,
    _Visit visit, {
    bool Function(int i, Offset seat)? where,
  }) {
    final seats = _seatsOf(thing);
    final taken = {
      for (final o in _livers.values)
        if (o != l && o.call?.thing == thing) o.call!.seat,
    };
    for (var i = 0; i < seats.length; i++) {
      if (taken.contains(i)) continue;
      if (where != null && !where(i, seats[i])) continue;
      return i;
    }
    return null;
  }

  /// Whether the weather is the kind to shelter from.
  bool get _wet => switch (game.fieldWeather) {
    WeatherKind.rain || WeatherKind.snow || WeatherKind.storm => true,
    _ => false,
  };

  /// One step of a visit to a keepsake.
  void _attend(
    _Liver l,
    WildMonComponent comp,
    SpawnPoint sp,
    _Call call,
    double dt,
  ) {
    final size = sp.size.x;
    final thing = game._things[call.thing];
    if (thing == null) {
      _leave(l, comp);
      return;
    }
    final d = game._loopDelta(call.thing, sp.id);
    final faceIt = d > l.dx ? -1.0 : 1.0;
    void stir(double every) {
      if (call.time >= call.stirAt) {
        call.stirAt = call.time + every;
        if (thing case final FieldThing t) t.stir(call.strength);
      }
    }

    switch (call.stage) {
      case 0:
        // Walking there.
        comp.sprite?.animating = true;
        _walk(l, comp, sp, dt, size);
        if ((l.target - l.dx).abs() < 0.5) {
          call
            ..stage = 1
            ..time = 0
            ..stirAt = 0;
          comp.face(faceIt);
        }
        return;
      case 1:
        call.time += dt;
        final t = call.time, v = call.visit;
        final ground = _groundShift(sp, l.dx);
        switch (v.act) {
          case _Do.look:
            comp.face(faceIt);
            stir(2.4);
          case _Do.warm:
            comp.face(faceIt);
            stir(1.8);
            // By night it lies down by the fire and sleeps there.
            if (_night && t > 3) {
              l
                ..call = null
                ..sleepsThere = true;
              return;
            }
          case _Do.hop:
            comp.face(faceIt);
            final beat = v.beat ?? 0.8;
            final f = (t / beat) % 1.0;
            l.lift = math.sin(f * math.pi) * 9 * _u;
            if (f < dt / beat) stir(0);
          case _Do.bow:
            comp.face(faceIt);
            final dip = math.sin(math.min(1.0, t / 1.4) * math.pi / 2) *
                (t > v.seconds - 1.4
                    ? math.max(0.0, (v.seconds - t) / 1.4)
                    : 1.0);
            comp.angle = -faceIt * 0.16 * dip;
            stir(3);
          case _Do.preen:
            // This way, that way, before the glass.
            final turn = ((t / 1.3).floor()).isEven ? faceIt : -faceIt;
            comp.face(t < 1 ? faceIt : turn);
            stir(2.6);
          case _Do.climb || _Do.perform:
            final seats = _seatsOf(call.thing);
            if (call.seat >= seats.length) {
              comp.face(faceIt);
              break;
            }
            final seat = seats[call.seat];
            // A bed keeps whoever got into it by night until morning.
            final sleeping = v.bed && _night && t > 0.6;
            if (sleeping && t > v.seconds - 0.7) call.time = v.seconds - 0.7;
            // Up onto it in an arc, a while there, and down again.
            final up = math.min(1.0, t / 0.6);
            final down = t > v.seconds - 0.6
                ? math.max(0.0, (v.seconds - t) / 0.6)
                : 1.0;
            final k = math.min(up, down);
            final ease = k * k * (3 - 2 * k);
            final from = call.side * size * 0.62;
            // The seat may move (a swing, a ride): it is followed.
            l.dx = d + seat.dx * ease + from * (1 - ease);
            l.lift =
                seat.dy * ease +
                math.sin(k * math.pi) * 14 * _u * (1 - ease);
            l.dy = _groundShift(sp, l.dx);
            comp.submerged = l.lift < -2;
            if (sleeping) {
              comp.sprite?.animating = false;
              final b = 1 + 0.018 * math.sin(game._fieldTime * 1.2 + l.seed);
              comp.scale.setValues(1, b);
            } else {
              comp.sprite?.animating = true;
              if (comp.scale.y != 1) comp.scale.setValues(1, 1);
            }
            if (v.act == _Do.perform && ease >= 1) {
              // On the boards: hops in time, turning to its audience.
              final beat = v.beat ?? 0.7;
              final f = (t / beat) % 1.0;
              l.lift += math.sin(f * math.pi) * 8 * _u;
              comp.face(((t / (beat * 2)).floor()).isEven ? 1 : -1);
              if (f < dt / beat) stir(0);
            } else if (!sleeping) {
              comp.face(t < v.seconds / 2 ? -call.side : call.side);
              if (ease >= 1) stir(1.5);
            }
            if (t >= v.seconds) {
              comp.scale.setValues(1, 1);
              l
                ..lift = 0
                ..dx = d + from
                ..target = l.dx;
              call.stage = 2;
            }
            return;
          case _Do.shelter:
            // Under it, looking out at the weather, until it clears.
            final seats = _seatsOf(call.thing);
            final out = call.seat < seats.length ? seats[call.seat].dx : 0.0;
            comp.face(out == 0 ? faceIt : (out > 0 ? -1 : 1));
            if (_night) {
              comp.sprite?.animating = false;
            }
            if (_wet) call.time = math.min(call.time, 1);
          case _Do.watch:
            // At one side, watching whoever is on the stage.
            comp.face(faceIt);
            final performing = _livers.values.any(
              (o) => o.call?.thing == call.thing && o.call?.visit.act == _Do.perform,
            );
            if (performing) call.time = math.min(call.time, v.seconds - 1);
          case _Do.dash:
            // Through it and out the far side, then back, fast.
            final far = d - call.side * size * 0.9;
            final there = t < v.seconds / 2;
            final to = there ? far : d + call.side * size * 0.62;
            final step = size * 1.4 * dt;
            final g = to - l.dx;
            l.dx += g.sign * math.min(g.abs(), step);
            l.stride += step / (size * 0.12);
            l.lift = (math.sin(l.stride * math.pi)).abs() * 3 * _u;
            if (g.abs() > 0.5) comp.face(g > 0 ? -1 : 1);
            if ((l.dx - d).abs() < size * 0.2) stir(0.6);
            l.dy = _groundShift(sp, l.dx);
            if (t >= v.seconds) call.stage = 2;
            return;
        }
        l.dy = ground;
        if (t >= v.seconds) {
          comp.angle = 0;
          l.lift = 0;
          call.stage = 2;
        }
      default:
        _leave(l, comp);
    }
  }

  void _leave(_Liver l, WildMonComponent comp) {
    comp
      ..angle = 0
      ..submerged = false;
    l
      ..call = null
      ..lift = 0
      ..act = _Act.idle
      ..wait = 1.5 + _rng.nextDouble() * 3;
  }

  /// Steps it toward its target along the ground, its feet on it.
  void _walk(
    _Liver l,
    WildMonComponent comp,
    SpawnPoint sp,
    double dt,
    double size,
  ) {
    final d = l.target - l.dx;
    var bob = 0.0;
    if (d.abs() > 0.5) {
      final step = math.min(d.abs(), size * 0.34 * dt);
      l.dx += d.sign * step;
      l.stride += step / (size * 0.16);
      bob = -(math.sin(l.stride * math.pi)).abs() * 2.4 * _u;
      comp.face(d > 0 ? -1 : 1);
    }
    l.dy = _groundShift(sp, l.dx) + bob;
  }

  /// How much higher or lower the ground is [dx] along from [sp]'s spot.
  double _groundShift(SpawnPoint sp, double dx) {
    if (dx == 0) return 0;
    final art = game._art;
    if (art == null) return 0;
    final x = game._spawnBaseX(sp);
    final g0 = art.groundAt(sp.anchor, x), g1 = art.groundAt(sp.anchor, x + dx);
    if (g0 == null || g1 == null) return 0;
    return g1.rest - g0.rest;
  }

  /// The ground [sp]'s resident can walk either side of its spot: as far
  /// as it stays nearly level and keeps clear of other residents standing
  /// on its row. Keepsakes it may walk up to (and through the portals).
  (double, double) _rangeOf(SpawnPoint sp) {
    final art = game._art;
    if (art == null) return (0, 0);
    final size = sp.size.x;
    final x = game._spawnBaseX(sp);
    final perch = art.perchFor(sp.id);
    final g0 = art.groundAt(sp.anchor, x);
    if (g0 == null) return (0, 0);
    // On a rock above the grass (the Valley's boulders) it stays put: its
    // feet are over the ground's own top. (Where the ground is a perch all
    // the way down — an isle, a bank — or a plane it stands anywhere on —
    // the Arcane's glass — it walks.)
    if (perch != null && g0.top.isFinite && perch < g0.top - 6 * _u) {
      return (0, 0);
    }
    final others = _residentsOn(sp);
    final step = 3 * _u;
    final far = size * 1.6;
    double reach(int dir) {
      var at = 0.0;
      for (var d = step; d <= far; d += step) {
        final g = art.groundAt(sp.anchor, x + dir * d);
        if (g == null || (g.rest - g0.rest).abs() > 9 * _u) break;
        // Up to halfway to a neighbour, who has the other half.
        final clash = others.any(
          (o) => o.sign == dir && dir * d > o.abs() / 2 - size * 0.25,
        );
        if (clash) break;
        at = d;
      }
      return at;
    }

    return (-reach(-1), reach(1));
  }

  /// The other residents standing on [sp]'s row: how far along from it.
  List<double> _residentsOn(SpawnPoint sp) => [
    for (final id in game._residents.keys)
      if (id != sp.id)
        if (game._pointOf(id) case final o?
            when o.anchor == sp.anchor && !o.aloft)
          game._loopDelta(id, sp.id),
  ];

  Iterable<String> _thingsOfKind(String kind, SceneLayer layer) => [
    for (final id in game._things.keys)
      if (game._thingKind(id) == kind &&
          game._pointOf(id)?.anchor == layer &&
          !_ghost(id))
        id,
  ];

  double? _nearestNeighbour(SpawnPoint sp, double within) {
    double? best;
    for (final d in _residentsOn(sp)) {
      if (d.abs() > within) continue;
      if (best == null || d.abs() < best.abs()) best = d;
    }
    return best;
  }

  /// A walk through the portals for [l], if a pair stands on its row: in
  /// at the nearer — walked to if it can be reached, else it thins out at
  /// home and comes out of it — and out at the other.
  _Trip? _tripFor(_Liver l, SpawnPoint sp, (double, double) range) {
    final portals = _thingsOfKind(kPortalThing, sp.anchor).toList();
    if (portals.length < 2) return null;
    portals.sort(
      (a, b) => game
          ._loopDelta(a, sp.id)
          .abs()
          .compareTo(game._loopDelta(b, sp.id).abs()),
    );
    final near = portals[0], far = portals[1];
    final d = game._loopDelta(near, sp.id);
    final walkIn = d >= range.$1 - 1 && d <= range.$2 + 1;
    return _Trip(near, far, walkIn: walkIn);
  }

  /// One step of a walk through the portals.
  void _travel(
    _Liver l,
    WildMonComponent comp,
    SpawnPoint sp,
    _Trip trip,
    double dt,
  ) {
    final size = sp.size.x;
    final from = game._things[trip.from], to = game._things[trip.to];
    if (from == null || to == null) {
      _comeHome(l, comp);
      return;
    }
    comp.sprite?.animating = true;
    trip.time += dt;
    void fadeTo(double v, double seconds) {
      final k = dt / seconds;
      l.fade = v > l.fade
          ? math.min(v, l.fade + k)
          : math.max(v, l.fade - k);
      comp.sprite?.spriteOpacity = l.fade;
    }

    switch (trip.leg) {
      case 0:
        // To the first portal: walked to, or gone from home in a breath.
        if (trip.walkIn) {
          l
            ..act = _Act.stroll
            ..target = game._loopDelta(trip.from, sp.id);
          _walk(l, comp, sp, dt, size);
          if ((l.target - l.dx).abs() < 0.5) fadeTo(0, 0.45);
        } else {
          fadeTo(0, 0.6);
        }
        if (l.fade <= 0) {
          if (from case final FieldThing t) t.stir();
          _standAt(l, sp, trip.from, size, out: 1);
          trip
            ..leg = 1
            ..time = 0;
        }
      case 1:
        // Out of the first and looking round, then back into it.
        fadeTo(trip.time < 3.2 ? 1 : 0, 0.5);
        if (trip.time < 0.1) comp.face(-1);
        if (trip.time > 1.6 && trip.time < 1.7) comp.face(1);
        if (trip.time > 3.2 && l.fade <= 0) {
          if (from case final FieldThing t) t.stir();
          if (to case final FieldThing t) t.stir();
          _standAt(l, sp, trip.to, size, out: -1);
          trip
            ..leg = 2
            ..time = 0;
        }
      case 2:
        // Out of the other, a while, then back through.
        fadeTo(trip.time < 6 ? 1 : 0, 0.5);
        if (trip.time < 0.1) comp.face(1);
        if (trip.time > 3 && trip.time < 3.1) comp.face(-1);
        if (trip.time > 6 && l.fade <= 0) {
          if (to case final FieldThing t) t.stir();
          l
            ..dx = 0
            ..dy = 0
            ..target = 0;
          trip
            ..leg = 3
            ..time = 0;
        }
      default:
        // Home: it gathers back where it was put.
        fadeTo(1, 0.6);
        if (l.fade >= 1) _comeHome(l, comp);
    }
  }

  /// Stands [l] just out of the portal at [portal], to the side [out]
  /// (1 right, -1 left), its feet on the portal's ground.
  void _standAt(
    _Liver l,
    SpawnPoint sp,
    String portal,
    double size, {
    required double out,
  }) {
    final p = game._pointOf(portal);
    final at = game._spawnPointComps[portal];
    final me = game._spawnPointComps[sp.id];
    if (p == null || at == null || me == null) return;
    l
      ..dx = game._loopDelta(portal, sp.id) + out * size * 0.34
      ..target = l.dx;
    final home = game._anchorY(sp, sp.normalizedPos.dy * game._viewportH);
    final drop = game._standDrop[sp.id] ?? size * 0.46;
    l.dy = at.position.y - drop - home;
  }

  void _comeHome(_Liver l, WildMonComponent comp) {
    l
      ..trip = null
      ..dx = 0
      ..dy = 0
      ..target = 0
      ..act = _Act.idle
      ..wait = 3 + _rng.nextDouble() * 4
      ..fade = 1;
    comp.sprite?.spriteOpacity = 1;
  }
}

/// A piece of scenery carried by hand: the piece come apart into a drift
/// of grains the shape of it, that sets into the piece where it is put
/// down. Drawn in [box] (layer units, round its point).
class _PieceGhost extends PositionComponent {
  _PieceGhost(this.box, this.tint) : super(priority: 50);

  final Rect box;
  final Color tint;
  double _t = 0;
  static const _n = 260;
  static final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Float32List _pts = Float32List(_n * 2);

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final w = box.width, h = box.height;
    for (var i = 0; i < _n; i++) {
      final a = (i * 0.618034) % 1.0, b = (i * 0.381966 + 0.13) % 1.0;
      // Denser low down, where it stands; thinner toward its top.
      final fy = 1 - math.pow(b, 0.8).toDouble();
      final sway = math.sin(_t * 1.7 + i * 0.37) * 0.04;
      final narrow = 0.55 + 0.45 * fy;
      _pts[i * 2] = box.center.dx + ((a - 0.5) * narrow + sway) * w;
      _pts[i * 2 + 1] =
          box.top + fy * h + math.sin(_t * 2.3 + i * 1.3) * h * 0.012;
    }
    final pulse = 0.55 + 0.2 * math.sin(_t * 3);
    _paint
      ..strokeWidth = math.max(1.4, h * 0.012)
      ..color = tint.withValues(alpha: pulse);
    canvas.drawRawPoints(ui.PointMode.points, _pts, _paint);
  }
}

/// The home biome zoomed out while it is arranged: the field a band of
/// land floating in the dark under the home planet, the void above and
/// below it, and stardust gathered along its edges — drifting along them,
/// and shed slowly off its underside. Nothing at the field's own height.
class _OverviewVoid extends Component with HasGameReference<SceneGame> {
  static const _top = 170, _under = 300, _shed = 130, _stars = 70;
  final PointBatch _dust = PointBatch(_top + _under + _shed);
  final PointBatch _bright = PointBatch(_top + _under);
  final PointBatch _far = PointBatch(_stars);
  static final Paint _fill = Paint();
  double _t = 0;

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final amount = game.overviewAmount;
    if (amount <= 0.01) return;
    final view = game._fieldViewFor(0);
    final w = game.size.x, h = game.size.y;
    final top = view.screenY(0), bottom = view.screenY(view.height);
    final a = Curves.easeOut.transform(amount);
    const voidColor = Color(0xFF05060B);
    final fade = 26.0 * a;

    // The void, and the field's edges soft into it.
    _fill.shader = null;
    _fill.color = voidColor.withValues(alpha: a);
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, w, top), _fill)
      ..drawRect(Rect.fromLTRB(0, bottom, w, h), _fill);
    _fill
      ..color = const Color(0xFFFFFFFF)
      ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, top + fade), [
        voidColor.withValues(alpha: a),
        voidColor.withValues(alpha: 0),
      ]);
    canvas.drawRect(Rect.fromLTRB(0, top, w, top + fade), _fill);
    _fill.shader = ui.Gradient.linear(
      Offset(0, bottom - fade * 1.3),
      Offset(0, bottom),
      [voidColor.withValues(alpha: 0), voidColor.withValues(alpha: a)],
    );
    canvas.drawRect(Rect.fromLTRB(0, bottom - fade * 1.3, w, bottom), _fill);
    _fill.shader = null;

    // Stardust: banked thick along the field's edges, thinning out into
    // the dark — the sky's edge a haze of it, the land's underside
    // crumbling into it — drifting along as the field is panned, slower
    // than the field.
    _dust.clear();
    _bright.clear();
    _far.clear();
    final pan = game._cameraX * view.zoom * 0.18;
    double along(int i, int salt, double speed) =>
        (hash01(i, salt) * w * 1.2 + _t * speed - pan) % (w * 1.2) - w * 0.1;
    for (var i = 0; i < _top; i++) {
      final x = along(i, 11, 3 + 4 * hash01(i, 12));
      final out = math.pow(hash01(i, 13), 2.2) * 46 * a;
      final y = top - out + 4 + math.sin(_t * 0.7 + i) * 1.5;
      (hash01(i, 14) < 0.2 ? _bright : _dust).add(x, y);
    }
    for (var i = 0; i < _under; i++) {
      final x = along(i, 15, 2 + 3 * hash01(i, 16));
      // An uneven bank: thicker in places, as crumbled ground would be.
      final bank = 0.55 + 0.45 * math.sin(x / w * 9.0 + hash01(i, 17) * 0.6);
      final out = math.pow(hash01(i, 18), 1.7) * 64 * a * bank;
      final y = bottom - 6 + out + math.sin(_t * 0.6 + i) * 1.2;
      (hash01(i, 19) < 0.24 ? _bright : _dust).add(x, y);
    }
    // Shed off the underside: grains falling slowly away, thinning out.
    for (var i = 0; i < _shed; i++) {
      final f = (_t * (0.03 + 0.03 * hash01(i, 21)) + hash01(i, 22)) % 1.0;
      final x = along(i, 23, 0) * 1.0;
      _dust.add(x + math.sin(_t * 0.5 + i) * 6 * f, bottom + 20 + f * 160 * a);
    }
    for (var i = 0; i < _stars; i++) {
      final above = i.isEven;
      final room = above ? top : h - bottom;
      if (room < 8) continue;
      final y = above
          ? hash01(i, 31) * room
          : bottom + hash01(i, 31) * room;
      _far.add((hash01(i, 32) * w * 1.1 - pan * 0.4) % (w * 1.1), y);
    }
    final tw = 0.75 + 0.25 * math.sin(_t * 1.7);
    _far.draw(canvas, 1.3, const Color(0xFFB8C4E8).withValues(alpha: 0.45 * a));
    _dust.draw(canvas, 1.6, const Color(0xFFE8D2A0).withValues(alpha: 0.55 * a));
    _bright.draw(
      canvas,
      2.1,
      const Color(0xFFFFF0C8).withValues(alpha: 0.85 * a * tw),
    );
  }
}
