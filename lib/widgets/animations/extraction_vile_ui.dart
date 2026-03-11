// lib/widgets/shop/extraction_vial_ui.dart
//
// Extraction Vial UI — rarity + elemental-driven animations
// Wire this into your shop view. It reuses your
// AlchemyBrewingParticleSystem and lets rarity dictate intensity while the
// ElementalGroup controls palette/feel.

import 'dart:math' as math;
import 'package:alchemons/models/extraction_vile.dart';
import 'package:flutter/material.dart';

// canonical models/helpers (no duplicates)
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';

/// ─────────────────────────────────────────────────────────
/// UI-only extensions & types (safe to live here)
/// ─────────────────────────────────────────────────────────

/// Animation + FX knobs mapped by rarity.
/// Higher rarity => stronger particles, faster swirl, shinier frame.
class RarityFX {
  final double particleMult; // scales particleCount
  final double speedMult; // scales particle system speed
  final double frameGlow; // 0..1 halo strength
  final bool shimmer; // animated gradient frame
  final bool twinkle; // subtle sparkles overlay
  final bool pulse; // slow radial pulsing
  const RarityFX({
    required this.particleMult,
    required this.speedMult,
    required this.frameGlow,
    this.shimmer = false,
    this.twinkle = false,
    this.pulse = false,
  });
}

/// Keep rarity FX local to UI so you don’t duplicate enums.
extension VialRarityFx on VialRarity {
  String get label => kRarityOrder[index];

  RarityFX get fx {
    switch (this) {
      case VialRarity.common:
        return const RarityFX(
          particleMult: 0.60,
          speedMult: 0.50,
          frameGlow: 0.10,
          shimmer: false,
        );
      case VialRarity.uncommon:
        return const RarityFX(
          particleMult: 0.80,
          speedMult: 0.80,
          frameGlow: 0.18,
          shimmer: false,
        );
      case VialRarity.rare:
        return const RarityFX(
          particleMult: 1.00,
          speedMult: 1.10,
          frameGlow: 0.24,
          shimmer: true,
        );
      case VialRarity.legendary:
        return const RarityFX(
          particleMult: 1.25,
          speedMult: 1.40,
          frameGlow: 0.32,
          shimmer: true,
          twinkle: true,
        );
      case VialRarity.mythic:
        return const RarityFX(
          particleMult: 1.50,
          speedMult: 1.75,
          frameGlow: 0.40,
          shimmer: true,
          twinkle: true,
          pulse: true,
        );
    }
  }
}

/// Basic data model for a sellable extraction vial (UI-side)
class ExtractionVial {
  final String id;
  final String name;
  final ElementalGroup group;
  final VialRarity rarity;
  final int quantity; // stock available
  final int? price; // your currency unit

  const ExtractionVial({
    required this.id,
    required this.name,
    required this.group,
    required this.rarity,
    required this.quantity,
    required this.price,
  });
}

/// Public widget: a tappable card with rarity/element-driven animation.
class ExtractionVialCard extends StatelessWidget {
  final ExtractionVial vial;
  final VoidCallback? onTap;
  final VoidCallback? onAddToInventory;
  final bool compact; // smaller for grid cells

  const ExtractionVialCard({
    super.key,
    required this.vial,
    this.onTap,
    this.onAddToInventory,
    this.compact = false,
  });

  int _baseParticles(ElementalGroup g) {
    // You can vary baseline per element if you want different vibes
    switch (g) {
      case ElementalGroup.volcanic:
        return 90;
      case ElementalGroup.oceanic:
        return 80;
      case ElementalGroup.earthen:
        return 70;
      case ElementalGroup.verdant:
        return 80;
      case ElementalGroup.arcane:
        return 85;
    }
  }

  Color _scorchedAccent(Color base) {
    return Color.lerp(base, const Color(0xFFF59E0B), 0.45) ?? base;
  }

  @override
  Widget build(BuildContext context) {
    final skin = vial.group.skin;
    final fx = vial.rarity.fx;
    final (aType, bType) = vial.group.particleTypes;
    final nameTag = vial.group.displayName.trim();
    final rarityTag = vial.rarity.name.trim().toUpperCase();
    final hasNameTag = nameTag.isNotEmpty;
    final hasRarityTag = rarityTag.isNotEmpty;

    // particle dial — rarity scales both count and speed.
    final particleCount = (_baseParticles(vial.group) * fx.particleMult)
        .round();
    final borderRadius = BorderRadius.circular(compact ? 12 : 16);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [skin.frameStart, skin.frameEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: skin.frameEnd.withValues(alpha: 0.35 * fx.frameGlow),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius.subtract(
            const BorderRadius.all(Radius.circular(2)),
          ),
          child: Stack(
            children: [
              // Animated backdrop tied to element & rarity
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        skin.fill,
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.18),
                      ],
                      stops: const [0.2, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Particle field — reusing your brewing system
              Positioned.fill(
                child: IgnorePointer(
                  child: AlchemyBrewingParticleSystem(
                    parentATypeId: aType,
                    parentBTypeId: bType,
                    particleCount: particleCount,
                    speedMultiplier: fx.speedMult,
                    fusion: false,
                    useSimpleFusion: true,
                  ),
                ),
              ),

              // (Optional) Sparkle / pulse overlays for high rarity
              if (fx.pulse)
                Positioned.fill(child: _PulseOverlay(color: skin.badge)),
              if (fx.twinkle) const Positioned.fill(child: _TwinkleOverlay()),

              // Content
              Positioned.fill(
                child: Container(
                  padding: EdgeInsets.all(compact ? 10 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasNameTag || hasRarityTag)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasNameTag)
                              _ScorchedVialTag(
                                text: nameTag,
                                compact: compact,
                                accent: _scorchedAccent(skin.badge),
                              ),
                            if (hasNameTag && hasRarityTag)
                              const SizedBox(height: 6),
                            if (hasRarityTag)
                              _ScorchedVialTag(
                                text: rarityTag,
                                compact: compact,
                                accent: _scorchedAccent(skin.frameEnd),
                              ),
                          ],
                        ),
                      if (hasNameTag || hasRarityTag) const SizedBox(height: 8),
                      Text(
                        '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (vial.price != null) ...[
                            Text(
                              '${vial.price}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 14 : 16,
                              ),
                            ),
                            Text(
                              '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontWeight: FontWeight.w500,
                                fontSize: compact ? 12 : 13,
                              ),
                            ),
                            const Spacer(),
                            if (onAddToInventory != null)
                              _AddButton(
                                onPressed: onAddToInventory!,
                                compact: compact,
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Subtle moving shimmer on the frame for RARE+
              if (vial.rarity.fx.shimmer)
                Positioned.fill(
                  child: _FrameShimmer(intensity: vial.rarity.fx.frameGlow),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScorchedVialTag extends StatelessWidget {
  final String? text;
  final bool compact;
  final Color accent;

  const _ScorchedVialTag({
    required this.text,
    required this.compact,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final label = text?.trim();
    if (label == null || label.isEmpty) return const SizedBox.shrink();

    final textColor = const Color(0xFFE8DCC8);
    final borderColor = accent.withValues(alpha: 0.75);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1117), Color(0xFF151A23)],
        ),
        borderRadius: BorderRadius.circular(compact ? 9 : 11),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 2 : 3,
            height: compact ? 11 : 13,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 8 : 9,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool compact;
  const _AddButton({required this.onPressed, required this.compact});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.08,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack)),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 10 : 12,
            vertical: widget.compact ? 6 : 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          _ctrl.forward(from: 0);
          widget.onPressed();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16),
            const SizedBox(width: 6),
            Text(
              'Buy',
              style: TextStyle(
                fontSize: widget.compact ? 12 : 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle shimmer sweeping over the frame for rare+ items
class _FrameShimmer extends StatefulWidget {
  final double intensity; // 0..1
  const _FrameShimmer({required this.intensity});
  @override
  State<_FrameShimmer> createState() => _FrameShimmerState();
}

class _FrameShimmerState extends State<_FrameShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + 2 * t, -1),
                end: Alignment(1 + 2 * t, 1),
                colors: [
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.15 * widget.intensity),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.35, 0.5, 0.65],
              ),
              backgroundBlendMode: BlendMode.softLight,
            ),
          ),
        );
      },
    );
  }
}

/// Twinkle overlay: tiny white dots with slow flicker (legendary+)
class _TwinkleOverlay extends StatefulWidget {
  const _TwinkleOverlay();
  @override
  State<_TwinkleOverlay> createState() => _TwinkleOverlayState();
}

class _TwinkleOverlayState extends State<_TwinkleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();
  final math.Random _rng = math.Random();
  final List<Offset> _stars = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureStars(MediaQuery.of(context).size);
  }

  void _ensureStars(Size size) {
    if (_stars.isNotEmpty) return;
    const count = 18;
    for (int i = 0; i < count; i++) {
      _stars.add(
        Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _TwinklePainter(_ctrl, _stars)),
    );
  }
}

class _TwinklePainter extends CustomPainter {
  final Animation<double> anim;
  final List<Offset> stars;
  _TwinklePainter(this.anim, this.stars) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < stars.length; i++) {
      final phase = (i * 0.17) % 1.0;
      final alpha =
          0.25 + 0.75 * (0.5 + 0.5 * math.sin(2 * math.pi * (t + phase)));
      paint.color = Colors.white.withValues(alpha: alpha * 0.3);
      canvas.drawCircle(stars[i], 0.8 + 1.5 * alpha, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter oldDelegate) => true;
}

/// Soft pulsing radial glow (mythic)
class _PulseOverlay extends StatefulWidget {
  final Color color;
  const _PulseOverlay({required this.color});
  @override
  State<_PulseOverlay> createState() => _PulseOverlayState();
}

class _PulseOverlayState extends State<_PulseOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final breathe = 0.5 + 0.5 * math.sin(_ctrl.value * 2 * math.pi);
        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85 + 0.1 * breathe,
                colors: [
                  widget.color.withValues(alpha: 0.10 + 0.05 * breathe),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ---------- Demo grid (optional) ----------
class ExtractionVialGrid extends StatelessWidget {
  final List<ExtractionVial> items;
  final void Function(ExtractionVial) onAdd;
  final void Function(ExtractionVial)? onTap;
  final int crossAxisCount;
  const ExtractionVialGrid({
    super.key,
    required this.items,
    required this.onAdd,
    this.onTap,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final vial = items[i];
        return ExtractionVialCard(
          vial: vial,
          compact: true,
          onTap: onTap == null ? null : () => onTap!(vial),
          onAddToInventory: () => onAdd(vial),
        );
      },
    );
  }
}
