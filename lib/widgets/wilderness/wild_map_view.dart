// lib/widgets/wilderness/wild_map_view.dart
//
// The wild map on screen: the field of grains, a finger stirring it, a tap
// on a realm going in (with a ripple), a long press peeking, and each
// realm's name and clock laid on it.

import 'package:alchemons/models/encounters/wild_weather.dart';
import 'package:alchemons/widgets/wilderness/wild_map.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class WildMapView extends StatefulWidget {
  const WildMapView({
    super.key,
    required this.onEnter,
    this.onPeek,
    this.weather = const {},
    this.ready = const {},
    this.arcane = false,
    this.volcano = WildVolcano.still,
    this.rainbow = false,
    this.slots = kWildCoreSlots,
    this.glass = false,
    this.rime = false,
    this.tide = 0.5,
    this.shells = false,
    this.ink = false,
    this.labelFor,
    this.field,
  });

  /// A realm (or 'arcane') was tapped: its scene id.
  final void Function(String sceneId) onEnter;
  final void Function(String sceneId)? onPeek;

  /// The weather over each realm, by scene id.
  final Map<String, WeatherKind> weather;

  /// The realms with something waiting in them.
  final Set<String> ready;
  final bool arcane;

  /// How the Volcano's next visit will find it.
  final WildVolcano volcano;

  /// Whether the Valley's next clear visit finds a rainbow.
  final bool rainbow;

  /// The realm in each of the four circles, by scene id: top left, top
  /// right, bottom left, bottom right (today's pick).
  final List<String> slots;

  /// Whether the Dunes' next clear visit finds the glass a sandstorm left.
  final bool glass;

  /// Whether Geode Hollow's next clear visit finds the rime a frostfall
  /// left.
  final bool rime;

  /// The tide on the Tidal Shelf (0 low water, 1 high).
  final double tide;

  /// Whether the Tidal Shelf's next clear visit finds the shells a swell
  /// left.
  final bool shells;

  /// Drawn in ink, for a light page.
  final bool ink;

  /// What to lay on each realm (and on the rift): its name and clock.
  final Widget Function(String sceneId)? labelFor;

  /// A field to draw instead of a new one (tests).
  final WildMapField? field;

  @override
  State<WildMapView> createState() => _WildMapViewState();
}

class _WildMapViewState extends State<WildMapView>
    with SingleTickerProviderStateMixin {
  late final WildMapField _field = widget.field ?? WildMapField();
  late final Ticker _ticker = createTicker(_tick);
  final _frame = _Frame();
  Duration _last = Duration.zero;
  Duration? _lastMove;

  @override
  void initState() {
    super.initState();
    _apply();
    // Every realm opens as dust; those with something waiting gather.
    _field.settle(gather: true);
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant WildMapView old) {
    super.didUpdateWidget(old);
    _apply();
  }

  void _apply() {
    _field
      ..weather = widget.weather
      ..ready = widget.ready
      ..arcane = widget.arcane
      ..volcano = widget.volcano
      ..rainbow = widget.rainbow
      ..slots = widget.slots
      ..glass = widget.glass
      ..rime = widget.rime
      ..tide = widget.tide
      ..shells = widget.shells
      ..ink = widget.ink;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _field.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _field.step(dt);
    _frame.tick();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final now = d.sourceTimeStamp;
    final last = _lastMove;
    final dt = now != null && last != null
        ? (now - last).inMicroseconds / 1e6
        : 1 / 60;
    _lastMove = now;
    _field.stir(d.localPosition, d.delta, dt);
  }

  void _onTapUp(TapUpDetails d) {
    final scene = _field.sceneAt(d.localPosition);
    _field.ripple(d.localPosition, strength: scene == null ? 220 : 340);
    if (scene == null) return;
    HapticFeedback.lightImpact();
    widget.onEnter(scene);
  }

  void _onLongPress(LongPressStartDetails d) {
    final scene = _field.sceneAt(d.localPosition);
    if (scene == null || widget.onPeek == null) return;
    HapticFeedback.selectionClick();
    widget.onPeek!(scene);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _field.layout(Size(box.maxWidth, box.maxHeight));
        final label = widget.labelFor;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _lastMove = null,
                onPanUpdate: _onPanUpdate,
                onTapUp: _onTapUp,
                onLongPressStart: _onLongPress,
                child: RepaintBoundary(
                  child: CustomPaint(
                    isComplex: true,
                    willChange: true,
                    painter: _MapPainter(_field, repaint: _frame),
                  ),
                ),
              ),
            ),
            if (label != null) ...[
              for (final r in WildRealm.values)
                if (_field.shows(r))
                  _place(_field.labelAnchor(r), label(r.sceneId)),
              if (widget.arcane)
                _place(
                  _field.riftRect.bottomCenter + const Offset(0, 4),
                  label('arcane'),
                ),
            ],
          ],
        );
      },
    );
  }

  /// [child] centred on [at], letting taps through to the field.
  Widget _place(Offset at, Widget child) => Positioned(
    left: at.dx - 80,
    top: at.dy,
    width: 160,
    child: IgnorePointer(child: Center(child: child)),
  );
}

class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.field, {required Listenable repaint})
    : super(repaint: repaint);

  final WildMapField field;

  @override
  void paint(Canvas canvas, Size size) => field.paint(canvas);

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.field != field;
}
