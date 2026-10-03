// lib/widgets/fx/starter_vial_handoff.dart
//
// FROM THE FACTION'S REALM TO THE FIRST CHAMBER, IN ONE MOVE.
//
// Joining a division used to close the picker onto the startup splash, then
// home's loading card, then a "Vial secured" dialog, then a hard cut to the
// breed tab — and the player never saw the realm they had just chosen. Now
// the choice keeps the screen:
//
//   gather  the realm's grains stream up into the starter vial the picker
//           was holding, and it brightens (about a second);
//   hold    the vial waits over the realm, a few grains still finding it,
//           while the app finishes loading underneath — the splash and
//           loading card are never seen;
//   land    the vial drifts down into the first chamber of the breed tab as
//           the realm fades away round it.
//
// It lives in the root overlay, above the routes, so it outlasts the picker
// closing and the shell replacing the startup splash. The picker's realm
// field is handed over rather than rebuilt, so not a grain jumps.
//
// It cannot strand anyone: if the chamber never turns up it fades out on its
// own after [_giveUpAfter].
//
// Cheap: the pour is a few hundred points in two batches; the realm is the
// picker's own field, still drawing the way it was.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/faction_realm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const double _gatherSecs = 1.5;
const double _landSecs = 1.0;
const Duration _giveUpAfter = Duration(seconds: 14);

class StarterVialHandoff {
  StarterVialHandoff._();
  static final StarterVialHandoff instance = StarterVialHandoff._();

  OverlayEntry? _entry;
  _HandoffController? _controller;

  /// Set by the nursery to its first chamber's cell: where the vial lands.
  GlobalKey? chamberKey;

  bool _landRequested = false;
  bool _shellReady = false;

  /// Whether a handoff is on screen.
  bool get active => _entry != null;

  /// Takes over from the picker. [orbRect] is the chosen starter orb on
  /// screen; [field] the picker's realm, which this now owns (and disposes).
  void begin(
    BuildContext context, {
    required FactionId faction,
    required bool ink,
    required FactionRealmField field,
    required ExtractionVial vial,
    required Rect orbRect,
    required List<Color> grainColors,
  }) {
    if (_entry != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    _landRequested = false;
    final controller = _HandoffController(onDone: _finish);
    _controller = controller;
    _entry = OverlayEntry(
      builder: (_) => _HandoffView(
        controller: controller,
        faction: faction,
        ink: ink,
        field: field,
        vial: vial,
        orbRect: orbRect,
        grainColors: grainColors,
      ),
    );
    overlay.insert(_entry!);
  }

  /// The starter vial is in its chamber and the breed tab is showing it.
  void land() {
    _landRequested = true;
    _maybeLand();
  }

  /// A shell is mounting behind its own warm-up splash.
  void markShellWarming() => _shellReady = false;

  /// The shell's own warm-up splash has gone: what is under the realm is
  /// the real screen.
  void markShellReady() {
    _shellReady = true;
    _maybeLand();
  }

  /// No vial is coming (the starter was already granted): fade out where
  /// it is.
  void cancel() => _controller?.requestFade();

  void _maybeLand() {
    if (_landRequested && _shellReady) _controller?.requestLand();
  }

  /// Where the vial lands, if the chamber is laid out and on screen.
  Rect? _chamberRect() {
    final ctx = chamberKey?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  void _finish() {
    _entry?.remove();
    _entry = null;
    _controller = null;
    _landRequested = false;
  }
}

class _HandoffController extends ChangeNotifier {
  _HandoffController({required this.onDone});

  final VoidCallback onDone;
  bool landRequested = false;
  bool fadeRequested = false;

  void requestFade() => fadeRequested = true;

  void requestLand() {
    if (landRequested) return;
    landRequested = true;
    notifyListeners();
  }
}

class _HandoffView extends StatefulWidget {
  const _HandoffView({
    required this.controller,
    required this.faction,
    required this.ink,
    required this.field,
    required this.vial,
    required this.orbRect,
    required this.grainColors,
  });

  final _HandoffController controller;
  final FactionId faction;
  final bool ink;
  final FactionRealmField field;
  final ExtractionVial vial;
  final Rect orbRect;
  final List<Color> grainColors;

  @override
  State<_HandoffView> createState() => _HandoffViewState();
}

class _HandoffViewState extends State<_HandoffView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _Pour _pour = _Pour();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  double _t = 0;

  /// When landing began (seconds since start), or null while holding.
  double? _landAt;
  Rect? _landFrom;
  Rect? _landTo;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    widget.field.dispose();
    super.dispose();
  }

  Rect get _heldRect {
    // The orb comes down from the picker's row to hold the middle of the
    // screen, growing as it fills.
    final k = Curves.easeInOutCubic.transform((_t / _gatherSecs).clamp(0, 1));
    final size = MediaQuery.sizeOf(context);
    final from = widget.orbRect;
    final side = ui.lerpDouble(from.width, from.width * 1.7, k)!;
    final c = Offset.lerp(
      from.center,
      Offset(size.width / 2, size.height * 0.4),
      k,
    )!;
    return Rect.fromCenter(center: c, width: side, height: side);
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _t += dt;
    final size = MediaQuery.sizeOf(context);

    if (_landAt == null &&
        _t >= _gatherSecs &&
        widget.controller.landRequested) {
      final target = StarterVialHandoff.instance._chamberRect();
      if (target != null) {
        _landAt = _t;
        _landFrom = _heldRect;
        _landTo = target;
        HapticFeedback.lightImpact();
      }
    }
    if (_landAt == null &&
        (elapsed > _giveUpAfter ||
            (widget.controller.fadeRequested && _t >= _gatherSecs))) {
      // Nothing to land in: fade out where it is rather than strand anyone.
      _landAt = _t;
      _landFrom = _heldRect;
      _landTo = _heldRect;
    }

    final landing = _landAt != null;
    final landK = landing ? ((_t - _landAt!) / _landSecs).clamp(0.0, 1.0) : 0.0;
    _pour.step(
      dt,
      size: size,
      target: landing ? _orbRectAt(landK).center : _heldRect.center,
      gathering: _t < _gatherSecs,
      trickle: !landing,
      colors: widget.grainColors,
    );
    _frame.value++;
    setState(() {});

    if (landing && landK >= 1 && !_done) {
      _done = true;
      _ticker.stop();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.controller.onDone(),
      );
    }
  }

  /// The orb along its fall into the chamber: an easy arc, shrinking to the
  /// chamber's size.
  Rect _orbRectAt(double k) {
    final from = _landFrom!, to = _landTo!;
    final e = Curves.easeInOutCubic.transform(k);
    final mid = Offset(
      (from.center.dx + to.center.dx) / 2,
      math.min(from.center.dy, to.center.dy) - 40,
    );
    final a = Offset.lerp(from.center, mid, e)!;
    final b = Offset.lerp(mid, to.center, e)!;
    final c = Offset.lerp(a, b, e)!;
    final w = ui.lerpDouble(from.width, to.width, e)!;
    return Rect.fromCenter(center: c, width: w, height: w);
  }

  @override
  Widget build(BuildContext context) {
    final landing = _landAt != null;
    final landK = landing ? ((_t - _landAt!) / _landSecs).clamp(0.0, 1.0) : 0.0;
    final realmAlpha = 1 - Curves.easeIn.transform((landK / 0.75).clamp(0, 1));
    final orb = landing ? _orbRectAt(landK) : _heldRect;
    // The flying orb gives way to the chamber's own sphere as it arrives.
    final orbAlpha = landing
        ? 1 - Curves.easeIn.transform(((landK - 0.7) / 0.3).clamp(0, 1))
        : 1.0;
    final fill = Curves.easeOut.transform((_t / _gatherSecs).clamp(0, 1));

    return IgnorePointer(
      ignoring: landing,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Under the realm while it fades: block taps on the half-shown
          // screen until the vial has landed.
          if (!landing) const ModalBarrier(dismissible: false),
          Opacity(
            opacity: realmAlpha,
            child: FactionRealmStir(
              field: widget.field,
              child: FactionRealmView(
                faction: widget.faction,
                ink: widget.ink,
                field: widget.field,
                stirs: false,
              ),
            ),
          ),
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _PourPainter(_pour, repaint: _frame),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: orb.inflate(orb.width * 0.35),
            child: IgnorePointer(
              child: Opacity(
                opacity: orbAlpha,
                child: CustomPaint(
                  painter: _OrbLightPainter(
                    color: widget.vial.group.color,
                    strength: 0.35 + 0.65 * fill,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: orb,
            child: IgnorePointer(
              child: Opacity(
                opacity: orbAlpha,
                child: ExtractionVialCard(
                  vial: widget.vial,
                  showTags: false,
                  circular: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The light the vial throws as it fills: a radial pool, no blur.
class _OrbLightPainter extends CustomPainter {
  _OrbLightPainter({required this.color, required this.strength});

  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [
            color.withValues(alpha: 0.32 * strength),
            color.withValues(alpha: 0.10 * strength),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbLightPainter old) =>
      old.color != color || old.strength != strength;
}

/// Grains streaming from all over the realm into the vial: a burst while it
/// gathers, then a thin trickle while it holds. Each grain rides its own
/// curve from where it rose to the vial, quickening as it goes, with two
/// fading grains behind it so the streams read as streams.
class _Pour {
  static const int _cap = 1000;
  static const int _trail = 3;
  final Float32List _sx = Float32List(_cap);
  final Float32List _sy = Float32List(_cap);
  final Float32List _bend = Float32List(_cap);
  final Float32List _t = Float32List(_cap);
  final Float32List _speed = Float32List(_cap);
  final Float32List _delay = Float32List(_cap);
  final Uint8List _alive = Uint8List(_cap);
  final Uint8List _tone = Uint8List(_cap);
  final math.Random _rng = math.Random(31);

  bool _burstDone = false;
  double _trickleDebt = 0;
  Offset _target = Offset.zero;
  List<Color> _colors = const [Color(0xFFE8DCC8)];

  // One batch per trail step; refilled per tone.
  final List<Float32List> _pts = List.generate(
    _trail,
    (_) => Float32List(_cap * 2),
  );
  final List<int> _counts = List.filled(_trail, 0);

  /// A stream's source: mostly the ground along the foot, some from the
  /// sides and the air.
  (Offset, double) _source(Size size) {
    final r = _rng.nextDouble();
    final Offset at;
    if (r < 0.62) {
      at = Offset(
        _rng.nextDouble() * size.width,
        size.height * (0.68 + 0.3 * _rng.nextDouble()),
      );
    } else if (r < 0.86) {
      at = Offset(
        _rng.nextBool() ? -6 : size.width + 6,
        size.height * (0.3 + 0.6 * _rng.nextDouble()),
      );
    } else {
      at = Offset(
        _rng.nextDouble() * size.width,
        size.height * (0.08 + 0.3 * _rng.nextDouble()),
      );
    }
    return (at, (_rng.nextDouble() - 0.5) * 0.8);
  }

  /// One stream: [count] grains along the same curve, one after another.
  void _stream(Size size, int count, {required double delay}) {
    final (at, bend) = _source(size);
    final dur = 0.62 + _rng.nextDouble() * 0.3;
    final tone = _rng.nextInt(math.max(1, _colors.length));
    for (var j = 0; j < count; j++) {
      _spawn(
        Offset(
          at.dx + (_rng.nextDouble() - 0.5) * 18,
          at.dy + (_rng.nextDouble() - 0.5) * 18,
        ),
        bend + (_rng.nextDouble() - 0.5) * 0.06,
        delay: delay + j * 0.014 + _rng.nextDouble() * 0.01,
        dur: dur * (0.92 + _rng.nextDouble() * 0.16),
        tone: _rng.nextDouble() < 0.75 ? tone : null,
      );
    }
  }

  void _spawn(
    Offset at,
    double bend, {
    required double delay,
    required double dur,
    int? tone,
  }) {
    for (var i = 0; i < _cap; i++) {
      if (_alive[i] != 0) continue;
      _sx[i] = at.dx;
      _sy[i] = at.dy;
      _bend[i] = bend;
      _t[i] = 0;
      _speed[i] = 1 / dur;
      _delay[i] = delay;
      _tone[i] = tone ?? _rng.nextInt(math.max(1, _colors.length));
      _alive[i] = 1;
      return;
    }
  }

  void step(
    double dt, {
    required Size size,
    required Offset target,
    required bool gathering,
    required bool trickle,
    required List<Color> colors,
  }) {
    _target = target;
    if (colors.isNotEmpty) _colors = colors;
    if (!_burstDone && size.width > 0) {
      _burstDone = true;
      for (var i = 0; i < 16; i++) {
        _stream(size, 40, delay: _rng.nextDouble() * 0.4);
      }
    }
    if (trickle && !gathering) {
      // A thin stream now and then while it holds.
      _trickleDebt += dt * 1.4;
      while (_trickleDebt >= 1) {
        _trickleDebt -= 1;
        _stream(size, 18, delay: 0);
      }
    }
    for (var i = 0; i < _cap; i++) {
      if (_alive[i] == 0) continue;
      if (_delay[i] > 0) {
        _delay[i] -= dt;
        continue;
      }
      _t[i] += dt * _speed[i];
      if (_t[i] >= 1) _alive[i] = 0;
    }
  }

  /// Where grain [i] is at curve time [u] (0..1, already eased).
  void _at(int i, double u, Float32List out, int slot) {
    final sx = _sx[i], sy = _sy[i];
    final tx = _target.dx, ty = _target.dy;
    final mx = (sx + tx) / 2, my = (sy + ty) / 2;
    // Bow the path sideways, perpendicular to the straight line.
    final dx = tx - sx, dy = ty - sy;
    final cx = mx - dy * _bend[i], cy = my + dx * _bend[i];
    final a = 1 - u;
    out[slot * 2] = a * a * sx + 2 * a * u * cx + u * u * tx;
    out[slot * 2 + 1] = a * a * sy + 2 * a * u * cy + u * u * ty;
  }

  void paint(Canvas canvas) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var tone = 0; tone < _colors.length; tone++) {
      for (var k = 0; k < _trail; k++) {
        _counts[k] = 0;
      }
      for (var i = 0; i < _cap; i++) {
        if (_alive[i] == 0 || _delay[i] > 0 || _tone[i] != tone) continue;
        for (var k = 0; k < _trail; k++) {
          final u0 = _t[i] * _t[i]; // quickening into the vial
          final u = u0 - k * 0.025;
          if (u <= 0) break;
          _at(i, u, _pts[k], _counts[k]);
          _counts[k]++;
        }
      }
      for (var k = 0; k < _trail; k++) {
        final n = _counts[k];
        if (n == 0) continue;
        paint
          ..color = _colors[tone].withValues(alpha: 0.85 - k * 0.27)
          ..strokeWidth = 2.1 - k * 0.45;
        canvas.drawRawPoints(
          ui.PointMode.points,
          Float32List.sublistView(_pts[k], 0, n * 2),
          paint,
        );
      }
    }
  }
}

class _PourPainter extends CustomPainter {
  _PourPainter(this.pour, {required Listenable repaint})
    : super(repaint: repaint);

  final _Pour pour;

  @override
  void paint(Canvas canvas, Size size) => pour.paint(canvas);

  @override
  bool shouldRepaint(covariant _PourPainter old) => old.pour != pour;
}
