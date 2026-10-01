// THE BLACK SUN'S MULTI-ROOM SOLVER — a tool, not a test of the suite.
//
// The prototype's solver (docs/prototypes/dark_portals) proves one room at a
// time. A rite that spans rooms needs the Dart rules, which are multi-room:
// every body is (room, x, y), every portal end (room, face), and the doors
// between rooms are moves (`kSunLinks`).
//
//   flutter test test/black_sun_solve_tool_test.dart --dart-define=SOLVE=rite
//
// prints a plan (guided best-first: a plan, not the shortest) and the
// exhaustive answers to "is it possible without …" for the restricted rooms
// small enough to search whole. Without SOLVE it does nothing.

import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:flutter_test/flutter_test.dart';

const String _solve = String.fromEnvironment('SOLVE');

/// The rite's world: the Lantern and the Heart, and their doors.
SunWorld riteWorld() => SunWorld(
  rooms: {'sun_lantern': kSunLantern, 'sun_heart': kSunHeart},
  links: [
    for (final l in kSunLinks)
      if ((l.room == 'sun_lantern' || l.room == 'sun_heart') &&
          (l.to == 'sun_lantern' || l.to == 'sun_heart'))
        l,
  ],
);

SunState riteStart() => SunState(
  pos: {
    for (var i = 0; i < 3; i++)
      kSunBodies[i]: (
        room: 'sun_lantern',
        x: kSunLantern.arrivals[i].x,
        y: kSunLantern.arrivals[i].y,
      ),
  },
);

/// Done: the Great Seal has burned and all three are through its door.
bool riteDone(SunState s) =>
    s.latched.contains(kSunRiteLatch) &&
    kSunBodies.every((n) {
      final p = s.pos[n]!;
      return p.room == 'sun_heart' && p.y == 6;
    });

int _h(SunState s) {
  // Staged: until the seal has burned, only the Darks' way down counts
  // (Light belongs upstairs, holding the door); after, everyone's.
  final latched = s.latched.contains(kSunRiteLatch);
  var h = latched ? 0 : 14;
  for (final n in kSunBodies) {
    if (!latched && n == 'light') continue;
    final p = s.pos[n]!;
    h += p.room == 'sun_heart'
        ? (latched ? (6 - p.y).abs() + (4 - p.x).abs() : 0)
        : (5 - p.y).abs() + (5 - p.x).abs() + 7;
  }
  return h;
}

/// Best-first: decisions cost 1, walking .25, plus how far the goal is.
({List<String>? plan, int states}) guided(
  SunWorld w,
  SunState s0,
  bool Function(SunState) done, {
  bool Function(String)? allow,
  int limit = 4000000,
}) {
  final prev = <String, (String, String)?>{s0.encoded: null};
  final g = <String, double>{s0.encoded: 0};
  final open = <(double, SunState)>[(0, s0)];
  final walk = RegExp(r'^(light|purple|orange) (north|south|east|west)$');
  void push((double, SunState) e) {
    open.add(e);
    var i = open.length - 1;
    while (i > 0) {
      final j = (i - 1) >> 1;
      if (open[j].$1 <= open[i].$1) break;
      final t = open[i];
      open[i] = open[j];
      open[j] = t;
      i = j;
    }
  }

  (double, SunState) pop() {
    final top = open.first;
    final last = open.removeLast();
    if (open.isNotEmpty) {
      open[0] = last;
      var i = 0;
      for (;;) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < open.length && open[l].$1 < open[m].$1) m = l;
        if (r < open.length && open[r].$1 < open[m].$1) m = r;
        if (m == i) break;
        final t = open[i];
        open[i] = open[m];
        open[m] = t;
        i = m;
      }
    }
    return top;
  }

  while (open.isNotEmpty && prev.length < limit) {
    final (_, s) = pop();
    final k = s.encoded;
    if (done(s)) {
      final plan = <String>[];
      for (var c = k; prev[c] != null; c = prev[c]!.$1) {
        plan.insert(0, prev[c]!.$2);
      }
      return (plan: plan, states: prev.length);
    }
    for (final (label, n) in sunActions(w, s)) {
      if (allow != null && !allow(label)) continue;
      final nk = n.encoded;
      final ng = g[k]! + (walk.hasMatch(label) ? .25 : 1);
      if (g.containsKey(nk) && g[nk]! <= ng) continue;
      g[nk] = ng;
      prev[nk] = (k, label);
      push((ng + _h(n) * 1.0, n));
    }
  }
  return (plan: null, states: prev.length);
}

/// Exhaustive breadth-first: is [done] reachable at all?
({bool? possible, int states}) exhaustive(
  SunWorld w,
  SunState s0,
  bool Function(SunState) done, {
  bool Function(String)? allow,
  int limit = 3000000,
}) {
  final seen = {s0.encoded};
  final q = [s0];
  for (var i = 0; i < q.length; i++) {
    if (done(q[i])) return (possible: true, states: seen.length);
    if (seen.length > limit) return (possible: null, states: seen.length);
    for (final (label, n) in sunActions(w, q[i])) {
      if (allow != null && !allow(label)) continue;
      if (seen.add(n.encoded)) q.add(n);
    }
  }
  return (possible: false, states: seen.length);
}


/// Every square [who] can WALK to from [s] (single steps, portals and doors;
/// nobody else moves, and a road that drops someone else is no road), with
/// the state on arrival and the steps that got it there.
Map<String, (SunState, List<String>)> walks(SunWorld w, SunState s, String who) {
  String key(SunState t) {
    final p = t.pos[who]!;
    return '${p.room}.${p.x}.${p.y}.${t.shine}';
  }

  final out = <String, (SunState, List<String>)>{key(s): (s, const [])};
  final q = [s];
  for (var i = 0; i < q.length; i++) {
    final t = q[i];
    final path = out[key(t)]!.$2;
    final e = sunEvaluate(w, t);
    for (var d = 0; d < 4; d++) {
      final r = sunMove(w, t, who, d, eval: e);
      if (!r.ok || r.fell.isNotEmpty) continue;
      final k = key(r.state!);
      if (out.containsKey(k)) continue;
      out[k] = (r.state!, [...path, '$who ${kSunDirWord[d]}']);
      q.add(r.state!);
    }
    final p = t.pos[who]!;
    for (final l in w.links) {
      if (l.room != p.room || l.x != p.x || l.y != p.y) continue;
      final r = sunTakeLink(w, t, who, l, eval: e);
      if (!r.ok || r.fell.isNotEmpty) continue;
      final k = key(r.state!);
      if (out.containsKey(k)) continue;
      out[k] = (r.state!, [...path, '$who takes the door to ${l.to}']);
      q.add(r.state!);
    }
  }
  return out;
}

/// The decisions a player makes: walk a body somewhere and cast, shine,
/// or stand (on a door, a pad, a goal square, or anywhere off the light).
List<(List<String>, SunState)> macros(SunWorld w, SunState s, bool Function(SunAt) rest) {
  final out = <(List<String>, SunState)>[];
  for (final b in kSunBodies) {
    // The same cast from further away is the same decision: keep the
    // nearest spot for each (face, end) and each shine.
    final done = <String>{};
    for (final (t, path) in walks(w, s, b).values) {
      final p = t.pos[b]!;
      final e = sunEvaluate(w, t);
      if (b != 'light') {
        for (var d = 0; d < 4; d++) {
          final cf = sunCastFace(w, t, e, b, d);
          if (cf.why != null) continue;
          for (var end = 0; end < 2; end++) {
            if (!done.add('${p.room}:${cf.face}:$end')) continue;
            final r = sunCast(w, t, b, end, d, eval: e);
            if (r.ok) {
              out.add(([...path, '$b casts ${end == 0 ? 'I' : 'II'} ${kSunDirWord[d]}'], r.state!));
            }
          }
        }
      } else if (w.rooms[p.room]!.at(p.x, p.y) == '*') {
        for (var d = 0; d < 4; d++) {
          if (!done.add('shine:${p.room}:${p.x},${p.y}:$d')) continue;
          final r = sunShine(w, t, d);
          if (r.ok && r.state!.shine != t.shine) {
            out.add(([...path, 'light shines ${kSunDirWord[d]}'], r.state!));
          }
        }
      }
      if (path.isNotEmpty && rest(p)) out.add((path, t));
    }
  }
  return out;
}

/// Best-first over decisions (each macro costs 1), guided by [h].
({List<String>? plan, int states, int decisions}) guidedMacro(
  SunWorld w,
  SunState s0,
  bool Function(SunState) done,
  bool Function(SunAt) rest,
  int Function(SunState) h, {
  int limit = 200000,
}) {
  final prev = <String, (String, List<String>)?>{s0.encoded: null};
  final g = <String, int>{s0.encoded: 0};
  final open = <(double, SunState)>[(0, s0)];
  void push((double, SunState) e) {
    open.add(e);
    var i = open.length - 1;
    while (i > 0) {
      final j = (i - 1) >> 1;
      if (open[j].$1 <= open[i].$1) break;
      final t = open[i];
      open[i] = open[j];
      open[j] = t;
      i = j;
    }
  }

  (double, SunState) pop() {
    final top = open.first;
    final last = open.removeLast();
    if (open.isNotEmpty) {
      open[0] = last;
      var i = 0;
      for (;;) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < open.length && open[l].$1 < open[m].$1) m = l;
        if (r < open.length && open[r].$1 < open[m].$1) m = r;
        if (m == i) break;
        final t = open[i];
        open[i] = open[m];
        open[m] = t;
        i = m;
      }
    }
    return top;
  }

  while (open.isNotEmpty && prev.length < limit) {
    final (_, s) = pop();
    final k = s.encoded;
    if (done(s)) {
      final plan = <String>[];
      var n = 0;
      for (var c = k; prev[c] != null; c = prev[c]!.$1) {
        plan.insertAll(0, prev[c]!.$2);
        n++;
      }
      return (plan: plan, states: prev.length, decisions: n);
    }
    for (final (steps, n) in macros(w, s, rest)) {
      final nk = n.encoded;
      final ng = g[k]! + 1;
      if (g.containsKey(nk) && g[nk]! <= ng) continue;
      g[nk] = ng;
      prev[nk] = (k, steps);
      push((ng + h(n) * 1.0, n));
    }
  }
  return (plan: null, states: prev.length, decisions: -1);
}

/// Where a body may simply stand: through the seal, on a doorway, or on
/// one of its room's arrival squares (out of the light's way).
bool riteRest(SunAt p) {
  if (p.room == 'sun_heart' && p.y == 6) return true;
  for (final l in kSunLinks) {
    if (l.room == p.room && l.x == p.x && l.y == p.y) return true;
  }
  final d = kSunRooms[p.room]!;
  return d.arrivals.any((a) => a.x == p.x && a.y == p.y);
}

int riteMacroH(SunState s) {
  final latched = s.latched.contains(kSunRiteLatch);
  var h = latched ? 0 : 3;
  for (final n in kSunBodies) {
    final p = s.pos[n]!;
    if (latched && !(p.room == 'sun_heart' && p.y == 6)) h += 1;
  }
  return h;
}

void main() {
  test('solve', () {
    if (_solve != 'rite') return;
    final w = riteWorld();
    final sw = Stopwatch()..start();
    final m = guidedMacro(w, riteStart(), riteDone, riteRest, riteMacroH);
    // ignore: avoid_print
    print('RITE macro: ${m.plan == null ? 'NO PLAN' : '${m.decisions} decisions, ${m.plan!.length} steps'}'
        ' (${m.states} states, ${sw.elapsedMilliseconds} ms)');
    if (m.plan != null) {
      final rp = sunReplay(w, riteStart(), m.plan!);
      // ignore: avoid_print
      print('  replays: ${rp.failed ?? (riteDone(rp.state!) ? 'solved' : 'NOT SOLVED')}');
      // ignore: avoid_print
      print('  plan: ${m.plan!.join(' · ')}');
    }
    if (_solve == 'rite') return;
    final r = guided(w, riteStart(), riteDone);
    // ignore: avoid_print
    print('RITE guided: ${r.plan == null ? 'NO PLAN' : '${r.plan!.length} steps'}'
        ' (${r.states} states, ${sw.elapsedMilliseconds} ms)');
    if (r.plan != null) {
      final decisions = r.plan!.where((a) => a.contains('casts') || a.contains('takes'));
      // ignore: avoid_print
      print('  casts: ${r.plan!.where((a) => a.contains('casts')).length}'
          '  doors: ${r.plan!.where((a) => a.contains('takes')).length}'
          '  decisions+doors: ${decisions.length}');
      // ignore: avoid_print
      print('  plan: ${r.plan!.join(' · ')}');
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
