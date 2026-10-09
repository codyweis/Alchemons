import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/audio/audio.dart';
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
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';

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

/// Smoked glass: what every vial is shown against — the black market's
/// lots, the inventory, cold storage. Dark whatever the theme, as a cabinet
/// is, so the grains glow.
const Color kVialGlass = Color(0xE60B0A10);

/// The light a vial gives off: a soft pool of its color, never a ring or a
/// disc. [strength] scales it (a ready cultivation glows a little more).
class VialLightPool extends StatelessWidget {
  const VialLightPool({super.key, required this.color, this.strength = 1});

  final Color color;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: (0.34 * strength).clamp(0.0, 1.0)),
              color.withValues(alpha: (0.1 * strength).clamp(0.0, 1.0)),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

/// A vial held up to the light: what it holds — a sphere of its elements'
/// grains, turning as a cultivation does — over a soft pool of its color.
/// No card or disc round it: a flat ball of color read as a button rather
/// than a thing.
class ExtractionVialOrb extends StatelessWidget {
  const ExtractionVialOrb({super.key, required this.vial, required this.size});

  final ExtractionVial vial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (a, b) = vial.group.particleTypes;
    final fx = vial.rarity.fx;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VialLightPool(color: vial.group.color),
          IgnorePointer(
            child: CultivationSphere(
              payload: const {},
              types: [a, ?b],
              // Fewer for a small one: at a thumbnail they would only mat.
              grains: (size * 3.4 * fx.particleMult).round().clamp(60, 640),
              interactive: false,
              spinScale: 0.6 + fx.speedMult,
              twinkle: fx.twinkle ? 2.5 : 1,
              radiusFactor: 0.34,
            ),
          ),
        ],
      ),
    );
  }
}

/// Public widget: a tappable card with rarity/element-driven animation.
class ExtractionVialCard extends StatelessWidget {
  final ExtractionVial vial;
  final VoidCallback? onTap;
  final VoidCallback? onAddToInventory;
  final bool compact; // smaller for grid cells
  final bool showTags;

  /// Draws the vial as a disc rather than a card.
  ///
  /// The faction picker shows one vial as a specimen rather than as an item
  /// in a list, and a round frame reads as a thing held up to the light.
  /// Rounding has to happen in the decoration, not a clip over it — clipping
  /// the card would cut its own frame off.
  final bool circular;

  /// Whether the [circular] lens sits on a light page.
  final bool onLight;

  const ExtractionVialCard({
    super.key,
    required this.vial,
    this.onTap,
    this.onAddToInventory,
    this.compact = false,
    this.showTags = true,
    this.circular = false,
    this.onLight = false,
  });

  Color _scorchedAccent(Color base) {
    return Color.lerp(base, const Color(0xFFCDB07A), 0.45) ?? base;
  }

  @override
  Widget build(BuildContext context) {
    final color = vial.group.color;
    final fx = vial.rarity.fx;

    // Shown as a specimen (the faction picker): the orb, in a lens of
    // smoked glass that fades out at its edge — the grains need the dark to
    // glow against, on the light theme too, and a hard disc read as a
    // button.
    if (circular) {
      return GestureDetector(
        onTap: context.soundAction(onTap),
        child: LayoutBuilder(
          builder: (context, box) {
            final side = math.min(box.maxWidth, box.maxHeight);
            return Center(
              child: SizedBox.square(
                dimension: side,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // On paper a long fade out of the dark is a grey
                        // smudge: there the lens is a bead of smoked glass,
                        // its rim catching a little light, with a short edge.
                        gradient: onLight
                            ? const RadialGradient(
                                colors: [
                                  Color(0xFF1C1922),
                                  Color(0xF70B0A10),
                                  Color(0xF7302B36),
                                  Color(0x000B0A10),
                                ],
                                stops: [0.0, 0.76, 0.86, 0.93],
                              )
                            : const RadialGradient(
                                colors: [
                                  kVialGlass,
                                  Color(0xCC0B0A10),
                                  Color(0x000B0A10),
                                ],
                                stops: [0.0, 0.62, 1.0],
                              ),
                      ),
                    ),
                    ExtractionVialOrb(vial: vial, size: side),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final nameTag = vial.group.displayName.trim();
    final hasNameTag = showTags && nameTag.isNotEmpty;
    final hasFooter = vial.price != null;

    // A case of smoked glass, its corners in the vial's color — brighter
    // the rarer — and the vial held up in it. It used to be a card of
    // saturated color, which read as a button rather than a thing.
    return GestureDetector(
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: color.withValues(
            alpha: (0.55 + 0.4 * fx.frameGlow).clamp(0.0, 1.0),
          ),
          bracketSize: compact ? 8 : 10,
        ),
        child: Container(
          color: kVialGlass,
          child: LayoutBuilder(
            builder: (context, box) {
              final side = math.min(box.maxWidth, box.maxHeight);
              // Room for the tag and the price, when there are any.
              final crowded = hasNameTag || hasFooter;
              return Stack(
                children: [
                  Center(
                    child: ExtractionVialOrb(
                      vial: vial,
                      size: side * (crowded ? 0.78 : 0.92),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 10 : 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The element, and nothing else. The grade tag
                          // under it read "WORN" / "RUNED": flavour words
                          // that told the player nothing they could act on.
                          if (hasNameTag)
                            _ScorchedVialTag(
                              text: nameTag,
                              compact: compact,
                              accent: _scorchedAccent(color),
                            ),
                          const Spacer(),
                          if (hasFooter)
                            Row(
                              children: [
                                Text(
                                  '${vial.price}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: const Color(0xFFE8DCC8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: compact ? 13 : 15,
                                  ),
                                ),
                                const Spacer(),
                                if (onAddToInventory != null)
                                  _AddButton(
                                    onPressed: onAddToInventory!,
                                    compact: compact,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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
          colors: [Color(0xFF131316), Color(0xFF151518)],
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(() {
          _ctrl.forward(from: 0);
          widget.onPressed();
        }),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: const Color(0xFFFFB74D),
            bracketSize: widget.compact ? 5 : 6,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 9 : 11,
              vertical: widget.compact ? 5 : 7,
            ),
            color: const Color(0xFFFFB74D).withValues(alpha: 0.14),
            child: Text(
              'BUY',
              style: TextStyle(
                fontFamily: 'monospace',
                color: const Color(0xFFE8DCC8),
                fontSize: widget.compact ? 11 : 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ),
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
