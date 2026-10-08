// lib/navigation/emblem_passage.dart
//
// The way in through one of home's living icons — the right-side emblems
// (widgets/home_emblems.dart) and the dock's (widgets/dock_passages.dart).
// The icon the player touched lifts off home
// and grows over the screen while home sinks into the scene's own ground;
// it holds there, alive, while the page is built behind it — the passage is
// the page's loading screen, as the glyph portal is — and then gives way to
// the page. Going back plays it the other way: the page sinks into the
// ground, the scene gathers, and settles into its place on home.
//
// The page is not built until the screen is covered, so whatever its first
// frame costs is paid under a scene at rest, not mid-flight.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/home_emblems.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class EmblemPassage {
  EmblemPassage._();

  /// Push [page] through the emblem of [kind] standing under [from]. The
  /// page is shown once [ready] turns true (or a safety timeout passes);
  /// pass no [ready] for a page that is instant. [lifted] is held true
  /// while the emblem is away, so the icon can leave its place empty.
  /// [revealed] turns true once the page is half shown, for a page that
  /// plays an entrance of its own after the passage.
  static Future<T?> push<T>(
    BuildContext context, {
    required HomeEmblemKind kind,
    required GlobalKey from,
    required Widget page,
    ValueListenable<bool>? ready,
    ValueNotifier<bool>? lifted,
    ValueNotifier<bool>? revealed,
  }) => pushScene<T>(
    context,
    scene: HomeEmblemScene(kind),
    from: from,
    page: page,
    ready: ready,
    lifted: lifted,
    revealed: revealed,
  );

  /// [push], for any [PassageScene] (the dock's, say).
  static Future<T?> pushScene<T>(
    BuildContext context, {
    required PassageScene scene,
    required GlobalKey from,
    required Widget page,
    ValueListenable<bool>? ready,
    ValueNotifier<bool>? lifted,
    ValueNotifier<bool>? revealed,
  }) {
    final navigator = Navigator.of(context);
    return pushSceneAt<T>(
      context,
      scene: scene,
      from: _rectOf(from, navigator),
      page: page,
      ready: ready,
      lifted: lifted,
      revealed: revealed,
    );
  }

  /// [pushScene] from a box on the screen ([from], global coordinates) —
  /// for a scene that is something drawn rather than a widget, a planet in
  /// space say. Null pushes plainly.
  static Future<T?> pushSceneAt<T>(
    BuildContext context, {
    required PassageScene scene,
    required Rect? from,
    required Widget page,
    ValueListenable<bool>? ready,
    ValueNotifier<bool>? lifted,
    ValueNotifier<bool>? revealed,
  }) {
    final navigator = Navigator.of(context);
    final rect = from;
    if (rect == null) {
      revealed?.value = true;
      return navigator.push<T>(MaterialPageRoute(builder: (_) => page));
    }
    lifted?.value = true;
    return navigator.push<T>(
      EmblemPassageRoute<T>(
        scene: scene,
        from: rect,
        page: page,
        ready: ready,
        lifted: lifted,
        revealed: revealed,
      ),
    );
  }

  /// [key]'s box in the navigator's overlay, where the route is drawn.
  static Rect? _rectOf(GlobalKey key, NavigatorState navigator) {
    final box = key.currentContext?.findRenderObject();
    final overlay = navigator.overlay?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || overlay is! RenderBox) {
      return null;
    }
    return MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
  }
}

/// What a passage draws: an icon's scene at any moment of its way in and
/// back ([EmblemStage]), in two layers the page is laid between.
abstract class PassageScene {
  const PassageScene();

  /// Growing over the screen.
  Duration get inward;

  /// Going back, the whole way home.
  Duration get outward;

  /// Giving way to the page once it is ready.
  Duration get landing;

  /// How far into growing the page starts to be built (it is unseen until it
  /// is given way to). 1 waits for the icon to be fully grown, which leaves
  /// it standing there while a heavy page reads what it needs; earlier gets
  /// it ready by the time the icon has grown. The landing still waits for
  /// the grow to finish.
  double get buildAt => 1;

  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  });

  /// Anything else the scene reads while it plays (a place the page reports
  /// once it is laid out, say), so it is repainted when that changes.
  Listenable? get listenable => null;

  /// Going back, the share of [outward] the scene has to gather home in,
  /// after the page has sunk away. Most of it: a gather crammed into the
  /// last moment reads as a spring.
  double get backSplit => 0.65;

  /// How much of the page shows at [land] (0..1 of giving way): a scene
  /// with something to settle into place first holds the page back until
  /// it has, so the page's own copy does not show beside it.
  double pageShown(double land) => land;

  /// The part of the screen the page shows through at [s], for a scene that
  /// opens onto the page rather than only fading it in; null for all of it.
  Rect? pageWindow(EmblemStage s) => null;
}

/// One of home's right-side emblems as a passage.
class HomeEmblemScene extends PassageScene {
  const HomeEmblemScene(this.kind);

  final HomeEmblemKind kind;

  /// The way in: the rite's drop has a fall and a pool to play.
  @override
  Duration get inward => switch (kind) {
    HomeEmblemKind.constellation => const Duration(milliseconds: 1050),
    HomeEmblemKind.altar => const Duration(milliseconds: 950),
    HomeEmblemKind.rite => const Duration(milliseconds: 1300),
  };

  @override
  Duration get outward => switch (kind) {
    HomeEmblemKind.rite => const Duration(milliseconds: 1250),
    _ => const Duration(milliseconds: 1000),
  };

  /// The rite's page clears quickly; the pool and the drop have the rest.
  @override
  double get backSplit => kind == HomeEmblemKind.rite ? 0.74 : 0.65;

  /// Giving way to the page. The sky disc hands over to a sky, so it can
  /// be quick: the chart's own entrance follows it.
  @override
  Duration get landing => switch (kind) {
    HomeEmblemKind.constellation => const Duration(milliseconds: 650),
    _ => const Duration(milliseconds: 900),
  };

  @override
  void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) => paintEmblem(
    canvas,
    kind,
    s,
    layer: back && front
        ? EmblemLayer.all
        : (back ? EmblemLayer.back : EmblemLayer.front),
  );
}

class EmblemPassageRoute<T> extends PageRoute<T> implements SelfLeavingRoute {
  EmblemPassageRoute({
    required this.scene,
    required this.from,
    required this.page,
    this.ready,
    this.lifted,
    this.revealed,
  });

  final PassageScene scene;

  /// The icon's box in the navigator's overlay.
  final Rect from;
  final Widget page;
  final ValueListenable<bool>? ready;
  final ValueNotifier<bool>? lifted;
  final ValueNotifier<bool>? revealed;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => scene.inward;

  @override
  Duration get reverseTransitionDuration => scene.outward;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => page;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => _PassageVeil(route: this, animation: animation, child: child);

  @override
  void dispose() {
    lifted?.value = false;
    super.dispose();
  }
}

/// A page that never says it is ready cannot keep the player waiting.
const Duration _kReadyTimeout = Duration(seconds: 6);

class _PassageVeil extends StatefulWidget {
  const _PassageVeil({
    required this.route,
    required this.animation,
    required this.child,
  });

  final EmblemPassageRoute route;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_PassageVeil> createState() => _PassageVeilState();
}

class _PassageVeilState extends State<_PassageVeil>
    with SingleTickerProviderStateMixin, GlyphClockLease {
  late final AnimationController _land = AnimationController(
    vsync: this,
    duration: widget.route.scene.landing,
  );

  /// The page is in the tree (only once the screen is covered).
  bool _built = false;
  bool _landing = false;
  bool _landPending = false;
  bool _closing = false;
  Timer? _timeout;

  late final Listenable _repaint = Listenable.merge([
    widget.animation,
    _land,
    GlyphClock.instance.seconds,
    ?widget.route.scene.listenable,
  ]);
  late final Listenable _fade = Listenable.merge([widget.animation, _land]);

  /// The passage has given way and nothing of it is left to draw.
  bool get _settled => !_closing && _land.isCompleted;

  @override
  bool get wantsClock => !_settled;

  @override
  void initState() {
    super.initState();
    widget.animation
      ..addStatusListener(_onRoute)
      ..addListener(_onTick);
    _land
      ..addStatusListener(_onLand)
      ..addListener(_onLanding);
    syncGlyphClock();
    _onRoute(widget.animation.status);
  }

  @override
  void dispose() {
    widget.animation
      ..removeStatusListener(_onRoute)
      ..removeListener(_onTick);
    widget.route.ready?.removeListener(_onReady);
    _timeout?.cancel();
    _land.dispose();
    releaseGlyphClock();
    super.dispose();
  }

  void _onRoute(AnimationStatus status) {
    if (!mounted) return;
    switch (status) {
      case AnimationStatus.completed:
        // Not the frame a hero push lays the route out offstage to measure
        // it: its animation reads complete there, and nothing is covered.
        if (widget.route.offstage) return;
        _beginBuild();
        // Ready before the icon had finished growing: it lands now.
        if (_landPending) {
          _landPending = false;
          _startLanding();
        }
      case AnimationStatus.reverse:
        if (_closing) return;
        _timeout?.cancel();
        widget.route.ready?.removeListener(_onReady);
        _land.stop();
        setState(() => _closing = true);
        syncGlyphClock();
      case AnimationStatus.forward || AnimationStatus.dismissed:
        break;
    }
  }

  /// Puts the page in the tree, and once it has laid out its first frame,
  /// waits on it.
  void _beginBuild() {
    if (_built || !mounted) return;
    setState(() => _built = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _awaitReady());
  }

  /// Home's icon comes back the moment the scene is back in its box.
  void _onTick() {
    if (!_built &&
        !_closing &&
        !widget.route.offstage &&
        widget.animation.status == AnimationStatus.forward &&
        widget.animation.value >= widget.route.scene.buildAt) {
      _beginBuild();
    }
    if (_closing && widget.animation.value <= 0) {
      widget.route.lifted?.value = false;
    }
  }

  /// Half shown: the page may start its own entrance.
  void _onLanding() {
    final revealed = widget.route.revealed;
    if (revealed != null && !revealed.value && _land.value >= 0.5) {
      revealed.value = true;
    }
  }

  void _onLand(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {});
      syncGlyphClock();
    }
  }

  void _awaitReady() {
    if (!mounted || _landing || _closing) return;
    final ready = widget.route.ready;
    if (ready == null || ready.value) {
      _startLanding();
      return;
    }
    ready.addListener(_onReady);
    _timeout = Timer(_kReadyTimeout, _startLanding);
  }

  void _onReady() {
    if (widget.route.ready?.value ?? true) _startLanding();
  }

  void _startLanding() {
    widget.route.ready?.removeListener(_onReady);
    _timeout?.cancel();
    if (!mounted || _landing || _closing) return;
    // Still growing: it lands when the icon has grown (see [buildAt]).
    if (widget.animation.status != AnimationStatus.completed) {
      _landPending = true;
      return;
    }
    _landing = true;
    _land.forward();
  }

  double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

  /// How far the scene has grown over the screen.
  double get _open {
    final v = widget.animation.value;
    final split = widget.route.scene.backSplit;
    return _closing ? _clamp01(v / split) : v;
  }

  /// How far it has given way to the page.
  double get _given {
    if (!_closing) return _land.value;
    final v = widget.animation.value;
    return math.min(
      _land.value,
      _clamp01(
        (v - widget.route.scene.backSplit) / (1 - widget.route.scene.backSplit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settled = _settled;
    final pad = MediaQuery.paddingOf(context);
    final scene = widget.route.scene;
    EmblemStage stage(Size size) => EmblemStage(
      box: widget.route.from,
      screen: size,
      pad: pad,
      time: GlyphClock.instance.seconds.value,
      open: _open,
      land: _given,
      closing: _closing,
    );
    _ScenePainter? painter(bool back) => settled
        ? null
        : _ScenePainter(scene, back: back, stage: stage, repaint: _repaint);
    return AbsorbPointer(
      // Nothing answers mid-passage: not the page, nor home under it.
      absorbing: !settled,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: CustomPaint(painter: painter(true))),
          ClipRect(
            // Always in the tree, so settling never rebuilds the page.
            clipper: _WindowClipper(scene, stage, reclip: _fade),
            clipBehavior: settled ? Clip.none : Clip.hardEdge,
            child: AnimatedBuilder(
              animation: _fade,
              builder: (_, child) =>
                  Opacity(opacity: scene.pageShown(_given), child: child),
              child: _built ? widget.child : const SizedBox.expand(),
            ),
          ),
          IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: painter(false))),
          ),
        ],
      ),
    );
  }
}

/// The page's share of the screen, at the passage's moment.
class _WindowClipper extends CustomClipper<Rect> {
  _WindowClipper(this.scene, this.stage, {required Listenable reclip})
    : super(reclip: reclip);

  final PassageScene scene;
  final EmblemStage Function(Size size) stage;

  @override
  Rect getClip(Size size) =>
      scene.pageWindow(stage(size)) ?? Offset.zero & size;

  @override
  bool shouldReclip(covariant _WindowClipper old) =>
      old.scene != scene || old.stage != stage;
}

/// One of a scene's two layers, at the passage's moment.
class _ScenePainter extends CustomPainter {
  _ScenePainter(
    this.scene, {
    required this.back,
    required this.stage,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final PassageScene scene;
  final bool back;
  final EmblemStage Function(Size size) stage;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    scene.paint(canvas, stage(size), back: back, front: !back);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.scene != scene || old.back != back || old.stage != stage;
}
