// lib/screens/heart_puzzle/altar_play_screen.dart
//
// THE ALTARS, played: one level. The Heart's rite with the walking taken
// out (the author, 2026-10-07: "instead of controlling the alchemon with a
// joystick we just do a drag and drop on the spots").
//
//   · SEATING IS FREE. Drag a creature onto an altar's seat (or tap it, then
//     the seat); drag it back, swap it, as often as you like.
//   · A MOVE IS COMMITTED by tapping FUSE under a loaded altar, or SPLIT
//     under the split stage — plan the board, then fire.
//   · UNDO and START AGAIN cost nothing; the stars count the moves of the
//     way you finish on, so trying things is never punished.
//
// The stage (2026-10-08 redesign, altar_stage_art.dart) is lit grains on
// black: sand-ring seats over pools of floor light, faint columns up to the
// GOAL, which hangs at the top as its word in grains. The moments are the
// Heart's own — the two come apart into grains and gather into what they
// make (RiteMorphFx), it rises up its column in its element's own motion
// (HeartRiseFx), what it meets up there is drawn in — and when the goal is
// made it streams up to its word and lights it.
//
// SMOOTH, ALWAYS (the author: "no jump static animations"): every state on
// the stage eases — selection, seat glow, FUSE and SPLIT, creatures and orbs
// coming and going (undo and start again included), the level's opening,
// the count, the result.

import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_levels.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_progress.dart';
import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';
import 'package:alchemons/games/planet_dungeon/blood_heart_fx.dart';
import 'package:alchemons/games/planet_dungeon/blood_rite_fx.dart';
import 'package:alchemons/screens/heart_puzzle/altar_bodies.dart';
import 'package:alchemons/screens/heart_puzzle/altar_realm.dart';
import 'package:alchemons/screens/heart_puzzle/altar_recipe_book.dart';
import 'package:alchemons/screens/heart_puzzle/altar_stage_art.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const double _kSeatGap = 19, _kOrbR = 19, _kOrbStep = 54;

/// Moments play this much faster than the dungeon's; a tap while one plays
/// hurries it.
const double _kPace = 1.35, _kHurry = 3.2;

/// How long what a fusion made stands on the altar, named, before it rises.
const double _kMadeHold = 1.2;

/// What a level says under the bar: each of the Basics, and the first level
/// of a chapter that brings something new.
String? _teachFor(int n, AltarChapter c) {
  if (c.name == 'Basics') {
    return switch (n - c.first) {
      0 => 'Drag two creatures onto the circle, then tap FUSE.',
      1 =>
        'What you make rises. If it has a recipe with what hangs above, '
            'the two fuse up there.',
      _ => 'Every orb must be taken before the level is done.',
    };
  }
  if (n != c.first) return null;
  return switch (c.name) {
    'The Split' =>
      'Put something made on the split stage and tap SPLIT to take it apart.',
    'Species' =>
      'Families fuse too, by one rule everywhere. The book has the table.',
    _ => null,
  };
}

enum _PlaceKind { stage, seat, split }

class _Place {
  const _Place.stage() : kind = _PlaceKind.stage, altar = -1, side = -1;
  const _Place.seat(this.altar, this.side) : kind = _PlaceKind.seat;
  const _Place.split() : kind = _PlaceKind.split, altar = -1, side = -1;
  final _PlaceKind kind;
  final int altar, side;

  bool same(_Place o) => kind == o.kind && altar == o.altar && side == o.side;
}

class _Snap {
  _Snap(this.state, this.order);
  final AltarState state;
  final List<String> order;
}

/// A fusion or a split playing out.
class _Moment {
  _Moment({
    required this.hide,
    this.altar = -1,
    this.morph,
    this.morphSources = const [],
    this.morphTargets = const [],
    this.rise,
    this.riseFrom = 0,
    this.riseSpecies,
    this.meetSlot = 0,
    this.meetEl,
    this.meetAt = Offset.zero,
    this.landedSpecies,
    this.landedAt = Offset.zero,
    this.fizzleAt,
    this.fizzleCols = const [],
    this.prevColumn,
    this.madeName,
    this.madeTint = const Color(0xFFE6E2DA),
  });

  /// Units the moment draws itself (the stage leaves them out).
  final Set<String> hide;

  /// The altar it plays on (-1 for the split stage).
  final int altar;

  final RiteMorphFx? morph;
  final List<(AltarSpecies?, Offset)> morphSources;
  final List<(AltarSpecies?, Offset)> morphTargets;

  final HeartRiseFx? rise;
  final double riseFrom;
  final AltarSpecies? riseSpecies;

  /// The orb it meets up there (its slot, element, where it hangs), and
  /// that column as it was until then.
  final int meetSlot;
  final String? meetEl;
  final Offset meetAt;
  final List<String>? prevColumn;
  SpecimenGrains? meetGrains;
  double meetT = -1;

  /// What came down from the meeting.
  RiteMorphFx? after;
  final AltarSpecies? landedSpecies;
  final Offset landedAt;
  double afterFrom = -1;

  final Offset? fizzleAt;
  final List<Color> fizzleCols;

  /// What the fusion made, named under it while it stands on the altar.
  final String? madeName;
  final Color madeTint;

  double t = 0;

  bool get rising {
    final r = rise;
    return r != null && t >= riseFrom && t < riseFrom + r.duration;
  }

  double get end {
    var e = morph?.duration ?? 0;
    final r = rise;
    if (r != null) e = math.max(e, riseFrom + r.duration);
    if (after != null || (rise?.into != null && landedSpecies != null)) {
      final from = afterFrom >= 0
          ? afterFrom
          : riseFrom + (rise?.returnAt ?? 0);
      e = math.max(e, from + (after?.duration ?? 2.0));
    }
    if (fizzleAt != null) e = math.max(e, .9);
    return e;
  }
}

/// The goal made: it comes apart and streams up to its word.
class _Win {
  _Win(this.unitId, this.rise);
  final String unitId;
  final HeartRiseFx? rise;
  double t = 0;
  bool lit = false;

  double get shown => (rise?.duration ?? 1.2) + .9;
}

class AltarPlayScreen extends StatefulWidget {
  const AltarPlayScreen({
    super.key,
    required this.number,
    required this.progress,
  });

  /// The level, from 1.
  final int number;
  final AltarProgress progress;

  @override
  State<AltarPlayScreen> createState() => AltarPlayScreenState();
}

class AltarPlayScreenState extends State<AltarPlayScreen>
    with SingleTickerProviderStateMixin {
  late final AltarLevel level = kAltarLevels[widget.number - 1];
  late final AltarChapter chapter = kAltarChapters.firstWhere(
    (c) => widget.number >= c.first && widget.number <= c.last,
  );
  late AltarState state = altarStart(level);
  final List<_Snap> _history = [];
  late List<String> order = [for (final u in state.units) u.id];
  late List<List<String?>> seats = [
    for (var i = 0; i < level.altars; i++) [null, null],
  ];
  String? onSplit;
  String? selected;
  String? dragging;
  Offset dragAt = Offset.zero;

  /// Where each creature's feet are drawn (easing toward its place).
  final Map<String, Offset> feet = {};

  _Moment? _moment;
  _Win? _win;
  bool hurry = false;
  bool won = false;
  int stars = 0;
  bool showResult = false;

  late final AltarBodies bodies = AltarBodies(context.read<CreatureCatalog>());
  late final Ticker _ticker;
  final ValueNotifier<int> _tick = ValueNotifier(0);
  Duration _last = Duration.zero;
  double time = 0, _dt = 0;
  final RiteGrainBatch batch = RiteGrainBatch();
  final Map<String, ElementOrb> _orbs = {};
  AltarGoalWord? goalWord;

  /// Every eased value on the stage, by what it is.
  final Map<String, double> _e = {};

  /// When each thing first shows as the level opens (screen clock).
  final Map<String, double> _introAt = {};

  final List<AltarGhost> _ghosts = [];

  /// The theatre's scale and size in units, from the last layout.
  double _u = 1;
  Size _units = const Size(400, 480);
  Offset _origin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    for (final u in state.units) {
      bodies.load(u.el, u.fam);
    }
    if (level.goalFamily != null) bodies.load(level.goal, level.goalFamily!);
    // The opening: the word gathers, the orbs come in from the bottom of
    // each column up, then the creatures, left to right.
    for (var a = 0; a < level.altars; a++) {
      for (var k = 0; k < level.columns[a].length; k++) {
        _introAt['o:$a:$k'] = .35 + .14 * k + .08 * a;
      }
    }
    for (var i = 0; i < state.units.length; i++) {
      _introAt['p:${state.units[i].id}'] = .55 + .09 * i;
    }
    () async {
      final w = await heartWordOf(_goalName(), size: AltarGoalWord.size);
      if (mounted) goalWord = AltarGoalWord(level.goal, w, null);
    }();
  }

  /// The goal as one word: the element, or the species' own name.
  String _goalName() {
    final fam = level.goalFamily;
    if (fam == null) return level.goal;
    return _speciesName(level.goal, fam);
  }

  String _speciesName(String el, String fam) {
    final c = context
        .read<CreatureCatalog>()
        .creatures
        .where(
          (c) =>
              c.types.isNotEmpty &&
              c.types.first == el &&
              (c.mutationFamily ?? '').toLowerCase() == fam.toLowerCase(),
        )
        .firstOrNull;
    return c?.name ?? '$el${fam.toLowerCase()}';
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  AltarUnit? unitOf(String id) =>
      state.units.where((u) => u.id == id).firstOrNull;

  /// [key]'s eased value, moved toward [target] by this frame's step.
  double _ease(String key, double target, {double rate = 9, double init = 0}) {
    final v = _e[key] ?? init;
    final n = v + (target - v) * (1 - math.exp(-_dt * rate));
    _e[key] = (n - target).abs() < .002 ? target : n;
    return _e[key]!;
  }

  bool _shown(String key) => time >= (_introAt[key] ?? 0);

  // ── layout (theatre units) ───────────────────────────────

  /// The units this level needs: across, its altars and its stage; up, the
  /// stage, the altars, its deepest column, and the goal over it all.
  double get _needW => math.max(
    260,
    math.max(
      level.altars * 100.0 + 40,
      level.hand.length * 48.0 + (level.split ? 110 : 60),
    ),
  );
  double get _needH {
    final deep = level.columns.fold<int>(1, (m, c) => math.max(m, c.length));
    return 372 + (deep - 1) * _kOrbStep;
  }

  double get stageY => _units.height - 48;
  double get altarY => stageY - 104;
  double get groundY => altarY - 30;
  Offset get wordCentre => Offset(
    _units.width / 2,
    24 + (goalWord?.height ?? AltarGoalWord.size * 1.25) / 2,
  );
  double get wordBottom => 24 + (goalWord?.height ?? AltarGoalWord.size * 1.25);
  double altarX(int i) =>
      _units.width / 2 + (i - (level.altars - 1) / 2) * _altarStep;
  double get _altarStep => math.min(108, (_units.width - 40) / level.altars);
  Offset seatFeet(int ai, int side) =>
      Offset(altarX(ai) + (side == 0 ? -_kSeatGap : _kSeatGap), altarY + 2);
  Offset altarFeet(int ai) => Offset(altarX(ai), altarY + 2);
  Offset orbAt(int ai, int k) => Offset(
    altarX(ai),
    altarY - 88 - k * _kOrbStep + math.sin(time * .9 + ai * 1.7 + k * .6) * 3,
  );

  /// Where the k-th of [len] still hanging over altar [ai] hangs: things up
  /// there stay where they are as the ones below them go.
  int slotOf(int ai, int len, int k) => k + level.columns[ai].length - len;

  Offset get splitFeet => Offset(38, stageY);

  List<String> get stageIds => [
    for (final id in order)
      if (_placeOf(id).kind == _PlaceKind.stage && unitOf(id) != null) id,
  ];

  Offset stageFeet(String id) {
    final ids = stageIds;
    final i = ids.indexOf(id);
    final x0 = level.split ? 84.0 : 30.0, x1 = _units.width - 30;
    final n = ids.length;
    final perRow = math.max(1, ((x1 - x0) / 48).floor());
    final rows = (n / perRow).ceil();
    final row = rows > 1 && i < n - perRow ? 1 : 0;
    final inRow = row == 1 ? perRow : (rows > 1 ? n - perRow : n);
    final j = row == 1 ? i : i - (rows > 1 ? perRow : 0);
    final step = math.min(66.0, (x1 - x0) / math.max(1, inRow));
    final width = step * (inRow - 1);
    return Offset((x0 + x1) / 2 - width / 2 + j * step, stageY - row * 36);
  }

  _Place _placeOf(String id) {
    if (onSplit == id) return const _Place.split();
    for (var a = 0; a < seats.length; a++) {
      for (var s = 0; s < 2; s++) {
        if (seats[a][s] == id) return _Place.seat(a, s);
      }
    }
    return const _Place.stage();
  }

  Offset targetFeet(String id) {
    final p = _placeOf(id);
    return switch (p.kind) {
      _PlaceKind.seat => seatFeet(p.altar, p.side),
      _PlaceKind.split => splitFeet,
      _PlaceKind.stage => stageFeet(id),
    };
  }

  Offset centreOf(AltarUnit u, Offset f) =>
      bodies.ready(u.el, u.fam)?.centreFor(f) ?? f - const Offset(0, 16);

  // ── the clock ────────────────────────────────────────────

  void _onTick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, .05);
    _last = now;
    time += dt;
    _dt = dt;
    for (final u in state.units) {
      // One the moment (or the win) is drawing stays where it was made.
      if ((_moment?.hide.contains(u.id) ?? false) || _win?.unitId == u.id) {
        continue;
      }
      final to = targetFeet(u.id);
      final at = feet[u.id] ?? to;
      feet[u.id] = Offset.lerp(at, to, 1 - math.exp(-dt * 9))!;
    }
    final step = dt * _kPace * (hurry ? _kHurry : 1);
    final m = _moment;
    if (m != null) _advance(m, step);
    final w = _win;
    if (w != null) _advanceWin(w, step);
    _tick.value++;
  }

  void _advance(_Moment m, double dt) {
    m.t += dt;
    m.morph?.update(dt);
    final r = m.rise;
    if (r != null && m.meetEl != null) {
      final rt = m.t - m.riseFrom;
      if (rt >= r.hitAt && m.meetT < 0) {
        m.meetT = m.t;
        final orb = _orb(m.meetEl!, m.altar, m.meetSlot);
        m.meetGrains = orb.grainsAt(time);
        // The meeting draws it now; its own presence goes at once.
        _e['o:${m.altar}:${m.meetSlot}'] = 0;
        HapticFeedback.lightImpact();
        context.sound(SoundCue.dungeonSecretReveal);
      }
      if (rt >= r.returnAt && m.after == null && m.landedSpecies != null) {
        m.afterFrom = m.t;
        m.after = RiteMorphFx(
          targets: [(m.landedSpecies!.body, m.landedAt)],
          from: r.at + r.up * (r.reach + 20),
          flight: .8,
        );
      }
    }
    m.after?.update(dt);
    if (m.t >= m.end) {
      _moment = null;
      hurry = false;
      // What it made was shown by the moment: it stands there fully now.
      for (final id in m.hide) {
        if (unitOf(id) != null) _e['p:$id'] = 1;
      }
      _checkWin();
    }
  }

  void _advanceWin(_Win w, double dt) {
    w.t += dt;
    final r = w.rise;
    final hit = r?.hitAt ?? .3;
    if (!w.lit && w.t >= hit) {
      w.lit = true;
      final head = r == null ? wordCentre : r.at + r.up * (r.reach + 20);
      goalWord?.lightFrom(head.dx - wordCentre.dx, time);
      HapticFeedback.heavyImpact();
      context.sound(SoundCue.dungeonPuzzleSolved);
    }
    if (!showResult && w.t >= w.shown) {
      hurry = false;
      setState(() => showResult = true);
    }
  }

  ElementOrb _orb(String el, int ai, int k) => _orbs.putIfAbsent(
    '$el $ai $k',
    () => ElementOrb(EssenceElement.of(el), radius: _kOrbR),
  );

  // ── moves ────────────────────────────────────────────────

  void _push() => _history.add(_Snap(state, List.of(order)));

  void _clearSeats() {
    seats = [
      for (var i = 0; i < level.altars; i++) [null, null],
    ];
    onSplit = null;
    selected = null;
  }

  Future<void> _fire(int ai) async {
    if (_moment != null || won) return;
    final a = unitOf(seats[ai][0] ?? ''), b = unitOf(seats[ai][1] ?? '');
    if (a == null || b == null) return;
    final f = altarFuse(level, state, ai, a, b);
    final fa = feet[a.id] ?? seatFeet(ai, 0),
        fb = feet[b.id] ?? seatFeet(ai, 1);
    final spA = bodies.ready(a.el, a.fam), spB = bodies.ready(b.el, b.fam);
    if (f == null) {
      // A pair that makes nothing: a breath of their colours, and nothing.
      HapticFeedback.selectionClick();
      setState(() {
        _moment = _Moment(
          hide: const {},
          altar: ai,
          fizzleAt: altarFeet(ai) - const Offset(0, 24),
          fizzleCols: [
            elementOrbTint(EssenceElement.of(a.el)),
            elementOrbTint(EssenceElement.of(b.el)),
          ],
        );
      });
      return;
    }
    final made = f.made, landed = f.landed;
    final loads = await Future.wait([
      bodies.load(made.el, made.fam),
      bodies.load(landed.el, landed.fam),
    ]);
    if (!mounted) return;
    final spMade = loads[0], spLanded = loads[1];
    HapticFeedback.mediumImpact();
    context.sound(SoundCue.fusionMerge);
    final at = (spMade ?? spA)?.centreFor(altarFeet(ai)) ?? altarFeet(ai);
    final prevColumn = List<String>.of(state.columns[ai]);
    final cA = spA?.centreFor(fa) ?? fa, cB = spB?.centreFor(fb) ?? fb;
    final morph = RiteMorphFx(
      sources: [
        if (spA != null) (spA.body, cA),
        if (spB != null) (spB.body, cB),
      ],
      targets: [if (spMade != null) (spMade.body, at)],
      flight: .8,
    );
    HeartRiseFx? rise;
    final firstSlot = slotOf(ai, prevColumn.length, 0);
    if (f.rose && spMade != null) {
      // Up to the near side of what hangs there, or up toward the goal.
      final top = prevColumn.isEmpty
          ? wordBottom + 30
          : orbAt(ai, firstSlot).dy + 6;
      rise = HeartRiseFx(
        body: spMade.body,
        el: made.el,
        at: at,
        reach: math.max(40.0, at.dy - top - 20),
        hits: prevColumn.isNotEmpty,
        into: f.fusedUp ? landed.el : null,
      );
    }
    setState(() {
      _push();
      state = f.state;
      // The new one comes down where it was made, and walks to the stage.
      feet[landed.id] = altarFeet(ai);
      final i = math.min(order.indexOf(a.id), order.indexOf(b.id));
      order
        ..remove(a.id)
        ..remove(b.id)
        ..insert(i.clamp(0, order.length), landed.id);
      seats[ai] = [null, null];
      selected = null;
      _moment = _Moment(
        hide: {landed.id},
        altar: ai,
        morph: morph,
        morphSources: [(spA, cA), (spB, cB)],
        morphTargets: [(spMade, at)],
        rise: rise,
        // It stands there a moment, named, before it goes up.
        riseFrom: rise == null ? 0 : morph.duration + _kMadeHold,
        riseSpecies: spMade,
        meetSlot: firstSlot,
        meetEl: f.met,
        meetAt: f.fusedUp ? orbAt(ai, firstSlot) : Offset.zero,
        prevColumn: prevColumn,
        landedSpecies: f.fusedUp ? spLanded : null,
        landedAt: (spLanded ?? spMade)?.centreFor(altarFeet(ai)) ?? at,
        madeName: level.species
            ? (spMade?.name ?? '${made.el}${made.fam.toLowerCase()}')
            : made.el,
        madeTint: elementOrbTint(EssenceElement.of(made.el)),
      );
    });
  }

  Future<void> _split() async {
    if (_moment != null || won) return;
    final u = unitOf(onSplit ?? '');
    if (u == null) return;
    final sp = altarSplit(state, u);
    if (sp == null) return;
    final (next, p, q) = sp;
    final loads = await Future.wait([
      bodies.load(p.el, p.fam),
      bodies.load(q.el, q.fam),
    ]);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.sound(SoundCue.fusionRecoil);
    final spU = bodies.ready(u.el, u.fam);
    final c = spU?.centreFor(feet[u.id] ?? splitFeet) ?? splitFeet;
    final fp = splitFeet + const Offset(-18, 0),
        fq = splitFeet + const Offset(20, 0);
    final cp = loads[0]?.centreFor(fp) ?? fp,
        cq = loads[1]?.centreFor(fq) ?? fq;
    setState(() {
      _push();
      state = next;
      feet[p.id] = fp;
      feet[q.id] = fq;
      final i = order.indexOf(u.id);
      order
        ..remove(u.id)
        ..insertAll(i.clamp(0, order.length), [p.id, q.id]);
      onSplit = null;
      selected = null;
      final morph = RiteMorphFx(
        sources: [if (spU != null) (spU.body, c)],
        targets: [
          if (loads[0] != null) (loads[0]!.body, cp),
          if (loads[1] != null) (loads[1]!.body, cq),
        ],
        flight: .8,
      );
      _moment = _Moment(
        hide: {p.id, q.id},
        morph: morph,
        morphSources: [(spU, c)],
        morphTargets: [(loads[0], cp), (loads[1], cq)],
      );
    });
  }

  /// Back to [next] without a moment (undo, start again): whoever leaves
  /// thins away where they stand, whoever comes back fades in at their
  /// place, and the word lets its light go.
  void _restore(AltarState next, List<String> nextOrder) {
    final before = {for (final u in state.units) u.id: u};
    final after = {for (final u in next.units) u.id};
    for (final MapEntry(key: id, value: u) in before.entries) {
      if (after.contains(id) || _win?.unitId == id) continue;
      final sp = bodies.ready(u.el, u.fam);
      final f = feet[id];
      if (sp == null || f == null) continue;
      _ghosts.add(
        AltarGhost(
          (canvas, c, a) => sp.paint(canvas, c, time, alpha: a),
          sp.centreFor(f),
          time,
        ),
      );
    }
    state = next;
    order = nextOrder;
    won = false;
    showResult = false;
    _win = null;
    _clearSeats();
    for (final u in state.units) {
      if (!before.containsKey(u.id) || feet[u.id] == null) {
        _e['p:${u.id}'] = 0;
        feet[u.id] = targetFeet(u.id);
      } else if (_e['p:${u.id}'] != null && _e['p:${u.id}']! < 1) {
        // The goal that became its word: it gathers back where it was.
        feet[u.id] = targetFeet(u.id);
      }
    }
  }

  void _undo() {
    if (_moment != null || _history.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      final s = _history.removeLast();
      _restore(s.state, s.order);
    });
  }

  void _reset() {
    if (_moment != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _history.clear();
      final s0 = altarStart(level);
      _restore(s0, [for (final u in s0.units) u.id]);
    });
  }

  void _checkWin() {
    if (won || !altarDone(level, state)) return;
    final u = state.units.firstWhere(level.caught);
    final sp = bodies.ready(u.el, u.fam);
    HeartRiseFx? rise;
    if (sp != null) {
      final c = sp.centreFor(feet[u.id] ?? targetFeet(u.id));
      rise = HeartRiseFx(
        body: sp.body,
        el: u.el,
        at: c,
        reach: math.max(40.0, c.dy - wordBottom - 22),
        hits: true,
        into: u.el,
      );
    }
    final moves = _history.length;
    setState(() {
      won = true;
      stars = level.starsFor(moves);
      _win = _Win(u.id, rise);
    });
    HapticFeedback.mediumImpact();
    context.sound(SoundCue.fusionPour);
    widget.progress.record(widget.number, stars);
  }

  // ── seating ──────────────────────────────────────────────

  /// Move [id] to [to]; whoever was there goes where [id] came from.
  void _seat(String id, _Place to) {
    final from = _placeOf(id);
    final u = unitOf(id);
    if (u == null) return;
    if (to.kind == _PlaceKind.split && u.parts == null) {
      HapticFeedback.selectionClick();
      return; // only what was made comes apart
    }
    String? there;
    switch (to.kind) {
      case _PlaceKind.seat:
        there = seats[to.altar][to.side];
      case _PlaceKind.split:
        there = onSplit;
      case _PlaceKind.stage:
        there = null;
    }
    if (there == id) return;
    void put(String? who, _Place p) {
      switch (p.kind) {
        case _PlaceKind.seat:
          seats[p.altar][p.side] = who;
        case _PlaceKind.split:
          onSplit = who;
        case _PlaceKind.stage:
          break;
      }
    }

    put(null, from);
    put(id, to);
    if (there != null) {
      final back =
          (from.kind == _PlaceKind.split && unitOf(there)?.parts == null)
          ? const _Place.stage()
          : from;
      put(there, back);
    }
    HapticFeedback.selectionClick();
  }

  // ── input ────────────────────────────────────────────────

  Offset _toUnits(Offset local) => (local - _origin) / _u;

  String? _unitAt(Offset p) {
    String? best;
    var bd = 30.0;
    for (final u in state.units) {
      if (_moment?.hide.contains(u.id) ?? false) continue;
      final f = feet[u.id] ?? targetFeet(u.id);
      final d = (centreOf(u, f) - p).distance;
      if (d < bd) {
        bd = d;
        best = u.id;
      }
    }
    return best;
  }

  _Place? _placeAt(Offset p, {double reach = 34}) {
    _Place? best;
    var bd = reach;
    for (var a = 0; a < level.altars; a++) {
      for (var s = 0; s < 2; s++) {
        final d = (seatFeet(a, s) - const Offset(0, 14) - p).distance;
        if (d < bd) {
          bd = d;
          best = _Place.seat(a, s);
        }
      }
    }
    if (level.split) {
      final d = (splitFeet - const Offset(0, 14) - p).distance;
      if (d < bd) best = const _Place.split();
    }
    return best;
  }

  /// The FUSE label under altar [ai] and the SPLIT one under the stage.
  Rect fuseRect(int ai) => Rect.fromCenter(
    center: altarFeet(ai) + const Offset(0, 30),
    width: 58,
    height: 22,
  );
  Rect get splitRect => Rect.fromCenter(
    center: splitFeet + const Offset(0, 25),
    width: 58,
    height: 20,
  );

  bool loaded(int ai) => seats[ai][0] != null && seats[ai][1] != null;

  void _onTap(TapUpDetails d) {
    if (_moment != null || (_win != null && !showResult)) {
      hurry = true;
      return;
    }
    if (won) return;
    final p = _toUnits(d.localPosition);
    for (var a = 0; a < level.altars; a++) {
      if (loaded(a) && fuseRect(a).inflate(6).contains(p)) {
        _fire(a);
        return;
      }
    }
    if (onSplit != null && splitRect.inflate(6).contains(p)) {
      _split();
      return;
    }
    final hit = _unitAt(p);
    final place = _placeAt(p);
    setState(() {
      if (hit != null && (selected == null || selected == hit)) {
        selected = selected == hit ? null : hit;
      } else if (selected != null && place != null) {
        _seat(selected!, place);
        selected = null;
      } else if (selected != null && hit != null) {
        // Tapping another creature: choose that one instead, or swap a
        // seated one with the one in hand.
        if (_placeOf(hit).kind != _PlaceKind.stage) {
          _seat(selected!, _placeOf(hit));
          selected = null;
        } else {
          selected = hit;
        }
      } else if (selected != null) {
        _seat(selected!, const _Place.stage());
        selected = null;
      }
    });
  }

  void _onPanStart(DragStartDetails d) {
    if (_moment != null || won) return;
    final p = _toUnits(d.localPosition);
    final hit = _unitAt(p);
    if (hit == null) return;
    setState(() {
      dragging = hit;
      selected = null;
      dragAt = p;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (dragging == null) return;
    dragAt = _toUnits(d.localPosition);
  }

  /// Where a creature carried at [dragAt] would be put down.
  _Place? get _dropTarget => dragging == null
      ? null
      : _placeAt(dragAt + const Offset(0, 10), reach: 40);

  void _onPanEnd(DragEndDetails _) {
    final id = dragging;
    if (id == null) return;
    final to = _dropTarget;
    setState(() {
      dragging = null;
      final u = unitOf(id);
      final sp = u == null ? null : bodies.ready(u.el, u.fam);
      // It is put down where the finger let go, and walks from there.
      feet[id] = dragAt + Offset(0, (sp?.feet ?? .4) * (sp?.box ?? 38));
      _seat(id, to ?? const _Place.stage());
    });
  }

  // ── test seams: where things are on screen ───────────────

  final GlobalKey _theatreKey = GlobalKey();

  Offset _global(Offset units) {
    final box = _theatreKey.currentContext!.findRenderObject()! as RenderBox;
    return box.localToGlobal(_origin + units * _u);
  }

  @visibleForTesting
  AltarState get debugState => state;
  @visibleForTesting
  bool get debugBusy => _moment != null || (_win != null && !showResult);
  @visibleForTesting
  bool get debugWon => won;
  @visibleForTesting
  int get debugMoves => _history.length;
  @visibleForTesting
  Offset debugUnit(String id) {
    final u = unitOf(id)!;
    return _global(centreOf(u, feet[id] ?? targetFeet(id)));
  }

  @visibleForTesting
  Offset debugSeat(int ai, int side) =>
      _global(seatFeet(ai, side) - const Offset(0, 14));
  @visibleForTesting
  Offset debugFuse(int ai) => _global(fuseRect(ai).center);
  @visibleForTesting
  Offset get debugSplit => _global(splitFeet - const Offset(0, 14));
  @visibleForTesting
  Offset get debugSplitButton => _global(splitRect.center);

  // ── the screen ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.watch<FactionTheme>());
    final moves = _history.length;
    final teach = _teachFor(widget.number, chapter);
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      letterSpacing: 1.4,
      color: t.textSecondary,
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // The chapter's realm, behind everything.
          Positioned.fill(child: AltarRealmView(realm: altarRealmFor(chapter))),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // ── the bar ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: t.textSecondary,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Text(
                              'LEVEL ${widget.number} · ${chapter.name.toUpperCase()}',
                              style: mono.copyWith(color: t.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Recipes',
                            icon: Icon(
                              Icons.menu_book_outlined,
                              color: t.amber,
                            ),
                            onPressed: () =>
                                showAltarRecipeBook(context, level),
                          ),
                          AnimatedOpacity(
                            opacity: _history.isEmpty ? .35 : 1,
                            duration: const Duration(milliseconds: 260),
                            child: IconButton(
                              tooltip: 'Undo',
                              icon: Icon(Icons.undo, color: t.textPrimary),
                              onPressed: _history.isEmpty ? null : _undo,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Start again',
                            icon: Icon(Icons.replay, color: t.textPrimary),
                            onPressed: _reset,
                          ),
                        ],
                      ),
                    ),
                    // ── the lesson, and the count ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: teach == null
                                ? const SizedBox.shrink()
                                : TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 900),
                                    curve: const Interval(
                                      .4,
                                      1,
                                      curve: Curves.easeOut,
                                    ),
                                    builder: (context, k, child) => Opacity(
                                      opacity: k,
                                      child: Transform.translate(
                                        offset: Offset(0, 6 * (1 - k)),
                                        child: child,
                                      ),
                                    ),
                                    child: Text(
                                      teach,
                                      style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 12.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Text('MOVES ', style: mono),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, a) => FadeTransition(
                              opacity: a,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(0, .4),
                                  end: Offset.zero,
                                ).animate(a),
                                child: child,
                              ),
                            ),
                            child: Text(
                              '$moves',
                              key: ValueKey(moves),
                              style: mono.copyWith(color: t.textPrimary),
                            ),
                          ),
                          Text('  ·  PAR ${level.par}', style: mono),
                        ],
                      ),
                    ),
                    // ── the stage ──
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final u = math.min(
                            1.9,
                            math.min(
                              box.maxWidth / _needW,
                              box.maxHeight / _needH,
                            ),
                          );
                          _u = u;
                          _units = Size(box.maxWidth / u, box.maxHeight / u);
                          _origin = Offset.zero;
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: _onTap,
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: CustomPaint(
                              key: _theatreKey,
                              size: Size(box.maxWidth, box.maxHeight),
                              painter: _StagePainter(this, t),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                if (showResult)
                  _ResultCard(
                    t: t,
                    mono: mono,
                    stars: stars,
                    moves: moves,
                    par: level.par,
                    onLevels: () => Navigator.of(context).pop(),
                    onAgain: _reset,
                    onNext: widget.number < kAltarLevels.length
                        ? () => Navigator.of(context).pushReplacement(
                            PageRouteBuilder<void>(
                              transitionDuration: const Duration(
                                milliseconds: 420,
                              ),
                              pageBuilder: (_, _, _) => AltarPlayScreen(
                                number: widget.number + 1,
                                progress: widget.progress,
                              ),
                              transitionsBuilder: (_, a, _, child) =>
                                  FadeTransition(opacity: a, child: child),
                            ),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The result, rising in over the stage, its stars filling one by one.
class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.t,
    required this.mono,
    required this.stars,
    required this.moves,
    required this.par,
    required this.onLevels,
    required this.onAgain,
    this.onNext,
  });
  final ForgeTokens t;
  final TextStyle mono;
  final int stars, moves, par;
  final VoidCallback onLevels, onAgain;
  final VoidCallback? onNext;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t, mono = widget.mono;
    Widget button(String label, VoidCallback onTap, {bool lit = false}) =>
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: lit ? t.amberBright : t.textSecondary,
            backgroundColor: lit
                ? t.amber.withValues(alpha: .14)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          child: Text(
            label,
            style: mono.copyWith(color: lit ? t.amberBright : t.textSecondary),
          ),
        );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final inK = Curves.easeOutCubic.transform((v / .35).clamp(0.0, 1.0));
        return Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: .5 * inK),
            child: Center(
              child: Opacity(
                opacity: inK,
                child: Transform.translate(
                  offset: Offset(0, 18 * (1 - inK)),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
                    decoration: BoxDecoration(
                      color: t.bg1,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SOLVED',
                          style: mono.copyWith(
                            color: t.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Each star lights in turn, from its heart out.
                        SizedBox(
                          width: 156,
                          height: 46,
                          child: CustomPaint(
                            painter: _ResultStars(widget.stars, v, inK),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${widget.moves} ${widget.moves == 1 ? 'move' : 'moves'}  ·  par ${widget.par}',
                          style: mono,
                        ),
                        if (widget.stars < 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'It can be done in ${widget.par}.',
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            button('LEVELS', widget.onLevels),
                            button('AGAIN', widget.onAgain),
                            if (widget.onNext != null)
                              button('NEXT', widget.onNext!, lit: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The result's three stars in grains: ash until won, each won one lit in
/// turn from its heart out to its tips.
class _ResultStars extends CustomPainter {
  _ResultStars(this.stars, this.v, this.shown);
  final int stars;
  final double v, shown;
  static final RiteGrainBatch _batch = RiteGrainBatch();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final s = ((v - .3 - i * .18) / .3).clamp(0.0, 1.0);
      paintGrainStar(
        _batch,
        Offset(size.width / 2 + (i - 1) * 52, size.height / 2),
        15,
        lit: i < stars ? Curves.easeInOut.transform(s) : 0,
        alpha: shown,
        canvas: canvas,
        salt: i,
      );
    }
    _batch.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _ResultStars old) =>
      old.stars != stars || old.v != v || old.shown != shown;
}

// ═══════════════════════════ THE STAGE ═════════════════════════════════════

class _StagePainter extends CustomPainter {
  _StagePainter(this.s, this.t) : super(repaint: s._tick);
  final AltarPlayScreenState s;
  final ForgeTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final time = s.time;
    canvas.save();
    canvas.translate(s._origin.dx, s._origin.dy);
    canvas.scale(s._u);
    final w = s._units.width;
    final level = s.level;
    final m = s._moment;
    final batch = s.batch;
    final stage = s._ease('stage', time > .1 ? 1 : 0, rate: 4);

    // ── the ground (the realm's own): light where the stage stands ──
    paintFloorPool(
      canvas,
      Offset(w / 2, s.altarY + 4),
      w * .62,
      26,
      kAltarBrass,
      .07 * stage,
    );
    paintFloorPool(
      canvas,
      Offset(w / 2, s.stageY + 2),
      w * .7,
      30,
      kAltarBrass,
      .06 * stage,
    );

    // Shade where the hand waits, so its creatures and names read over the
    // realm's foreground.
    paintFloorShade(
      canvas,
      Offset(w / 2, s.stageY + 8),
      w * .62,
      46,
      .55 * stage,
    );

    // ── each altar's column, up toward the goal ──
    for (var a = 0; a < level.altars; a++) {
      final lift = s._ease(
        'col:$a',
        m != null && m.altar == a && m.rising ? 1 : 0,
        rate: 5,
      );
      final winLift = s._win != null
          ? s._ease('colwin', 1, rate: 3)
          : s._ease('colwin', 0, rate: 3);
      paintColumn(
        canvas,
        batch,
        s.altarX(a),
        s.altarY - 12,
        s.wordBottom + 6,
        time,
        lift: math.max(lift, winLift * .5),
        fade: stage,
        salt: a,
      );
    }
    batch.paint(canvas);

    // ── the goal, its word in grains ──
    final word = s.goalWord;
    if (word != null) {
      final lit = s._ease('lit', s.won ? 1 : 0, rate: 4);
      // "MAKE", small, over it.
      // A long name is drawn smaller, to fit the stage.
      word.fit = math.min(1.0, (w - 36) / word.naturalWidth);
      final makeA = s._ease('make', 1, rate: 2.5) * (1 - .6 * lit);
      _text(
        canvas,
        'MAKE',
        s.wordCentre - Offset(0, word.height / 2 + 12),
        t.textMuted,
        makeA,
        size: 8,
      );
      paintFloorShade(
        canvas,
        s.wordCentre,
        word.width * .72 + 30,
        word.height * 1.1 + 12,
        .45 * s._ease('make', 1, rate: 2.5),
      );
      final held = s._ease(
        'held',
        altarHeld(level, s.state) && s._moment == null ? 1 : 0,
        rate: 3,
      );
      word.paint(canvas, batch, s.wordCentre, time, lit: lit, held: held);
    }

    // ── what hangs over each altar ──
    for (var a = 0; a < level.altars; a++) {
      final colNow = s.state.columns[a];
      final meeting = m != null && m.altar == a && m.meetEl != null;
      final col = meeting && m.meetT < 0 ? m.prevColumn! : colNow;
      final shown = <int>{};
      for (var k = 0; k < col.length; k++) {
        final slot = s.slotOf(a, col.length, k);
        shown.add(slot);
        final key = 'o:$a:$slot';
        final p = s._ease(key, s._shown(key) ? 1 : 0, rate: 6);
        if (p <= .01) continue;
        final at = s.orbAt(a, slot) + Offset(0, 10 * (1 - p));
        s
            ._orb(col[k], a, slot)
            .paint(canvas, at, time + a * 1.7 + slot * .9, fade: p);
        _name(
          canvas,
          col[k],
          at + const Offset(0, _kOrbR + 6),
          elementOrbTint(EssenceElement.of(col[k])),
          p,
        );
      }
      // Anything that was there and is not now fades on its own key.
      for (var slot = 0; slot < level.columns[a].length; slot++) {
        if (!shown.contains(slot)) s._ease('o:$a:$slot', 0, rate: 6);
      }
    }

    // ── the altars: a pool of light under two sand-ring seats ──
    final drop = s._dropTarget;
    for (var a = 0; a < level.altars; a++) {
      final ua = s.unitOf(s.seats[a][0] ?? ''),
          ub = s.unitOf(s.seats[a][1] ?? '');
      final n = (ua == null ? 0 : 1) + (ub == null ? 0 : 1);
      final warm = s._ease('pool:$a', n == 2 ? 1 : (n == 1 ? .45 : 0), rate: 6);
      final cols = [
        if (ua != null) elementOrbTint(EssenceElement.of(ua.el)),
        if (ub != null) elementOrbTint(EssenceElement.of(ub.el)),
      ];
      final poolCol = switch (cols.length) {
        0 => kAltarBrass,
        1 => Color.lerp(kAltarBrass, cols[0], .5)!,
        _ => Color.lerp(cols[0], cols[1], .5)!,
      };
      paintFloorShade(
        canvas,
        s.altarFeet(a) + const Offset(0, 5),
        62,
        20,
        .55 * stage,
      );
      paintFloorPool(
        canvas,
        s.altarFeet(a) + const Offset(0, 4),
        50,
        15,
        kAltarBrass,
        (.1 + .05 * warm) * stage,
      );
      paintFloorPool(
        canvas,
        s.altarFeet(a) + const Offset(0, 4),
        46,
        14,
        poolCol,
        (.2 * warm + .08 * math.sin(time * 2.2) * warm) * stage,
      );
      for (var side = 0; side < 2; side++) {
        final who = side == 0 ? ua : ub;
        final over = drop != null && drop.same(_Place.seat(a, side));
        final hint = s.selected != null && who == null ? .35 : 0.0;
        final g = s._ease(
          'seat:$a:$side',
          over ? 1 : (who != null ? .6 : hint),
          rate: 10,
        );
        paintSeatRing(
          batch,
          s.seatFeet(a, side) + const Offset(0, 1),
          time,
          glow: g,
          fade: stage,
          tint: who == null ? null : elementOrbTint(EssenceElement.of(who.el)),
          salt: a * 2 + side,
        );
      }
    }
    // ── the split stage ──
    if (level.split) {
      final held = s.unitOf(s.onSplit ?? '');
      final carried = s.unitOf(s.dragging ?? s.selected ?? '');
      final over = drop != null && drop.kind == _PlaceKind.split;
      final g = s._ease(
        'split',
        over ? 1 : (held != null ? .7 : (carried?.parts != null ? .35 : 0)),
        rate: 10,
      );
      paintFloorShade(
        canvas,
        s.splitFeet + const Offset(0, 3),
        40,
        14,
        .5 * stage,
      );
      paintFloorPool(
        canvas,
        s.splitFeet + const Offset(0, 2),
        30,
        10,
        kAltarBrass,
        (.08 + .1 * g) * stage,
      );
      paintSplitRing(
        batch,
        s.splitFeet + const Offset(0, 1),
        time,
        glow: g,
        fade: stage,
      );
    }
    batch.paint(canvas);
    for (var a = 0; a < level.altars; a++) {
      final f = s._ease(
        'fuse:$a',
        s.loaded(a) && m == null && !s.won ? 1 : 0,
        rate: 10,
      );
      if (f > .01) _label(canvas, 'FUSE', s.fuseRect(a), f);
    }
    if (level.split) {
      final on = s.onSplit != null && m == null && !s.won;
      final f = s._ease('splitLbl', on ? 1 : .3, rate: 10, init: .3) * stage;
      _label(canvas, 'SPLIT', s.splitRect, f, quiet: !on);
    }

    // ── the creatures ──
    final names = _stageNames();
    final win = s._win;
    // The goal on the stage: lit under it from the moment it is made.
    final caught = s.state.units.where(level.caught).firstOrNull;
    final drawn = [
      ...s.state.units,
    ]..sort((p, q) => (s.feet[p.id]?.dy ?? 0).compareTo(s.feet[q.id]?.dy ?? 0));
    for (final u in drawn) {
      final hidden = (m?.hide.contains(u.id) ?? false) || win?.unitId == u.id;
      final key = 'p:${u.id}';
      final pr = hidden
          ? (s._e[key] ?? 0)
          : s._ease(key, s._shown(key) ? 1 : 0, rate: 7);
      if (hidden || pr <= .01) continue;
      final sp = s.bodies.ready(u.el, u.fam);
      var f = s.feet[u.id] ?? s.targetFeet(u.id);
      final lifted = s.dragging == u.id;
      if (lifted) f = s.dragAt + Offset(0, (sp?.feet ?? .4) * (sp?.box ?? 38));
      final sel = s._ease(
        'sel:${u.id}',
        s.selected == u.id || lifted ? 1 : 0,
        rate: 12,
      );
      final tint = elementOrbTint(EssenceElement.of(u.el));
      // Its own light on the ground, and the brass of being chosen.
      paintFloorPool(
        canvas,
        f + const Offset(0, 1),
        (sp?.box ?? 38) * .55,
        7,
        tint,
        (.14 + .1 * sel) * pr,
      );
      if (sel > .01) {
        paintFloorPool(
          canvas,
          f + const Offset(0, 1),
          30,
          10,
          kAltarBrass,
          .28 * sel * pr,
        );
      }
      if (caught?.id == u.id) {
        vfxSpill(
          canvas,
          f - const Offset(0, 14),
          60,
          tint,
          .3 + .08 * math.sin(time * 3),
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: f + const Offset(0, 1),
          width: (sp?.box ?? 38) * .5,
          height: 4.5,
        ),
        Paint()..color = Colors.black.withValues(alpha: .45 * pr),
      );
      final rise = 8 * (1 - pr) + 3 * sel;
      if (sp != null) {
        sp.paint(
          canvas,
          sp.centreFor(f) - Offset(0, rise),
          time + (u.id.hashCode % 7) * .13,
          alpha: pr,
          scale: 1 + .06 * sel,
        );
      } else {
        canvas.drawCircle(
          f - Offset(0, 16 + rise),
          13,
          Paint()..color = tint.withValues(alpha: .8 * pr),
        );
      }
      final named = names[u.id];
      if (!lifted && named != null) {
        _name(
          canvas,
          named.$1,
          f + Offset(0, 9 + named.$3),
          tint,
          pr,
          size: named.$2,
        );
      }
    }
    s._ghosts.removeWhere((g) => !g.paint(canvas, time));

    // ── the moment, and the goal going up to its word ──
    if (m != null) _moment(canvas, m, time);
    if (win != null) {
      final r = win.rise;
      if (r != null && win.t < r.duration) {
        final sp = s.bodies.ready(
          s.unitOf(win.unitId)?.el ?? level.goal,
          s.unitOf(win.unitId)?.fam ?? kBaseFamily,
        );
        final a = r.spriteAlpha(win.t);
        if (sp != null && a > .01) sp.paint(canvas, r.at, time, alpha: a);
        r.paint(canvas, batch, win.t, time);
        batch.paint(canvas);
      }
    }

    canvas.restore();
  }

  void _moment(Canvas canvas, _Moment m, double time) {
    final batch = s.batch;
    final morph = m.morph;
    if (morph != null && morph.t < morph.duration + .01) {
      for (var i = 0; i < m.morphSources.length; i++) {
        final (sp, c) = m.morphSources[i];
        if (sp == null || morph.cut >= 1) continue;
        final half = kAltarSnapBox / 2;
        final crest = i < morph.sources.length ? morph.crestLocal(i) : -half;
        sp.paint(
          canvas,
          c,
          time,
          clip: Rect.fromLTRB(
            c.dx - half,
            c.dy + crest,
            c.dx + half,
            c.dy + half,
          ),
        );
      }
      morph.paint(canvas, batch, time);
    }
    final r = m.rise;
    if (morph != null) {
      final riseT = m.t - m.riseFrom;
      // Made, it stands on the altar until it rises; then the rise decides
      // how much of it shows.
      final standing = r == null
          ? morph.t < morph.duration + .01
          : riseT < 0;
      if (standing) {
        for (final (sp, c) in m.morphTargets) {
          sp?.paint(canvas, c, time, alpha: morph.reveal);
        }
      }
      final name = m.madeName;
      if (name != null && m.altar >= 0) {
        final out = r == null ? 0.0 : (riseT / .25).clamp(0.0, 1.0);
        _name(
          canvas,
          name,
          s.altarFeet(m.altar) + const Offset(0, 9),
          m.madeTint,
          morph.reveal * (1 - out),
        );
      }
    }
    if (r != null) {
      final rt = m.t - m.riseFrom;
      if (rt >= 0) {
        final sp = m.riseSpecies;
        final a = r.spriteAlpha(rt);
        if (sp != null && a > .01) sp.paint(canvas, r.at, time, alpha: a);
        r.paint(canvas, batch, rt, time);
      }
    }
    if (m.meetT >= 0 && m.meetGrains != null) {
      final since = m.t - m.meetT;
      final orb = s._orb(m.meetEl!, m.altar, m.meetSlot);
      final glass = 1 - (since / .3).clamp(0.0, 1.0);
      if (glass > .01) {
        orb.paint(canvas, m.meetAt, time, grains: false, opacity: glass);
      }
      paintHeartMeet(batch, m.meetGrains!, m.meetAt, since);
    }
    final after = m.after;
    if (after != null) {
      final sp = m.landedSpecies;
      if (sp != null) sp.paint(canvas, m.landedAt, time, alpha: after.reveal);
      after.paint(canvas, batch, time);
    }
    final fz = m.fizzleAt;
    if (fz != null) {
      paintHeartFizzle(batch, fz, m.t, m.fizzleCols[0], m.fizzleCols[1]);
    }
    batch.paint(canvas);
  }

  static final Map<String, TextPainter> _texts = {};

  TextPainter _tp(
    String text,
    Color color,
    double size, {
    double spacing = .8,
    bool bold = false,
  }) => _texts.putIfAbsent('$text|${color.toARGB32()}|$size|$bold', () {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size,
          letterSpacing: spacing,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
  });

  void _text(
    Canvas canvas,
    String text,
    Offset centre,
    Color color,
    double alpha, {
    double size = 9,
  }) {
    if (alpha <= .01) return;
    final tp = _tp(text, color, size, spacing: 2);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  }

  /// A creature's or an element's name, small, under it.
  void _name(
    Canvas canvas,
    String text,
    Offset topCentre,
    Color tint,
    double alpha, {
    double size = _kNameSize,
  }) {
    if (alpha <= .01) return;
    final col = Color.lerp(
      tint,
      const Color(0xFFE6E2DA),
      .45,
    )!.withValues(alpha: .78 * alpha);
    final tp = _tp(text.toUpperCase(), col, size);
    tp.paint(canvas, topCentre - Offset(tp.width / 2, 0));
  }

  static const double _kNameSize = 7.5, _kNameMin = 6.2;

  /// The names under the creatures on the stage, sized so neighbours never
  /// touch (the author, 2026-10-08: on level 21 "the words run into each
  /// other"): each row is shrunk just enough to fit, and if even the
  /// smallest size cannot, every other name drops to a second line.
  /// Creature id → (name, size, drop).
  Map<String, (String, double, double)> _stageNames() {
    final level = s.level;
    final ids = s.stageIds;
    final out = <String, (String, double, double)>{};
    final rows = <double, List<(String, double, String)>>{};
    for (final id in ids) {
      final u = s.unitOf(id)!;
      final sp = s.bodies.ready(u.el, u.fam);
      final text = level.species
          ? (sp?.name ?? '${u.el}${u.fam.toLowerCase()}')
          : u.el;
      final at = s.stageFeet(id);
      (rows[at.dy] ??= []).add((id, at.dx, text));
    }
    for (final row in rows.values) {
      row.sort((a, b) => a.$2.compareTo(b.$2));
      double width(String t, double size) =>
          _tp(t.toUpperCase(), const Color(0xFFFFFFFF), size).width;
      // The size that fits every pair of neighbours with a little air.
      var size = _kNameSize;
      for (var i = 1; i < row.length; i++) {
        final gap = row[i].$2 - row[i - 1].$2;
        final need =
            (width(row[i].$3, _kNameSize) + width(row[i - 1].$3, _kNameSize)) /
                2 +
            4;
        if (need > gap) size = math.min(size, _kNameSize * gap / need);
      }
      final stagger = size < _kNameMin;
      size = (math.max(size, _kNameMin) * 10).floorToDouble() / 10;
      for (var i = 0; i < row.length; i++) {
        out[row[i].$1] = (row[i].$3, size, stagger && i.isOdd ? 9.0 : 0.0);
      }
    }
    return out;
  }

  /// A plain label, lit from below when it can be pressed.
  void _label(
    Canvas canvas,
    String text,
    Rect r,
    double alpha, {
    bool quiet = false,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.inflate(2), const Radius.circular(4)),
      Paint()
        ..color = Colors.black.withValues(alpha: (quiet ? .35 : .55) * alpha),
    );
    if (!quiet) {
      paintFloorPool(
        canvas,
        r.bottomCenter,
        r.width * .6,
        7,
        t.amberBright,
        .35 * alpha,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()..color = t.amber.withValues(alpha: .14 * alpha),
      );
    }
    final col = quiet ? t.textMuted : t.amberBright;
    final tp = _tp(text, col, 10, spacing: 1.6, bold: true);
    canvas.saveLayer(
      null,
      Paint()..color = Color.fromRGBO(0, 0, 0, (quiet ? .6 : 1) * alpha),
    );
    tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => true;
}
