import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/planet_dungeon/planet_dungeon_portal.dart';
import 'package:alchemons/widgets/fx/sand_passage.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding, Ticker;
import 'package:flutter/services.dart';

/// Configuration for the Warp Portal effect
class VoidPortalConfig {
  const VoidPortalConfig({
    this.duration = const Duration(milliseconds: 700),
    this.starCount = 80,
    this.color = const Color(0xFF000000),
    this.starColor = const Color(0xFFFFFFFF),
    this.dimStarColor = const Color(0xFF888888),
    this.showGlow = true,
    this.enableBlur = true,
  });

  final Duration duration;
  final int starCount;
  final Color color;
  final Color starColor;
  final Color dimStarColor;
  final bool showGlow;
  final bool enableBlur;

  /// Get effective star count (reduced on Android)
  int get effectiveStarCount {
    if (_isAndroid) {
      return (starCount * 0.6).round().clamp(30, 50);
    }
    return starCount;
  }

  /// Check if blur should be enabled (disabled on Android by default)
  bool get effectiveBlur => enableBlur && !_isAndroid;

  static bool get _isAndroid {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false; // Web or other platform
    }
  }

  /// Standard black hole with stars
  static const standard = VoidPortalConfig();

  /// More stars, slower
  static const cinematic = VoidPortalConfig(
    duration: Duration(milliseconds: 1000),
    starCount: 120,
  );

  /// Fast and snappy
  static const quick = VoidPortalConfig(
    duration: Duration(milliseconds: 400),
    starCount: 60,
  );

  /// Optimized for low-end devices
  static const performance = VoidPortalConfig(
    duration: Duration(milliseconds: 500),
    starCount: 40,
    showGlow: false,
    enableBlur: false,
  );
}

/// For a page entered through [VoidPortal.pushThroughGlyphs]: flips its
/// `revealReady` notifier the first time [isReady] returns true, so the
/// portal reveals a built page rather than a spinner. Polls every 50ms.
///
/// Create it in `initState`, dispose it in `dispose` — disposing also
/// reports ready, so a page that goes away never leaves a portal waiting.
class RevealWhenReady {
  RevealWhenReady(this.notifier, this.isReady) {
    final notifier = this.notifier;
    if (notifier == null || notifier.value) return;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!isReady()) return;
      timer.cancel();
      notifier.value = true;
    });
  }

  final ValueNotifier<bool>? notifier;
  final bool Function() isReady;
  Timer? _timer;

  void dispose() {
    _timer?.cancel();
    notifier?.value = true;
  }
}

/// Where a field's sand goes when it is left through
/// [VoidPortal.leaveThroughSand]: the element its light takes, and the
/// circle on the screen behind that takes the sand back.
class SandLanding {
  const SandLanding({this.element = '', this.circle, this.onLanded});

  /// The element whose light rides in the sand ('' for spirit's).
  final String element;

  /// The circle the sand pours into, in global coordinates, asked once the
  /// screen behind has been laid out again. Null, or returning null: the
  /// sand thins out where it is.
  final Rect? Function()? circle;

  /// The first of the sand has reached [circle].
  final VoidCallback? onLanded;
}

/// Where a passage's sand rises from ([VoidPortal.pushThroughSand]): a
/// circle on the screen, and the RepaintBoundary that shows it.
class SandSource {
  const SandSource({required this.picture, required this.circle});

  /// A RepaintBoundary whose picture holds [circle].
  final GlobalKey picture;

  /// The circle, in global coordinates.
  final Rect circle;
}

/// A route that plays its own way out when popped (as an emblem's passage
/// does): [VoidPortal.pop] just pops it rather than warping on top.
abstract interface class SelfLeavingRoute {}

/// Main portal utility class
class VoidPortal {
  VoidPortal._();

  /// Push a page with portal animation (no orientation change)
  static Future<T?> push<T>(
    BuildContext context, {
    required Widget page,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final navigator = Navigator.of(context);
    T? result;

    final handle = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () async {
        result = await navigator.push<T>(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => page,
          ),
        );
      },
    );

    await handle.future;
    return result;
  }

  /// Push [page] through the glyph portal — the same tunnel of alchemical
  /// script the planet descents use, spelling [title] around its rings.
  ///
  /// The portal fades up over the current screen and pushes [page] once it
  /// fully covers it. With an [orientation] change it goes through black
  /// instead: the screen dips to black, the rotation, the push and the
  /// re-layout they force all happen while nothing on screen is moving, and
  /// only once that has settled does the portal start — a rotation hitches
  /// badly enough that it must never land mid-animation. Either way it then
  /// STAYS until [ready] turns true (or a safety timeout passes), so a
  /// page that needs a moment to load is revealed already built — the portal
  /// is its loading screen. Pass no [ready] for a page that is instant.
  ///
  /// [element] picks one of the 17 elemental twists and palettes ('' for
  /// the plain portal).
  ///
  /// Pass [orientation] to switch orientation while the portal covers the
  /// screen; [returnOrientation] is restored when the page is popped. The
  /// switch is hidden: the window is locked to `orientation.first` (so the
  /// rotation is known), the system's rotation animation is turned off, and
  /// the portal counter-rotates itself so it stays upright in the player's
  /// hand. The full [orientation] list is allowed again once revealed.
  ///
  /// Turning to landscape, [page] is pushed the moment the turn is asked for
  /// and laid out at its landscape size straight away (see [_PreTurned]), so
  /// whatever it does on its first frame happens once, at its real size,
  /// while the system is still turning.
  ///
  /// [back] is where the page's sand pours if it is left through
  /// [leaveThroughSand].
  ///
  /// Unlike [push], the returned future completes with the route's result
  /// when the page is popped.
  static Future<T?> pushThroughGlyphs<T>(
    BuildContext context, {
    required Widget page,
    required String title,
    String label = 'ENTERING',
    String element = '',
    ValueListenable<bool>? ready,
    List<Color>? palette,
    Color? tint,
    List<DeviceOrientation>? orientation,
    List<DeviceOrientation>? returnOrientation,
    SandLanding? back,
  }) {
    final navigator = Navigator.of(context);
    final routeResult = Completer<T?>();
    final picture = GlobalKey();
    final counterTurns = switch (orientation?.first) {
      DeviceOrientation.landscapeLeft => 3,
      DeviceOrientation.landscapeRight => 1,
      _ => 0,
    };
    // True once the window has turned, or plainly will not.
    final turned = ValueNotifier<bool>(counterTurns == 0);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GlyphPortalOverlay(
        title: title,
        label: label,
        element: element,
        throughBlack: orientation != null,
        ready: ready,
        palette: palette,
        tint: tint,
        counterTurns: counterTurns,
        onTurned: () => turned.value = true,
        onCovered: () async {
          try {
            if (orientation != null && orientation.isNotEmpty) {
              await _setSeamlessRotation(true);
              await SystemChrome.setPreferredOrientations([orientation.first]);
            }
            navigator
                .push<T>(
                  PageRouteBuilder(
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (_, __, ___) => _passagePage(
                      page: page,
                      picture: picture,
                      turned: counterTurns == 0 ? null : turned,
                      returnOrientation: returnOrientation,
                      back: back,
                    ),
                  ),
                )
                .then((result) async {
                  if (returnOrientation != null) {
                    await SystemChrome.setPreferredOrientations(
                      returnOrientation,
                    );
                  }
                  routeResult.complete(result);
                }, onError: routeResult.completeError);
          } catch (e, st) {
            routeResult.completeError(e, st);
          }
        },
        onComplete: () {
          entry.remove();
          if (orientation != null && orientation.length > 1) {
            unawaited(SystemChrome.setPreferredOrientations(orientation));
          }
          if (orientation != null) unawaited(_setSeamlessRotation(false));
        },
      ),
    );
    navigator.overlay!.insert(entry);
    return routeResult.future;
  }

  /// Replaces the current route with [page] while the screen is already
  /// black — the last frame of a transition the current screen drew itself
  /// (a rift's threshold falling into its core) — so nothing else plays.
  ///
  /// With [orientation], the phone is turned first, on that black frame,
  /// with the system's rotation animation off: a rotation hitches, and must
  /// never land on anything moving. [returnOrientation] is restored when
  /// [page] is popped. Completes with [page]'s result.
  static Future<T?> replaceInBlack<T>(
    BuildContext context, {
    required Widget page,
    List<DeviceOrientation>? orientation,
    List<DeviceOrientation>? returnOrientation,
  }) async {
    final navigator = Navigator.of(context);
    final turn = orientation != null && orientation.isNotEmpty;
    if (turn) {
      await _setSeamlessRotation(true);
      await SystemChrome.setPreferredOrientations([orientation.first]);
      final wide =
          orientation.first == DeviceOrientation.landscapeLeft ||
          orientation.first == DeviceOrientation.landscapeRight;
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final began = DateTime.now();
      while ((view.physicalSize.width > view.physicalSize.height) != wide &&
          DateTime.now().difference(began) < const Duration(seconds: 1)) {
        await SchedulerBinding.instance.endOfFrame;
      }
    }
    final result = navigator.pushReplacement<T, Object?>(
      PageRouteBuilder<T>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => page,
      ),
    );
    if (turn) {
      // A few frames for the re-layout before the rotation animation and
      // the other orientations come back.
      for (var i = 0; i < 3; i++) {
        await SchedulerBinding.instance.endOfFrame;
      }
      if (orientation.length > 1) {
        unawaited(SystemChrome.setPreferredOrientations(orientation));
      }
      unawaited(_setSeamlessRotation(false));
    }
    final value = await result;
    if (returnOrientation != null) {
      await SystemChrome.setPreferredOrientations(returnOrientation);
    }
    return value;
  }

  /// Play the glyph portal over the current screen without navigating — for
  /// a change that happens IN a screen (starting a survival run).
  ///
  /// [onCovered] runs once the portal fully covers the screen; build the new
  /// state there. The portal then holds until [ready] turns true (or a
  /// safety timeout), and [onReveal] runs the moment it starts to fade — the
  /// first instant the player can see, so start anything time-sensitive
  /// there. The returned future completes when the portal has gone.
  static Future<void> coverWithGlyphs(
    BuildContext context, {
    required String title,
    required Future<void> Function() onCovered,
    VoidCallback? onReveal,
    String label = 'ENTERING',
    String element = '',
    ValueListenable<bool>? ready,
    List<Color>? palette,
    Color? tint,
  }) {
    final overlay = Navigator.of(context).overlay!;
    final done = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GlyphPortalOverlay(
        title: title,
        label: label,
        element: element,
        throughBlack: false,
        counterTurns: 0,
        ready: ready,
        palette: palette,
        tint: tint,
        onCovered: onCovered,
        onReveal: onReveal,
        onComplete: () {
          entry.remove();
          done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }

  static const MethodChannel _rotationChannel = MethodChannel(
    'alchemons/rotation',
  );

  /// Android only (MainActivity): suppress the system rotation animation
  /// while a transition hides the orientation change itself.
  static Future<void> _setSeamlessRotation(bool on) async {
    try {
      await _rotationChannel.invokeMethod<void>('setSeamless', on);
    } on MissingPluginException {
      // iOS / tests: the platform rotates the way it always has.
    } on PlatformException {
      // Same — never let a cosmetic hook break navigation.
    }
  }

  /// Pop the current page behind a portal
  static Future<void> pop<T>(
    BuildContext context, {
    T? result,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final navigator = Navigator.of(context);
    // A route with a way out of its own leaves by it alone: the warp on top
    // played two exits, one after the other.
    if (ModalRoute.of(context) is SelfLeavingRoute) {
      navigator.pop(result);
      return;
    }

    final handle = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () {
        navigator.pop(result);
      },
    );

    await handle.future;
  }

  /// The density screens are pictured at: the screen's own, so the first
  /// frame of a picture IS the screen and nothing shows as it swaps in.
  static double _pictureRatio(BuildContext context) =>
      math.min(MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0, 3.0);

  /// Pictures what [key]'s RepaintBoundary shows, straight after a frame
  /// has painted -- a live field marks itself dirty every frame, and a
  /// layer waiting to paint cannot be pictured. Null when it cannot be.
  static Future<(ui.Image, RenderRepaintBoundary)?> _picture(
    GlobalKey key,
    double ratio,
  ) async {
    await SchedulerBinding.instance.endOfFrame;
    final boundary = key.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.attached) return null;
    final Future<ui.Image> pending;
    try {
      pending = boundary.toImage(pixelRatio: ratio);
    } catch (_) {
      return null;
    }
    final ui.Image image;
    try {
      image = await pending.timeout(const Duration(milliseconds: 400));
    } on TimeoutException {
      unawaited(pending.then<void>((i) => i.dispose(), onError: (_) {}));
      return null;
    } catch (_) {
      return null;
    }
    if (!boundary.attached) {
      image.dispose();
      return null;
    }
    return (image, boundary);
  }

  /// The middle of the window, in global coordinates, as it is now.
  static Offset _screenCentre() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return (view.physicalSize / view.devicePixelRatio).center(Offset.zero);
  }

  /// Whether the window is wider than it is tall right now.
  static bool _windowWide() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize.width > view.physicalSize.height;
  }

  /// Until the window is [wide] (or not), or plainly will not be.
  static Future<void> _awaitWindow({required bool wide}) async {
    final began = DateTime.now();
    while (_windowWide() != wide &&
        DateTime.now().difference(began) < const Duration(seconds: 1)) {
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  /// Leave the current page as sand: it comes apart into grains of its own
  /// colour that gather into a turning ball, the page is popped (with
  /// [result]) behind it, and the ball pours into [landing]'s circle on the
  /// screen behind.
  ///
  /// A page entered through [pushThroughSand] or [pushThroughGlyphs] needs
  /// neither [boundaryKey] (what is pictured) nor [landing]: it pours back
  /// into the `back` it was pushed with. One entered turned to landscape is
  /// turned back while only the ball shows -- it is round, so the turn
  /// hides in it -- and is held at its wide size meanwhile, so the turn
  /// costs it no re-layout; the screen behind is laid out once, at its own
  /// orientation, before the sand pours. Falls back to [pop] when the page
  /// cannot be pictured. Completes once the last grain has gone.
  static Future<void> leaveThroughSand<T>(
    BuildContext context, {
    GlobalKey? boundaryKey,
    SandLanding? landing,
    T? result,
  }) async {
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay;
    final scope = _PassageScope.maybeOf(context);
    final key = boundaryKey ?? scope?.picture;
    final to = landing ?? scope?.back ?? const SandLanding();
    final wide = MediaQuery.sizeOf(context).aspectRatio > 1;
    final ratio = _pictureRatio(context);
    final shot = key == null || overlay == null
        ? null
        : await _picture(key, ratio);
    if (shot == null || !overlay!.mounted || !context.mounted) {
      shot?.$1.dispose();
      if (context.mounted) await pop<T>(context, result: result);
      return;
    }
    final (image, boundary) = shot;
    final sand = SandPicture(
      image: image,
      pixelRatio: ratio,
      size: boundary.size,
      way: SandWay.gather,
      origin: boundary.localToGlobal(Offset.zero),
      screenCentre: _screenCentre(),
      element: to.element,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    final turned = scope?.turned;
    final returnTo = scope?.returnOrientation;
    final turnBack =
        wide && turned != null && returnTo != null && returnTo.isNotEmpty;

    // Everything that costs a hitch happens here, behind the ball.
    Future<void> swap() async {
      if (turnBack) {
        // Keep the page laid out wide while the window turns under it: it
        // is about to go, and re-laying it out tall would only hitch.
        turned.value = false;
        await _setSeamlessRotation(true);
        await SystemChrome.setPreferredOrientations([returnTo.first]);
        await _awaitWindow(wide: false);
      }
      if (navigator.mounted) navigator.pop<T>(result);
      // A few frames for the screen behind to lay itself out.
      for (var i = 0; i < 3; i++) {
        await SchedulerBinding.instance.endOfFrame;
      }
      if (turnBack) {
        if (returnTo.length > 1) {
          unawaited(SystemChrome.setPreferredOrientations(returnTo));
        }
        unawaited(_setSeamlessRotation(false));
      }
    }

    final done = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SandExitOverlay(
        sand: sand,
        landing: to,
        turns: turnBack,
        swap: swap,
        onComplete: () {
          entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }

  /// Push [page] through sand: [from]'s circle comes apart into a turning
  /// ball in the middle of the screen as the screen goes dark, the phone is
  /// turned to [orientation] and [page] pushed behind the ball, and once
  /// [ready] (or a safety timeout) the ball comes undone into [page], its
  /// pieces flying out from the middle and growing back into the picture.
  ///
  /// [element] colours the light in the sand; [back] is where the page's
  /// sand pours when it is left through [leaveThroughSand]. Falls back to
  /// [pushThroughGlyphs] (spelling [title]) when [from] cannot be pictured.
  /// Completes with the route's result when the page is popped.
  static Future<T?> pushThroughSand<T>(
    BuildContext context, {
    required Widget page,
    required SandSource from,
    required String title,
    String element = '',
    ValueListenable<bool>? ready,
    List<DeviceOrientation>? orientation,
    List<DeviceOrientation>? returnOrientation,
    SandLanding? back,
  }) async {
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay;
    final ratio = _pictureRatio(context);
    final shot = overlay == null ? null : await _picture(from.picture, ratio);
    if (shot == null || !overlay!.mounted || !context.mounted) {
      shot?.$1.dispose();
      if (!context.mounted) return null;
      return pushThroughGlyphs<T>(
        context,
        page: page,
        title: title,
        element: element,
        ready: ready,
        orientation: orientation,
        returnOrientation: returnOrientation,
        back: back,
      );
    }
    final (image, boundary) = shot;
    final seed = DateTime.now().millisecondsSinceEpoch;
    final source = SandPicture(
      image: image,
      pixelRatio: ratio,
      size: boundary.size,
      way: SandWay.gather,
      origin: boundary.localToGlobal(Offset.zero),
      screenCentre: _screenCentre(),
      circle: from.circle,
      element: element,
      seed: seed,
    );
    final turnTo = orientation == null || orientation.isEmpty
        ? null
        : orientation.first;
    final wideTo =
        turnTo == DeviceOrientation.landscapeLeft ||
        turnTo == DeviceOrientation.landscapeRight;
    final needsTurn = turnTo != null && wideTo != _windowWide();
    final turned = ValueNotifier<bool>(!needsTurn);
    final picture = GlobalKey();
    final routeResult = Completer<T?>();

    // Everything that costs a hitch happens here, behind the ball.
    Future<void> swap() async {
      if (turnTo != null) {
        await _setSeamlessRotation(true);
        await SystemChrome.setPreferredOrientations([turnTo]);
      }
      navigator
          .push<T>(
            PageRouteBuilder(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => _passagePage(
                page: page,
                picture: picture,
                turned: needsTurn ? turned : null,
                returnOrientation: returnOrientation,
                back: back,
              ),
            ),
          )
          .then((result) async {
            if (returnOrientation != null) {
              await SystemChrome.setPreferredOrientations(returnOrientation);
            }
            routeResult.complete(result);
          }, onError: routeResult.completeError);
      if (needsTurn) await _awaitWindow(wide: wideTo);
      turned.value = true;
      for (var i = 0; i < 3; i++) {
        await SchedulerBinding.instance.endOfFrame;
      }
    }

    // The page as built, to come out of the ball.
    Future<SandPicture?> capture() async {
      final shot = await _picture(picture, ratio);
      if (shot == null) return null;
      final (image, boundary) = shot;
      return SandPicture(
        image: image,
        pixelRatio: ratio,
        size: boundary.size,
        way: SandWay.assemble,
        origin: boundary.localToGlobal(Offset.zero),
        screenCentre: _screenCentre(),
        element: element,
        seed: seed + 1,
      );
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SandEnterOverlay(
        from: source,
        turns: needsTurn,
        swap: swap,
        capture: capture,
        ready: ready,
        onComplete: () {
          entry.remove();
          if (orientation != null && orientation.length > 1) {
            unawaited(SystemChrome.setPreferredOrientations(orientation));
          }
          if (turnTo != null) unawaited(_setSeamlessRotation(false));
        },
      ),
    );
    overlay.insert(entry);
    return routeResult.future;
  }

  /// Push a page and force Landscape orientation seamlessly
  static Future<T?> pushLandscape<T>(
    BuildContext context, {
    required Widget page,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    return pushWithOrientation(
      context,
      page: page,
      targetOrientation: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      returnOrientation: [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
      config: config,
    );
  }

  /// Push a page with specific orientation changes
  static Future<T?> pushWithOrientation<T>(
    BuildContext context, {
    required Widget page,
    required List<DeviceOrientation> targetOrientation,
    required List<DeviceOrientation> returnOrientation,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final navigator = Navigator.of(context);
    T? result;

    final handleIn = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () async {
        await SystemChrome.setPreferredOrientations(targetOrientation);

        result = await navigator.push<T>(
          PageRouteBuilder(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => page,
          ),
        );

        await SystemChrome.setPreferredOrientations(returnOrientation);
      },
    );
    await handleIn.future;

    return result;
  }

  /// Just play the animation (useful for dramatic reveals, etc.)
  static Future<void> playEffect(
    BuildContext context, {
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    final handle = _showPortalWarp(context, config: config, onMidpoint: () {});
    await handle.future;
  }

  /// Show portal in, execute async work, then portal out
  static Future<T> wrapAsync<T>(
    BuildContext context, {
    required Future<T> Function() work,
    VoidPortalConfig config = const VoidPortalConfig(),
  }) async {
    late T result;

    final handle = _showPortalWarp(
      context,
      config: config,
      onMidpoint: () async {
        result = await work();
      },
    );

    await handle.future;
    return result;
  }
}

// ============================================================================
// Glyph portal overlay
// ============================================================================

/// Lays a page pushed under the black out at the size the window will have
/// once it has turned to landscape, until [turned] says it has (or plainly
/// will not).
///
/// The turn takes the system a few hundred milliseconds, and a page built
/// before it lands would be built tall and then again wide — a wild field's
/// first frame bakes all its art (70–290 ms each on a desktop test run), so
/// that is two bakes, one thrown away, on black. Built at the wide size from
/// the start, the field bakes once, while the system turns, and the turn
/// landing changes nothing it measured.
class _PreTurned extends StatelessWidget {
  const _PreTurned({required this.turned, required this.child});

  /// Also flipped back to false by [VoidPortal.leaveThroughSand], so the
  /// page stays wide while the phone turns back under the sand.
  final ValueListenable<bool> turned;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: turned,
      builder: (context, settled, _) {
        final size = media.size;
        final turning = !settled && size.height > size.width;
        final laid = turning ? size.flipped : size;
        // The same widgets either way, so the page keeps its state (and its
        // bake) when the turn lands. Nothing of it shows meanwhile: the
        // portal's black covers it.
        return MediaQuery(
          data: turning ? media.copyWith(size: laid) : media,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: laid.width,
            maxWidth: laid.width,
            minHeight: laid.height,
            maxHeight: laid.height,
            child: child,
          ),
        );
      },
    );
  }
}

/// A page pushed through a portal or sand: pictured by [picture], laid out
/// wide while the phone turns ([turned], null for no turn), and told its
/// way back.
Widget _passagePage({
  required Widget page,
  required GlobalKey picture,
  required ValueNotifier<bool>? turned,
  required List<DeviceOrientation>? returnOrientation,
  required SandLanding? back,
}) {
  final body = RepaintBoundary(key: picture, child: page);
  return _PassageScope(
    picture: picture,
    turned: turned,
    returnOrientation: returnOrientation,
    back: back,
    child: turned == null ? body : _PreTurned(turned: turned, child: body),
  );
}

/// What a page entered through a passage knows about its way back: what
/// pictures it, the switch that holds it wide (if it was turned), the
/// orientation the screen behind wants, and where its sand pours.
class _PassageScope extends InheritedWidget {
  const _PassageScope({
    required this.picture,
    required this.turned,
    required this.returnOrientation,
    required this.back,
    required super.child,
  });

  final GlobalKey picture;
  final ValueNotifier<bool>? turned;
  final List<DeviceOrientation>? returnOrientation;
  final SandLanding? back;

  static _PassageScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PassageScope>();

  @override
  bool updateShouldNotify(_PassageScope old) => false;
}

class _GlyphPortalOverlay extends StatefulWidget {
  const _GlyphPortalOverlay({
    required this.title,
    required this.label,
    required this.element,
    required this.throughBlack,
    required this.counterTurns,
    required this.ready,
    required this.palette,
    required this.tint,
    required this.onCovered,
    required this.onComplete,
    this.onTurned,
    this.onReveal,
  });

  final String title;
  final String label;
  final String element;

  /// Dip to black and do the push (and orientation switch) there before the
  /// portal starts. Off: the portal fades straight in over the old screen.
  final bool throughBlack;

  /// Quarter turns (clockwise) that keep the portal upright in the player's
  /// hand once the window has switched to the target landscape. 0 = none.
  final int counterTurns;
  final ValueListenable<bool>? ready;
  final List<Color>? palette;
  final Color? tint;

  /// Starts the orientation switch and the push; completes once both have
  /// been started (not when the page is popped).
  final Future<void> Function() onCovered;

  /// Runs once the window has turned after [onCovered], or the wait for it
  /// has given up (through-black only).
  final VoidCallback? onTurned;

  /// Runs once, the moment the portal starts to fade out.
  final VoidCallback? onReveal;
  final VoidCallback onComplete;

  @override
  State<_GlyphPortalOverlay> createState() => _GlyphPortalOverlayState();
}

class _GlyphPortalOverlayState extends State<_GlyphPortalOverlay>
    with SingleTickerProviderStateMixin {
  static const Color _void = Color(0xFF050507);

  /// The old screen dips to black in this long (through-black only).
  static const double _blackoutSeconds = 0.25;

  /// The portal fades straight in over the old screen in this long, and the
  /// page is pushed once it is opaque (direct only).
  static const double _coverSeconds = 0.4;

  /// How long to wait for the window to report its new orientation before
  /// starting the portal anyway.
  static const double _settleTimeoutSeconds = 1.0;

  /// Frames left to absorb the push and re-layout while still black.
  static const int _settleFrames = 3;

  /// Through-black: the portal fades up out of the black over this long.
  static const double _portalInSeconds = 0.25;

  /// The shortest the portal plays before revealing, even for a page that is
  /// ready instantly — long enough for the rings to gather and start rushing.
  static const double _minPortalSeconds = 1.1;

  /// Reveal regardless after this (wall time), so a page that never reports
  /// ready cannot trap the player behind the portal.
  static const double _timeoutSeconds = 8.0;

  static const double _fadeSeconds = 0.5;

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  double _now = 0;
  bool _switchStarted = false;

  /// Wall time the portal animation began; null while still black.
  double? _portalStart;
  double? _fadeStart;
  bool _done = false;

  /// Whether the screen was portrait when the transition began, and whether
  /// it is now. Counter-rotation only applies once the window has flipped.
  bool? _startedPortrait;
  bool _portraitNow = true;

  @override
  void initState() {
    super.initState();
    if (!widget.throughBlack) _portalStart = 0;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_done) return;
    final t = _now = elapsed.inMicroseconds / 1e6;
    if (!_switchStarted) {
      if (widget.throughBlack && t >= _blackoutSeconds) {
        _switchStarted = true;
        unawaited(_switchWhileBlack());
      } else if (!widget.throughBlack && t >= _coverSeconds) {
        _switchStarted = true;
        unawaited(widget.onCovered());
      }
    }
    if (_portalStart == null && t >= _timeoutSeconds) {
      _portalStart = t - _minPortalSeconds;
    }
    final start = _portalStart;
    if (start != null &&
        _fadeStart == null &&
        t - start >= _minPortalSeconds &&
        ((widget.ready?.value ?? true) || t >= _timeoutSeconds)) {
      _fadeStart = t;
      widget.onReveal?.call();
    }
    if (_fadeStart != null && t >= _fadeStart! + _fadeSeconds) {
      _done = true;
      _ticker.stop();
      widget.onComplete();
      return;
    }
    _time.value = t;
  }

  /// Everything that costs a hitch happens here, on black frames.
  Future<void> _switchWhileBlack() async {
    final began = _now;
    try {
      await widget.onCovered();
    } catch (_) {
      // The push reports its own failure through the route future.
    }
    if (widget.counterTurns != 0) {
      // Until the window is wide — which it may already have been, so wait
      // for wide rather than for a change — or the system has plainly
      // ignored the request.
      while (mounted && _portraitNow && _now - began < _settleTimeoutSeconds) {
        await SchedulerBinding.instance.endOfFrame;
      }
    }
    widget.onTurned?.call();
    for (var i = 0; i < _settleFrames && mounted; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (mounted && _portalStart == null) _portalStart = _now;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height >= size.width;
    _startedPortrait ??= portrait;
    _portraitNow = portrait;
    final turns = widget.counterTurns != 0 && _startedPortrait! && !portrait
        ? widget.counterTurns
        : 0;
    return IgnorePointer(
      child: RotatedBox(
        quarterTurns: turns,
        child: RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: _time,
            builder: (context, t, _) => _frame(t),
          ),
        ),
      ),
    );
  }

  Widget _frame(double t) {
    final start = _portalStart;
    if (start == null) {
      return Opacity(
        opacity: (t / _blackoutSeconds).clamp(0.0, 1.0),
        child: const ColoredBox(color: _void),
      );
    }
    final pt = t - start;
    final portalIn = widget.throughBlack
        ? (pt / _portalInSeconds).clamp(0.0, 1.0)
        : (pt / _coverSeconds).clamp(0.0, 1.0);
    final titleIn = ((pt - 0.35) / 0.4).clamp(0.0, 1.0);
    final Widget portal = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: PortalPainter(
            elapsed: pt,
            element: widget.element,
            title: widget.title,
            accent: const Color(0xFFE4C16A),
            palette: widget.palette,
            tint: widget.tint,
          ),
        ),
        Center(
          child: Opacity(
            opacity: titleIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Color(0xD9E8DFC8),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE4C16A),
                    fontFamily: 'monospace',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.6,
                    decoration: TextDecoration.none,
                    shadows: [Shadow(color: Color(0xFFE4C16A), blurRadius: 14)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    final fade = _fadeStart == null
        ? 1.0
        : (1 - (t - _fadeStart!) / _fadeSeconds).clamp(0.0, 1.0);
    return Opacity(
      opacity: fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Black under the portal while it fades up, so the switch never
          // shows through.
          if (portalIn < 1 && widget.throughBlack)
            const ColoredBox(color: _void),
          if (portalIn < 1)
            Opacity(opacity: portalIn, child: portal)
          else
            portal,
        ],
      ),
    );
  }
}

// ============================================================================
// Sand exit overlay
// ============================================================================

class _SandExitOverlay extends StatefulWidget {
  const _SandExitOverlay({
    required this.sand,
    required this.landing,
    required this.turns,
    required this.swap,
    required this.onComplete,
  });

  final SandPicture sand;
  final SandLanding landing;

  /// The phone turns in the swap: the sand goes out for it.
  final bool turns;

  /// Turns the phone back and pops the page, behind the ball.
  final Future<void> Function() swap;
  final VoidCallback onComplete;

  @override
  State<_SandExitOverlay> createState() => _SandExitOverlayState();
}

class _SandExitOverlayState extends State<_SandExitOverlay>
    with SingleTickerProviderStateMixin {
  /// After the last piece lets go, this long before the swap (or, with a
  /// turn, before the sand starts to go out for it): it is most of the way
  /// into the ball.
  static const double _swapAfterRelease = 0.45;
  static const double _dimAfterRelease = 0.3;

  /// The ball turns a moment on its own before it pours.
  static const double _hold = 0.15;

  /// The sand meets the circle about this long after it sets off.
  static const double _meet = 0.45;

  late final Ticker _ticker;
  final _clock = _SandClock();
  bool _swapStarted = false, _swapped = false, _landed = false, _done = false;
  double? _pourAt;
  Rect? _home;
  final _veil = _SandVeil();

  @override
  void initState() {
    super.initState();
    if (widget.turns) {
      _veil.dimAt = widget.sand.goneBy + _dimAfterRelease;
    }
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_done) return;
    final t = _clock.advance(elapsed);
    final sand = widget.sand;
    final swapAt = widget.turns ? _veil.outBy : sand.goneBy + _swapAfterRelease;
    if (!_swapStarted && t >= swapAt) {
      _swapStarted = true;
      unawaited(
        widget.swap().catchError((Object _) {}).whenComplete(() {
          _swapped = true;
          // A couple of frames more on the dark for the stretched ones.
          if (widget.turns) _veil.lightAt = _clock.t + 0.06;
        }),
      );
    }
    final pourAt = _pourAt;
    if (pourAt == null) {
      if (_swapped &&
          t >= sand.doneBy + _hold &&
          (!widget.turns || t >= _veil.litBy)) {
        _pourAt = t;
        _home = _homeHere();
        // The screen behind is live again under the sand.
        if (mounted) setState(() {});
      }
    } else {
      if (!_landed && t >= pourAt + _meet) {
        _landed = true;
        if (_home != null) widget.landing.onLanded?.call();
      }
      if (t >= pourAt + SandPicture.pourTime) {
        _done = true;
        _ticker.stop();
        widget.onComplete();
        return;
      }
    }
    _clock.tick(t);
  }

  /// The landing circle in this overlay's own coordinates.
  Rect? _homeHere() {
    final Rect? global;
    try {
      global = widget.landing.circle?.call();
    } catch (_) {
      return null;
    }
    if (global == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return global;
    return box.globalToLocal(global.topLeft) & global.size;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    widget.sand.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(size: Size.infinite, painter: _SandExitPainter(this)),
    );
    // The page under the sand is still live: nothing reaches it. The screen
    // behind is free to touch once the sand pours.
    return _pourAt == null
        ? AbsorbPointer(child: paint)
        : IgnorePointer(child: paint);
  }
}

/// The ball going out like an ember while the phone turns, and lighting
/// again after.
///
/// For a few frames after the window turns, Android shows the app's last
/// frame stretched to the new shape -- the round ball squashed into an oval
/// and shoved aside -- until the app has drawn at the new size. Black
/// stretched is still black, so the turn happens with the sand out: it
/// draws in on itself and dims to nothing, the window turns, and it swells
/// and brightens back the new way up. The push or pop behind it (a whole
/// screen's first frame) lands on the dark too.
class _SandVeil {
  static const double dimTime = 0.3, lightTime = 0.35;

  /// When the sand starts to go out, and to light again (null: not yet).
  double? dimAt, lightAt;

  /// From then on the sand is fully out: the turn may begin.
  double get outBy => (dimAt ?? double.infinity) + dimTime;

  /// From then on the sand is fully lit again.
  double get litBy => (lightAt ?? double.infinity) + lightTime;

  /// How lit the sand is [t] seconds in: 1 lit, 0 out.
  double lit(double t) {
    final dim = dimAt;
    if (dim == null) return 1;
    final light = lightAt;
    if (light == null || t < light) return 1 - _sandSmooth(dim, outBy, t);
    return _sandSmooth(light, litBy, t);
  }

  /// Draws [canvas] drawn in toward the middle of [size] as the sand goes
  /// out. Restore it after.
  static void drawIn(Canvas canvas, Size size, double lit) {
    final c = size.center(Offset.zero);
    final k = 0.55 + 0.45 * lit;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(k, k)
      ..translate(-c.dx, -c.dy);
  }
}

class _SandClock extends ChangeNotifier {
  double t = 0;
  Duration _last = Duration.zero;

  /// The passage's own time at [elapsed]: a long frame (the push or pop
  /// behind the ball laying out a whole screen) counts as one short step,
  /// so the sand pauses for it instead of jumping.
  double advance(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    return t + dt.clamp(0.0, 1 / 30);
  }

  void tick(double now) {
    t = now;
    notifyListeners();
  }
}

/// The black every sand passage happens on.
const Color _sandGround = Color(0xFF050507);
final Paint _sandGroundPaint = Paint();

void _paintSandGround(Canvas canvas, Size size, double alpha) {
  if (alpha <= 0.002) return;
  _sandGroundPaint.color = _sandGround.withValues(alpha: alpha);
  canvas.drawRect(Offset.zero & size, _sandGroundPaint);
}

double _sandSmooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class _SandExitPainter extends CustomPainter {
  _SandExitPainter(this.state) : super(repaint: state._clock);

  final _SandExitOverlayState state;

  @override
  void paint(Canvas canvas, Size size) {
    final t = state._clock.t;
    final pourAt = state._pourAt;
    // The black the page leaves behind, lifting off the screen behind as
    // the sand pours.
    _paintSandGround(
      canvas,
      size,
      pourAt == null ? 1 : 1 - _sandSmooth(0, 0.55, t - pourAt),
    );
    final lit = state._veil.lit(t);
    if (lit <= 0.002) return;
    if (lit < 1) _SandVeil.drawIn(canvas, size, lit);
    state.widget.sand.paintGather(
      canvas,
      size,
      t,
      pourAt: pourAt,
      home: state._home,
      fade: lit,
    );
    if (lit < 1) canvas.restore();
  }

  @override
  bool shouldRepaint(_SandExitPainter old) => old.state != state;
}

class _SandEnterOverlay extends StatefulWidget {
  const _SandEnterOverlay({
    required this.from,
    required this.turns,
    required this.swap,
    required this.capture,
    required this.ready,
    required this.onComplete,
  });

  /// The circle coming apart into the ball.
  final SandPicture from;

  /// The phone turns in the swap: the sand goes out for it.
  final bool turns;

  /// Turns the phone and pushes the page, behind the ball.
  final Future<void> Function() swap;

  /// The page as built, once it is ready.
  final Future<SandPicture?> Function() capture;
  final ValueListenable<bool>? ready;
  final VoidCallback onComplete;

  @override
  State<_SandEnterOverlay> createState() => _SandEnterOverlayState();
}

class _SandEnterOverlayState extends State<_SandEnterOverlay>
    with SingleTickerProviderStateMixin {
  /// The screen behind darkens over this long as its circle comes apart.
  static const double _darken = 0.6;

  /// Once the ball is whole, this long before the push: anything still
  /// flying would stall in the push's first frame, the slow turn barely.
  static const double _swapAfterGather = 0.1;

  /// Show the page regardless after this long behind the ball (wall time),
  /// so one that never says it is ready cannot trap the player.
  static const double _timeout = 8.0;

  /// The finished picture fades off the live page in this long.
  static const double _fade = 0.3;

  late final Ticker _ticker;
  final _clock = _SandClock();
  bool _swapStarted = false, _swapped = false, _capturing = false;
  bool _done = false;
  double _swappedAt = 0;
  double? _assembleAt, _fadeAt;
  SandPicture? _to;
  final _veil = _SandVeil();

  @override
  void initState() {
    super.initState();
    if (widget.turns) {
      _veil.dimAt = widget.from.doneBy + _swapAfterGather;
    }
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_done) return;
    final t = _clock.advance(elapsed);
    final swapAt = widget.turns
        ? _veil.outBy
        : widget.from.doneBy + _swapAfterGather;
    if (!_swapStarted && t >= swapAt) {
      _swapStarted = true;
      unawaited(
        widget.swap().catchError((Object _) {}).whenComplete(() {
          _swapped = true;
          _swappedAt = _clock.t;
          // A couple of frames more on the dark for the stretched ones.
          if (widget.turns) _veil.lightAt = _clock.t + 0.06;
        }),
      );
    }
    if (_swapped &&
        !_capturing &&
        ((widget.ready?.value ?? true) || t - _swappedAt >= _timeout)) {
      _capturing = true;
      widget.capture().then(
        (picture) {
          if (!mounted || _done) {
            picture?.dispose();
            return;
          }
          _to = picture;
          // Not before the ball has lit again after the turn.
          _assembleAt = widget.turns
              ? math.max(_clock.t, _veil.litBy)
              : _clock.t;
          if (picture == null) _fadeAt = _assembleAt;
        },
        onError: (Object _) {
          if (mounted) _fadeAt = _clock.t;
        },
      );
    }
    final to = _to, assembleAt = _assembleAt;
    if (to != null &&
        assembleAt != null &&
        _fadeAt == null &&
        t - assembleAt >= to.doneBy + 0.05) {
      _fadeAt = t;
    }
    final fadeAt = _fadeAt;
    if (fadeAt != null && t >= fadeAt + _fade) {
      _done = true;
      _ticker.stop();
      widget.onComplete();
      return;
    }
    _clock.tick(t);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    widget.from.dispose();
    _to?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing reaches the screen behind, nor the page until it is shown.
    return AbsorbPointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SandEnterPainter(this),
        ),
      ),
    );
  }
}

class _SandEnterPainter extends CustomPainter {
  _SandEnterPainter(this.state) : super(repaint: state._clock);

  final _SandEnterOverlayState state;

  @override
  void paint(Canvas canvas, Size size) {
    final t = state._clock.t;
    final fadeAt = state._fadeAt;
    final gone = fadeAt == null ? 0.0 : _sandSmooth(0, 1, (t - fadeAt) / 0.3);
    _paintSandGround(
      canvas,
      size,
      _sandSmooth(0, _SandEnterOverlayState._darken, t) * (1 - gone),
    );
    final from = state.widget.from;
    if (!state._swapStarted) from.paintHole(canvas, size, _sandGround);
    final assembleAt = state._assembleAt;
    final since = assembleAt == null || t < assembleAt ? null : t - assembleAt;
    final to = state._to;
    // The circle's grains go out of the ball as the page's come into it,
    // and out altogether while the phone turns.
    final lit = state._veil.lit(t);
    final fade =
        (since == null ? 1 - gone : 1 - _sandSmooth(0, 0.45, since)) * lit;
    if (fade > 0.002) {
      if (lit < 1) _SandVeil.drawIn(canvas, size, lit);
      from.paintGather(canvas, size, t, fade: fade);
      if (lit < 1) canvas.restore();
    }
    if (to != null && since != null) {
      to.paintAssemble(canvas, size, t, since, opacity: 1 - gone);
    }
  }

  @override
  bool shouldRepaint(_SandEnterPainter old) => old.state != state;
}

// ============================================================================
// Internal Implementation (Optimized for 60FPS)
// ============================================================================

_PortalHandle _showPortalWarp(
  BuildContext context, {
  required VoidPortalConfig config,
  required FutureOr<void> Function() onMidpoint,
}) {
  final overlay = Navigator.of(context).overlay!;
  late OverlayEntry entry;
  final handle = _PortalHandle();

  entry = OverlayEntry(
    builder: (_) => _WarpEffectOverlay(
      config: config,
      onMidpoint: onMidpoint,
      onComplete: () {
        entry.remove();
        handle._complete();
      },
    ),
  );

  overlay.insert(entry);
  return handle;
}

class _PortalHandle {
  final _completer = Completer<void>();
  Future<void> get future => _completer.future;
  void _complete() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

class _WarpEffectOverlay extends StatefulWidget {
  const _WarpEffectOverlay({
    required this.config,
    required this.onMidpoint,
    required this.onComplete,
  });

  final VoidPortalConfig config;
  final FutureOr<void> Function() onMidpoint;
  final VoidCallback onComplete;

  @override
  State<_WarpEffectOverlay> createState() => _WarpEffectOverlayState();
}

class _WarpEffectOverlayState extends State<_WarpEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final _WarpPainterData _painterData;
  bool _midpointFired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.config.duration,
    );

    // Pre-generate all data once
    _painterData = _WarpPainterData.generate(widget.config);

    _controller.addListener(_tick);
    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _tick() {
    if (!_midpointFired && _controller.value >= 0.5) {
      _midpointFired = true;
      widget.onMidpoint();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              size: size,
              painter: _WarpPainter(
                progress: _controller.value,
                data: _painterData,
                size: size,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ----------------------------------------------------------------------------
// Pre-computed Data Structures
// ----------------------------------------------------------------------------

class _Star {
  final double angle;
  final double cosAngle;
  final double sinAngle;
  final double distance; // Starting distance from center (0.0 - 1.0)
  final double size;
  final double speedVariance;
  final double brightness; // 0.0 - 1.0

  _Star({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speedVariance,
    required this.brightness,
  }) : cosAngle = math.cos(angle),
       sinAngle = math.sin(angle);

  factory _Star.random(math.Random r) {
    return _Star(
      angle: r.nextDouble() * math.pi * 2,
      distance: 0.1 + r.nextDouble() * 0.9, // Spread across the screen
      size: 0.1 + r.nextDouble(), // Small dots
      speedVariance: 0.5 + r.nextDouble() * 1.0,
      brightness: 0.3 + r.nextDouble() * 0.7,
    );
  }
}

/// Pre-computed painter data to avoid allocations during paint
class _WarpPainterData {
  final VoidPortalConfig config;
  final List<_Star> stars;

  // Pre-computed colors at various opacities
  final List<Color> starOpacities;
  final List<Color> dimStarOpacities;

  // Reusable paint objects
  final Paint backgroundPaint;
  final Paint starPaint;
  final Paint glowPaint;

  _WarpPainterData._({
    required this.config,
    required this.stars,
    required this.starOpacities,
    required this.dimStarOpacities,
    required this.backgroundPaint,
    required this.starPaint,
    required this.glowPaint,
  });

  factory _WarpPainterData.generate(VoidPortalConfig config) {
    final random = math.Random();

    // Generate stars
    final stars = List.generate(
      config.effectiveStarCount,
      (_) => _Star.random(random),
    );

    // Pre-compute opacity variants
    final starOpacities = List.generate(
      21,
      (i) => config.starColor.withValues(alpha: i / 20),
    );
    final dimStarOpacities = List.generate(
      21,
      (i) => config.dimStarColor.withValues(alpha: i / 20),
    );

    // Create reusable paints
    final backgroundPaint = Paint();
    final starPaint = Paint();
    final glowPaint = Paint();

    return _WarpPainterData._(
      config: config,
      stars: stars,
      starOpacities: starOpacities,
      dimStarOpacities: dimStarOpacities,
      backgroundPaint: backgroundPaint,
      starPaint: starPaint,
      glowPaint: glowPaint,
    );
  }

  Color getStarWithOpacity(double opacity) {
    final index = (opacity.clamp(0.0, 1.0) * 20).round();
    return starOpacities[index];
  }

  Color getDimStarWithOpacity(double opacity) {
    final index = (opacity.clamp(0.0, 1.0) * 20).round();
    return dimStarOpacities[index];
  }
}

// ----------------------------------------------------------------------------
// Optimized Painter
// ----------------------------------------------------------------------------

class _WarpPainter extends CustomPainter {
  _WarpPainter({
    required this.progress,
    required this.data,
    required this.size,
  });

  final double progress;
  final _WarpPainterData data;
  final Size size;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxDist =
        math.sqrt(size.width * size.width + size.height * size.height) * 0.7;

    final bool isWarpingIn = progress < 0.5;
    final double t = isWarpingIn ? progress * 2 : (progress - 0.5) * 2;
    final double easedT = isWarpingIn ? _easeInQuad(t) : _easeOutQuad(t);

    // 1. Black background
    _drawBackground(canvas, size, easedT, isWarpingIn);

    // 2. Stars being pulled into/out of the void
    _drawStars(canvas, centerX, centerY, maxDist, easedT, isWarpingIn);

    // 3. Subtle center glow (white, like a distant light)
    if (data.config.showGlow) {
      _drawCenterGlow(canvas, centerX, centerY, easedT, isWarpingIn);
    }
  }

  void _drawBackground(Canvas canvas, Size size, double t, bool isWarpingIn) {
    final opacity = isWarpingIn ? t : (1.0 - t);
    if (opacity <= 0) return;

    data.backgroundPaint
      ..shader = null
      ..color = data.config.color.withValues(alpha: opacity);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      data.backgroundPaint,
    );
  }

  void _drawStars(
    Canvas canvas,
    double centerX,
    double centerY,
    double maxDist,
    double t,
    bool isWarpingIn,
  ) {
    for (final star in data.stars) {
      // Calculate star position - moving toward or away from center
      double distanceRatio;
      double alpha;
      double currentSize;

      if (isWarpingIn) {
        // Stars rush toward center
        final adjustedT = (t * star.speedVariance).clamp(0.0, 1.0);
        distanceRatio = star.distance * (1.0 - _easeInCubic(adjustedT));
        alpha = star.brightness * (0.3 + adjustedT * 0.7);
        // Stars stretch slightly as they accelerate
        currentSize = star.size * (1.0 + adjustedT * 2.0);
      } else {
        // Stars rush away from center
        final adjustedT = (t * star.speedVariance).clamp(0.0, 1.0);
        distanceRatio = star.distance * _easeOutCubic(adjustedT);
        alpha = star.brightness * (1.0 - adjustedT * 0.7);
        currentSize = star.size * (3.0 - adjustedT * 2.0);
      }

      if (alpha <= 0.05 || distanceRatio <= 0) continue;

      final dist = maxDist * distanceRatio;
      final x = centerX + star.cosAngle * dist;
      final y = centerY + star.sinAngle * dist;

      // Draw star as a small circle
      final starColor = star.brightness > 0.6
          ? data.getStarWithOpacity(alpha)
          : data.getDimStarWithOpacity(alpha);

      data.starPaint
        ..color = starColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), currentSize, data.starPaint);

      // Add subtle glow to bright stars
      if (data.config.enableBlur && star.brightness > 0.7 && alpha > 0.5) {
        data.starPaint
          ..color = data.getStarWithOpacity(alpha * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(x, y), currentSize * 1.5, data.starPaint);
        data.starPaint.maskFilter = null;
      }
    }
  }

  void _drawCenterGlow(
    Canvas canvas,
    double centerX,
    double centerY,
    double t,
    bool isWarpingIn,
  ) {
    final glowIntensity = isWarpingIn ? t : (1.0 - t);
    if (glowIntensity <= 0) return;

    // Soft white glow at center
    data.glowPaint.shader =
        RadialGradient(
          colors: [
            data.getStarWithOpacity(glowIntensity * 0.4),
            data.getStarWithOpacity(glowIntensity * 0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: 100),
        );

    canvas.drawCircle(Offset(centerX, centerY), 100, data.glowPaint);
  }

  // Inline easing functions
  static double _easeInCubic(double t) => t * t * t;
  static double _easeOutCubic(double t) {
    final t1 = t - 1;
    return t1 * t1 * t1 + 1;
  }

  static double _easeInQuad(double t) => t * t;
  static double _easeOutQuad(double t) => t * (2 - t);

  @override
  bool shouldRepaint(_WarpPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
