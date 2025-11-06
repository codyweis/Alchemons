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
class _RarityFX {
  final double particleMult; // scales particleCount
  final double speedMult; // scales particle system speed
  final double frameGlow; // 0..1 halo strength
  final bool shimmer; // animated gradient frame
  final bool twinkle; // subtle sparkles overlay
  final bool pulse; // slow radial pulsing
  const _RarityFX({
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

  _RarityFX get fx {
    switch (this) {
      case VialRarity.common:
        return const _RarityFX(
          particleMult: 0.60,
          speedMult: 0.50,
          frameGlow: 0.10,
          shimmer: false,
        );
      case VialRarity.uncommon:
        return const _RarityFX(
          particleMult: 0.80,
          speedMult: 0.80,
          frameGlow: 0.18,
          shimmer: false,
        );
      case VialRarity.rare:
        return const _RarityFX(
          particleMult: 1.00,
          speedMult: 1.10,
          frameGlow: 0.24,
          shimmer: true,
        );
      case VialRarity.legendary:
        return const _RarityFX(
          particleMult: 1.25,
          speedMult: 1.40,
          frameGlow: 0.32,
          shimmer: true,
          twinkle: true,
        );
      case VialRarity.mythic:
        return const _RarityFX(
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

  @override
  Widget build(BuildContext context) {
    final skin = vial.group.skin;
    final fx = vial.rarity.fx;
    final (aType, bType) = vial.group.particleTypes;

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
              color: skin.frameEnd.withOpacity(0.35 * fx.frameGlow),
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
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.18),
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
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 8 : 10,
                              vertical: compact ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: skin.badge.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: skin.badge.withOpacity(0.7),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              vial.name,
                              style: TextStyle(
                                color: skin.badge,
                                fontWeight: FontWeight.w600,
                                fontSize: compact ? 10 : 12,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                                color: Colors.white.withOpacity(0.95),
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 14 : 16,
                              ),
                            ),
                            Text(
                              '',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.70),
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
          backgroundColor: Colors.white.withOpacity(0.1),
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
              'Add',
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

class _RarityChip extends StatelessWidget {
  final VialRarity rarity;
  const _RarityChip({required this.rarity});

  @override
  Widget build(BuildContext context) {
    final colors = <VialRarity, List<Color>>{
      VialRarity.common: [const Color(0xFF334155), const Color(0xFF475569)],
      VialRarity.uncommon: [const Color(0xFF14532D), const Color(0xFF15803D)],
      VialRarity.rare: [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
      VialRarity.legendary: [const Color(0xFF7C2D12), const Color(0xFFEA580C)],
      VialRarity.mythic: [const Color(0xFF4C1D95), const Color(0xFFA21CAF)],
    }[rarity]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rarity.name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.2,
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
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.15 * widget.intensity),
                  Colors.white.withOpacity(0.0),
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
      paint.color = Colors.white.withOpacity(alpha * 0.3);
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
                  widget.color.withOpacity(0.10 + 0.05 * breathe),
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
