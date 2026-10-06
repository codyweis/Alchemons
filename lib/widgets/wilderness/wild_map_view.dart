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
    this.landing,
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

  /// Lets a wild field being left find its realm's circle here.
  final WildMapLanding? landing;

  @override
  State<WildMapView> createState() => _WildMapViewState();
}

class _WildMapViewState extends State<WildMapView>
    with SingleTickerProviderStateMixin {
  late final WildMapField _field = widget.field ?? WildMapField();
  late final Ticker _ticker = createTicker(_tick);
  final _frame = _Frame();

  /// The field's own layer, pictured when a realm's circle goes as sand.
  final GlobalKey _picture = GlobalKey();
  Duration _last = Duration.zero;
  Duration? _lastMove;

  @override
  void initState() {
    super.initState();
    _apply();
    widget.landing?._view = this;
    // Every realm opens as dust; those with something waiting gather.
    _field.settle(gather: true);
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant WildMapView old) {
    super.didUpdateWidget(old);
    _apply();
    if (old.landing != widget.landing) {
      if (old.landing?._view == this) old.landing!._view = null;
      widget.landing?._view = this;
    }
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
    if (widget.landing?._view == this) widget.landing!._view = null;
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

  /// Realm [sceneId]'s circle (or the rift's), on the map, or null.
  Rect? _circleIn(String sceneId) {
    if (sceneId == 'arcane') return widget.arcane ? _field.riftRect : null;
    for (final r in WildRealm.values) {
      if (r.sceneId == sceneId && _field.shows(r)) return _field.circleOf(r);
    }
    return null;
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
                  key: _picture,
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

/// Lets a wild field that is being left find its realm's circle on the map
/// and stir it as the sand comes home (VoidPortal.leaveThroughSand).
class WildMapLanding {
  _WildMapViewState? _view;

  /// Realm [sceneId]'s circle in global coordinates, or null when it is not
  /// on the map (or the map is not up).
  Rect? circleOf(String sceneId) {
    final view = _view;
    if (view == null || !view.mounted) return null;
    final circle = view._circleIn(sceneId);
    final box = view.context.findRenderObject();
    if (circle == null || box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(circle.topLeft) & circle.size;
  }

  /// The RepaintBoundary the map's grains are drawn in (null while the map
  /// is not up): what a realm's circle is pictured from as it goes as sand.
  GlobalKey? get picture {
    final view = _view;
    return view == null || !view.mounted ? null : view._picture;
  }

  /// The sand reaching [sceneId]'s circle: a soft swell through it.
  void settle(String sceneId) {
    final view = _view;
    if (view == null || !view.mounted) return;
    final circle = view._circleIn(sceneId);
    if (circle == null) return;
    view._field.ripple(
      circle.center,
      strength: 150,
      reach: circle.width * 0.55,
    );
  }
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
