import 'dart:async';
import 'package:flutter/material.dart';

class CreatureScanAnimation extends StatefulWidget {
  final Widget child;
  final bool isNewDiscovery;

  /// Called when the scan chain completes. Only fired if [autoComplete] is true
  /// *and* no external action has been taken.
  final VoidCallback? onScanComplete;

  /// Total scan duration.
  final Duration scanDuration;

  /// If true, this widget absorbs touches over its own bounds while animating.
  final bool blockTouchesWhileAnimating;

  /// Emits when the widget is ready for user interaction (CTA can be enabled).
  final ValueChanged<bool>? onReadyChanged;

  /// If true, the widget will call [onScanComplete] automatically when the
  /// animation chain finishes. Set this to false when you show your own button.
  final bool autoComplete;

  const CreatureScanAnimation({
    super.key,
    required this.child,
    this.isNewDiscovery = false,
    this.onScanComplete,
    this.scanDuration = const Duration(milliseconds: 1000),
    this.blockTouchesWhileAnimating = false,
    this.onReadyChanged,
    this.autoComplete = false, // <- default to manual, safer for CTA flows
  });

  @override
  State<CreatureScanAnimation> createState() => CreatureScanAnimationState();
}

class CreatureScanAnimationState extends State<CreatureScanAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _gridController;
  late final AnimationController _discoveryController;

  late final Animation<double> _scanPosition;
  late final Animation<double> _gridOpacity;
  late final Animation<double> _creatureOpacity;
  late final Animation<double> _discoveryFlash;

  late final Listenable _allAnimations;

  Timer? _flashDelay;

  // Guards
  bool _completionQueued = false; // internal completion scheduled
  bool _externalHandled = false; // parent pressed CTA and took control
  bool _readyForTap = false;

  bool get isReadyForTap => _readyForTap;

  /// Call this from your CTA before you navigate/change screens.
  /// It atomically marks the completion as handled so any queued internal
  /// completion will be ignored.
  void takeAction() {
    if (!mounted) return; // extra safety
    _externalHandled = true;
    _completionQueued = false; // ignore any queued internal callback
  }

  void restart() {
    if (!mounted) return; // prevent use after dispose
    _startScanning();
  }

  @override
  void initState() {
    super.initState();

    final scanMs = widget.scanDuration.inMilliseconds;
    final mainScanMs = (scanMs * 0.75).round();

    _scanController = AnimationController(
      duration: Duration(milliseconds: mainScanMs),
      vsync: this,
    );

    _gridController = AnimationController(
      duration: Duration(milliseconds: (mainScanMs * 0.8).round()),
      vsync: this,
    );

    _discoveryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // ---- Animations ----
    _scanPosition = Tween<double>(
      begin: -0.1,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    _gridOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.6), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 0.6), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 0.0), weight: 20),
    ]).animate(_gridController);

    _creatureOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.4), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 0.4), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.0), weight: 30),
    ]).animate(_scanController);

    _discoveryFlash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_discoveryController);

    // merged listenable (built once)
    _allAnimations = Listenable.merge([
      _scanController,
      _gridController,
      _discoveryController,
    ]);

    // ---- Chain (no awaits) ----
    _scanController.addStatusListener(_onScanStatus);
    _discoveryController.addStatusListener(_onDiscoveryStatus);

    _startScanning();
  }

  void _onScanStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      if (widget.isNewDiscovery) {
        _flashDelay?.cancel();
        _flashDelay = Timer(const Duration(milliseconds: 200), () {
          if (!mounted || _externalHandled) return;
          _discoveryController.forward(from: 0);
        });
      } else {
        _queueCompletion();
      }
    }
  }

  void _onDiscoveryStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      _queueCompletion();
    }
  }

  void _queueCompletion() {
    if (_completionQueued) return;
    _completionQueued = true;

    // Mark ready before calling out, so UI can enable CTA immediately.
    _setReady(true);

    // Defer to next frame and respect externalHandled + autoComplete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_externalHandled) return; // parent CTA already acted
      if (!widget.autoComplete) return; // manual mode -> do nothing
      widget.onScanComplete?.call(); // auto mode -> fire once
    });
  }

  void _setReady(bool v) {
    if (_readyForTap == v) return;
    _readyForTap = v;
    widget.onReadyChanged?.call(v);
    if (mounted) setState(() {});
  }

  void _startScanning() {
    if (!mounted) return; // defensive: don't drive controllers after dispose
    _flashDelay?.cancel();
    _completionQueued = false;
    _externalHandled = false;
    _setReady(false);

    _gridController.value = 0;
    _scanController.value = 0;
    _discoveryController.value = 0;

    _gridController.forward(from: 0);
    _scanController.forward(from: 0);
  }

  @override
  void dispose() {
    _flashDelay?.cancel();
    _scanController.removeStatusListener(_onScanStatus);
    _discoveryController.removeStatusListener(_onDiscoveryStatus);

    // Mark as externally handled to prevent any pending callbacks
    _externalHandled = true;
    _completionQueued = false;

    for (final c in [_scanController, _gridController, _discoveryController]) {
      c.stop(canceled: true);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder outside the AnimatedBuilder so it doesn't rebuild every tick.
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _allAnimations,
          builder: (context, _) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Main content
                Center(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Opacity(
                      opacity: _creatureOpacity.value,
                      child: widget.child,
                    ),
                  ),
                ),

                // Grid
                if (_gridOpacity.value > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: _gridOpacity.value,
                      child: const CustomPaint(
                        painter: HolographicGridPainter(),
                      ),
                    ),
                  ),

                // Scan line
                if (_scanController.isAnimating)
                  Positioned(
                    top:
                        (_scanPosition.value * (constraints.maxHeight - 20)) +
                        10,
                    left: 1,
                    right: 1,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade400,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.shade400,
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Brackets
                if (_scanController.isAnimating || _gridController.isAnimating)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ScanningBracketsPainter(
                        progress: _scanController,
                      ),
                    ),
                  ),

                // Discovery flash
                if (widget.isNewDiscovery && _discoveryController.isAnimating)
                  Positioned(
                    top: -(constraints.maxHeight * 0.12),
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: _discoveryFlash.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.shade400,
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'NEW DISCOVERY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Optional input blocker over this widget's area only
                if (widget.blockTouchesWhileAnimating && !_readyForTap)
                  const Positioned.fill(
                    child: AbsorbPointer(child: SizedBox.expand()),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// === Painters ===

class HolographicGridPainter extends CustomPainter {
  const HolographicGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.cyan.shade400.withOpacity(0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const step = 20.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final border = Paint()
      ..color = Colors.cyan.shade400.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanningBracketsPainter extends CustomPainter {
  final Animation<double> progress;

  ScanningBracketsPainter({required this.progress}) : super(repaint: progress);

  final Paint _p = Paint()
    ..color = Colors.cyan.shade400.withOpacity(0.8)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    const maxLen = 20.0;
    final len = maxLen * progress.value;

    // TL
    canvas.drawLine(Offset(0, len), const Offset(0, 0), _p);
    canvas.drawLine(const Offset(0, 0), Offset(len, 0), _p);
    // TR
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), _p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), _p);
    // BL
    canvas.drawLine(Offset(0, size.height - len), Offset(0, size.height), _p);
    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), _p);
    // BR
    canvas.drawLine(
      Offset(size.width - len, size.height),
      Offset(size.width, size.height),
      _p,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - len),
      _p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
