// screens/breed/breed_screen.dart
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/breed/breed_tab.dart';
import 'package:alchemons/screens/breed/nursery_tab.dart';
import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/nav_bar.dart';
import 'package:alchemons/widgets/starter_granted_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _BreedMode { cultivations, fusion }

class BreedScreen extends StatefulWidget {
  const BreedScreen({
    super.key,
    this.title = 'Alchemons',
    this.onGoToSection,
    this.isActive = false,
  });
  final String title;
  final ValueChanged<NavSection>? onGoToSection;
  final bool isActive;

  @override
  State<BreedScreen> createState() => _BreedScreenState();
}

class _BreedScreenState extends State<BreedScreen> {
  _BreedMode _mode = _BreedMode.cultivations;
  bool _coldStorageIntroCheckInFlight = false;

  @override
  void initState() {
    super.initState();
    _maybeShowColdStorageIntroIfEligible();
  }

  @override
  void didUpdateWidget(covariant BreedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _maybeShowColdStorageIntroIfEligible();
    }
  }

  void _goCreatureScreen() {
    widget.onGoToSection?.call(NavSection.creatures);
  }

  void _setMode(_BreedMode next) {
    if (_mode == next) return;
    setState(() => _mode = next);
  }

  void _toggleMode() {
    _setMode(
      _mode == _BreedMode.cultivations
          ? _BreedMode.fusion
          : _BreedMode.cultivations,
    );
  }

  void _maybeShowColdStorageIntroIfEligible() {
    if (!mounted || !widget.isActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeShowColdStorageIntro();
    });
  }

  Future<void> _maybeShowColdStorageIntro() async {
    if (_coldStorageIntroCheckInFlight) return;
    _coldStorageIntroCheckInFlight = true;

    final db = context.read<AlchemonsDatabase>();
    try {
      final seen = await db.settingsDao.getSetting(
        ColdStorageService.introSeenSettingKey,
      );
      if (seen == '1' ||
          !mounted ||
          !widget.isActive ||
          _mode != _BreedMode.cultivations) {
        return;
      }

      final storedEggs = await db.incubatorDao.watchInventory().first;
      if (!mounted ||
          !widget.isActive ||
          _mode != _BreedMode.cultivations ||
          storedEggs.isEmpty) {
        return;
      }

      final theme = context.read<FactionTheme>();
      final t = ForgeTokens(theme);
      final dialogSurface = theme.isDark ? t.bg1 : Colors.white;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: dialogSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: t.borderAccent, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cold Storage',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cold storage still cultivates your vials, but at a 5x slower pace. An 8 hour cultivation becomes 40 hours while stored, and moving a vial back to a chamber resumes its active cultivation time.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        color: t.amberBright,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted) return;
      await db.settingsDao.setSetting(
        ColdStorageService.introSeenSettingKey,
        '1',
      );
    } finally {
      _coldStorageIntroCheckInFlight = false;
    }
  }

  Future<void> _handleExtractionComplete() async {
    final db = context.read<AlchemonsDatabase>();
    final firstDone =
        await db.settingsDao.getSetting('first_extraction_done') == '1';

    if (!firstDone && mounted) {
      final story = context.read<StoryManager>();
      story.trigger(StoryEvent.firstBreeding);
      final pages = story.drainQueue();

      if (pages.isNotEmpty) {
        await SystemDialog.playStory(context, pages);
      }

      await db.settingsDao.setSetting('first_extraction_done', '1');
      await db.settingsDao.deleteSetting('tutorial_extraction_pending');
      await db.settingsDao.setNavLocked(false);

      _goCreatureScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: withGameData(
        context,
        loadingBuilder: buildLoadingScreen,
        builder:
            (
              context, {
              required theme,
              required catalog,
              required entries,
              required discovered,
            }) {
              final isCultivations = _mode == _BreedMode.cultivations;
              return ParticleBackgroundScaffold(
                whiteBackground: theme.brightness == Brightness.light,
                body: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: _FuseModeToggle(
                            theme: theme,
                            mode: _mode,
                            onTap: _toggleMode,
                          ),
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: isCultivations ? 0 : 1,
                            sizing: StackFit.expand,
                            children: [
                              TickerMode(
                                enabled: isCultivations,
                                child: NurseryTab(
                                  maxSeenNowUtc: DateTime.now().toUtc(),
                                  onHatchComplete: _handleExtractionComplete,
                                  onRequestAddEgg: () =>
                                      _setMode(_BreedMode.fusion),
                                  onRequestFusion: () =>
                                      _setMode(_BreedMode.fusion),
                                ),
                              ),
                              TickerMode(
                                enabled: !isCultivations,
                                child: BreedingTab(
                                  discoveredCreatures: entries,
                                  onBreedingComplete: _noop,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
      ),
    );
  }
}

void _noop() {}

// ─────────────────────────────────────────────────────────────────────────────
// FUSE MODE TOGGLE — animated primary CTA that swaps between modes
// ─────────────────────────────────────────────────────────────────────────────

class _FuseModeToggle extends StatefulWidget {
  const _FuseModeToggle({
    required this.theme,
    required this.mode,
    required this.onTap,
  });

  final FactionTheme theme;
  final _BreedMode mode;
  final VoidCallback onTap;

  @override
  State<_FuseModeToggle> createState() => _FuseModeToggleState();
}

class _FuseModeToggleState extends State<_FuseModeToggle>
    with TickerProviderStateMixin {
  late final AnimationController _sigilSpin;
  late final AnimationController _sigilCounter;
  late final AnimationController _press;
  late final AnimationController _ignite;

  @override
  void initState() {
    super.initState();
    _sigilSpin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _sigilCounter = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _ignite = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _sigilSpin.dispose();
    _sigilCounter.dispose();
    _press.dispose();
    _ignite.dispose();
    super.dispose();
  }

  void _handleTap() {
    _ignite.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    final isFusionPrompt = widget.mode == _BreedMode.cultivations;

    final hotA = t.amberBright;
    final hotB = t.amberGlow;
    final coolA = t.teal;
    final coolB = Color.lerp(t.teal, Colors.white, 0.18) ?? t.teal;

    final gradColors = isFusionPrompt ? [hotA, hotB] : [coolA, coolB];
    final accent = isFusionPrompt ? hotA : coolA;
    final onColor = t.onColor(gradColors.first);

    final label = isFusionPrompt ? 'FUSE ALCHEMONS' : 'VIEW CULTIVATIONS';
    final Widget iconWidget = isFusionPrompt
        ? _AlchemyHexagramIcon(
            key: const ValueKey('icon-hex'),
            color: onColor,
            size: 20,
          )
        : Icon(
            Icons.science_rounded,
            key: const ValueKey('icon-science'),
            color: onColor,
            size: 18,
          );

    final radius = BorderRadius.circular(6);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _sigilSpin,
        _sigilCounter,
        _press,
        _ignite,
      ]),
      builder: (context, _) {
        final pressed = _press.value;
        final ignite = _ignite.value;
        final scale = 1 - (pressed * 0.025);

        return GestureDetector(
          onTapDown: (_) => _press.forward(),
          onTapCancel: () => _press.reverse(),
          onTapUp: (_) => _press.reverse(),
          onTap: _handleTap,
          child: Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradColors,
                ),
                border: Border.all(
                  color: accent.withValues(alpha: .65),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    // Background alchemy sigil — wide, very faint, slow rotation
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _AlchemySigilPainter(
                          rotation: _sigilSpin.value * 2 * 3.1415926,
                          counterRotation:
                              -_sigilCounter.value * 2 * 3.1415926,
                          color: onColor,
                          igniteProgress: ignite,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          _AlchemyIconCrest(
                            color: onColor,
                            ringRotation: _sigilSpin.value * 2 * 3.1415926,
                            igniteProgress: ignite,
                            child: iconWidget,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) {
                                final slide = Tween<Offset>(
                                  begin: const Offset(0, 0.4),
                                  end: Offset.zero,
                                ).animate(anim);
                                return ClipRect(
                                  child: SlideTransition(
                                    position: slide,
                                    child: FadeTransition(
                                      opacity: anim,
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                label,
                                key: ValueKey(label),
                                style: TextStyle(
                                  color: onColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Opacity(
                            opacity: 0.85,
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: onColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlchemyIconCrest extends StatelessWidget {
  const _AlchemyIconCrest({
    required this.child,
    required this.color,
    required this.ringRotation,
    required this.igniteProgress,
  });

  final Widget child;
  final Color color;
  final double ringRotation;
  final double igniteProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating runic ring behind the icon
          Transform.rotate(
            angle: ringRotation,
            child: CustomPaint(
              size: const Size(38, 38),
              painter: _RuneRingPainter(
                color: color,
                igniteProgress: igniteProgress,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              return ScaleTransition(
                scale: anim,
                child: RotationTransition(
                  turns: Tween<double>(begin: -0.25, end: 0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
              );
            },
            child: child,
          ),
        ],
      ),
    );
  }
}

// Custom hexagram (Star of Solomon) — two overlapping triangles, the
// classic alchemical symbol for the union of opposites.
class _AlchemyHexagramIcon extends StatelessWidget {
  const _AlchemyHexagramIcon({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _HexagramPainter(color: color),
    );
  }
}

class _HexagramPainter extends CustomPainter {
  _HexagramPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    Path triangle(double rotationOffset) {
      final path = Path();
      for (int i = 0; i < 3; i++) {
        final a = (i / 3) * 2 * math.pi + rotationOffset;
        final p = center + Offset(r * math.cos(a), r * math.sin(a));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      return path;
    }

    // Upward triangle
    canvas.drawPath(triangle(-math.pi / 2), stroke);
    // Downward triangle
    canvas.drawPath(triangle(math.pi / 2), stroke);

    // Small center dot — the "quintessence"
    canvas.drawCircle(
      center,
      1.4,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_HexagramPainter old) => old.color != color;
}

// Faint, wide alchemy sigil that fills the button background.
// Two concentric circles + tick marks + an inscribed triangle, rotating slowly.
class _AlchemySigilPainter extends CustomPainter {
  _AlchemySigilPainter({
    required this.rotation,
    required this.counterRotation,
    required this.color,
    required this.igniteProgress,
  });

  final double rotation;
  final double counterRotation;
  final Color color;
  final double igniteProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.height * 0.95;

    final baseAlpha = 0.10 + (igniteProgress * 0.18);
    final paint = Paint()
      ..color = color.withValues(alpha: baseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Outer circle (slow rotation reference — circles look the same rotated,
    // but tick marks below rely on the same transform).
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    canvas.drawCircle(Offset.zero, maxR, paint);
    canvas.drawCircle(Offset.zero, maxR * 0.78, paint);

    // 12 tick marks between the two circles
    const ticks = 12;
    for (int i = 0; i < ticks; i++) {
      final a = (i / ticks) * 2 * 3.1415926;
      final p1 = Offset(maxR * 0.78 * math.cos(a), maxR * 0.78 * math.sin(a));
      final p2 = Offset(maxR * math.cos(a), maxR * math.sin(a));
      canvas.drawLine(p1, p2, paint);
    }
    canvas.restore();

    // Counter-rotating inscribed triangle (alchemy "fire" / "water" feel)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(counterRotation);
    final triR = maxR * 0.62;
    final tri = Path();
    for (int i = 0; i < 3; i++) {
      final a = (i / 3) * 2 * 3.1415926 - 3.1415926 / 2;
      final p = Offset(triR * math.cos(a), triR * math.sin(a));
      if (i == 0) {
        tri.moveTo(p.dx, p.dy);
      } else {
        tri.lineTo(p.dx, p.dy);
      }
    }
    tri.close();
    canvas.drawPath(
      tri,
      Paint()
        ..color = color.withValues(alpha: baseAlpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.restore();

    // Ignite ripple — expanding ring on tap
    if (igniteProgress > 0 && igniteProgress < 1) {
      final ripplePaint = Paint()
        ..color = color.withValues(alpha: (1 - igniteProgress) * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final r = maxR * (0.4 + igniteProgress * 1.1);
      canvas.drawCircle(center, r, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(_AlchemySigilPainter old) =>
      old.rotation != rotation ||
      old.counterRotation != counterRotation ||
      old.color != color ||
      old.igniteProgress != igniteProgress;
}

// Small runic ring around the icon — concentric circle with short tick dashes.
class _RuneRingPainter extends CustomPainter {
  _RuneRingPainter({required this.color, required this.igniteProgress});

  final Color color;
  final double igniteProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;

    final alpha = 0.55 + (igniteProgress * 0.35);
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawCircle(center, r, paint);

    // 8 short dashes outside the circle
    const dashes = 8;
    final dashPaint = Paint()
      ..color = color.withValues(alpha: alpha * 0.9)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < dashes; i++) {
      final a = (i / dashes) * 2 * 3.1415926;
      final p1 = center + Offset((r + 1) * math.cos(a), (r + 1) * math.sin(a));
      final p2 =
          center + Offset((r + 4) * math.cos(a), (r + 4) * math.sin(a));
      canvas.drawLine(p1, p2, dashPaint);
    }
  }

  @override
  bool shouldRepaint(_RuneRingPainter old) =>
      old.color != color || old.igniteProgress != igniteProgress;
}
