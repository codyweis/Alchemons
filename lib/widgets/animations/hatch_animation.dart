import 'dart:async';
import 'package:alchemons/constants/egg.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Fullscreen overlay: plays a Lottie egg hatch, then fades to white,
/// then calls [onFinished].
class HatchCinematic extends StatefulWidget {
  final String lottieAsset;
  final VoidCallback onFinished;
  final Duration whiteFade;
  final Color bg;

  /// Begin white fade when Lottie progress reaches this (0..1).
  final double triggerAt;

  /// Multiply the original Lottie duration by this factor.
  /// e.g. 0.7 = 30% faster, 0.5 = 2x speed.
  final double speed;

  /// Start playback at this fraction into the animation (0..1).
  /// e.g. 0.15 skips the first 15%.
  final double startAt;

  final EggPalette palette;

  const HatchCinematic({
    super.key,
    required this.lottieAsset,
    required this.onFinished,
    required this.palette,
    this.whiteFade = const Duration(milliseconds: 280), // faster default
    this.bg = const Color(0xFF0E0F1A),
    this.triggerAt = 0.80, // earlier flash
    this.speed = 0.8, // 30% faster
    this.startAt = 0.0, // no skip by default
  });

  @override
  State<HatchCinematic> createState() => _HatchCinematicState();
}

class _HatchCinematicState extends State<HatchCinematic>
    with TickerProviderStateMixin {
  late final AnimationController _lottieCtrl = AnimationController(vsync: this);
  late final AnimationController _whiteCtrl = AnimationController(
    vsync: this,
    duration: widget.whiteFade,
  );

  bool _triggered = false;
  Timer? _failsafe;

  void _triggerFadeOnce() {
    if (_triggered) return;
    _triggered = true;
    _whiteCtrl.forward().whenComplete(widget.onFinished);
  }

  @override
  void initState() {
    super.initState();

    _lottieCtrl.addListener(() {
      if (!_triggered && _lottieCtrl.value >= widget.triggerAt) {
        _triggerFadeOnce();
      }
    });

    _lottieCtrl.addStatusListener((st) {
      if (st == AnimationStatus.completed) _triggerFadeOnce();
    });

    // Failsafe sooner since we’re speeding up
    _failsafe = Timer(const Duration(seconds: 4), () {
      if (mounted && !_triggered) _triggerFadeOnce();
    });
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    _lottieCtrl.dispose();
    _whiteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.bg,
      child: RepaintBoundary(
        // tiny perf win
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Lottie.asset(
                widget.lottieAsset,
                controller: _lottieCtrl,
                fit: BoxFit.contain,
                repeat: false,
                delegates: LottieDelegates(
                  values: [
                    // Upper shell
                    ValueDelegate.color(const [
                      'Egg main',
                      'upper egg Outlines',
                      'Group 1',
                      'Fill 1',
                    ], value: widget.palette.shell),
                    // Lower shell
                    ValueDelegate.color(const [
                      'Egg main',
                      'lower egg Outlines',
                      'Group 1',
                      'Fill 1',
                    ], value: widget.palette.shell),
                  ],
                ),
                onLoaded: (c) {
                  // Speed: shrink duration by factor (<=1 speeds up)
                  final spedUp = Duration(
                    milliseconds: (c.duration.inMilliseconds * widget.speed)
                        .round(),
                  );

                  _lottieCtrl
                    ..duration = spedUp
                    ..value = widget.startAt
                        .clamp(0.0, 0.98) // optional skip
                    ..forward();
                },
              ),
            ),
            FadeTransition(
              opacity: _whiteCtrl.drive(Tween(begin: 0.0, end: 1.0)),
              child: const ColoredBox(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
