// lib/widgets/wilderness/mutation_meter.dart
//
// THE MUTATION METER, in the wild.
//
// A slim glass on the left edge, between Exit and Items, holding a column of
// lit grains: one notch for every wilderness fusion since the last mutation
// (constellation node "Mutation Meter"; the count is a Settings row). The
// fuller it is, the likelier the next fusion mutates; full, it is certain,
// and the glass breathes.
//
// It never moves under a fusion. The encounter tells it through
// [MutationMeterBus] when a fusion starts and where it landed: a notch then
// arrives as a thread of grains from the fusion, after the cinematic has
// gone. A mutation's moment (mutation_moment.dart) takes the meter's grains
// itself, from where they stood, so the glass is simply empty after.
//
// Tap the glass for the next fusion's chance, in one line.
//
// Cost: up to a few hundred points a frame through drawRawPoints, a handful
// of batches by colour and brightness; no blur, no per-grain paths.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

/// The meter's grains: mostly brass-gold, some pale, some starlight, and a
/// share that turn slowly through the spectrum. Every mutation is in there;
/// none of them is named.
const List<Color> kMutagenColors = [
  Color(0xFFE2C98F),
  Color(0xFFE2C98F),
  Color(0xFFEEEAF6),
  Color(0xFFA9C1FF),
];

/// How often a grain is one of the spectrum's, not one of [kMutagenColors].
const double kMutagenSpectrumShare = 0.28;

/// A spectrum grain's colour at [hue] (degrees).
Color mutagenSpectrum(double hue) =>
    HSLColor.fromAHSL(1, hue % 360, 0.7, 0.74).toColor();

/// What passes between the encounter, the meter and a mutation's moment.
class MutationMeterBus extends ChangeNotifier {
  MutationMeterBus._();
  static final MutationMeterBus instance = MutationMeterBus._();

  /// The glass, in global coordinates, while a meter is on screen.
  Rect? glass;

  /// How full the glass is drawn (0–1).
  double shownFill = 0;

  bool _fusing = false;
  bool get fusing => _fusing;
  Offset? _landedAt;
  bool _taken = false;

  /// A fusion has started: hold every change until it lands.
  void beginFusion() {
    _fusing = true;
    _landedAt = null;
    _taken = false;
  }

  /// The fusion is over (landed at [at] — null if it failed or went
  /// nowhere): a notch it earned arrives from there.
  void fusionEnded({Offset? at}) {
    _fusing = false;
    _landedAt = at;
    notifyListeners();
  }

  /// A mutation's moment has taken the meter's grains: it is empty now, with
  /// nothing to animate.
  void grainsTaken() {
    _taken = true;
    shownFill = 0;
    notifyListeners();
  }
}

/// The meter, as a full-screen layer over the wild scene. Draws nothing until
/// the node is unlocked. Only the glass takes a touch.
class MutationMeterHud extends StatefulWidget {
  const MutationMeterHud({super.key});

  @override
  State<MutationMeterHud> createState() => _MutationMeterHudState();
}

class _MutationMeterHudState extends State<MutationMeterHud>
    with SingleTickerProviderStateMixin {
  final _bus = MutationMeterBus.instance;
  late final Ticker _ticker;
  final _clock = Stopwatch()..start();
  final _layer = GlobalKey();

  int? _notches; // as drawn
  int? _stored; // as saved
  final List<_Grain> _grains = [];
  final List<_Flier> _fliers = [];
  double _bornAt = -1;
  double _hintUntil = 0;
  final _rng = math.Random();

  StreamSubscription<int>? _sub;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted) return;
      // Nothing to animate while the node is locked.
      if (!context.read<ConstellationEffectsService>().hasMutationMeter()) {
        return;
      }
      _publishGlass();
      setState(() {});
    })..start();
    _bus.addListener(_onBus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context
        .read<AlchemonsDatabase>()
        .settingsDao
        .watchMutationMeter()
        .listen(_onStored);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bus.removeListener(_onBus);
    _bus.glass = null;
    _ticker.dispose();
    super.dispose();
  }

  /// Where the glass is on screen, for a mutation's moment to pour from.
  void _publishGlass() {
    final box = _layer.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || _glass.isEmpty) return;
    _bus.glass = Rect.fromPoints(
      box.localToGlobal(_glass.topLeft),
      box.localToGlobal(_glass.bottomRight),
    );
  }

  double get _t => _clock.elapsedMicroseconds / 1e6;

  void _onStored(int v) {
    if (!mounted) return;
    _stored = v;
    if (_notches == null) {
      // First read: as it stands, no animation.
      _notches = v;
      _bornAt = _t;
      _grains.clear();
      return;
    }
    if (!_bus.fusing) _apply(from: null);
  }

  void _onBus() {
    if (_bus._taken) {
      _bus._taken = false;
      _grains.clear();
      _fliers.clear();
      _notches = _stored ?? 0;
      return;
    }
    if (!_bus.fusing) _apply(from: _bus._landedAt);
  }

  /// Brings the drawn meter to what is saved: new notches pour in (from
  /// [from], or straight down into the cap), lost ones lift out.
  void _apply({required Offset? from}) {
    final target = _stored;
    if (target == null || _notches == null || target == _notches) return;
    if (target > _notches!) {
      _pour(target, from);
    } else {
      _notches = target;
      final keep = _countFor(target);
      final now = _t;
      for (final g in _grains.skip(keep)) {
        _fliers.add(_Flier.lift(g, now, _rng));
      }
      if (_grains.length > keep) _grains.removeRange(keep, _grains.length);
    }
  }

  // ── layout ─────────────────────────────────────────────────────────────

  Rect _glassIn(Size size, EdgeInsets pad) {
    // Centred under Exit (66 wide, 54 tall, 8 in), clear of Items below it.
    const w = 14.0, gap = 12.0;
    final cx = pad.left + 8 + 33;
    final top = pad.top + 8 + 54 + gap;
    final bottom = size.height - pad.bottom - 8 - 54 - gap;
    return Rect.fromLTRB(cx - w / 2, top, cx + w / 2, math.max(top + 40, bottom));
  }

  static const _perRow = 3;
  Rect _glass = Rect.zero;
  int get _capacity => _perRow * math.max(8, ((_glass.height - 10) / 2.9).floor());
  int _countFor(int notches) =>
      (_capacity * (notches.clamp(0, kMutationMeterNotches) / kMutationMeterNotches))
          .round();

  Offset _slot(int i) {
    final row = i ~/ _perRow, c = i % _perRow;
    final iw = _glass.width - 5;
    final jx = math.sin(i * 12.9898) * 0.6, jy = math.cos(i * 78.233) * 0.5;
    final rows = _capacity / _perRow;
    return Offset(
      _glass.left + 2.5 + (c + 0.5) * (iw / _perRow) + jx + (row.isOdd ? 0.6 : -0.6),
      _glass.bottom - 5 - row * (_glass.height - 10) / rows + jy,
    );
  }

  Offset get _cap => Offset(_glass.center.dx, _glass.top - 7);

  _Grain _newGrain(int i) => _Grain(
    i: i,
    phase: _rng.nextDouble(),
    colour: _rng.nextDouble() < kMutagenSpectrumShare
        ? null
        : kMutagenColors[_rng.nextInt(kMutagenColors.length)],
  );

  void _fill() {
    // Grains for what is drawn, laid in place (first frame, or a resize).
    final want = _countFor(_notches ?? 0);
    while (_grains.length < want) {
      _grains.add(_newGrain(_grains.length));
    }
    if (_grains.length > want) _grains.removeRange(want, _grains.length);
  }

  void _pour(int target, Offset? fromGlobal) {
    final box = _layer.currentContext?.findRenderObject() as RenderBox?;
    final from = fromGlobal != null && box != null
        ? box.globalToLocal(fromGlobal)
        : _cap - const Offset(0, 40);
    _notches = target;
    final want = _countFor(target);
    final now = _t;
    final ctrl = Offset(
      (from.dx + _cap.dx) / 2 - 30,
      math.min(from.dy, _cap.dy) - 60,
    );
    for (var i = _grains.length; i < want; i++) {
      final g = _newGrain(i)
        ..arrive = now + _rng.nextDouble() * 0.45
        ..travel = 1.1 + _rng.nextDouble() * 0.3
        ..from = from + Offset(_rng.nextDouble() * 20 - 10, _rng.nextDouble() * 20 - 10)
        ..ctrl = ctrl + Offset(_rng.nextDouble() * 50 - 25, _rng.nextDouble() * 30 - 15);
      _grains.add(g);
    }
    // The thread you see: more than the notches, most dissolving at the cap.
    if (fromGlobal != null) {
      for (var k = 0; k < 22; k++) {
        _fliers.add(_Flier.spray(
          from: from + Offset(_rng.nextDouble() * 24 - 12, _rng.nextDouble() * 24 - 12),
          ctrl: ctrl + Offset(_rng.nextDouble() * 70 - 35, _rng.nextDouble() * 40 - 20),
          to: _cap + const Offset(0, 4),
          start: now + _rng.nextDouble() * 0.5,
          length: 0.95 + _rng.nextDouble() * 0.35,
          phase: _rng.nextDouble(),
          colour: kMutagenColors[k % kMutagenColors.length],
        ));
      }
    }
  }

  void _showHint() => setState(() => _hintUntil = _t + 2.6);

  @override
  Widget build(BuildContext context) {
    final unlocked = context.watch<ConstellationEffectsService>().hasMutationMeter();
    if (!unlocked) return const SizedBox.shrink();
    final pad = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final glass = _glassIn(size, pad);
        if (glass != _glass) {
          // Slots follow the glass; only the count changes with its height.
          _glass = glass;
          if (_notches != null) _fill();
        }
        if (_notches != null && _grains.isEmpty) _fill();
        final notches = _notches ?? 0;
        final chance = mutationChance(notches);
        final hint = (_hintUntil - _t).clamp(0.0, 1.0);
        return Stack(
          key: _layer,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MeterPainter(
                    glass: glass,
                    cap: _cap,
                    grains: _grains,
                    fliers: _fliers,
                    slot: _slot,
                    t: _t,
                    full: notches >= kMutationMeterNotches,
                    appear: _bornAt < 0 ? 0 : ((_t - _bornAt) / 0.7).clamp(0.0, 1.0),
                    onDrawn: (fill) => _bus.shownFill = fill,
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: glass.inflate(10),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showHint,
              ),
            ),
            if (hint > 0)
              Positioned(
                left: glass.right + 10,
                top: glass.top - 4,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: hint,
                    child: _Hint(
                      text: chance >= 1
                          ? 'Next fuse will mutate'
                          : 'Next fuse: ${_percent(chance)}',
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _percent(double p) {
  final v = p * 100;
  return v < 10 ? '${v.toStringAsFixed(1)}%' : '${v.round()}%';
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9131316),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: Color(0xFFE6E2DA),
          ),
        ),
      ),
    );
  }
}

class _Grain {
  _Grain({required this.i, required this.phase, required this.colour});
  final int i;
  final double phase;

  /// Null: one of the spectrum's.
  final Color? colour;

  // Pouring in: when it set off, how long it takes, and its path.
  double? arrive;
  double travel = 1;
  Offset? from, ctrl;
  final List<Offset> trail = [];
}

class _Flier {
  _Flier.spray({
    required this.from,
    required this.ctrl,
    required this.to,
    required this.start,
    required this.length,
    required this.phase,
    required this.colour,
  }) : lift = false;

  _Flier.lift(_Grain g, double now, math.Random rng)
    : from = Offset.zero,
      ctrl = Offset.zero,
      to = Offset.zero,
      start = now + rng.nextDouble() * 0.3,
      length = 0.9 + rng.nextDouble() * 0.4,
      phase = g.phase,
      colour = g.colour,
      lift = true,
      grain = g;

  final Offset from, ctrl, to;
  final double start, length, phase;
  final Color? colour;
  final bool lift;
  _Grain? grain;
  final List<Offset> trail = [];
}

Offset _bez(Offset a, Offset c, Offset b, double u) {
  final v = 1 - u;
  return a * (v * v) + c * (2 * v * u) + b * (u * u);
}

double _ease(double u) {
  final x = u.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

class _MeterPainter extends CustomPainter {
  _MeterPainter({
    required this.glass,
    required this.cap,
    required this.grains,
    required this.fliers,
    required this.slot,
    required this.t,
    required this.full,
    required this.appear,
    required this.onDrawn,
  });

  final Rect glass;
  final Offset cap;
  final List<_Grain> grains;
  final List<_Flier> fliers;
  final Offset Function(int) slot;
  final double t;
  final bool full;
  final double appear;
  final void Function(double fill) onDrawn;

  // Batches: colour key → points, by brightness band.
  final Map<int, List<double>> _bands = {};

  void _add(Color c, double alpha, Offset p) {
    final band = (alpha.clamp(0.0, 1.0) * 3).round().clamp(1, 3);
    final key = (c.toARGB32() & 0x00FFFFFF) | (band << 24);
    (_bands[key] ??= []).addAll([p.dx, p.dy]);
  }

  // Spectrum grains in twelve hues, so they batch.
  Color _colourOf(Color? c, double phase) =>
      c ?? mutagenSpectrum(((phase * 360 + t * 40) / 30).round() * 30.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (appear <= 0) return;
    _bands.clear();
    final r = glass.width / 2;
    final rrect = RRect.fromRectAndRadius(glass, Radius.circular(r));

    // The glass: a brass rim as a slightly larger fill under dark glass.
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, appear));
    canvas.drawRRect(
      rrect.inflate(1.4),
      Paint()
        ..shader = ui.Gradient.linear(
          glass.centerLeft,
          glass.centerRight,
          const [Color(0x1ACDB07A), Color(0x4DCDB07A), Color(0x24CDB07A)],
          const [0, 0.75, 1],
        ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(
          glass.centerLeft,
          glass.centerRight,
          const [Color(0xDB1A1A20), Color(0xE607070A), Color(0xDB16161C)],
          const [0, 0.45, 1],
        ),
    );

    // Grains at rest, and the ones still pouring in.
    var settled = 0;
    for (final g in grains) {
      final s = slot(g.i);
      final arrive = g.arrive;
      if (arrive != null) {
        final u = (t - arrive) / g.travel;
        if (u < 0) continue;
        if (u >= 1) {
          g.arrive = null;
          g.trail.clear();
        } else {
          final Offset p;
          if (u < 0.72) {
            p = _bez(g.from!, g.ctrl!, cap, _ease(u / 0.72));
          } else {
            final v = _ease((u - 0.72) / 0.28);
            p = Offset(cap.dx + (s.dx - cap.dx) * v, cap.dy + (s.dy - cap.dy) * v * v);
          }
          g.trail.add(p);
          if (g.trail.length > 4) g.trail.removeAt(0);
          final c = _colourOf(g.colour, g.phase);
          for (var k = 0; k < g.trail.length - 1; k++) {
            _add(c, 0.15 + k * 0.12, g.trail[k]);
          }
          _add(c, 1, p);
          continue;
        }
      }
      settled++;
    }
    final shownFill = grains.isEmpty
        ? 0.0
        : (settled / math.max(1, _capacityGuess())).clamp(0.0, 1.0);
    onDrawn(shownFill);

    final topRow = settled ~/ 3;
    final breath = full ? 0.5 + 0.5 * math.sin(t * 1.6) : 0.0;
    for (final g in grains) {
      if (g.arrive != null) continue;
      final s = slot(g.i);
      final row = g.i ~/ 3;
      final surface = math.max(0.0, 1 - (topRow - row) / 6);
      final amp = 0.25 + (0.35 + 1.1 * shownFill + (full ? 0.5 : 0)) * surface;
      final p = Offset(
        s.dx + math.sin(t * 1.3 + g.phase * 40) * amp,
        s.dy + math.cos(t * 1.1 + g.phase * 23) * amp * 0.8 -
            surface * (full ? (math.sin(t * 2 + g.phase * 9)).abs() * 1.2 : 0),
      );
      final tw = 0.55 + 0.45 * math.sin(t * 2.1 + g.phase * 31);
      _add(_colourOf(g.colour, g.phase), 0.45 + 0.5 * tw, p);
    }

    // Light held by the grains, rising with the fill.
    if (shownFill > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      final top = glass.bottom - shownFill * glass.height;
      canvas.drawRect(
        Rect.fromLTRB(glass.left, top - 24, glass.right, glass.bottom),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            Offset(0, glass.bottom),
            Offset(0, top - 24),
            [
              Color.fromRGBO(226, 201, 143, 0.10 + 0.14 * shownFill + 0.10 * breath),
              const Color(0x00E2C98F),
            ],
          ),
      );
      canvas.restore();
    }
    // Sheen down the left wall.
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      Rect.fromLTWH(glass.left, glass.top, 4, glass.height),
      Paint()
        ..shader = ui.Gradient.linear(
          glass.topLeft,
          glass.topLeft + const Offset(4, 0),
          const [Color(0x12FFFFFF), Color(0x00FFFFFF)],
        ),
    );
    canvas.restore();

    // Fliers: the thread from a fusion, and grains lifting out.
    for (var k = fliers.length - 1; k >= 0; k--) {
      final f = fliers[k];
      final u = (t - f.start) / f.length;
      if (u < 0) continue;
      if (u >= 1) {
        fliers.removeAt(k);
        continue;
      }
      final Offset p;
      final double a;
      if (f.lift) {
        final s = slot(f.grain!.i);
        p = Offset(
          s.dx + math.sin(f.phase * 20 + u * 3) * 4 * u,
          s.dy - (s.dy - glass.top + 30) * _ease(u),
        );
        a = 1 - u;
      } else {
        p = _bez(f.from, f.ctrl, f.to, _ease(u));
        a = math.sin(math.pi * u) * (u > 0.8 ? (1 - u) / 0.2 : 1);
      }
      f.trail.add(p);
      if (f.trail.length > 4) f.trail.removeAt(0);
      final c = _colourOf(f.colour, f.phase);
      for (var i = 0; i < f.trail.length - 1; i++) {
        _add(c, a * (0.12 + i * 0.1), f.trail[i]);
      }
      _add(c, a, p);
    }

    // Draw every batch: a soft halo pass, then the cores.
    for (final e in _bands.entries) {
      final band = e.key >> 24;
      final colour = Color(0xFF000000 | (e.key & 0x00FFFFFF));
      final pts = Float32List.fromList(e.value);
      canvas.drawRawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..color = colour.withValues(alpha: 0.10 * band / 3)
          ..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawRawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..color = colour.withValues(alpha: band / 3)
          ..strokeWidth = 1.7
          ..strokeCap = StrokeCap.round,
      );
    }

    // The bead at the top: brightens as it fills, breathes when full.
    final b = 0.35 + 0.65 * shownFill;
    if (shownFill > 0.05) {
      canvas.drawCircle(
        cap,
        10 + 10 * shownFill + 8 * breath,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(cap, 10 + 10 * shownFill + 8 * breath, [
            Color.fromRGBO(226, 201, 143, 0.12 + 0.25 * shownFill + 0.2 * breath),
            const Color(0x00E2C98F),
          ]),
      );
    }
    canvas.drawCircle(
      cap,
      4,
      Paint()
        ..shader = ui.Gradient.radial(
          cap - const Offset(1, 1.4),
          4.4,
          [
            Color.fromRGBO(255, 244, 214, 0.45 + 0.55 * b),
            Color.fromRGBO(205, 176, 122, 0.55 + 0.4 * b),
            const Color(0xE6463A22),
          ],
          const [0, 0.55, 1],
        ),
    );
    canvas.restore();
  }

  int _capacityGuess() => 3 * math.max(8, ((glass.height - 10) / 2.9).floor());

  @override
  bool shouldRepaint(_MeterPainter old) => true;
}
