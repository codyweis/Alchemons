import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// One clock for every particle glyph on screen.
///
/// These appear in lists — the black market draws five at once, the shop rows
/// more, and the harvester shelf another six — and giving each its own
/// AnimationController means one ticker per glyph all asking for the same
/// frame. Ref-counted so the ticker only runs while something is painting.
class GlyphClock {
  GlyphClock._();
  static final GlyphClock instance = GlyphClock._();

  final ValueNotifier<double> seconds = ValueNotifier<double>(0);
  Ticker? _ticker;
  int _listeners = 0;

  void acquire() {
    _listeners++;
    if (_ticker != null) return;
    _ticker = Ticker((elapsed) {
      seconds.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  void release() {
    _listeners = math.max(0, _listeners - 1);
    if (_listeners > 0) return;
    _ticker?.dispose();
    _ticker = null;
  }
}

/// Holds a [GlyphClock] lease for as long as [wantsClock] stays true.
///
/// Every glyph does the same acquire/release dance around its animate flag;
/// keeping the ref-counting here means a widget cannot leak a lease by
/// getting one half of it wrong. Call [syncGlyphClock] from initState and
/// didUpdateWidget, and [releaseGlyphClock] from dispose.
mixin GlyphClockLease<T extends StatefulWidget> on State<T> {
  bool _held = false;

  /// Whether this glyph currently wants frames.
  bool get wantsClock;

  /// Null when the glyph is at rest, which leaves its painter static.
  ValueListenable<double>? get glyphClock =>
      wantsClock ? GlyphClock.instance.seconds : null;

  void syncGlyphClock() {
    if (wantsClock && !_held) {
      GlyphClock.instance.acquire();
      _held = true;
    } else if (!wantsClock && _held) {
      GlyphClock.instance.release();
      _held = false;
    }
  }

  void releaseGlyphClock() {
    if (!_held) return;
    GlyphClock.instance.release();
    _held = false;
  }
}
