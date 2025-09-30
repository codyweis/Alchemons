import 'package:flutter/material.dart';

class CreatureScanAnimation extends StatefulWidget {
  final Widget child;
  final bool isNewDiscovery;
  final VoidCallback? onScanComplete;
  final Duration scanDuration;

  const CreatureScanAnimation({
    super.key,
    required this.child,
    this.isNewDiscovery = false,
    this.onScanComplete,
    this.scanDuration = const Duration(milliseconds: 2000),
  });

  @override
  State<CreatureScanAnimation> createState() => _CreatureScanAnimationState();
}

class _CreatureScanAnimationState extends State<CreatureScanAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _gridController;
  late AnimationController _discoveryController;

  late Animation<double> _scanPosition;
  late Animation<double> _gridOpacity;
  late Animation<double> _creatureOpacity;
  late Animation<double> _discoveryFlash;

  @override
  void initState() {
    super.initState();

    // Use the passed scanDuration for the main scan effect
    final scanDuration = (widget.scanDuration.inMilliseconds * 0.75).round();

    _scanController = AnimationController(
      duration: Duration(milliseconds: scanDuration),
      vsync: this,
    );

    _gridController = AnimationController(
      duration: Duration(milliseconds: (scanDuration * 0.8).round()),
      vsync: this,
    );

    _discoveryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _setupAnimations();
    _startScanning();
  }

  void _setupAnimations() {
    // Scanning line moving from top to bottom
    _scanPosition = Tween<double>(
      begin: -0.1,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    // Grid overlay that appears during scan
    _gridOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.6), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 0.6), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 0.0), weight: 20),
    ]).animate(_gridController);

    // Creature becomes translucent during scan
    _creatureOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.4), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 0.4), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.0), weight: 30),
    ]).animate(_scanController);

    // Discovery flash effect
    _discoveryFlash = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_discoveryController);
  }

  void _startScanning() async {
    print(
      'CreatureScanAnimation: Starting scan with duration ${widget.scanDuration.inMilliseconds}ms',
    );

    // Start the grid and scan simultaneously
    _gridController.forward();
    await _scanController.forward();

    print('CreatureScanAnimation: Scan line complete');

    // If it's a new discovery, show the flash
    if (widget.isNewDiscovery) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _discoveryController.forward();
      print('CreatureScanAnimation: Discovery flash complete');
    }

    // Callback when scan is done
    widget.onScanComplete?.call();
    print('CreatureScanAnimation: All animations complete');
  }

  @override
  void dispose() {
    _scanController.dispose();
    _gridController.dispose();
    _discoveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scanController,
        _gridController,
        _discoveryController,
      ]),
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Main creature with opacity effect - centered and full size
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

                // Holographic grid overlay
                if (_gridOpacity.value > 0)
                  Positioned.fill(
                    child: Opacity(
                      opacity: _gridOpacity.value,
                      child: CustomPaint(painter: HolographicGridPainter()),
                    ),
                  ),

                // Scanning line
                if (_scanController.isAnimating)
                  Positioned(
                    top:
                        (_scanPosition.value * (constraints.maxHeight - 20)) +
                        10, // Starts 10px from top, ends 10px from bottom
                    left: 1, // Inset from left
                    right: 1, // Inset from right
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

                // Corner scanning brackets
                if (_scanController.isAnimating || _gridController.isAnimating)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ScanningBracketsPainter(
                        progress: _scanController.value,
                      ),
                    ),
                  ),

                // New discovery flash overlay
                if (widget.isNewDiscovery && _discoveryController.isAnimating)
                  Positioned(
                    top:
                        -(constraints.maxHeight *
                            0.12), // Proportional to container height
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NEW CREATURE DISCOVERED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class HolographicGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.shade400.withOpacity(0.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final gridSize = 20.0;

    // Draw vertical lines
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw wireframe border
    final borderPaint = Paint()
      ..color = Colors.cyan.shade400.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanningBracketsPainter extends CustomPainter {
  final double progress;

  ScanningBracketsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.shade400.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bracketSize = 20.0;
    final animatedSize = bracketSize * progress;

    // Top-left bracket
    canvas.drawLine(Offset(0, animatedSize), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(animatedSize, 0), paint);

    // Top-right bracket
    canvas.drawLine(
      Offset(size.width - animatedSize, 0),
      Offset(size.width, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, animatedSize),
      paint,
    );

    // Bottom-left bracket
    canvas.drawLine(
      Offset(0, size.height - animatedSize),
      Offset(0, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(animatedSize, size.height),
      paint,
    );

    // Bottom-right bracket
    canvas.drawLine(
      Offset(size.width - animatedSize, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - animatedSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
