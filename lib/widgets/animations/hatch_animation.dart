import 'dart:async';
import 'package:alchemons/constants/egg.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/background/interactive_background_widget.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Fullscreen overlay: plays a Lottie egg hatch with animated background,
/// then fades to white, then calls [onFinished].
class HatchCinematic extends StatefulWidget {
  final String lottieAsset;
  final VoidCallback onFinished;
  final Duration whiteFade;
  final Color bg;

  /// Begin white fade when Lottie progress reaches this (0..1).
  final double triggerAt;

  /// Multiply the original Lottie duration by this factor.
  final double speed;

  /// Start playback at this fraction into the animation (0..1).
  final double startAt;

  final EggPalette palette;

  /// Faction type for background animation
  final FactionId? factionId;

  const HatchCinematic({
    super.key,
    required this.lottieAsset,
    required this.onFinished,
    required this.palette,
    this.factionId,
    this.whiteFade = const Duration(milliseconds: 280),
    this.bg = const Color(0xFF0E0F1A),
    this.triggerAt = 0.80,
    this.speed = 0.8,
    this.startAt = 0.0,
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

  // Background animation controllers
  late final AnimationController _particleController;
  late final AnimationController _rotationController;
  late final AnimationController _waveController;

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

    // Initialize background controllers
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _lottieCtrl.addListener(() {
      if (!_triggered && _lottieCtrl.value >= widget.triggerAt) {
        _triggerFadeOnce();
      }
    });

    _lottieCtrl.addStatusListener((st) {
      if (st == AnimationStatus.completed) _triggerFadeOnce();
    });

    _failsafe = Timer(const Duration(seconds: 4), () {
      if (mounted && !_triggered) _triggerFadeOnce();
    });
  }

  @override
  void dispose() {
    _failsafe?.cancel();
    _lottieCtrl.dispose();
    _whiteCtrl.dispose();
    _particleController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background layer
          InteractiveBackground(
            particleController: _particleController,
            rotationController: _rotationController,
            waveController: _waveController,
            primaryColor: widget.palette.shell,
            secondaryColor: widget.palette.shell.withOpacity(0.7),
            accentColor: widget.palette.shell.withOpacity(0.5),
            factionType: widget.factionId ?? FactionId.air,
            particleSpeed: 0.6, // Slower, more ambient
            rotationSpeed: 0.4, // Gentle rotation
            elementalSpeed: 0.5, // Subtle elemental effects
          ),

          // Dark overlay to help egg pop
          Container(color: widget.bg.withOpacity(0.3)),

          // Egg hatch animation on top
          RepaintBoundary(
            child: Center(
              child: Lottie.asset(
                widget.lottieAsset,
                controller: _lottieCtrl,
                fit: BoxFit.contain,
                repeat: false,
                delegates: LottieDelegates(
                  values: [
                    ValueDelegate.color(const [
                      'Egg main',
                      'upper egg Outlines',
                      'Group 1',
                      'Fill 1',
                    ], value: widget.palette.shell),
                    ValueDelegate.color(const [
                      'Egg main',
                      'lower egg Outlines',
                      'Group 1',
                      'Fill 1',
                    ], value: widget.palette.shell),
                  ],
                ),
                onLoaded: (c) {
                  final spedUp = Duration(
                    milliseconds: (c.duration.inMilliseconds * widget.speed)
                        .round(),
                  );

                  _lottieCtrl
                    ..duration = spedUp
                    ..value = widget.startAt.clamp(0.0, 0.98)
                    ..forward();
                },
              ),
            ),
          ),

          // White fade overlay
          FadeTransition(
            opacity: _whiteCtrl.drive(Tween(begin: 0.0, end: 1.0)),
            child: const ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
