import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';

class LootOpeningEntry {
  final IconData icon;
  final String label;
  final String? name;
  final Color color;

  const LootOpeningEntry({
    required this.icon,
    required this.label,
    this.name,
    required this.color,
  });
}

Future<void> showLootOpeningDialog({
  required BuildContext context,
  required List<LootOpeningEntry> entries,
  String title = 'REWARDS',
}) async {
  if (entries.isEmpty) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.80),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (ctx, _, __) =>
        _SleekLootDialog(entries: entries, title: title),
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
    for (final c in _rowCtrls) c.dispose();
    _btnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFAA00);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loot opening Lottie animation
              Center(
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Lottie.asset(
                    'assets/animations/loot-open.json',
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
              Container(height: 1, color: amber.withOpacity(0.25)),
              const SizedBox(height: 32),
              ...List.generate(widget.entries.length, (i) {
                final e = widget.entries[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 26),
                  child: FadeTransition(
                    opacity: _rowFade[i],
                    child: SlideTransition(
                      position: _rowSlide[i],
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: e.color.withOpacity(0.12),
                              border: Border.all(
                                color: e.color.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Icon(e.icon, color: e.color, size: 22),
                          ),
                          const SizedBox(width: 18),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.label,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: e.color,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                  height: 1.0,
                                ),
                              ),
                              if (e.name != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  e.name!.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF7A7A8A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
                      color: amber.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: amber, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: amber.withOpacity(0.22),
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
    );
  }
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
                    FC.amberGlow.withOpacity(_glow.value),
                    FC.amberDim.withOpacity(0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.15, 0.7, 1.0],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 52,
                color: FC.amberBright,
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
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.92),
    transitionDuration: const Duration(milliseconds: 400),
    transitionBuilder: (ctx, anim, _, child) {
      return FadeTransition(opacity: anim, child: child);
    },
    pageBuilder: (ctx, _, __) => _KeyItemRevealDialog(
      itemName: itemName,
      itemDescription: itemDescription,
      itemIcon: itemIcon,
      elementColor: elementColor,
    ),
  );
}

class _KeyItemRevealDialog extends StatefulWidget {
  final String itemName;
  final String itemDescription;
  final IconData itemIcon;
  final Color elementColor;

  const _KeyItemRevealDialog({
    required this.itemName,
    required this.itemDescription,
    required this.itemIcon,
    required this.elementColor,
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
                              color.withOpacity(0.28 * _iconGlow.value),
                              color.withOpacity(0.0),
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
                          color: color.withOpacity(0.12),
                          border: Border.all(
                            color: color.withOpacity(0.6),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(widget.itemIcon, color: color, size: 52),
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
                                  color: color.withOpacity(
                                    opacity.clamp(0.0, 1.0),
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
                      style: const TextStyle(
                        color: FC.textSecondary,
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
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.35),
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
