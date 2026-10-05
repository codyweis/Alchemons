// lib/widgets/home_portal.dart
//
// THE WAY HOME FROM THE HOME SCREEN. Once the player has descended to their
// home planet from space, a circle drawn round the featured Alchemon opens a
// hole through the sand onto it: the Alchemon comes apart into its grains,
// they fall in turning, the sand round it is pulled into the turn, and the
// hole is a window onto the home biome, live (HomeBiomeWindow): dark grains
// turn in it while the field builds, then the field comes up through them. A
// tap on the window goes down. Another circle closes it, and the Alchemon
// gathers back out of its element.
//
// The window stays open for as long as the player leaves it. Its rim is a few
// hundred grains turning in the faction's colours; the field inside is only
// built once the hole has finished opening (its first frame bakes its art,
// which would stall the grains falling in) and is dropped when it shuts.
// Nothing here ticks while it is shut.
//
// A Listener, not a gesture: the hero's own tap (details) and long press
// (choose) stay as they were, and a stroke here also stirs the sand under it.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart'
    show GrainBatch, SpecimenGrains;
import 'package:alchemons/widgets/fx/rift_vortex.dart' show RiftPalette;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Counts how far a finger has gone round [center], and says when it has
/// gone round far enough to be a circle.
///
/// Forgiving on purpose: about five sixths of a turn, either way, anywhere
/// between [minRadius] and [maxRadius]. Samples outside that band (the
/// finger crossing the middle, or wandering off) are skipped rather than
/// ending the circle, and a jump of more than about 70° between two counted
/// samples is not counted, so cutting across does not pass for going round.
class PortalLoopTracker {
  PortalLoopTracker({
    required this.center,
    required this.minRadius,
    required this.maxRadius,
    this.needed = math.pi * 2 * 0.84,
  });

  Offset center;
  double minRadius, maxRadius;
  final double needed;

  double _swept = 0;
  double? _last;
  bool _closed = false;

  /// Radians gone round so far, signed: positive is clockwise on screen.
  double get swept => _swept;

  /// 0..1 of a circle.
  double get progress => (_swept.abs() / needed).clamp(0.0, 1.0);

  /// 1 clockwise on screen, -1 the other way.
  int get direction => _swept < 0 ? -1 : 1;

  void reset() {
    _swept = 0;
    _last = null;
    _closed = false;
  }

  /// Adds where the finger is now. True once, the moment it closes a circle.
  bool add(Offset p) {
    final d = p - center;
    final r = d.distance;
    if (r < minRadius || r > maxRadius) return false;
    final a = math.atan2(d.dy, d.dx);
    final last = _last;
    _last = a;
    if (last != null) {
      var da = a - last;
      if (da > math.pi) da -= math.pi * 2;
      if (da < -math.pi) da += math.pi * 2;
      if (da.abs() < 1.2) _swept += da;
    }
    if (_closed || _swept.abs() < needed) return false;
    _closed = true;
    return true;
  }
}

/// Wraps the home screen's featured Alchemon in the portal.
class HomePortalHero extends StatefulWidget {
  const HomePortalHero({
    super.key,
    required this.open,
    required this.child,
    required this.spriteKey,
    required this.tone,
    required this.onToggle,
    required this.onEnter,
    this.window,
    this.guide = false,
    this.onStir,
    this.onTapSand,
    this.onSwirl,
  });

  /// Whether it stands open (the saved state). Changing it from outside
  /// snaps to it; the player's circles animate.
  final bool open;

  /// The featured Alchemon. Not built while the window is open.
  final Widget child;

  /// The boundary round [child]'s sprite (see FeaturedCreaturePresentation),
  /// read into grains as it falls in.
  final GlobalKey spriteKey;

  /// The faction's colour: the rim's grains are shades of it.
  final Color tone;

  /// The player opened (true) or closed (false) it with a circle.
  final ValueChanged<bool> onToggle;

  /// A tap on the open window.
  final VoidCallback onEnter;

  /// What the hole looks onto, filling a square the window's size. It is
  /// handed a callback to say when it is ready to be seen; until then dark
  /// grains turn in the hole. Built only while the window is open.
  final Widget Function(BuildContext context, VoidCallback onReady)? window;

  /// Traces the circle round the Alchemon until the first one is drawn.
  final bool guide;

  /// A finger moving here, in global coordinates, to stir the sand.
  final void Function(Offset global, Offset delta, double dt)? onStir;

  /// A finger lifted here without moving, in global coordinates.
  final ValueChanged<Offset>? onTapSand;

  /// The sand round the hole pulled into its turn: centre (global), reach,
  /// rim speed (px/s, positive clockwise), and pull (negative lets go).
  final void Function(Offset global, double reach, double spin, double pull)?
  onSwirl;

  @override
  State<HomePortalHero> createState() => _HomePortalHeroState();
}

class _HomePortalHeroState extends State<HomePortalHero>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _Repaint _repaint = _Repaint();
  final _HomePortalArt _art = _HomePortalArt();

  /// Open as far as the player knows: the child is not built.
  late bool _open = widget.open;

  /// 0 shut … 1 open, eased by [_HomePortalArt].
  late double _openness = widget.open ? 1 : 0;

  /// Seconds into an opening (grains falling in) or a closing; null at rest.
  double? _openingAt, _closingAt;
  int _dir = 1;
  bool _reading = false;

  /// The window's content has said it is ready, and how far it has faded
  /// up over the dark grains (0..1).
  bool _windowReady = false;
  final ValueNotifier<double> _live = ValueNotifier(0);

  /// Bumped each time the window is dropped, so the next one is built fresh.
  int _windowTurn = 0;

  Duration _last = Duration.zero;

  PortalLoopTracker? _loop;
  int? _pointer;
  Offset _downAt = Offset.zero;
  Duration _downTime = Duration.zero;
  double _moved = 0;
  Duration _lastMove = Duration.zero;
  int _ticks = 0;

  static const double _openSecs = 1.7, _closeSecs = 1.1;

  @override
  void initState() {
    super.initState();
    _art.palette = RiftPalette(widget.tone);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant HomePortalHero old) {
    super.didUpdateWidget(old);
    if (old.tone != widget.tone) _art.palette = RiftPalette(widget.tone);
    if (old.window != null && widget.window == null) {
      // Taken away (the player went down into it): the next one starts in
      // the dark again.
      _windowReady = false;
      _live.value = 0;
      _windowTurn++;
    }
    if (old.open != widget.open && widget.open != _open) {
      // Loaded, or changed elsewhere: no show, just the state.
      _open = widget.open;
      _openness = _open ? 1 : 0;
      _openingAt = _closingAt = null;
      _art.falling = null;
      if (!_open) {
        _windowReady = false;
        _live.value = 0;
        _windowTurn++;
      }
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    _live.dispose();
    super.dispose();
  }

  bool get _wantsTicks =>
      _open ||
      _openingAt != null ||
      _closingAt != null ||
      (widget.guide && !_open);

  void _syncTicker() {
    if (_wantsTicks && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_wantsTicks && _ticker.isActive) {
      _ticker.stop();
      _repaint.ping();
    }
  }

  // ── Geometry ─────────────────────────────────────────────────────────────

  Size get _size =>
      (context.findRenderObject() as RenderBox?)?.size ?? Size.zero;

  Offset get _center => _size.center(Offset.zero);

  /// The window's radius: about the size the Alchemon is drawn.
  double get _radius => math.min(_size.height * 0.42, _size.width * 0.38);

  Offset _global(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? local : box.localToGlobal(local);
  }

  // ── The clock ────────────────────────────────────────────────────────────

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _art.time += dt;
    final r = _radius;

    final opening = _openingAt;
    if (opening != null) {
      final t = opening + dt;
      _openingAt = t;
      _openness = _HomePortalArt.ease(((t - 0.15) / 1.3).clamp(0.0, 1.0));
      // The sand pulled round with it, hard at first and easing off.
      final k = (1 - t / 1.1).clamp(0.0, 1.0);
      if (k > 0 && _ticks.isEven) {
        widget.onSwirl?.call(
          _global(_center),
          r * 1.9,
          560 * k * k * _dir,
          0.3,
        );
      }
      if (t >= _openSecs) {
        _openingAt = null;
        _openness = 1;
        _art.falling = null;
        // Now the field may be built behind the dark.
        setState(() {});
      }
    }
    final closing = _closingAt;
    if (closing != null) {
      final t = closing + dt;
      _closingAt = t;
      _openness = 1 - _HomePortalArt.ease((t / 0.95).clamp(0.0, 1.0));
      final k = (1 - t / 0.7).clamp(0.0, 1.0);
      if (k > 0 && _ticks.isEven) {
        // Let go: the sand turns the other way and spills out.
        widget.onSwirl?.call(_global(_center), r * 1.7, -300 * k * _dir, -0.4);
      }
      if (t >= _closeSecs) {
        _closingAt = null;
        _openness = 0;
        _dropWindow();
      }
    }
    if (_windowReady && _live.value < 1) {
      _live.value = math.min(1.0, _live.value + dt / 0.9);
    }
    _ticks++;
    _art.step(dt, _dir, _openness);
    if (_openness > 0 && _live.value < 1) _art.stepDark(dt, _dir);
    _repaint.ping();
    if (!_wantsTicks) _syncTicker();
  }

  // ── Opening and closing ──────────────────────────────────────────────────

  bool get _showWindow =>
      widget.window != null &&
      ((_open && _openingAt == null) || _closingAt != null);

  void _windowIsReady() {
    if (!mounted || _windowReady) return;
    _windowReady = true;
    _syncTicker();
  }

  void _dropWindow() {
    if (!mounted) return;
    setState(() {
      _windowReady = false;
      _live.value = 0;
      _windowTurn++;
    });
  }

  Future<void> _beginOpen(int dir) async {
    if (_reading || _openingAt != null || _closingAt != null) return;
    _reading = true;
    HapticFeedback.mediumImpact();
    final falling = await _readHero();
    _reading = false;
    if (!mounted || _open) return;
    setState(() {
      _dir = dir;
      _open = true;
      _openingAt = 0;
      _art.falling = falling;
    });
    widget.onToggle(true);
    _syncTicker();
  }

  void _beginClose(int dir) {
    if (_openingAt != null || _closingAt != null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _dir = dir;
      _open = false;
      _closingAt = 0;
    });
    widget.onToggle(false);
    _syncTicker();
  }

  /// The Alchemon as grains, where it stands now, in this box's coordinates.
  Future<_Falling?> _readHero() async {
    final boundary = widget.spriteKey.currentContext?.findRenderObject();
    final me = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary ||
        !boundary.attached ||
        me is! RenderBox) {
      return null;
    }
    try {
      final m = boundary.getTransformTo(me);
      final mid = MatrixUtils.transformPoint(
        m,
        boundary.size.center(Offset.zero),
      );
      final scale =
          (MatrixUtils.transformPoint(m, const Offset(1, 0)) -
                  MatrixUtils.transformPoint(m, Offset.zero))
              .distance;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final grains = await SpecimenGrains.capture(
        boundary,
        pixelRatio: math.min(scale * math.min(dpr, 2.0), 5.0),
      );
      if (grains == null) return null;
      return _Falling(grains, mid, scale, _center);
    } catch (_) {
      return null;
    }
  }

  // ── The finger ───────────────────────────────────────────────────────────

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _downAt = e.localPosition;
    _downTime = e.timeStamp;
    _lastMove = e.timeStamp;
    _moved = 0;
    final r = _radius;
    _loop = PortalLoopTracker(
      center: _center,
      minRadius: r * 0.45,
      maxRadius: math.max(r * 2.2, _size.width * 0.48),
    )..add(e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) {
      widget.onStir?.call(e.position, e.delta, 1 / 60);
      return;
    }
    final dt = ((e.timeStamp - _lastMove).inMicroseconds / 1e6).clamp(
      1 / 240,
      0.1,
    );
    _lastMove = e.timeStamp;
    _moved += e.delta.distance;
    widget.onStir?.call(e.position, e.delta, dt);
    final loop = _loop;
    if (loop == null || !loop.add(e.localPosition)) return;
    if (_open) {
      _beginClose(loop.direction);
    } else {
      _beginOpen(loop.direction);
    }
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _loop = null;
    final quick = e.timeStamp - _downTime < const Duration(milliseconds: 450);
    if (_moved >= 10 || !quick) return;
    final inWindow = (_downAt - _center).distance <= _radius * 1.08;
    if (_open && _openingAt == null && inWindow) {
      HapticFeedback.selectionClick();
      widget.onEnter();
    } else {
      widget.onTapSand?.call(e.position);
    }
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _loop = null;
  }

  @override
  Widget build(BuildContext context) {
    final showChild = !_open;
    final window = widget.window;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // The seat in the sand and the dark grains turning in the hole.
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _WindowPainter(this, repaint: _repaint),
              ),
            ),
          ),
          // What it looks onto, cut to the hole as it opens and shuts.
          if (_showWindow && window != null)
            LayoutBuilder(
              builder: (context, box) {
                final size = box.biggest;
                final r = math.min(size.height * 0.42, size.width * 0.38);
                return ClipPath(
                  clipper: _HoleClipper(this, repaint: _repaint),
                  child: Center(
                    child: SizedBox.square(
                      dimension: r * 2,
                      child: ValueListenableBuilder<double>(
                        valueListenable: _live,
                        builder: (context, live, child) => Opacity(
                          opacity: Curves.easeInOut.transform(live),
                          child: child,
                        ),
                        child: KeyedSubtree(
                          key: ValueKey(_windowTurn),
                          child: window(context, _windowIsReady),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Depth at the edge, and the lip of turning sand.
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _LipPainter(this, repaint: _repaint)),
            ),
          ),
          if (showChild) widget.child,
          IgnorePointer(
            child: CustomPaint(painter: _OverPainter(this, repaint: _repaint)),
          ),
        ],
      ),
    );
  }
}

/// The hole, as open as it is now.
class _HoleClipper extends CustomClipper<Path> {
  _HoleClipper(this.s, {required Listenable repaint}) : super(reclip: repaint);

  final _HomePortalHeroState s;

  @override
  Path getClip(Size size) {
    final r = math.min(size.height * 0.42, size.width * 0.38);
    return Path()..addOval(
      Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: math.max(0.01, r * s._openness),
      ),
    );
  }

  @override
  bool shouldReclip(covariant _HoleClipper old) => true;
}

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// The Alchemon's grains as they fall into the hole.
class _Falling {
  _Falling(this.grains, Offset mid, double scale, Offset c)
    : r0 = Float32List(grains.length),
      a0 = Float32List(grains.length),
      delay = Float32List(grains.length) {
    var far = 1.0;
    for (var i = 0; i < grains.length; i++) {
      final x = mid.dx + grains.hx[i] * scale - c.dx;
      final y = mid.dy + grains.hy[i] * scale - c.dy;
      r0[i] = math.sqrt(x * x + y * y);
      a0[i] = math.atan2(y, x);
      if (r0[i] > far) far = r0[i];
    }
    final rng = math.Random(11);
    for (var i = 0; i < grains.length; i++) {
      // Peeled from the outside in, each a little early or late.
      delay[i] = 0.32 * (1 - r0[i] / far) + 0.12 * rng.nextDouble();
    }
    size = math.max(1.6, grains.step * scale * 0.95);
  }

  final SpecimenGrains grains;
  final Float32List r0, a0, delay;
  late final double size;
}

/// What the portal draws: the window, its turning rim, the Alchemon's grains
/// falling in and the traced guide.
class _HomePortalArt {
  RiftPalette palette = RiftPalette(const Color(0xFFE0B068));
  _Falling? falling;
  double time = 0;

  static double ease(double x) =>
      x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

  // The rim: grains on a band from just inside the lip out to half again
  // its radius, turning faster near the lip and slowly drawn in.
  static const int _rimCount = 640;
  final Float32List _rho = Float32List(_rimCount);
  final Float32List _theta = Float32List(_rimCount);
  final Float32List _ph = Float32List(_rimCount);
  final math.Random _rng = math.Random(3);
  bool _seeded = false;

  void _respawn(int i, {bool initial = false}) {
    final u = _rng.nextDouble();
    _rho[i] = initial ? 0.98 + 0.4 * math.pow(u, 1.8) : 1.26 + 0.14 * u;
    _theta[i] = _rng.nextDouble() * math.pi * 2;
    _ph[i] = _rng.nextDouble();
  }

  void step(double dt, int dir, double openness) {
    if (!_seeded) {
      for (var i = 0; i < _rimCount; i++) {
        _respawn(i, initial: true);
      }
      _seeded = true;
    }
    if (openness <= 0) return;
    for (var i = 0; i < _rimCount; i++) {
      final r = _rho[i];
      _theta[i] += dt * dir * 0.42 / (r * r * r);
      _rho[i] = r - dt * (0.008 + 0.03 * (r - 0.9));
      if (_rho[i] < 0.97) _respawn(i);
    }
  }

  // While the field builds: dark grains turning slowly down into the hole,
  // silhouettes against a faint glow in its depth.
  static const int _darkCount = 460;
  final Float32List _dRho = Float32List(_darkCount);
  final Float32List _dTheta = Float32List(_darkCount);
  final Float32List _dPh = Float32List(_darkCount);
  bool _darkSeeded = false;

  void _respawnDark(int i, {bool initial = false}) {
    final u = _rng.nextDouble();
    _dRho[i] = initial ? 0.06 + 0.94 * math.sqrt(u) : 0.9 + 0.1 * u;
    _dTheta[i] = _rng.nextDouble() * math.pi * 2;
    _dPh[i] = _rng.nextDouble();
  }

  void stepDark(double dt, int dir) {
    if (!_darkSeeded) {
      for (var i = 0; i < _darkCount; i++) {
        _respawnDark(i, initial: true);
      }
      _darkSeeded = true;
    }
    for (var i = 0; i < _darkCount; i++) {
      final r = _dRho[i];
      _dTheta[i] += dt * dir * 0.3 / math.max(0.12, r);
      _dRho[i] = r - dt * (0.05 + 0.04 * (1 - r));
      if (_dRho[i] < 0.04) _respawnDark(i);
    }
  }

  final GrainBatch _batch = GrainBatch(34);

  // Cached per radius: the hole's shading only changes as it opens.
  double _shadeR = -1;
  Offset _shadeC = Offset.zero;
  final Paint _seat = Paint();
  final Paint _vignette = Paint();
  final Paint _void = Paint();

  void _shade(Offset c, double rw) {
    if (rw == _shadeR && c == _shadeC) return;
    _shadeR = rw;
    _shadeC = c;
    // A dark seat round the hole, so it sits down in the sand.
    _seat.shader = ui.Gradient.radial(
      c,
      rw * 1.45,
      [
        const Color(0xD0000000),
        const Color(0x66000000),
        const Color(0x00000000),
      ],
      const [0.6, 0.76, 1.0],
    );
    // Depth: whatever is down there falls away into dark at the edge.
    _vignette.shader = ui.Gradient.radial(
      c,
      rw,
      [
        const Color(0x00000000),
        const Color(0x33000000),
        const Color(0xCC000000),
        const Color(0xF2000000),
      ],
      const [0.0, 0.62, 0.9, 1.0],
    );
    // The hole's own depth: a faint glow far down, for the dark grains to
    // be seen against.
    _void.shader = ui.Gradient.radial(
      c,
      rw,
      [
        Color.lerp(palette.tint, palette.glow, 0.3)!,
        Color.lerp(palette.tint, palette.glow, 0.08)!,
        const Color(0xFF020203),
      ],
      const [0.0, 0.55, 1.0],
    );
  }

  /// Under the window's content: the seat in the sand, the hole's depth and,
  /// [dark] strong, the dark grains turning in it.
  void paintHole(
    Canvas canvas,
    Offset c,
    double radius,
    double openness,
    double dark,
  ) {
    if (openness <= 0.001) return;
    final rw = radius * openness;
    _shade(c, rw);
    canvas.drawCircle(c, rw * 1.45, _seat);
    if (dark <= 0.001) return;
    canvas.drawCircle(c, rw, _void);
    if (!_darkSeeded) return;
    final b = _batch..clear();
    for (var i = 0; i < _darkCount; i++) {
      final r = _dRho[i] * rw;
      final a = _dTheta[i];
      // Most are black; one in six carries a little of the faction's colour.
      b.add(
        _dPh[i] < 0.16 ? 1 : 0,
        c.dx + math.cos(a) * r,
        c.dy + math.sin(a) * r,
      );
    }
    b.draw(
      canvas,
      0,
      2.2,
      const Color(0xFF040405).withValues(alpha: 0.9 * dark),
    );
    b.draw(canvas, 1, 1.7, palette.tones[1].withValues(alpha: 0.7 * dark));
  }

  /// Over the window's content: the edge falling away into dark.
  void paintDepth(Canvas canvas, Offset c, double radius, double openness) {
    if (openness <= 0.001) return;
    final rw = radius * openness;
    _shade(c, rw);
    canvas.drawCircle(c, rw, _vignette);
  }

  void paintRim(Canvas canvas, Offset c, double radius, double openness) {
    if (openness <= 0.001) return;
    final b = _batch..clear();
    final o = openness;
    final rr = radius * o;
    for (var i = 0; i < _rimCount; i++) {
      final rho = _rho[i];
      final a = _theta[i];
      final x = c.dx + math.cos(a) * rr * rho;
      final y = c.dy + math.sin(a) * rr * rho;
      // Warm at the lip, the sand's own dark out in the sand; now and then
      // one catches the light.
      final heat = (1 - (rho - 0.97) / 0.43).clamp(0.0, 1.0);
      final tone = (heat * heat * 3.99).floor();
      final far = rho > 1.2 ? 1 : 0;
      final glint = ((_ph[i] + time * 0.3) % 1.0) < 0.012;
      b.add(glint ? 12 : tone + far * 6, x, y);
    }
    final tones = palette.tones;
    for (var t = 0; t < 4; t++) {
      b.draw(canvas, t, 1.7, tones[t + 1].withValues(alpha: 0.85 * o));
      b.draw(canvas, t + 6, 1.4, tones[t + 1].withValues(alpha: 0.4 * o));
    }
    b.draw(canvas, 12, 2.1, tones[5].withValues(alpha: 0.9 * o));
  }

  void paintFalling(Canvas canvas, Offset c, double t, int dir) {
    final f = falling;
    if (f == null) return;
    final b = _batch..clear();
    final g = f.grains;
    final tones = g.tones.length;
    for (var i = 0; i < g.length; i++) {
      final u = ((t - f.delay[i]) / 0.95).clamp(0.0, 1.0);
      // Falling: slow to let go, faster as it nears the middle.
      final e = u * u * u;
      final r = f.r0[i] * (1 - e);
      if (e > 0.985) continue;
      final a = f.a0[i] + dir * (u * 0.9 + e * 2.6);
      b.add(
        (g.tone[i] * 16 ~/ math.max(1, tones)) + (e > 0.6 ? 16 : 0),
        c.dx + math.cos(a) * r,
        c.dy + math.sin(a) * r,
      );
    }
    final step = math.max(1, tones ~/ 16);
    for (var k = 0; k < 16; k++) {
      final colour = g.tones[math.min(tones - 1, k * step)];
      b.draw(canvas, k, f.size, colour);
      b.draw(canvas, k + 16, f.size * 0.8, colour.withValues(alpha: 0.45));
    }
  }

  /// A comet of grains going round where the circle is to be drawn, fading
  /// in and out once a turn so it reads as a motion, not a ring.
  void paintGuide(Canvas canvas, Offset c, double radius) {
    final b = _batch..clear();
    const period = 2.6;
    final turn = (time % period) / period;
    final env = math.sin(turn * math.pi).clamp(0.0, 1.0);
    final head = -math.pi / 2 + turn * math.pi * 2 * 1.1;
    const n = 46;
    final rr = radius * 1.18;
    for (var j = 0; j < n; j++) {
      final lag = j / n;
      final a = head - lag * 1.6;
      final wob = 2.2 * math.sin(j * 1.7 + time * 3);
      b.add(
        (lag * 4).floor().clamp(0, 3),
        c.dx + math.cos(a) * (rr + wob),
        c.dy + math.sin(a) * (rr + wob),
      );
    }
    final tones = palette.tones;
    for (var k = 0; k < 4; k++) {
      final fade = (1 - k / 4) * env;
      b.draw(canvas, k, 2.6 - k * 0.3, tones[5 - k].withValues(alpha: fade));
    }
  }
}

class _WindowPainter extends CustomPainter {
  _WindowPainter(this.s, {required Listenable repaint})
    : super(repaint: repaint);

  final _HomePortalHeroState s;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.height * 0.42, size.width * 0.38);
    s._art.paintHole(canvas, c, r, s._openness, 1 - s._live.value);
  }

  @override
  bool shouldRepaint(covariant _WindowPainter old) => true;
}

class _LipPainter extends CustomPainter {
  _LipPainter(this.s, {required Listenable repaint}) : super(repaint: repaint);

  final _HomePortalHeroState s;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.height * 0.42, size.width * 0.38);
    s._art.paintDepth(canvas, c, r, s._openness);
    s._art.paintRim(canvas, c, r, s._openness);
  }

  @override
  bool shouldRepaint(covariant _LipPainter old) => true;
}

class _OverPainter extends CustomPainter {
  _OverPainter(this.s, {required Listenable repaint}) : super(repaint: repaint);

  final _HomePortalHeroState s;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.height * 0.42, size.width * 0.38);
    final opening = s._openingAt;
    if (opening != null) s._art.paintFalling(canvas, c, opening, s._dir);
    if (s.widget.guide && !s._open && s._closingAt == null) {
      s._art.paintGuide(canvas, c, r);
    }
  }

  @override
  bool shouldRepaint(covariant _OverPainter old) => true;
}
