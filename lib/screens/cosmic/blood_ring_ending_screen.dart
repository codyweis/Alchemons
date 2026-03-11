import 'dart:async';
import 'dart:math';

import 'package:alchemons/providers/audio_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class BloodRitualFlashPage extends StatefulWidget {
  const BloodRitualFlashPage({
    super.key,
    this.duration = const Duration(seconds: 5),
  });

  final Duration duration;

  @override
  State<BloodRitualFlashPage> createState() => _BloodRitualFlashPageState();
}

class _BloodRitualFlashPageState extends State<BloodRitualFlashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward().whenComplete(() {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value.clamp(0.0, 1.0);
          final pulse = 0.7 + 0.3 * sin(t * pi * 16);
          final ringScale = 0.85 + 0.15 * sin(t * pi * 8);
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black.withValues(alpha: 0.95)),
              Center(
                child: Transform.scale(
                  scale: ringScale,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF6E6E).withValues(alpha: 0.95),
                        width: 7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFB71C1C,
                          ).withValues(alpha: 0.45 * pulse),
                          blurRadius: 48,
                          spreadRadius: 18,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF200000,
                          ).withValues(alpha: 0.88),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFFFCDD2,
                              ).withValues(alpha: 0.35 * pulse),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 96,
                left: 24,
                right: 24,
                child: Text(
                  'THE BLOOD RING AWAKENS',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFFFCDD2),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 2.3,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BloodRingStoryScenePage extends StatefulWidget {
  const BloodRingStoryScenePage({
    super.key,
    required this.mysticName,
    required this.favoriteName,
  });

  final String mysticName;
  final String favoriteName;

  @override
  State<BloodRingStoryScenePage> createState() =>
      _BloodRingStoryScenePageState();
}

class _BloodRingStoryScenePageState extends State<BloodRingStoryScenePage>
    with TickerProviderStateMixin {
  int _index = 0;
  late final List<String> _pages;
  late final AnimationController _fade;
  late final AnimationController _introFade;
  late final Animation<double> _introOpacity;
  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    _pages = [
      'Whether you accept reality for the beauty it is, or forge deceptions of beauty to shield yourself from chaos, the ring does not care.',
      'Reality bends to the witness and the wound at once. What you call truth is only a story that survived long enough to be believed.',
      '${widget.mysticName} and ${widget.favoriteName} stand at the seam of worlds, where every certainty dissolves into choice.',
      'If all things are constructs, then this construct is yours now. Walk forward.',
    ];
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _introFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
      value: 0.0,
    );
    _introOpacity = CurvedAnimation(
      parent: _introFade,
      curve: Curves.easeInOutCubic,
    );
    Future<void>.delayed(const Duration(milliseconds: 1100), () async {
      if (!mounted || _index != 0) return;
      await _introFade.forward();
      if (mounted) setState(() => _introDone = true);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _introFade.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index >= _pages.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    await _fade.reverse();
    if (!mounted) return;
    setState(() => _index++);
    await _fade.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            if (_index == 0 && !_introDone) return;
            _next();
          },
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [Color(0xFF240606), Color(0xFF050505)],
                  ),
                ),
              ),
              Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: FadeTransition(
                    opacity: _index == 0
                        ? _introOpacity
                        : const AlwaysStoppedAnimation<double>(1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        _pages[_index],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.crimsonText(
                          color: const Color(0xFFFFEBEE),
                          fontSize: 28,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  opacity: (_index == 0 && !_introDone) ? 0.0 : 1.0,
                  child: Text(
                    _index == _pages.length - 1
                        ? 'Tap to continue'
                        : 'Tap to advance',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BloodRingPortalPlaceholderPage extends StatelessWidget {
  const BloodRingPortalPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_esports,
                  color: Color(0xFFFF8A80),
                  size: 54,
                ),
                const SizedBox(height: 14),
                Text(
                  'BLOOD PORTAL',
                  style: GoogleFonts.cinzel(
                    color: const Color(0xFFFFCDD2),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Flappy-style mini game portal coming soon.\nAlchemon selection will be added here next.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.crimsonText(
                    color: Colors.white70,
                    fontSize: 20,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Space'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ValleyFinalePhase { credits, approach, sacrifice }

class BloodRingValleyCreditsPage extends StatefulWidget {
  const BloodRingValleyCreditsPage({
    super.key,
    required this.mysticName,
    required this.favoriteName,
    this.mysticImagePath,
    this.offeringImagePath,
  });

  final String mysticName;
  final String favoriteName;
  final String? mysticImagePath;
  final String? offeringImagePath;

  @override
  State<BloodRingValleyCreditsPage> createState() =>
      _BloodRingValleyCreditsPageState();
}

class _BloodRingValleyCreditsPageState extends State<BloodRingValleyCreditsPage>
    with SingleTickerProviderStateMixin {
  static const String _bloodMysticSpritePath =
      'creatures/mystic/MYS17_bloodmystic_spritesheet.png';
  static const double _gravity = 980.0;
  static const double _jumpVelocity = -430.0;
  static const double _creditLineSpeed = 170.0;
  static const double _creditLineDelay = 3.4;
  static const double _playerStartX = 0.24;
  static const double _mysticX = 0.90;
  static const double _approachSpeed = 0.11;
  static const double _stopDistance = 0.19;
  static const double _sacrificeDuration = 3.2;
  static const double _mysticRevealDuration = 1.25;
  static const double _maxJumpLift = -220.0;

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _started = false;
  bool _finishing = false;
  _ValleyFinalePhase _phase = _ValleyFinalePhase.credits;
  double _scrollTime = 0;
  double _playerVy = 0;
  double _jumpOffset = 0;
  double _playerX = _playerStartX;
  double _creditsElapsed = 0;
  double _mysticRevealElapsed = 0;
  double _sacrificeElapsed = 0;
  double _viewportW = 0;
  double _viewportH = 0;
  bool _creditsReady = false;
  late final List<_CreditLineFxState> _lineFx;
  late final List<int> _creditRenderIndices;
  late final Map<int, int> _creditRenderOrder;

  List<String> get _creditLines => [
    'ALCHEMONS',
    'A BLOOD RING FINALE',
    'Design: Placeholder Name',
    'Story: Placeholder Name',
    'Code: Placeholder Name',
    'Art + Audio: Placeholder Name',
    'Starring: ${widget.mysticName} and ${widget.favoriteName}',
    'Thank you for playing.',
  ];

  @override
  void initState() {
    super.initState();
    _lineFx = _creditLines.map(_CreditLineFxState.new).toList();
    _creditRenderIndices = [
      for (var i = 0; i < _creditLines.length; i++)
        if (_creditLines[i].isNotEmpty) i,
    ];
    _creditRenderOrder = <int, int>{
      for (var i = 0; i < _creditRenderIndices.length; i++)
        _creditRenderIndices[i]: i,
    };
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AudioController>().playEndCreditsMusic());
    });
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    if (!mounted || dt <= 0 || !_creditsReady) return;

    if (_phase == _ValleyFinalePhase.sacrifice) {
      final slowT = _c01(_sacrificeElapsed / 1.5);
      final scrollMul = 1.0 - (0.82 * Curves.easeOut.transform(slowT));
      _scrollTime += dt * scrollMul;
    } else {
      _scrollTime += dt;
    }

    if (_phase != _ValleyFinalePhase.sacrifice) {
      _playerVy += _gravity * dt;
      _jumpOffset += _playerVy * dt;
      if (_jumpOffset < _maxJumpLift) {
        _jumpOffset = _maxJumpLift;
        if (_playerVy < -80) _playerVy = -80;
      }
      if (_jumpOffset > 0) {
        _jumpOffset = 0;
        _playerVy = 0;
      }
    } else {
      _jumpOffset += (0 - _jumpOffset) * min(1.0, dt * 8.0);
      _playerVy = 0;
      if (_jumpOffset.abs() < 0.2) _jumpOffset = 0;
    }

    if (_phase == _ValleyFinalePhase.credits) {
      _creditsElapsed += dt;
      _updateLetterPhysics(dt);
      _handleCreditCollisions();
      final lastIdx = _creditRenderIndices.last;
      final lastWidth = _estimateLineWidth(_creditLines[lastIdx], _viewportW);
      final lastRight =
          _creditLineX(lastIdx, lastWidth, _viewportW) + lastWidth;
      if (lastRight < -40) {
        _phase = _ValleyFinalePhase.approach;
        _mysticRevealElapsed = 0;
      }
    } else if (_phase == _ValleyFinalePhase.approach) {
      _mysticRevealElapsed += dt;
      _playerX += _approachSpeed * dt;
      if (_playerX >= _mysticX - _stopDistance) {
        _playerX = _mysticX - _stopDistance;
        _phase = _ValleyFinalePhase.sacrifice;
        _sacrificeElapsed = 0;
        _playerVy = 0;
      }
    } else if (_phase == _ValleyFinalePhase.sacrifice) {
      _mysticRevealElapsed += dt;
      _sacrificeElapsed += dt;
      if (!_finishing && _sacrificeElapsed >= _sacrificeDuration) {
        _finishing = true;
        Future<void>.delayed(const Duration(milliseconds: 420), () {
          if (!mounted) return;
          Navigator.of(context).pop(true);
        });
      }
    }

    setState(() {});
  }

  void _jump() {
    if (_phase == _ValleyFinalePhase.sacrifice) return;
    _playerVy = (_playerVy + _jumpVelocity).clamp(-740.0, 4800.0);
  }

  double _c01(double value) => value.clamp(0.0, 1.0).toDouble();

  void _updateLetterPhysics(double dt) {
    for (final fx in _lineFx) {
      if (fx.shake > 0) {
        fx.shake = max(0.0, fx.shake - (dt * 3.2));
      }
      for (var i = 0; i < fx.letterDrops.length; i++) {
        final vy = fx.letterVys[i];
        final drop = fx.letterDrops[i];
        if (vy == 0 && drop == 0) continue;
        final nextVy = vy + (980.0 * dt);
        final nextDrop = min(180.0, drop + (nextVy * dt));
        fx.letterVys[i] = nextDrop >= 180.0 ? 0 : nextVy;
        fx.letterDrops[i] = nextDrop;
      }
    }
  }

  void _handleCreditCollisions() {
    if (_viewportW <= 0 || _viewportH <= 0 || _playerVy <= 0) return;
    final groundY = _viewportH * 0.88;
    const playerSize = 82.0;
    final playerLeft = (_viewportW * _playerX).clamp(
      0.0,
      _viewportW - playerSize,
    );
    final playerTop = (groundY - playerSize + _jumpOffset).clamp(
      0.0,
      _viewportH - playerSize,
    );
    final playerBottom = playerTop + playerSize;
    final playerCenterX = playerLeft + (playerSize * 0.5);
    final basePlayerTop = groundY - playerSize;

    for (final i in _creditRenderIndices) {
      if (_lineFx[i].hit) continue;
      final line = _creditLines[i];
      final lineTop = _creditLineTop(i, _viewportH);
      if (lineTop < -50 || lineTop > _viewportH + 80) continue;

      final lineWidth = _estimateLineWidth(line, _viewportW);
      final lineX = _creditLineX(i, lineWidth, _viewportW);
      final inX = playerCenterX >= lineX && playerCenterX <= lineX + lineWidth;
      final inY =
          playerBottom >= (lineTop - 8) && playerBottom <= (lineTop + 20);
      if (!inX || !inY) continue;

      final snappedTop = lineTop - playerSize + 2;
      _jumpOffset = (snappedTop - basePlayerTop).clamp(_maxJumpLift, 0.0);
      _playerVy = -290.0;
      _triggerLetterCollision(i);
      break;
    }
  }

  double _estimateLineWidth(String line, double viewportWidth) {
    final isTitle = line == 'ALCHEMONS';
    final fontSize = isTitle ? 24.0 : 16.0;
    final charWidth = fontSize * 0.62;
    return min(viewportWidth * 0.86, (line.length * charWidth) + 30.0);
  }

  double _creditLineX(int index, double lineWidth, double viewportWidth) {
    final order = _creditRenderOrder[index] ?? 0;
    final elapsed = _creditsElapsed - (order * _creditLineDelay);
    final startX = viewportWidth + 24;
    return startX - max(0.0, elapsed * _creditLineSpeed);
  }

  double _creditLineTop(int index, double viewportHeight) {
    const lanes = [0.42, 0.58, 0.74];
    final order = _creditRenderOrder[index] ?? 0;
    final lane = lanes[order % lanes.length];
    return viewportHeight * lane;
  }

  Widget _buildCreditLine(int index, double viewportWidth) {
    final line = _creditLines[index];
    final fx = _lineFx[index];
    final isTitle = line == 'ALCHEMONS';
    final style = GoogleFonts.cinzel(
      color: Colors.white,
      fontSize: isTitle ? 24 : 16,
      fontWeight: isTitle ? FontWeight.w800 : FontWeight.w500,
      letterSpacing: 1.1,
    );

    final lineWidth = _estimateLineWidth(line, viewportWidth);
    return SizedBox(
      width: lineWidth,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < line.length; i++)
            Transform.translate(
              offset: Offset(
                0,
                fx.letterDrops[i] +
                    (sin((_scrollTime * 42) + i) * 3.0 * fx.shake),
              ),
              child: Text(line[i], style: style),
            ),
        ],
      ),
    );
  }

  void _triggerLetterCollision(int index) {
    final fx = _lineFx[index];
    if (fx.hit) return;
    fx.hit = true;
    fx.shake = 1.0;
    final rng = Random(1009 + (index * 7919));
    for (var i = 0; i < fx.line.length; i++) {
      if (fx.line[i] == ' ') continue;
      fx.letterVys[i] = 80 + (rng.nextDouble() * 190);
      fx.letterDrops[i] = 0;
    }
  }

  Widget _layer({
    required double tileWidth,
    required String assetPath,
    required double speed,
    BoxFit fit = BoxFit.fill,
  }) {
    final loopOffset = (_scrollTime * speed * tileWidth) % tileWidth;
    final startX = -loopOffset - tileWidth;
    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          children: List.generate(6, (i) {
            final x = (startX + i * tileWidth).floorToDouble();
            return Positioned(
              left: x,
              top: 0,
              // Slight overlap prevents single-pixel cracks during animation.
              width: tileWidth + 1,
              bottom: 0,
              child: Image.asset(
                assetPath,
                fit: fit,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          _viewportW = w;
          _viewportH = h;
          if (!_started) {
            _started = true;
            _creditsElapsed = 0;
            _mysticRevealElapsed = 0;
            _playerX = _playerStartX;
            _creditsReady = true;
          }

          final isSacrifice = _phase == _ValleyFinalePhase.sacrifice;
          final shouldShowMystic = _phase != _ValleyFinalePhase.credits;
          final groundY = h * 0.88;
          const playerSize = 82.0;
          const mysticSize = 240.0;
          final playerTop = (groundY - playerSize + _jumpOffset).clamp(
            0.0,
            h - playerSize,
          );
          final playerLeft = (w * _playerX).clamp(0.0, w - playerSize);

          final mysticIdleBob = sin(_scrollTime * 3.2) * 2.6;
          final mysticPulse = 0.9 + 0.1 * sin(_scrollTime * 6.0);
          final mysticBaseTop = (groundY - mysticSize + mysticIdleBob).clamp(
            0.0,
            h - mysticSize,
          );

          var mysticLunge = 0.0;
          var playerOpacity = 1.0;
          var playerScale = 1.0;
          var redOverlayAlpha = 0.0;
          var burstSize = 0.0;
          var burstAlpha = 0.0;
          var flashAlpha = 0.0;
          var sigilAlpha = 0.0;
          var sigilScale = 1.0;
          var sigilRotation = 0.0;
          var cameraShakeX = 0.0;
          var cameraShakeY = 0.0;
          var vignetteAlpha = 0.0;
          var tetherAlpha = 0.0;
          if (isSacrifice) {
            final t = _sacrificeElapsed;
            final strike = Curves.easeOutCubic.transform(_c01(t / 0.5));
            final recover = Curves.easeInOut.transform(_c01((t - 0.5) / 0.65));
            mysticLunge = (strike - recover) * 112.0;

            final fadeT = _c01((t - 0.52) / 1.08);
            playerOpacity = 1.0 - Curves.easeInCubic.transform(fadeT);
            playerScale = 1.0 - (0.36 * Curves.easeInOut.transform(fadeT));

            final redT = _c01((t - 0.24) / 1.45);
            redOverlayAlpha = 0.88 * Curves.easeIn.transform(redT);

            final burstT = _c01((t - 0.34) / 1.1);
            burstSize = 90 + (420 * Curves.easeOut.transform(burstT));
            burstAlpha = (1.0 - burstT) * 0.82;

            final flashCore = 1.0 - (((t - 0.42).abs()) / 0.09);
            flashAlpha = 0.72 * _c01(flashCore);

            final sigilIn = Curves.easeOut.transform(_c01((t - 0.2) / 0.55));
            final sigilOut = 1.0 - _c01((t - 1.5) / 1.1);
            sigilAlpha = 0.72 * sigilIn * sigilOut;
            sigilScale =
                0.72 +
                (1.35 * Curves.easeOut.transform(_c01((t - 0.16) / 1.1)));
            sigilRotation = t * 4.8;

            final shakeIn = _c01((t - 0.34) / 0.08);
            final shakeOut = 1.0 - _c01((t - 1.4) / 0.8);
            final shakeAmp = 9.0 * shakeIn * shakeOut;
            cameraShakeX = sin(t * 110.0) * shakeAmp;
            cameraShakeY = cos(t * 97.0) * shakeAmp * 0.58;

            vignetteAlpha =
                0.66 * Curves.easeIn.transform(_c01((t - 0.48) / 1.35));
            tetherAlpha =
                0.9 *
                Curves.easeIn.transform(_c01((t - 0.28) / 0.45)) *
                (1.0 - _c01((t - 1.38) / 0.6));
          }
          final mysticTargetLeft = ((w * _mysticX) - mysticLunge).clamp(
            0.0,
            w - mysticSize,
          );
          final revealT = Curves.easeOutCubic.transform(
            _c01(_mysticRevealElapsed / _mysticRevealDuration),
          );
          final mysticSlideOffset = (1 - revealT) * (mysticSize + 160);
          final mysticLeft = mysticTargetLeft + mysticSlideOffset;
          final playerCenterX = playerLeft + (playerSize * 0.5);
          final playerCenterY = playerTop + (playerSize * 0.5);
          final mysticCenterX = mysticLeft + (mysticSize * 0.32);
          final mysticCenterY = mysticBaseTop + (mysticSize * 0.52);
          final tetherDx = playerCenterX - mysticCenterX;
          final tetherDy = playerCenterY - mysticCenterY;
          final tetherLen = sqrt((tetherDx * tetherDx) + (tetherDy * tetherDy));
          final tetherAngle = atan2(tetherDy, tetherDx);

          return GestureDetector(
            onTap: _jump,
            behavior: HitTestBehavior.opaque,
            child: Transform.translate(
              offset: Offset(cameraShakeX, cameraShakeY),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _layer(
                    tileWidth: w,
                    assetPath:
                        'assets/images/backgrounds/scenes/valley/sky.png',
                    speed: 0.03,
                  ),
                  _layer(
                    tileWidth: w,
                    assetPath:
                        'assets/images/backgrounds/scenes/valley/clouds.png',
                    speed: 0.06,
                  ),
                  _layer(
                    tileWidth: w,
                    assetPath:
                        'assets/images/backgrounds/scenes/valley/backhills.png',
                    speed: 0.11,
                  ),
                  _layer(
                    tileWidth: w,
                    assetPath:
                        'assets/images/backgrounds/scenes/valley/hills.png',
                    speed: 0.22,
                  ),
                  _layer(
                    tileWidth: w,
                    assetPath:
                        'assets/images/backgrounds/scenes/valley/foreground.png',
                    speed: 0.33,
                  ),
                  Positioned(
                    left: playerLeft,
                    top: playerTop,
                    width: playerSize,
                    height: playerSize,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: playerOpacity,
                        child: Transform.scale(
                          scale: playerScale,
                          child: _PlayerAvatar(
                            imagePath: widget.offeringImagePath,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (shouldShowMystic)
                    Positioned(
                      left: mysticLeft,
                      top: mysticBaseTop,
                      width: mysticSize,
                      height: mysticSize,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: (0.82 + (0.18 * mysticPulse)).clamp(
                            0.0,
                            1.0,
                          ),
                          child: const _BloodMysticSprite(flipX: true),
                        ),
                      ),
                    ),
                  if (_phase == _ValleyFinalePhase.credits)
                    for (final i in _creditRenderIndices)
                      Positioned(
                        left: _creditLineX(
                          i,
                          _estimateLineWidth(_creditLines[i], w),
                          w,
                        ),
                        top: _creditLineTop(i, h),
                        child: IgnorePointer(child: _buildCreditLine(i, w)),
                      ),
                  if (isSacrifice && tetherAlpha > 0.001)
                    Positioned(
                      left: mysticCenterX,
                      top: mysticCenterY - 2,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: tetherAngle,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: tetherLen,
                            height: 4.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFFFFCDD2,
                                  ).withValues(alpha: 0.0),
                                  const Color(
                                    0xFFFF5D73,
                                  ).withValues(alpha: tetherAlpha * 0.95),
                                  const Color(
                                    0xFFFF1744,
                                  ).withValues(alpha: tetherAlpha * 0.88),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFE53935,
                                  ).withValues(alpha: tetherAlpha * 0.68),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isSacrifice && burstAlpha > 0.001)
                    Positioned(
                      left: playerCenterX - (burstSize * 0.5),
                      top: playerCenterY - (burstSize * 0.5),
                      width: burstSize,
                      height: burstSize,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFFFF9AA2,
                              ).withValues(alpha: burstAlpha),
                              width: 3.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFE53935,
                                ).withValues(alpha: burstAlpha * 0.7),
                                blurRadius: 26,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (isSacrifice && sigilAlpha > 0.001)
                    Positioned(
                      left: playerCenterX - (burstSize * 0.3),
                      top: playerCenterY - (burstSize * 0.3),
                      width: burstSize * 0.6,
                      height: burstSize * 0.6,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: sigilRotation,
                          child: Transform.scale(
                            scale: sigilScale,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFFFF8A80,
                                  ).withValues(alpha: sigilAlpha),
                                  width: 2.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFB71C1C,
                                    ).withValues(alpha: sigilAlpha * 0.86),
                                    blurRadius: 28,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isSacrifice && flashAlpha > 0.001)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: const Color(
                            0xFFFFEBEE,
                          ).withValues(alpha: flashAlpha),
                        ),
                      ),
                    ),
                  if (isSacrifice)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          color: const Color(
                            0xFF8E0000,
                          ).withValues(alpha: redOverlayAlpha),
                        ),
                      ),
                    ),
                  if (isSacrifice && vignetteAlpha > 0.001)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.0,
                              colors: [
                                const Color(0x00000000),
                                const Color(
                                  0xAA120000,
                                ).withValues(alpha: vignetteAlpha),
                              ],
                              stops: const [0.44, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 90,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xAA000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 120,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xDD000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (imagePath != null) {
      child = Image.asset(
        imagePath!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.auto_awesome, color: Colors.white, size: 34),
      );
    } else {
      child = const Icon(Icons.auto_awesome, color: Colors.white, size: 34);
    }

    return child;
  }
}

class _BloodMysticSprite extends StatelessWidget {
  const _BloodMysticSprite({this.flipX = false});

  final bool flipX;

  @override
  Widget build(BuildContext context) {
    Widget sprite = CreatureSprite(
      spritePath: _BloodRingValleyCreditsPageState._bloodMysticSpritePath,
      totalFrames: 4,
      rows: 1,
      frameSize: Vector2(512, 512),
      stepTime: 0.12,
      scale: 1.0,
    );
    if (flipX) {
      sprite = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: sprite,
      );
    }
    return sprite;
  }
}

class _CreditLineFxState {
  _CreditLineFxState(this.line)
    : letterDrops = List<double>.filled(line.length, 0),
      letterVys = List<double>.filled(line.length, 0);

  final String line;
  final List<double> letterDrops;
  final List<double> letterVys;
  bool hit = false;
  double shake = 0;
}
