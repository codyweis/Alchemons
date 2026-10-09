import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:alchemons/widgets/fx/grain_text.dart';
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
        // Sand, like the vial it sits on: the word gathers out of grains
        // as the dialog opens, then rests as one picture.
        child: IntrinsicWidth(
          child: GrainText(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Colors.white,
              fontSize: 17.6,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
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
        // A dim disc and the icon: no ring round it, which read as a hoop
        // drawn on the stage rather than a thing on it.
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
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
    this.onStageTap,
    this.payload,
    this.progress,
    this.sphereKey,
    this.arrival,
  });

  /// On the sphere, so it can be handed on (see [CultivationHandoff]).
  final GlobalKey? sphereKey;

  /// The chamber's own sphere, flown up onto this stage as it opens.
  final CultivationFlight? arrival;

  /// The cultivation's saved data. With it, the stage shows the cultivation
  /// as its chamber does — its parents' grains in one turning sphere, which
  /// a held finger can part — only bigger.
  final Map<String, dynamic>? payload;

  /// 0..1 to extraction, for how fast that sphere turns.
  final double? progress;

  final List<String>? parentTypes;
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

  /// Tapping the vial itself does what the button on it does.
  ///
  /// The word EXTRACT is a small target sitting on a 245px disc that reads as
  /// the thing you are acting on — so the disc is the target too, and the
  /// button is the label for it.
  final VoidCallback? onStageTap;

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
                child: GestureDetector(
                  onTap: onStageTap == null
                      ? null
                      : context.soundTap(onStageTap!),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.square(
                    dimension: 245,
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (payload != null &&
                              TickerMode.valuesOf(context).enabled &&
                              !media.disableAnimations)
                            ColoredBox(
                              color: kCultivationStage,
                              child: CultivationSphere(
                                key: sphereKey,
                                payload: payload!,
                                types: parentTypes ?? const [],
                                progress: progress,
                                isReady: fusion,
                                grains: 1100,
                                radiusFactor: 0.36,
                                pureElement: pureElementTypeId,
                                arrival: arrival,
                              ),
                            )
                          else if (showParticles)
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
              ),
              Positioned(
                top: 10,
                left: 14,
                child: CultivationChamberPill(label: chamberLabel),
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

/// Where this cultivation is standing ("CHAMBER 2", "COLD STORAGE"): a plain
/// word in the stage's corner. It wore a squared border in the rarity's
/// color, which made a place read as a status.
class CultivationChamberPill extends StatelessWidget {
  const CultivationChamberPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'monospace',
        // The stage is dark on both themes.
        color: BracketPalette.dark.muted,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}
