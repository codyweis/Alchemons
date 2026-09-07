// lib/widgets/animations/sprite_effects/static_effect_snapshot.dart
//
// Pre-baked "resting frame" rasters for the alchemy sprite effects.
//
// The sprite effects (VolcanicAura, PrismaticCascade, VoidRift, RitualGold, …)
// were authored for a single hero slot: layered MaskFilter blurs, sweep
// gradients and Paths rebuilt inside paint(), and two or three
// AnimationControllers apiece. Eleven of them running at once inside a
// scrolling shop grid costs more per frame than the rest of the screen
// combined, and every one of those frames lands on the scroll thread.
//
// [StaticEffectSnapshot] mounts the *real* effect widget exactly once with its
// tickers muted — so every AnimationController sits at its initial value and
// the subtree paints the effect's t = 0 frame, the same pixels the widget shows
// on the first frame it is mounted today — captures the resulting layer into a
// ui.Image, and from then on draws that image with a single drawImageRect.
//
// Nothing about the artwork changes: the bake is a photograph of the real
// widget, not a reimplementation of it. If the capture ever fails the frozen
// live widget stays on screen, which is still repaint-free.

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Process-wide LRU of baked effect rasters, keyed by effect + capture extent +
/// device pixel ratio.
///
/// Entries are owned by the cache; [take] hands out `ui.Image.clone()` handles
/// so evicting a master image can never pull the pixels out from under a widget
/// that is still painting it.
class EffectSnapshotCache {
  EffectSnapshotCache._();

  static final EffectSnapshotCache instance = EffectSnapshotCache._();

  /// Hard ceiling on retained raster bytes.
  ///
  /// The shop bakes 11 effects at a 128pt capture box; at a device pixel ratio
  /// of 3 that is 384x384x4B = 576 KB each, ~6.2 MB in total — the realistic
  /// worst case. The budget below leaves headroom for one more screen's worth
  /// and evicts least-recently-used entries beyond it.
  static const int maxBytes = 8 * 1024 * 1024;

  /// Belt-and-braces cap so a pathological key space cannot grow unbounded even
  /// with small rasters.
  static const int maxEntries = 24;

  final LinkedHashMap<String, ui.Image> _lru =
      LinkedHashMap<String, ui.Image>();
  int _bytes = 0;

  /// Bytes currently retained by baked rasters.
  int get retainedBytes => _bytes;

  /// Number of baked rasters currently retained.
  int get length => _lru.length;

  static int _sizeOf(ui.Image image) => image.width * image.height * 4;

  /// Returns a caller-owned clone of the cached raster, or null on a miss.
  ///
  /// The caller must dispose the returned image.
  ui.Image? take(String key) {
    final image = _lru.remove(key);
    if (image == null) return null;
    _lru[key] = image; // reinsert at the tail — most recently used
    return image.clone();
  }

  /// Stores [image] under [key]; the cache takes ownership of [image].
  void put(String key, ui.Image image) {
    final previous = _lru.remove(key);
    if (previous != null) {
      _bytes -= _sizeOf(previous);
      previous.dispose();
    }
    _lru[key] = image;
    _bytes += _sizeOf(image);

    while (_lru.length > maxEntries || (_bytes > maxBytes && _lru.length > 1)) {
      final oldest = _lru.keys.first;
      final evicted = _lru.remove(oldest)!;
      _bytes -= _sizeOf(evicted);
      evicted.dispose();
    }
  }

  @visibleForTesting
  void clear() {
    for (final image in _lru.values) {
      image.dispose();
    }
    _lru.clear();
    _bytes = 0;
  }
}

/// Draws [child] as a one-off baked raster instead of a live animation.
///
/// The widget occupies exactly [boxSize] logical pixels of layout, matching the
/// `SizedBox.square(dimension: size)` the effect would otherwise sit in, but
/// paints a [captureScale]x box centred on that slot so effects that
/// deliberately bleed past their layout box (the outer glows, the orbiting
/// sparks) keep bleeding exactly as far as they do today. Whatever clips the
/// widget today clips the raster identically.
class StaticEffectSnapshot extends StatefulWidget {
  const StaticEffectSnapshot({
    super.key,
    required this.cacheKey,
    required this.boxSize,
    required this.child,
    this.captureScale = 2.0,
    this.maxCapturePixelRatio = 3.0,
  });

  /// Stable identity of the artwork — same key must mean same pixels.
  final String cacheKey;

  /// Logical layout footprint, and the box [child] is laid out in.
  final double boxSize;

  /// The live effect widget. Mounted for one muted frame, then discarded.
  final Widget child;

  /// How much larger than [boxSize] the captured/painted box is, to preserve
  /// overflow. 2.0 covers every alchemy effect's visible extent.
  final double captureScale;

  /// Capture resolution ceiling, so a 4x display cannot blow the byte budget.
  final double maxCapturePixelRatio;

  @override
  State<StaticEffectSnapshot> createState() => _StaticEffectSnapshotState();
}

class _StaticEffectSnapshotState extends State<StaticEffectSnapshot> {
  final GlobalKey _boundaryKey = GlobalKey();

  ui.Image? _image;
  double _pixelRatio = 1.0;
  bool _capturePending = false;
  bool _captureFailed = false;

  double get _captureExtent => widget.boxSize * widget.captureScale;

  String get _key =>
      '${widget.cacheKey}'
      '|${_captureExtent.toStringAsFixed(1)}'
      '|${_pixelRatio.toStringAsFixed(2)}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = math.min(
      MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0,
      widget.maxCapturePixelRatio,
    );
    if (ratio != _pixelRatio) {
      _pixelRatio = ratio;
      _adoptCached();
    }
  }

  @override
  void didUpdateWidget(covariant StaticEffectSnapshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.boxSize != widget.boxSize ||
        oldWidget.captureScale != widget.captureScale) {
      _adoptCached();
    }
  }

  void _adoptCached() {
    final cached = EffectSnapshotCache.instance.take(_key);
    _image?.dispose();
    _image = cached;
    _captureFailed = false;
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  /// Called from the paint phase of the probe, i.e. only on frames where the
  /// frozen subtree actually rendered. Off-screen (an unselected IndexedStack
  /// branch, a collapsed section) this never fires, so nothing is scheduled.
  void _onChildPainted() {
    if (_capturePending || _captureFailed || _image != null) return;
    _capturePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePending = false;
      if (!mounted || _captureFailed || _image != null) return;
      _capture();
    });
  }

  void _capture() {
    final object = _boundaryKey.currentContext?.findRenderObject();
    // Not a boundary yet, or laid out to nothing — leave it; the probe re-arms
    // on the next real paint.
    if (object is! RenderRepaintBoundary) return;
    if (!object.hasSize || object.size.isEmpty) return;

    final ui.Image baked;
    try {
      baked = object.toImageSync(pixelRatio: _pixelRatio);
    } catch (_) {
      // No rasterizer for this surface. Keep the frozen live widget: it is
      // still static, and still repaint-free.
      _captureFailed = true;
      return;
    }

    EffectSnapshotCache.instance.put(_key, baked);
    final mine = EffectSnapshotCache.instance.take(_key);
    if (mine == null) {
      _captureFailed = true;
      return;
    }
    if (!mounted) {
      mine.dispose();
      return;
    }
    setState(() => _image = mine);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return SizedBox.square(
      dimension: widget.boxSize,
      child: Center(
        child: OverflowBox(
          minWidth: _captureExtent,
          maxWidth: _captureExtent,
          minHeight: _captureExtent,
          maxHeight: _captureExtent,
          child: image == null
              ? RepaintBoundary(
                  key: _boundaryKey,
                  child: TickerMode(
                    // Every AnimationController in the subtree stays at its
                    // initial value: this renders the artwork's t = 0 frame.
                    enabled: false,
                    child: CustomPaint(
                      foregroundPainter: _PaintProbe(_onChildPainted),
                      child: Center(child: widget.child),
                    ),
                  ),
                )
              : RawImage(
                  image: image,
                  width: _captureExtent,
                  height: _captureExtent,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.low,
                ),
        ),
      ),
    );
  }
}

/// Draws nothing; exists only to learn that the subtree below it really
/// painted this frame, which is when a [RenderRepaintBoundary] capture can
/// succeed.
class _PaintProbe extends CustomPainter {
  const _PaintProbe(this.onPainted);

  final VoidCallback onPainted;

  @override
  void paint(Canvas canvas, Size size) => onPainted();

  @override
  bool shouldRepaint(covariant _PaintProbe oldDelegate) => false;
}
