// lib/widgets/perf/viewport_ticker_gate.dart
//
// Two cheap guarantees for an animated section that lives inside a scrollable:
//
//  1. It gets its own compositing layer, so its repaints cannot dirty — and
//     force a re-record of — the entire scroll view every frame.
//  2. Its tickers are muted while it is scrolled out of the viewport, so
//     controllers that nobody can see stop driving frames.
//
// Visibility is recomputed from a post-frame callback (layout is clean there)
// and coalesced to at most one check per frame; the check itself is a single
// localToGlobal against the scrollable's box. State only changes when the
// widget crosses the viewport edge, so a steady scroll costs one comparison
// per frame and no rebuilds.

import 'package:flutter/widgets.dart';

class ViewportTickerGate extends StatefulWidget {
  const ViewportTickerGate({
    super.key,
    required this.child,
    this.slack = 120.0,
  });

  final Widget child;

  /// Extra margin above/below the viewport that still counts as visible, so a
  /// section does not pop back to life mid-fling right at the edge.
  final double slack;

  @override
  State<ViewportTickerGate> createState() => _ViewportTickerGateState();
}

class _ViewportTickerGateState extends State<ViewportTickerGate> {
  ScrollPosition? _position;
  bool _visible = true;
  bool _checkScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleCheck);
      _position = position;
      _position?.addListener(_scheduleCheck);
    }
    _scheduleCheck();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleCheck);
    _position = null;
    super.dispose();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final visible = _computeVisible();
      if (visible != _visible) {
        setState(() => _visible = visible);
      }
    });
  }

  bool _computeVisible() {
    final scrollableContext = Scrollable.maybeOf(context)?.context;
    if (scrollableContext == null) return true;

    final self = context.findRenderObject();
    final viewport = scrollableContext.findRenderObject();
    if (self is! RenderBox || viewport is! RenderBox) return true;
    if (!self.attached || !viewport.attached) return true;
    if (!self.hasSize || !viewport.hasSize) return true;

    final top = self.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final bottom = top + self.size.height;
    return bottom >= -widget.slack &&
        top <= viewport.size.height + widget.slack;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TickerMode(enabled: _visible, child: widget.child),
    );
  }
}
