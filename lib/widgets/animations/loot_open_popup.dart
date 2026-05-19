import 'dart:math';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:provider/provider.dart';

class LootOpeningEntry {
  final IconData icon;
  final String label;
  final String? name;
  final Color color;
  final String? imagePath;
  final Widget Function(double size)? visualBuilder;

  const LootOpeningEntry({
    required this.icon,
    required this.label,
    this.name,
    required this.color,
    this.imagePath,
    this.visualBuilder,
  });
}

Future<void> showLootOpeningDialog({
  required BuildContext context,
  required List<LootOpeningEntry> entries,
  String title = 'REWARDS',
  FactionTheme? theme,
}) async {
  if (entries.isEmpty) return;
  final dialogTheme = theme ?? context.read<FactionTheme>();
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.80),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, __) => Provider<FactionTheme>.value(
      value: dialogTheme,
      child: Theme(
        data: dialogTheme.toMaterialTheme(Theme.of(context).textTheme),
        child: _SleekLootDialog(entries: entries, title: title),
      ),
    ),
  );
}

class _SleekLootDialog extends StatefulWidget {
  final List<LootOpeningEntry> entries;
  final String title;
  const _SleekLootDialog({required this.entries, required this.title});

  @override
  State<_SleekLootDialog> createState() => _SleekLootDialogState();
}

class _SleekLootDialogState extends State<_SleekLootDialog>
    with TickerProviderStateMixin {
  late final AnimationController _lottieCtrl;
  late final List<AnimationController> _rowCtrls;
  late final List<Animation<double>> _rowFade;
  late final List<Animation<Offset>> _rowSlide;
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnFade;

  static const int _lottieDelay = 1200; // ms before items start appearing

  @override
  void initState() {
    super.initState();
    _lottieCtrl = AnimationController(vsync: this);
    _rowCtrls = List.generate(
      widget.entries.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 480),
      ),
    );
    _rowFade = _rowCtrls
        .map(
          (c) => CurvedAnimation(
            parent: c,
            curve: Curves.easeOut,
          ).drive(Tween(begin: 0.0, end: 1.0)),
        )
        .toList();
    _rowSlide = _rowCtrls
        .map(
          (c) => CurvedAnimation(
            parent: c,
            curve: Curves.easeOutCubic,
          ).drive(Tween(begin: const Offset(0, 0.25), end: Offset.zero)),
        )
        .toList();
    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _btnFade = CurvedAnimation(
      parent: _btnCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Lottie is started from onLoaded (see build)
    for (int i = 0; i < _rowCtrls.length; i++) {
      Future.delayed(Duration(milliseconds: _lottieDelay + i * 220), () {
        if (mounted) _rowCtrls[i].forward();
      });
    }
    final btnDelay = _lottieDelay + widget.entries.length * 220 + 160;
    Future.delayed(Duration(milliseconds: btnDelay), () {
      if (mounted) _btnCtrl.forward();
    });
  }

  @override
  void dispose() {
    _lottieCtrl.dispose();
    for (final c in _rowCtrls) {
      c.dispose();
    }
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFAA00);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Loot opening Lottie animation — fill width, unconstrained
              LayoutBuilder(
                builder: (context, constraints) {
                  final size =
                      (constraints.maxWidth * 0.7).clamp(160.0, 360.0);
                  return Center(
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Lottie.asset(
                        'assets/animations/loot-open-safe.json',
                        controller: _lottieCtrl,
                        fit: BoxFit.contain,
                        repeat: false,
                        onLoaded: (comp) {
                          if (!mounted) return;
                          _lottieCtrl.duration = comp.duration;
                          _lottieCtrl.forward();
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: amber,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 5.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: amber.withValues(alpha: 0.25)),
              const SizedBox(height: 12),
              // Survival-parity hint — tells the player the list is
              // interactive without shouting. Matches the small dimmed
              // amber line in cosmic_survival's game-over screen.
              Text(
                'TAP FOR DETAILS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: amber.withValues(alpha: 0.55),
                  fontSize: 9,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              ...List.generate(widget.entries.length, (i) {
                final e = widget.entries[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FadeTransition(
                    opacity: _rowFade[i],
                    child: SlideTransition(
                      position: _rowSlide[i],
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showRewardDetail(context, e),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: e.color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: e.color.withValues(alpha: 0.28),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: e.color.withValues(alpha: 0.14),
                                    border: Border.all(
                                      color: e.color.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: e.imagePath != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.asset(
                                            e.imagePath!,
                                            width: 32,
                                            height: 32,
                                            fit: BoxFit.contain,
                                          ),
                                        )
                                      : e.visualBuilder != null
                                      ? Center(child: e.visualBuilder!(32))
                                      : Icon(e.icon, color: e.color, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (e.name != null)
                                        Text(
                                          e.name!.toUpperCase(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            color: Color(0xFFE8DCC8),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.6,
                                          ),
                                        ),
                                      Text(
                                        e.label,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: e.color,
                                          fontSize: e.name != null ? 18 : 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: e.color.withValues(alpha: 0.5),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _btnFade,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: amber, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: amber.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'COLLECT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFFFFCC44),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Detail modal for a single loot entry. Mirrors the survival
/// game-over screen's reward detail dialog so the two flows feel
/// like the same UI language. Tap the entry, get the rich view.
void _showRewardDetail(BuildContext ctx, LootOpeningEntry entry) {
  showDialog<void>(
    context: ctx,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1117),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: entry.color.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: entry.color.withValues(alpha: 0.18),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.color.withValues(alpha: 0.12),
                border: Border.all(
                  color: entry.color.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: entry.imagePath != null
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        entry.imagePath!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : entry.visualBuilder != null
                  ? Center(child: entry.visualBuilder!(52))
                  : Icon(entry.icon, color: entry.color, size: 34),
            ),
            const SizedBox(height: 18),
            if (entry.name != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  entry.name!.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFE8DCC8),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            Text(
              entry.label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: entry.color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(dialogCtx),
              child: Container(
                width: double.infinity,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: entry.color.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: entry.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
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

class _LootFallbackAnimation extends StatefulWidget {
  const _LootFallbackAnimation();

  @override
  State<_LootFallbackAnimation> createState() => _LootFallbackAnimationState();
}

class _LootFallbackAnimationState extends State<_LootFallbackAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 0.9,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _glow = Tween<double>(
      begin: 0.25,
      end: 0.65,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    fc.amberGlow.withValues(alpha: _glow.value),
                    fc.amberDim.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.15, 0.7, 1.0],
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 52,
                color: fc.amberBright,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KEY ITEM UNLOCK DIALOG
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showKeyItemUnlockDialog({
  required BuildContext context,
  required String itemName,
  required String itemDescription,
  required IconData itemIcon,
  required Color elementColor,
  String?
  itemImagePath, // optional relic PNG — shown instead of icon when provided
  FactionTheme? theme,
}) async {
  final dialogTheme = theme ?? context.read<FactionTheme>();
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(opacity: anim, child: child);
    },
    pageBuilder: (ctx, _, __) => Provider<FactionTheme>.value(
      value: dialogTheme,
      child: Theme(
        data: dialogTheme.toMaterialTheme(Theme.of(context).textTheme),
        child: _KeyItemRevealDialog(
          itemName: itemName,
          itemDescription: itemDescription,
          itemIcon: itemIcon,
          elementColor: elementColor,
          itemImagePath: itemImagePath,
        ),
      ),
    ),
  );
}

class _KeyItemRevealDialog extends StatefulWidget {
  final String itemName;
  final String itemDescription;
  final IconData itemIcon;
  final Color elementColor;
  final String? itemImagePath;

  const _KeyItemRevealDialog({
    required this.itemName,
    required this.itemDescription,
    required this.itemIcon,
    required this.elementColor,
    this.itemImagePath,
  });

  @override
  State<_KeyItemRevealDialog> createState() => _KeyItemRevealDialogState();
}

class _KeyItemRevealDialogState extends State<_KeyItemRevealDialog>
    with TickerProviderStateMixin {
  // Icon entrance
  late final AnimationController _entranceCtrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconGlow;

  // Orbiting sparkles
  late final AnimationController _orbitCtrl;

  // Text fade-in
  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;

  // Button fade-in
  late final AnimationController _btnCtrl;
  late final Animation<double> _btnOpacity;

  // Continuous glow pulse
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _iconScale = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.elasticOut,
    ).drive(Tween(begin: 0.0, end: 1.0));
    _iconGlow = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textOpacity = CurvedAnimation(
      parent: _textCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _btnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _btnOpacity = CurvedAnimation(
      parent: _btnCtrl,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(
      parent: _pulseCtrl,
      curve: Curves.easeInOut,
    ).drive(Tween(begin: 0.7, end: 1.0));

    // Sequence: icon in → text → button
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _entranceCtrl.forward().then((_) {
        if (!mounted) return;
        _textCtrl.forward().then((_) {
          if (!mounted) return;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _btnCtrl.forward();
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _orbitCtrl.dispose();
    _textCtrl.dispose();
    _btnCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final color = widget.elementColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── "KEY ITEM UNLOCKED" header ──────────────────────────────
              FadeTransition(
                opacity: _iconGlow,
                child: Text(
                  'KEY ITEM UNLOCKED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4.0,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ── Icon + orbiting sparkles ────────────────────────────────
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Container(
                        width: 160 * _pulse.value,
                        height: 160 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              color.withValues(alpha: 0.28 * _iconGlow.value),
                              color.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Inner fill circle
                    ScaleTransition(
                      scale: _iconScale,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.12),
                          border: Border.all(
                            color: color.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: widget.itemImagePath != null
                            ? Image.asset(
                                widget.itemImagePath!,
                                width: 72,
                                height: 72,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  widget.itemIcon,
                                  color: color,
                                  size: 52,
                                ),
                              )
                            : Icon(widget.itemIcon, color: color, size: 52),
                      ),
                    ),
                    // Orbiting sparkles (8 points)
                    AnimatedBuilder(
                      animation: _orbitCtrl,
                      builder: (_, __) {
                        final t = _orbitCtrl.value * 2 * pi;
                        return Stack(
                          alignment: Alignment.center,
                          children: List.generate(8, (i) {
                            final angle = t + (i / 8) * 2 * pi;
                            final r = 68.0 + sin(t * 2 + i) * 6;
                            final opacity =
                                (0.4 + 0.6 * _iconGlow.value) *
                                (0.5 + 0.5 * sin(t + i * 0.8));
                            return Transform.translate(
                              offset: Offset(cos(angle) * r, sin(angle) * r),
                              child: Container(
                                width: i.isEven ? 5 : 3,
                                height: i.isEven ? 5 : 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withValues(
                                    alpha: opacity.clamp(0.0, 1.0),
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Item name + description ─────────────────────────────────
              FadeTransition(
                opacity: _textOpacity,
                child: Column(
                  children: [
                    Text(
                      widget.itemName.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.itemDescription,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fc.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Claim button ────────────────────────────────────────────
              FadeTransition(
                opacity: _btnOpacity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'CLAIM',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.0,
                        ),
                      ),
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
