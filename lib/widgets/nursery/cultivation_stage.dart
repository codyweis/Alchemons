import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The ground a cultivation is shown against, in both themes.
///
/// A vial is a lit object — the particles inside it are the whole point — and
/// on a light surface the glow has nothing to read against. So the cultivation
/// dialogs stay dark whatever the app theme is, the way a lightbox does.
const Color kCultivationStage = Color(0xFF0B0E13);

/// The one thing you came to the dialog to do, sitting on the vial itself.
///
/// Replaces a full-width footer button under a heading that only restated what
/// the screen was already showing.
class VialActionButton extends StatelessWidget {
  const VialActionButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundTap(onTap),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // No pill, no border, no icon, and the same white whatever the
        // specimen's rarity is. The word is the button.
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: Colors.white,
            fontSize: 17.6,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
      ),
    );
  }
}

/// A round control tucked into a corner of the stage, for the actions that are
/// not the main one.
class StageIconButton extends StatelessWidget {
  const StageIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.heavy = false,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  /// Discarding is worth a firmer knock than storing.
  final bool heavy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: context.soundTap(() {
          if (heavy) HapticFeedback.mediumImpact();
          onTap();
        }),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

/// The cultivation dialog, both of them.
///
/// In-progress and ready were two separate implementations of the same
/// picture — their own circular banner, their own particle layer, their own
/// vignette, their own bottom row — and every time one was adjusted the other
/// drifted. They differ in four things and nothing else: what the button on
/// the vial does, what the left-hand icon does, whether anything sits in the
/// middle of the row, and how hard the brew is churning. So those are the
/// parameters, and the picture is written once.
class CultivationVialStage extends StatelessWidget {
  const CultivationVialStage({
    super.key,
    required this.parentTypes,
    required this.accentColor,
    required this.chamberLabel,
    required this.action,
    required this.leading,
    required this.trailing,
    required this.particleCount,
    required this.speedMultiplier,
    required this.theme,
    this.centre,
    this.below,
    this.fusion = false,
    this.pureElementTypeId,
  });

  final List<String>? parentTypes;
  final Color accentColor;
  final String chamberLabel;

  /// The one thing you came here to do, drawn on the vial.
  final Widget action;

  /// Store, or discard.
  final Widget leading;

  /// Close.
  final Widget trailing;

  /// The countdown, when there is still something to wait for.
  final Widget? centre;

  /// Instant fuse, when you have one.
  final Widget? below;

  final int particleCount;
  final double speedMultiplier;
  final FactionTheme theme;

  /// The finished look — the brew collapsing to its fused result. This is what
  /// a ready chamber shows on its card, and the ready dialog lost it when the
  /// two dialogs were merged onto this widget.
  final bool fusion;
  final String? pureElementTypeId;

  /// Dark in both themes, so these never branch on brightness.
  static const _overlayTint = Colors.black;
  static const _vignetteAlpha = .5;
  static const _bottomFadeAlpha = .65;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final showParticles =
        TickerMode.valuesOf(context).enabled &&
        !media.disableAnimations &&
        particleCount > 0 &&
        parentTypes != null &&
        parentTypes!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 280,
          child: Stack(
            children: [
              // The brew, drawn as the round chamber it stands in.
              Center(
                child: SizedBox.square(
                  dimension: 245,
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (showParticles)
                          RepaintBoundary(
                            child: AlchemyBrewingParticleSystem(
                              parentATypeId: parentTypes![0],
                              parentBTypeId: parentTypes!.length > 1
                                  ? parentTypes![1]
                                  : null,
                              particleCount: particleCount,
                              speedMultiplier: speedMultiplier,
                              fusion: fusion,
                              pureElementTypeId: pureElementTypeId,
                              theme: theme,
                            ),
                          )
                        else
                          const ColoredBox(color: kCultivationStage),
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.85,
                              colors: [
                                Colors.transparent,
                                Color.fromRGBO(0, 0, 0, _vignetteAlpha),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 56,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  _overlayTint.withValues(
                                    alpha: _bottomFadeAlpha,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 14,
                child: CultivationChamberPill(
                  label: chamberLabel,
                  color: accentColor,
                ),
              ),
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(child: action),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              leading,
              Expanded(child: Center(child: centre ?? const SizedBox.shrink())),
              trailing,
            ],
          ),
        ),
        if (below != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Center(child: below),
          ),
      ],
    );
  }
}

/// The chamber this cultivation is standing in.
class CultivationChamberPill extends StatelessWidget {
  const CultivationChamberPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      // Squared, not a pill — it is a label on a piece of equipment.
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
